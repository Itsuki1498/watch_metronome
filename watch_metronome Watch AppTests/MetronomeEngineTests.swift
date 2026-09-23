//
//  MetronomeEngineTests.swift
//  watch_metronomeTests
//
//  Created by Gemini on 2026/05/18.
//

import Testing
import Foundation
@testable import watch_metronome_Watch_App

/// MetronomeEngine の挙動を検証するテスト
@MainActor
struct MetronomeEngineTests {

    @Test("4拍子の時、1拍目だけが強拍になるかテスト")
    func testFourFourTime() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                sections: [ProgramSection(
                    name: "4/32",
                    meter: MeterPattern(numerator: 4, denominator: 32),
                    bpm: 400,
                    referenceNoteMultiplier: 0.125
                )]
            )
        )
        
        var recordedBeats: [Int] = []
        var recordedStrongFlags: [Bool] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.fourFour")
        
        // エンジンが鳴った時の記録を取る
        engine.onTick = { beat, intensity, _ in
            guard intensity != .silence else { return }
            recordingQueue.sync {
                recordedBeats.append(Int(beat))
                recordedStrongFlags.append(intensity == .strong)
            }
        }
        
        engine.start()
        
        // 4回鳴るまで少し待つ（非同期処理の待機）
        try await Task.sleep(nanoseconds: 800_000_000)
        
        engine.stop()
        
        // --- 答え合わせ ---
        // 少なくとも4回以上は鳴っているはず
        let (beats, strongFlags) = recordingQueue.sync {
            (recordedBeats, recordedStrongFlags)
        }
        
        #expect(beats.count >= 4)
        if beats.count >= 4 {
            #expect(Array(beats.prefix(4)) == [1, 2, 3, 4])
            #expect(Array(strongFlags.prefix(4)) == [true, false, false, false])
        }
    }

    @Test("分子が0の時、1拍子に補正されるかテスト")
    func testZeroNumeratorClampsToOne() async throws {
        let engine = MetronomeEngine()
        engine.numerator = 0
        #expect(engine.numerator == 1)
        engine.applyProgram(
            MetronomeProgram(
                sections: [ProgramSection(
                    name: "1/32",
                    meter: MeterPattern(numerator: 1, denominator: 32),
                    bpm: 400,
                    referenceNoteMultiplier: 0.125
                )]
            )
        )
        
        var recordedIntensities: [BeatIntensity] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.zeroNumerator")
        
        engine.onTick = { _, intensity, _ in
            guard intensity != .silence else { return }
            recordingQueue.sync {
                recordedIntensities.append(intensity)
            }
        }
        
        engine.start()
        try await Task.sleep(nanoseconds: 300_000_000)
        engine.stop()
        
        let intensities = recordingQueue.sync {
            recordedIntensities
        }
        #expect(engine.numerator == 1)
        #expect(!intensities.isEmpty)
        #expect(intensities.allSatisfy { $0 == .strong })
    }
    
    @Test("分子が1の時、全て強拍になるかテスト")
    func testOneNumerator() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                sections: [ProgramSection(
                    name: "1/32",
                    meter: MeterPattern(numerator: 1, denominator: 32),
                    bpm: 400,
                    referenceNoteMultiplier: 0.125
                )]
            )
        )
        
        var weakCount = 0
        let recordingQueue = DispatchQueue(label: "metronome.test.oneNumerator")
        
        engine.onTick = { _, intensity, _ in
            guard intensity != .silence else { return }
            if intensity != .strong {
                recordingQueue.sync {
                    weakCount += 1
                }
            }
        }
        
        engine.start()
        try await Task.sleep(nanoseconds: 300_000_000)
        engine.stop()
        
        // 弱拍が一度も鳴っていない(0回)ことを確認
        let recordedWeakCount = recordingQueue.sync {
            weakCount
        }
        #expect(recordedWeakCount == 0)
    }

    @Test("特殊アクセントでは1拍目を強拍に固定し、選択拍を中拍にする")
    func testCustomAccentsKeepFirstBeatStrong() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                sections: [ProgramSection(
                    name: "Accent",
                    meter: MeterPattern(numerator: 4, denominator: 32),
                    bpm: 400,
                    referenceNoteMultiplier: 0.125,
                    accents: [false, true, false, true]
                )]
            )
        )

        var recordedIntensities: [BeatIntensity] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.customAccents")
        engine.onTick = { _, intensity, _ in
            recordingQueue.sync {
                recordedIntensities.append(intensity)
            }
        }

        engine.start()
        try await Task.sleep(nanoseconds: 800_000_000)
        engine.stop()

        let intensities = recordingQueue.sync { recordedIntensities }
        #expect(intensities.count >= 4)
        if intensities.count >= 4 {
            #expect(Array(intensities.prefix(4)) == [.strong, .medium, .weak, .medium])
        }
    }

    @Test("テンポ変化が指定小節数の最終小節で目標BPMに到達するかテスト")
    func testTempoAutomationReachesTargetOnFinalBar() async throws {
        let engine = MetronomeEngine()
        let section = ProgramSection(
            name: "rit.",
            meter: MeterPattern(numerator: 1, denominator: 32),
            bpm: 400,
            bars: 4,
            referenceNoteMultiplier: 0.125,
            tempoAutomation: TempoAutomation(shape: .ritardando, targetBpm: 100, lengthInBars: 4)
        )
        engine.applyProgram(MetronomeProgram(name: "Tempo", sections: [section], loops: false))

        var recordedBpms: [Int] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.tempoAutomation")
        engine.onMeasureStart = { _, _, _, _ in
            recordingQueue.sync {
                recordedBpms.append(engine.bpm)
            }
        }

        engine.start()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        engine.stop()

        let bpms = recordingQueue.sync {
            recordedBpms
        }

        #expect(Array(bpms.prefix(3)) == [300, 200, 100])
    }

    @Test("小節頭でテンポを落としても次の拍間隔を維持する")
    func testSlowerSectionUsesItsFullFirstBeatInterval() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                name: "Tempo Boundary",
                sections: [
                    ProgramSection(name: "Fast", meter: MeterPattern(numerator: 1, denominator: 32), bpm: 400),
                    ProgramSection(name: "Slow", meter: MeterPattern(numerator: 1, denominator: 32), bpm: 100)
                ],
                loops: true
            )
        )

        var tickTimes: [UInt64] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.tempoBoundary")
        engine.onTick = { _, _, tickTime in
            recordingQueue.sync {
                tickTimes.append(tickTime.uptimeNanoseconds)
            }
        }

        engine.start()
        try await Task.sleep(nanoseconds: 280_000_000)
        engine.stop()

        let times = recordingQueue.sync { tickTimes }
        #expect(times.count >= 3)
        let firstSlowInterval = Double(times[2] - times[1]) / 1_000_000_000
        #expect(firstSlowInterval > 0.06)
    }

    @Test("複合拍子プログラムがセクションの小節数通りに進むかテスト")
    func testCompositeProgramAdvancesBySectionBars() async throws {
        let engine = MetronomeEngine()
        let program = MetronomeProgram(
            name: "Composite",
            sections: [
                ProgramSection(name: "A", meter: MeterPattern(numerator: 1, denominator: 32), bpm: 400, bars: 2),
                ProgramSection(name: "B", meter: MeterPattern(numerator: 2, denominator: 32), bpm: 400, bars: 1)
            ],
            loops: true
        )
        engine.applyProgram(program)

        var recordedPositions: [(Int, Int, String)] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.compositeAdvance")
        engine.onMeasureStart = { sectionIndex, barIndex, section, _ in
            recordingQueue.sync {
                recordedPositions.append((sectionIndex, barIndex, section.name))
            }
        }

        engine.start()
        try await Task.sleep(nanoseconds: 280_000_000)
        engine.stop()

        let positions = recordingQueue.sync {
            recordedPositions
        }

        #expect(positions.count >= 3)
        #expect(positions.prefix(3).map { $0.0 } == [0, 1, 0])
        #expect(positions.prefix(3).map { $0.1 } == [1, 0, 0])
        #expect(positions.prefix(3).map { $0.2 } == ["A", "B", "A"])
    }

    @Test("次小節キューが小節境界でプログラムごと適用されるかテスト")
    func testQueuedProgramAppliesAtNextMeasure() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                name: "Base",
                sections: [
                    ProgramSection(
                        name: "Base",
                        meter: MeterPattern(numerator: 1, denominator: 32),
                        bpm: 400,
                        bars: 8,
                        referenceNoteMultiplier: 0.125
                    )
                ],
                loops: true
            )
        )

        let queuedProgram = MetronomeProgram(
            name: "Queued",
            sections: [
                ProgramSection(
                    name: "QueuedA",
                    meter: MeterPattern(numerator: 3, denominator: 32),
                    bpm: 320,
                    bars: 1,
                    referenceNoteMultiplier: 0.125
                ),
                ProgramSection(
                    name: "QueuedB",
                    meter: MeterPattern(numerator: 4, denominator: 32),
                    bpm: 280,
                    bars: 1,
                    referenceNoteMultiplier: 0.125
                )
            ],
            loops: false
        )

        var firstAppliedSection: ProgramSection?
        var appliedProgramName: String?
        var firstAppliedBpm: Int?
        let recordingQueue = DispatchQueue(label: "metronome.test.queuedProgram")
        engine.onMeasureStart = { _, _, section, program in
            recordingQueue.sync {
                if firstAppliedSection == nil {
                    firstAppliedSection = section
                    appliedProgramName = program.name
                    firstAppliedBpm = engine.bpm
                }
            }
        }

        engine.start()
        engine.queueChangeForNextMeasure(QueuedMetronomeChange(program: queuedProgram))
        try await Task.sleep(nanoseconds: 600_000_000)
        engine.stop()

        let appliedState = recordingQueue.sync {
            (firstAppliedSection, appliedProgramName, firstAppliedBpm)
        }

        #expect(appliedState.0?.name == "QueuedA")
        #expect(appliedState.0?.meter.displayName == "3/32")
        #expect(appliedState.1 == "Queued")
        #expect(appliedState.2 == 320)
    }

    @Test("以前のプリセット形式は既定の終端動作で読み込まれる")
    func testLegacyProgramDecodesWithoutEndBehavior() throws {
        let encoded = try JSONEncoder().encode(MetronomeProgram.defaultProgram)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "endBehavior")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(MetronomeProgram.self, from: legacyData)

        #expect(decoded.endBehavior == .stop)
        #expect(decoded.sections.count == 1)
    }

    @Test("以前の小節予約形式は既定の終端動作で読み込まれる")
    func testLegacyQueuedChangeDecodesWithoutEndBehavior() throws {
        let encoded = try JSONEncoder().encode(QueuedMetronomeChange(section: ProgramSection()))
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "endBehavior")

        let decoded = try JSONDecoder().decode(
            QueuedMetronomeChange.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(decoded.endBehavior == .stop)
        #expect(decoded.section.bpm == 120)
    }

    @Test("ループしないプログラムは最後の小節で停止する")
    func testNonLoopingProgramStopsAtEnd() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                name: "One Shot",
                sections: [
                    ProgramSection(name: "A", meter: MeterPattern(numerator: 1, denominator: 32), bpm: 400, bars: 2)
                ],
                loops: false
            )
        )

        engine.start()
        try await Task.sleep(nanoseconds: 350_000_000)

        #expect(!engine.isPlaying)

        engine.start()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(engine.isPlaying)
        engine.stop()
    }

    @Test("テンポ変化の完了後は目標テンポを維持する")
    func testTempoAutomationHoldsTargetAfterFinishing() async throws {
        let engine = MetronomeEngine()
        engine.applyProgram(
            MetronomeProgram(
                name: "Tempo Hold",
                sections: [
                    ProgramSection(
                        name: "rit.",
                        meter: MeterPattern(numerator: 1, denominator: 32),
                        bpm: 400,
                        bars: 2,
                        tempoAutomation: TempoAutomation(shape: .ritardando, targetBpm: 100, lengthInBars: 2)
                    )
                ],
                loops: false,
                endBehavior: .holdLastSection
            )
        )

        engine.start()
        try await Task.sleep(nanoseconds: 350_000_000)

        #expect(engine.isPlaying)
        #expect(engine.bpm == 100)
        engine.stop()
    }
}
