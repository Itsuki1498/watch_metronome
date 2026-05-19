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
    
    /// 最小単位（パルス）が刻まれる間隔（秒）
    private(set) var internalInterval: Double = 0.5
    /// 1小節の中に最小単位がいくつ入るか
    private(set) var totalTicksInMeasure: Int = 4
    /// メイン拍（分母基準）1拍あたりのパルス数
    private(set) var ticksPerOuterBeat: Int = 1
    /// 基準音符1拍あたりのパルス数
    private(set) var ticksPerRefNote: Int = 1

    private func updateConstants() {
        // --- 修正：32分固定を廃止し、必要最小限の単位を求める ---
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        
        // 分母と基準音符を割り切れる「最小公約数的音価」を求める
        // 音楽的な範囲（2分音符〜32分音符）で総当たりし、最小のパルスを決定
        let possibleUnits: [Double] = [2.0, 1.0, 0.5, 0.25, 0.125] // 2, 4, 8, 16, 32
        var pulseUnit = unitDenom
        for unit in possibleUnits {
            let isDivisible1 = abs((unitDenom / unit) - round(unitDenom / unit)) < 0.001
            let isDivisible2 = abs((unitRef / unit) - round(unitRef / unit)) < 0.001
            if isDivisible1 && isDivisible2 {
                pulseUnit = unit
            }
        }
        
        // 小節内の総パルス数
        totalTicksInMeasure = max(1, Int(round((unitDenom * Double(numerator)) / pulseUnit)))
        ticksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        ticksPerRefNote = max(1, Int(round(unitRef / pulseUnit)))
        
        // 基準音符基準のタイマー間隔
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
        
        // --- 強制リセットロジック ---
        if tickCount > totalTicksInMeasure {
            tickCount = 1
        }
        
        let currentTick = tickCount
        lastTickTime = tickTime
        
        let outerStep = ticksPerOuterBeat
        let refStep = ticksPerRefNote
        let simplified = isSimplifiedMode
        lock.unlock()
        
        // 最小単位のインデックス (0 〜 totalTicks-1)
        let tickIndex = currentTick - 1
        let logicalBeat = Double(tickIndex) / Double(outerStep) + 1.0
        
        // --- 強弱判定 ---
        var intensity: BeatIntensity
        if tickIndex == 0 {
            intensity = .strong // 小節頭
        } else if tickIndex % refStep == 0 {
            intensity = .medium // 基準音符（BPMパルス）の節目
        } else if tickIndex % outerStep == 0 {
            intensity = .medium // 拍（分母）の節目
        } else {
            intensity = .weak   // それ以外のパルス
        }
        
        if simplified && intensity == .weak {
            onTick?(logicalBeat, .silence, tickTime)
        } else {
            onTick?(logicalBeat, intensity, tickTime)
        }
    }
}
