//
//  MetronomeEngine.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import Foundation
import Observation
import WatchKit

/// 拍の強さ
enum BeatIntensity {
    case strong   // 強拍
    case medium   // 中拍
    case weak     // 弱拍
    case silence  // 無音
}

/// 演奏モード（順序：全て -> 強中 -> 強のみ）
enum RhythmMode: Int, CaseIterable {
    case all = 0         // 全ての拍
    case strongMedium = 1 // 強拍 + 中拍 (弱拍ミュート)
    case strongOnly = 2   // 強拍のみ (中・弱拍ミュート)
}

/// メトロノームのリズム生成を担う engine
@Observable
final class MetronomeEngine {
    
    // MARK: - Properties
    
    var bpm: Int = 120 {
        didSet { updateConstants() }
    }
    
    var numerator: Int = 4 {
        didSet { updateConstants() }
    }
    
    var denominator: Int = 4 {
        didSet { updateConstants() }
    }
    
    var referenceNoteMultiplier: Double = 1.0 {
        didSet { updateConstants() }
    }
    
    var rhythmMode: RhythmMode = .all
    
    private(set) var isPlaying: Bool = false
    private var tickCount: Int = 0
    private(set) var lastTickTime: DispatchTime = .now()
    
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
    private let lock = NSRecursiveLock()
    
    var onTick: ((_ beat: Double, _ intensity: BeatIntensity, _ tickTime: DispatchTime) -> Void)?
    
    // MARK: - Logic Constants
    
    private(set) var internalInterval: Double = 0.5
    private(set) var totalTicksInMeasure: Int = 4
    private(set) var ticksPerOuterBeat: Int = 1
    private(set) var ticksPerRefNote: Int = 1

    private func updateConstants() {
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        let pulseUnit = 0.125 
        
        totalTicksInMeasure = max(1, Int(round((unitDenom * Double(numerator)) / pulseUnit)))
        ticksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        ticksPerRefNote = max(1, Int(round(unitRef / pulseUnit)))
        
        internalInterval = (60.0 / Double(bpm)) / Double(ticksPerRefNote)
        
        if isPlaying { updateTimerSchedule(isRestart: true) }
    }
    
    // MARK: - Methods
    
    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPlaying else { return }
        
        isPlaying = true
        tickCount = 0
        updateConstants()
        
        let deadline = DispatchTime.now() + .milliseconds(100)
        lastTickTime = deadline
        
        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        timer?.schedule(deadline: deadline, repeating: internalInterval, leeway: .nanoseconds(0))
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    private func updateTimerSchedule(isRestart: Bool) {
        guard isPlaying else { return }
        let nextTime = lastTickTime + internalInterval
        let deadline = nextTime < .now() ? .now() : nextTime
        timer?.schedule(deadline: deadline, repeating: internalInterval, leeway: .nanoseconds(0))
    }
    
    private func tick() {
        let tickTime = DispatchTime.now()
        lock.lock()
        guard isPlaying else {
            lock.unlock()
            return
        }
        
        tickCount += 1
        if tickCount > totalTicksInMeasure {
            tickCount = 1
        }
        
        let currentTick = tickCount
        lastTickTime = tickTime
        
        let outerStep = ticksPerOuterBeat
        let refStep = ticksPerRefNote
        let mode = rhythmMode
        let currentNumerator = numerator
        
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        let isRefMultiple = (unitRef / unitDenom) >= 0.999 && abs((unitRef / unitDenom) - round(unitRef / unitDenom)) < 0.001
        
        lock.unlock()
        
        let tickIndex = currentTick - 1
        let logicalBeat = Double(tickIndex) / Double(outerStep) + 1.0
        
        // 強弱判定
        var rawIntensity: BeatIntensity
        if tickIndex == 0 && currentNumerator != 0 {
            rawIntensity = .strong
        } else if isRefMultiple {
            if tickIndex % refStep == 0 { rawIntensity = .medium }
            else if tickIndex % outerStep == 0 { rawIntensity = .weak }
            else { rawIntensity = .silence }
        } else {
            if tickIndex % outerStep == 0 { rawIntensity = .medium }
            else if tickIndex % refStep == 0 { rawIntensity = .weak }
            else { rawIntensity = .silence }
        }
        
        // モードによるフィルタリング
        var finalIntensity: BeatIntensity = rawIntensity
        switch mode {
        case .all:
            break
        case .strongMedium:
            if rawIntensity == .weak { finalIntensity = .silence }
        case .strongOnly:
            if rawIntensity != .strong { finalIntensity = .silence }
        }
        
        onTick?(logicalBeat, finalIntensity, tickTime)
    }
}
