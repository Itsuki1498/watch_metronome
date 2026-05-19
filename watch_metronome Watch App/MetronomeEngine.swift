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
    case strong   // 強拍 (1拍目)
    case medium   // 中拍 (基準音符の節目)
    case weak     // 弱拍 (最小単位の刻み)
    case silence  // 無音 (簡易モードでのスキップ用)
}

/// メトロノームのリズム生成を担うエンジン
@Observable
final class MetronomeEngine {
    
    // MARK: - Properties (設定値)
    
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
    
    var isSimplifiedMode: Bool = false
    
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
        
        // 音楽的な範囲で共通の最小パルスを動的に決定
        let possibleUnits: [Double] = [2.0, 1.0, 0.5, 0.25, 0.125] // 2, 4, 8, 16, 32
        var pulseUnit = unitDenom
        for unit in possibleUnits {
            let ratioDenom = unitDenom / unit
            let ratioRef = unitRef / unit
            if abs(ratioDenom - round(ratioDenom)) < 0.0001 && 
               abs(ratioRef - round(ratioRef)) < 0.0001 {
                pulseUnit = unit
                break // 最大公約数（荒い単位）を見つけたら終了
            }
        }
        
        totalTicksInMeasure = max(1, Int(round((unitDenom * Double(numerator)) / pulseUnit)))
        ticksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        ticksPerRefNote = max(1, Int(round(unitRef / pulseUnit)))
        
        // 基準音符1回 = ticksPerRefNoteパルス
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
        // 強制リセット: 小節頭で位相を合わせる
        if tickCount > totalTicksInMeasure {
            tickCount = 1
        }
        
        let currentTick = tickCount
        lastTickTime = tickTime
        
        let outerStep = ticksPerOuterBeat
        let refStep = ticksPerRefNote
        let simplified = isSimplifiedMode
        lock.unlock()
        
        let tickIndex = currentTick - 1
        let logicalBeat = Double(tickIndex) / Double(outerStep) + 1.0
        
        // --- 修正：一生君の要件に基づく強弱優先順位 ---
        var intensity: BeatIntensity
        if tickIndex == 0 {
            intensity = .strong // 1. 小節頭が最優先
        } else if tickIndex % refStep == 0 {
            intensity = .medium // 2. 基準音符の節目 (中拍)
        } else {
            intensity = .weak   // 3. その他
        }
        
        // 通知
        if simplified && intensity == .weak {
            onTick?(logicalBeat, .silence, tickTime)
        } else {
            onTick?(logicalBeat, intensity, tickTime)
        }
    }
}
