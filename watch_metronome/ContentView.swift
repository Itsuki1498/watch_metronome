//
//  ContentView.swift
//  watch_metronome
//

import SwiftUI

@available(iOS 16.7, *)
struct ContentView: View {
    @StateObject private var viewModel = MetronomeViewModel()
    @State private var selectedTab = 1 // Main (PlayDashboard) is center
    @State private var queuedDraft = ProgramSection(
        name: "Next",
        meter: MeterPattern(groups: [4], denominator: 4),
        bpm: 120,
        bars: 1
    )
    @State private var queuedLoops = true

    var body: some View {
        TabView(selection: $selectedTab) {
            CompositeEditor(viewModel: viewModel)
                .tag(0)

            PlayDashboard(viewModel: viewModel, queuedDraft: $queuedDraft, queuedLoops: $queuedLoops)
                .tag(1)

            PresetLibrary(viewModel: viewModel)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .preferredColorScheme(.dark)
        .onAppear {
            if viewModel.program.name == MetronomeProgram.defaultProgram.name {
                viewModel.applyProgram(.iPhoneStarterProgram)
            }
        }
    }
}

@available(iOS 16.7, *)
private struct CompositeEditor: View {
    @ObservedObject var viewModel: MetronomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeader(title: "Mixed Meter & Groups")
                        MeterFullEditor(section: currentSectionBinding)

                        SectionHeader(title: "Special Accents")
                        AccentEditor(viewModel: viewModel)

                        SectionHeader(title: "Section Properties")
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Bars")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Stepper(value: barsBinding, in: 1...999) {
                                    Text("\(currentSection.bars)")
                                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                                }
                            }
                            Spacer()
                            Toggle("Loop", isOn: loopBinding)
                                .fixedSize()
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Complex Setup")
        }
    }

    private var currentSection: ProgramSection {
        viewModel.program.sections.first ?? ProgramSection()
    }

    private var currentSectionBinding: Binding<ProgramSection> {
        Binding(
            get: { currentSection },
            set: { viewModel.updateSection($0) }
        )
    }

    private var barsBinding: Binding<Int> {
        Binding(
            get: { currentSection.bars },
            set: {
                var s = currentSection
                s.bars = $0
                viewModel.updateSection(s)
            }
        )
    }

    private var loopBinding: Binding<Bool> {
        Binding(
            get: { viewModel.program.loops },
            set: {
                var p = viewModel.program
                p.loops = $0
                viewModel.applyProgram(p)
            }
        )
    }
}

@available(iOS 16.7, *)
private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.cyan)
            .padding(.top, 10)
    }
}

@available(iOS 16.7, *)
private struct AccentEditor: View {
    @ObservedObject var viewModel: MetronomeViewModel

    var body: some View {
        let count = max(1, viewModel.numerator)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: min(count, 8))

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<count, id: \.self) { index in
                Button {
                    toggleAccent(at: index)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isAccented(index) ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isAccented(index) ? Color.cyan : Color.clear, lineWidth: 2)
                                )
                                .frame(height: 40)

                            if isAccented(index) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(index == 0) // 1拍目は固定
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

        Button(viewModel.accents == nil ? "Enable Special Accents" : "Reset to Default Groups") {
            if viewModel.accents == nil {
                viewModel.accents = Array(repeating: false, count: count)
            } else {
                viewModel.accents = nil
            }
        }
        .font(.caption)
        .padding(.top, 4)
    }

    private func isAccented(_ index: Int) -> Bool {
        if index == 0 { return true }
        guard let accents = viewModel.accents, accents.indices.contains(index) else { return false }
        return accents[index]
    }

    private func toggleAccent(at index: Int) {
        var current = normalizedAccents()
        current[index].toggle()
        viewModel.accents = current
    }

    private func normalizedAccents() -> [Bool] {
        var current = viewModel.accents ?? []
        let count = max(1, viewModel.numerator)
        if current.count < count {
            current.append(contentsOf: Array(repeating: false, count: count - current.count))
        } else if current.count > count {
            current = Array(current.prefix(count))
        }
        return current
    }
}

