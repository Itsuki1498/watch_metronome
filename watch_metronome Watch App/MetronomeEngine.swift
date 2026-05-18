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
    /// 40.0 〜 400.0 の範囲で設定します
    var bpm: Double = 120.0 {
        didSet {
            // ここで即座にタイマーを再スケジュール（deadline: .now()）すると、
            // 変更した瞬間に次の拍が割り込んできて「ピピピ」となってしまいます。
            // そのため、ここでは何もしないか、あるいは「次の拍の予定時刻」を
            // 正確に再計算する必要があります。
            // シンプルな解決策として、タイマーは一定間隔で動かし続け、
            // tick()の中で最新のBPMを参照するように後ほど調整します。
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
    
    /// スレッド間でのデータ競合を防ぐためのロック
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
        tickCount = 0
        
        // 最初の拍の時刻を「今」に設定
        nextTickTime = .now()
        
        if timer == nil {
            let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }
        
        // 最初の拍を即座に実行（このタイマーが即座にtickを呼び出す）
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
        
        // 次の拍の予定時刻を計算（今の処理が終わるのを待たず、予定されていた時間から加算する）
        let interval = 60.0 / currentBpm
        nextTickTime = nextTickTime + interval
        
        // 次の拍を正確な時刻に予約
        timer?.schedule(deadline: nextTickTime, leeway: .nanoseconds(0))
        lock.unlock()
        
        // 判定
        var isStrong: Bool = false
        if currentNumerator == 0 {
            isStrong = false
        } else if currentNumerator == 1 {
            isStrong = true
        } else {
            isStrong = (currentTick - 1) % currentNumerator == 0
        }
        
        let currentBeat = currentNumerator == 0 ? 1 : ((currentTick - 1) % currentNumerator) + 1
        
        // 通知
        onTick?(currentBeat, isStrong)
    }
}
}
