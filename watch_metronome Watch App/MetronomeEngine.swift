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
    var bpm: Double = 120.0 {
        didSet {
            // 整数に丸める
            let roundedBpm = Double(Int(bpm))
            if bpm != roundedBpm {
                bpm = roundedBpm
            }
        }
    }
    
    /// 拍子（分子）: 1小節の中に何拍あるか
    var numerator: Int = 4 {
        didSet {
            if numerator < 0 { numerator = 0 }
        }
    }
    
    /// 拍子（分母）: 何分音符を1拍とするか
    var denominator: Int = 4
    
    /// 動作状態（外からは見るだけ）
    private(set) var isPlaying: Bool = false
    
    /// 現在の拍カウント（何回目の刻みか）
    private var tickCount: Int = 0
    
    /// 次に拍を鳴らすべき絶対時刻
    private var nextTickTime: DispatchTime = .now()
    
    /// 内部的なタイマー
    private var timer: DispatchSourceTimer?
    
    /// スレッド間でのデータ競合を防ぐためのロック（再帰的な呼び出しを許可）
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
        
        // 1拍目を「今この瞬間」に実行
        let startTime = DispatchTime.now()
        let currentNumerator = numerator
        let isStrong = currentNumerator == 1 || (currentNumerator > 1 && (tickCount - 1) % currentNumerator == 0)
        let currentBeat = currentNumerator == 0 ? 1 : ((tickCount - 1) % currentNumerator) + 1
        
        // 外部に即座に通知
        onTick?(currentBeat, isStrong)
        
        // 2拍目の時刻を「正確に1拍分後」に設定
        let interval = 60.0 / bpm
        nextTickTime = startTime + interval
        
        if timer == nil {
            let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        // 2拍目を予約
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
        
        tickCount += 1
        let currentTick = tickCount
        let currentNumerator = numerator
        let currentBpm = bpm
        
        // 次の拍（未来）を予約
        let interval = 60.0 / currentBpm
        nextTickTime = nextTickTime + interval
        timer?.schedule(deadline: nextTickTime, leeway: .nanoseconds(0))
        lock.unlock()
        
        // 現在の拍を判定して通知
        let isStrong = currentNumerator == 1 || (currentNumerator > 1 && (currentTick - 1) % currentNumerator == 0)
        let currentBeat = currentNumerator == 0 ? 1 : ((currentTick - 1) % currentNumerator) + 1
        
        onTick?(currentBeat, isStrong)
    }
}
