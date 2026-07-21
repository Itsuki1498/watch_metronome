//
//  MetronomeViewModel.swift
//  watch_metronome
//
//  Created by Gemini on 2026/05/18.
//

import SwiftUI
import Combine

/// 音価の定義
struct NoteValue: Hashable {
    let name: String
    let multiplier: Double
    let imageName: String
    let isDotted: Bool
    let displayHeight: CGFloat // SwiftUI の型を使用するため import SwiftUI が必要
}

/// メトロノームの画面状態と操作を管理するViewModel
@available(watchOS 10.0, iOS 26.0, *)
final class MetronomeViewModel: ObservableObject {

    // MARK: - Properties

    private let engine = MetronomeEngine()
    private let hapticManager = HapticManager()
    private let clickSoundManager = ClickSoundManager()
    private var cancellables = Set<AnyCancellable>()

    @Published var isSystemReady: Bool = false
    @Published var program: MetronomeProgram = .defaultProgram
    @Published var queuedChange: QueuedMetronomeChange?
    @Published var currentSectionIndex: Int = 0
    @Published var currentBarIndex: Int = 0
    @Published var presetProfiles: [PresetProfile] = []
    private let presetStorageKey = "metronomePresetProfiles.v1"

    enum EditTarget: Hashable {
        case bpm, numerator, denominator, noteValue, beatPattern
    }

    /// リズムモード (全て / 強・中 / 強のみ)
    var rhythmMode: RhythmMode {
        get { engine.rhythmMode }
        set {
            objectWillChange.send()
            engine.rhythmMode = newValue
        }
    }

    var bpm: Int {
        get { engine.bpm }
        set {
            let clamped = min(400, max(40, newValue))
            if engine.bpm != clamped {
                objectWillChange.send()
                engine.bpm = clamped
                updateActiveProgramSectionFromEngine()
                syncToRemote()
            }
        }
    }

    var displayBpm: Double {
        get { Double(engine.bpm) }
        set {
            let newIntValue = Int(newValue)
            if newIntValue != engine.bpm {
                objectWillChange.send()
                engine.bpm = newIntValue
                updateActiveProgramSectionFromEngine()
                syncToRemote()
            }
        }
    }

    var displayNumerator: Double {
        get { Double(engine.numerator) }
        set {
            let newIntValue = Int(newValue)
            if newIntValue != engine.numerator {
                objectWillChange.send()
                engine.numerator = newIntValue
                refreshValidNoteValues()
                updateActiveProgramSectionFromEngine()
                syncToRemote()
            }
        }
    }

    var displayDenominatorIndex: Double {
        get { Double(denominatorOptions.firstIndex(of: engine.denominator) ?? 1) }
        set {
            let index = Int(newValue)
            if index >= 0 && index < denominatorOptions.count {
                let newDenom = denominatorOptions[index]
                if newDenom != engine.denominator {
                    objectWillChange.send()
                    engine.denominator = newDenom
                    refreshValidNoteValues()
                    syncNoteValueToDenominator()
                    updateActiveProgramSectionFromEngine()
                    syncToRemote()
                }
            }
        }
    }

    var displayNoteValueIndex: Double {
        get {
            let current = noteValueOptions[noteValueIndex]
            return Double(validNoteValueOptions.firstIndex(where: { $0.multiplier == current.multiplier }) ?? 0)
        }
        set {
            let index = Int(newValue)
            if index >= 0 && index < validNoteValueOptions.count {
                let selectedNote = validNoteValueOptions[index]
                if let masterIndex = noteValueOptions.firstIndex(where: { $0.multiplier == selectedNote.multiplier }) {
                    selectNoteValue(at: masterIndex)
                }
            }
        }
    }

    @Published var noteValueIndex: Int = 4 {
        didSet {
            engine.referenceNoteMultiplier = noteValueOptions[noteValueIndex].multiplier
        }
    }

    var isPlaying: Bool { engine.isPlaying }

    /// 複合拍子のパターン
    var beatPattern: [Int] {
        get { engine.beatPattern }
        set {
            objectWillChange.send()
            engine.beatPattern = newValue
            updateActiveProgramSectionFromEngine()
        }
    }

    var accents: [Bool]? {
        get { engine.accents }
        set {
            objectWillChange.send()
            engine.accents = newValue
            updateActiveProgramSectionFromEngine()
        }
    }

    var numerator: Int { beatPattern.reduce(0, +) }
    var denominator: Int { engine.denominator }

    /// --- 同期された状態プロパティ ---
    @Published var currentBeat: Double = 1.0
    @Published var currentIntensity: BeatIntensity = .weak
    @Published var lastTickTime: DispatchTime = .now()

