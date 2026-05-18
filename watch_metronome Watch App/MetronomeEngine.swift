//
//  MetronomeEngine.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import Foundation
import Observation
import WatchKit

/// メトロノームのリズム生成を担うエンジン
@Observable
final class MetronomeEngine {
    
    // MARK: - Properties (設定値)
    
    /// テンポ (基準音符が1分間に刻まれる回数)
    var bpm: Int = 120 {
        didSet {
            if bpm < 40 { bpm = 40 }
            if bpm > 400 { bpm = 400 }
            if isPlaying { updateTimerSchedule(isRestart: true) }
        }
    }
    
    /// 拍子（分子）
    var numerator: Int = 4 {
        didSet {
            if numerator < 0 { numerator = 0 }
            if numerator > 32 { numerator = 32 }
        }
    }
    
    /// 拍子（分母）
    var denominator: Int = 4
    
    /// BPMの基準となる音価（四分音符を 1.0 とする）
    /// 例: 八分音符なら 0.5, 二分音符なら 2.0
    var referenceNoteMultiplier: Double = 1.0 {
        didSet {
            if isPlaying { updateTimerSchedule(isRestart: true) }
        }
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
    
    /// スレッド安全性のためのロック
    private let lock = NSRecursiveLock()
    
    /// 1拍ごとの通知用クロージャ
    var onTick: ((_ beat: Int, _ isStrong: Bool) -> Void)?
    
    // MARK: - Methods (機能)
    
    /// メトロノームを開始します
    func start() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isPlaying else { return }
        
        isPlaying = true
        tickCount = 0 // 最初のtickで 1 になるように設定
        
        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        // --- 根本解決：1拍目もタイマーに任せる ---
        // start()内での直接発火をやめ、100ms後にタイマーの「初回」が来るようにします。
        // これで1拍目と2拍目の動作環境が完全に同一になり、間隔が狂わなくなります。
        lastTickTime = .now() // 基準を今にする
        updateTimerSchedule(isRestart: false)
    }
    
    /// メトロノームを停止します
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    /// タイマーのスケジュールを設定・更新
    private func updateTimerSchedule(isRestart: Bool) {
        // インターバル計算: (60秒 / BPM) 
        // ※ 基準音価に関わらず、BPMは「その音符が1分間に何回鳴るか」を指します
        let interval = 60.0 / Double(bpm)
        
        let deadline: DispatchTime
        if isRestart {
            // 演奏中の変更：最後の拍から正確な間隔後
            let nextTime = lastTickTime + interval
            deadline = nextTime < .now() ? .now() : nextTime
        } else {
            // 開始時：100ms後に最初の1拍目を予約
            deadline = .now() + .milliseconds(100)
            // 最初の拍が100ms後なので、lastTickTimeをそこに合わせて補正
            lastTickTime = deadline - interval
        }
        
        timer?.schedule(deadline: deadline, repeating: interval, leeway: .nanoseconds(0))
    }
    
    /// タイマーから呼ばれる処理
    private func tick() {
        lock.lock()
        guard isPlaying else {
            lock.unlock()
            return
        }
        
        tickCount += 1
        let currentTick = tickCount
        lastTickTime = .now() // 実際の正確な発火時刻を記録
        
        let currentNumerator = numerator
        lock.unlock()
        
        // 判定
        let isStrong = currentNumerator == 1 || (currentNumerator > 1 && (currentTick - 1) % currentNumerator == 0)
        let displayBeat = currentNumerator == 0 ? 1 : ((currentTick - 1) % currentNumerator) + 1
        
        // 通知
        onTick?(displayBeat, isStrong)
    }
}