@available(iOS 16.7, *)
private struct PresetLibrary: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @State private var presetName = ""
    @State private var presetKind: PresetProfileKind = .basic

    var body: some View {
        NavigationStack {
            List {
                Section("Save Current Profile") {
                    TextField("Preset name", text: $presetName)
                    Picker("Type", selection: $presetKind) {
                        Text("Basic").tag(PresetProfileKind.basic)
                        Text("Composite").tag(PresetProfileKind.composite)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        viewModel.saveCurrentProgramAsPreset(name: presetName, kind: presetKind)
                        presetName = ""
                    } label: {
                        Label("Save Profile", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Profiles") {
                    ForEach(viewModel.presetProfiles) { profile in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text(profile.program.sections.map { $0.displayName }.joined(separator: " -> "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(profile.kind == .basic ? "Basic" : "Composite")
                                    .font(.caption.bold())
                                    .foregroundStyle(.cyan)
                            }

                            HStack {
                                Button("Apply") {
                                    viewModel.applyPresetProfile(profile)
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Next Bar") {
                                    viewModel.queuePresetProfile(profile)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.deletePresetProfile(profile)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Presets")
        }
    }
}

@available(iOS 16.7, *)
private struct PlayDashboard: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @Binding var queuedDraft: ProgramSection
    @Binding var queuedLoops: Bool
    @State private var isBpmEditing = false
    @State private var isQueueEditorPresented = false
    @State private var tempoTargetBpm = 96
    @State private var tempoBars = 4

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 0.016)) { context in
                    ModernPieIndicatorView(viewModel: viewModel, date: context.date)
                        .padding(.horizontal, 18)
                        .padding(.top, 70)
                        .padding(.bottom, 230)
                }

                VStack(spacing: 18) {
                    currentReadout
                    Spacer()
                    transport
                    queuedChangePanel
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
            .navigationTitle("Metronome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var currentSection: ProgramSection {
        let index = min(viewModel.currentSectionIndex, max(0, viewModel.program.sections.count - 1))
        return viewModel.program.sections[index]
    }

    private var currentReadout: some View {
        VStack(spacing: 14) {
            Button {
                isBpmEditing.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(viewModel.bpm)")
                        .font(.system(size: 86, weight: .black).monospacedDigit())
                        .foregroundStyle(.white)
                    Text("BPM")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $isBpmEditing) {
                BpmDirectInput(bpm: bpmBinding)
                    .presentationDetents([.height(200)])
            }

            HStack(spacing: 16) {
                Menu {
                    ForEach(viewModel.noteValueOptions.indices, id: \.self) { index in
                        Button {
                            viewModel.noteValueIndex = index
                        } label: {
                            Label(viewModel.noteValueOptions[index].name, image: viewModel.noteValueOptions[index].imageName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(viewModel.currentNote.imageName)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 24)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: Capsule())
                }

                HStack(spacing: 8) {
                    Text(currentSection.meter.displayName)
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                    Text("bar \(viewModel.currentBarIndex + 1)/\(currentSection.bars)")
                        .font(.system(size: 14, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            BasicMeterRoller(viewModel: viewModel)
                .frame(height: 112)

            // Drumroll BPM Selector
            Picker("BPM", selection: bpmBinding) {
                ForEach(40...400, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            .clipped()
        }
        .padding(.top, 14)
    }

    private var transport: some View {
        HStack(spacing: 18) {
            Button {
                viewModel.nextRhythmMode()
            } label: {
                ControlButton(icon: modeIcon(viewModel.rhythmMode), title: modeName(viewModel.rhythmMode), tint: .blue)
            }

            Button {
                viewModel.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isPlaying ? Color.red.opacity(0.24) : Color.green.opacity(0.24))
                    Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(viewModel.isPlaying ? .red : .green)
                        .offset(x: viewModel.isPlaying ? 0 : 3)
                }
                .frame(width: 108, height: 108)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.tapTempo()
            } label: {
                ControlButton(icon: "hand.tap.fill", title: "Tap", tint: .cyan)
            }
        }
    }

    private var queuedChangePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Next Bar Queue", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                Spacer()
                if let queued = viewModel.queuedChange {
                    Text("Armed")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Target BPM", selection: queuedBpmBinding) {
                        ForEach(40...400, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 86)
                    .clipped()
                    MeterDraftEditor(section: $queuedDraft)
                }

                HStack {
                    Button {
                        isQueueEditorPresented = true
                    } label: {
                        Label("Edit Detail", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Toggle("Loop", isOn: $queuedLoops)
                        .toggleStyle(.switch)
                        .fixedSize()
                }

                DisclosureGroup("Tempo Change") {
                    HStack {
                        NumberField(title: "Target", value: $tempoTargetBpm, range: 40...400)
                        NumberField(title: "Bars", value: $tempoBars, range: 1...64)
                    }
                    Button {
                        viewModel.queueTempoAutomation(targetBpm: tempoTargetBpm, bars: tempoBars)
                    } label: {
                        Label("Start Next Bar", systemImage: "speedometer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    viewModel.queueChange(section: queuedDraft, loops: queuedLoops)
                } label: {
                    Label("Arm Change", systemImage: "forward.end.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

                Button {
                    viewModel.clearQueuedChange()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 42, height: 36)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sheet(isPresented: $isQueueEditorPresented) {
            QueueDetailEditor(viewModel: viewModel, section: $queuedDraft, loops: $queuedLoops)
        }
    }

    private var bpmBinding: Binding<Int> {
        Binding(
            get: { viewModel.bpm },
            set: { viewModel.bpm = $0 }
        )
    }

    private var queuedBpmBinding: Binding<Int> {
        Binding(
            get: { queuedDraft.bpm },
            set: { queuedDraft.bpm = min(400, max(40, $0)) }
        )
    }

    private func modeIcon(_ mode: RhythmMode) -> String {
        switch mode {
        case .all: return "speaker.wave.3.fill"
        case .strongMedium: return "speaker.wave.1.fill"
        case .strongOnly: return "speaker.fill"
        }
    }

    private func modeName(_ mode: RhythmMode) -> String {
        switch mode {
        case .all: return "Full"
        case .strongMedium: return "Beat"
        case .strongOnly: return "Bar"
        }
    }
}

@available(iOS 16.7, *)
private struct BasicMeterRoller: View {
    @ObservedObject var viewModel: MetronomeViewModel

    var body: some View {
        HStack(spacing: 0) {
            Picker("Numerator", selection: numeratorBinding) {
                ForEach(0...32, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Text("/")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.secondary)

            Picker("Denominator", selection: denominatorIndexBinding) {
                ForEach(viewModel.denominatorOptions.indices, id: \.self) { index in
                    Text("\(viewModel.denominatorOptions[index])").tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var numeratorBinding: Binding<Int> {
        Binding(
            get: { viewModel.numerator },
            set: { viewModel.displayNumerator = Double($0) }
        )
    }

    private var denominatorIndexBinding: Binding<Int> {
        Binding(
            get: { Int(viewModel.displayDenominatorIndex) },
            set: { viewModel.displayDenominatorIndex = Double($0) }
        )
    }
}

@available(iOS 16.7, *)
private struct QueueDetailEditor: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @Binding var section: ProgramSection
    @Binding var loops: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isBpmEditing = false

    var body: some View {
        NavigationStack {
            List {
                Section("BPM") {
                    Button {
                        isBpmEditing = true
                    } label: {
                        HStack {
                            Text("\(section.bpm)")
                                .font(.system(size: 44, weight: .black).monospacedDigit())
                            Text("BPM")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Picker("BPM", selection: $section.bpm) {
                        ForEach(40...400, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 112)
                    .clipped()
                }

                Section("Note") {
                    Picker("Reference Note", selection: noteBinding) {
                        ForEach(viewModel.noteValueOptions.indices, id: \.self) { index in
                            Text(viewModel.noteValueOptions[index].name)
                                .tag(viewModel.noteValueOptions[index].multiplier)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Meter") {
                    MeterFullEditor(section: $section)
                }

                Section("Special Accents") {
                    SectionAccentEditor(section: $section)
                }

                Section("Composite Options") {
                    Stepper(value: $section.bars, in: 1...999) {
                        Text("Bars: \(section.bars)")
                            .font(.system(size: 18, weight: .bold).monospacedDigit())
                    }
                    Toggle("Loop after applying", isOn: $loops)
                }
            }
            .navigationTitle("Next Bar Detail")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isBpmEditing) {
                BpmDirectInput(bpm: $section.bpm)
                    .presentationDetents([.height(200)])
            }
        }
    }

    private var noteBinding: Binding<Double> {
        Binding(
            get: { section.referenceNoteMultiplier },
            set: { section.referenceNoteMultiplier = $0 }
        )
    }
}

@available(iOS 16.7, *)
private struct SectionAccentEditor: View {
    @Binding var section: ProgramSection

    var body: some View {
        let count = max(1, section.meter.numerator)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(count, 8))

        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<count, id: \.self) { index in
                    Toggle("\(index + 1)", isOn: accentBinding(index, count: count))
                        .toggleStyle(.button)
                        .disabled(index == 0)
                }
            }

            Button(section.accents == nil ? "Enable Special Accents" : "Reset Accents") {
                if section.accents == nil {
                    section.accents = Array(repeating: false, count: count)
                } else {
                    section.accents = nil
                }
            }
            .font(.caption)
        }
    }

    private func accentBinding(_ index: Int, count: Int) -> Binding<Bool> {
        Binding(
            get: {
                if index == 0 { return true }
                guard let accents = section.accents, accents.indices.contains(index) else { return false }
                return accents[index]
            },
            set: { newValue in
                guard index != 0 else { return }
                var accents = section.accents ?? Array(repeating: false, count: count)
                if accents.count < count {
                    accents.append(contentsOf: Array(repeating: false, count: count - accents.count))
                } else if accents.count > count {
                    accents = Array(accents.prefix(count))
                }
                accents[index] = newValue
                section.accents = accents
            }
        )
    }
}

@available(iOS 16.7, *)
private struct ProgramEditor: View {
    @ObservedObject var viewModel: MetronomeViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Loop Program", isOn: Binding(
                        get: { viewModel.program.loops },
                        set: { value in
                            var program = viewModel.program
                            program.loops = value
                            viewModel.applyProgram(program)
                        }
                    ))
                }

                ForEach(viewModel.program.sections) { section in
                    SectionEditor(
                        viewModel: viewModel,
                        section: binding(for: section)
                    ) {
                        viewModel.removeSection(section)
                    }
                }
            }
            .navigationTitle("Program")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.addSection()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func binding(for section: ProgramSection) -> Binding<ProgramSection> {
        Binding(
            get: {
                viewModel.program.sections.first(where: { $0.id == section.id }) ?? section
            },
            set: { newValue in
                viewModel.updateSection(newValue)
            }
        )
    }
}

@available(iOS 16.7, *)
private struct SectionEditor: View {
    @ObservedObject var viewModel: MetronomeViewModel
    @Binding var section: ProgramSection
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Name", text: $section.name)
                    .font(.headline)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            MeterFullEditor(section: $section)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    NumberField(title: "BPM", value: $section.bpm, range: 40...400)
                    NumberField(title: "Bars", value: $section.bars, range: 1...64)
                }

                Slider(value: bpmSlider, in: 40...400, step: 1) {
                    Text("BPM")
                }
            }

            HStack {
                Picker("Click", selection: $section.rhythmModeRawValue) {
                    Text("Full").tag(RhythmMode.all.rawValue)
                    Text("Beat").tag(RhythmMode.strongMedium.rawValue)
                    Text("Bar").tag(RhythmMode.strongOnly.rawValue)
                }
                .pickerStyle(.segmented)

                Picker("Note", selection: noteBinding) {
                    ForEach(viewModel.noteValueOptions.indices, id: \.self) { index in
                        Text(viewModel.noteValueOptions[index].name)
                            .tag(viewModel.noteValueOptions[index].multiplier)
                    }
                }
                .pickerStyle(.menu)
            }

            TempoAutomationEditor(automation: $section.tempoAutomation, startBpm: section.bpm)
        }
        .padding(.vertical, 6)
    }

    private var bpmSlider: Binding<Double> {
        Binding(
            get: { Double(section.bpm) },
            set: { section.bpm = Int($0) }
        )
    }

    private var noteBinding: Binding<Double> {
        Binding(
            get: { section.referenceNoteMultiplier },
            set: { section.referenceNoteMultiplier = $0 }
        )
    }
}

@available(iOS 16.7, *)
private struct MeterDraftEditor: View {
    @Binding var section: ProgramSection

    var body: some View {
        Menu(section.meter.displayName) {
            Button("4/4") { section.meter = MeterPattern(groups: [4], denominator: 4) }
            Button("3/4") { section.meter = MeterPattern(groups: [3], denominator: 4) }
            Button("6/8") { section.meter = MeterPattern(groups: [3, 3], denominator: 8) }
            Button("7/8") { section.meter = MeterPattern(groups: [3, 2, 2], denominator: 8) }
            Button("5/8") { section.meter = MeterPattern(groups: [3, 2], denominator: 8) }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
    }
}

@available(iOS 16.7, *)
private struct MeterFullEditor: View {
    @Binding var section: ProgramSection
    private let denominatorOptions = [2, 4, 8, 16, 32]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.meter.displayName)
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                Spacer()
                Picker("Denominator", selection: denominatorBinding) {
                    ForEach(denominatorOptions, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 92, height: 86)
                .clipped()
            }

            HStack(spacing: 8) {
                ForEach(section.meter.groups.indices, id: \.self) { index in
                    Stepper(value: groupBinding(index), in: 1...12) {
                        Text("\(section.meter.groups[index])")
                            .font(.system(size: 17, weight: .bold).monospacedDigit())
                            .frame(width: 22)
                    }
                    .labelsHidden()
                    .frame(width: 72)
                }

                Button {
                    section.meter.groups.append(2)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }

                Button {
                    if section.meter.groups.count > 1 {
                        section.meter.groups.removeLast()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .disabled(section.meter.groups.count <= 1)
            }

            HStack {
                Button("4/4") { section.meter = MeterPattern(groups: [4], denominator: 4) }
                Button("7/8") { section.meter = MeterPattern(groups: [3, 2, 2], denominator: 8) }
                Button("5/8") { section.meter = MeterPattern(groups: [3, 2], denominator: 8) }
                Button("12/8") { section.meter = MeterPattern(groups: [3, 3, 3, 3], denominator: 8) }
            }
            .buttonStyle(.bordered)
        }
    }

    private var denominatorBinding: Binding<Int> {
        Binding(
            get: { section.meter.denominator },
            set: { section.meter.denominator = $0 }
        )
    }

    private func groupBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { section.meter.groups[index] },
            set: { section.meter.groups[index] = max(1, $0) }
        )
    }
}

@available(iOS 16.7, *)
private struct TempoAutomationEditor: View {
    @Binding var automation: TempoAutomation
    let startBpm: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Tempo Change", selection: $automation.shape) {
                Text("None").tag(TempoAutomationShape.none)
                Text("rit.").tag(TempoAutomationShape.ritardando)
                Text("accel.").tag(TempoAutomationShape.accelerando)
            }
            .pickerStyle(.segmented)

            if automation.shape != .none {
                HStack {
                    NumberField(title: "Target", value: $automation.targetBpm, range: 40...400)
                    NumberField(title: "Bars", value: $automation.lengthInBars, range: 1...64)
                }
                Slider(value: targetSlider, in: 40...400, step: 1) {
                    Text("Target")
                }
                Text("\(startBpm) -> \(automation.targetBpm) BPM over \(automation.lengthInBars) bars")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetSlider: Binding<Double> {
        Binding(
            get: { Double(automation.targetBpm) },
            set: { automation.targetBpm = Int($0) }
        )
    }
}

@available(iOS 16.7, *)
private struct NumberField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, value: sanitizedValue, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 18, weight: .bold).monospacedDigit())
        }
    }

    private var sanitizedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { value = min(range.upperBound, max(range.lowerBound, $0)) }
        )
    }
}

@available(iOS 16.7, *)
private struct ControlButton: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
        }
        .frame(width: 76, height: 76)
        .foregroundStyle(tint)
        .background(tint.opacity(0.16), in: Circle())
    }
}

