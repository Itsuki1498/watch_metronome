//
//  MetronomeEngine.swift
//  watch_metronome
//
//  Created by Gemini on 2026/05/18.
//

import Foundation

/// メトロノームのリズム生成を担うエンジン
final class MetronomeEngine {
    
    // MARK: - Properties (設定値)
    
    /// テンポ (Beats Per Minute)
    /// 40.0 〜 400.0 の範囲で設定します
    var bpm: Double = 120.0 {
        didSet {
            // もしも動いている最中にBPM（速さ）が変わったら…
            if isPlaying {
                // 一度今のタイマーを止めて
                timer?.cancel()
                // 新しい速さでタイマーを作り直します
                setupTimer()
            }
        }
    }
    
    /// 拍子（分子）: 1小節の中に何拍あるか
    /// 0: 全て弱拍（フラットなリズム）
    /// 1: 全て強拍
    /// 2以上: 1拍目が強拍の周期的なリズム
    var numerator: Int = 4
    
    /// 拍子（分母）: 何分音符を1拍とするか
    /// 2, 4, 8, 16, 32 を想定
    var denominator: Int = 4
    
    /// 動作状態（外からは見るだけ）
    private(set) var isPlaying: Bool = false
    
    /// 現在の拍カウント（何回目の刻みか）
    private var tickCount: Int = 0
    
    /// 内部的なタイマー
    private var timer: DispatchSourceTimer?
    
    /// 1拍ごとの通知用クロージャ
    /// - Parameter beat: 現在の拍数（1から開始）
    /// - Parameter isStrong: その拍が強拍（強調される音）かどうか
    var onTick: ((_ beat: Int, _ isStrong: Bool) -> Void)?
    
    // MARK: - Methods (機能)
    
    /// メトロノームを開始します
    func start() {
        // すでに動いているなら何もしない
        guard !isPlaying else { return }
        
        isPlaying = true
        tickCount = 0 // 最初から数え直すためにリセット
        
        // 準備しておいたタイマー設定を呼び出します
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
        // BPMから「1拍が何秒か」を計算します（例: 60 / 120 = 0.5秒）
        let interval = 60.0 / bpm
        
        // タイマーを動かすための専用の「列（Queue）」を作ります
        // ※ .userInteractive は、最も優先度が高い（遅延が少ない）設定です
        let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
        
        // タイマーを作成します
        timer = DispatchSource.makeTimerSource(queue: queue)
        
        // タイマーのスケジュールを設定します
        // deadline: .now()（今すぐ開始）
        // repeating: interval（計算した間隔で繰り返す）
        timer?.schedule(deadline: .now(), repeating: interval)
        
        // タイマーが動くたびに、一生君と作った tick() を呼び出すように設定します
        timer?.setEventHandler { [weak self] in
            self?.tick()
        }
        
        // 最後に、タイマーを動かします（最初は一時停止状態で作成されるため）
        timer?.resume()
    }
    
    /// 1拍ごとに実行される処理
    private func tick() {
        // 箱（tickCount）の数字を 1 つ増やします
        tickCount += 1
        
        // 「強拍（強調する音）かどうか」を入れるための、一時的な箱を作ります
        var isStrong: Bool = false
        
        // 【条件分岐】もしも、分子（numerator）が 0 だったら…
        if numerator == 0 {
            // 強拍はなし（ずっと弱拍）
            isStrong = false
        } else if numerator == 1 {
            // そうではなくて、分子が 1 だったら「全て強拍」
            isStrong = true
        } else {
            // それ以外（2拍子以上）なら、1拍目だけを強くする
            // 今のカウントを分子で割って、余りが 1 なら「1拍目」です
            isStrong = (tickCount - 1) % numerator == 0
        }
        
        // --- 外部への通知 ---
        
        // 現在の拍（1, 2, 3...）を計算します
        let currentBeat = numerator == 0 ? 1 : ((tickCount - 1) % numerator) + 1
        
        // 設定された「窓口（onTick）」に、結果を渡します
        onTick?(currentBeat, isStrong)
    }
}
