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
@available(watchOS 10.0, iOS 26.0, *)
final class MetronomeEngine {

    // MARK: - Properties

    private let lock = NSRecursiveLock()
    private var storedBpm = 120
    private var storedBeatPattern = [4]
    private var storedDenominator = 4
    private var storedReferenceNoteMultiplier = 1.0
    private var storedAccents: [Bool]?
    private var storedRhythmMode: RhythmMode = .all
    private var storedIsPlaying = false
    private var storedLastTickTime: DispatchTime = .now()
    private var storedProgram = MetronomeProgram.defaultProgram
    private var storedInternalInterval = 0.5
    private var storedTotalTicksInMeasure = 4
    private var storedTicksPerOuterBeat = 1
    private var storedTicksPerRefNote = 1

    var bpm: Int {
        get { lock.withLock { storedBpm } }
        set {
            lock.withLock {
                storedBpm = max(1, newValue)
                updateConstants()
            }
        }
    }

    var numerator: Int {
        get { lock.withLock { max(1, storedBeatPattern.reduce(0, +)) } }
        set {
            lock.withLock {
                storedBeatPattern = [max(1, newValue)]
                updateConstants()
            }
        }
    }

    var denominator: Int {
        get { lock.withLock { storedDenominator } }
        set {
            lock.withLock {
                storedDenominator = max(1, newValue)
                updateConstants()
            }
        }
    }

    /// 現在小節の分子。互換性のため配列のまま保持するが、iPhone 側の複合拍子は小節モジュール列で表現する。
    var beatPattern: [Int] {
        get { lock.withLock { storedBeatPattern } }
        set {
            lock.withLock {
                storedBeatPattern = newValue.isEmpty ? [1] : newValue.map { max(1, $0) }
                updateConstants()
            }
        }
    }

    var referenceNoteMultiplier: Double {
        get { lock.withLock { storedReferenceNoteMultiplier } }
        set {
            lock.withLock {
                storedReferenceNoteMultiplier = max(0.125, newValue)
                updateConstants()
            }
        }
    }

    var accents: [Bool]? {
        get { lock.withLock { storedAccents } }
        set {
            lock.withLock {
                storedAccents = newValue
                updateConstants()
            }
        }
    }

    var rhythmMode: RhythmMode {
        get { lock.withLock { storedRhythmMode } }
        set { lock.withLock { storedRhythmMode = newValue } }
    }

    var isPlaying: Bool { lock.withLock { storedIsPlaying } }
    private var tickCount: Int = 0
    var lastTickTime: DispatchTime { lock.withLock { storedLastTickTime } }

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.watchmetronome.engine", qos: .userInteractive)

    var onTick: ((_ beat: Double, _ intensity: BeatIntensity, _ tickTime: DispatchTime) -> Void)?
    var onMeasureStart: ((_ sectionIndex: Int, _ barIndex: Int, _ section: ProgramSection, _ program: MetronomeProgram) -> Void)?
    var onPlaybackEnd: (() -> Void)?

    var program: MetronomeProgram { lock.withLock { storedProgram } }
    private var activeSectionIndex: Int = 0
    private var activeBarIndex: Int = 0
    private var queuedChange: QueuedMetronomeChange?
    private var reachedProgramEnd = false

    // MARK: - Logic Constants

    var internalInterval: Double { lock.withLock { storedInternalInterval } }
    var totalTicksInMeasure: Int { lock.withLock { storedTotalTicksInMeasure } }
    var ticksPerOuterBeat: Int { lock.withLock { storedTicksPerOuterBeat } }
    var ticksPerRefNote: Int { lock.withLock { storedTicksPerRefNote } }

    private func updateConstants() {
        let unitDenom = 4.0 / Double(denominator)
        let unitRef = referenceNoteMultiplier
        let pulseUnit = 0.125

        // パターンの合計を現在の分子とする
        let currentNumerator = max(1, beatPattern.reduce(0, +))

        storedTotalTicksInMeasure = max(1, Int(round((unitDenom * Double(currentNumerator)) / pulseUnit)))
        storedTicksPerOuterBeat = max(1, Int(round(unitDenom / pulseUnit)))
        storedTicksPerRefNote = max(1, Int(round(unitRef / pulseUnit)))

        storedInternalInterval = (60.0 / Double(bpm)) / Double(storedTicksPerRefNote)

        if isPlaying { updateTimerSchedule(isRestart: true) }
    }

