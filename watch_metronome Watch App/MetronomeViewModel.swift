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
    
    /// システムの準備ができているか
    var isSystemReady: Bool = false
    
    /// 編集対象の項目
    enum EditTarget: Hashable {
        case bpm, numerator, denominator
    }
    
    /// 現在のBPM (Int型)
    var bpm: Int {
        get { engine.bpm }
        set { engine.bpm = newValue }
    }

    /// Digital Crown操作用のBPM (Double)
    var displayBpm: Double {
        get { Double(engine.bpm) }
        set { 
            let newIntValue = Int(newValue)
            if newIntValue != engine.bpm {
                engine.bpm = newIntValue
            }
        }
    }
    
    /// Digital Crown操作用の分子
    var displayNumerator: Double {
        get { Double(engine.numerator) }
        set { 
            let newIntValue = Int(newValue)
            if newIntValue != engine.numerator {
                engine.numerator = newIntValue
            }
        }
    }
    
    /// Digital Crown操作用の分母インデックス
    var displayDenominatorIndex: Double {
        get { Double(denominatorOptions.firstIndex(of: engine.denominator) ?? 1) }
        set { 
            let index = Int(newValue)
            if index >= 0 && index < denominatorOptions.count {
                engine.denominator = denominatorOptions[index]
            }
        }
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
    }
    
    /// 分母
    var denominator: Int {
        get { engine.denominator }
    }
    
    /// 分母の選択肢
    let denominatorOptions = [2, 4, 8, 16, 32]
    
    // MARK: - Initialization
    
    init() {
        setupEngine()
        
        // 起動から1秒間待機
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isSystemReady = true
        }
    }
    
    private func setupEngine() {
        engine.onTick = { [weak self] (beat: Int, isStrong: Bool) in
            // 振動
            if isStrong {
                self?.hapticManager.playStrong()
            } else {
                self?.hapticManager.playWeak()
            }
            
            // UI更新
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
