//
//  MetronomeViewModel.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import Foundation
import Observation

/// メトロノームの画面状態と操作を管理するViewModel
@Observable
final class MetronomeViewModel {
    
    // MARK: - Properties
    
    private let engine = MetronomeEngine()
    private let hapticManager = HapticManager()
    
    /// システムの準備ができているか（起動直後の不安定さを回避するため）
    var isSystemReady: Bool = false
    
    /// 現在のBPM (Int型)
    var bpm: Int {
        get { engine.bpm }
        set { engine.bpm = newValue }
    }

    /// Digital Crown操作用のBPM (UI側はDoubleで受け取るため)
    var displayBpm: Double {
        get { Double(engine.bpm) }
        set { engine.bpm = Int(newValue) }
    }
    
    /// 動作中かどうか
    var isPlaying: Bool {
        engine.isPlaying
    }
    
    /// 現在の拍数 (1 〜 numerator)
    var currentBeat: Int = 1
    
    /// 現在が強拍かどうか
    var isCurrentBeatStrong: Bool = false
    
    /// 分子（何拍子か）
    var numerator: Int {
        get { engine.numerator }
        set { engine.numerator = newValue }
    }
    
    // MARK: - Initialization
    
    init() {
        setupEngine()
        
        // 起動から1秒間、システムが落ち着くのを待ちます
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSystemReady = true
        }
    }
    
    private func setupEngine() {
        // エンジンからの通知を受け取る
        engine.onTick = { [weak self] (beat: Int, isStrong: Bool) in
            // 振動はラグを避けるため、このバックグラウンドスレッドで即座に実行
            if isStrong {
                self?.hapticManager.playStrong()
            } else {
                self?.hapticManager.playWeak()
            }
            
            // 画面表示の更新（メインスレッド）
            DispatchQueue.main.async {
                self?.currentBeat = beat
                self?.isCurrentBeatStrong = isStrong
            }
        }
    }
    
    // MARK: - Actions
    
    func togglePlayback() {
        if engine.isPlaying {
            engine.stop()
        } else {
            engine.start()
        }
    }
}