    var totalTicksInMeasure: Int { engine.totalTicksInMeasure }
    var ticksPerOuterBeat: Int { engine.ticksPerOuterBeat }
    var ticksPerRefNote: Int { engine.ticksPerRefNote }
    var tickInterval: Double { engine.internalInterval }

    let denominatorOptions = [2, 4, 8, 16, 32]

    let noteValueOptions: [NoteValue] = [
        NoteValue(name: "全", multiplier: 4.0, imageName: "note_whole", isDotted: false, displayHeight: 10),
        NoteValue(name: "付2", multiplier: 3.0, imageName: "note_half_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "2", multiplier: 2.0, imageName: "note_half", isDotted: false, displayHeight: 24),
        NoteValue(name: "付4", multiplier: 1.5, imageName: "note_quarter_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "4", multiplier: 1.0, imageName: "note_quarter", isDotted: false, displayHeight: 24),
        NoteValue(name: "付8", multiplier: 0.75, imageName: "note_eighth_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "8", multiplier: 0.5, imageName: "note_eighth", isDotted: false, displayHeight: 24),
        NoteValue(name: "付16", multiplier: 0.375, imageName: "note_sixteenth_dotted", isDotted: true, displayHeight: 24),
        NoteValue(name: "16", multiplier: 0.25, imageName: "note_sixteenth", isDotted: false, displayHeight: 24),
        NoteValue(name: "32", multiplier: 0.125, imageName: "note_32nd", isDotted: false, displayHeight: 24)
    ]

    @Published var validNoteValueOptions: [NoteValue] = []

    var currentNote: NoteValue {
        noteValueOptions[noteValueIndex]
    }

    // MARK: - Tap Tempo Logic

    private var tapTimes: [Date] = []

    func tapTempo() {
        let now = Date()
        tapTimes.append(now)

        // 過去2秒以上前のタップは削除
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 2.0 }

        if tapTimes.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i-1]))
            }
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let calculatedBpm = Int(round(60.0 / averageInterval))
            self.bpm = calculatedBpm
        }

        hapticManager.playWeak() // タップ時の手応え
    }

    // MARK: - Initialization

    init() {
        refreshValidNoteValues()
        loadPresetProfiles()
        engine.applyProgram(program)
        setupEngine()
        setupConnectivity()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isSystemReady = true
        }
    }

    private func setupEngine() {
        engine.onMeasureStart = { [weak self] sectionIndex, barIndex, section in
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentSectionIndex = sectionIndex
                self.currentBarIndex = barIndex
                self.refreshValidNoteValues()
                self.syncNoteValue(to: section.referenceNoteMultiplier)
                if self.queuedChange != nil && sectionIndex == 0 && barIndex == 0 {
                    self.queuedChange = nil
                }
            }
        }
        engine.onTick = { [weak self] (beat: Double, intensity: BeatIntensity, tickTime: DispatchTime) in
            guard let self else { return }
            switch intensity {
            case .strong:
                #if os(watchOS)
                self.hapticManager.playStrong()
                #else
                self.clickSoundManager.play(.strong)
                #endif
            case .medium:
                #if os(watchOS)
                self.hapticManager.playMedium()
                #else
                self.clickSoundManager.play(.medium)
                #endif
            case .weak:
                #if os(watchOS)
                self.hapticManager.playWeak()
                #else
                self.clickSoundManager.play(.weak)
                #endif
            case .silence:
                break
            }

            DispatchQueue.main.async {
                self.currentBeat = beat
                self.currentIntensity = intensity
                self.lastTickTime = tickTime
            }
        }
    }

    private func refreshValidNoteValues() {
        let unitDenom = 4.0 / Double(engine.denominator)
        validNoteValueOptions = noteValueOptions.filter { note in
            let m = note.multiplier
            let ratio1 = m / unitDenom
            let ratio2 = unitDenom / m
            return abs(ratio1 - round(ratio1)) < 0.001 || abs(ratio2 - round(ratio2)) < 0.001
        }
        if !validNoteValueOptions.contains(noteValueOptions[noteValueIndex]) {
            syncNoteValueToDenominator()
        }
    }

    private func syncNoteValueToDenominator() {
        let unitDenom = 4.0 / Double(engine.denominator)
        syncNoteValue(to: unitDenom)
    }

    private func syncNoteValue(to multiplier: Double) {
        if let index = noteValueOptions.firstIndex(where: { abs($0.multiplier - multiplier) < 0.001 }) {
            noteValueIndex = index
        }
    }

    // MARK: - Connectivity
    private func setupConnectivity() {
        // ConnectivityManagerからの変更を受け取る
        ConnectivityManager.shared.$remoteBpm
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bpm in
                guard let self else { return }
                if self.engine.bpm != bpm {
                    self.objectWillChange.send()
                    self.engine.bpm = bpm
                    self.updateActiveProgramSectionFromEngine(sync: false)
                }
            }
            .store(in: &cancellables)

        ConnectivityManager.shared.$remoteNumerator
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] num in
                guard let self else { return }
                if self.engine.numerator != num {
                    self.objectWillChange.send()
                    self.engine.numerator = num
                    self.refreshValidNoteValues()
                    self.updateActiveProgramSectionFromEngine(sync: false)
                }
            }
            .store(in: &cancellables)

        ConnectivityManager.shared.$remoteDenominator
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] den in
                guard let self else { return }
                if self.engine.denominator != den {
                    self.objectWillChange.send()
                    self.engine.denominator = den
                    self.refreshValidNoteValues()
                    self.syncNoteValueToDenominator()
                    self.updateActiveProgramSectionFromEngine(sync: false)
                }
            }
            .store(in: &cancellables)

        ConnectivityManager.shared.$remoteProgram
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] program in
                self?.applyProgram(program, sync: false, resetPosition: true)
            }
            .store(in: &cancellables)

        ConnectivityManager.shared.$remoteQueuedChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                self?.queuedChange = change
                self?.engine.queueChangeForNextMeasure(change)
            }
            .store(in: &cancellables)

        ConnectivityManager.shared.$remoteTransportCommand
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                guard let self else { return }
                if command == "play", !self.engine.isPlaying {
                    self.togglePlayback(sync: false)
                } else if command == "stop", self.engine.isPlaying {
                    self.togglePlayback(sync: false)
                }
            }
            .store(in: &cancellables)
    }

    private func syncToRemote() {
        ConnectivityManager.shared.sendStatus(
            bpm: engine.bpm,
            numerator: numerator,
            denominator: engine.denominator
        )
    }

    // MARK: - Actions

    func nextRhythmMode() {
        let allModes = RhythmMode.allCases
        let currentIndex = rhythmMode.rawValue
        let nextIndex = (currentIndex + 1) % allModes.count
        rhythmMode = allModes[nextIndex]
        updateActiveProgramSectionFromEngine()
    }

    func selectNoteValue(at index: Int) {
        guard noteValueOptions.indices.contains(index) else { return }
        noteValueIndex = index
        updateActiveProgramSectionFromEngine()
    }

    func togglePlayback(sync: Bool = true) {
        objectWillChange.send()
        if engine.isPlaying {
            engine.stop()
            if sync { ConnectivityManager.shared.sendTransportCommand("stop") }
        } else {
            engine.start()
            self.currentBeat = 1.0
            self.currentIntensity = .strong
            self.lastTickTime = engine.lastTickTime
            if sync {
                ConnectivityManager.shared.sendProgram(program)
                ConnectivityManager.shared.sendQueuedChange(queuedChange)
                ConnectivityManager.shared.sendTransportCommand("play")
            }
        }
    }

    func applyProgram(_ newProgram: MetronomeProgram, sync: Bool = true, resetPosition: Bool = true) {
        objectWillChange.send()
        program = newProgram
        if resetPosition {
            currentSectionIndex = 0
            currentBarIndex = 0
        } else {
            currentSectionIndex = min(currentSectionIndex, max(0, program.sections.count - 1))
            let activeSection = program.sections[currentSectionIndex]
            currentBarIndex = min(currentBarIndex, max(0, activeSection.bars - 1))
        }
        engine.applyProgram(newProgram, resetPosition: resetPosition)
        let syncIndex = resetPosition ? 0 : currentSectionIndex
        if let section = newProgram.sections[safe: syncIndex] ?? newProgram.sections.first {
            syncEditableState(from: section)
        }
        if sync {
            ConnectivityManager.shared.sendProgram(newProgram)
        }
    }

    func updateSection(_ section: ProgramSection) {
        guard let index = program.sections.firstIndex(where: { $0.id == section.id }) else { return }
        var nextProgram = program
        nextProgram.sections[index] = section
        applyProgram(nextProgram, resetPosition: false)
    }

    func addSection(after sectionID: UUID? = nil) {
        var nextProgram = program
        let template = nextProgram.sections.last ?? ProgramSection(name: "Section")
        let next = ProgramSection(
            name: "Section \(nextProgram.sections.count + 1)",
            meter: template.meter,
            bpm: template.bpm,
            bars: template.bars,
            referenceNoteMultiplier: template.referenceNoteMultiplier,
            rhythmMode: template.rhythmMode,
            tempoAutomation: template.tempoAutomation,
            accents: template.accents
        )
        if let sectionID, let index = nextProgram.sections.firstIndex(where: { $0.id == sectionID }) {
            nextProgram.sections.insert(next, at: index + 1)
        } else {
            nextProgram.sections.append(next)
        }
        applyProgram(nextProgram, resetPosition: false)
    }

    func removeSection(_ section: ProgramSection) {
        guard program.sections.count > 1 else { return }
        var nextProgram = program
        nextProgram.sections.removeAll { $0.id == section.id }
        applyProgram(nextProgram, resetPosition: false)
    }

    func queueChange(section: ProgramSection, loops: Bool = true) {
        let change = QueuedMetronomeChange(section: section, loops: loops)
        queuedChange = change
        engine.queueChangeForNextMeasure(change)
        ConnectivityManager.shared.sendQueuedChange(change)
    }

    func queueProgram(_ program: MetronomeProgram) {
        let change = QueuedMetronomeChange(program: program)
        queuedChange = change
        engine.queueChangeForNextMeasure(change)
        ConnectivityManager.shared.sendQueuedChange(change)
    }

    func queueTempoAutomation(targetBpm: Int, bars: Int) {
        let current = program.sections[safe: currentSectionIndex] ?? program.sections.first ?? ProgramSection()
        let shape: TempoAutomationShape = targetBpm >= bpm ? .accelerando : .ritardando
        let section = ProgramSection(
            name: shape == .accelerando ? "accel." : "rit.",
            meter: current.meter,
            bpm: bpm,
            bars: max(1, bars),
            referenceNoteMultiplier: current.referenceNoteMultiplier,
            rhythmMode: current.rhythmMode,
            tempoAutomation: TempoAutomation(shape: shape, targetBpm: targetBpm, lengthInBars: max(1, bars)),
            accents: current.accents
        )
        queueChange(section: section, loops: false)
    }

    func clearQueuedChange() {
        queuedChange = nil
        engine.queueChangeForNextMeasure(nil)
        ConnectivityManager.shared.sendQueuedChange(nil)
    }

    private func syncEditableState(from section: ProgramSection) {
        refreshValidNoteValues()
        syncNoteValue(to: section.referenceNoteMultiplier)
    }

    private func updateActiveProgramSectionFromEngine(sync: Bool = true) {
        guard !program.sections.isEmpty else { return }
        var nextProgram = program
        let targetIndex = min(currentSectionIndex, max(0, nextProgram.sections.count - 1))
        let currentSection = nextProgram.sections[targetIndex]
        let section = ProgramSection(
            id: currentSection.id,
            name: currentSection.name,
            meter: MeterPattern(id: currentSection.meter.id, numerator: engine.beatPattern.reduce(0, +), denominator: engine.denominator),
            bpm: engine.bpm,
            bars: currentSection.bars,
            referenceNoteMultiplier: engine.referenceNoteMultiplier,
            rhythmMode: engine.rhythmMode,
            tempoAutomation: currentSection.tempoAutomation,
            accents: engine.accents
        )
        nextProgram.sections[targetIndex] = section
        program = nextProgram
        if sync {
            ConnectivityManager.shared.sendProgram(nextProgram)
        }
    }

    func saveCurrentProgramAsPreset(name: String, kind: PresetProfileKind) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileName = trimmedName.isEmpty ? program.name : trimmedName
        let profileProgram: MetronomeProgram
        switch kind {
        case .basic:
            let section = program.sections.first ?? ProgramSection()
            profileProgram = MetronomeProgram(name: profileName, sections: [section], loops: true)
        case .composite:
            profileProgram = MetronomeProgram(name: profileName, sections: program.sections, loops: program.loops)
        }
        let profile = PresetProfile(
            name: profileName,
            kind: kind,
            program: profileProgram
        )
        presetProfiles.append(profile)
        persistPresetProfiles()
    }

    func deletePresetProfile(_ profile: PresetProfile) {
        presetProfiles.removeAll { $0.id == profile.id }
        persistPresetProfiles()
    }

    func applyPresetProfile(_ profile: PresetProfile) {
        if profile.kind == .basic, let section = profile.program.sections.first {
            applyProgram(MetronomeProgram(name: profile.name, sections: [section], loops: profile.program.loops))
        } else {
            applyProgram(profile.program)
        }
    }

    func queuePresetProfile(_ profile: PresetProfile) {
        if profile.kind == .composite {
            queueProgram(profile.program)
        } else if let section = profile.program.sections.first {
            queueChange(section: section, loops: profile.program.loops)
        }
    }

    private func loadPresetProfiles() {
        if let data = UserDefaults.standard.data(forKey: presetStorageKey),
           let decoded = try? JSONDecoder().decode([PresetProfile].self, from: data) {
            presetProfiles = decoded
        } else {
            presetProfiles = [
                PresetProfile(name: "Basic 4/4", kind: .basic, program: .defaultProgram),
                PresetProfile(name: "4/4 + 7/8", kind: .composite, program: .iPhoneStarterProgram)
            ]
        }
    }

    private func persistPresetProfiles() {
        guard let data = try? JSONEncoder().encode(presetProfiles) else { return }
        UserDefaults.standard.set(data, forKey: presetStorageKey)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
