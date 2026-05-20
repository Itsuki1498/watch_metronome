//
//  ContentView.swift
//  watch_metronome
//
//  Created by Itsuki & Gemini on 2026/05/20.
//

import SwiftUI

@available(iOS 16.7, *)
struct ContentView: View {
    @State private var viewModel = MetronomeViewModel()
    @FocusState private var focusedField: MetronomeViewModel.EditTarget?
    @State private var isAdvancedMode: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 背景: Canvas UI (大画面向けにスケーリング)
                TimelineView(.animation(minimumInterval: 0.016)) { context in
                    ModernPieIndicatorView(
                        viewModel: viewModel,
                        date: context.date
                    )
                    .scaleEffect(1.5) // iPhoneの大画面に合わせて拡大
                }
                
                VStack {
                    Spacer()
                    
                    // BPM & Note Value
                    VStack(spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            noteValueDisplay(focused: focusedField == .noteValue)
                                .onTapGesture { focusedField = .noteValue }
                            
                            Text("=")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 80, hPadding: 10)
                        }
                        
                        Text("BPM")
                            .font(.system(size: 18, weight: .bold))
                            .kerning(2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)
                    
                    // Meter
                    HStack(spacing: 20) {
                        settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 40, hPadding: 15)
                        Text("/")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.secondary)
                        settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 40, hPadding: 15)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 30) {
                        // Rhythm Mode
                        Button {
                            viewModel.nextRhythmMode()
                        } label: {
                            Image(systemName: modeIcon(viewModel.rhythmMode))
                                .font(.system(size: 30))
                                .frame(width: 80, height: 60)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        // Play/Stop
                        Button {
                            viewModel.togglePlayback()
                        } label: {
                            Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                                .font(.system(size: 40))
                                .frame(width: 100, height: 80)
                                .background(viewModel.isPlaying ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                .clipShape(Capsule())
                                .foregroundColor(viewModel.isPlaying ? .red : .green)
                        }
                        
                        // Advanced Settings
                        Button {
                            isAdvancedMode.toggle()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 30))
                                .frame(width: 80, height: 60)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Metronome Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Advanced") {
                        isAdvancedMode.toggle()
                    }
                }
            }
            .sheet(isPresented: $isAdvancedMode) {
                AdvancedSettingsView(viewModel: viewModel)
            }
        }
    }
    
    private func modeIcon(_ mode: RhythmMode) -> String {
        switch mode {
        case .all:          return "speaker.wave.3.fill"
        case .strongMedium: return "speaker.wave.1.fill"
        case .strongOnly:   return "speaker.fill"
        }
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat, hPadding: CGFloat) -> some View {
        Text(label)
            .font(.system(size: size, weight: .bold, design: .default).monospacedDigit())
            .foregroundColor(focusedField == target ? .white : .primary.opacity(0.8))
            .padding(.horizontal, hPadding)
            .padding(.vertical, 5)
            .background(
                ZStack {
                    if focusedField == target {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.2))
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cyan, lineWidth: 2)
                    }
                }
            )
            .onTapGesture {
                focusedField = target
            }
    }
    
    private func noteValueDisplay(focused: Bool) -> some View {
        Image(viewModel.currentNote.imageName)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(height: 40)
            .padding(8)
            .background(
                ZStack {
                    if focused {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.2))
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cyan, lineWidth: 2)
                    }
                }
            )
    }
}

@available(iOS 16.7, *)
struct AdvancedSettingsView: View {
    @Bindable var viewModel: MetronomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Complex Meter (複合拍子)") {
                    Text("複合拍子の高度な設定（3+2, 2+2+3 等）は将来のアップデートで完全に統合されます。現在は分子/分母の変更のみサポートしています。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Tempo Automation (BPM変化)") {
                    Text("セットリスト機能により、指定した小節数ごとにBPMを自動変化させるプログラミングが可能です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 16.7, *)
struct ModernPieIndicatorView: View {
    let viewModel: MetronomeViewModel
    let date: Date
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outerRadius = radius - 10
            let innerRadius = outerRadius - 20
            
            let isPlaying = viewModel.isPlaying
            let rawProgress = isPlaying ? currentMeasureProgress() : 0.0
            let needleProgress = rawProgress.truncatingRemainder(dividingBy: 1.0)
            let safeProgress = needleProgress > 0.999 ? 0.0 : needleProgress
            let currentAngle = (safeProgress * 360.0) - 90.0
            
            context.stroke(Circle().path(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)), with: .color(.white.opacity(0.1)), lineWidth: 2)
            
            if viewModel.numerator > 0 {
                let outerCount = Double(max(1, viewModel.numerator))
                let outerStep = 1.0 / outerCount
                for i in 0..<Int(outerCount) {
                    let rangeStart = Double(i) * outerStep
                    let rangeEnd = Double(i + 1) * outerStep
                    drawArc(context: context, center: center, radius: outerRadius, start: rangeStart * 360 - 89, end: rangeEnd * 360 - 91, color: .white.opacity(0.1), width: 4)
                    
                    if isPlaying && safeProgress >= rangeStart && safeProgress < rangeEnd {
                        let color = (i == 0) ? Color.orange : Color.cyan
                        let segStart = max(rangeStart * 360 - 90, currentAngle)
                        let segEnd = rangeEnd * 360 - 91
                        if segStart < segEnd {
                            drawArc(context: context, center: center, radius: outerRadius, start: segStart, end: segEnd, color: color, width: 12)
                        }
                    }
                }
                
                let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
                let ticksPerRef = Double(max(1, viewModel.ticksPerRefNote))
                let mediumBeatCount = Int(ceil(totalTicks / ticksPerRef))
                
                for i in 0..<mediumBeatCount {
                    let start = (Double(i) * ticksPerRef) / totalTicks
                    let end = min(totalTicks, (Double(i + 1) * ticksPerRef)) / totalTicks
                    drawArc(context: context, center: center, radius: innerRadius, start: start * 360 - 88, end: end * 360 - 92, color: .blue.opacity(0.15), width: 3)
                    
                    if isPlaying && safeProgress >= start && safeProgress < end {
                        let segStart = max(start * 360 - 90, currentAngle)
                        let segEnd = end * 360 - 92
                        if segStart < segEnd {
                            drawArc(context: context, center: center, radius: innerRadius, start: segStart, end: segEnd, color: .white.opacity(0.8), width: 8)
                        }
                    }
                }
            }
            
            if isPlaying {
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(x: center.x + outerRadius * cos(currentAngle * .pi / 180), y: center.y + outerRadius * sin(currentAngle * .pi / 180))
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.white), lineWidth: 2)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 4, y: endPoint.y - 4, width: 8, height: 8)), with: .color(.white))
            }
        }
    }
    
    private func drawArc(context: GraphicsContext, center: CGPoint, radius: CGFloat, start: Double, end: Double, color: Color, width: CGFloat) {
        guard end > start else { return }
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
    
    private func currentMeasureProgress() -> Double {
        let now = DispatchTime.now()
        let last = viewModel.lastTickTime
        guard now >= last else { return 0.0 }
        let elapsed = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000_000.0
        let beatIdx = viewModel.currentBeat - 1.0
        let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
        let beatProgress = (beatIdx * Double(viewModel.ticksPerOuterBeat)) + (elapsed / viewModel.tickInterval)
        return beatProgress / totalTicks
    }
}
