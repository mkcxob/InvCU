//
//  InventoryCard 2.swift
//  InvCU
//
//  Created by work on 11/13/25.
//


//
//  InventoryCard.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import SwiftUI

struct InventoryCard: View {
    @Binding var item: InventoryItem
    let onBookmarkToggle: () -> Void
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
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
            
            // FIXED: Bookmark Button with proper state tracking
            Button(action: {
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
