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
    
    /// 簡易モード: 弱拍を消し、中拍を弱拍として扱う
    var isSimplifiedMode: Bool = false
    
    private(set) var isPlaying: Bool = false
    private var tickCount: Int = 0
    private var lastTickTime: DispatchTime = .now()
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
    private let lock = NSRecursiveLock()
    
    var onTick: ((_ beat: Int, _ intensity: BeatIntensity) -> Void)?
    
    // MARK: - Logic Constants
    
    /// 常に最小単位（分母）の間隔でタイマーを回す
    private var internalInterval: Double = 0.5
    private var ticksPerMediumBeat: Int = 1

    private func updateConstants() {
        // 最小単位（分母）の音価（例: 8分音符なら0.5）
        let unitNoteValue = 4.0 / Double(denominator)
        
        // 内部BPM = 表示BPM * (基準音価 / 最小単位)
        // 例: 付点4分(1.5)=120, 12/8(0.5) のとき 120 * (1.5/0.5) = 360
        let internalBpm = Double(bpm) * (referenceNoteMultiplier / unitNoteValue)
        
        // 中拍の間隔（最小単位何個分で基準音符になるか）
        ticksPerMediumBeat = max(1, Int(round(referenceNoteMultiplier / unitNoteValue)))
        
        // **重要**: テンポを維持するため、簡易モードでもタイマー間隔は「最小単位」で固定
        internalInterval = 60.0 / internalBpm
        
        if isPlaying { updateTimerSchedule(isRestart: true) }
    }
    
    // MARK: - Methods
    
    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPlaying else { return }
        
        isPlaying = true
        tickCount = 0
        lastTickTime = .now()
        updateConstants()
        
        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        updateTimerSchedule(isRestart: false)
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    private func updateTimerSchedule(isRestart: Bool) {
        let deadline: DispatchTime
        if isRestart {
            let nextTime = lastTickTime + internalInterval
            deadline = nextTime < .now() ? .now() : nextTime
        } else {
            deadline = .now() + .milliseconds(100)
            lastTickTime = deadline - internalInterval
        }
        timer?.schedule(deadline: deadline, repeating: internalInterval, leeway: .nanoseconds(0))
    }
    
    private func tick() {
        lock.lock()
        guard isPlaying else {
            lock.unlock()
            return
        }
        
        tickCount += 1
        let currentTick = tickCount
        lastTickTime = .now()
        
        let currentNumerator = numerator
        let currentTicksPerMedium = ticksPerMediumBeat
        let simplified = isSimplifiedMode
        lock.unlock()
        
        // 論理的な拍位置 (1 〜 numerator)
        let totalTicksInMeasure = max(1, currentNumerator)
        let logicalBeat = ((currentTick - 1) % totalTicksInMeasure) + 1
        
        // --- 強弱ロジックの決定 ---
        var intensity: BeatIntensity
        if currentNumerator == 0 {
            intensity = .weak
        } else if logicalBeat == 1 {
            intensity = .strong
        } else if (logicalBeat - 1) % currentTicksPerMedium == 0 {
            // 基準音符の節目
            intensity = .medium
        } else {
            // 最小単位の刻み
            intensity = .weak
        }
        
        // --- 簡易モード（弱拍ミュート）の適用 ---
        if simplified {
            if intensity == .strong {
                // 強拍はそのまま
                onTick?(logicalBeat, .strong)
            } else if intensity == .medium {
                // 中拍はそのまま（ViewModel側で振動だけ弱める）
                onTick?(logicalBeat, .medium)
            } else {
                // 弱拍のタイミングでも通知は送る（UIを動かすため）
                // ただし強さを .silence にすることで振動を消す
                onTick?(logicalBeat, .silence)
            }
        } else {
            // 通常モード
            onTick?(logicalBeat, intensity)
        }
    }
}
