//
//  HapticManager.swift
//  watch_metronome
//
//  Created by Gemini on 2026/05/18.
//

#if os(watchOS)
import WatchKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// デバイスの触覚フィードバック（振動）を管理するクラス
final class HapticManager {
    
    #if canImport(UIKit) && !os(watchOS)
    private let strongGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let weakGenerator = UIImpactFeedbackGenerator(style: .light)
    
    init() {
        strongGenerator.prepare()
        mediumGenerator.prepare()
        weakGenerator.prepare()
    }
    #endif
    
    /// 強拍用の振動パターン
    func playStrong() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionUp)
        #elseif canImport(UIKit)
        strongGenerator.impactOccurred()
        #endif
    }
    
    /// 中拍用の振動パターン
    func playMedium() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.directionDown)
        #elseif canImport(UIKit)
        mediumGenerator.impactOccurred()
        #endif
    }
    
    /// 弱拍用の振動パターン
    func playWeak() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #elseif canImport(UIKit)
        weakGenerator.impactOccurred()
        #endif
    }
}
