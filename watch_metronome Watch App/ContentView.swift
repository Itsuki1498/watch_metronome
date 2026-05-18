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
            .opacity(0.4)
            .scaleEffect(1.1)
            
            if !viewModel.isSystemReady {
                ProgressView()
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
            
            // 1. BPM & 音価設定
            HStack(alignment: .center, spacing: 4) {
                // 基準音価
                settingItem(target: .noteValue, label: viewModel.currentNoteName)
                    .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                
                Text("=")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                
                // BPM
                settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 48)
                    .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
            }
            
            // 2. 拍子設定 (分子 / 分母)
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    // 分子
                    settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 26)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    // 分母
                    settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 26)
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                // 簡易モード切替
                Button {
                    viewModel.isSimplifiedMode.toggle()
                } label: {
                    Image(systemName: viewModel.isSimplifiedMode ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isSimplifiedMode ? Color.orange : .secondary)
                .padding(.leading, 4)
            }
            .padding(.top, 4)
            
            Spacer()
            
            // 3. 再生ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
            }
            .frame(height: 40)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
    
    // 設定項目の共通コンポーネント
    private func settingItem(target: MetronomeViewModel.EditTarget, label: String, size: CGFloat = 20) -> some View {
        Text(label)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(focusedField == target ? Color.accentColor : .primary)
            .padding(.horizontal, 6)
            .background(focusedField == target ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = target
                WKInterfaceDevice.current().play(.click)
            }
            .focusable()
            .focused($focusedField, equals: target)
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
                    }
                } else {
                    Circle()
                        .fill(pieceColor(for: 1))
                        .opacity(isPlaying ? 0.3 : 0.05)
                }
            }
        }
        .padding(4)
    }
    
    private func pieceColor(for beat: Int) -> Color {
        guard beat == currentBeat else { return Color.white }
        switch intensity {
        case .strong:  return .orange
        case .medium:  return .accentColor
        case .weak:    return .blue
        case .silence: return .clear // 無音時は表示しない
        }
    }
    
    private func pieceOpacity(for beat: Int) -> Double {
        if beat == currentBeat { return 0.7 }
        return 0.1
    }
}

#Preview {
    ContentView()
}
