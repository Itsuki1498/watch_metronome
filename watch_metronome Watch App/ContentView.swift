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
            // 拍のインジケーター（簡易版）
            HStack {
                ForEach(1...max(1, viewModel.numerator), id: \.self) { i in
                    Circle()
                        .fill(i == viewModel.currentBeat ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // BPM表示
            VStack {
                Text("\(Int(viewModel.displayBpm))")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .focusable()
            .focused($isCrownFocused)
            // by: 0.1 にすることで、ゆっくり回した時の微調整を可能にします
            .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 0.1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
            
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
