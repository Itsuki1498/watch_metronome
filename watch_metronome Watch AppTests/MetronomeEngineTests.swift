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
struct MetronomeEngineTests {

    @Test("4拍子の時、1拍目だけが強拍になるかテスト")
    func testFourFourTime() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600 // テストを早く終わらせるために速いテンポにします
        engine.numerator = 4
        
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
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
        
        engine.stop()
        
        // --- 答え合わせ ---
        // 少なくとも4回以上は鳴っているはず
        let (beats, strongFlags) = recordingQueue.sync {
            (recordedBeats, recordedStrongFlags)
        }
        
        #expect(beats.count >= 4)
        // 1拍目、2拍目、3拍目、4拍目と記録されているはず
        #expect(beats[0] == 1)
        #expect(beats[1] == 2)
        #expect(beats[2] == 3)
        #expect(beats[3] == 4)
        
        // 強拍の答え合わせ（1拍目だけが true）
        #expect(strongFlags[0] == true)
        #expect(strongFlags[1] == false)
        #expect(strongFlags[2] == false)
        #expect(strongFlags[3] == false)
    }

    @Test("分子が0の時、1拍子に補正されるかテスト")
    func testZeroNumeratorClampsToOne() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600
        engine.numerator = 0
        
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
        engine.bpm = 600
        engine.numerator = 1 // 全て強拍設定
        
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

    @Test("テンポ変化が指定小節数の最終小節で目標BPMに到達するかテスト")
    func testTempoAutomationReachesTargetOnFinalBar() async throws {
        let engine = MetronomeEngine()
        let section = ProgramSection(
            name: "rit.",
            meter: MeterPattern(numerator: 1, denominator: 4),
            bpm: 400,
            bars: 4,
            tempoAutomation: TempoAutomation(shape: .ritardando, targetBpm: 100, lengthInBars: 4)
        )
        engine.applyProgram(MetronomeProgram(name: "Tempo", sections: [section], loops: false))

        var recordedBpms: [Int] = []
        let recordingQueue = DispatchQueue(label: "metronome.test.tempoAutomation")
        engine.onMeasureStart = { _, _, _ in
            recordingQueue.sync {
                recordedBpms.append(engine.bpm)
            }
        }

        engine.start()
        try await Task.sleep(nanoseconds: 700_000_000)
        engine.stop()

        let bpms = recordingQueue.sync {
            recordedBpms
        }

        #expect(Array(bpms.prefix(3)) == [300, 200, 100])
    }
}
