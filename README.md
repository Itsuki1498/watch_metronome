# Watch Metronome Professional

**High-Precision Timing Engine & Modern Canvas Interface for watchOS**

[![Platform](https://img.shields.io/badge/platform-watchOS%2010.0%2B-black.svg)](https://developer.apple.com/watchos/)
[![Swift](https://img.shields.io/badge/Swift-5.10%2B-orange.svg)](https://swift.org)

## 概要

`Watch Metronome Professional` は、Apple Watch の限界に挑戦した高精度メトロノーム・アプリケーションです。プロの演奏家が要求する「絶対的なタイミング精度」と、最新の SwiftUI 技術を駆使した「直感的なビジュアル・フィードバック」を watchOS 上で実現しました。

単なるリズム再生ツールを超え、触覚・視覚・聴覚の全てを統合した「ウェアラブル・精密インストゥルメント」として設計されています。

## 主な特長

### 1. 超高精度シンクロ・エンジン
- **Drift-Corrected Timing**: `DispatchSourceTimer` をベースに、システム uptime を基準とした相対スケジューリングを実装。メインスレッドの負荷や Digital Crown の操作に影響されない、ナノ秒単位の正確性を維持します。
- **Zero-Latency Start**: 最初の拍動の 100ms 未来を予約実行することで、オーディオデバイスと Taptic Engine の準備時間を確保し、起動直後の「モタつき」を完全に排除しました。

### 2. インテリジェント・リズム・ロジック
- **Triple-Pulse Hierarchy**: 小節頭（Strong）、基準音符（Medium）、最小パルス（Weak）の 3 階層でリズムを解釈。
- **Density Control (3 Modes)**:
    - **All**: 全てのパルスを表示・出力（高度な裏拍の確認に）。
    - **Strong/Medium**: 主要な拍のみ（リズムの骨格把握に）。
    - **Strong Only**: 小節頭のみ（内部時計の自立トレーニングに）。
- **Musical Note Filtering**: 指定した拍子（Numerator/Denominator）に基づき、選択可能な音価（基準音符）を動的にフィルタリング。音楽的な整合性をシステムが保証します。

### 3. 次世代 Canvas UI
- **60fps Vector Rendering**: SwiftUI の `Canvas` API を使用し、滑らかな針の動きを実現。
- **Modern Pie Indicator**: 外側（分母単位）と内側（基準音符単位）の二重円環インジケーターにより、複雑な変拍子も視覚的に一瞬で把握可能です。
- **Anti-Flash Guard**: 0.999 境界値ガードにより、浮動小数点演算特有の「12時位置の描画飛び」を抑制しています。

### 4. 高度な触覚フィードバック
- **Taptic Hierarchy**: 強・中・弱の各拍に、それぞれ異なる Taptic Engine パターン（`.directionUp`, `.directionDown`, `.click`）を割り当て。画面を見ずとも、振動の「質感」だけで正確な位置を把握できます。

## 技術仕様

| カテゴリ | 採用技術 |
| :--- | :--- |
| 言語 | Swift 5.10+ |
| フレームワーク | SwiftUI, Observation, WatchKit |
| 状態管理 | `@Observable` によるリアクティブ・アーキテクチャ |
| レンダリング | Canvas API (Low-level rendering) |
| タイミング | GCD DispatchSourceTimer with relative deadline |
| アセット | 960px High-Definition PNG (Template Rendering) |

## システム要件

- **Device**: Apple Watch Series 4 以降 (SE 第1世代以降を含む)
- **OS**: watchOS 10.0 以上
- **IDE**: Xcode 15.4 / 16.0 以降

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
