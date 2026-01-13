//
//  ItemDetailOverlay.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI

struct ItemDetailOverlay: View {
    @Binding var item: InventoryItem
    @Binding var isPresented: Bool
    let onUpdate: (InventoryItem) -> Void
    let onBookmarkToggle: (InventoryItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditHistory = false
    @State private var showingRecordTransfer = false
    @State private var showingRestock = false

    // Local state to force UI refresh
    @State private var localBookmarkState:  Bool = false

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
                            Image(systemName:  "xmark. circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                    }
                    .padding(.top, 8)

                    // Item Image - USES CACHED UIIMAGE DIRECTLY FOR INSTANT LOADING
                    HStack {
                        Spacer()
                        Group {
                            if item.isURLImage {
                                if let cachedImage = item.cachedUIImage {
                                    // Show cached image INSTANTLY - NO DELAY
                                    Image(uiImage: cachedImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height:  120)
                                        .clipped()
                                        .cornerRadius(16)
                                } else {
                                    // Fallback if somehow not cached
                                    ZStack {
                                        Color(UIColor.systemGray6)
                                        ProgressView()
                                            .tint(.brandNavy)
                                    }
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(16)
                                }
                            } else {
                                Image(systemName: item.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height:  120)
                                    .padding(24)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(16)
                            }
                        }
                        Spacer()
                    }

                    // Item Name and Details
                    VStack(alignment:  .leading, spacing: 12) {
                        Text(item.name)
                            .font(.title)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Item ID:")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                Text(item.itemId)
                                    .font(. subheadline)
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("Quantity:")
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.secondaryLabel))
                                Text("\(item.quantity) pc")
                                    .font(.subheadline)
                                    .fontWeight(. medium)
                                    .foregroundColor(item.quantity < 50 ? Color(UIColor.systemRed) : . brandNavy)
                            }

                            HStack {
                                Text("Category:")
                                    .font(. subheadline)
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
                                .fontWeight(. semibold)

                            Text(notes)
                                .font(.body)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                . background(Color(UIColor.tertiarySystemBackground))
                                .cornerRadius(8)
                        }

                        Divider()
                    }

                    // History Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("History:")
                                .font(.headline)
                                .fontWeight(. semibold)
                            Spacer()
                            Button(action: {
                                showingEditHistory = true
                            }) {
                                Text("Edit History")
                                    .font(. subheadline)
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
                                                .font(. subheadline)
                                                .foregroundColor(Color(UIColor.secondaryLabel))

                                            Spacer()

                                            Text(entry.value)
                                                .font(.subheadline)
                                                .foregroundColor(Color(UIColor.label))
                                                .multilineTextAlignment(.trailing)
                                        }
                                        . padding(. vertical, 6)

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
                            . cornerRadius(12)
                        }
                    }

                    // Bookmark Button with local state forcing UI refresh
                    Button(action:  {
                        print("ItemDetailOverlay: Bookmark tapped")
                        print("Current state: \(localBookmarkState)")
                        localBookmarkState.toggle()
                        print("New state: \(localBookmarkState)")
                        onBookmarkToggle(item)
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: localBookmarkState ? "bookmark.fill" : "bookmark")
                            Text(localBookmarkState ? "Bookmarked" : "Bookmark Item")
                                .fontWeight(. semibold)
                            Spacer()
                        }
                        .padding()
                        .background(localBookmarkState ? Color.brandNavy.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                        . foregroundColor(localBookmarkState ? Color.brandNavy : Color(UIColor.label))
                        .cornerRadius(12)
                    }

                    Spacer(minLength: 20)
                }
                .padding(24)
            }
            . frame(maxWidth: 500)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.2),
                radius: 20,
                x: 0,
                y: 10
            )
            .padding(. horizontal, 20)
            .padding(.vertical, 60)
        }
        // When this view opens, match the local bookmark state
        // with the item's real bookmark value.
        .onAppear {
            localBookmarkState = item.isBookmarked
        }
        // If the parent changes item. isBookmarked elsewhere,
        // update the local UI state so it stays in sync.
        .onChange(of: item.isBookmarked) { oldValue, newValue in
            localBookmarkState = newValue
        }
        // Opens the Edit History sheet when showingEditHistory = true.
        // Passes a binding so edits update the item's history.
        // Calls onUpdate to save changes to the parent.
        .sheet(isPresented: $showingEditHistory) {
            EditHistoryView(history: $item.history, onSave: {
                onUpdate(item)
            })
        }
        // Opens the Record Transfer sheet.
        // Gives it a binding to the item and to the sheet's own visible state.
        // onSave tells the parent to update the item
        . sheet(isPresented: $showingRecordTransfer) {
            RecordTransferView(item: $item, isPresented: $showingRecordTransfer, onSave: {
                onUpdate(item)
            })
        }
        // Opens the Restock sheet.
        // item is passed as a binding so any quantity changes update the parent.
        .sheet(isPresented: $showingRestock) {
            RestockView(item: $item, isPresented: $showingRestock, onSave: {
                onUpdate(item)
            })
        }
    }
}

