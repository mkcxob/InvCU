//
//  ItemLookupView.swift
//  InvCU
//
//  Created by work on 11/17/25.
//

import SwiftUI

struct ItemLookupView: View {
    // MARK: - State Management
    
    @StateObject private var supabaseManager = SupabaseManager.shared
    @Binding var isAuthenticated: Bool
    
    @State private var searchText = ""
    @State private var searchResults: [InventoryItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    
    @State private var selectedItem: InventoryItem?
    @State private var showingDetail = false
    @State private var showingBarcodeScanner = false
    
    @State private var bookmarkInFlight:  Set<UUID> = []
    
    @State private var cachedItems: [InventoryItem] = []
    @State private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Computed Properties
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    private var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheTimeout
    }
    
    // MARK: - Main Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    searchControls
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if isSearching {
                                loadingView
                            } else if let error = searchError {
                                errorView(error)
                            } else if !searchResults.isEmpty {
                                searchResultsView
                            } else if !searchText.isEmpty {
                                noResultsView
                            } else {
                                emptyStateView
                            }
                        }
                        .padding(.horizontal, 20)
                        . padding(.vertical, 16)
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
                            Task { await updateItem(updatedItem) }
                        },
                        onBookmarkToggle: { tappedItem in
                            toggleBookmark(for: tappedItem)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(isPresented: $showingBarcodeScanner) { barcode in
                    print("BARCODE SCANNED")
                    print("Raw barcode value: '\(barcode)'")
                    print("Barcode length: \(barcode.count)")
                    
                    searchText = barcode
                    performSearch()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showingDetail)
            .task {
                await loadCacheIfNeeded()
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: ProfileView(isAuthenticated: $isAuthenticated)) {
                Image(. image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color(UIColor.systemBlue)))
                    .clipShape(Circle())
                    .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            }
            
            Spacer()
            
            Text("Search")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            Color.clear
                .frame(width: 52, height: 52)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Search Controls
    
    private var searchControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .font(.system(size: 16))
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    . font(.system(size: 16))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchError = nil
                    }) {
                        Image(systemName:  "xmark. circle.fill")
                            . foregroundColor(Color(UIColor.secondaryLabel))
                            . font(.system(size: 16))
                    }
                }
            }
            . padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08),
                radius: 4, x: 0, y: 2
            )
            
            Button(action: { showingBarcodeScanner = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 16))
                    Text("Barcode")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08),
                    radius: 4, x: 0, y: 2
                )
            }
        }
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .padding(.top, 40)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(. secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(. red)
                .padding(.top, 40)
            Text("Search Error")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(. secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { performSearch() }
                .buttonStyle(. borderedProminent)
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(. secondary)
                .padding(.top, 60)
            Text("No items found")
                .font(.headline)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 60)
            Text("Search for items")
                .font(.headline)
            Text("Enter an item name, barcode, or scan a barcode")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var searchResultsView: some View {
        LazyVStack(spacing: 12) {
            ForEach(searchResults) { item in
                InventoryCard(
                    item: binding(for: item),
                    onBookmarkToggle: { toggleBookmark(for: item) },
                    onTap: {
                        selectedItem = item
                        showingDetail = true
                    }
                )
            }
        }
    }
    
    // MARK: - Cache Management

    private func loadCacheIfNeeded() async {
        guard !isCacheValid else { return }
        
        do {
            var items = try await supabaseManager.fetchAllItems()
            
            print("SEARCH CACHE:  IMAGE PRELOAD START")
            print("Total items:  \(items.count)")
            
            for index in items.indices {
                if items[index].isURLImage {
                    print("Preloading image for:  \(items[index].name)")
                    let image = await ImageCache.shared.fetchImage(for: items[index].imageName)
                    items[index].cachedUIImage = image
                    
                    if image != nil {
                        print("Cached:  \(items[index].name)")
                    } else {
                        print("Failed:  \(items[index].name)")
                    }
                }
            }
            
            print("SEARCH CACHE:  PRELOAD COMPLETE")
            
            await MainActor.run {
                cachedItems = items
                lastFetchTime = Date()
            }
        } catch {
            print("Failed to preload cache: \(error.localizedDescription)")
        }
    }

    // MARK: - Search Logic

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: . whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        Task { await executeSearch() }
    }

    private func executeSearch() async {
        isSearching = true
        searchError = nil
        
        do {
            let allItems:  [InventoryItem]
            
            if isCacheValid && !cachedItems.isEmpty {
                print("Using cached items with preloaded images")
                allItems = cachedItems
            } else {
                print("Fetching fresh items and preloading images...")
                var freshItems = try await supabaseManager.fetchAllItems()
                
                for index in freshItems.indices {
                    if freshItems[index].isURLImage {
                        let image = await ImageCache.shared.fetchImage(for: freshItems[index].imageName)
                        freshItems[index].cachedUIImage = image
                    }
                }
                
                allItems = freshItems
                
                await MainActor.run {
                    cachedItems = allItems
                    lastFetchTime = Date()
                }
                
                print("Cached \(allItems.count) items with images")
            }
            
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("SEARCH DEBUG")
            print("Search query: '\(query)'")
            print("Total items in cache: \(allItems.count)")
            
            print("All item barcodes:")
            for item in allItems {
                print("   - \(item.name): barcode = '\(item.itemId)'")
            }
            
            let filtered = allItems.filter { item in
                let queryLower = query.lowercased()
                let barcodeLower = item.itemId.lowercased()
                let nameLower = item.name.lowercased()
                let categoryLower = item.category.lowercased()
                
                let exactBarcodeMatch = barcodeLower == queryLower
                let partialBarcodeMatch = barcodeLower.contains(queryLower)
                let nameMatch = nameLower.contains(queryLower)
                let categoryMatch = categoryLower.contains(queryLower)
                
                let matches = exactBarcodeMatch || partialBarcodeMatch || nameMatch || categoryMatch
                
                if matches {
                    print("MATCH: \(item.name) (barcode: \(item.itemId))")
                }
                
                return matches
            }
            
            print("Found \(filtered.count) matching items")
            
            await MainActor.run { searchResults = filtered }
        } catch {
            print("Search error: \(error.localizedDescription)")
            await MainActor.run { searchError = error.localizedDescription }
        }
        
        isSearching = false
    }
    
    // MARK: - Data Operations
    
    private func updateItem(_ item: InventoryItem) async {
        do {
            try await supabaseManager.updateItem(item)
            await MainActor.run {
                if let index = searchResults.firstIndex(where: { $0.id == item.id }) {
                    searchResults[index] = item
                }
                if let cacheIndex = cachedItems.firstIndex(where: { $0.id == item.id }) {
                    cachedItems[cacheIndex] = item
                }
            }
        } catch {
            print("Error updating item: \(error)")
            searchError = "Failed to update item:  \(error.localizedDescription)"
        }
    }
    
    private func toggleBookmark(for item: InventoryItem) {
        guard let index = searchResults.firstIndex(where: { $0.id == item.id }) else { return }
        
        if bookmarkInFlight.contains(item.id) { return }
        bookmarkInFlight.insert(item.id)
        
        let oldState = searchResults[index].isBookmarked
        let newState = !oldState
        searchResults[index].isBookmarked = newState
        
        if let cacheIndex = cachedItems.firstIndex(where: { $0.id == item.id }) {
            cachedItems[cacheIndex].isBookmarked = newState
        }
        
        if showingDetail, selectedItem?.id == item.id { selectedItem = searchResults[index] }
        
        Task {
            do { try await supabaseManager.toggleBookmark(item.id, isBookmarked: newState) }
            catch {
                _ = await MainActor.run {
                    if let idx = searchResults.firstIndex(where: { $0.id == item.id }) {
                        searchResults[idx].isBookmarked = oldState
                        if showingDetail, selectedItem?.id == item.id { selectedItem = searchResults[idx] }
                    }
                    if let cacheIdx = cachedItems.firstIndex(where: { $0.id == item.id }) {
                        cachedItems[cacheIdx].isBookmarked = oldState
                    }
                }
            }
            _ = await MainActor.run { bookmarkInFlight.remove(item.id) }
        }
    }
    
    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = searchResults.firstIndex(where: { $0.id == item.id }) else { return .constant(item) }
        return $searchResults[index]
    }
}

// MARK: - Preview

struct ItemLookupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ItemLookupView(isAuthenticated: . constant(true))
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            ItemLookupView(isAuthenticated: . constant(true))
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }
}

