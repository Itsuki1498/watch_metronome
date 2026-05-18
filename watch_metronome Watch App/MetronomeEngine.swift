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
    
    var bpm: Int = 120 {
        didSet {
            if bpm < 40 { bpm = 40 }
            if bpm > 400 { bpm = 400 }
            if isPlaying {
                // 演奏中のBPM変更：次の拍の予定を現在時刻基準ではなく、
                // 「最後の拍が鳴った時刻」から再計算することで、操作中の停止を防ぎます。
                updateTimerSchedule(isRestart: true)
            }
        }
    }
    
    var numerator: Int = 4 {
        didSet {
            if numerator < 0 { numerator = 0 }
            if numerator > 32 { numerator = 32 }
        }
    }
    
    var denominator: Int = 4
    
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
        tickCount = 1 // 1拍目
        lastTickTime = .now()
        
        // 1拍目を即座に発火
        triggerTick(beat: 1)
        
        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        // 2拍目以降を予約
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
        let interval = 60.0 / Double(bpm)
        
        let deadline: DispatchTime
        if isRestart {
            // BPM変更時：最後に鳴った時刻 + 新しい間隔
            // もし既にその時刻を過ぎていたら、即座（.now()）に鳴らします
            let nextTime = lastTickTime + interval
            deadline = nextTime < .now() ? .now() : nextTime
        } else {
            // 開始時：今から正確な間隔後（1拍目は既にstart()で鳴らしているため）
            deadline = lastTickTime + interval
        }
        
        // 繰り返し間隔も新しいBPMに更新
        timer?.schedule(deadline: deadline, repeating: interval, leeway: .nanoseconds(0))
    }
    
    /// 内部的な発火処理
    private func triggerTick(beat: Int) {
        // 最後に鳴った時刻を更新（この時刻を基準に次のBPM変更を計算する）
        lock.lock()
        lastTickTime = .now()
        let currentNumerator = numerator
        lock.unlock()
        
        let isStrong = currentNumerator == 1 || (currentNumerator > 1 && (beat - 1) % currentNumerator == 0)
        let displayBeat = currentNumerator == 0 ? 1 : ((beat - 1) % currentNumerator) + 1
        
        // 通知（メインスレッドへのディスパッチはViewModel側で行う）
        onTick?(displayBeat, isStrong)
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
        lock.unlock()
        
        triggerTick(beat: currentTick)
    }
}
