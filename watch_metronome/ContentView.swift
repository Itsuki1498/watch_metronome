//
//  ContentView.swift
//  watch_metronome
//
//  Created by Itsuki & Gemini on 2026/05/20.
//

import SwiftUI

@available(iOS 16.7, *)
struct ContentView: View {
    @StateObject private var viewModel = MetronomeViewModel()
    @FocusState private var focusedField: MetronomeViewModel.EditTarget?
    @State private var isAdvancedMode: Bool = false
    
    // UIアニメーション用のステート
    @State private var tapAnimate: Bool = false
    @State private var dragAngle: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // 1. 背景：Canvas UI (大画面向け)
                TimelineView(.animation(minimumInterval: 0.016)) { context in
                    ModernPieIndicatorView(
                        viewModel: viewModel,
                        date: context.date
                    )
                    .padding(30)
                    .opacity(0.8)
                }
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // 2. メインBPM表示 & ダイヤル
                    bpmDialSection
                    
                    // 3. 拍子表示
                    meterSection
                    
                    Spacer()
                    
                    // 4. メインコントロール
                    transportSection
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Metronome Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdvancedMode.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $isAdvancedMode) {
                AdvancedSettingsView(viewModel: viewModel)
            }
        }
    }
    
    // BPMダイヤルセクション
    private var bpmDialSection: some View {
        VStack(spacing: -10) {
            ZStack {
                // タップエリア
                Circle()
                    .fill(Color.cyan.opacity(tapAnimate ? 0.1 : 0.02))
                    .frame(width: 260, height: 260)
                    .scaleEffect(tapAnimate ? 1.05 : 1.0)
                    .onTapGesture {
                        viewModel.tapTempo()
                        withAnimation(.easeOut(duration: 0.1)) {
                            tapAnimate = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            tapAnimate = false
                        }
                    }
                
                // ドラッグ・ダイヤル（外周）
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 240, height: 240)
                
                // 現在のBPM
                VStack(spacing: 0) {
                    Text("\(viewModel.bpm)")
                        .font(.system(size: 90, weight: .black, design: .default).monospacedDigit())
                        .foregroundColor(.white)
                    Text("BPM")
                        .font(.system(size: 18, weight: .bold))
                        .kerning(4)
                        .foregroundColor(.secondary)
                }
                
                // インジケーター（ドラッグ位置）
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 12, height: 12)
                    .offset(y: -120)
                    .rotationEffect(.degrees(dragAngle))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateBpmFromDrag(value: value)
                            }
                    )
            }
            
            Text("TAP")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan.opacity(0.6))
                .padding(.top, 20)
        }
    }
    
    // 拍子セクション
    private var meterSection: some View {
        HStack(spacing: 20) {
            // 音価
            Image(viewModel.currentNote.imageName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(height: 34)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundColor(.white)
            
            Text("/")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.secondary)
            
            // 拍子
            HStack(spacing: 4) {
                Text("\(viewModel.numerator)")
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
                Text("/")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(viewModel.denominator)")
                    .font(.system(size: 40, weight: .bold).monospacedDigit())
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundColor(.white)
        }
    }
    
    // トランスポート（再生・停止・モード）
    private var transportSection: some View {
        HStack(spacing: 40) {
            // リズムモード
            Button {
                viewModel.nextRhythmMode()
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: modeIcon(viewModel.rhythmMode))
                        .font(.system(size: 24))
                    Text(modeName(viewModel.rhythmMode))
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 70, height: 70)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(Circle())
            }
            
            // 再生 / 停止
            Button {
                viewModel.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isPlaying ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isPlaying ? .red : .green)
                }
            }
            
            // プリセット（将来用）
            Button {
                // TODO: Preset
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 24))
                    Text("PRESET")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(width: 70, height: 70)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.secondary)
                .clipShape(Circle())
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
    
    private func modeName(_ mode: RhythmMode) -> String {
        switch mode {
        case .all:          return "FULL"
        case .strongMedium: return "BEAT"
        case .strongOnly:   return "BAR"
        }
    }
    
    // ダイヤル操作ロジック
    private func updateBpmFromDrag(value: DragGesture.Value) {
        let vector = CGVector(dx: value.location.x, dy: value.location.y)
        let angle = atan2(vector.dx, -vector.dy) * 180 / .pi
        let normalizedAngle = angle < 0 ? angle + 360 : angle
        
        let diff = normalizedAngle - dragAngle
        // 急激な反転を防止
        if abs(diff) < 180 {
            let bpmChange = Int(diff / 5) // 感度調整
            if bpmChange != 0 {
                viewModel.bpm += bpmChange
                dragAngle = normalizedAngle
            }
        } else {
            dragAngle = normalizedAngle
        }
    }
}

