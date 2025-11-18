//
//  AddItemView.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI
import PhotosUI

struct AddItemView: View {
    @Binding var isPresented: Bool
    let onAddItem: (InventoryItem) -> Void
    
    @State private var itemName = ""
    @State private var itemId = ""
    @State private var quantity = ""
    @State private var selectedCategory = "Merchandise"
    @State private var notes = ""
    
    @State private var loggedBy = "Amy Portillo" // need update to match user
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
                    
                    TextField("Item ID", text: $itemId)
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
