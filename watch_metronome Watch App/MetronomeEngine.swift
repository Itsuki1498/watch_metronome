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
        // 1. 最小パルス単位の決定
        // 分母(Denom)と基準音符(Ref)を構成する最小公約数的な単位を探す
        // 簡単のため、分母、基準音符、および四分音符の公約数的な最小単位（例: 32分音符の倍数）を想定
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        
        // 最小刻み（パルス）は、分母と基準音符の短い方のさらに「割り切れる最小単位」とする
        // ここでは単純化しつつ、ご要望の「1.5拍」なども扱えるよう、0.125(32分音符)を最小解像度とする
        let pulseUnit = 0.125 
        
        // 2. 1小節内の総パルス数
        totalTicksInMeasure = max(1, Int(round((unitDenom * Double(numerator)) / pulseUnit)))
        
        // 3. 各項目のパルス換算
        ticksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        ticksPerRefNote = max(1, Int(round(unitRef / pulseUnit)))
        
        // 4. タイマー間隔 (BPMは基準音符基準)
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
        
        // --- 強制リセットロジック ---
        // 1小節（totalTicksInMeasure）を超えたら1に戻す（強制リセット）
        if tickCount > totalTicksInMeasure {
            tickCount = 1
            // 位相のズレを防ぐため、lastTickTimeを理論上の開始点に補正
            // ※ 厳密にはジッターがあるが、メトロノームとしては周期リセットが最優先
        }
        
        let currentTick = tickCount
        lastTickTime = tickTime
        
        let totalTicks = totalTicksInMeasure
        let outerStep = ticksPerOuterBeat
        let refStep = ticksPerRefNote
        let simplified = isSimplifiedMode
        lock.unlock()
        
        // 論理的な拍位置
        let tickIndex = currentTick - 1
        let logicalBeat = Double(tickIndex) / Double(outerStep) + 1.0
        
        // 強弱判定 (一生君の高度な例に対応)
        var intensity: BeatIntensity
        if tickIndex == 0 {
            intensity = .strong // 小節頭
        } else if tickIndex % refStep == 0 {
            intensity = .medium // 基準音符の節目 (中拍)
        } else if tickIndex % outerStep == 0 {
            intensity = .medium // 分母基準の節目
        } else {
            intensity = .weak   // その他
        }
        
        // 通知
        if simplified && intensity == .weak {
            onTick?(logicalBeat, .silence, tickTime)
        } else {
            onTick?(logicalBeat, intensity, tickTime)
        }
    }
}
