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
            // 背景レイヤー: 円グラフ型インジケーター
            PieIndicatorView(
                numerator: viewModel.numerator,
                currentBeat: viewModel.currentBeat,
                intensity: viewModel.currentIntensity,
                isPlaying: viewModel.isPlaying
            )
            .opacity(0.3) // 薄く背景におく
            .scaleEffect(1.1)
            
            if !viewModel.isSystemReady {
                ProgressView()
            } else {
                // 前面レイヤー: 操作UI
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
            
            // BPM & 音価
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(viewModel.currentNoteName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(focusedField == .noteValue ? Color.accentColor : .secondary)
                    .onTapGesture { focusedField = .noteValue }
                    .focusable()
                    .focused($focusedField, equals: .noteValue)
                    .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                
                Text("=")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("\(viewModel.bpm)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(focusedField == .bpm ? Color.accentColor : .primary)
                    .onTapGesture { focusedField = .bpm }
                    .focusable()
                    .focused($focusedField, equals: .bpm)
                    .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
            }
            
            // 拍子 (分子 / 分母) & 簡易モード
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("\(viewModel.numerator)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(focusedField == .numerator ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .numerator }
                        .focusable()
                        .focused($focusedField, equals: .numerator)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    Text("\(viewModel.denominator)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(focusedField == .denominator ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .denominator }
                        .focusable()
                        .focused($focusedField, equals: .denominator)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                // 弱拍ミュートボタン
                Button {
                    viewModel.isSimplifiedMode.toggle()
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isSimplifiedMode ? Color.orange : .secondary)
            }
            .padding(.top, 4)
            
            Spacer()
            
            // 再生ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
            }
            .frame(height: 38)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}

/// 背景用：円グラフ型インジケーター
struct PieIndicatorView: View {
    let numerator: Int
    let currentBeat: Int
    let intensity: BeatIntensity
    let isPlaying: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ベースのガイド円
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                
                if numerator > 1 {
                    ForEach(0..<numerator, id: \.self) { i in
                        let startAngle = Double(i) * (360.0 / Double(numerator)) - 90
                        let endAngle = Double(i + 1) * (360.0 / Double(numerator)) - 90
                        
                        Path { path in
                            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            path.move(to: center)
                            path.addArc(center: center, radius: geo.size.width / 2,
                                        startAngle: .degrees(startAngle + 1),
                                        endAngle: .degrees(endAngle - 1),
                                        clockwise: false)
                        }
                        .fill(pieceColor(for: i + 1))
                        .opacity(pieceOpacity(for: i + 1))
                        .animation(.easeInOut(duration: 0.1), value: currentBeat)
                    }
                } else {
                    Circle()
                        .fill(pieceColor(for: 1))
                        .opacity(isPlaying ? 0.3 : 0.05)
                        .scaleEffect(isPlaying ? 1.02 : 1.0)
                }
            }
        }
        .padding(4)
    }
    
    private func pieceColor(for beat: Int) -> Color {
        guard beat == currentBeat else { return Color.white }
        switch intensity {
        case .strong: return .orange
        case .medium: return .accentColor
        case .weak:   return .blue
        }
    }
    
    private func pieceOpacity(for beat: Int) -> Double {
        if beat == currentBeat { return 0.6 }
        return 0.1
    }
}

#Preview {
    ContentView()
}
