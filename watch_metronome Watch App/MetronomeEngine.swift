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
    
    /// テンポ (基準音符が1分間に刻まれる回数)
    var bpm: Int = 120 {
        didSet { updateConstants() }
    }
    
    /// 拍子（分子）: 最小単位の音符が1小節にいくつあるか
    var numerator: Int = 4 {
        didSet { updateConstants() }
    }
    
    /// 拍子（分母）: 1小節を何分割するか（最小単位の音符）
    var denominator: Int = 4 {
        didSet { updateConstants() }
    }
    
    /// BPMの基準となる音価倍率 (四分音符 = 1.0)
    var referenceNoteMultiplier: Double = 1.0 {
        didSet { updateConstants() }
    }
    
    /// 弱拍を消して、中拍を弱拍として扱うモード
    var isSimplifiedMode: Bool = false {
        didSet { if isPlaying { updateTimerSchedule(isRestart: true) } }
    }
    
    /// 動作状態
    private(set) var isPlaying: Bool = false
    
    /// 現在の拍カウント
    private var tickCount: Int = 0
    
    /// 最後に拍が鳴った時刻
    private var lastTickTime: DispatchTime = .now()
    
    /// 内部的なタイマー
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
    private let lock = NSRecursiveLock()
    
    /// 拍ごとの通知用クロージャ
    var onTick: ((_ beat: Int, _ intensity: BeatIntensity) -> Void)?
    
    // MARK: - Internal Logic Constants
    
    /// 実際にタイマーが刻む1拍の間隔（秒）
    private var internalInterval: Double = 0.5
    
    /// 中拍が発生する間隔（最小単位何個分か）
    private var ticksPerMediumBeat: Int = 1

    private func updateConstants() {
        // 1. 内部的な刻み（最小単位 = denominator）のBPMを計算
        // 理論: 内部BPM = 表示BPM * (基準音価倍率 / (4.0 / 分母))
        // 例: 付点4分(1.5) = 120, 12/8(分母8) の時
        // 内部BPM = 120 * (1.5 / (4.0/8)) = 120 * (1.5 / 0.5) = 360
        let baseNoteValue = 4.0 / Double(denominator)
        let internalBpm = Double(bpm) * (referenceNoteMultiplier / baseNoteValue)
        
        // 2. 中拍の間隔を計算
        // 基準音符の中に最小単位がいくつ入るか
        // 例: 基準が付点4分、分母が8の時 -> 1.5 / 0.5 = 3個
        ticksPerMediumBeat = max(1, Int(round(referenceNoteMultiplier / baseNoteValue)))
        
        // 3. タイマー間隔の決定
        if isSimplifiedMode {
            // 簡易モードなら中拍の間隔でタイマーを回す
            internalInterval = 60.0 / (internalBpm / Double(ticksPerMediumBeat))
        } else {
            // 通常モードなら最小単位で回す
            internalInterval = 60.0 / internalBpm
        }
        
        if isPlaying { updateTimerSchedule(isRestart: true) }
    }
    
    // MARK: - Methods (機能)
    
    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPlaying else { return }
        
        isPlaying = true
        tickCount = 0
        lastTickTime = .now()
        updateConstants()
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
        let step = isSimplifiedMode ? ticksPerMediumBeat : 1
        lock.unlock()
        
        // 論理的な拍位置
        let logicalBeat = ((currentTick - 1) * step) % max(1, currentNumerator) + 1
        
        // 強弱判定
        let intensity: BeatIntensity
        if logicalBeat == 1 {
            intensity = .strong
        } else if (logicalBeat - 1) % ticksPerMediumBeat == 0 {
            intensity = .medium
        } else {
            intensity = .weak
        }
        
        onTick?(logicalBeat, intensity)
    }
}
