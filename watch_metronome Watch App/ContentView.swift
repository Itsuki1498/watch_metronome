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
            HStack(spacing: 6) {
                ForEach(1...max(1, viewModel.numerator), id: \.self) { i in
                    let isCurrent = i == viewModel.currentBeat
                    let isStrong = i == 1 // 1拍目を強拍として表示
                    
                    Circle()
                        .fill(isCurrent ? (viewModel.isCurrentBeatStrong ? Color.orange : Color.accentColor) : Color.gray.opacity(0.3))
                        .frame(width: isCurrent ? (viewModel.isCurrentBeatStrong ? 12 : 10) : 8, 
                               height: isCurrent ? (viewModel.isCurrentBeatStrong ? 12 : 10) : 8)
                        .animation(.spring(duration: 0.1), value: viewModel.currentBeat)
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
