import Foundation

struct JSONDraftRepository {
    let url: URL

    enum LoadResult {
        case missing
        case draft(CheckInDraft)
        case quarantined(URL)
    }

    /// A malformed draft cannot lock access to otherwise valid study records.
    /// Its original bytes are retained under a unique recovery filename.
    func load() throws -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        let bytes = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let draft = try decoder.decode(CheckInDraft.self, from: bytes)
            try draft.validate()
            return .draft(draft)
        } catch {
            let recoveryURL = url.deletingLastPathComponent()
                .appendingPathComponent("check-in-draft-recovery-\(UUID().uuidString).json")
            try FileManager.default.moveItem(at: url, to: recoveryURL)
            return .quarantined(recoveryURL)
        }
    }

    func save(_ draft: CheckInDraft) throws {
        try draft.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(draft).write(to: url, options: .atomic)
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
