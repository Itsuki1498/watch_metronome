//
//  ClickSoundManager.swift
//  watch_metronome
//

#if canImport(AVFoundation) && !os(watchOS)
import AVFoundation
#endif

final class ClickSoundManager {
    #if canImport(AVFoundation) && !os(watchOS)
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [BeatIntensity: AVAudioPCMBuffer] = [:]

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        buffers[.strong] = makeClick(frequency: 1_800, amplitude: 0.9, duration: 0.035)
        buffers[.medium] = makeClick(frequency: 1_250, amplitude: 0.65, duration: 0.028)
        buffers[.weak] = makeClick(frequency: 900, amplitude: 0.42, duration: 0.022)
    }
    #endif

    func play(_ intensity: BeatIntensity) {
        guard intensity != .silence else { return }
        #if canImport(AVFoundation) && !os(watchOS)
        do {
            if !engine.isRunning {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            }
            if !player.isPlaying {
                player.play()
            }
            if let buffer = buffers[intensity] {
                player.scheduleBuffer(buffer, at: nil, options: .interruptsAtLoop, completionHandler: nil)
            }
        } catch {
            return
        }
        #endif
    }

    #if canImport(AVFoundation) && !os(watchOS)
    private func makeClick(frequency: Float, amplitude: Float, duration: Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else { return buffer }
        for frame in 0..<Int(frameCount) {
            let t = Float(frame) / Float(format.sampleRate)
            let envelope = exp(-90.0 * t)
            let value = sin(2.0 * .pi * frequency * t) * amplitude * envelope
            channel[frame] = value
        }
        return buffer
    }
    #endif
}
