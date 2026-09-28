import Foundation

/// Raw observations and a reproducible, source-labelled derived snapshot travel together.
/// All historical thresholds, missingness and analysis assumptions remain inspectable.
struct StudyExport: Codable, Sendable {
    let exportedAt: Date
    let isPrototype: Bool
    let configuration: StudyConfiguration
    let data: StudyData
    let analysis: ResearchAnalysisSnapshot
}
