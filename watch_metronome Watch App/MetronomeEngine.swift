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
    case medium   // 中拍 (分母基準のメイン拍 2, 3, 4...)
    case weak     // 弱拍 (基準音符基準の裏拍など)
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
    
    // MARK: - Logic Constants (UI側で参照可能にする)
    
    /// 最小単位（パルス）が刻まれる間隔（秒）
    private(set) var internalInterval: Double = 0.5
    
    /// 1小節の中に最小単位がいくつ入るか
    private(set) var totalTicksInMeasure: Int = 4
    
    /// 外側リング（分母基準）の1セグメントが、最小単位何個分か
    private(set) var ticksPerOuterBeat: Int = 1

    private func updateConstants() {
        // 1. 最小単位（パルス）の決定
        // 分母(Denom)と基準音符(Ref)のうち、短い方を最小の刻み単位とする
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        let pulseUnit = min(unitDenom, unitRef)
        
        // 2. 1小節内の総パルス数
        // (分母音価 * 分子) / 最小パルス
        totalTicksInMeasure = max(1, Int(round((unitDenom * Double(numerator)) / pulseUnit)))
        
        // 3. 外側ビート（分母基準）1拍あたりのパルス数
        ticksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        
        // 4. タイマー間隔 (BPMは基準音符が1分間に鳴る回数)
        // 1パルスの時間 = (60 / BPM) * (最小パルス / 基準音符)
        internalInterval = (60.0 / Double(bpm)) * (pulseUnit / unitRef)
        
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
        let currentTick = tickCount
        lastTickTime = tickTime
        
        let totalTicks = totalTicksInMeasure
        let outerStep = ticksPerOuterBeat
        let simplified = isSimplifiedMode
        lock.unlock()
        
        // 論理的な拍（1, 1.5, 2... のように表現するためにDoubleを使用）
        // 最小単位のインデックス (0 〜 totalTicks-1)
        let tickIndex = (currentTick - 1) % totalTicks
        let logicalBeat = Double(tickIndex) / Double(outerStep) + 1.0
        
        // 強弱判定
        var intensity: BeatIntensity
        if tickIndex == 0 {
            intensity = .strong // 1拍目
        } else if tickIndex % outerStep == 0 {
            intensity = .medium // 2, 3, 4拍目
        } else {
            intensity = .weak   // それ以外のパルス（裏拍など）
        }
        
        // 通知
        if simplified && intensity == .weak {
            onTick?(logicalBeat, .silence, tickTime)
        } else {
            onTick?(logicalBeat, intensity, tickTime)
        }
    }
}
