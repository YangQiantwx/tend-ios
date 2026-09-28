import Foundation

protocol StudyRepository {
    func load() throws -> StudyData?
    func save(_ data: StudyData) throws
}

/// Local prototype persistence. A malformed file is surfaced to the app for recovery;
/// it is never treated as an empty study or overwritten by a successful-looking reset.
struct JSONStudyRepository: StudyRepository {
    let url: URL

    func load() throws -> StudyData? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try decoder.decode(StudyData.self, from: Data(contentsOf: url))
        try data.validate()
        return data
    }

    func save(_ data: StudyData) throws {
        try data.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let encoded = try encoder.encode(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoded.write(to: url, options: .atomic)
    }
}