@available(iOS 16.7, *)
struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Beat Patterns (複合拍子)") {
                    Text("アクセントのグループ化を設定できます。")
                        .font(.caption)
                    
                    HStack {
                        ForEach(0..<viewModel.beatPattern.count, id: \.self) { index in
                            Stepper("\(viewModel.beatPattern[index])", value: Binding(
                                get: { viewModel.beatPattern[index] },
                                set: { newValue in
                                    var newPattern = viewModel.beatPattern
                                    newPattern[index] = max(1, newValue)
                                    viewModel.beatPattern = newPattern
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        Button {
                            var newPattern = viewModel.beatPattern
                            newPattern.append(1)
                            viewModel.beatPattern = newPattern
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        if viewModel.beatPattern.count > 1 {
                            Button {
                                var newPattern = viewModel.beatPattern
                                newPattern.removeLast()
                                viewModel.beatPattern = newPattern
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section("Denominator (分母)") {
                    Picker("Denominator", selection: $viewModel.displayDenominatorIndex) {
                        ForEach(0..<viewModel.denominatorOptions.count, id: \.self) { i in
                            Text("\(viewModel.denominatorOptions[i])").tag(Double(i))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Note Value (基準音価)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(0..<viewModel.validNoteValueOptions.count, id: \.self) { i in
                                let note = viewModel.validNoteValueOptions[i]
                                Button {
                                    viewModel.displayNoteValueIndex = Double(i)
                                } label: {
                                    Image(note.imageName)
                                        .resizable()
                                        .renderingMode(.template)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 30)
                                        .padding(10)
                                        .background(viewModel.currentNote.multiplier == note.multiplier ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
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
            let innerRadius = outerRadius - 25
            
            let isPlaying = viewModel.isPlaying
            let rawProgress = isPlaying ? currentMeasureProgress() : 0.0
            let needleProgress = rawProgress.truncatingRemainder(dividingBy: 1.0)
            let safeProgress = needleProgress > 0.999 ? 0.0 : needleProgress
            let currentAngle = (safeProgress * 360.0) - 90.0
            
            context.stroke(Circle().path(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)), with: .color(.white.opacity(0.05)), lineWidth: 2)
            
            if viewModel.numerator > 0 {
                let outerCount = Double(max(1, viewModel.numerator))
                let outerStep = 1.0 / outerCount
                for i in 0..<Int(outerCount) {
                    let rangeStart = Double(i) * outerStep
                    let rangeEnd = Double(i + 1) * outerStep
                    drawArc(context: context, center: center, radius: outerRadius, start: rangeStart * 360 - 89, end: rangeEnd * 360 - 91, color: .white.opacity(0.08), width: 6)
                    
                    if isPlaying && safeProgress >= rangeStart && safeProgress < rangeEnd {
                        let color = (i == 0) ? Color.orange : Color.cyan
                        let segStart = max(rangeStart * 360 - 90, currentAngle)
                        let segEnd = rangeEnd * 360 - 91
                        if segStart < segEnd {
                            drawArc(context: context, center: center, radius: outerRadius, start: segStart, end: segEnd, color: color, width: 14)
                        }
                    }
                }
                
                let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
                let ticksPerRef = Double(max(1, viewModel.ticksPerRefNote))
                let mediumBeatCount = Int(ceil(totalTicks / ticksPerRef))
                
                for i in 0..<mediumBeatCount {
                    let start = (Double(i) * ticksPerRef) / totalTicks
                    let end = min(totalTicks, (Double(i + 1) * ticksPerRef)) / totalTicks
                    drawArc(context: context, center: center, radius: innerRadius, start: start * 360 - 88, end: end * 360 - 92, color: .blue.opacity(0.1), width: 4)
                    
                    if isPlaying && safeProgress >= start && safeProgress < end {
                        let segStart = max(start * 360 - 90, currentAngle)
                        let segEnd = end * 360 - 92
                        if segStart < segEnd {
                            drawArc(context: context, center: center, radius: innerRadius, start: segStart, end: segEnd, color: .white.opacity(0.7), width: 10)
                        }
                    }
                }
            }
            
            if isPlaying {
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(x: center.x + outerRadius * cos(currentAngle * .pi / 180), y: center.y + outerRadius * sin(currentAngle * .pi / 180))
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 3)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 5, y: endPoint.y - 5, width: 10, height: 10)), with: .color(.white))
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
