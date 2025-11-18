//
//  SupabaseManager.swift
//  InvCU
//
//  Created by work on 11/17/2025
//

import Foundation
import Combine
import SwiftUI
import Supabase

private struct InventoryRow: Codable {
    let id: UUID
    let name: String
    let quantity: Int
    let category: String
    let image_url: String?
    let item_id: String
    let notes: String?
    let created_at: String?
    let updated_at: String?
    let created_by: UUID?
    let last_modified_by: UUID?
}

private struct HistoryRow: Codable {
    let id: UUID
    let item_id: UUID
    let label: String
    let value: String
    let created_at: String?
    let created_by: UUID?
    let entry_order: Int
}

private struct BookmarkRow: Codable {
    let id: UUID?
    let user_id: UUID
    let item_id: UUID
    let created_at: String?
}

final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    private init() {}
    
    // MARK: - Configuration
    private let itemsTable = "inventory_items"
    private let historyTable = "history_entries"
    private let bookmarksTable = "user_bookmarks"
    private let imagesBucket = "item-images"
    
    // MARK: - Authentication Properties
    @Published var currentUser: User?
    @Published var currentProfile: UserProfile?
    
    struct UserProfile: Codable {
        let id: UUID
        let username: String
        let email: String
        let role: String
        let created_at: String?
    }
    
    // MARK: - Helper: Get Current User ID
    private func currentUserId() async throws -> UUID {
        let session = try await supabase.auth.session
        return session.user.id
    }
    
    // MARK: - CRUD Operations
    func fetchAllItems() async throws -> [InventoryItem] {
        print("Fetching all items...")
        
        // Fetch all items
        let itemsResponse = try await supabase
            .from(itemsTable)
            .select()
            .execute()
        
        let rows = try JSONDecoder().decode([InventoryRow].self, from: itemsResponse.data)
        
        // Fetch ALL history entries in ONE call
        let allHistoryResponse = try await supabase
            .from(historyTable)
            .select()
            .order("entry_order")
            .execute()
        
        let allHistoryRows = try JSONDecoder().decode([HistoryRow].self, from: allHistoryResponse.data)
        
        // Group history by item_id
        var historyByItemId: [UUID: [HistoryEntry]] = [:]
        for historyRow in allHistoryRows {
            let entry = HistoryEntry(id: historyRow.id, label: historyRow.label, value: historyRow.value)
            historyByItemId[historyRow.item_id, default: []].append(entry)
        }
        
        // Fetch ALL bookmarks in ONE call (if authenticated)
        var bookmarkedIds: Set<UUID> = []
        do {
            let userId = try await currentUserId()
            let bookmarksResponse = try await supabase
                .from(bookmarksTable)
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            let bookmarks = try JSONDecoder().decode([BookmarkRow].self, from: bookmarksResponse.data)
            bookmarkedIds = Set(bookmarks.map { $0.item_id })
            print("Loaded \(bookmarks.count) bookmarks for user")
        } catch {
            print("Failed to load bookmarks (no session?): \(error)")
            bookmarkedIds = []
        }
        
        // Build items with their history and bookmark status
        let items = rows.map { row in
            InventoryItem(
                id: row.id,
                name: row.name,
                quantity: row.quantity,
                category: row.category,
                imageName: row.image_url ?? "photo",
                itemId: row.item_id,
                notes: row.notes,
                history: historyByItemId[row.id] ?? [],
                isBookmarked: bookmarkedIds.contains(row.id)
            )
        }
        
        print("Fetched \(items.count) items with history")
        return items
    }
    
    // MARK: - Add Item
    func addItem(_ item: InventoryItem) async throws -> InventoryItem {
        let userId = try await currentUserId()
        
        print("Adding item: \(item.name)")
        
        // Insert into inventory_items
        let newRow = InventoryRow(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            category: item.category,
            image_url: item.imageName,
            item_id: item.itemId,
            notes: item.notes,
            created_at: nil,
            updated_at: nil,
            created_by: userId,
            last_modified_by: userId
        )
        
        _ = try await supabase
            .from(itemsTable)
            .insert(newRow)
            .execute()
        
        // Insert history entries with explicit entry_order
        let historyRows: [HistoryRow] = item.history.enumerated().map { idx, entry in
            HistoryRow(
                id: entry.id,
                item_id: item.id,
                label: entry.label,
                value: entry.value,
                created_at: nil,
                created_by: userId,
                entry_order: idx
            )
        }
        if !historyRows.isEmpty {
            _ = try await supabase
                .from(historyTable)
                .insert(historyRows)
                .execute()
        }
        
        print("Item added successfully")
        
        // Return the inserted item
        return item
    }
    
    // MARK: - Update Item
    func updateItem(_ item: InventoryItem) async throws {
        let userId = try await currentUserId()
        
        print("Updating item: \(item.name)")
        
        // Update inventory_items core fields
        let updatedRow = InventoryRow(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            category: item.category,
            image_url: item.imageName,
            item_id: item.itemId,
            notes: item.notes,
            created_at: nil,
            updated_at: nil,
            created_by: nil,
            last_modified_by: userId
        )
        
        _ = try await supabase
            .from(itemsTable)
            .update(updatedRow)
            .eq("id", value: item.id)
            .execute()
        
        // Replace history: delete existing, then insert current with NEW UUIDs and entry_order
        _ = try await supabase
            .from(historyTable)
            .delete()
            .eq("item_id", value: item.id)
            .execute()
        
        // Generate NEW UUIDs for history entries to avoid duplicate key errors
        let historyRows: [HistoryRow] = item.history.enumerated().map { idx, entry in
            HistoryRow(
                id: UUID(),  // NEW UUID instead of entry.id
                item_id: item.id,
                label: entry.label,
                value: entry.value,
                created_at: nil,
                created_by: userId,
                entry_order: idx
            )
        }
        if !historyRows.isEmpty {
            _ = try await supabase
                .from(historyTable)
                .insert(historyRows)
                .execute()
        }
        
        print("Item updated successfully")
    }
    
    // MARK: - Toggle Bookmark
    func toggleBookmark(_ itemId: UUID, isBookmarked: Bool) async throws {
        print("Toggling bookmark for item \(itemId) to \(isBookmarked)")
        
        let userId = try await currentUserId()
        print("Current user ID: \(userId)")
        
        if isBookmarked {
            // Insert bookmark
            let row = BookmarkRow(id: nil, user_id: userId, item_id: itemId, created_at: nil)
            
            do {
                _ = try await supabase
                    .from(bookmarksTable)
                    .insert(row)
                    .execute()
                print("Bookmark added successfully")
            } catch {
                print("Failed to add bookmark: \(error)")
                throw error
            }
        } else {
            // Remove bookmark
            do {
                _ = try await supabase
                    .from(bookmarksTable)
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("item_id", value: itemId)
                    .execute()
                print("Bookmark removed successfully")
            } catch {
                print("Failed to remove bookmark: \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Authentication Methods
    func signUp(email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        
        let user = response.user
        let username = email.components(separatedBy: "@").first ?? "user"
        
        let profile = UserProfile(
            id: user.id,
            username: username,
            email: email,
            role: "employee",
            created_at: nil
        )
        
        _ = try await supabase
            .from("profiles")
            .insert(profile)
            .execute()
    }
    
    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        await MainActor.run {
            self.currentUser = session.user
        }
        
        try await fetchCurrentProfile()
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        
        await MainActor.run {
            self.currentUser = nil
            self.currentProfile = nil
        }
    }
    
    func hasActiveSession() async throws -> Bool {
        do {
            let session = try await supabase.auth.session
            await MainActor.run {
                self.currentUser = session.user
            }
            try await fetchCurrentProfile()
            return true
        } catch {
            return false
        }
    }
    
    private func fetchCurrentProfile() async throws {
        guard let userId = currentUser?.id else { return }
        
        let response = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
        
        let profile = try JSONDecoder().decode(UserProfile.self, from: response.data)
        
        await MainActor.run {
            self.currentProfile = profile
        }
    }
    
    // MARK: - Storage
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "SupabaseManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        
        print("Uploading image to bucket: \(imagesBucket), path: \(fileName)")
        
        do {
            try await supabase.storage
                .from(imagesBucket)
                .upload(
                    fileName,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: false)
                )
            
            print("Upload successful")
            
            let publicURL = try supabase.storage
                .from(imagesBucket)
                .getPublicURL(path: fileName)
            
            print("Public URL: \(publicURL)")
            return publicURL.absoluteString
            
        } catch {
            print("Upload failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Fetch Activity Notifications from History Entries
    func fetchActivityNotifications() async throws -> [ActivityNotification] {
        print("Fetching activity notifications from history_entries...")
        
        // Fetch all history entries ordered by creation date (newest first)
        let historyResponse = try await supabase
            .from(historyTable)
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        let historyEntries = try JSONDecoder().decode([HistoryRow].self, from: historyResponse.data)
        print("Fetched \(historyEntries.count) history entries")
        
        // Fetch all items to get names and categories
        let itemsResponse = try await supabase
            .from(itemsTable)
            .select()
            .execute()
        
        let items = try JSONDecoder().decode([InventoryRow].self, from: itemsResponse.data)
        
        // Create a dictionary for quick item lookup
        let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        
        // Fetch all profiles to get user names
        struct ProfileRow: Codable {
            let id: UUID
            let full_name: String?
            let username: String
        }
        
        let profilesResponse = try await supabase
            .from("profiles")
            .select("id, full_name, username")
            .execute()
        
        let profiles = try JSONDecoder().decode([ProfileRow].self, from: profilesResponse.data)
        
        // Create a dictionary for quick profile lookup
        let profilesDict = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        
        // Group history entries by "Last Updated" to identify separate activities
        var activityGroups: [[HistoryRow]] = []
        var currentGroup: [HistoryRow] = []
        
        // Sort by created_at and entry_order to ensure proper grouping
        let sortedEntries = historyEntries.sorted { entry1, entry2 in
            if entry1.created_at == entry2.created_at {
                return entry1.entry_order < entry2.entry_order
            }
            return entry1.created_at ?? "" > entry2.created_at ?? ""
        }
        
        for entry in sortedEntries {
            currentGroup.append(entry)
            
            // When we hit "Last Updated", this marks the end of an activity group
            if entry.label == "Last Updated" {
                activityGroups.append(currentGroup)
                currentGroup = []
            }
        }
        
        // Add any remaining entries
        if !currentGroup.isEmpty {
            activityGroups.append(currentGroup)
        }
        
        print("Grouped into \(activityGroups.count) activities")
        
        // Convert grouped entries to notifications
        var notifications: [ActivityNotification] = []
        
        for group in activityGroups {
            guard let firstEntry = group.first,
                  let item = itemsDict[firstEntry.item_id],
                  let createdAt = firstEntry.created_at else {
                print("Skipping group - missing data")
                continue
            }
            
            // Parse timestamp with multiple format options
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var timestamp: Date?
            timestamp = dateFormatter.date(from: createdAt)
            
            // Try without fractional seconds if first attempt fails
            if timestamp == nil {
                dateFormatter.formatOptions = [.withInternetDateTime]
                timestamp = dateFormatter.date(from: createdAt)
            }
            
            guard let finalTimestamp = timestamp else {
                print("Failed to parse date: \(createdAt)")
                continue
            }
            
            // Get user name
            let profile = firstEntry.created_by.flatMap { profilesDict[$0] }
            let userName = profile?.full_name ?? profile?.username ?? "Unknown User"
            
            // Determine action type based on labels in the group
            let labels = Set(group.map { $0.label })
            let action: ActivityNotification.ActivityAction
            var quantity: Int? = nil
            var recipient: String? = nil
            
            if labels.contains("Restocked") {
                action = .restocked
                if let restockEntry = group.first(where: { $0.label == "Restocked" }) {
                    let qtyString = restockEntry.value
                        .replacingOccurrences(of: " pc", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    quantity = Int(qtyString)
                }
                print("Found restock activity: \(item.name) - \(quantity ?? 0) pc")
            } else if labels.contains("Given To") {
                action = .transferred
                recipient = group.first(where: { $0.label == "Given To" })?.value
                if let qtyEntry = group.first(where: { $0.label == "Quantity Given" }) {
                    let qtyString = qtyEntry.value
                        .replacingOccurrences(of: " pc", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    quantity = Int(qtyString)
                }
                print("Found transfer activity: \(item.name) to \(recipient ?? "unknown") - \(quantity ?? 0) pc")
            } else if labels.contains("Date Received") && !labels.contains("Restocked") && !labels.contains("Given To") {
                action = .added
                print("Found add activity: \(item.name)")
            } else {
                action = .updated
                print("Found update activity: \(item.name)")
            }
            
            // Extract notes if present in the group
            let notesValue = group.first(where: { $0.label == "Notes" || $0.label == "Restock Notes" })?.value
            
            let notification = ActivityNotification(
                id: firstEntry.id,
                itemId: firstEntry.item_id,
                itemName: item.name,
                category: item.category,
                userName: userName,
                action: action,
                quantity: quantity,
                recipientName: recipient,
                notes: notesValue,
                timestamp: finalTimestamp
            )
            
            notifications.append(notification)
        }
        
        print("Generated \(notifications.count) notifications")
        
        // Sort by timestamp (newest first)
        return notifications.sorted { $0.timestamp > $1.timestamp }
    }
}

