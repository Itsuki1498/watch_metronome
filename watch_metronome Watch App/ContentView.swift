//
//  ContentView.swift
//  watch_metronome Watch App
//
//  Created by 執行一生 on 2026/05/18.
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
            // 拍のインジケーター
            indicatorView
                .frame(height: 20)
                .padding(.top, 2)
            
            Spacer(minLength: 0)
            
            // 設定項目エリア
            VStack(spacing: 2) {
                // 1行目: BPMと基準音価
                HStack(spacing: 4) {
                    // 基準音価
                    Text(viewModel.currentNoteName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(focusedField == .noteValue ? Color.accentColor : .secondary)
                        .padding(.horizontal, 4)
                        .background(focusedField == .noteValue ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        .onTapGesture { focusedField = .noteValue }
                        .focusable()
                        .focused($focusedField, equals: .noteValue)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(viewModel.noteValueOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    // BPM
                    Text("\(viewModel.bpm)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(focusedField == .bpm ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .bpm }
                        .focusable()
                        .focused($focusedField, equals: .bpm)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                
                // 2行目: 拍子 (分子 / 分母)
                HStack(spacing: 6) {
                    Text("\(viewModel.numerator)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(focusedField == .numerator ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .numerator }
                        .focusable()
                        .focused($focusedField, equals: .numerator)
                        .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("/")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.secondary)
                    
                    Text("\(viewModel.denominator)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(focusedField == .denominator ? Color.accentColor : .primary)
                        .onTapGesture { focusedField = .denominator }
                        .focusable()
                        .focused($focusedField, equals: .denominator)
                        // 感度を上げてスムーズに切り替え
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                }
            }
            
            Spacer(minLength: 2)
            
            // 再生ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(height: 34)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
    
    private var indicatorView: some View {
        HStack(spacing: 4) {
            let count = viewModel.numerator
            if count == 0 {
                circle(isCurrent: viewModel.isPlaying, isStrong: false)
            } else if count == 1 {
                circle(isCurrent: viewModel.isPlaying, isStrong: true)
            } else {
                ForEach(1...min(count, 8), id: \.self) { i in
                    circle(isCurrent: i == viewModel.currentBeat, isStrong: i == 1)
                }
                if count > 8 {
                    Text("...")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func circle(isCurrent: Bool, isStrong: Bool) -> some View {
        Circle()
            .fill(isCurrent ? (isStrong ? Color.orange : Color.accentColor) : Color.gray.opacity(0.3))
            .frame(width: isCurrent ? (isStrong ? 12 : 10) : 7, 
                   height: isCurrent ? (isStrong ? 12 : 10) : 7)
            .shadow(color: isCurrent && isStrong ? .orange : .clear, radius: 3)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isCurrent)
    }
}

#Preview {
    ContentView()
}
