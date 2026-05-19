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
        GeometryReader { screen in
            let w = screen.size.width
            let h = screen.size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            // リングの半径を画面幅から計算（少し余裕を持たせる）
            let ringRadius = (min(w, h) / 2) - 6
            
            ZStack {
                // 1. 背景レイヤー: 精密な円環 (セーフエリア無視で画面全体を使用)
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    center: center,
                    radius: ringRadius
                )
                .ignoresSafeArea()
                
                // 2. コントロールレイヤー (標準のセーフエリア内で配置)
                mainControlUI
                
                // 3. 左右下の弧状ボタン (画面の角に精密配置)
                arcControlButtons(center: center, radius: ringRadius + 2, width: w, height: h)
            }
        }
        .onAppear {
            focusedField = .bpm
        }
    }
    
    private var mainControlUI: some View {
        VStack(spacing: 0) {
            // 上部：BPMセクション
            VStack(spacing: -2) {
                HStack(alignment: .center, spacing: 4) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 16, hPadding: 6)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(max(0, viewModel.validNoteValueOptions.count - 1)), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 52, hPadding: 4)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.top, 30)
            
            Spacer()
            
            // 中央：拍子セクション
            HStack(spacing: 4) {
                settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 28, hPadding: 8)
                    .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                
                Text("/")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.5))
                
                settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 28, hPadding: 8)
                    .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            }
            .padding(.bottom, 20)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private func arcControlButtons(center: CGPoint, radius: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let btnSize: CGFloat = 55
        return ZStack {
            // 左下：簡易化モード
            Button {
                viewModel.isSimplifiedMode.toggle()
                WKInterfaceDevice.current().play(.click)
            } label: {
                ZStack(alignment: .bottomLeading) {
                    ConcaveArcShape(corner: .bottomLeft, screenCenter: center, ringRadius: radius)
                        .fill(viewModel.isSimplifiedMode ? Color.orange.opacity(0.3) : Color.gray.opacity(0.15))
                    Image(systemName: "waveform.path.badge.minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(viewModel.isSimplifiedMode ? .orange : .secondary)
                        .padding(.leading, 10)
                        .padding(.bottom, 12)
                }
            }
            .buttonStyle(.plain)
            .frame(width: btnSize, height: btnSize)
            .position(x: btnSize/2, y: height - btnSize/2)
            
            // 右下：再生/停止
            Button {
                viewModel.togglePlayback()
                WKInterfaceDevice.current().play(.click)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ConcaveArcShape(corner: .bottomRight, screenCenter: center, ringRadius: radius)
                        .fill(viewModel.isPlaying ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.isPlaying ? .red : .green)
                        .padding(.trailing, 10)
                        .padding(.bottom, 12)
                }
            }
            .buttonStyle(.plain)
            .frame(width: btnSize, height: btnSize)
            .position(x: width - btnSize/2, y: height - btnSize/2)
        }
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

/// リングの外側に沿って「窪んだ」特殊な三角形
struct ConcaveArcShape: Shape {
    enum Corner { case bottomLeft, bottomRight }
    let corner: Corner
    let screenCenter: CGPoint
    let ringRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // この図形自体の左上を (0,0) とした時の、画面中心の相対位置
        // ボタンは画面の角にあるので、screenCenter へのベクトルを計算
        let localCenter: CGPoint
        if corner == .bottomLeft {
            // ボタンの矩形は画面の左下にある (x:0, y:H-btnSize)
            localCenter = CGPoint(x: screenCenter.x, y: screenCenter.y - (screenCenter.y * 2 - h))
        } else {
            // 右下にある (x:W-btnSize, y:H-btnSize)
            localCenter = CGPoint(x: screenCenter.x - (screenCenter.x * 2 - w), y: screenCenter.y - (screenCenter.y * 2 - h))
        }
        
        switch corner {
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: 0)) // 画面左端
            path.addLine(to: CGPoint(x: 0, y: h)) // 画面角
            path.addLine(to: CGPoint(x: w, y: h)) // 画面下端
            // 窪んだ円弧を描く (180度から135度方向へ逆回転)
            path.addArc(center: localCenter, radius: ringRadius,
                        startAngle: .degrees(90),
                        endAngle: .degrees(180),
                        clockwise: false)
        case .bottomRight:
            path.move(to: CGPoint(x: w, y: 0)) // 画面右端
            path.addLine(to: CGPoint(x: w, y: h)) // 画面角
            path.addLine(to: CGPoint(x: 0, y: h)) // 画面下端
            // 窪んだ円弧を描く (0度から45度方向へ)
            path.addArc(center: localCenter, radius: ringRadius,
                        startAngle: .degrees(90),
                        endAngle: .degrees(0),
                        clockwise: true)
        }
        path.closeSubpath()
        return path
    }
}

struct ModernPieIndicatorView: View {
    let viewModel: MetronomeViewModel
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let outerRadius = radius
            let innerRadius = outerRadius - 12
            
            let isPlaying = viewModel.isPlaying
            let rawProgress = isPlaying ? currentMeasureProgress() : 0.0
            let needleProgress = min(0.9999, rawProgress.truncatingRemainder(dividingBy: 1.0))
            let currentAngle = (needleProgress * 360.0) - 90.0
            
            // 1. 静的ベース
            context.stroke(Circle().path(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)), with: .color(.white.opacity(0.05)), lineWidth: 1)
            
            if viewModel.numerator > 0 {
                // 2. 外側リング
                let outerCount = Double(max(1, viewModel.numerator))
                let outerStep = 1.0 / outerCount
                for i in 0..<Int(outerCount) {
                    let rangeStart = Double(i) * outerStep
                    let rangeEnd = Double(i + 1) * outerStep
                    drawArc(context: context, center: center, radius: outerRadius, start: rangeStart * 360 - 89.5, end: rangeEnd * 360 - 90.5, color: .white.opacity(0.04), width: 2)
                    if isPlaying && needleProgress >= rangeStart && needleProgress < rangeEnd {
                        let color = (i == 0) ? Color.orange : Color.cyan
                        drawArc(context: context, center: center, radius: outerRadius, start: max(rangeStart * 360 - 90, currentAngle), end: rangeEnd * 360 - 90.5, color: color, width: 8)
                    }
                }
                
                // 3. 内側リング
                let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
                let ticksPerRef = Double(max(1, viewModel.ticksPerRefNote))
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
            
            // 4. スキャン針
            if isPlaying {
                var path = Path()
                path.move(to: center)
                let endPoint = CGPoint(x: center.x + outerRadius * cos(currentAngle * .pi / 180), y: center.y + outerRadius * sin(currentAngle * .pi / 180))
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
        let elapsed = Double(now.uptimeNanoseconds - viewModel.lastTickTime.uptimeNanoseconds) / 1_000_000_000.0
        let beatIdx = viewModel.currentBeat - 1.0
        let totalProgress = (beatIdx * Double(viewModel.ticksPerOuterBeat)) + (elapsed / viewModel.tickInterval)
        return totalProgress / Double(viewModel.totalTicksInMeasure)
    }
}

#Preview {
    ContentView()
}
