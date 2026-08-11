import SwiftUI
import UIKit

struct ActiveWorkoutScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsCancelConfirmation = false
    @State private var showsFinishWarning = false
    @State private var finishWarningMessage = ""
    @State private var finishWarningAllowsOverride = false
    @State private var exerciseToRemove: ActiveExerciseDraft?

    var body: some View {
        if let state = appModel.activeWorkoutState {
            VStack(spacing: 0) {
                header

                List {
                    Section {
                        ForEach(state.exercises) { exercise in
                            if let exerciseBinding = binding(for: exercise.id) {
                                ActiveExerciseCard(exercise: exerciseBinding)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            exerciseToRemove = exercise
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                        .tint(RepSyncTheme.destructive)
                                    }
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                        .onMove { source, destination in
                            appModel.moveActiveExercises(fromOffsets: source, toOffset: destination)
                        }

                        RepSyncGhostAddCard(title: "Add Exercise") {
                            appModel.addExerciseToActiveWorkout()
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
            }
            .background(RepSyncTheme.background.ignoresSafeArea())
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
            .navigationBarBackButtonHidden(true)
            .alert("Discard Workout?", isPresented: $showsCancelConfirmation) {
                Button("Keep Editing", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    appModel.cancelActiveWorkout()
                }
            } message: {
                Text("This will permanently remove the current workout and all entered sets.")
            }
            .alert("Review Workout", isPresented: $showsFinishWarning) {
                Button("Keep Editing", role: .cancel) {}
                if finishWarningAllowsOverride {
                    Button("Finish Anyway") {
                        appModel.finishActiveWorkout()
                    }
                }
            } message: {
                Text(finishWarningMessage)
            }
            .alert("Remove Exercise?", isPresented: Binding(
                get: { exerciseToRemove != nil },
                set: { if !$0 { exerciseToRemove = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    exerciseToRemove = nil
                }
                Button("Remove", role: .destructive) {
                    if let exerciseToRemove {
                        appModel.removeActiveExercise(id: exerciseToRemove.id)
                    }
                    exerciseToRemove = nil
                }
            } message: {
                Text("This exercise and its sets will be removed from the active workout.")
            }
            .sheet(isPresented: $appModel.showsRestTimerSheet) {
                RestTimerSheet()
                    .presentationDetents([.medium])
            }
        } else {
            Color.clear.onAppear { appModel.pop() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                HStack {
                    RepSyncHeaderButton(title: "<") {
                        appModel.leaveActiveWorkoutOpen()
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        finishWorkoutButton

                        RepSyncHeaderButton(title: "X", background: RepSyncTheme.destructive) {
                            if appModel.hasActiveWorkoutToDiscard() {
                                showsCancelConfirmation = true
                            } else {
                                appModel.cancelActiveWorkout()
                            }
                        }
                    }
                }

                VStack(spacing: 4) {
                    Text(appModel.activeWorkoutState?.elapsedText ?? "0:00")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Button {
                        if appModel.restTimerSecondsRemaining > 0 {
                            appModel.cancelRestTimer()
                        } else {
                            appModel.showRestTimerSheet()
                        }
                    } label: {
                        Text(appModel.restTimerSecondsRemaining > 0 ? "Rest \(formatRestTimer(appModel.restTimerSecondsRemaining))" : "Rest \(formatRestTimer(appModel.restTimerDurationSeconds))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(appModel.restTimerSecondsRemaining > 0 ? RepSyncTheme.primaryGreenDark : RepSyncTheme.cardElevated)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Workout Name", text: binding(\.workoutName))
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(RepSyncTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RepSyncTheme.card)
    }

    private var finishWorkoutButton: some View {
        Button {
            validateAndFinishWorkout()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(width: 40, height: 40)
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish Workout")
    }

    private func validateAndFinishWorkout() {
        if !appModel.activeWorkoutHasNamedExercises() {
            finishWarningMessage = "Add at least one exercise before finishing this workout."
            finishWarningAllowsOverride = false
            showsFinishWarning = true
        } else if !appModel.activeWorkoutHasCompletedSets() {
            finishWarningMessage = "Check off at least one completed set before finishing so the workout is not saved with missing data."
            finishWarningAllowsOverride = false
            showsFinishWarning = true
        } else if let message = appModel.finishWorkoutWarningMessage() {
            finishWarningMessage = message
            finishWarningAllowsOverride = true
            showsFinishWarning = true
        } else {
            appModel.finishActiveWorkout()
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ActiveWorkoutScreenState, Value>) -> Binding<Value> {
        Binding(
            get: { appModel.activeWorkoutState?[keyPath: keyPath] ?? fallbackValue(for: keyPath) },
            set: {
                guard var state = appModel.activeWorkoutState else { return }
                state[keyPath: keyPath] = $0
                appModel.updateActiveWorkout(state)
            }
        )
    }

    private func binding(for exerciseID: UUID) -> Binding<ActiveExerciseDraft>? {
        guard let exercise = appModel.activeWorkoutState?.exercises.first(where: { $0.id == exerciseID }) else {
            return nil
        }

        return Binding(
            get: {
                appModel.activeWorkoutState?.exercises.first(where: { $0.id == exerciseID }) ?? exercise
            },
            set: { updatedExercise in
                appModel.updateActiveExercise(updatedExercise)
            }
        )
    }

    private func fallbackValue<Value>(for keyPath: WritableKeyPath<ActiveWorkoutScreenState, Value>) -> Value {
        let fallbackState = ActiveWorkoutScreenState(
            templateID: nil,
            isQuickWorkout: true,
            workoutName: "",
            startedAt: Date(),
            elapsedText: "0:00",
            exercises: []
        )
        return fallbackState[keyPath: keyPath]
    }

    private func formatRestTimer(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(remainder)s"
    }
}

private struct ActiveWorkoutMusicWidget: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var isExpanded = false

    var body: some View {
        Group {
            if appModel.selectedMusicProvider == .appleMusic {
                widgetCard(title: "Apple Music", subtitle: appModel.musicNowPlaying?.title ?? appModel.currentAppleMusicWorkoutMixLabel ?? appModel.appleMusicStatusText) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            controlButton(appModel.isAppleMusicPlaying ? "pause.fill" : "play.fill") {
                                appModel.toggleAppleMusicPlayback()
                            }
                            controlButton("forward.fill") {
                                appModel.skipAppleMusicTrack()
                            }
                        }

                        HStack(spacing: 8) {
                            if appModel.hasCurrentAppleMusicWorkoutMix {
                                labeledControlButton("Workout Mix", systemName: "music.note.list") {
                                    appModel.playCurrentWorkoutMix()
                                }
                            }

                            labeledControlButton("Open", systemName: "arrow.up.forward.app.fill") {
                                appModel.openAppleMusicApp()
                            }
                        }
                    }
                }
            } else if appModel.selectedMusicProvider == .spotify {
                widgetCard(title: "Spotify", subtitle: appModel.musicNowPlaying?.title ?? appModel.activeWorkoutState?.musicPlaylistName ?? appModel.spotifyStatusText) {
                    controlButton(appModel.isSpotifyConnected ? (appModel.isSpotifyPlaying ? "pause.fill" : "play.fill") : "link") {
                        if appModel.isSpotifyConnected {
                            appModel.toggleSpotifyPlayback()
                        } else {
                            appModel.connectSpotify()
                        }
                    }
                    controlButton(appModel.isSpotifyConnected ? "forward.fill" : "arrow.up.forward.app.fill") {
                        if appModel.isSpotifyConnected {
                            appModel.skipSpotifyTrack()
                        } else {
                            appModel.playCurrentWorkoutMix()
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func widgetCard<Controls: View>(title: String, subtitle: String, @ViewBuilder controls: () -> Controls) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                if isExpanded {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                controls()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: isExpanded ? 216 : 92, alignment: .leading)
        .frame(minHeight: 56)
        .background(RepSyncTheme.card.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RepSyncTheme.cardElevated, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                isExpanded = true
            }
        }
    }

    private func controlButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func labeledControlButton(_ title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct ActiveExerciseDragPreview: View {
    let exercise: ActiveExerciseDraft

    var body: some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Exercise" : exercise.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                RepSyncExerciseTypeBadge(trackingType: exercise.trackingType)

                HStack {
                    Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }
}

private struct ActiveExerciseCard: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @Binding var exercise: ActiveExerciseDraft

    private var suggestions: [ExerciseSuggestion] {
        let exactMatch = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(
            appModel.exerciseSuggestions(for: exactMatch)
                .filter { $0.name.caseInsensitiveCompare(exactMatch) != .orderedSame }
                .prefix(5)
        )
    }

    var body: some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    TextField("Exercise name", text: $exercise.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .textInputAutocapitalization(.words)
                        .onChange(of: exercise.name) { _, _ in
                            appModel.clearActiveSuggestionFlag(for: exercise.id)
                            appModel.resolveActiveExerciseName(for: exercise.id)
                        }

                    Spacer(minLength: 8)

                    if exercise.isTrackingTypeLocked {
                        RepSyncExerciseTypeBadge(trackingType: exercise.trackingType)
                    }
                }

                if !suggestions.isEmpty {
                    RepSyncSuggestionList(suggestions: suggestions) { suggestion in
                        appModel.applyActiveSuggestion(suggestion, to: exercise.id)
                    }
                }

                if !exercise.isTrackingTypeLocked && !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Exercise Type")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                        ForEach(ExerciseTrackingKind.allCases) { type in
                            Button {
                                appModel.lockTrackingType(type, for: exercise.id)
                            } label: {
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 4) {
                    List {
                        ForEach($exercise.sets) { $set in
                            setRow(for: $set)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if exercise.sets.count > 1 && set.setNumber > 1 {
                                        Button(role: .destructive) {
                                            dismissKeyboard()
                                            appModel.removeSet(from: exercise.id, setID: set.id)
                                        } label: {
                                            Text("Remove")
                                        }
                                        .tint(RepSyncTheme.destructive)
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(RepSyncTheme.card)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 0)
                    .frame(height: setListHeight)

                    addSetButton
                }
            }
        }
    }

    private var setListHeight: CGFloat {
        CGFloat(exercise.sets.count) * (setListRowHeight + 8)
    }

    private var setListRowHeight: CGFloat {
        switch exercise.trackingType {
        case .durationDistance:
            return 164
        case .weightReps, .duration:
            return 108
        }
    }

    private var addSetButton: some View {
        Button(action: addSet) {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(RepSyncTheme.primaryGreen)
                .frame(width: 72, height: 34)
                .contentShape(Capsule())
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen.opacity(0.58), shape: .capsule)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Add Set")
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func addSet() {
        appModel.addSet(to: exercise.id)
    }

    private func setRow(for set: Binding<ActiveSetDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                setNumberButton(for: set, totalSetCount: exercise.sets.count)
                Spacer()
                if !set.wrappedValue.previous.isEmpty {
                    Text(set.wrappedValue.previous)
                        .font(.system(size: 13))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }
                Button {
                    dismissKeyboard()
                    appModel.toggleSetCompleted(for: exercise.id, setID: set.wrappedValue.id)
                } label: {
                    Image(systemName: set.wrappedValue.isComplete ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(set.wrappedValue.isComplete ? RepSyncTheme.checkmark : RepSyncTheme.textSecondary)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .repsyncGlassButtonBackground(set.wrappedValue.isComplete ? RepSyncTheme.primaryGreen.opacity(0.42) : RepSyncTheme.cardElevated, shape: .circle)
                        .opacity(appModel.canToggleSetCompleted(for: exercise.id, setID: set.wrappedValue.id) ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!appModel.canToggleSetCompleted(for: exercise.id, setID: set.wrappedValue.id))
            }

            fields(for: set, trackingType: exercise.trackingType)
        }
        .padding(12)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func fields(for set: Binding<ActiveSetDraft>, trackingType: ExerciseTrackingKind) -> some View {
        switch trackingType {
        case .weightReps:
            HStack(spacing: 8) {
                workoutField("Lbs", text: set.weight, allowsDecimal: true)
                workoutField("Reps", text: set.reps)
            }
        case .duration:
            HStack(spacing: 8) {
                workoutField("Min", text: set.minutes)
                workoutField("Sec", text: set.seconds)
            }
        case .durationDistance:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    workoutField("Min", text: set.minutes)
                    workoutField("Sec", text: set.seconds)
                }
                HStack(spacing: 8) {
                    workoutField("Miles", text: set.distance, allowsDecimal: true)
                    workoutField("MPH", text: set.speed, allowsDecimal: true)
                }
            }
        }
    }

    private func workoutField(_ label: String, text: Binding<String>, allowsDecimal: Bool = false) -> some View {
        TextField(label, text: text)
            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
            .foregroundStyle(RepSyncTheme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .repsyncGlassButtonBackground(RepSyncTheme.input, shape: .roundedRectangle(cornerRadius: 8))
            .onChange(of: text.wrappedValue) { _, newValue in
                let sanitized = allowsDecimal ? sanitizeDecimalInput(newValue) : sanitizeIntegerInput(newValue)
                if sanitized != newValue {
                    text.wrappedValue = sanitized
                }
            }
    }

    private func setNumberButton(for set: Binding<ActiveSetDraft>, totalSetCount: Int) -> some View {
        let _ = totalSetCount

        return Text("Set \(set.wrappedValue.setNumber)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(RepSyncTheme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RepSyncTheme.input.opacity(0.55))
            .clipShape(Capsule())
    }
}

private struct RestTimerSheet: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    private let presets = [30, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rest Timer")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)

            Text("Choose a preset or set a custom number of seconds.")
                .font(.system(size: 14))
                .foregroundStyle(RepSyncTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button(label(for: preset)) {
                        appModel.setRestTimerDuration(seconds: preset)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appModel.restTimerDurationSeconds == preset ? RepSyncTheme.textOnLight : RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .repsyncGlassButtonBackground(appModel.restTimerDurationSeconds == preset ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                TextField("Custom sec", text: $appModel.customRestTimerSeconds)
                    .keyboardType(.numberPad)
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(RepSyncTheme.input)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: appModel.customRestTimerSeconds) { _, newValue in
                        let sanitized = sanitizeIntegerInput(newValue)
                        if sanitized != newValue {
                            appModel.customRestTimerSeconds = sanitized
                        }
                    }

                Button("Set") {
                    appModel.applyCustomRestTimerDuration()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Button("Disable") {
                    appModel.setRestTimerDuration(seconds: 0)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)

                Button("Done") {
                    appModel.dismissRestTimerSheet()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(24)
        .background(RepSyncTheme.background)
    }

    private func label(for seconds: Int) -> String {
        switch seconds {
        case 30: return "30s"
        case 60: return "1m"
        case 90: return "1m 30s"
        case 120: return "2m"
        default: return "\(seconds)s"
        }
    }
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private func sanitizeIntegerInput(_ value: String) -> String {
    value.filter(\.isNumber)
}

private func sanitizeDecimalInput(_ value: String) -> String {
    var result = ""
    var hasDecimalSeparator = false

    for character in value {
        if character.isNumber {
            result.append(character)
        } else if character == "." && !hasDecimalSeparator {
            hasDecimalSeparator = true
            result.append(character)
        }
    }

    return result
}
