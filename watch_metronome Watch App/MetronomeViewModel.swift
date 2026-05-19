//
//  MetronomeViewModel.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import Foundation
import Observation

/// 音価の定義
struct NoteValue: Hashable {
    let name: String
    let multiplier: Double
}

/// メトロノームの画面状態と操作を管理するViewModel
@Observable
final class MetronomeViewModel {
    
    // MARK: - Properties
    
    private let engine = MetronomeEngine()
    private let hapticManager = HapticManager()
    
    var isSystemReady: Bool = false
    
    enum EditTarget: Hashable {
        case bpm, numerator, denominator, noteValue
    }
    
    var isSimplifiedMode: Bool {
        get { engine.isSimplifiedMode }
        set { engine.isSimplifiedMode = newValue }
    }
    
    var bpm: Int {
        get { engine.bpm }
        set { engine.bpm = newValue }
    }

    var displayBpm: Double {
        get { Double(engine.bpm) }
        set { 
            let newIntValue = Int(newValue)
            if newIntValue != engine.bpm { engine.bpm = newIntValue }
        }
    }
    
    var displayNumerator: Double {
        get { Double(engine.numerator) }
        set { 
            let newIntValue = Int(newValue)
            if newIntValue != engine.numerator { engine.numerator = newIntValue }
        }
    }
    
    var displayDenominatorIndex: Double {
        get { Double(denominatorOptions.firstIndex(of: engine.denominator) ?? 1) }
        set { 
            let index = Int(newValue)
            if index >= 0 && index < denominatorOptions.count {
                let newDenom = denominatorOptions[index]
                if newDenom != engine.denominator {
                    engine.denominator = newDenom
                    syncNoteValueToDenominator()
                }
            }
        }
    }
    
    var displayNoteValueIndex: Double {
        get { Double(noteValueIndex) }
        set { 
            let index = Int(newValue)
            if index >= 0 && index < noteValueOptions.count {
                if index != noteValueIndex {
                    noteValueIndex = index
                }
            }
        }
    }
    
    var noteValueIndex: Int = 4 {
        didSet {
            engine.referenceNoteMultiplier = noteValueOptions[noteValueIndex].multiplier
        }
    }
    
    var isPlaying: Bool { engine.isPlaying }
    
    /// --- 同期された状態プロパティ ---
    var currentBeat: Int = 1
    var currentIntensity: BeatIntensity = .weak
    var lastTickTime: DispatchTime = .now()
    
    /// --- エンジンの不変条件を一括公開 ---
    var numerator: Int { engine.numerator }
    var denominator: Int { engine.denominator }
    var ticksPerMediumBeat: Int { engine.ticksPerMediumBeat }
    var tickInterval: Double { engine.internalInterval }
    /// --------------------------
    
    let denominatorOptions = [2, 4, 8, 16, 32]
    
    let noteValueOptions: [NoteValue] = [
        NoteValue(name: "全", multiplier: 4.0),
        NoteValue(name: "付2", multiplier: 3.0),
        NoteValue(name: "2", multiplier: 2.0),
        NoteValue(name: "付4", multiplier: 1.5),
        NoteValue(name: "4", multiplier: 1.0),
        NoteValue(name: "付8", multiplier: 0.75),
        NoteValue(name: "8", multiplier: 0.5),
        NoteValue(name: "付16", multiplier: 0.375),
        NoteValue(name: "16", multiplier: 0.25),
        NoteValue(name: "32", multiplier: 0.125)
    ]
    
    var currentNoteName: String {
        noteValueOptions[noteValueIndex].name
    }
    
    // MARK: - Initialization
    
    init() {
        setupEngine()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSystemReady = true
        }
    }
    
    private func setupEngine() {
        engine.onTick = { [weak self] (beat: Int, intensity: BeatIntensity, tickTime: DispatchTime) in
            // 1. 振動はバックグラウンドスレッドで即座に実行
            if self?.isSimplifiedMode == true {
                switch intensity {
                case .strong: self?.hapticManager.playStrong()
                case .medium: self?.hapticManager.playMedium()
                default: break
                }
            } else {
                switch intensity {
                case .strong:  self?.hapticManager.playStrong()
                case .medium:  self?.hapticManager.playMedium()
                case .weak:    self?.hapticManager.playWeak()
                case .silence: break
                }
            }
            
            // 2. UI状態を完全に同期してメインスレッドへ
            DispatchQueue.main.async {
                self?.currentBeat = beat
                self?.currentIntensity = intensity
                self?.lastTickTime = tickTime
            }
        }
    }
    
    private func syncNoteValueToDenominator() {
        let targetMultiplier: Double
        switch engine.denominator {
        case 2: targetMultiplier = 2.0
        case 4: targetMultiplier = 1.0
        case 8: targetMultiplier = 0.5
        case 16: targetMultiplier = 0.25
        case 32: targetMultiplier = 0.125
        default: targetMultiplier = 1.0
        }
        
        if let index = noteValueOptions.firstIndex(where: { $0.multiplier == targetMultiplier }) {
            noteValueIndex = index
        }
    }
    
    func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
        } else {
            engine.start()
            // 開始時に状態をクリーンに同期
            self.currentBeat = 1
            self.currentIntensity = .strong
            self.lastTickTime = engine.lastTickTime
        }
    }
}
