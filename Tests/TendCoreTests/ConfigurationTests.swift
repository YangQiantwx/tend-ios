import XCTest
@testable import TendCore

final class ConfigurationTests: XCTestCase {
    func testSourceBoundariesAreExplicitInConfiguration() throws {
        let configuration = try loadConfiguration()
        XCTAssertEqual(configuration.prompts.count, 3)
        XCTAssertEqual(configuration.studyDurationDays, 56)
        XCTAssertEqual(configuration.ruleStatus, "demo-pending-review")
        XCTAssertEqual(configuration.practices.count, 8)
    }

    func testInvalidConfigurationIsRejected() throws {
        var configuration = try loadConfiguration()
        configuration.prompts.removeLast()
        XCTAssertThrowsError(try configuration.validate())
        configuration = try loadConfiguration()
        configuration.prompts[0].hour = Int.max
        XCTAssertThrowsError(try configuration.validate())
        configuration = try loadConfiguration()
        configuration.prompts[1].hour = configuration.prompts[0].hour
        configuration.prompts[1].minute = configuration.prompts[0].minute
        XCTAssertThrowsError(try configuration.validate())
        configuration = try loadConfiguration()
        configuration.thresholds.painHigh = 0
        XCTAssertThrowsError(try configuration.validate())
        configuration = try loadConfiguration()
        configuration.practices.removeAll { $0.id == "grounding" }
        XCTAssertThrowsError(try configuration.validate())
        configuration = try loadConfiguration()
        configuration.practices.append(configuration.practices[0])
        XCTAssertThrowsError(try configuration.validate())
    }

    func testBriefFallbackMustRemainAvailable() throws {
        var configuration = try loadConfiguration()
        let index = try XCTUnwrap(configuration.practices.firstIndex { $0.id == "movement-break" })
        configuration.practices[index].durationSeconds = 300
        XCTAssertThrowsError(try configuration.validate())
    }
}
