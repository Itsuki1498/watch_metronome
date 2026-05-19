//
//  MetronomeViewModel.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import SwiftUI
import Observation

/// 音価の定義
struct NoteValue: Hashable {
    let name: String
    let multiplier: Double
    let imageName: String
    let isDotted: Bool
    let displayHeight: CGFloat // SwiftUI の型を使用するため import SwiftUI が必要
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
    
    /// リズムモード (全て / 強・中 / 強のみ)
    var rhythmMode: RhythmMode {
        get { engine.rhythmMode }
        set { engine.rhythmMode = newValue }
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
    
    /// --- 同期された状態プロパティ ---
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
        NoteValue(name: "全", multiplier: 4.0, imageName: "note_whole", isDotted: false, displayHeight: 10),
        NoteValue(name: "付2", multiplier: 3.0, imageName: "note_half_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "2", multiplier: 2.0, imageName: "note_half", isDotted: false, displayHeight: 24),
        NoteValue(name: "付4", multiplier: 1.5, imageName: "note_quarter_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "4", multiplier: 1.0, imageName: "note_quarter", isDotted: false, displayHeight: 24),
        NoteValue(name: "付8", multiplier: 0.75, imageName: "note_eighth_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "8", multiplier: 0.5, imageName: "note_eighth", isDotted: false, displayHeight: 24),
        NoteValue(name: "付16", multiplier: 0.375, imageName: "note_sixteenth_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "16", multiplier: 0.25, imageName: "note_sixteenth", isDotted: false, displayHeight: 24),
        NoteValue(name: "32", multiplier: 0.125, imageName: "note_32nd", isDotted: false, displayHeight: 24)
    ]
    
    var validNoteValueOptions: [NoteValue] = []
    
    var currentNote: NoteValue {
        noteValueOptions[noteValueIndex]
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
    
    private func refreshValidNoteValues() {
        let unitDenom = 4.0 / Double(engine.denominator)
        validNoteValueOptions = noteValueOptions.filter { note in
            let m = note.multiplier
            let ratio1 = m / unitDenom
            let ratio2 = unitDenom / m
            return abs(ratio1 - round(ratio1)) < 0.001 || abs(ratio2 - round(ratio2)) < 0.001
        }
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
    
    // MARK: - Actions
    
    func nextRhythmMode() {
        let allModes = RhythmMode.allCases
        let currentIndex = rhythmMode.rawValue
        let nextIndex = (currentIndex + 1) % allModes.count
        rhythmMode = allModes[nextIndex]
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
