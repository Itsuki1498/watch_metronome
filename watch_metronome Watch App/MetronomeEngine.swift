//
//  MetronomeEngine.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import Foundation
import Observation

/// メトロノームのリズム生成を担うエンジン
@Observable
final class MetronomeEngine {
    
    // MARK: - Properties (設定値)
    
    /// テンポ (Beats Per Minute)
    /// 40 〜 400 の範囲で設定します
    var bpm: Int = 120 {
        didSet {
            if bpm < 40 { bpm = 40 }
            if bpm > 400 { bpm = 400 }
        }
    }
    
    /// 拍子（分子）: 1小節の中に何拍あるか
    var numerator: Int = 4 {
        didSet {
            if numerator < 0 { numerator = 0 }
            if numerator > 32 { numerator = 32 }
        }
    }
    
    /// 拍子（分母）: 何分音符を1拍とするか
    var denominator: Int = 4
    
    /// 動作状態（外からは見るだけ）
    private(set) var isPlaying: Bool = false
    
    /// 現在の拍カウント
    private var tickCount: Int = 0
    
    /// 次に拍を鳴らすべき「絶対予定時刻」
    private var nextTickTime: DispatchTime = .now()
    
    /// 内部的なタイマー
    private var timer: DispatchSourceTimer?
    
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
        tickCount = 0 // 最初は0から（最初のtickで1になる）
        
        // --- 根本解決：未来の「最初の発火点」を予約する ---
        // UIが「再生中」に切り替わる時間を考慮し、50ミリ秒後を1拍目の基準にします。
        // これにより、1拍目がスキップされることなく確実に表示・振動します。
        nextTickTime = DispatchTime.now() + .milliseconds(50)
        
        if timer == nil {
            let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        // 最初の1拍目を予約
        timer?.schedule(deadline: nextTickTime, leeway: .nanoseconds(0))
    }
    
    /// メトロノームを停止します
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    /// 1拍ごとに実行される処理
    private func tick() {
        lock.lock()
        guard isPlaying else {
            lock.unlock()
            return
        }
        
        // カウントを進める
        tickCount += 1
        let currentTick = tickCount
        let currentNumerator = numerator
        let currentBpm = bpm
        
        // --- 絶対時間スケジューリング ---
        // 「今」ではなく「前回の予定時刻」を基準に次を予約することで、誤差の蓄積を完全に防ぎます。
        let interval = 60.0 / Double(currentBpm)
        nextTickTime = nextTickTime + interval
        timer?.schedule(deadline: nextTickTime, leeway: .nanoseconds(0))
        lock.unlock()
        
        // 強拍判定
        let isStrong: Bool
        if currentNumerator == 0 {
            isStrong = false
        } else if currentNumerator == 1 {
            isStrong = true
        } else {
            isStrong = (currentTick - 1) % currentNumerator == 0
        }
        
        let currentBeat = currentNumerator == 0 ? 1 : ((currentTick - 1) % currentNumerator) + 1
        
        // 外部に通知
        onTick?(currentBeat, isStrong)
    }
}
