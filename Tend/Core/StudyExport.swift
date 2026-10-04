import Foundation

/// Raw observations and a reproducible, source-labelled derived snapshot travel together.
/// All historical thresholds, missingness and analysis assumptions remain inspectable.
struct StudyExport: Codable, Sendable {
    let exportedAt: Date
    let isPrototype: Bool
    let configuration: StudyConfiguration
    let data: StudyData
    let analysis: ResearchAnalysisSnapshot

    func write(to url: URL) throws {
        try configuration.validate()
        try data.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(self)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: .atomic)
    }
}
