//
//  InventoryItem.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import Foundation

struct InventoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var quantity: Int
    var category: String
    var imageName: String
    let itemId: String
    var notes: String?
    var history: [HistoryEntry]
    var isBookmarked: Bool
    
    var isURLImage: Bool {
        imageName.hasPrefix("http://") || imageName.hasPrefix("https://")
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        quantity: Int,
        category: String,
        imageName: String,
        itemId: String,
        notes: String? = nil,
        history: [HistoryEntry] = [],
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.category = category
        self.imageName = imageName
        self.itemId = itemId
        self.notes = notes
        self.history = history
        self.isBookmarked = isBookmarked
    }
    
    static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool {
        lhs.id == rhs.id
    }
}
