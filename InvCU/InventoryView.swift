//
//  InventoryView.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI
import PhotosUI
import Storage
import Supabase

// MARK: - Models
struct InventoryItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var quantity: Int
    var category: String
    var imageName: String   // For photos: public URL string.
    var itemId: String
    var notes: String?
    var history: [HistoryEntry]
    var isBookmarked: Bool = false
    
    static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct HistoryEntry: Identifiable, Equatable {
    let id: UUID
    var label: String
    var value: String
    
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - InventoryView
struct InventoryView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    @State private var selectedCategory = "Merchandise"
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?
    @State private var showingDetail = false
    @State private var showingAddItem = false
    
    @State private var inventoryItems: [InventoryItem] = []
    @State private var isLoading = false
    @State private var loadError: String?
    
    let categories = ["Merchandise", "Decorations", "Banners"]
    
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
                            Task { await loadItems() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header
                        header
                        
                        ScrollView {
                            VStack(spacing: 16) {
                                // Category Filter
                                categoryFilter
                                
                                // Inventory Cards
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
                await loadItems()
            }
            .refreshable {
                await loadItems()
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
    private func loadItems() async {
        isLoading = true
        loadError = nil
        
        do {
            inventoryItems = try await supabaseManager.fetchAllItems()
        } catch {
            loadError = error.localizedDescription
            print(" Error loading items:", error)
        }
        
        isLoading = false
    }
    
    private func addItem(_ item: InventoryItem) async {
        do {
            let addedItem = try await supabaseManager.addItem(item)
            await MainActor.run {
                inventoryItems.append(addedItem)
            }
        } catch {
            print("Error adding item:", error)
            // Show error to user
            loadError = "Failed to add item: \(error.localizedDescription)"
        }
    }
    
    private func updateItem(_ item: InventoryItem) async {
        do {
            try await supabaseManager.updateItem(item)
            await MainActor.run {
                if let index = inventoryItems.firstIndex(where: { $0.id == item.id }) {
                    inventoryItems[index] = item
                }
            }
        } catch {
            print(" Error updating item:", error)
            loadError = "Failed to update item: \(error.localizedDescription)"
        }
    }
    
    private func toggleBookmark(for item: InventoryItem) {
        Task {
            if let index = inventoryItems.firstIndex(where: { $0.id == item.id }) {
                let newBookmarkState = !inventoryItems[index].isBookmarked
                
                // Optimistic update
                await MainActor.run {
                    inventoryItems[index].isBookmarked = newBookmarkState
                }
                
                do {
                    try await supabaseManager.toggleBookmark(item.id, isBookmarked: newBookmarkState)
                } catch {
                    // Revert on error
                    await MainActor.run {
                        inventoryItems[index].isBookmarked = !newBookmarkState
                    }
                    print("Error toggling bookmark:", error)
                }
            }
        }
    }
    
    // Helper to get binding for an item
    private func binding(for item: InventoryItem) -> Binding<InventoryItem> {
        guard let index = inventoryItems.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $inventoryItems[index]
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 6) {
            // Left image
            Image(.image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color(UIColor.systemBlue)))
                .clipShape(Circle())
                .shadow(color: shadowColor, radius: 2, x: 0, y: 2)

            Spacer()

            // Center title
            Text("Marketing Inventory")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .offset(x: -4)

            Spacer()

            // Right add button
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
                        selectedItem = item
                        showingDetail = true
                    }
                )
            }
        }
    }
}

// MARK: - Helpers to render image/icon
private extension InventoryItem {
    var isURLImage: Bool {
        imageName.lowercased().hasPrefix("http://") || imageName.lowercased().hasPrefix("https://")
    }
}

