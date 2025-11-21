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
    
    @State private var bookmarkInFlight: Set<UUID> = []
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Computed Properties
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
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
                        .padding(.vertical, 16)
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
                    searchText = barcode
                    performSearch()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showingDetail)
        }
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
                    .font(.system(size: 16))
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
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
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
    
    // MARK: - Search Logic
    
    /// Validates search text and initiates search
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        Task { await executeSearch() }
    }
    
    /// Fetches all items and filters by search query
    /// Searches across item name, ID, and category
    private func executeSearch() async {
        isSearching = true
        searchError = nil
        
        do {
            let allItems = try await supabaseManager.fetchAllItems()
            let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            let filtered = allItems.filter { item in
                item.name.lowercased().contains(query) ||
                item.itemId.lowercased().contains(query) ||
                item.category.lowercased().contains(query)
            }
            
            _ = await MainActor.run { searchResults = filtered }
        } catch {
            _ = await MainActor.run { searchError = error.localizedDescription }
        }
        
        isSearching = false
    }
    
    // MARK: - Data Operations
    
    /// Updates item in database and refreshes search results
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
    
    /// Toggles bookmark state with optimistic UI update
    /// Reverts to previous state if database operation fails
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
    
    /// Creates a binding for an item to allow two-way data flow in child views
    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = searchResults.firstIndex(where: { $0.id == item.id }) else { return .constant(item) }
        return $searchResults[index]
    }
}

// MARK: - Preview

struct ItemLookupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ItemLookupView(isAuthenticated: .constant(true))
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            ItemLookupView(isAuthenticated: .constant(true))
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }
}
