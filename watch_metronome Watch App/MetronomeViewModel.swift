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
    
    /// 現在のBPM
    var bpm: Double {
        get { engine.bpm }
        set { engine.bpm = newValue }
    }

    /// Digital Crown操作用のBPM
    var displayBpm: Double {
        get { engine.bpm }
        set { engine.bpm = Double(Int(newValue)) }
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
    }
    
    private func setupEngine() {
        // エンジンからの通知を受け取る
        engine.onTick = { [weak self] (beat: Int, isStrong: Bool) in
            // 振動を実行
            if isStrong {
                self?.hapticManager.playStrong()
            } else {
                self?.hapticManager.playWeak()
            }
            
            // 画面表示を更新（メインスレッドで行う）
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
