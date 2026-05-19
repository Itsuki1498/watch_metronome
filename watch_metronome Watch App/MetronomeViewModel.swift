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
            // 分子を変えたら選択可能な基準音符を再フィルタリング
            refreshValidNoteValues()
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
                    // 分母を変えたら選択可能な基準音符を再フィルタリング
                    refreshValidNoteValues()
                    syncNoteValueToDenominator()
                }
            }
        }
    }
    
    var displayNoteValueIndex: Double {
        get { Double(validNoteValueOptions.firstIndex(of: noteValueOptions[noteValueIndex]) ?? 0) }
        set { 
            let index = Int(newValue)
            if index >= 0 && index < validNoteValueOptions.count {
                let selectedNote = validNoteValueOptions[index]
                if let masterIndex = noteValueOptions.firstIndex(of: selectedNote) {
                    noteValueIndex = masterIndex
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
    
    var currentBeat: Double = 1.0
    var currentIntensity: BeatIntensity = .weak
    var lastTickTime: DispatchTime = .now()
    
    var numerator: Int { engine.numerator }
    var denominator: Int { engine.denominator }
    var totalTicksInMeasure: Int { engine.totalTicksInMeasure }
    var ticksPerOuterBeat: Int { engine.ticksPerOuterBeat }
    var ticksPerRefNote: Int { engine.ticksPerRefNote }
    var tickInterval: Double { engine.internalInterval }
    
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
    
    /// 現在の分母に対して有効な（整数倍または整数分の1になる）音価のみを表示
    var validNoteValueOptions: [NoteValue] = []
    
    var currentNoteName: String {
        noteValueOptions[noteValueIndex].name
    }
    
    // MARK: - Initialization
    
    init() {
        refreshValidNoteValues()
        setupEngine()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSystemReady = true
        }
    }
    
    private func setupEngine() {
        engine.onTick = { [weak self] (beat: Double, intensity: BeatIntensity, tickTime: DispatchTime) in
            switch intensity {
            case .strong: self?.hapticManager.playStrong()
            case .medium: self?.hapticManager.playMedium()
            case .weak:   self?.hapticManager.playWeak()
            case .silence: break
            }
            
            DispatchQueue.main.async {
                self?.currentBeat = beat
                self?.currentIntensity = intensity
                self?.lastTickTime = tickTime
            }
        }
    }
    
    /// 有効な音価リストを更新
    private func refreshValidNoteValues() {
        let unitDenom = 4.0 / Double(engine.denominator)
        let measureLength = unitDenom * Double(engine.numerator)
        let minResolution = 0.125 // 32分音符
        
        validNoteValueOptions = noteValueOptions.filter { note in
            let m = note.multiplier
            
            // 1. 1小節を超える音価は（練習用メトロノームとしては）不適切なので除外
            if m > measureLength + 0.001 { return false }
            
            // 2. 最小解像度(0.125)で、その音価と分母単位の両方が割り切れるか
            //    これにより、パルスとして数学的に矛盾なく刻めることが保証される
            let rNote = m / minResolution
            let rDenom = unitDenom / minResolution
            
            let isNoteResolvable = abs(rNote - round(rNote)) < 0.001
            let isDenomResolvable = abs(rDenom - round(rDenom)) < 0.001
            
            return isNoteResolvable && isDenomResolvable
        }
        
        // 現在の選択がリスト外になったら安全な値（分母相当）に強制
        if !validNoteValueOptions.contains(noteValueOptions[noteValueIndex]) {
            syncNoteValueToDenominator()
        }
    }
    
    private func syncNoteValueToDenominator() {
        let unitDenom = 4.0 / Double(engine.denominator)
        if let index = noteValueOptions.firstIndex(where: { abs($0.multiplier - unitDenom) < 0.001 }) {
            noteValueIndex = index
        }
    }
    
    func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
        } else {
            engine.start()
            self.currentBeat = 1.0
            self.currentIntensity = .strong
            self.lastTickTime = engine.lastTickTime
        }
    }
}
