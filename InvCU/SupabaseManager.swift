import Foundation
import Combine
import SwiftUI
import Supabase

// DTOs that match your Supabase table columns
private struct InventoryRow: Codable {
    let id: UUID
    let name: String
    let quantity: Int
    let category: String
    let image_url: String
    let item_id: String
    let notes: String?
    let history: [HistoryDTO]?
    let is_bookmarked: Bool?
}

private struct HistoryDTO: Codable {
    let id: UUID
    let label: String
    let value: String
}

final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    private init() {}
    
    // MARK: - Configuration
    private let itemsTable = "inventory_items"
    private let imagesBucket = "inventory-images"       
    
    // MARK: - Mapping
    private func toModel(_ row: InventoryRow) -> InventoryItem {
        let history = (row.history ?? []).map { HistoryEntry(id: $0.id, label: $0.label, value: $0.value) }
        return InventoryItem(
            id: row.id,
            name: row.name,
            quantity: row.quantity,
            category: row.category,
            imageName: row.image_url,
            itemId: row.item_id,
            notes: row.notes,
            history: history,
            isBookmarked: row.is_bookmarked ?? false
        )
    }
    
    private func toRow(_ item: InventoryItem) -> InventoryRow {
        InventoryRow(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            category: item.category,
            image_url: item.imageName,
            item_id: item.itemId,
            notes: item.notes,
            history: item.history.map { HistoryDTO(id: $0.id, label: $0.label, value: $0.value) },
            is_bookmarked: item.isBookmarked
        )
    }
    
    // MARK: - CRUD
    func fetchAllItems() async throws -> [InventoryItem] {
        let response = try await supabase
            .from(itemsTable)
            .select()
            .execute()
        
        let rows = try JSONDecoder().decode([InventoryRow].self, from: response.data)
        return rows.map(toModel(_:))
    }
    
    func addItem(_ item: InventoryItem) async throws -> InventoryItem {
        let row = toRow(item)
        let response = try await supabase
            .from(itemsTable)
            .insert(row, returning: .representation)
            .single()
            .execute()
        
        let created = try JSONDecoder().decode(InventoryRow.self, from: response.data)
        return toModel(created)
    }
    
    func updateItem(_ item: InventoryItem) async throws {
        let row = toRow(item)
        _ = try await supabase
            .from(itemsTable)
            .update(row)
            .eq("id", value: item.id)
            .execute()
    }
    
    func toggleBookmark(_ id: UUID, isBookmarked: Bool) async throws {
        _ = try await supabase
            .from(itemsTable)
            .update(["is_bookmarked": isBookmarked])
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Storage
    // Uploads a UIImage to Supabase Storage and returns a public URL string.
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "images/\(fileName)"
        
        // Upload to Storage
        try await supabase.storage
            .from(imagesBucket)
            .upload(filePath, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        
        // Get a public URL (assumes bucket is public)
        guard let publicURL = try supabase.storage
            .from(imagesBucket)
            .getPublicURL(path: filePath)
            .absoluteString as String? else {
            throw NSError(domain: "SupabaseManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create public URL"])
        }
        return publicURL
    }
}
