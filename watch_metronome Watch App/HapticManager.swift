//
//  HapticManager.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import WatchKit

/// Apple Watchの触覚フィードバック（振動）を管理するクラス
final class HapticManager {
    
    /// 強拍用の振動パターン
    func playStrong() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    /// 弱拍用の振動パターン
    func playWeak() {
        WKInterfaceDevice.current().play(.click)
    }
}