    func applyProgram(_ newProgram: MetronomeProgram, resetPosition: Bool = true) {
        lock.lock()
        defer { lock.unlock() }

        storedProgram = newProgram.sections.isEmpty ? .defaultProgram : newProgram
        if resetPosition {
            activeSectionIndex = 0
            activeBarIndex = 0
            tickCount = 0
            reachedProgramEnd = false
        } else {
            activeSectionIndex = min(activeSectionIndex, max(0, storedProgram.sections.count - 1))
            let activeSection = storedProgram.sections[activeSectionIndex]
            activeBarIndex = min(activeBarIndex, max(0, activeSection.bars - 1))
        }
        applySection(storedProgram.sections[activeSectionIndex])
    }

    func replaceProgramPreservingPosition(_ newProgram: MetronomeProgram) {
        lock.lock()
        defer { lock.unlock() }
        guard !newProgram.sections.isEmpty else { return }
        storedProgram = newProgram
        reachedProgramEnd = false
        activeSectionIndex = min(activeSectionIndex, storedProgram.sections.count - 1)
        let section = storedProgram.sections[activeSectionIndex]
        activeBarIndex = min(activeBarIndex, max(0, section.bars - 1))
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

        storedIsPlaying = true
        if reachedProgramEnd {
            activeSectionIndex = 0
            activeBarIndex = 0
            reachedProgramEnd = false
        }
        tickCount = 0
        applySection(storedProgram.sections[activeSectionIndex])
        updateConstants()

        let deadline = DispatchTime.now() + .milliseconds(100)
        storedLastTickTime = deadline

        if timer == nil {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer?.setEventHandler { [weak self] in
                self?.tick()
            }
            timer?.resume()
        }

        timer?.schedule(deadline: deadline, repeating: storedInternalInterval, leeway: .nanoseconds(0))
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        storedIsPlaying = false
        timer?.cancel()
        timer = nil
    }

    private func updateTimerSchedule(isRestart: Bool) {
        guard storedIsPlaying else { return }
        let nextTime = storedLastTickTime + storedInternalInterval
        let deadline = nextTime < .now() ? .now() : nextTime
        timer?.schedule(deadline: deadline, repeating: storedInternalInterval, leeway: .nanoseconds(0))
    }

    private func tick() {
        let tickTime = DispatchTime.now()
        lock.lock()
        guard storedIsPlaying else {
            lock.unlock()
            return
        }

        storedLastTickTime = tickTime
        tickCount += 1
        if tickCount > storedTotalTicksInMeasure {
            tickCount = 1
            guard advanceMeasureLocked() else {
                lock.unlock()
                onPlaybackEnd?()
                return
            }
        }

        let currentTick = tickCount

        let outerStep = storedTicksPerOuterBeat
        let refStep = storedTicksPerRefNote
        let mode = storedRhythmMode
        let currentAccents = storedAccents

        let unitDenom = 4.0 / Double(storedDenominator)
        let unitRef = storedReferenceNoteMultiplier
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

    @discardableResult
    private func advanceMeasureLocked() -> Bool {
        if let queuedChange {
            self.queuedChange = nil
            storedProgram = queuedChange.program ?? MetronomeProgram(
                name: "Queued Change",
                sections: [queuedChange.section],
                loops: queuedChange.loops,
                endBehavior: queuedChange.endBehavior
            )
            reachedProgramEnd = false
            activeSectionIndex = 0
            activeBarIndex = 0
            let section = storedProgram.sections[activeSectionIndex]
            applySection(section)
            onMeasureStart?(activeSectionIndex, activeBarIndex, section, storedProgram)
            return true
        }

        guard !storedProgram.sections.isEmpty else { return false }
        var nextBar = activeBarIndex + 1
        var nextSectionIndex = activeSectionIndex
        let section = storedProgram.sections[activeSectionIndex]

        if nextBar >= section.bars {
            if activeSectionIndex == storedProgram.sections.count - 1 && !storedProgram.loops {
                if storedProgram.endBehavior == .holdLastSection {
                    nextBar = max(0, section.bars - 1)
                } else {
                    storedIsPlaying = false
                    reachedProgramEnd = true
                    timer?.cancel()
                    timer = nil
                    return false
                }
            } else {
                nextBar = 0
                nextSectionIndex += 1
                if nextSectionIndex >= storedProgram.sections.count {
                    nextSectionIndex = 0
                }
            }
        }

        activeSectionIndex = nextSectionIndex
        activeBarIndex = nextBar
        let nextSection = storedProgram.sections[activeSectionIndex]
        applySection(nextSection)
        onMeasureStart?(activeSectionIndex, activeBarIndex, nextSection, storedProgram)
        return true
    }
}

private extension NSRecursiveLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
