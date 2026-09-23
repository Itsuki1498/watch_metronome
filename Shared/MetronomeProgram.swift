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
        var total = 0
        self.groups = (groups.isEmpty ? [1] : groups).compactMap { group in
            guard total < 32 else { return nil }
            let value = min(32 - total, max(1, group))
            total += value
            return value
        }
        self.denominator = max(1, denominator)
    }

    init(id: UUID = UUID(), numerator: Int, denominator: Int) {
        self.init(id: id, groups: [numerator], denominator: denominator)
    }

    var numerator: Int {
        max(1, groups.reduce(0) { total, group in
            min(32, total + min(32, max(1, group)))
        })
    }

    var displayName: String {
        "\(numerator)/\(denominator)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, groups, numerator, denominator
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let groups = try values.decodeIfPresent([Int].self, forKey: .groups)
            ?? [values.decodeIfPresent(Int.self, forKey: .numerator) ?? 4]
        self.init(
            id: try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            groups: groups,
            denominator: try values.decodeIfPresent(Int.self, forKey: .denominator) ?? 4
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(groups, forKey: .groups)
        try values.encode(denominator, forKey: .denominator)
    }
}

enum TempoAutomationShape: String, Codable, CaseIterable, Identifiable {
    case none
    case ritardando
    case accelerando

    var id: String { rawValue }
}

enum ProgramEndBehavior: String, Codable {
    case stop
    case holdLastSection
}

struct TempoAutomation: Codable, Hashable {
    var shape: TempoAutomationShape
    var targetBpm: Int
    var lengthInBars: Int

    init(shape: TempoAutomationShape = .none, targetBpm: Int = 120, lengthInBars: Int = 1) {
        self.shape = shape
        self.targetBpm = min(400, max(40, targetBpm))
        self.lengthInBars = min(64, max(1, lengthInBars))
    }

    private enum CodingKeys: String, CodingKey {
        case shape, targetBpm, lengthInBars
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            shape: try values.decodeIfPresent(TempoAutomationShape.self, forKey: .shape) ?? .none,
            targetBpm: try values.decodeIfPresent(Int.self, forKey: .targetBpm) ?? 120,
            lengthInBars: try values.decodeIfPresent(Int.self, forKey: .lengthInBars) ?? 1
        )
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
        self.bars = min(999, max(1, bars))
        self.referenceNoteMultiplier = referenceNoteMultiplier.isFinite
            ? min(4.0, max(0.125, referenceNoteMultiplier))
            : 1.0
        self.rhythmModeRawValue = rhythmMode.rawValue
        self.tempoAutomation = tempoAutomation
        self.accents = accents.map { Array($0.prefix(32)) }
    }

    var rhythmMode: RhythmMode {
        RhythmMode(rawValue: rhythmModeRawValue) ?? .all
    }

    var displayName: String {
        "\(meter.displayName)  \(bpm) BPM"
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, meter, bpm, bars, referenceNoteMultiplier, rhythmModeRawValue, tempoAutomation, accents
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try values.decodeIfPresent(String.self, forKey: .name) ?? "Section",
            meter: try values.decodeIfPresent(MeterPattern.self, forKey: .meter) ?? MeterPattern(),
            bpm: try values.decodeIfPresent(Int.self, forKey: .bpm) ?? 120,
            bars: try values.decodeIfPresent(Int.self, forKey: .bars) ?? 1,
            referenceNoteMultiplier: try values.decodeIfPresent(Double.self, forKey: .referenceNoteMultiplier) ?? 1.0,
            rhythmMode: RhythmMode(rawValue: try values.decodeIfPresent(Int.self, forKey: .rhythmModeRawValue) ?? RhythmMode.all.rawValue) ?? .all,
            tempoAutomation: try values.decodeIfPresent(TempoAutomation.self, forKey: .tempoAutomation) ?? TempoAutomation(),
            accents: try values.decodeIfPresent([Bool].self, forKey: .accents)
        )
    }
}

struct QueuedMetronomeChange: Codable, Hashable, Identifiable {
    var id: UUID
    var section: ProgramSection
    var loops: Bool
    var program: MetronomeProgram?
    var endBehavior: ProgramEndBehavior

    init(id: UUID = UUID(), section: ProgramSection, loops: Bool = true, endBehavior: ProgramEndBehavior = .stop) {
        self.id = id
        self.section = section
        self.loops = loops
        self.program = nil
        self.endBehavior = endBehavior
    }

    init(id: UUID = UUID(), program: MetronomeProgram) {
        self.id = id
        self.section = program.sections.first ?? ProgramSection()
        self.loops = program.loops
        self.program = program
        self.endBehavior = program.endBehavior
    }

    private enum CodingKeys: String, CodingKey {
        case id, section, loops, program, endBehavior
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        section = try values.decode(ProgramSection.self, forKey: .section)
        loops = try values.decode(Bool.self, forKey: .loops)
        program = try values.decodeIfPresent(MetronomeProgram.self, forKey: .program)
        endBehavior = try values.decodeIfPresent(ProgramEndBehavior.self, forKey: .endBehavior) ?? .stop
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
    var endBehavior: ProgramEndBehavior

    init(
        id: UUID = UUID(),
        name: String = "Program",
        sections: [ProgramSection] = [ProgramSection(name: "A")],
        loops: Bool = true,
        endBehavior: ProgramEndBehavior = .stop
    ) {
        self.id = id
        self.name = name
        self.sections = sections.isEmpty ? [ProgramSection(name: "A")] : sections
        self.loops = loops
        self.endBehavior = endBehavior
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, sections, loops, endBehavior
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        sections = try values.decode([ProgramSection].self, forKey: .sections)
        loops = try values.decode(Bool.self, forKey: .loops)
        endBehavior = try values.decodeIfPresent(ProgramEndBehavior.self, forKey: .endBehavior) ?? .stop
        if sections.isEmpty {
            sections = [ProgramSection(name: "A")]
        }
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
