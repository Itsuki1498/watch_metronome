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
        VStack(spacing: 4) {
            // 拍のインジケーター（強拍と弱拍で光り方を変える）
            indicatorView
                .frame(height: 20)
            
            VStack(spacing: 0) {
                // BPM設定
                VStack(spacing: -2) {
                    Text("\(viewModel.bpm)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(focusedField == .bpm ? Color.accentColor : .primary)
                    Text("BPM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { focusedField = .bpm }
                .focusable()
                .focused($focusedField, equals: .bpm)
                .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                
                // 拍子設定 (分子 / 分母)
                HStack(spacing: 8) {
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
                        .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                .padding(.top, 2)
            }
            
            Spacer(minLength: 1)
            
            // 再生/停止ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
            }
            .frame(height: 36)
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
    
    private var indicatorView: some View {
        HStack(spacing: 5) {
            let count = viewModel.numerator
            if count == 0 {
                // 0拍子: 1つのドットが弱く光る
                circle(isCurrent: viewModel.isPlaying, isStrong: false)
            } else if count == 1 {
                // 1拍子: 1つのドットが強く光る
                circle(isCurrent: viewModel.isPlaying, isStrong: true)
            } else {
                // 2拍子以上: 最大8個まで表示
                ForEach(1...min(count, 8), id: \.self) { i in
                    circle(isCurrent: i == viewModel.currentBeat, isStrong: i == 1)
                }
                if count > 8 {
                    Text("...")
                        .font(.caption2)
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
