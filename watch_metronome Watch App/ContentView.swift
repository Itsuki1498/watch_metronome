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
            // 背景レイヤー: ネオン・サイバー円環UI
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .scaleEffect(1.25)
            .ignoresSafeArea()
            
            if !viewModel.isSystemReady {
                ProgressView()
                    .tint(.orange)
            } else {
                // 前面レイヤー: 計測器風コントロールUI
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
            VStack(spacing: -4) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 16)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 52)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BEATS PER MINUTE")
                    .font(.system(size: 8, weight: .black))
                    .kerning(1)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.bottom, 6)
            
            // 2. 拍子セクション
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 22)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 22)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                // モード切替（ネオン管風）
                Button {
                    viewModel.isSimplifiedMode.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.isSimplifiedMode ? .orange : .blue.opacity(0.8))
                        .shadow(color: viewModel.isSimplifiedMode ? .orange : .clear, radius: 4)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // 3. 起動ボタン（シャープなカプセルデザイン）
            Button {
                viewModel.togglePlayback()
            } label: {
                HStack {
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    Text(viewModel.isPlaying ? "STOP" : "START")
                        .font(.system(size: 12, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 100, height: 36)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(.horizontal)
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20) -> some View {
        Text(label)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(focusedField == target ? .white : .primary.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                ZStack {
                    if focusedField == target {
                        Color.blue.opacity(0.4)
                            .blur(radius: 2)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.cyan, lineWidth: 1.5)
                            .shadow(color: .cyan, radius: 4)
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
                // 背景：サイバーグリッド（薄い円）
                Circle()
                    .stroke(Color.blue.opacity(0.05), lineWidth: 1)
                Circle()
                    .stroke(Color.blue.opacity(0.03), lineWidth: 20)
                
                // 1. 拍セグメント
                if viewModel.numerator > 1 {
                    ForEach(0..<viewModel.numerator, id: \.self) { i in
                        // --- 修正：12時から始まるように開始角を -90° 固定 ---
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
                            style: StrokeStyle(lineWidth: isCurrent ? 10 : 4, lineCap: .round)
                        )
                        .shadow(color: isCurrent ? colorForIntensity(viewModel.currentIntensity).opacity(0.5) : .clear, radius: isCurrent ? 5 : 0)
                    }
                } else {
                    // 分子が0 or 1の時も中央に配置
                    Circle()
                        .stroke(
                            viewModel.isPlaying ? colorForIntensity(viewModel.currentIntensity) : Color.white.opacity(0.05),
                            lineWidth: viewModel.isPlaying ? 10 : 4
                        )
                        .shadow(color: viewModel.isPlaying ? colorForIntensity(viewModel.currentIntensity).opacity(0.5) : .clear, radius: 10)
                        .frame(width: size, height: size)
                }
                
                // 2. 流動的な「スキャン針」
                if viewModel.isPlaying {
                    let progress = currentProgress()
                    // --- 修正：針も12時から始まるように位相を合わせる ---
                    let angle = (progress * 360.0) - 90.0
                    
                    // 針の光跡（レーダー風）
                    Circle()
                        .trim(from: max(0, progress - 0.1), to: progress)
                        .stroke(
                            AngularGradient(colors: [.clear, colorForIntensity(viewModel.currentIntensity).opacity(0.3)], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    // 針の本体
                    Capsule()
                        .fill(LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 2, height: radius)
                        .offset(y: -radius / 2)
                        .rotationEffect(.degrees(angle + 90)) // 90°進めた角度
                    
                    // 先端のコア
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(angle + 90))
                        .shadow(color: .white, radius: 3)
                }
            }
        }
        .padding(4)
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
