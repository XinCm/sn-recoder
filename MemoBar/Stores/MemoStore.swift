import Foundation
import SwiftUI

@MainActor
final class MemoStore: ObservableObject {
    @Published private(set) var items: [MemoItem]
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var notice: String?

    private let fileStore: MemoFileStore

    init(fileStore: MemoFileStore = MemoFileStore()) {
        self.fileStore = fileStore
        let result = fileStore.load()
        self.items = result.database?.items ?? []
        self.notice = result.notice
        self.saveErrorMessage = nil
    }

    var dataDirectoryURL: URL { fileStore.directory }
    var dataFileURL: URL { fileStore.fileURL }

    // MARK: - Queries

    func items(for dateKey: String) -> [MemoItem] {
        items
            .filter { $0.dateKey == dateKey }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func items(inMonthWithPrefix prefix: String) -> [MemoItem] {
        items.filter { $0.dateKey.hasPrefix(prefix) }
    }

    func itemCount(for dateKey: String) -> Int {
        items.reduce(into: 0) { count, item in
            if item.dateKey == dateKey { count += 1 }
        }
    }

    var totalItemCount: Int { items.count }

    // MARK: - Mutations

    @discardableResult
    func add(text: String, to dateKey: String) -> MemoItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let item = MemoItem(
            dateKey: dateKey,
            text: trimmed,
            sortOrder: nextSortOrder(for: dateKey)
        )
        items.append(item)
        persist()
        return item
    }

    func toggleCompletion(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
        items[index].updatedAt = Date()
        persist()
    }

    @discardableResult
    func updateText(_ id: UUID, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        guard items[index].text != trimmed else { return true }
        items[index].text = trimmed
        items[index].updatedAt = Date()
        persist()
        return true
    }

    @discardableResult
    func delete(_ id: UUID) -> MemoItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = items.remove(at: index)
        persist()
        return removed
    }

    /// Restores an item after an undo, keeping its original position.
    func restore(_ item: MemoItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        items.sort { lhs, rhs in
            if lhs.dateKey != rhs.dateKey { return lhs.dateKey < rhs.dateKey }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
        persist()
    }

    func retrySave() {
        persist()
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: - Persistence

    private func nextSortOrder(for dateKey: String) -> Int {
        let highest = items
            .filter { $0.dateKey == dateKey }
            .map(\.sortOrder)
            .max()
        return (highest ?? -1) + 1
    }

    private func persist() {
        do {
            try fileStore.save(MemoDatabase(items: items))
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
