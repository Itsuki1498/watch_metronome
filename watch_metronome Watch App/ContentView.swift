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
            // 背景レイヤー: 精密な二重円環
            TimelineView(.animation(minimumInterval: 0.016)) { context in
                ModernPieIndicatorView(
                    viewModel: viewModel,
                    date: context.date
                )
            }
            .padding(2)
            .ignoresSafeArea()
            
            if !viewModel.isSystemReady {
                ProgressView()
                    .tint(.orange)
            } else {
                // 前面レイヤー: 中央カプセル型UI
                mainControlUI
            }
        }
        .onAppear {
            focusedField = .bpm
        }
    }
    
    private var mainControlUI: some View {
        VStack(spacing: 0) {
            // 上部：BPM & 音価
            VStack(spacing: -2) {
                HStack(alignment: .center, spacing: 6) {
                    settingItem(target: .noteValue, label: viewModel.currentNoteName, size: 18, hPadding: 6)
                        .digitalCrownRotation($viewModel.displayNoteValueIndex, from: 0, through: Double(max(0, viewModel.validNoteValueOptions.count - 1)), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                    
                    Text("=")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    settingItem(target: .bpm, label: "\(viewModel.bpm)", size: 50, hPadding: 4)
                        .digitalCrownRotation($viewModel.displayBpm, from: 40, through: 400, by: 1, sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
                }
                Text("BPM")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .padding(.top, 25)
            
            Spacer()
            
            // 中央：拍子設定
            HStack(spacing: 4) {
                settingItem(target: .numerator, label: "\(viewModel.numerator)", size: 28, hPadding: 8)
                    .digitalCrownRotation($viewModel.displayNumerator, from: 0, through: 32, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                
                Text("/")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.5))
                
                settingItem(target: .denominator, label: "\(viewModel.denominator)", size: 28, hPadding: 8)
                    .digitalCrownRotation($viewModel.displayDenominatorIndex, from: 0, through: Double(viewModel.denominatorOptions.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            }
            
            Spacer()
            
            // 下部：中央カプセル型ボタン
            HStack(spacing: 2) {
                // 左側：モード切り替え（U字 ⊂）
                Button {
                    viewModel.nextRhythmMode()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    ZStack {
                        CapsuleHalf(side: .left)
                            .fill(Color.blue.opacity(0.15))
                        Image(systemName: modeIcon(viewModel.rhythmMode))
                            .font(.system(size: 16))
                            .foregroundStyle(viewModel.rhythmMode == .strongOnly ? .orange : .blue)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 60, height: 40)
                
                // 右側：再生/停止（U字 ⊃）
                Button {
                    viewModel.togglePlayback()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    ZStack {
                        CapsuleHalf(side: .right)
                            .fill(viewModel.isPlaying ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(viewModel.isPlaying ? .red : .green)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 60, height: 40)
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
    }
    
    private func modeIcon(_ mode: RhythmMode) -> String {
        switch mode {
        case .strongOnly:   return "speaker.fill"
        case .strongMedium: return "speaker.wave.1.fill"
        case .all:          return "speaker.wave.3.fill"
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
            .animation(.easeInOut(duration: 0.1), value: focusedField)
    }
}

/// カプセルを半分に割った形状
struct CapsuleHalf: Shape {
    enum Side { case left, right }
    let side: Side
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.height / 2
        if side == .left {
            path.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        } else {
            path.addArc(center: CGPoint(x: rect.width - r, y: r), radius: r, startAngle: .degrees(270), endAngle: .degrees(450), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: 0))
        }
        path.closeSubpath()
        return path
    }
}

struct ModernPieIndicatorView: View {
...
    private func currentMeasureProgress() -> Double {
        let now = DispatchTime.now()
        let last = viewModel.lastTickTime
        guard now >= last else { return 0.0 }
        let elapsed = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000_000.0
        
        let beatIdx = viewModel.currentBeat - 1.0
        let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
        // 1パルスあたりの進捗 (1.0 / totalTicks) に基づいて計算
        let currentPulseProgress = (beatIdx * (1.0 / (totalTicks / Double(viewModel.numerator)))) + (elapsed / viewModel.tickInterval)
        // 簡略化：(現在の論理的な拍位置 + 経過率) / 総パルス数 
        // ただし logicalBeat は既に ticksPerOuterBeat を考慮済み
        
        let beatProgress = (beatIdx * Double(viewModel.ticksPerOuterBeat)) + (elapsed / viewModel.tickInterval)
        return beatProgress / totalTicks
    }
}

#Preview {
    ContentView()
}
