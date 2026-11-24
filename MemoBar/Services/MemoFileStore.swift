import Foundation

/// Loads and saves the memo database as a single JSON file inside
/// `~/Library/Application Support/MemoBar/`.
///
/// Saves are atomic (write to a temporary file, then rename) and the last
/// readable file is kept as `memos.backup.json` so a damaged write can be
/// recovered instead of silently losing every memo.
struct MemoFileStore {
    let directory: URL

    var fileURL: URL { directory.appendingPathComponent("memos.json") }
    var backupURL: URL { directory.appendingPathComponent("memos.backup.json") }

    init(directory: URL = MemoFileStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("MemoBar", isDirectory: true)
    }

    struct LoadResult {
        var database: MemoDatabase?
        var notice: String?
    }

    func load() -> LoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return LoadResult(database: nil, notice: nil)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let database = try Self.decoder.decode(MemoDatabase.self, from: data)
            return LoadResult(database: database, notice: nil)
        } catch {
            if let backupData = try? Data(contentsOf: backupURL),
               let database = try? Self.decoder.decode(MemoDatabase.self, from: backupData) {
                // Keep the unreadable original for manual recovery, then put the
                // backup content back in place so the next launch starts clean.
                let corruptURL = directory.appendingPathComponent("memos.corrupt-\(Self.corruptStamp()).json")
                try? fileManager.moveItem(at: fileURL, to: corruptURL)
                if let restored = try? Self.encoder.encode(database) {
                    try? restored.write(to: fileURL, options: [.atomic])
                }
                return LoadResult(database: database, notice: "主数据文件损坏，已从备份恢复。")
            }

            // Keep the unreadable file around for manual recovery.
            let stamp = Self.corruptStamp()
            let corruptURL = directory.appendingPathComponent("memos.corrupt-\(stamp).json")
            try? fileManager.moveItem(at: fileURL, to: corruptURL)
            return LoadResult(database: nil, notice: "数据文件无法读取，原文件已备份为 \(corruptURL.lastPathComponent)。")
        }
    }

    func save(_ database: MemoDatabase) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try Self.encoder.encode(database)

        // Only rotate a backup if the current file is fully readable.
        if let current = try? Data(contentsOf: fileURL),
           (try? Self.decoder.decode(MemoDatabase.self, from: current)) != nil {
            try? current.write(to: backupURL, options: [.atomic])
        }

        try data.write(to: fileURL, options: [.atomic])
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func corruptStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
