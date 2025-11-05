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
struct InventoryItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let category: String
    let imageName: String   // For icons: SF Symbol name. For photos: public URL string.
    let itemId: String
    let notes: String?
    let history: [HistoryEntry]
    var isBookmarked: Bool = false
}

struct HistoryEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// MARK: - InventoryView
struct InventoryView: View {
    @State private var selectedCategory = "Merchandise"
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?
    @State private var showingDetail = false
    @State private var showingAddItem = false
    @State private var bookmarkedItems: Set<UUID> = []
    
    let categories = ["Merchandise", "Decorations", "Banners"]
    
    // Sample inventory data
    @State private var inventoryItems = [
        InventoryItem(
            name: "Gray Crewneck",
            quantity: 200,
            category: "Merchandise",
            imageName: "tshirt",
            itemId: "MERC-001",
            notes: nil,
            history: [
                HistoryEntry(label: "Date Received", value: "September 15, 2025"),
                HistoryEntry(label: "Logged By", value: "Amy Portillo"),
                HistoryEntry(label: "Last Updated", value: "October 15, 2025, 1:50 PM")
            ]
        ),
        InventoryItem(
            name: "Blue Mug",
            quantity: 40,
            category: "Merchandise",
            imageName: "mug",
            itemId: "MERC-002",
            notes: nil,
            history: [
                HistoryEntry(label: "Date Received", value: "August 10, 2025"),
                HistoryEntry(label: "Logged By", value: "John Smith"),
                HistoryEntry(label: "Last Updated", value: "October 15, 2025, 3:49 PM")
            ]
        ),
        InventoryItem(
            name: "Black Hoodie",
            quantity: 500,
            category: "Merchandise",
            imageName: "hoodie",
            itemId: "MERC-003",
            notes: "Delivered to Jared for Marketing Event #12",
            history: [
                HistoryEntry(label: "Date Received", value: "September 25, 2025"),
                HistoryEntry(label: "Logged By", value: "Amy Portillo"),
                HistoryEntry(label: "Given To", value: "Jared Eldridge"),
                HistoryEntry(label: "Date Given", value: "October 17, 2025"),
                HistoryEntry(label: "Time Given", value: "10:32 AM"),
                HistoryEntry(label: "Last Updated", value: "October 17, 2025, 10:32 AM")
            ],
            isBookmarked: true
        ),
        InventoryItem(
            name: "Gray Beanie",
            quantity: 100,
            category: "Merchandise",
            imageName: "beanie",
            itemId: "MERC-004",
            notes: nil,
            history: [
                HistoryEntry(label: "Date Received", value: "October 1, 2025"),
                HistoryEntry(label: "Logged By", value: "Sarah Johnson"),
                HistoryEntry(label: "Last Updated", value: "October 10, 2025, 2:15 PM")
            ]
        ),
        InventoryItem(
            name: "Blue Backpack",
            quantity: 25,
            category: "Merchandise",
            imageName: "backpack",
            itemId: "MERC-005",
            notes: nil,
            history: [
                HistoryEntry(label: "Date Received", value: "September 5, 2025"),
                HistoryEntry(label: "Logged By", value: "Amy Portillo"),
                HistoryEntry(label: "Last Updated", value: "October 5, 2025, 9:20 AM")
            ]
        ),
        InventoryItem(
            name: "Banner Stand",
            quantity: 15,
            category: "Banners",
            imageName: "flag",
            itemId: "BANN-001",
            notes: nil,
            history: [
                HistoryEntry(label: "Date Received", value: "July 12, 2025"),
                HistoryEntry(label: "Logged By", value: "Mike Davis"),
                HistoryEntry(label: "Last Updated", value: "September 20, 2025, 11:45 AM")
            ]
        ),
        InventoryItem(
            name: "Table Runner",
            quantity: 30,
            category: "Decorations",
            imageName: "tablecloth",
            itemId: "DECO-001",
            notes: nil,
            history: [
                HistoryEntry(label: "Date Received", value: "August 20, 2025"),
                HistoryEntry(label: "Logged By", value: "Emily Brown"),
                HistoryEntry(label: "Last Updated", value: "October 1, 2025, 3:30 PM")
            ]
        )
    ]
    
