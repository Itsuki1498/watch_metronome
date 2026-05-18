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
    case strong // 強拍 (1拍目)
    case medium // 中拍 (基準音符の節目)
    case weak   // 弱拍 (最小単位の刻み)
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
    
    var isSimplifiedMode: Bool = false {
        didSet { if isPlaying { updateTimerSchedule(isRestart: true) } }
    }
    
    private(set) var isPlaying: Bool = false
    private var tickCount: Int = 0
    private var lastTickTime: DispatchTime = .now()
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
    private let lock = NSRecursiveLock()
    
    var onTick: ((_ beat: Int, _ intensity: BeatIntensity) -> Void)?
    
    // MARK: - Logic Constants
    
    private var internalInterval: Double = 0.5
    private var ticksPerMediumBeat: Int = 1

    private func updateConstants() {
        // 分母に応じた基準音価（例: 四分音符=1.0）
        let baseNoteValue = 4.0 / Double(denominator)
        
        // 内部BPM = 表示BPM * (基準音価倍率 / (4.0 / 分母))
        let internalBpm = Double(bpm) * (referenceNoteMultiplier / baseNoteValue)
        
        // 中拍の間隔（最小単位何個分か）
        ticksPerMediumBeat = max(1, Int(round(referenceNoteMultiplier / baseNoteValue)))
        
        // 刻み間隔
        if isSimplifiedMode {
            internalInterval = 60.0 / (internalBpm / Double(ticksPerMediumBeat))
        } else {
            internalInterval = 60.0 / internalBpm
        }
        
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
            // 最初の1拍目が100ms後に鳴るように
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
        let step = isSimplifiedMode ? ticksPerMediumBeat : 1
        lock.unlock()
        
        // 論理的な拍位置 (1 〜 numerator)
        let totalTicksInMeasure = max(1, currentNumerator)
        let logicalBeat = ((currentTick - 1) * step) % totalTicksInMeasure + 1
        
        // 強弱判定
        let intensity: BeatIntensity
        if currentNumerator == 0 {
            intensity = .weak // 0拍子の時は常に弱拍
        } else if logicalBeat == 1 {
            intensity = .strong
        } else if (logicalBeat - 1) % ticksPerMediumBeat == 0 {
            intensity = .medium
        } else {
            intensity = .weak
        }
        
        onTick?(logicalBeat, intensity)
    }
}
