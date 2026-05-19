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
            // 背景レイヤー: 精密な同期UI
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .padding(6)
            
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
            
            VStack(spacing: 1) {
                HStack(alignment: .center, spacing: 2) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 14)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.orange.opacity(0.8))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 44)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.top, 10)
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 22)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 16, weight: .ultraLight))
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
            .padding(.top, 2)
            
            Spacer()
            
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(width: 70, height: 32)
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
            .foregroundStyle(focusedField == target ? .white : .primary.opacity(0.9))
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
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outerRadius = radius - 2
            let innerRadius = outerRadius - 10
            
            // 1. 静的ベースライン
            context.stroke(
                Circle().path(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)),
                with: .color(.white.opacity(0.05)),
                lineWidth: 1
            )
            
            let isPlaying = viewModel.isPlaying
            let numerator = viewModel.numerator
            let totalTicks = Double(max(1, numerator))
            
            // --- 同期された進捗計算 ---
            let currentProgress = isPlaying ? currentMeasureProgress() : 0.0
            let currentAngle = (currentProgress * 360.0) - 90.0
            // ---------------------
            
            if numerator > 0 {
                // 2. 外側リング
                let stepAngle = 360.0 / totalTicks
                for i in 0..<numerator {
                    let startAngle = Double(i) * stepAngle - 90
                    let endAngle = Double(i + 1) * stepAngle - 90
                    let isCurrent = isPlaying && (i + 1) == viewModel.currentBeat
                    
                    // ベース
                    drawArc(context: context, center: center, radius: outerRadius, start: startAngle + 1, end: endAngle - 1, color: .white.opacity(0.05), width: 2)
                    
                    // アクティブ（追従消灯）
                    if isCurrent {
                        let effectiveStartAngle = max(startAngle, currentAngle)
                        if effectiveStartAngle < endAngle - 1 {
                            let color = colorForIntensity(viewModel.currentIntensity)
                            drawArc(context: context, center: center, radius: outerRadius, start: effectiveStartAngle + 1, end: endAngle - 1, color: color, width: 6)
                        }
                    }
                }
                
                // 3. 内側リング (中拍)
                let ticksPerMedium = Double(max(1, viewModel.ticksPerMediumBeat))
                let mediumBeatCount = Int(ceil(totalTicks / ticksPerMedium))
                
                for i in 0..<mediumBeatCount {
                    let startTick = Double(i) * ticksPerMedium
                    let endTick = min(totalTicks, Double(i + 1) * ticksPerMedium)
                    let startAngle = (startTick / totalTicks) * 360.0 - 90.0
                    let endAngle = (endTick / totalTicks) * 360.0 - 90.0
                    
                    drawArc(context: context, center: center, radius: innerRadius, start: startAngle + 1.5, end: endAngle - 1.5, color: .cyan.opacity(0.05), width: 1.5)
                    
                    if isPlaying && currentAngle >= startAngle && currentAngle < endAngle {
                        let effectiveStartAngle = max(startAngle, currentAngle)
                        if effectiveStartAngle < endAngle - 1.5 {
                            drawArc(context: context, center: center, radius: innerRadius, start: effectiveStartAngle + 1.5, end: endAngle - 1.5, color: .cyan.opacity(0.4), width: 4)
                        }
                    }
                }
            }
            
            // 4. スキャン針
            if isPlaying {
                let angle = currentAngle
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(
                    x: center.x + outerRadius * cos(angle * .pi / 180),
                    y: center.y + outerRadius * sin(angle * .pi / 180)
                )
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.white), lineWidth: 1.5)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 2, y: endPoint.y - 2, width: 4, height: 4)), with: .color(.white))
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
        
        // リードタイム（開始までの100msなど）の間は0に固定してフリッカーを防ぐ
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
