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
            // モダンな背景レイヤー: グラデーションとブラーを効かせた円環
            ModernPieIndicatorView(
                numerator: viewModel.numerator,
                currentBeat: viewModel.currentBeat,
                intensity: viewModel.currentIntensity,
                isPlaying: viewModel.isPlaying
            )
            .scaleEffect(1.2)
            
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
            
            // 1. BPM & 音価設定 (フローティング感のあるデザイン)
            HStack(alignment: .center, spacing: 4) {
                settingItem(target: .noteValue, label: viewModel.currentNoteName)
                    .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                
                Text("=")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.7))
                
                settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 50)
                    .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
            }
            .padding(.bottom, 4)
            
            // 2. 拍子設定 (分子 / 分母)
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 24)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 24)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                // ネオン風の簡易モードボタン
                Button {
                    viewModel.isSimplifiedMode.toggle()
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isSimplifiedMode ? Color.orange : Color.blue.opacity(0.8))
                .shadow(color: viewModel.isSimplifiedMode ? .orange.opacity(0.5) : .clear, radius: 5)
            }
            
            Spacer()
            
            // 3. 再生ボタン (シンプルかつモダン)
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
            }
            .frame(height: 42)
            .tint(viewModel.isPlaying ? .red.opacity(0.8) : .green.opacity(0.8))
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
    }
    
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20) -> some View {
        Text(label)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(focusedField == target ? Color.white : Color.primary.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                ZStack {
                    if focusedField == target {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.3))
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 2)
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
            .animation(.easeInOut(duration: 0.2), value: focusedField)
    }
}

/// モダンな円環型インジケーター
struct ModernPieIndicatorView: View {
    let numerator: Int
    let currentBeat: Int
    let intensity: BeatIntensity
    let isPlaying: Bool
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                // 背景のベースリング
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1), .blue.opacity(0.1)]),
                            center: .center
                        ),
                        lineWidth: 6
                    )
                
                if numerator > 1 {
                    ForEach(0..<numerator, id: \.self) { i in
                        let startAngle = Double(i) * (360.0 / Double(numerator)) - 90
                        let endAngle = Double(i + 1) * (360.0 / Double(numerator)) - 90
                        let isCurrent = (i + 1) == currentBeat
                        
                        // 軌跡のセグメント
                        Path { path in
                            path.addArc(center: center, radius: size / 2,
                                        startAngle: .degrees(startAngle + 1),
                                        endAngle: .degrees(endAngle - 1),
                                        clockwise: false)
                        }
                        .stroke(
                            isCurrent ? currentGradient : AnyShapeStyle(Color.white.opacity(0.05)),
                            style: StrokeStyle(lineWidth: isCurrent ? 8 : 4, lineCap: .round)
                        )
                        .shadow(color: isCurrent ? currentColor.opacity(0.6) : .clear, radius: isCurrent ? 6 : 0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: currentBeat)
                    }
                } else {
                    // 1拍子などの単一円
                    Circle()
                        .stroke(
                            isPlaying ? currentGradient : AnyShapeStyle(Color.white.opacity(0.1)),
                            lineWidth: 8
                        )
                        .shadow(color: isPlaying ? currentColor.opacity(0.4) : .clear, radius: 10)
                        .scaleEffect(isPlaying ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isPlaying)
                }
            }
        }
        .padding(6)
    }
    
    private var currentColor: Color {
        switch intensity {
        case .strong: return .orange
        case .medium: return .cyan
        case .weak, .silence: return .blue
        }
    }
    
    private var currentGradient: AnyShapeStyle {
        switch intensity {
        case .strong:
            return AnyShapeStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .medium:
            return AnyShapeStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .weak, .silence:
            return AnyShapeStyle(Color.blue)
        }
    }
}

#Preview {
    ContentView()
}
