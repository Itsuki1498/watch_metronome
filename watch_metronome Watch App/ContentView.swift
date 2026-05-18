//
//  ContentView.swift
//  watch_metronome Watch App
//
//  Created by 執行一生 on 2026/05/18.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = MetronomeViewModel()
    @FocusState private var isCrownFocused: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            // 拍のインジケーター（強拍と弱拍で光り方を変える）
            HStack(spacing: 8) {
                ForEach(1...max(1, viewModel.numerator), id: \.self) { i in
                    let isCurrent = i == viewModel.currentBeat
                    let isFirstBeat = i == 1
                    
                    Circle()
                        .fill(isCurrent ? (viewModel.isCurrentBeatStrong ? Color.orange : Color.accentColor) : Color.gray.opacity(0.3))
                        .frame(width: isCurrent ? (viewModel.isCurrentBeatStrong ? 14 : 10) : 8, 
                               height: isCurrent ? (viewModel.isCurrentBeatStrong ? 14 : 10) : 8)
                        // 強拍時は少し光を強くする（擬似的な発光表現）
                        .shadow(color: isCurrent && viewModel.isCurrentBeatStrong ? .orange : .clear, radius: 4)
                        .scaleEffect(isCurrent ? 1.2 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.currentBeat)
                }
            }
            
            // BPM表示
            VStack {
                Text("\(viewModel.bpm)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .focusable()
            .focused($isCrownFocused)
            // by: 1 に戻し、BPMを整数で扱います
            .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
            
            // 再生/停止ボタン
            Button {
                viewModel.togglePlayback()
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.title2)
            }
            .tint(viewModel.isPlaying ? .red : .green)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            // 画面が表示された時に自動でフォーカスを当てる
            isCrownFocused = true
        }
    }
}

#Preview {
    ContentView()
}