    var filteredItems: [InventoryItem] {
        inventoryItems.filter { item in
            let matchesCategory = item.category == selectedCategory
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    // Match DashboardView’s adaptive shadow color
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.06)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            // Category Filter
                            categoryFilter
                            
                            // Search Bar
                            searchBar
                            
                            // Inventory Cards
                            inventoryCards
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationBarHidden(true)
            .overlay {
                if showingDetail, let item = selectedItem {
                    ItemDetailOverlay(
                        item: binding(for: item),
                        isPresented: $showingDetail
                    )
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(
                    isPresented: $showingAddItem,
                    onAddItem: { newItem in
                        inventoryItems.append(newItem)
                    }
                )
            }
            .animation(.easeInOut(duration: 0.25), value: showingDetail)
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
        HStack(alignment: .center, spacing: 30) {
            Image(.image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .foregroundColor(.white)
                .background(Circle().fill(Color(UIColor.systemBlue)))
                .clipShape(Circle())
                .shadow(color: shadowColor, radius: 2, x: 0, y: 2)
            
            Text("Marketing Inventory")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
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
                            // Background with dynamic color
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selectedCategory == category
                                      ? Color.brandNavy
                                      : Color(UIColor.secondarySystemBackground))
                            
                            // Subtle stroke for edge contrast
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color(UIColor.separator).opacity(0.25), lineWidth: 1)
                            
                            // Label
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedCategory == category ? .white : Color(UIColor.label))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        // Stronger, more visible shadow
                        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.12),
                                radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal, 2) // give shadows a bit of breathing room
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(UIColor.secondaryLabel))
                
                TextField("Search inventory", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            
            Button(action: {
                showingAddItem = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.brandNavy)
            }
        }
    }
    
    // MARK: - Inventory Cards
    private var inventoryCards: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredItems) { item in
                InventoryCard(
                    item: item,
                    isBookmarked: item.isBookmarked,
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
    
    private func toggleBookmark(for item: InventoryItem) {
        if let index = inventoryItems.firstIndex(where: { $0.id == item.id }) {
            inventoryItems[index].isBookmarked.toggle()
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
    let item: InventoryItem
    let isBookmarked: Bool
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
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                Spacer()
                
                // Bookmark Button
                Button(action: onBookmarkToggle) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(isBookmarked ? .brandNavy : Color(UIColor.secondaryLabel))
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Dimmed background - tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Card content
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
                                    .foregroundColor(.brandNavy)
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
                        Text("History:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(item.history.enumerated()), id: \.element.id) { index, entry in
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
                                
                                if index != item.history.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    // Bookmark Button
                    Button(action: {
                        item.isBookmarked.toggle()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                            Text(item.isBookmarked ? "Bookmarked" : "Bookmark Item")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(item.isBookmarked ? Color.brandNavy : Color(UIColor.secondarySystemBackground))
                        .foregroundColor(item.isBookmarked ? .white : Color(UIColor.label))
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
    }
}

// MARK: - Item Detail View
struct ItemDetailView: View {
    @Binding var item: InventoryItem
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                    .padding(.vertical, 12)
                    
                    // Item Name and Quantity
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("Quantity:")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            Text("\(item.quantity) pc")
                                .font(.headline)
                                .foregroundColor(.brandNavy)
                        }
                        
                        HStack {
                            Text("Category:")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                            Text(item.category)
                                .font(.headline)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
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
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    
                    // History Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("History:")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(item.history.enumerated()), id: \.element.id) { index, entry in
                                HStack(alignment: .top) {
                                    Text("• \(entry.label):")
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                        .frame(width: 120, alignment: .leading)
                                    
                                    Text(entry.value)
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.label))
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal)
                                
                                if index != item.history.count - 1 {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        item.isBookmarked.toggle()
                    }) {
                        Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.brandNavy)
                    }
                }
            }
        }
    }
}

