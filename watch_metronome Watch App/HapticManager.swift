//
//  HapticManager.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import WatchKit

/// Apple Watchの触覚フィードバック（振動）を管理するクラス
final class HapticManager {
    
    /// 強拍用の振動パターン（上向きの力強い振動）
    func playStrong() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    /// 弱拍用の振動パターン（下向きの軽い振動 - .clickよりも明確です）
    func playWeak() {
        WKInterfaceDevice.current().play(.directionDown)
    }
}
