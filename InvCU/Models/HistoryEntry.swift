//
//  HistoryEntry.swift
//  InvCU
//
//  Created by work on 11/04/2025
//

import Foundation

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var value: String
    
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}
