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
    
    /// 四分音符を 1.0 とした基準音価の倍率
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
    
    var onTick: ((_ beat: Int, _ intensity: BeatIntensity, _ tickTime: DispatchTime) -> Void)?
    
    // MARK: - Logic Constants (UI側で参照可能にする)
    
    /// 最小単位（denominator）が刻まれる間隔（秒）
    private(set) var internalInterval: Double = 0.5
    /// 基準音符（BPMの単位）が最小単位何個分か
    private(set) var ticksPerMediumBeat: Int = 1

    private func updateConstants() {
        // 1. 最小単位（分母）の音価（例: 8分音符なら 0.5）
        let unitNoteValue = 4.0 / Double(denominator)
        
        // 2. 基準音符の中に最小単位がいくつ入るか（中拍の間隔）
        // 例: 基準が付点4分(1.5)、分母が8(0.5) のとき 1.5 / 0.5 = 3個
        ticksPerMediumBeat = max(1, Int(round(referenceNoteMultiplier / unitNoteValue)))
        
        // 3. 内部BPMの計算
        // 基準音符が1分間に BPM回 鳴るということは、1つの中拍の間隔は 60.0 / BPM 秒。
        // 最小単位の間隔は、それを ticksPerMediumBeat で割ったもの。
        let mediumBeatInterval = 60.0 / Double(bpm)
        internalInterval = mediumBeatInterval / Double(ticksPerMediumBeat)
        
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
        
        // 最初の1拍目が100ms後に鳴るように予定を立てる
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
        
        // 現在の周期を壊さないよう、次の予定時刻を計算
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
        
        let currentNumerator = numerator
        let currentTicksPerMedium = ticksPerMediumBeat
        let simplified = isSimplifiedMode
        lock.unlock()
        
        let totalTicksInMeasure = max(1, currentNumerator)
        let logicalBeat = ((currentTick - 1) % totalTicksInMeasure) + 1
        
        // 強弱判定
        var intensity: BeatIntensity
        if currentNumerator == 0 {
            intensity = (currentTick - 1) % currentTicksPerMedium == 0 ? .medium : .weak
        } else if logicalBeat == 1 {
            intensity = .strong
        } else if (logicalBeat - 1) % currentTicksPerMedium == 0 {
            intensity = .medium
        } else {
            intensity = .weak
        }
        
        // 通知
        if simplified {
            if intensity == .strong {
                onTick?(logicalBeat, .strong, tickTime)
            } else if intensity == .medium {
                onTick?(logicalBeat, .medium, tickTime)
            } else {
                onTick?(logicalBeat, .silence, tickTime)
            }
        } else {
            onTick?(logicalBeat, intensity, tickTime)
        }
    }
}
