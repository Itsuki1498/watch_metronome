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
            .padding(4) // パディングを微増させ、左右の見切れを物理的に防止
            .ignoresSafeArea()
            
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
            
            VStack(spacing: -2) {
                HStack(alignment: .center, spacing: 6) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 18, hPadding: 6)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(max(0, viewModel.validNoteValueOptions.count - 1)), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 50, hPadding: 4)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.top, 28)
            
            Spacer()
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 24, hPadding: 6)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 24, hPadding: 6)
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
            
            Spacer()
            
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
            }
            .frame(width: 60, height: 32)
            .tint(viewModel.isPlaying ? .red.opacity(0.8) : .green.opacity(0.8))
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
            .padding(.bottom, 12)
        }
        .padding(.horizontal)
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20, hPadding: CGFloat = 6) -> some View {
        Text(label)
            .font(.system(size: size, weight: .bold, design: .default).monospacedDigit())
            .foregroundStyle(focusedField == target ? .white : .primary.opacity(0.8))
            .padding(.horizontal, hPadding)
            .padding(.vertical, 2)
            .background(
                ZStack {
                    if focusedField == target {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.blue.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
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
            .animation(.easeInOut(duration: 0.1), value: focusedField)
    }
}

struct ModernPieIndicatorView: View {
    let viewModel: MetronomeViewModel
    let date: Date
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outerRadius = radius - 4 // さらに1px内側に寄せて見切れを防止
            let innerRadius = outerRadius - 12
            
            let isPlaying = viewModel.isPlaying
            let rawProgress = isPlaying ? currentMeasureProgress() : 0.0
            let needleProgress = min(0.9999, rawProgress.truncatingRemainder(dividingBy: 1.0))
            let currentAngle = (needleProgress * 360.0) - 90.0
            
            // 静的ベース
            context.stroke(Circle().path(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)), with: .color(.white.opacity(0.05)), lineWidth: 1)
            
            let numerator = viewModel.numerator
            
            if numerator > 0 {
                // 1. 外側リング (分母基準)
                let outerCount = Double(max(1, numerator))
                let outerStep = 1.0 / outerCount
                for i in 0..<Int(outerCount) {
                    let start = Double(i) * outerStep
                    let end = Double(i + 1) * outerStep
                    drawArc(context: context, center: center, radius: outerRadius, start: start * 360 - 89.5, end: end * 360 - 90.5, color: .white.opacity(0.04), width: 2)
                    
                    if isPlaying && needleProgress >= start && needleProgress < end {
                        let color = (i == 0) ? Color.orange : Color.cyan
                        let segStart = max(start * 360 - 90, currentAngle)
                        let segEnd = end * 360 - 90.5
                        if segStart < segEnd {
                            drawArc(context: context, center: center, radius: outerRadius, start: segStart, end: segEnd, color: color, width: 8)
                        }
                    }
                }
                
                // 2. 内側リング (基準音符準拠)
                let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
                let ticksPerRef = Double(max(1, viewModel.ticksPerRefNote))
                let mediumBeatCount = Int(ceil(totalTicks / ticksPerRef))
                
                for i in 0..<mediumBeatCount {
                    let startTick = Double(i) * ticksPerRef
                    let endTick = min(totalTicks, Double(i + 1) * ticksPerRef)
                    let start = startTick / totalTicks
                    let end = endTick / totalTicks
                    
                    drawArc(context: context, center: center, radius: innerRadius, start: start * 360 - 88.5, end: end * 360 - 91.5, color: .blue.opacity(0.06), width: 1.5)
                    
                    if isPlaying && needleProgress >= start && needleProgress < end {
                        let segStart = max(start * 360 - 90, currentAngle)
                        let segEnd = end * 360 - 91
                        if segStart < segEnd {
                            drawArc(context: context, center: center, radius: innerRadius, start: segStart, end: segEnd, color: .white.opacity(0.6), width: 5)
                        }
                    }
                }
            } else {
                // 0拍子（フラット）: 全て中拍（白）の単一リング
                drawArc(context: context, center: center, radius: outerRadius, start: -90, end: 270, color: .white.opacity(0.04), width: 2)
                if isPlaying {
                    drawArc(context: context, center: center, radius: outerRadius, start: currentAngle, end: 269.5, color: .cyan, width: 8)
                }
                
                // 内側も同様
                let ticksPerRef = Double(max(1, viewModel.ticksPerRefNote))
                let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
                let mediumBeatCount = Int(ceil(totalTicks / ticksPerRef))
                for i in 0..<mediumBeatCount {
                    let start = (Double(i) * ticksPerRef) / totalTicks
                    let end = min(totalTicks, (Double(i + 1) * ticksPerRef)) / totalTicks
                    drawArc(context: context, center: center, radius: innerRadius, start: start * 360 - 88.5, end: end * 360 - 91.5, color: .blue.opacity(0.06), width: 1.5)
                    if isPlaying && needleProgress >= start && needleProgress < end {
                        drawArc(context: context, center: center, radius: innerRadius, start: max(start * 360 - 90, currentAngle), end: end * 360 - 91, color: .white.opacity(0.6), width: 5)
                    }
                }
            }
            
            if isPlaying {
                let angle = currentAngle
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(x: center.x + outerRadius * cos(angle * .pi / 180), y: center.y + outerRadius * sin(angle * .pi / 180))
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 2, y: endPoint.y - 2, width: 4, height: 4)), with: .color(.white))
            }
        }
    }
    
    private func drawArc(context: GraphicsContext, center: CGPoint, radius: CGFloat, start: Double, end: Double, color: Color, width: CGFloat) {
        guard end > start else { return }
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }
    
    private func currentMeasureProgress() -> Double {
        let now = DispatchTime.now()
        let last = viewModel.lastTickTime
        guard now >= last else { return 0.0 }
        let elapsed = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000_000.0
        let beatIdx = viewModel.currentBeat - 1.0
        let totalProgress = (beatIdx * Double(viewModel.ticksPerOuterBeat)) + (elapsed / viewModel.tickInterval)
        return totalProgress / Double(viewModel.totalTicksInMeasure)
    }
}

#Preview {
    ContentView()
}
