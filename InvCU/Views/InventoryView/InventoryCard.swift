//
//  InventoryCard. swift
//  InvCU
//

import SwiftUI

struct InventoryCard: View {
    @Binding var item:  InventoryItem
    let onBookmarkToggle: () -> Void
    let onTap:  () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Item Image or Remote Photo
            Group {
                if item.isURLImage {
                    if let cachedImage = item.cachedUIImage {
                        // Show cached image immediately - INSTANT
                        Image(uiImage: cachedImage)
                            .resizable()
                            . scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                    } else {
                        // Fallback placeholder
                        RoundedRectangle(cornerRadius: 10)
                            . fill(Color(UIColor.systemGray6))
                            . frame(width: 60, height: 60)
                            . overlay(
                                ProgressView()
                                    .tint(.brandNavy)
                            )
                    }
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
            VStack(alignment:  . leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 17, weight: . semibold))
                    . foregroundColor(Color(UIColor.label))
                
                Text("Quantity: \(item.quantity) pc")
                    . font(.system(size: 15))
                    .foregroundColor(item.quantity < 10 ? Color(UIColor.systemRed) : Color(UIColor.secondaryLabel))
            }
            .frame(maxWidth: . infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        . padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(
            color: colorScheme == . dark ? Color.black.opacity(0.35) : Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 3
        )
    }
}
