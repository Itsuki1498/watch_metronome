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
            // 1. 背景レイヤー: 画面いっぱいに広がる精密な円環
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .padding(2) // 最小限の余白で画面最大まで広げる
            .ignoresSafeArea()
            
            if !viewModel.isSystemReady {
                ProgressView()
                    .tint(.orange)
            } else {
                // 2. 前面レイヤー: フローティング操作UI
                mainControlUI
            }
        }
        .onAppear {
            focusedField = .bpm
        }
    }
    
    private var mainControlUI: some View {
        VStack(spacing: 0) {
            // 上部：BPM & 音価（少し透過させて背景を活かす）
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 4) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 14)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.orange.opacity(0.6))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 48)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .padding(.top, 25) // ステータスバーとの兼ね合い
            
            Spacer()
            
            // 中央：拍子設定（コンパクトにまとめてリングの視認性を確保）
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 20)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 14, weight: .ultraLight))
                        .foregroundStyle(.secondary.opacity(0.4))
                    
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 20)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                Button {
                    viewModel.isSimplifiedMode.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(viewModel.isSimplifiedMode ? .orange : .blue.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // 下部：再生ボタン（角丸を強くしてモダンに）
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(width: 60, height: 32)
            .tint(viewModel.isPlaying ? .red.opacity(0.7) : .green.opacity(0.7))
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding(.bottom, 15)
        }
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20) -> some View {
        Text(label)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(focusedField == target ? .white : .primary.opacity(0.7))
            .padding(.horizontal, 4)
            .background(
                ZStack {
                    if focusedField == target {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.2))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
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
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outerRadius = radius - 2 // 画面端ギリギリまで広げる
            let innerRadius = outerRadius - 6 // リングの幅を少し細くして洗練させる
            
            let isPlaying = viewModel.isPlaying
            let numerator = viewModel.numerator
            let totalTicks = Double(max(1, numerator))
            
            let currentProgress = isPlaying ? currentMeasureProgress() : 0.0
            let currentAngle = (currentProgress * 360.0) - 90.0
            
            if numerator > 0 {
                // 1. 外側リング: 画面のフレームのように配置
                let stepAngle = 360.0 / totalTicks
                for i in 0..<numerator {
                    let startAngle = Double(i) * stepAngle - 90
                    let endAngle = Double(i + 1) * stepAngle - 90
                    let isCurrent = isPlaying && (i + 1) == viewModel.currentBeat
                    
                    // 背景の微かな刻み
                    drawArc(context: context, center: center, radius: outerRadius, start: startAngle + 0.5, end: endAngle - 0.5, color: .white.opacity(0.03), width: 1.5)
                    
                    if isCurrent {
                        let effectiveStartAngle = max(startAngle, currentAngle)
                        if effectiveStartAngle < endAngle - 0.5 {
                            let color = colorForIntensity(viewModel.currentIntensity)
                            drawArc(context: context, center: center, radius: outerRadius, start: effectiveStartAngle + 0.5, end: endAngle - 0.5, color: color, width: 5)
                        }
                    }
                }
                
                // 2. 内側リング: 基準音符（中拍）
                let ticksPerMedium = Double(max(1, viewModel.ticksPerMediumBeat))
                let mediumBeatCount = Int(ceil(totalTicks / ticksPerMedium))
                
                for i in 0..<mediumBeatCount {
                    let startTick = Double(i) * ticksPerMedium
                    let endTick = min(totalTicks, Double(i + 1) * ticksPerMedium)
                    let startAngle = (startTick / totalTicks) * 360.0 - 90.0
                    let endAngle = (endTick / totalTicks) * 360.0 - 90.0
                    
                    if isPlaying && currentAngle >= startAngle && currentAngle < endAngle {
                        let effectiveStartAngle = max(startAngle, currentAngle)
                        if effectiveStartAngle < endAngle - 1 {
                            drawArc(context: context, center: center, radius: innerRadius, start: effectiveStartAngle + 1, end: endAngle - 1, color: .cyan.opacity(0.3), width: 3)
                        }
                    }
                }
            }
            
            // 3. 極細のスキャン針
            if isPlaying {
                let angle = currentAngle
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(
                    x: center.x + outerRadius * cos(angle * .pi / 180),
                    y: center.y + outerRadius * sin(angle * .pi / 180)
                )
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 1.0)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 1.5, y: endPoint.y - 1.5, width: 3, height: 3)), with: .color(.white))
            }
        }
    }
    
    private func drawArc(context: GraphicsContext, center: CGPoint, radius: CGFloat, start: Double, end: Double, color: Color, width: CGFloat) {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .butt))
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
        let last = viewModel.lastTickTime
        guard now >= last else { return 0.0 }
        let elapsedSinceLastTick = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000_000.0
        let beatIndex = Double(viewModel.currentBeat - 1)
        let totalProgress = (beatIndex + (elapsedSinceLastTick / viewModel.tickInterval)) / Double(max(1, viewModel.numerator))
        return totalProgress.truncatingRemainder(dividingBy: 1.0)
    }
}

#Preview {
    ContentView()
}
