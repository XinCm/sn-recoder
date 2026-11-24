import Foundation

struct MemoItem: Codable, Identifiable, Equatable {
    var id: UUID
    var dateKey: String
    var text: String
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dateKey: String,
        text: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.text = text
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct MemoDatabase: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var items: [MemoItem]

    init(schemaVersion: Int = MemoDatabase.currentSchemaVersion, items: [MemoItem]) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}
