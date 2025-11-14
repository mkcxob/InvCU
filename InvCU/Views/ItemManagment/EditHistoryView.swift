//
//  EditHistoryView.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI

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
