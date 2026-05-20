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
        let lock = NSLock()
        
        // エンジンが鳴った時の記録を取る
        engine.onTick = { beat, intensity, _ in
            guard intensity != .silence else { return }
            lock.lock()
            recordedBeats.append(Int(beat))
            recordedStrongFlags.append(intensity == .strong)
            lock.unlock()
        }
        
        engine.start()
        
        // 4回鳴るまで少し待つ（非同期処理の待機）
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
        
        engine.stop()
        
        // --- 答え合わせ ---
        // 少なくとも4回以上は鳴っているはず
        lock.lock()
        let beats = recordedBeats
        let strongFlags = recordedStrongFlags
        lock.unlock()
        
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

    @Test("分子が0の時、全て弱拍になるかテスト")
    func testZeroNumerator() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600
        engine.numerator = 0 // 強拍なし設定
        
        var strongCount = 0
        let lock = NSLock()
        
        engine.onTick = { _, intensity, _ in
            if intensity == .strong {
                lock.lock()
                strongCount += 1
                lock.unlock()
            }
        }
        
        engine.start()
        try await Task.sleep(nanoseconds: 300_000_000)
        engine.stop()
        
        // 強拍が一度も鳴っていない(0回)ことを確認
        lock.lock()
        let recordedStrongCount = strongCount
        lock.unlock()
        #expect(recordedStrongCount == 0)
    }
    
    @Test("分子が1の時、全て強拍になるかテスト")
    func testOneNumerator() async throws {
        let engine = MetronomeEngine()
        engine.bpm = 600
        engine.numerator = 1 // 全て強拍設定
        
        var weakCount = 0
        let lock = NSLock()
        
        engine.onTick = { _, intensity, _ in
            guard intensity != .silence else { return }
            if intensity != .strong {
                lock.lock()
                weakCount += 1
                lock.unlock()
            }
        }
        
        engine.start()
        try await Task.sleep(nanoseconds: 300_000_000)
        engine.stop()
        
        // 弱拍が一度も鳴っていない(0回)ことを確認
        lock.lock()
        let recordedWeakCount = weakCount
        lock.unlock()
        #expect(recordedWeakCount == 0)
    }
}
