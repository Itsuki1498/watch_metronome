//
//  MetronomeEngine.swift
//  watch_metronome
//
//  Created by Gemini on 2026/05/18.
//

import Foundation

/// 拍の強さ
enum BeatIntensity: Hashable {
    case strong   // 強拍 (小節頭)
    case medium   // 中拍 (拍の頭)
    case weak     // 弱拍 (裏拍等)
    case silence  // 無音
}

/// 演奏モード（順序：全て -> 強中 -> 強のみ）
enum RhythmMode: Int, CaseIterable {
    case all = 0         // 全ての拍
    case strongMedium = 1 // 強拍 + 中拍 (弱拍ミュート)
    case strongOnly = 2   // 強拍のみ (中・弱拍ミュート)
}

/// メトロノームのリズム生成を担う engine
@available(watchOS 10.6, iOS 16.7, *)
final class MetronomeEngine {

    // MARK: - Properties

    var bpm: Int = 120 {
        didSet { updateConstants() }
    }

    var numerator: Int = 4 {
        didSet {
            numerator = max(1, numerator)
            // 外部から分子が変えられたら、単一の拍グループとしてパターンをリセット
            beatPattern = [numerator]
            updateConstants()
        }
    }

    var denominator: Int = 4 {
        didSet { updateConstants() }
    }

    /// 現在小節の分子。互換性のため配列のまま保持するが、iPhone 側の複合拍子は小節モジュール列で表現する。
    var beatPattern: [Int] = [4] {
        didSet {
            beatPattern = beatPattern.isEmpty ? [1] : beatPattern.map { max(1, $0) }
            updateConstants()
        }
    }

    var referenceNoteMultiplier: Double = 1.0 {
        didSet { updateConstants() }
    }

    var accents: [Bool]? = nil {
        didSet { updateConstants() }
    }

    var rhythmMode: RhythmMode = .all

