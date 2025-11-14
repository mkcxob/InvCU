//
//  RecordTransferView.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI

struct RecordTransferView: View {
    @Binding var item: InventoryItem
    @Binding var isPresented: Bool
    let onSave: () -> Void
    
    @State private var loggedBy = "Amy Portillo"
    @State private var givenTo = ""
    @State private var itemGiven = ""
    @State private var quantityGiven = ""
    @State private var transferNotes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transfer Details")) {
                    TextField("Logged By", text: $loggedBy)
                        .disabled(isSaving)
                    TextField("Given To", text: $givenTo)
                        .disabled(isSaving)
                    TextField("Item Given", text: $itemGiven)
                        .disabled(isSaving)
                    TextField("Quantity Given", text: $quantityGiven)
                        .keyboardType(.numberPad)
                        .disabled(isSaving)
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $transferNotes)
                        .frame(height: 80)
                        .disabled(isSaving)
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
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
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
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await recordTransfer()
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Record")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(loggedBy.isEmpty || givenTo.isEmpty || itemGiven.isEmpty || quantityGiven.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func recordTransfer() async {
        guard let qty = Int(quantityGiven), qty > 0 else { return }
        
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())
        
        // Update local item
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
        
        // Save to database (non-throwing in current design)
        onSave() // This triggers the updateItem() call in InventoryView
        
        await MainActor.run {
            isSaving = false
            isPresented = false
        }
    }
}
