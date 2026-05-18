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
    let multiplier: Double // 四分音符を 1.0 とした倍率
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
    
    /// 弱拍を消す（簡易表示）モード
    var isSimplifiedMode: Bool {
        get { engine.isSimplifiedMode }
        set { engine.isSimplifiedMode = newValue }
    }
    
    /// 現在のBPM
    var bpm: Int {
        get { engine.bpm }
        set { engine.bpm = newValue }
    }

    /// Digital Crown操作用のBPM (Double)
    var displayBpm: Double {
        get { Double(engine.bpm) }
        set { 
            let newIntValue = Int(newValue)
            if newIntValue != engine.bpm { engine.bpm = newIntValue }
        }
    }
    
    /// Digital Crown操作用の分子
    var displayNumerator: Double {
        get { Double(engine.numerator) }
        set { 
            let newIntValue = Int(newValue)
            if newIntValue != engine.numerator { engine.numerator = newIntValue }
        }
    }
    
    /// Digital Crown操作用の分母インデックス
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
    
    /// Digital Crown操作用の音価インデックス
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
    
    var noteValueIndex: Int = 4 { // デフォルトは四分音符
        didSet {
            engine.referenceNoteMultiplier = noteValueOptions[noteValueIndex].multiplier
        }
    }
    
    /// 動作状態
    var isPlaying: Bool { engine.isPlaying }
    
    /// 現在の拍数と強さ
    var currentBeat: Int = 1
    var currentIntensity: BeatIntensity = .weak
    
    /// 各種設定値
    var numerator: Int { engine.numerator }
    var denominator: Int { engine.denominator }
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
        engine.onTick = { [weak self] (beat: Int, intensity: BeatIntensity) in
            // 振動の使い分け
            if self?.isSimplifiedMode == true {
                // 簡易モード時
                switch intensity {
                case .strong:  self?.hapticManager.playStrong()
                case .medium:  self?.hapticManager.playWeak() // 中拍を弱拍の振動にする
                default:       break // 弱拍(weak)や無音(silence)は振動させない
                }
            } else {
                // 通常モード時
                switch intensity {
                case .strong:  self?.hapticManager.playStrong()
                case .medium:  self?.hapticManager.playMedium()
                case .weak:    self?.hapticManager.playWeak()
                case .silence: break
                }
            }
            
            DispatchQueue.main.async {
                self?.currentBeat = beat
                self?.currentIntensity = intensity
            }
        }
    }
    
    private func syncNoteValueToDenominator() {
        let targetName = "\(engine.denominator)"
        if let index = noteValueOptions.firstIndex(where: { $0.name == targetName }) {
            noteValueIndex = index
        }
    }
    
    // MARK: - Actions
    
    func togglePlayback() {
        if engine.isPlaying { engine.stop() }
        else { engine.start() }
    }
}
