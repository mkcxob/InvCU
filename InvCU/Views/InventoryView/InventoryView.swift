//
//  InventoryView. swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI
import Storage
import Supabase

struct InventoryView: View {
    // MARK: - State Management
    
    @StateObject private var supabaseManager = SupabaseManager.shared
    @Binding var isAuthenticated: Bool
    
    @State private var selectedCategory = "Merchandise"
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?
    @State private var showingDetail = false
    @State private var showingAddItem = false
    
    @State private var inventoryItems: [InventoryItem] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var loadError: String?
    
    @State private var bookmarkInFlight: Set<UUID> = []
    
    let categories = ["Merchandise", "Decorations", "Banners"]
    
    // MARK:  - Computed Properties
    
    var filteredItems: [InventoryItem] {
        inventoryItems.filter { item in
            let matchesCategory = item.category == selectedCategory
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    // MARK: - Main View Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading inventory...")
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text("Failed to load inventory")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await loadItemsAndPreloadImages() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 0) {
                        header
                        
                        ScrollView {
                            VStack(spacing: 16) {
                                categoryFilter
                                
                                if filteredItems.isEmpty {
                                    emptyState
                                } else {
                                    inventoryCards
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if showingDetail, let item = selectedItem {
                    ItemDetailOverlay(
                        item: binding(for: item),
                        isPresented: $showingDetail,
                        onUpdate: { updatedItem in
                            Task {
                                await updateItem(updatedItem)
                            }
                        },
                        onBookmarkToggle: { tappedItem in
                            toggleBookmark(for: tappedItem)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(
                    isPresented: $showingAddItem,
                    onAddItem: { newItem in
                        Task {
                            await addItem(newItem)
                        }
                    }
                )
            }
            .animation(.easeInOut(duration: 0.25), value: showingDetail)
            .task {
                await loadItemsAndPreloadImages()
            }
            .refreshable {
                await refreshItems()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No items in \(selectedCategory)")
                .font(.headline)
            Text("Add your first item to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Data Operations
    
    /// Fetches all inventory items from Supabase and preloads all images into memory
    private func loadItemsAndPreloadImages() async {
        isLoading = true
        loadError = nil
        
        do {
            // Load items from database
            var loadedItems = try await supabaseManager.fetchAllItems()
            
            print("\n===== IMAGE PRELOAD START =====")
            print("Total items loaded: \(loadedItems.count)")
            
            // Count how many have URL images
            let urlImageCount = loadedItems.filter { $0.isURLImage }.count
            print("Items with URL images: \(urlImageCount)")
            
            // Preload all images and store directly in items
            for index in loadedItems.indices {
                let item = loadedItems[index]
                
                if item.isURLImage {
                    print("\n[\(index + 1)/\(loadedItems.count)] Processing: \(item.name)")
                    print("   URL:  \(item.imageName)")
                    print("   Fetching image...")
                    
                    let startTime = Date()
                    let image = await ImageCache.shared.fetchImage(for: item.imageName)
                    let elapsed = Date().timeIntervalSince(startTime)
                    
                    loadedItems[index].cachedUIImage = image
                    
                    if let img = image {
                        print("   SUCCESS:  Cached \(item.name)")
                        print("   Image size: \(img.size.width)x\(img.size.height)")
                        print("   Time:  \(String(format: "%.2f", elapsed))s")
                    } else {
                        print("   FAILED: Could not load image for \(item.name)")
                        print("   Time: \(String(format: "%.2f", elapsed))s")
                    }
                } else {
                    print("\n[\(index + 1)/\(loadedItems.count)] Skipping: \(item.name) (SF Symbol)")
                }
            }
            
            inventoryItems = loadedItems
            
            print("\n===== IMAGE PRELOAD COMPLETE =====")
            print("Successfully cached:  \(loadedItems.filter { $0.cachedUIImage != nil }.count)/\(urlImageCount)")
            print("=========================================\n")
            
        } catch {
            loadError = error.localizedDescription
            print("Error loading items: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refreshes inventory items when user pulls to refresh
    private func refreshItems() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        loadError = nil
        
        do {
            var newItems = try await supabaseManager.fetchAllItems()
            
            // Preload images for new items
            for index in newItems.indices {
                if newItems[index].isURLImage {
                    let image = await ImageCache.shared.fetchImage(for: newItems[index].imageName)
                    newItems[index].cachedUIImage = image
                }
            }
            
            await MainActor.run {
                inventoryItems = newItems
            }
            
        } catch {
            loadError = error.localizedDescription
            print("Error refreshing items:", error)
        }
        
        isRefreshing = false
    }
    
    /// Adds new item to inventory and database
    private func addItem(_ item: InventoryItem) async {
        do {
            var addedItem = try await supabaseManager.addItem(item)
            
            // Preload the new item's image
            if addedItem.isURLImage {
                addedItem.cachedUIImage = await ImageCache.shared.fetchImage(for: addedItem.imageName)
            }
            
            await MainActor.run {
                inventoryItems.append(addedItem)
            }
            
        } catch {
            print("Error adding item:", error)
            loadError = "Failed to add item: \(error.localizedDescription)"
        }
    }
    
    /// Updates existing item in inventory and database
    private func updateItem(_ item: InventoryItem) async {
        do {
            try await supabaseManager.updateItem(item)
            await MainActor.run {
                if let index = inventoryItems.firstIndex(where: { $0.id == item.id }) {
                    var updatedItem = item
                    // Preserve cached image
                    updatedItem.cachedUIImage = inventoryItems[index].cachedUIImage
                    // Re-cache if image changed
                    if updatedItem.isURLImage && updatedItem.imageName != inventoryItems[index].imageName {
                        Task {
                            updatedItem.cachedUIImage = await ImageCache.shared.fetchImage(for: updatedItem.imageName)
                            if let idx = inventoryItems.firstIndex(where: { $0.id == item.id }) {
                                inventoryItems[idx] = updatedItem
                            }
                        }
                    }
                    inventoryItems[index] = updatedItem
                }
            }
        } catch {
            print("Error updating item:", error)
            loadError = "Failed to update item: \(error.localizedDescription)"
        }
    }
    
    /// Toggles bookmark state for item with optimistic UI update
    private func toggleBookmark(for item: InventoryItem) {
        print("\n=== BOOKMARK TOGGLE START ===")
        print("Item: \(item.name)")
        print("Barcode: \(item.id)")
        
        guard let index = inventoryItems.firstIndex(where: { $0.id == item.id }) else {
            print("ERROR: Item not found in array")
            return
        }
        
        if bookmarkInFlight.contains(item.id) {
            print("WARNING:  Blocked - already in progress")
            return
        }
        
        bookmarkInFlight.insert(item.id)
        
        let oldState = inventoryItems[index].isBookmarked
        let newState = !oldState
        
        print("State change: \(oldState) -> \(newState)")
        
        inventoryItems[index].isBookmarked = newState
        
        if showingDetail, selectedItem?.id == item.id {
            selectedItem = inventoryItems[index]
        }
        
        Task {
            do {
                try await supabaseManager.toggleBookmark(item.id, isBookmarked: newState)
                print("SUCCESS: Saved to database")
                
            } catch {
                print("ERROR: Database failed - \(error.localizedDescription)")
                
                await MainActor.run {
                    if let idx = inventoryItems.firstIndex(where: { $0.id == item.id }) {
                        inventoryItems[idx].isBookmarked = oldState
                        
                        if showingDetail, selectedItem?.id == item.id {
                            selectedItem = inventoryItems[idx]
                        }
                        
                        print("REVERTED: Back to \(oldState)")
                    }
                }
            }
            
            await MainActor.run {
                bookmarkInFlight.remove(item.id)
                print("=== BOOKMARK TOGGLE COMPLETE ===\n")
            }
        }
    }
    
    /// Creates a binding for an item to allow two-way data flow in child views
    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = inventoryItems.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $inventoryItems[index]
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: ProfileView(isAuthenticated: $isAuthenticated)) {
                Image(.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color(UIColor.systemBlue)))
                    .clipShape(Circle())
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            }

            Spacer()

            Text("Marketing Inventory")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .offset(x: -4)

            Spacer()
        
            Button(action: {
                showingAddItem = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.brandNavy)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selectedCategory == category
                                      ? Color.brandNavy
                                      : Color(UIColor.secondarySystemBackground))
                            
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color(UIColor.separator).opacity(0.25), lineWidth: 1)
                            
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedCategory == category ? .white : Color(UIColor.label))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.12),
                                radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Inventory Cards
    
    private var inventoryCards: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredItems) { item in
                InventoryCard(
                    item: binding(for: item),
                    onBookmarkToggle: {
                        toggleBookmark(for: item)
                    },
                    onTap: {
                        // Find and use the item with cached image
                        if let index = inventoryItems.firstIndex(where: { $0.id == item.id }) {
                            selectedItem = inventoryItems[index]
                        }
                        showingDetail = true
                    }
                )
            }
        }
    }
}
 
// MARK: - Preview
struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InventoryView(isAuthenticated: .constant(true))
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            InventoryView(isAuthenticated: .constant(true))
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }
}