// MARK: - Inventory Card
struct InventoryCard: View {
    @Binding var item: InventoryItem
    let onBookmarkToggle: () -> Void
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Item Image or Remote Photo
                Group {
                    if item.isURLImage, let url = URL(string: item.imageName) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 60, height: 60)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipped()
                            case .failure:
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .padding(12)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    } else {
                        Image(systemName: item.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .padding(12)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                    }
                }
                
                // Item Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                    
                    Text("Quantity: \(item.quantity) pc")
                        .font(.system(size: 15))
                        .foregroundColor(item.quantity < 50 ? Color(UIColor.systemRed) : Color(UIColor.secondaryLabel))
                }
                
                Spacer()
                
                // Bookmark Button
                Button(action: onBookmarkToggle) {
                    Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(item.isBookmarked ? .brandNavy : Color(UIColor.secondaryLabel))
                        .frame(width: 30)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Item Detail Overlay (Card Style)
struct ItemDetailOverlay: View {
    @Binding var item: InventoryItem
    @Binding var isPresented: Bool
    let onUpdate: (InventoryItem) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditHistory = false
    @State private var showingRecordTransfer = false
    @State private var showingRestock = false
    
    // Helper to group history by transfers
    private var groupedHistory: [[HistoryEntry]] {
        var groups: [[HistoryEntry]] = []
        var currentGroup: [HistoryEntry] = []
        
        for entry in item.history {
            currentGroup.append(entry)
            
            if entry.label == "Last Updated" {
                groups.append(currentGroup)
                currentGroup = []
            }
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Close button at top
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                    }
                    .padding(.top, 8)
                    
                    // Item Image
                    HStack {
                        Spacer()
                        Group {
                            if item.isURLImage, let url = URL(string: item.imageName) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 120, height: 120)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipped()
                                    case .failure:
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 120, height: 120)
                                            .padding(24)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(16)
                            } else {
                                Image(systemName: item.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 120)
                                    .padding(24)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(16)
                            }
                        }
                        Spacer()
                    }
                    
                    // Item Name and Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Item ID:")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                Text(item.itemId)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Quantity:")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                Text("\(item.quantity) pc")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(item.quantity < 50 ? Color(UIColor.systemRed) : .brandNavy)
                            }
                            
                            HStack {
                                Text("Category:")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                Text(item.category)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Notes Section
                    if let notes = item.notes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(notes)
                                .font(.body)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        Divider()
                    }
                    
                    // History Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("History:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: {
                                showingEditHistory = true
                            }) {
                                Text("Edit History")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        VStack(spacing: 0) {
                            ForEach(Array(groupedHistory.enumerated()), id: \.offset) { groupIndex, group in
                                VStack(spacing: 0) {
                                    ForEach(Array(group.enumerated()), id: \.element.id) { entryIndex, entry in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                            
                                            Text("\(entry.label):")
                                                .font(.subheadline)
                                                .foregroundColor(Color(UIColor.secondaryLabel))
                                            
                                            Spacer()
                                            
                                            Text(entry.value)
                                                .font(.subheadline)
                                                .foregroundColor(Color(UIColor.label))
                                                .multilineTextAlignment(.trailing)
                                        }
                                        .padding(.vertical, 6)
                                        
                                        if entryIndex != group.count - 1 {
                                            Divider()
                                        }
                                    }
                                }
                                
                                if groupIndex != groupedHistory.count - 1 {
                                    Rectangle()
                                        .fill(Color(UIColor.separator))
                                        .frame(height: 2)
                                        .padding(.vertical, 12)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Quick Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            showingRecordTransfer = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Give Items")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(Color.brandNavy)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingRestock = true
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                Text("Restock")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(Color(red: 255/255, green: 202/255, blue: 0/255))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Bookmark Button
                    Button(action: {
                        item.isBookmarked.toggle()
                        onUpdate(item)
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                            Text(item.isBookmarked ? "Bookmarked" : "Bookmark Item")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(item.isBookmarked ? Color.brandNavy.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(item.isBookmarked ? Color.brandNavy : Color(UIColor.label))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(24)
            }
            .frame(maxWidth: 500)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.2),
                radius: 20,
                x: 0,
                y: 10
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 60)
        }
        .sheet(isPresented: $showingEditHistory) {
            EditHistoryView(history: $item.history, onSave: {
                onUpdate(item)
            })
        }
        .sheet(isPresented: $showingRecordTransfer) {
            RecordTransferView(item: $item, isPresented: $showingRecordTransfer, onSave: {
                onUpdate(item)
            })
        }
        .sheet(isPresented: $showingRestock) {
            RestockView(item: $item, isPresented: $showingRestock, onSave: {
                onUpdate(item)
            })
        }
    }
}

