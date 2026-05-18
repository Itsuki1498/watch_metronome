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
            if isPlaying {
                updateTimerSchedule()
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
    
    /// 内部的なタイマー
    private var timer: DispatchSourceTimer?
    
    /// 1拍ごとの通知用クロージャ
    var onTick: ((_ beat: Int, _ isStrong: Bool) -> Void)?
    
    // MARK: - Methods (機能)
    
    /// メトロノームを開始します
    func start() {
        guard !isPlaying else { return }
        
        isPlaying = true
        tickCount = 0
        setupTimer()
    }
    
    /// メトロノームを停止します
    func stop() {
        isPlaying = false
        timer?.cancel()
        timer = nil
    }
    
    /// 内部的なタイマー設定
    private func setupTimer() {
        let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
        timer = DispatchSource.makeTimerSource(queue: queue)
        
        updateTimerSchedule()
        
        timer?.setEventHandler { [weak self] in
            self?.tick()
        }
        timer?.resume()
    }
    
    /// タイマーのスケジュールを更新（BPM変更時に呼び出し）
    private func updateTimerSchedule() {
        let interval = 60.0 / bpm
        timer?.schedule(deadline: .now(), repeating: interval, leeway: .nanoseconds(0))
    }
    
    /// 1拍ごとに実行される処理
    private func tick() {
        tickCount += 1
        
        var isStrong: Bool = false
        
        if numerator == 0 {
            isStrong = false
        } else if numerator == 1 {
            isStrong = true
        } else {
            isStrong = (tickCount - 1) % numerator == 0
        }
        
        let currentBeat = numerator == 0 ? 1 : ((tickCount - 1) % numerator) + 1
        
        onTick?(currentBeat, isStrong)
    }
}
