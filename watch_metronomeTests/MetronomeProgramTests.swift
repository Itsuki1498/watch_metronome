import XCTest
@testable import watch_metronome

final class MetronomeProgramTests: XCTestCase {
    func testProgramRoundTripsForWatchSynchronization() throws {
        let section = ProgramSection(
            name: "7/8",
            meter: MeterPattern(numerator: 7, denominator: 8),
            bpm: 132,
            bars: 2,
            referenceNoteMultiplier: 0.5,
            rhythmMode: .strongMedium,
            tempoAutomation: TempoAutomation(shape: .accelerando, targetBpm: 148, lengthInBars: 2),
            accents: [true, false, true, false, false, true, false]
        )
        let program = MetronomeProgram(name: "Alternating", sections: [section, section], loops: true)
        let encoded = try JSONEncoder().encode(program)
        let decoded = try JSONDecoder().decode(MetronomeProgram.self, from: encoded)

        XCTAssertEqual(decoded, program)
        XCTAssertEqual(decoded.sections.first?.meter.displayName, "7/8")
        XCTAssertEqual(decoded.sections.first?.accents?.count, 7)
    }

    func testTempoAutomationAndSectionInputsAreClamped() {
        let automation = TempoAutomation(targetBpm: 900, lengthInBars: 0)
        let section = ProgramSection(
            meter: MeterPattern(numerator: 4, denominator: 4),
            bpm: 1,
            bars: 0,
            tempoAutomation: automation
        )

        XCTAssertEqual(automation.targetBpm, 400)
        XCTAssertEqual(automation.lengthInBars, 1)
        XCTAssertEqual(section.bpm, 40)
        XCTAssertEqual(section.bars, 1)
    }

    func testQueuedProgramCarriesLoopAndEndBehavior() throws {
        let program = MetronomeProgram(
            name: "Finite",
            sections: [ProgramSection(name: "rit.", bars: 3)],
            loops: false,
            endBehavior: .holdLastSection
        )
        let queuedChange = QueuedMetronomeChange(program: program)
        let decoded = try JSONDecoder().decode(
            QueuedMetronomeChange.self,
            from: JSONEncoder().encode(queuedChange)
        )

        XCTAssertEqual(decoded.program, program)
        XCTAssertFalse(decoded.loops)
        XCTAssertEqual(decoded.endBehavior, .holdLastSection)
    }

    func testDecodingSanitizesInvalidMeterAndTempoValues() throws {
        let meterData = try JSONSerialization.data(withJSONObject: [
            "id": UUID().uuidString,
            "groups": [0, -3],
            "denominator": 0
        ])
        let meter = try JSONDecoder().decode(MeterPattern.self, from: meterData)
        XCTAssertEqual(meter.groups, [1, 1])
        XCTAssertEqual(meter.denominator, 1)

        let automationData = try JSONSerialization.data(withJSONObject: [
            "shape": TempoAutomationShape.ritardando.rawValue,
            "targetBpm": 0,
            "lengthInBars": 0
        ])
        let automation = try JSONDecoder().decode(TempoAutomation.self, from: automationData)
        XCTAssertEqual(automation.targetBpm, 40)
        XCTAssertEqual(automation.lengthInBars, 1)
    }

    func testDecodingCapsExtremeSectionValuesWithoutOverflow() throws {
        let sectionData = try JSONSerialization.data(withJSONObject: [
            "id": UUID().uuidString,
            "name": "Extreme",
            "meter": [
                "id": UUID().uuidString,
                "groups": [Int.max, Int.max],
                "denominator": 8
            ],
            "bpm": 120,
            "bars": Int.max,
            "referenceNoteMultiplier": Double.greatestFiniteMagnitude,
            "rhythmModeRawValue": RhythmMode.all.rawValue,
            "tempoAutomation": [
                "shape": TempoAutomationShape.ritardando.rawValue,
                "targetBpm": 100,
                "lengthInBars": Int.max
            ],
            "accents": Array(repeating: true, count: 64)
        ])

        let section = try JSONDecoder().decode(ProgramSection.self, from: sectionData)

        XCTAssertEqual(section.meter.groups, [32])
        XCTAssertEqual(section.meter.numerator, 32)
        XCTAssertEqual(section.bars, 999)
        XCTAssertEqual(section.referenceNoteMultiplier, 4.0)
        XCTAssertEqual(section.tempoAutomation.lengthInBars, 64)
        XCTAssertEqual(section.accents?.count, 32)
    }
}