    private(set) var isPlaying: Bool = false
    private var tickCount: Int = 0
    private(set) var lastTickTime: DispatchTime = .now()

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)
    private let lock = NSRecursiveLock()

    var onTick: ((_ beat: Double, _ intensity: BeatIntensity, _ tickTime: DispatchTime) -> Void)?
    var onMeasureStart: ((_ sectionIndex: Int, _ barIndex: Int, _ section: ProgramSection) -> Void)?

    private(set) var program: MetronomeProgram = .defaultProgram
    private var activeSectionIndex: Int = 0
    private var activeBarIndex: Int = 0
    private var queuedChange: QueuedMetronomeChange?

    // MARK: - Logic Constants

    private(set) var internalInterval: Double = 0.5
    private(set) var totalTicksInMeasure: Int = 4
    private(set) var ticksPerOuterBeat: Int = 1
    private(set) var ticksPerRefNote: Int = 1

    private func updateConstants() {
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        let pulseUnit = 0.125

        // パターンの合計を現在の分子とする
        let currentNumerator = max(1, beatPattern.reduce(0, +))

        totalTicksInMeasure = max(1, Int(round((unitDenom * Double(currentNumerator)) / pulseUnit)))
        ticksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        ticksPerRefNote = max(1, Int(round(unitRef / pulseUnit)))

        internalInterval = (60.0 / Double(bpm)) / Double(ticksPerRefNote)

        if isPlaying { updateTimerSchedule(isRestart: true) }
    }

    func applyProgram(_ newProgram: MetronomeProgram, resetPosition: Bool = true) {
        lock.lock()
        defer { lock.unlock() }

        program = newProgram.sections.isEmpty ? .defaultProgram : newProgram
        if resetPosition {
            activeSectionIndex = 0
            activeBarIndex = 0
            tickCount = 0
        } else {
            activeSectionIndex = min(activeSectionIndex, max(0, program.sections.count - 1))
        }
        applySection(program.sections[activeSectionIndex])
    }

    func queueChangeForNextMeasure(_ change: QueuedMetronomeChange?) {
        lock.lock()
        queuedChange = change
        lock.unlock()
    }

    private func applySection(_ section: ProgramSection) {
        numerator = section.meter.numerator
        denominator = section.meter.denominator
        referenceNoteMultiplier = section.referenceNoteMultiplier
        rhythmMode = section.rhythmMode
        accents = section.accents
        bpm = bpmFor(section: section, barIndex: activeBarIndex)
        updateConstants()
    }

    private func bpmFor(section: ProgramSection, barIndex: Int) -> Int {
        guard section.tempoAutomation.shape != .none else { return section.bpm }
        let length = max(1, min(section.bars, section.tempoAutomation.lengthInBars))
        let progress = length == 1 ? 1.0 : min(1.0, Double(barIndex) / Double(length - 1))
        let start = Double(section.bpm)
        let end = Double(section.tempoAutomation.targetBpm)
        return min(400, max(40, Int(round(start + (end - start) * progress))))
    }

    // MARK: - Methods

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isPlaying else { return }

        isPlaying = true
        tickCount = 0
        applySection(program.sections[activeSectionIndex])
        updateConstants()

        let deadline = DispatchTime.now() + .milliseconds(100)
        lastTickTime = deadline

        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }

        timer?.schedule(deadline: deadline, repeating: internalInterval, leeway: .nanoseconds(0))
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        isPlaying = false
        timer?.cancel()
        timer = nil
    }

    private func updateTimerSchedule(isRestart: Bool) {
        guard isPlaying else { return }
        let nextTime = lastTickTime + internalInterval
        let deadline = nextTime < .now() ? .now() : nextTime
        timer?.schedule(deadline: deadline, repeating: internalInterval, leeway: .nanoseconds(0))
    }

    private func tick() {
        let tickTime = DispatchTime.now()
        lock.lock()
        guard isPlaying else {
            lock.unlock()
            return
        }

        tickCount += 1
        if tickCount > totalTicksInMeasure {
            tickCount = 1
            advanceMeasureLocked()
        }

        let currentTick = tickCount
        lastTickTime = tickTime

        let outerStep = ticksPerOuterBeat
        let refStep = ticksPerRefNote
        let mode = rhythmMode
        let currentAccents = accents

        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        let isRefMultiple = (unitRef / unitDenom) >= 0.999 && abs((unitRef / unitDenom) - round(unitRef / unitDenom)) < 0.001

        lock.unlock()

        let tickIndex = currentTick - 1
        let logicalBeat = Double(tickIndex) / Double(outerStep) + 1.0

        var rawIntensity: BeatIntensity
        if tickIndex == 0 {
            rawIntensity = .strong // 小節の頭
        } else if let customAccents = currentAccents {
            // 特殊アクセントが設定されている場合
            let beatIdx = Int(floor(logicalBeat)) - 1
            if tickIndex % outerStep == 0 {
                // 拍の頭
                if beatIdx < customAccents.count && customAccents[beatIdx] {
                    rawIntensity = .medium // 仕様：アクセントを中拍に設定
                } else {
                    rawIntensity = .weak // 仕様：もともと中拍だったものは全て弱拍に
                }
            } else if tickIndex % refStep == 0 {
                // 基準音符（拍の頭以外）
                rawIntensity = .weak
            } else {
                rawIntensity = .silence
            }
        } else if isRefMultiple {
            if tickIndex % refStep == 0 { rawIntensity = .medium }
            else if tickIndex % outerStep == 0 { rawIntensity = .weak }
            else { rawIntensity = .silence }
        } else {
            if tickIndex % outerStep == 0 { rawIntensity = .medium }
            else if tickIndex % refStep == 0 { rawIntensity = .weak }
            else { rawIntensity = .silence }
        }

        // モードによるフィルタリング
        var finalIntensity: BeatIntensity = rawIntensity
        switch mode {
        case .all:
            break
        case .strongMedium:
            if rawIntensity == .weak { finalIntensity = .silence }
        case .strongOnly:
            if rawIntensity != .strong { finalIntensity = .silence }
        }

        onTick?(logicalBeat, finalIntensity, tickTime)
    }

    private func advanceMeasureLocked() {
        if let queuedChange {
            self.queuedChange = nil
            program = queuedChange.program ?? MetronomeProgram(name: "Queued Change", sections: [queuedChange.section], loops: queuedChange.loops)
            activeSectionIndex = 0
            activeBarIndex = 0
            let section = program.sections[activeSectionIndex]
            applySection(section)
            onMeasureStart?(activeSectionIndex, activeBarIndex, section)
            return
        }

        guard !program.sections.isEmpty else { return }
        var nextBar = activeBarIndex + 1
        var nextSectionIndex = activeSectionIndex
        let section = program.sections[activeSectionIndex]

        if nextBar >= section.bars {
            nextBar = 0
            nextSectionIndex += 1
            if nextSectionIndex >= program.sections.count {
                nextSectionIndex = program.loops ? 0 : program.sections.count - 1
            }
        }

        activeSectionIndex = nextSectionIndex
        activeBarIndex = nextBar
        let nextSection = program.sections[activeSectionIndex]
        applySection(nextSection)
        onMeasureStart?(activeSectionIndex, activeBarIndex, nextSection)
    }
}
