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
            if !viewModel.isSystemReady {
                ProgressView("Preparing...")
            } else {
                mainContent
            }
        }
        .onAppear {
            focusedField = .bpm
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // 1. 円グラフ型リズム表示
            PieIndicatorView(
                numerator: viewModel.numerator,
                currentBeat: viewModel.currentBeat,
                intensity: viewModel.currentIntensity,
                isPlaying: viewModel.isPlaying
            )
            .frame(width: 80, height: 80)
            .padding(.top, 2)
            
            Spacer(minLength: 0)
            
            // 2. 設定エリア（タップで切り替え）
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    // 基準音価
                    Text(viewModel.currentNoteName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(focusedField == .noteValue ? Color.accentColor : .secondary)
                        .onTapGesture { focusedField = .noteValue }
                        .focusable()
                        .focused($focusedField, equals: .noteValue)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // BPM
                    Text("\(viewModel.bpm)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(focusedField == .bpm ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .bpm }
                        .focusable()
                        .focused($focusedField, equals: .bpm)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                HStack(spacing: 8) {
                    // 分子
                    Text("\(viewModel.numerator)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(focusedField == .numerator ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .numerator }
                        .focusable()
                        .focused($focusedField, equals: .numerator)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    // 分母
                    Text("\(viewModel.denominator)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(focusedField == .denominator ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .denominator }
                        .focusable()
                        .focused($focusedField, equals: .denominator)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    // 簡易モードボタン
                    Button {
                        viewModel.isSimplifiedMode.toggle()
                    } label: {
                        Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.isSimplifiedMode ? Color.orange : .secondary)
                }
            }
            
            Spacer(minLength: 2)
            
            // 3. 再生ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(height: 32)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}

/// 円グラフ型インジケーター
struct PieIndicatorView: View {
    let numerator: Int
    let currentBeat: Int
    let intensity: BeatIntensity
    let isPlaying: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景の円
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                
                if numerator > 1 {
                    // 分割線と扇形
                    ForEach(0..<numerator, id: \.self) { i in
                        let startAngle = Double(i) * (360.0 / Double(numerator)) - 90
                        let endAngle = Double(i + 1) * (360.0 / Double(numerator)) - 90
                        
                        // 各ピース
                        Path { path in
                            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            path.move(to: center)
                            path.addArc(center: center, radius: geo.size.width / 2,
                                        startAngle: .degrees(startAngle + 2),
                                        endAngle: .degrees(endAngle - 2),
                                        clockwise: false)
                        }
                        .fill(pieceColor(for: i + 1))
                        .opacity(pieceOpacity(for: i + 1))
                    }
                } else {
                    // 1拍子や0拍子の場合は円全体
                    Circle()
                        .fill(pieceColor(for: 1))
                        .opacity(isPlaying ? 0.8 : 0.1)
                        .scaleEffect(isPlaying ? 1.05 : 1.0)
                }
            }
        }
    }
    
    private func pieceColor(for beat: Int) -> Color {
        guard beat == currentBeat else { return Color.gray }
        switch intensity {
        case .strong: return .orange
        case .medium: return .accentColor
        case .weak:   return .blue
        }
    }
    
    private func pieceOpacity(for beat: Int) -> Double {
        if beat == currentBeat { return 0.8 }
        return 0.1
    }
}

#Preview {
    ContentView()
}
