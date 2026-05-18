//
//  ContentView.swift
//  watch_metronome Watch App
//
//  Created by Gemini on 2026/05/18.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var viewModel = MetronomeViewModel()
    @FocusState private var focusedField: MetronomeViewModel.EditTarget?
    
    var body: some View {
        ZStack {
            // 背景レイヤー: モダンな円環UI（TimelineViewで針を動かす）
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .scaleEffect(1.2)
            
            if !viewModel.isSystemReady {
                ProgressView()
                    .tint(.orange)
            } else {
                mainControlUI
            }
        }
        .onAppear {
            focusedField = .bpm
        }
    }
    
    private var mainControlUI: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 1. BPM & 音価設定
            HStack(alignment: .center, spacing: 4) {
                settingItem(target: .noteValue, label: viewModel.currentNoteName)
                    .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                
                Text("=")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.7))
                
                settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 44)
                    .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
            }
            .padding(.bottom, 2)
            
            // 2. 拍子設定 (分子 / 分母)
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 22)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 22)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                Button {
                    viewModel.isSimplifiedMode.toggle()
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isSimplifiedMode ? Color.orange : Color.blue.opacity(0.8))
            }
            
            Spacer()
            
            // 3. 再生ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
            }
            .frame(height: 38)
            .tint(viewModel.isPlaying ? .red.opacity(0.8) : .green.opacity(0.8))
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20) -> some View {
        Text(label)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(focusedField == target ? Color.white : Color.primary.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                ZStack {
                    if focusedField == target {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.3))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = target
                WKInterfaceDevice.current().play(.click)
            }
            .focusable()
            .focused($focusedField, equals: target)
    }
}

/// モダンな円環型インジケーター（針付き）
struct ModernPieIndicatorView: View {
    let viewModel: MetronomeViewModel
    let date: Date // TimelineViewからの更新用
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2
            
            ZStack {
                // 1. ベースリング
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 4)
                
                // 2. 拍ごとのセグメント（瞬時に光る）
                if viewModel.numerator > 1 {
                    ForEach(0..<viewModel.numerator, id: \.self) { i in
                        let startAngle = Double(i) * (360.0 / Double(viewModel.numerator)) - 90
                        let endAngle = Double(i + 1) * (360.0 / Double(viewModel.numerator)) - 90
                        let isCurrent = (i + 1) == viewModel.currentBeat
                        
                        Path { path in
                            path.addArc(center: center, radius: radius,
                                        startAngle: .degrees(startAngle + 1),
                                        endAngle: .degrees(endAngle - 1),
                                        clockwise: false)
                        }
                        .stroke(
                            isCurrent ? colorForIntensity(viewModel.currentIntensity) : Color.white.opacity(0.05),
                            style: StrokeStyle(lineWidth: isCurrent ? 8 : 4, lineCap: .round)
                        )
                        // キビキビさせるためアニメーションを極短縮または無しに
                    }
                }
                
                // 3. 流動的な「針」
                if viewModel.isPlaying {
                    let progress = currentProgress()
                    let angle = progress * 360.0 - 90.0
                    
                    // 針の本体
                    Capsule()
                        .fill(LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: radius)
                        .offset(y: -radius / 2)
                        .rotationEffect(.degrees(angle))
                    
                    // 先端の光
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(angle))
                        .shadow(color: .white.opacity(0.8), radius: 4)
                }
            }
        }
        .padding(8)
    }
    
    private func colorForIntensity(_ intensity: BeatIntensity) -> Color {
        switch intensity {
        case .strong: return .orange
        case .medium: return .cyan
        case .weak, .silence: return .blue
        }
    }
    
    /// 小節内の現在の進捗 (0.0 〜 1.0) を計算
    private func currentProgress() -> Double {
        // 現在時刻と最後の拍の時刻の差（ナノ秒 -> 秒）
        let now = DispatchTime.now()
        let elapsed = Double(now.uptimeNanoseconds - viewModel.lastTickTime.uptimeNanoseconds) / 1_000_000_000.0
        
        // 現在の拍の番号（0ベース）
        let beatIndex = Double(viewModel.currentBeat - 1)
        
        // (現在の拍の開始位置 + その拍内での進捗) / 全体の拍数
        let totalProgress = (beatIndex + (elapsed / viewModel.tickInterval)) / Double(max(1, viewModel.numerator))
        
        return totalProgress.truncatingRemainder(dividingBy: 1.0)
    }
}

#Preview {
    ContentView()
}
