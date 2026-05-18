//
//  HapticManager.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import WatchKit

/// Apple Watchの触覚フィードバック（振動）を管理するクラス
final class HapticManager {
    
    /// 強拍用の振動パターン（突き上げるような強い衝撃）
    func playStrong() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    /// 中拍用の振動パターン（標準的な手応えのある衝撃）
    func playMedium() {
        WKInterfaceDevice.current().play(.directionDown)
    }
    
    /// 弱拍用の振動パターン（指先で叩くような軽いタップ）
    func playWeak() {
        WKInterfaceDevice.current().play(.click)
    }
}
