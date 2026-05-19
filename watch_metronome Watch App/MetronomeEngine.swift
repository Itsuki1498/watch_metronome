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
    
    /// 拍ごとの通知用クロージャ (拍数, 強さ, 発火時刻)
    var onTick: ((_ beat: Int, _ intensity: BeatIntensity, _ tickTime: DispatchTime) -> Void)?
    
    // MARK: - Logic Constants (UI側で参照可能にする)
    
    private(set) var internalInterval: Double = 0.5
    private(set) var ticksPerMediumBeat: Int = 1

    private func updateConstants() {
        let unitNoteValue = 4.0 / Double(denominator)
        let internalBpm = Double(bpm) * (referenceNoteMultiplier / unitNoteValue)
        ticksPerMediumBeat = max(1, Int(round(referenceNoteMultiplier / unitNoteValue)))
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
        let interval = 60.0 / Double(bpm)

        let deadline: DispatchTime
        if isRestart {
            // BPM変更時：最後に鳴った時刻 + 新しい間隔
            let nextTime = lastTickTime + interval
            deadline = nextTime < .now() ? .now() : nextTime
        } else {
            // 開始時：100ms後に最初の1拍目を予約
            deadline = .now() + .milliseconds(100)
            // 修正：lastTickTimeを未来のdeadlineそのものに設定し、
            // それまでは進捗計算が0（ガードにかかる）になるようにします
            lastTickTime = deadline
        }
        timer?.schedule(deadline: deadline, repeating: interval, leeway: .nanoseconds(0))
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
        
        var intensity: BeatIntensity
        if currentNumerator == 0 {
            if (currentTick - 1) % currentTicksPerMedium == 0 {
                intensity = .medium
            } else {
                intensity = .weak
            }
        } else if logicalBeat == 1 {
            intensity = .strong
        } else if (logicalBeat - 1) % currentTicksPerMedium == 0 {
            intensity = .medium
        } else {
            intensity = .weak
        }
        
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
