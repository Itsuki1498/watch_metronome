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
            // 背景レイヤー: 精密なネオン円環
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .padding(10) // 画面端からのはみ出しを防止
            
            if !viewModel.isSystemReady {
                ProgressView()
                    .tint(.orange)
            } else {
                // 前面レイヤー: 整理された操作UI
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
            
            // 1. BPM & 音価セクション
            VStack(spacing: 2) {
                HStack(alignment: .center, spacing: 4) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 16)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 48)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 10, weight: .black))
                    .kerning(1)
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.top, 10) // インジケーターとの重なり防止
            
            // 2. 拍子セクション
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 22)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 18, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 22)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                // 簡易モード切替
                Button {
                    viewModel.isSimplifiedMode.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.isSimplifiedMode ? .orange : .blue.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            
            Spacer()
            
            // 3. 起動ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(width: 80, height: 34)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding(.bottom, 2)
        }
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20) -> some View {
        Text(label)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(focusedField == target ? .white : .primary.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                ZStack {
                    if focusedField == target {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.3))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan, lineWidth: 1)
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

struct ModernPieIndicatorView: View {
    let viewModel: MetronomeViewModel
    let date: Date
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2
            
            ZStack {
                // ベース：薄い背景円
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 2)
                
                // 1. 拍セグメント（シャープな直線カット）
                if viewModel.numerator > 1 {
                    ForEach(0..<viewModel.numerator, id: \.self) { i in
                        let startAngle = Double(i) * (360.0 / Double(viewModel.numerator)) - 90
                        let endAngle = Double(i + 1) * (360.0 / Double(viewModel.numerator)) - 90
                        let isCurrent = (i + 1) == viewModel.currentBeat
                        
                        // 光るセグメント
                        Path { path in
                            path.addArc(center: center, radius: radius,
                                        startAngle: .degrees(startAngle + 0.5), // 隣と被らないよう僅かな隙間
                                        endAngle: .degrees(endAngle - 0.5),
                                        clockwise: false)
                        }
                        .stroke(
                            isCurrent ? colorForIntensity(viewModel.currentIntensity) : Color.white.opacity(0.03),
                            style: StrokeStyle(lineWidth: isCurrent ? 8 : 2, lineCap: .butt) // .butt で直線的にカット
                        )
                        .shadow(color: isCurrent ? colorForIntensity(viewModel.currentIntensity).opacity(0.4) : .clear, radius: 4)
                    }
                } else if viewModel.numerator == 1 || viewModel.numerator == 0 {
                    // 単一円
                    Circle()
                        .stroke(
                            viewModel.isPlaying ? colorForIntensity(viewModel.currentIntensity) : Color.white.opacity(0.05),
                            style: StrokeStyle(lineWidth: viewModel.isPlaying ? 8 : 2)
                        )
                        .shadow(color: viewModel.isPlaying ? colorForIntensity(viewModel.currentIntensity).opacity(0.3) : .clear, radius: 6)
                }
                
                // 2. 流動的な「スキャン針」
                if viewModel.isPlaying {
                    let progress = currentProgress()
                    let angle = (progress * 360.0) - 90.0
                    
                    // 針の光跡
                    Circle()
                        .trim(from: max(0, progress - 0.15), to: progress)
                        .stroke(
                            AngularGradient(colors: [.clear, colorForIntensity(viewModel.currentIntensity).opacity(0.2)], center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    // 針（12時方向を基準とした絶対位置）
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2, height: radius)
                        .offset(y: -radius / 2)
                        .rotationEffect(.degrees(angle + 90))
                        .shadow(color: .white.opacity(0.5), radius: 2)
                }
            }
        }
    }
    
    private func colorForIntensity(_ intensity: BeatIntensity) -> Color {
        switch intensity {
        case .strong: return .orange
        case .medium: return .cyan
        case .weak, .silence: return .blue
        }
    }
    
    private func currentProgress() -> Double {
        let now = DispatchTime.now()
        let elapsed = Double(now.uptimeNanoseconds - viewModel.lastTickTime.uptimeNanoseconds) / 1_000_000_000.0
        let beatIndex = Double(viewModel.currentBeat - 1)
        let totalProgress = (beatIndex + (elapsed / viewModel.tickInterval)) / Double(max(1, viewModel.numerator))
        return totalProgress.truncatingRemainder(dividingBy: 1.0)
    }
}

#Preview {
    ContentView()
}
