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
                updateTimerSchedule(nextBeatOffset: nil)
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
        tickCount = 1 // 今から1拍目
        
        // 基準時間を取得
        let startTime = DispatchTime.now()
        
        // --- 1. ダブりの解消 ---
        // 前回の「ウォームアップ振動」を削除しました。
        // 代わりに、このスレッドで即座に1拍目の通知を行います。
        triggerTick(beat: 1)
        
        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        // --- 2. 2拍目以降を正確な間隔で予約 ---
        let interval = 60.0 / Double(bpm)
        timer?.schedule(deadline: startTime + interval, repeating: interval, leeway: .nanoseconds(0))
    }
    
    /// メトロノームを停止します
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    /// タイマーのスケジュールを更新
    private func updateTimerSchedule(nextBeatOffset: Double?) {
        let interval = 60.0 / Double(bpm)
        let deadline: DispatchTime = .now() + (nextBeatOffset ?? interval)
        timer?.schedule(deadline: deadline, repeating: interval, leeway: .nanoseconds(0))
    }
    
    /// 内部的な発火処理
    private func triggerTick(beat: Int) {
        let currentNumerator = numerator
        let isStrong = currentNumerator == 1 || (currentNumerator > 1 && (beat - 1) % currentNumerator == 0)
        let displayBeat = currentNumerator == 0 ? 1 : ((beat - 1) % currentNumerator) + 1
        
        // UIや振動の処理。
        // メインスレッドへ渡す際の僅かなラグを考慮し、バックグラウンドでの即時実行も併用します。
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
