# Watch Metronome

iPhoneで拍子・テンポのプログラムを作成し、iPhone単体で再生したりApple Watchへ同期したりできるメトロノームです。

[![Platform](https://img.shields.io/badge/platform-watchOS%2010.0%2B%20%7C%20iOS%2026.0%2B-black.svg)](https://developer.apple.com/apple-watch/)
[![Swift](https://img.shields.io/badge/Swift-5%20language%20mode-orange.svg)](https://swift.org)

## 機能

- BPMのドラムロール、直接入力、ドラッグ調整、タップテンポ
- 拍子・基準音符・クリックモード・特殊アクセントの設定
- 小節数を指定した拍子モジュールを連ねる複合プログラム
- 次小節から適用する拍子・テンポ変更、ritardando、accelerando
- 基本拍子・複合プログラムのプリセット保存と呼び出し
- iPhoneでは音、Apple Watchでは触覚による拍の通知
- iPhoneの画面ロック中も続けられるバックグラウンド再生
- 到達可能なWatchへは即時接続を試み、未接続時は設定をキューで同期

両アプリは同じ拍子・小節進行エンジンを使用します。タイマーは単調増加時計を基準に次の拍をスケジュールします。実際の出力精度はOSのスケジューリングや端末負荷に左右されます。

## システム要件

- **Apple Watch**: watchOS 10.0 以上
- **iPhone**: iOS 26.0 以上
- **IDE**: Xcode 26 以降

## セットアップとビルド

1. このリポジトリをクローンします。
2. `watch_metronome.xcodeproj` を Xcode で開きます。
3. ターゲットとして「watch_metronome Watch App」を選択します。
4. 適切な Development Team を設定し、実機またはシミュレータにビルド＆実行します。

## 起動

1. `watch_metronome.xcodeproj` をXcodeで開きます。
2. `watch_metronome` または `watch_metronome Watch App` schemeを選択します。
3. Signing設定を行い、対応する実機またはシミュレータで起動します。