// MARK: - EditHistoryView
struct EditHistoryView: View {
    @Binding var history: [HistoryEntry]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newLabel: String = ""
    @State private var addCustomLabel = false
    
    private let commonLabels = ["Date Received", "Logged By", "Given To", "Date Given", "Time Given", "Last Updated", "Notes"]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Entries")) {
                    ForEach($history) { $entry in
                        HStack {
                            Text(entry.label)
                                .foregroundColor(.secondary)
                                .frame(minWidth: 110, alignment: .leading)
                            
                            TextField("Value", text: $entry.value)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete { indices in
                        history.remove(atOffsets: indices)
                    }
                    .onMove { indices, newOffset in
                        history.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                
                Section(header: Text("Add Entry")) {
                    if addCustomLabel {
                        HStack {
                            TextField("Label", text: $newLabel)
                            Button("Add") {
                                let labelToUse = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !labelToUse.isEmpty else { return }
                                history.append(HistoryEntry(id: UUID(), label: labelToUse, value: ""))
                                newLabel = ""
                                addCustomLabel = false
                            }
                            .disabled(newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(commonLabels, id: \.self) { label in
                                    Button(action: {
                                        history.append(HistoryEntry(id: UUID(), label: label, value: ""))
                                    }) {
                                        Text(label)
                                            .padding(8)
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                                
                                Button(action: {
                                    addCustomLabel = true
                                    newLabel = ""
                                }) {
                                    Image(systemName: "plus")
                                        .padding(8)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Edit History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        EditButton()
                        Button("Done") {
                            onSave()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

// MARK: - Record Transfer View
struct RecordTransferView: View {
    @Binding var item: InventoryItem
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    @State private var loggedBy = "Amy Portillo"
    @State private var givenTo = ""
    @State private var itemGiven = ""
    @State private var quantityGiven = ""
    @State private var transferNotes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transfer Details")) {
                    TextField("Logged By", text: $loggedBy)
                    TextField("Given To", text: $givenTo)
                    TextField("Item Given", text: $itemGiven)
                    TextField("Quantity Given", text: $quantityGiven)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $transferNotes)
                        .frame(height: 80)
                }
                
                Section {
                    HStack {
                        Text("Current Quantity:")
                        Spacer()
                        Text("\(item.quantity) pc")
                            .fontWeight(.semibold)
                    }
                    
                    if let qty = Int(quantityGiven), qty > 0 {
                        HStack {
                            Text("New Quantity:")
                            Spacer()
                            Text("\(max(0, item.quantity - qty)) pc")
                                .fontWeight(.semibold)
                                .foregroundColor(qty > item.quantity ? .red : .brandNavy)
                        }
                        
                        if qty > item.quantity {
                            Text("Quantity exceeds current stock")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Give Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Record") {
                        recordTransfer()
                    }
                    .disabled(loggedBy.isEmpty || givenTo.isEmpty || itemGiven.isEmpty || quantityGiven.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func recordTransfer() {
        guard let qty = Int(quantityGiven), qty > 0 else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())
        
        item.quantity = max(0, item.quantity - qty)
        
        var newHistory = item.history
        newHistory.append(HistoryEntry(id: UUID(), label: "Logged By", value: loggedBy))
        newHistory.append(HistoryEntry(id: UUID(), label: "Given To", value: givenTo))
        newHistory.append(HistoryEntry(id: UUID(), label: "Item Given", value: itemGiven))
        newHistory.append(HistoryEntry(id: UUID(), label: "Quantity Given", value: "\(qty) pc"))
        newHistory.append(HistoryEntry(id: UUID(), label: "Date Given", value: currentDate))
        newHistory.append(HistoryEntry(id: UUID(), label: "Time Given", value: currentTime))
        
        if !transferNotes.isEmpty {
            newHistory.append(HistoryEntry(id: UUID(), label: "Notes", value: transferNotes))
        }
        
        newHistory.append(HistoryEntry(id: UUID(), label: "Last Updated", value: "\(currentDate), \(currentTime)"))
        
        item.history = newHistory
        
        let noteText = "Delivered to \(givenTo)"
        if let existingNotes = item.notes {
            item.notes = existingNotes + "\n" + noteText
        } else {
            item.notes = noteText
        }
        
        onSave()
        isPresented = false
    }
}

// MARK: - Restock View
struct RestockView: View {
    @Binding var item: InventoryItem
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    @State private var quantityToAdd = ""
    @State private var restockNotes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Restock Details")) {
                    TextField("Quantity to Add", text: $quantityToAdd)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $restockNotes)
                        .frame(height: 80)
                }
                
                Section {
                    HStack {
                        Text("Current Quantity:")
                        Spacer()
                        Text("\(item.quantity) pc")
                            .fontWeight(.semibold)
                    }
                    
                    if let qty = Int(quantityToAdd), qty > 0 {
                        HStack {
                            Text("New Quantity:")
                            Spacer()
                            Text("\(item.quantity + qty) pc")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Restock Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        recordRestock()
                    }
                    .disabled(quantityToAdd.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func recordRestock() {
        guard let qty = Int(quantityToAdd), qty > 0 else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())
        
        item.quantity += qty
        
        var newHistory = item.history
        newHistory.append(HistoryEntry(id: UUID(), label: "Restocked", value: "\(qty) pc"))
        newHistory.append(HistoryEntry(id: UUID(), label: "Restock Date", value: currentDate))
        newHistory.append(HistoryEntry(id: UUID(), label: "Logged By", value: "Amy Portillo"))
        
        if !restockNotes.isEmpty {
            newHistory.append(HistoryEntry(id: UUID(), label: "Restock Notes", value: restockNotes))
        }
        
        newHistory.append(HistoryEntry(id: UUID(), label: "Last Updated", value: "\(currentDate), \(currentTime)"))
        
        item.history = newHistory
        
        onSave()
        isPresented = false
    }
}

// MARK: - Add Item View
struct AddItemView: View {
    @Binding var isPresented: Bool
    let onAddItem: (InventoryItem) -> Void
    
    @State private var itemName = ""
    @State private var itemId = ""
    @State private var quantity = ""
    @State private var selectedCategory = "Merchandise"
    @State private var notes = ""
    
    @State private var loggedBy = "Amy Portillo"
    @State private var dateReceived = Date()
    @State private var givenTo = ""
    @State private var itemGiven = ""
    @State private var quantityGiven = ""
    @State private var dateGiven = Date()
    @State private var timeGiven = Date()
    @State private var historyNotes = ""
    
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var uploadedImageURLString: String? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    
    let categories = ["Merchandise", "Decorations", "Banners"]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $itemName)
                        .autocapitalization(.words)
                    
                    TextField("Item ID (e.g., MERC-001)", text: $itemId)
                        .autocapitalization(.allCharacters)
                    
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Item Photo (Required)")) {
                    if isUploading {
                        HStack {
                            ProgressView()
                            Text("Uploading photo...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let uiImage = pickedImage {
                        VStack(spacing: 12) {
                            HStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Spacer()
                                
                                VStack(spacing: 8) {
                                    if uploadedImageURLString != nil {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Uploaded")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    } else if uploadError != nil {
                                        HStack {
                                            Image(systemName: "exclamationmark.circle.fill")
                                                .foregroundColor(.red)
                                            Text("Failed")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    
                                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                                        Text("Change Photo")
                                            .font(.subheadline)
                                            .foregroundColor(.brandNavy)
                                    }
                                    
                                    Button("Remove Photo") {
                                        pickedImage = nil
                                        uploadedImageURLString = nil
                                        photoItem = nil
                                        uploadError = nil
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                }
                            }
                            
                            if let error = uploadError {
                                Text("Upload failed: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.title2)
                                        .foregroundColor(.brandNavy)
                                    Text("Select Photo")
                                        .foregroundColor(.brandNavy)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color(UIColor.tertiaryLabel))
                                }
                                .padding(.vertical, 8)
                            }
                            
                            Text("Photo is required to add an item")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .onChange(of: photoItem) { _, newItem in
                    guard let newItem else {
                        Task { @MainActor in
                            pickedImage = nil
                            uploadedImageURLString = nil
                            uploadError = nil
                        }
                        return
                    }
                    Task {
                        await MainActor.run {
                            isUploading = true
                            uploadError = nil
                        }
                        
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run { self.pickedImage = uiImage }
                            do {
                                let url = try await SupabaseManager.shared.uploadImage(uiImage)
                                await MainActor.run {
                                    self.uploadedImageURLString = url
                                    self.isUploading = false
                                    self.uploadError = nil
                                }
                            } catch {
                                print("Supabase upload failed:", error)
                                await MainActor.run {
                                    self.uploadedImageURLString = nil
                                    self.isUploading = false
                                    self.uploadError = error.localizedDescription
                                }
                            }
                        } else {
                            await MainActor.run {
                                self.pickedImage = nil
                                self.uploadedImageURLString = nil
                                self.isUploading = false
                                self.uploadError = "Could not load image"
                            }
                        }
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
                
                Section(header: Text("Initial History")) {
                    TextField("Logged By", text: $loggedBy)
                    DatePicker("Date Received", selection: $dateReceived, displayedComponents: .date)
                }
                
                Section(header: Text("Transfer History (Optional)")) {
                    TextField("Given To", text: $givenTo)
                    TextField("Item Given", text: $itemGiven)
                    TextField("Quantity Given", text: $quantityGiven)
                        .keyboardType(.numberPad)
                    
                    if !givenTo.isEmpty {
                        DatePicker("Date Given", selection: $dateGiven, displayedComponents: .date)
                        DatePicker("Time Given", selection: $timeGiven, displayedComponents: .hourAndMinute)
                    }
                    
                    TextEditor(text: $historyNotes)
                        .frame(height: 60)
                }
            }
            .navigationTitle("Add New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(!canAddItem)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var canAddItem: Bool {
        return !itemName.isEmpty &&
               !itemId.isEmpty &&
               !quantity.isEmpty &&
               uploadedImageURLString != nil &&
               !isUploading
    }
    
    private func addItem() {
        guard let qty = Int(quantity), let imageURL = uploadedImageURLString else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let receivedDateString = dateFormatter.string(from: dateReceived)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())
        let currentDate = dateFormatter.string(from: Date())
        
        var finalHistory: [HistoryEntry] = []
        
        finalHistory.append(HistoryEntry(id: UUID(), label: "Date Received", value: receivedDateString))
        finalHistory.append(HistoryEntry(id: UUID(), label: "Logged By", value: loggedBy))
        
        if !givenTo.isEmpty {
            finalHistory.append(HistoryEntry(id: UUID(), label: "Given To", value: givenTo))
            
            if !itemGiven.isEmpty {
                finalHistory.append(HistoryEntry(id: UUID(), label: "Item Given", value: itemGiven))
            }
            
            if let qtyGiven = Int(quantityGiven), qtyGiven > 0 {
                finalHistory.append(HistoryEntry(id: UUID(), label: "Quantity Given", value: "\(qtyGiven) pc"))
            }
            
            let givenDateString = dateFormatter.string(from: dateGiven)
            finalHistory.append(HistoryEntry(id: UUID(), label: "Date Given", value: givenDateString))
            
            let givenTimeString = timeFormatter.string(from: timeGiven)
            finalHistory.append(HistoryEntry(id: UUID(), label: "Time Given", value: givenTimeString))
            
            if !historyNotes.isEmpty {
                finalHistory.append(HistoryEntry(id: UUID(), label: "Notes", value: historyNotes))
            }
        }
        
        finalHistory.append(HistoryEntry(id: UUID(), label: "Last Updated", value: "\(currentDate), \(currentTime)"))
        
        let newItem = InventoryItem(
            id: UUID(),
            name: itemName,
            quantity: qty,
            category: selectedCategory,
            imageName: imageURL,
            itemId: itemId,
            notes: notes.isEmpty ? nil : notes,
            history: finalHistory
        )
        
        onAddItem(newItem)
        isPresented = false
    }
}

// MARK: - Preview
struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InventoryView()
                .previewDisplayName("Light")
                .preferredColorScheme(.light)
            
            InventoryView()
                .previewDisplayName("Dark")
                .preferredColorScheme(.dark)
        }
    }
}