// MARK: - Supabase upload helper
private func uploadImageToSupabase(_ image: UIImage) async throws -> URL {
    // Configure as needed
    let bucket = "item-images" // TODO: ensure this bucket exists in your Supabase project
    let filename = UUID().uuidString + ".jpg"
    let path = "items/\(filename)"
    
    guard let data = image.jpegData(compressionQuality: 0.85) else {
        throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "JPEG encoding failed"])
    }
    
    // Upload
    _ = try await supabase.storage
        .from(bucket)
        .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
    
    // Build a public URL (bucket must be public). For private buckets, generate a signed URL instead.
    let publicURL = try supabase.storage.from(bucket).getPublicURL(path: path)
    return publicURL
}

// MARK: - Add Item View (with photo picker)
struct AddItemView: View {
    @Binding var isPresented: Bool
    let onAddItem: (InventoryItem) -> Void
    
    @State private var itemName = ""
    @State private var itemId = ""
    @State private var quantity = ""
    @State private var selectedCategory = "Merchandise"
    @State private var selectedIcon = "tshirt"
    @State private var notes = ""
    
    // Photo picker state
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    // Will store the uploaded image’s public URL string from Supabase
    @State private var uploadedImageURLString: String? = nil
    
    let categories = ["Merchandise", "Decorations", "Banners"]
    let iconOptions = ["tshirt", "hoodie", "mug", "backpack", "beanie", "flag", "tablecloth", "photo"]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $itemName)
                    TextField("Item ID", text: $itemId)
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
                
                Section(header: Text("Item Image")) {
                    // Preview: either user-picked photo, or selected icon
                    HStack {
                        if let uiImage = pickedImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipped()
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brandNavy, lineWidth: 1))
                            
                            VStack(alignment: .leading) {
                                Text("Custom photo selected")
                                    .font(.subheadline)
                                Button("Remove Photo") {
                                    pickedImage = nil
                                    uploadedImageURLString = nil
                                }
                                .font(.caption)
                            }
                        } else {
                            Image(systemName: selectedIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .padding(12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                            
                            Text("No custom photo — using icon")
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        // PhotosPicker button
                        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                Text("Pick Photo")
                                    .font(.caption)
                            }
                            .padding(8)
                        }
                        .onChange(of: photoItem) { _, newItem in
                            guard let newItem else { // cleared selection
                                Task { @MainActor in
                                    pickedImage = nil
                                    uploadedImageURLString = nil
                                }
                                return
                            }
                            Task {
                                // Load image data locally for preview
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    await MainActor.run { self.pickedImage = uiImage }
                                    // Upload to Supabase
                                    do {
                                        let url = try await uploadImageToSupabase(uiImage)
                                        await MainActor.run {
                                            self.uploadedImageURLString = url.absoluteString
                                        }
                                    } catch {
                                        print("Supabase upload failed:", error)
                                        await MainActor.run {
                                            self.uploadedImageURLString = nil
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        self.pickedImage = nil
                                        self.uploadedImageURLString = nil
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Icon horizontal selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                    // Clear any photo selection
                                    pickedImage = nil
                                    uploadedImageURLString = nil
                                }) {
                                    VStack {
                                        Image(systemName: icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40, height: 40)
                                            .padding(12)
                                            .background(
                                                selectedIcon == icon && pickedImage == nil
                                                    ? Color.brandNavy.opacity(0.2)
                                                    : Color(UIColor.systemGray6)
                                            )
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        (selectedIcon == icon && pickedImage == nil) ? Color.brandNavy : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Text("You can pick a photo or choose an icon. Picked photos are uploaded to Supabase.")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
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
                    .disabled(itemName.isEmpty || itemId.isEmpty || quantity.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addItem() {
        guard let qty = Int(quantity) else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())
        
        // Prefer uploaded URL; otherwise use the chosen SF Symbol icon.
        let imageIdentifier = uploadedImageURLString ?? selectedIcon
        
        let newItem = InventoryItem(
            name: itemName,
            quantity: qty,
            category: selectedCategory,
            imageName: imageIdentifier,
            itemId: itemId,
            notes: notes.isEmpty ? nil : notes,
            history: [
                HistoryEntry(label: "Date Received", value: currentDate),
                HistoryEntry(label: "Logged By", value: "Current User"),
                HistoryEntry(label: "Last Updated", value: "\(currentDate), \(currentTime)")
            ]
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

