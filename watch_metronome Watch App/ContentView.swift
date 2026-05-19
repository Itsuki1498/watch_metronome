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
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .padding(2)
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
            
            let isPlaying = viewModel.isPlaying
            
            // --- 精密な同期計算 (フリッカー防止ガード) ---
            let currentProgress = isPlaying ? currentMeasureProgress() : 0.0
            // 360度に達した瞬間に0に戻る際の不連続性を考慮
            let currentAngle = (currentProgress * 359.99) - 90.0
            
            // 1. 静的ベース
            context.stroke(Circle().path(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)), with: .color(.white.opacity(0.05)), lineWidth: 1)
            
            if viewModel.numerator > 0 {
                // 2. 外側リング (分母基準)
                let outerCount = Double(max(1, viewModel.numerator))
                let outerStep = 360.0 / outerCount
                for i in 0..<Int(outerCount) {
                    let start = Double(i) * outerStep - 90
                    let end = Double(i + 1) * outerStep - 90
                    
                    drawArc(context: context, center: center, radius: outerRadius, start: start + 0.5, end: end - 0.5, color: .white.opacity(0.04), width: 2)
                    
                    // 針の現在位置に基づいたアクティブ描画
                    if isPlaying {
                        let effectiveStart = max(start, currentAngle)
                        if effectiveStart < end - 0.5 && currentAngle >= start {
                            let color = (i == 0) ? Color.orange : Color.cyan
                            drawArc(context: context, center: center, radius: outerRadius, start: effectiveStart + 0.5, end: end - 0.5, color: color, width: 8)
                        }
                    }
                }
                
                // 3. 内側リング (基準音符基準のパルス)
                let innerCount = Double(max(1, viewModel.totalTicksInMeasure))
                let innerStep = 360.0 / innerCount
                for i in 0..<Int(innerCount) {
                    let start = Double(i) * innerStep - 90
                    let end = Double(i + 1) * innerStep - 90
                    
                    drawArc(context: context, center: center, radius: innerRadius, start: start + 1.5, end: end - 1.5, color: .blue.opacity(0.06), width: 1.5)
                    
                    if isPlaying {
                        let effectiveStart = max(start, currentAngle)
                        if effectiveStart < end - 1.5 && currentAngle >= start {
                            drawArc(context: context, center: center, radius: innerRadius, start: effectiveStart + 1.5, end: end - 1.5, color: .white.opacity(0.6), width: 5)
                        }
                    }
                }
            }
            
            // 4. スキャン針
            if isPlaying {
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(
                    x: center.x + outerRadius * cos(currentAngle * .pi / 180),
                    y: center.y + outerRadius * sin(currentAngle * .pi / 180)
                )
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 2, y: endPoint.y - 2, width: 4, height: 4)), with: .color(.white))
            }
        }
    }
    
    private func drawArc(context: GraphicsContext, center: CGPoint, radius: CGFloat, start: Double, end: Double, color: Color, width: CGFloat) {
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
        let currentPulseProgress = (beatIdx * Double(viewModel.ticksPerOuterBeat)) + (elapsed / viewModel.tickInterval)
        let totalProgress = currentPulseProgress / Double(viewModel.totalTicksInMeasure)
        
        return totalProgress.truncatingRemainder(dividingBy: 1.0)
    }
}

#Preview {
    ContentView()
}
