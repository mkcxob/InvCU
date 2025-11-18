//
//  ItemLookupView.swift
//  InvCU
//
//  Created by work on 11/17/25.
//

import SwiftUI

struct ItemLookupView: View {
    // MARK: - State Management
    
    @StateObject private var supabaseManager = SupabaseManager.shared // Handles data fetching/updating
    
    @State private var searchText = ""               // Text in the search field
    @State private var searchResults: [InventoryItem] = [] // Stores items that match search
    @State private var isSearching = false          // Shows loading indicator
    @State private var searchError: String?         // Stores any search errors
    
    @State private var selectedItem: InventoryItem? // Item selected for detail view
    @State private var showingDetail = false        // Controls detail overlay
    @State private var showingBarcodeScanner = false // Shows barcode scanner sheet
    
    @State private var bookmarkInFlight: Set<UUID> = [] // Tracks bookmarks being updated
    
    @Environment(\.colorScheme) private var colorScheme // Detect dark/light mode
    
    // MARK: - Computed Properties
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    // MARK: - Main Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground) // Background color
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header                   // Header with title and image
                    
                    searchControls            // Search bar + barcode button
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if isSearching {                  // Show loading
                                loadingView
                            } else if let error = searchError { // Show error
                                errorView(error)
                            } else if !searchResults.isEmpty { // Show results
                                searchResultsView
                            } else if !searchText.isEmpty {   // Show no results
                                noResultsView
                            } else {                           // Show initial empty state
                                emptyStateView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if showingDetail, let item = selectedItem {
                    ItemDetailOverlay(
                        item: binding(for: item),        // Pass binding to detail overlay
                        isPresented: $showingDetail,
                        onUpdate: { updatedItem in       // Update item callback
                            Task { await updateItem(updatedItem) }
                        },
                        onBookmarkToggle: { tappedItem in
                            toggleBookmark(for: tappedItem) // Toggle bookmark callback
                        }
                    )
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                // Show barcode scanner sheet
                BarcodeScannerView(isPresented: $showingBarcodeScanner) { barcode in
                    searchText = barcode
                    performSearch() // Auto-search barcode
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showingDetail)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(.image) // Placeholder image
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color(UIColor.systemBlue)))
                .clipShape(Circle())
                .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            
            Spacer()
            
            Text("Search") // Title
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            Color.clear  // Empty space to balance layout
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
                Image(systemName: "magnifyingglass") // Search icon
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .font(.system(size: 16))
                
                TextField("Search", text: $searchText) // Text field for search
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit { performSearch() }
                
                if !searchText.isEmpty { // Clear button
                    Button(action: {
                        searchText = ""
                        searchResults = []
                        searchError = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08),
                radius: 4, x: 0, y: 2
            )
            
            // Barcode scanner button
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
            ProgressView() // Loading spinner
                .padding(.top, 40)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle") // Error icon
                .font(.system(size: 50))
                .foregroundColor(.red)
                .padding(.top, 40)
            Text("Search Error")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { performSearch() }
                .buttonStyle(.borderedProminent)
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
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
            Text("Enter an item name, ID, or scan a barcode")
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
                    item: binding(for: item),      // Bind item for updates
                    onBookmarkToggle: { toggleBookmark(for: item) },
                    onTap: {                        // Open detail view
                        selectedItem = item
                        showingDetail = true
                    }
                )
            }
        }
    }
    
    // MARK: - Search Logic
    
    private func performSearch() {
        guard !searchText.trimmedIsEmpty else { // Skip empty search
            searchResults = []
            return
        }
        Task { await executeSearch() }           // Perform async search
    }
    
    private func executeSearch() async {
        isSearching = true
        searchError = nil
        
        do {
            let allItems = try await supabaseManager.fetchAllItems() // Fetch all items
            let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            let filtered = allItems.filter { item in
                item.name.lowercased().contains(query) ||
                item.itemId.lowercased().contains(query) ||
                item.category.lowercased().contains(query)
            }
            
            _ = await MainActor.run { searchResults = filtered } // Update UI
        } catch {
            _ = await MainActor.run { searchError = error.localizedDescription }
        }
        
        isSearching = false
    }
    
    // MARK: - Data Operations
    
    private func updateItem(_ item: InventoryItem) async {
        do {
            try await supabaseManager.updateItem(item)
            _ = await MainActor.run {
                if let index = searchResults.firstIndex(where: { $0.id == item.id }) {
                    searchResults[index] = item
                }
            }
        } catch {
            print("Error updating item:", error)
            searchError = "Failed to update item: \(error.localizedDescription)"
        }
    }
    
    private func toggleBookmark(for item: InventoryItem) {
        guard let index = searchResults.firstIndex(where: { $0.id == item.id }) else { return }
        
        if bookmarkInFlight.contains(item.id) { return }
        bookmarkInFlight.insert(item.id)
        
        let oldState = searchResults[index].isBookmarked
        let newState = !oldState
        searchResults[index].isBookmarked = newState
        
        if showingDetail, selectedItem?.id == item.id { selectedItem = searchResults[index] }
        
        Task {
            do { try await supabaseManager.toggleBookmark(item.id, isBookmarked: newState) }
            catch {
                _ = await MainActor.run {
                    if let idx = searchResults.firstIndex(where: { $0.id == item.id }) {
                        searchResults[idx].isBookmarked = oldState
                        if showingDetail, selectedItem?.id == item.id { selectedItem = searchResults[idx] }
                    }
                }
            }
            _ = await MainActor.run { bookmarkInFlight.remove(item.id) }
        }
    }
    
    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = searchResults.firstIndex(where: { $0.id == item.id }) else { return .constant(item) }
        return $searchResults[index] // Bind for updates in InventoryCard
    }
}

// MARK: - String Extension

extension String {
    var trimmedIsEmpty: Bool { self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

// MARK: - Preview

struct ItemLookupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ItemLookupView()
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            ItemLookupView()
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }
}
