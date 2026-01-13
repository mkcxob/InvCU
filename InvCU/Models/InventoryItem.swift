//
//  InventoryItem.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import Foundation
import UIKit

//Equatable compares to values to see if they are equal
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

    // This property is for UI/runtime use and is NOT codable.
    var cachedUIImage: UIImage?

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
        isBookmarked: Bool = false,
        cachedUIImage: UIImage? = nil
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
        self.cachedUIImage = cachedUIImage
    }

    // Don't encode/decode cachedUIImage
    private enum CodingKeys: String, CodingKey {
        case id, name, quantity, category, imageName, itemId, notes, history, isBookmarked
    }

    //Two InventoryItem objects are considered the same if their IDs match, checks for duplicates
    static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool {
        lhs.id == rhs.id
    }
}

