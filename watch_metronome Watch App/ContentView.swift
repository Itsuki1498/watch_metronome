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
            // 背景レイヤー: 二重円環UI
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .padding(8)
            
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
            
            VStack(spacing: 2) {
                HStack(alignment: .center, spacing: 4) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 16)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 44)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 8, weight: .black))
                    .kerning(1)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(.top, 12)
            
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
                
                Button {
                    viewModel.isSimplifiedMode.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(viewModel.isSimplifiedMode ? .orange : .blue.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            
            Spacer()
            
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(width: 80, height: 32)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
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
                            .fill(Color.blue.opacity(0.25))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
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
            let outerRadius = size / 2
            let innerRadius = outerRadius - 12
            
            ZStack {
                // 1. 背景のベース
                Circle()
                    .stroke(Color.white.opacity(0.03), lineWidth: 1)
                
                // 2. 内側の「基準音符」インジケーター層
                if viewModel.numerator > 0 {
                    let mediumCount = max(1, viewModel.numerator / max(1, viewModel.ticksPerMediumBeat))
                    ForEach(0..<mediumCount, id: \.self) { i in
                        let angle = Double(i) * (360.0 / Double(mediumCount)) - 90
                        Path { path in
                            path.addArc(center: center, radius: innerRadius - 4,
                                        startAngle: .degrees(angle - 1),
                                        endAngle: .degrees(angle + 1),
                                        clockwise: false)
                        }
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 4)
                    }
                }
                
                // 3. 外側の「拍セグメント」（追従消灯エフェクト付き）
                if viewModel.numerator > 1 {
                    let progress = currentMeasureProgress()
                    let currentAngle = (progress * 360.0) - 90.0
                    
                    ForEach(0..<viewModel.numerator, id: \.self) { i in
                        segmentView(index: i, currentAngle: currentAngle, center: center, radius: outerRadius)
                    }
                }
                
                // 4. 流動的な「スキャン針」
                if viewModel.isPlaying {
                    let progress = currentMeasureProgress()
                    let angle = (progress * 360.0) - 90.0
                    
                    // 針の本体
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2, height: outerRadius)
                        .offset(y: -outerRadius / 2)
                        .rotationEffect(.degrees(angle + 90))
                        .shadow(color: .white.opacity(0.5), radius: 2)
                    
                    // 基準音符（中拍）の通過時に光るドット
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .offset(y: -innerRadius + 4)
                        .rotationEffect(.degrees(angle + 90))
                }
            }
        }
    }
    
    // セグメントの描画を別関数に切り出し、コンパイラの型チェック負荷を軽減
    private func segmentView(index: Int, currentAngle: Double, center: CGPoint, radius: CGFloat) -> some View {
        let stepAngle = 360.0 / Double(viewModel.numerator)
        let startAngle = Double(index) * stepAngle - 90
        let endAngle = Double(index + 1) * stepAngle - 90
        let isCurrent = (index + 1) == viewModel.currentBeat
        
        let effectiveStartAngle = isCurrent ? max(startAngle, currentAngle) : startAngle
        let hasContent = effectiveStartAngle < endAngle - 0.5
        
        return Group {
            if hasContent {
                Path { path in
                    path.addArc(center: center, radius: radius,
                                startAngle: .degrees(effectiveStartAngle + 0.5),
                                endAngle: .degrees(endAngle - 0.5),
                                clockwise: false)
                }
                .stroke(
                    isCurrent ? colorForIntensity(viewModel.currentIntensity) : Color.white.opacity(0.03),
                    style: StrokeStyle(lineWidth: isCurrent ? 8 : 2, lineCap: .butt)
                )
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
    
    private func currentMeasureProgress() -> Double {
        let now = DispatchTime.now()
        let elapsedSinceLastTick = Double(now.uptimeNanoseconds - viewModel.lastTickTime.uptimeNanoseconds) / 1_000_000_000.0
        let beatIndex = Double(viewModel.currentBeat - 1)
        let totalProgress = (beatIndex + (elapsedSinceLastTick / viewModel.tickInterval)) / Double(max(1, viewModel.numerator))
        return totalProgress.truncatingRemainder(dividingBy: 1.0)
    }
}

#Preview {
    ContentView()
}
