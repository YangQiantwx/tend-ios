import Foundation
import XCTest
@testable import TendCore

final class RuleEngineTests: XCTestCase {
    func testAllPossibleAnswersOfferBothCategoriesWithinAvailableTime() throws {
        let configuration = try loadConfiguration()
        let engine = RuleEngine(configuration: configuration)
        var combinations = 0
        for distress in 1...5 {
            for willingness in 1...5 {
                for fatigue in 1...5 {
                    for pain in 1...5 {
                        for function in 1...5 {
                            for time in AvailableTime.allCases {
                                let answers = EMAAnswers(
                                    distress: distress, willingness: willingness, fatigue: fatigue,
                                    pain: pain, physicalFunction: function, availableTime: time
                                )
                                let options = try engine.recommend(for: answers)
                                XCTAssertEqual(options.count, 2)
                                XCTAssertEqual(options.map(\.category), [.movement, .mindfulness])
                                XCTAssertTrue(options.allSatisfy { $0.durationSeconds <= time.maxMinutes * 60 })
                                combinations += 1
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(combinations, 12_500)
    }

    func testEachPhysicalCapabilityThresholdChangesRecommendation() throws {
        var configuration = try loadConfiguration()
        let answers = EMAAnswers(distress: 1, willingness: 5, fatigue: 3, pain: 3,
                                 physicalFunction: 3, availableTime: .fiveTo10)
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).first?.id, "short-walk")
        configuration.thresholds.painHigh = 3
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).first?.id, "chair-stretch")
        configuration = try loadConfiguration()
        configuration.thresholds.fatigueHigh = 3
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).first?.id, "chair-stretch")
        configuration = try loadConfiguration()
        configuration.thresholds.physicalFunctionLow = 3
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).first?.id, "chair-stretch")
    }

    func testDistressAndWillingnessThresholdsChangeRecommendations() throws {
        var configuration = try loadConfiguration()
        let answers = EMAAnswers(distress: 3, willingness: 3, fatigue: 1, pain: 1,
                                 physicalFunction: 5, availableTime: .fiveTo10)
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).last?.id, "mindful-breathing")
        configuration.thresholds.distressHigh = 3
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).last?.id, "self-compassion")
        configuration.thresholds.willingnessLow = 3
        XCTAssertEqual(try RuleEngine(configuration: configuration).recommend(for: answers).map(\.id),
                       ["movement-break", "grounding"])
    }

    func testLimitedCapabilityNeverFallsBackToStandingOrWalking() throws {
        let engine = RuleEngine(configuration: try loadConfiguration())
        let answers = EMAAnswers(distress: 5, willingness: 5, fatigue: 5, pain: 5,
                                 physicalFunction: 1, availableTime: .under5)
        let options = try engine.recommend(for: answers)
        XCTAssertEqual(options.map(\.id), ["chair-stretch", "self-compassion"])
    }

    func testShortTimeAndFatigueUseBriefFallbacks() throws {
        let engine = RuleEngine(configuration: try loadConfiguration())
        var answers = EMAAnswers(distress: 1, willingness: 5, fatigue: 1, pain: 1,
                                 physicalFunction: 5, availableTime: .under5)
        XCTAssertEqual(try engine.recommend(for: answers).map(\.id), ["sit-to-stand", "self-compassion"])
        answers.fatigue = 5
        XCTAssertEqual(try engine.recommend(for: answers).map(\.id), ["chair-stretch", "grounding"])
        answers.availableTime = .fiveTo10
        XCTAssertEqual(try engine.recommend(for: answers).last?.id, "body-scan")
    }

    func testOutOfRangeAnswersThrowInsteadOfBeingClamped() throws {
        let engine = RuleEngine(configuration: try loadConfiguration())
        let valid = EMAAnswers(distress: 3, willingness: 3, fatigue: 3, pain: 3,
                               physicalFunction: 3, availableTime: .fiveTo10)
        let keyPaths: [WritableKeyPath<EMAAnswers, Int>] = [\.distress, \.willingness, \.fatigue, \.pain, \.physicalFunction]
        for keyPath in keyPaths {
            for invalid in [0, 6, Int.max, Int.min] {
                var answers = valid
                answers[keyPath: keyPath] = invalid
                XCTAssertThrowsError(try answers.validate())
                XCTAssertThrowsError(try engine.recommend(for: answers))
            }
        }
    }
}

func loadConfiguration() throws -> StudyConfiguration {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try StudyConfiguration.load(from: root.appendingPathComponent("Tend/Resources/study-config.json"))
}
