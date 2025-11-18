//
//  ActivityNotification.swift
//  InvCU
//
//  Created by work on 11/17/25.
//

import Foundation
import SwiftUI

// MARK: - Activity Notification Model
struct ActivityNotification: Identifiable {
    let id: UUID
    let itemId: UUID
    let itemName: String
    let category: String
    let userName: String
    let action: ActivityAction
    let quantity: Int?
    let recipientName: String?
    let notes: String?
    let timestamp: Date
    
    enum ActivityAction: String {
        case added = "added"
        case removed = "removed"
        case transferred = "transferred"
        case restocked = "restocked"
        case updated = "updated"
        
        var icon: String {
            switch self {
            case .added: return "plus.circle.fill"
            case .removed: return "minus.circle.fill"
            case .transferred: return "arrow.right.circle.fill"
            case .restocked: return "arrow.up.circle.fill"
            case .updated: return "pencil.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .added:
                return Color(red: 49/255, green: 191/255, blue: 51/255)        // #31BF33 Green
            case .removed:
                return Color(red: 238/255, green: 5/255, blue: 9/255)          // #EE0509 Red
            case .transferred:
                return Color(red: 255/255, green: 202/255, blue: 0/255)        // #FFCA00 Yellow
            case .restocked:
                return Color(red: 248/255, green: 146/255, blue: 45/255)       // #F8922D Orange
            case .updated:
                return Color(red: 0/255, green: 40/255, blue: 104/255)         // #002868 Navy Blue
            }
        }
    }
    
    var displayText: String {
        switch action {
        case .added:
            return "\(userName) added '\(itemName)' to \(category)"
        case .removed:
            return "\(userName) removed '\(itemName)' from \(category)"
        case .transferred:
            if let recipient = recipientName, let qty = quantity {
                return "\(userName) gave \(qty) pc '\(itemName)' to \(recipient)"
            }
            return "\(userName) transferred '\(itemName)'"
        case .restocked:
            if let qty = quantity {
                return "\(userName) restocked '\(itemName)' with \(qty) pc"
            }
            return "\(userName) restocked '\(itemName)'"
        case .updated:
            return "\(userName) updated '\(itemName)'"
        }
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }
}
