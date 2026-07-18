//
//  MetronomeProgram.swift
//  watch_metronome
//

import Foundation

struct MeterPattern: Codable, Hashable, Identifiable {
    var id: UUID
    var groups: [Int]
    var denominator: Int

    init(id: UUID = UUID(), groups: [Int] = [4], denominator: Int = 4) {
        self.id = id
        self.groups = groups.map { max(1, $0) }
        self.denominator = denominator
    }

    init(id: UUID = UUID(), numerator: Int, denominator: Int) {
        self.id = id
        self.groups = [max(1, numerator)]
        self.denominator = denominator
    }

    var numerator: Int {
        max(1, groups.reduce(0, +))
    }

    var displayName: String {
        "\(numerator)/\(denominator)"
    }
}

enum TempoAutomationShape: String, Codable, CaseIterable, Identifiable {
    case none
    case ritardando
    case accelerando

    var id: String { rawValue }
}

struct TempoAutomation: Codable, Hashable {
    var shape: TempoAutomationShape
    var targetBpm: Int
    var lengthInBars: Int

    init(shape: TempoAutomationShape = .none, targetBpm: Int = 120, lengthInBars: Int = 1) {
        self.shape = shape
        self.targetBpm = min(400, max(40, targetBpm))
        self.lengthInBars = max(1, lengthInBars)
    }
}

struct ProgramSection: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var meter: MeterPattern
    var bpm: Int
    var bars: Int
    var referenceNoteMultiplier: Double
    var rhythmModeRawValue: Int
    var tempoAutomation: TempoAutomation
    var accents: [Bool]? // Optional custom accent pattern

    init(
        id: UUID = UUID(),
        name: String = "Section",
        meter: MeterPattern = MeterPattern(),
        bpm: Int = 120,
        bars: Int = 1,
        referenceNoteMultiplier: Double = 1.0,
        rhythmMode: RhythmMode = .all,
        tempoAutomation: TempoAutomation = TempoAutomation(),
        accents: [Bool]? = nil
    ) {
        self.id = id
        self.name = name
        self.meter = meter
        self.bpm = min(400, max(40, bpm))
        self.bars = max(1, bars)
        self.referenceNoteMultiplier = referenceNoteMultiplier
        self.rhythmModeRawValue = rhythmMode.rawValue
        self.tempoAutomation = tempoAutomation
        self.accents = accents
    }

    var rhythmMode: RhythmMode {
        RhythmMode(rawValue: rhythmModeRawValue) ?? .all
    }

    var displayName: String {
        "\(meter.displayName)  \(bpm) BPM"
    }
}

struct QueuedMetronomeChange: Codable, Hashable, Identifiable {
    var id: UUID
    var section: ProgramSection
    var loops: Bool
    var program: MetronomeProgram?

    init(id: UUID = UUID(), section: ProgramSection, loops: Bool = true) {
        self.id = id
        self.section = section
        self.loops = loops
        self.program = nil
    }

    init(id: UUID = UUID(), program: MetronomeProgram) {
        self.id = id
        self.section = program.sections.first ?? ProgramSection()
        self.loops = program.loops
        self.program = program
    }
}

enum PresetProfileKind: String, Codable, CaseIterable, Identifiable {
    case basic
    case composite

    var id: String { rawValue }
}

struct PresetProfile: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var kind: PresetProfileKind
    var program: MetronomeProgram

    init(id: UUID = UUID(), name: String, kind: PresetProfileKind, program: MetronomeProgram) {
        self.id = id
        self.name = name
        self.kind = kind
        self.program = program
    }
}

struct MetronomeProgram: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var sections: [ProgramSection]
    var loops: Bool

    init(
        id: UUID = UUID(),
        name: String = "Program",
        sections: [ProgramSection] = [ProgramSection(name: "A")],
        loops: Bool = true
    ) {
        self.id = id
        self.name = name
        self.sections = sections.isEmpty ? [ProgramSection(name: "A")] : sections
        self.loops = loops
    }

    static var defaultProgram: MetronomeProgram {
        MetronomeProgram(
            name: "Basic",
            sections: [
                ProgramSection(name: "4/4", meter: MeterPattern(numerator: 4, denominator: 4), bpm: 120, bars: 1)
            ],
            loops: true
        )
    }

    static var iPhoneStarterProgram: MetronomeProgram {
        MetronomeProgram(
            name: "Practice",
            sections: [
                ProgramSection(name: "4/4", meter: MeterPattern(numerator: 4, denominator: 4), bpm: 120, bars: 2),
                ProgramSection(name: "7/8", meter: MeterPattern(numerator: 7, denominator: 8), bpm: 120, bars: 2)
            ],
            loops: true
        )
    }
}
