//
//  MetronomeEngineTests.swift
//  watch_metronomeTests
//
//  Created by Gemini on 2026/05/18.
//

import Testing
import Foundation
@testable import watch_metronome

/// MetronomeEngine の挙動を検証するテスト
struct MetronomeEngineTests {

    @Test("4拍子の時、1拍目だけが強拍になるかテスト")
    func testFourFourTime() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600.0 // テストを早く終わらせるために速いテンポにします
        engine.numerator = 4
        
        var recordedBeats: [Int] = []
        var recordedStrongFlags: [Bool] = []
        
        // エンジンが鳴った時の記録を取る
        engine.onTick = { beat, isStrong in
            recordedBeats.append(beat)
            recordedStrongFlags.append(isStrong)
        }
        
        engine.start()
        
        // 4回鳴るまで少し待つ（非同期処理の待機）
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
        
        engine.stop()
        
        // --- 答え合わせ ---
        // 少なくとも4回以上は鳴っているはず
        #expect(recordedBeats.count >= 4)
        // 1拍目、2拍目、3拍目、4拍目と記録されているはず
        #expect(recordedBeats[0] == 1)
        #expect(recordedBeats[1] == 2)
        #expect(recordedBeats[2] == 3)
        #expect(recordedBeats[3] == 4)
        
        // 強拍の答え合わせ（1拍目だけが true）
        #expect(recordedStrongFlags[0] == true)
        #expect(recordedStrongFlags[1] == false)
        #expect(recordedStrongFlags[2] == false)
        #expect(recordedStrongFlags[3] == false)
    }

    @Test("分子が0の時、全て弱拍になるかテスト")
    func testZeroNumerator() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600.0
        engine.numerator = 0 // 強拍なし設定
        
        var strongCount = 0
        
        engine.onTick = { _, isStrong in
            if isStrong { strongCount += 1 }
        }
        
        engine.start()
        try await Task.sleep(nanoseconds: 300_000_000)
        engine.stop()
        
        // 強拍が一度も鳴っていない(0回)ことを確認
        #expect(strongCount == 0)
    }
    
    @Test("分子が1の時、全て強拍になるかテスト")
    func testOneNumerator() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600.0
        engine.numerator = 1 // 全て強拍設定
        
        var weakCount = 0
        
        engine.onTick = { _, isStrong in
            if !isStrong { weakCount += 1 }
        }
        
        engine.start()
        try await Task.sleep(nanoseconds: 300_000_000)
        engine.stop()
        
        // 弱拍が一度も鳴っていない(0回)ことを確認
        #expect(weakCount == 0)
    }
}