@available(iOS 16.7, *)
private struct ModernPieIndicatorView: View {
    let viewModel: MetronomeViewModel
    let date: Date

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outerRadius = radius - 10
            let innerRadius = outerRadius - 28
            let isPlaying = viewModel.isPlaying
            let progress = isPlaying ? currentMeasureProgress() : 0.0
            let safeProgress = progress.truncatingRemainder(dividingBy: 1.0)
            let currentAngle = safeProgress * 360.0 - 90.0

            drawArc(context: context, center: center, radius: outerRadius, start: -90, end: 270, color: .white.opacity(0.08), width: 5)

            let outerCount = Double(max(1, viewModel.numerator))
            for index in 0..<Int(outerCount) {
                let start = Double(index) / outerCount
                let end = Double(index + 1) / outerCount
                drawArc(
                    context: context,
                    center: center,
                    radius: innerRadius,
                    start: start * 360 - 88,
                    end: end * 360 - 92,
                    color: index == 0 ? .orange.opacity(0.24) : .cyan.opacity(0.14),
                    width: 8
                )
            }

            if isPlaying {
                drawArc(context: context, center: center, radius: outerRadius, start: -90, end: currentAngle, color: .cyan, width: 12)
                var needle = Path()
                needle.move(to: center)
                let endPoint = CGPoint(
                    x: center.x + outerRadius * cos(currentAngle * .pi / 180),
                    y: center.y + outerRadius * sin(currentAngle * .pi / 180)
                )
                needle.addLine(to: endPoint)
                context.stroke(needle, with: .color(.white.opacity(0.9)), lineWidth: 2)
                context.fill(Circle().path(in: CGRect(x: endPoint.x - 5, y: endPoint.y - 5, width: 10, height: 10)), with: .color(.white))
            }
        }
    }

    private func drawArc(context: GraphicsContext, center: CGPoint, radius: CGFloat, start: Double, end: Double, color: Color, width: CGFloat) {
        guard end > start else { return }
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func currentMeasureProgress() -> Double {
        let now = DispatchTime.now()
        let last = viewModel.lastTickTime
        guard now >= last else { return 0.0 }
        let elapsed = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000_000.0
        let beatIdx = viewModel.currentBeat - 1.0
        let totalTicks = Double(max(1, viewModel.totalTicksInMeasure))
        let beatProgress = (beatIdx * Double(viewModel.ticksPerOuterBeat)) + (elapsed / viewModel.tickInterval)
        return beatProgress / totalTicks
    }
}

@available(iOS 16.7, *)
private struct BpmDirectInput: View {
    @Binding var bpm: Int
    @Environment(\.dismiss) var dismiss
    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Set BPM")
                .font(.headline)

            TextField("BPM", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 48, weight: .bold).monospacedDigit())
                .onAppear {
                    text = "\(bpm)"
                }

            Button("Done") {
                if let value = Int(text) {
                    bpm = min(400, max(40, value))
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
