# Watch Metronome Professional (Multi-Platform)

**High-Precision Timing Engine & Modern Canvas Interface for iOS & watchOS**

[![Platform](https://img.shields.io/badge/platform-watchOS%2010.0%2B%20%7C%20iOS%2026.0%2B-black.svg)](https://developer.apple.com/apple-watch/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)

## 概要

`Watch Metronome Professional` は、Apple Watch と iPhone の両方で動作する、プロフェッショナル向けの高精度メトロノーム・ソリューションです。watchOS 版で培われた「絶対的なタイミング精度」を iPhone の大画面へも展開し、さらに高度な練習を可能にするコンパニオン機能を提供します。

## 主な特長

### 1. ハイブリッド・プラットフォーム構成
- **Standalone Mode**: iPhone と Apple Watch のどちらでも、単体で全ての基本機能を利用可能。
- **Real-time Sync**: `WatchConnectivity` により、iPhone 側での設定変更（BPM, 拍子）を即座に Apple Watch へ同期。

### 2. iOS版 専用機能 (Advanced Features)
- **大画面 Canvas レンダリング**: iPhone の高精細なディスプレイに最適化された、スケーラブルなリズムリング。
- **高度なプリセット管理**: 複雑な変拍子や BPM 変化をプログラムし、セットリストとして管理（※開発中）。

### 3. 超高精度シンクロ・エンジン (Shared Logic)
- **Drift-Corrected GCD Timer**: 両プラットフォームで共通のコアエンジンを使用し、ナノ秒単位の精度を保証。

## システム要件

- **Apple Watch**: watchOS 10.0 以上
- **iPhone**: iOS 26.0 以上
- **IDE**: Xcode 26 以降

## セットアップとビルド

1. このリポジトリをクローンします。
2. `watch_metronome.xcodeproj` を Xcode で開きます。
3. ターゲットとして「watch_metronome Watch App」を選択します。
4. 適切な Development Team を設定し、実機またはシミュレータにビルド＆実行します。

## デザイン哲学

「精密機械としての美しさ」をコンセプトに、余計な装飾を削ぎ落としたミニマルな UI を採用。中央のカプセル型コントロール (⊂ ⊃) は、操作性と視認性を最大化するために配置されています。

---

## 免責事項
本アプリケーションは、極めて高い精度を維持するように設計されていますが、極度のシステム負荷やハードウェアの制限により、わずかな誤差が生じる可能性を完全に排除するものではありません。

---

**Developed by Itsuki & Gemini (2026)**
*Dedicated to all musicians seeking perfection.*
