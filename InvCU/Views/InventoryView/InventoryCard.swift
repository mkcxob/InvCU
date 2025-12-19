//
//  InventoryCard 2.swift
//  InvCU
//
//  Created by work on 11/13/25.
//

import SwiftUI

// @Binding means this view does NOT own the item.
// It receives a live connection to the parent's InventoryItem,
// so any changes made here (bookmark, quantity) it updates the parent view's data instantly.

struct InventoryCard: View {
    @Binding var item: InventoryItem
    let onBookmarkToggle:  () -> Void
    let onTap: () -> Void
    
    // Takes the users light or dark system
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Item Image or Remote Photo
            Group {
                if item.isURLImage, let _ = URL(string: item.imageName) {
                    // Use CachedAsyncImage instead of AsyncImage for faster loading
                    CachedAsyncImage(url: item.imageName) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.systemGray6))
                            .frame(width: 60, height: 60)
                            .overlay(
                                ProgressView()
                            )
                    }
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                } else {
                    // Local system image
                    Image(systemName: item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .padding(12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                }
            }
            .onTapGesture {
                onTap()
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
            
            // Bookmark
            Button(action:  {
                print("InventoryCard: Bookmark button tapped for \(item.name)")
                print("InventoryCard: Current bookmark state: \(item.isBookmarked)")
                onBookmarkToggle()
            }) {
                Image(systemName: item.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(item.isBookmarked ? .brandNavy : Color(UIColor.secondaryLabel))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle())
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
}
