//
//  RestockView.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI

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
