//
//  HapticManager.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import WatchKit

/// Apple Watchの触覚フィードバック（振動）を管理するクラス
final class HapticManager {
    
    /// 強拍用の振動パターン（しっかりした振動）
    func playStrong() {
        WKInterfaceDevice.current().play(.directionUp)
    }
    
    /// 中拍用の振動パターン（標準的な振動）
    func playMedium() {
        WKInterfaceDevice.current().play(.click)
    }
    
    /// 弱拍用の振動パターン（控えめな振動）
    func playWeak() {
        // 弱拍は非常に軽く
        WKInterfaceDevice.current().play(.directionDown)
    }
}
