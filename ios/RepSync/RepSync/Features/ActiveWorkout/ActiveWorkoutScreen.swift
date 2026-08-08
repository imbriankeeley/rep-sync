import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ActiveWorkoutScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsCancelConfirmation = false
    @State private var showsFinishWarning = false
    @State private var finishWarningMessage = ""
    @State private var finishWarningAllowsOverride = false
    @State private var draggingExerciseID: UUID?
    @State private var highlightedExerciseDropIndex: Int?

    var body: some View {
        if let state = appModel.activeWorkoutState {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(state.exercises.enumerated()), id: \.element.id) { index, exercise in
                                RepSyncReorderDropZone(
                                    index: index,
                                    isEnabled: canDropActiveExercise(at: index),
                                    draggingID: $draggingExerciseID,
                                    highlightedIndex: $highlightedExerciseDropIndex,
                                    onDrop: { sourceID, targetIndex in
                                        appModel.moveActiveExercise(id: sourceID, to: targetIndex)
                                    },
                                    onEnd: {
                                        appModel.commitActiveExerciseOrder()
                                    }
                                )

                                if let exerciseBinding = binding(for: exercise.id) {
                                    ActiveExerciseCard(exercise: exerciseBinding)
                                        .onDrag {
                                            draggingExerciseID = exercise.id
                                            return NSItemProvider(object: exercise.id.uuidString as NSString)
                                        } preview: {
                                            ActiveExerciseDragPreview(exercise: exercise)
                                        }
                                }
                            }

                            if !state.exercises.isEmpty {
                                RepSyncReorderDropZone(
                                    index: state.exercises.count,
                                    isEnabled: canDropActiveExercise(at: state.exercises.count),
                                    draggingID: $draggingExerciseID,
                                    highlightedIndex: $highlightedExerciseDropIndex,
                                    onDrop: { sourceID, targetIndex in
                                        appModel.moveActiveExercise(id: sourceID, to: targetIndex)
                                    },
                                    onEnd: {
                                        appModel.commitActiveExerciseOrder()
                                    }
                                )
                            }

                            Button {
                                appModel.addExerciseToActiveWorkout()
                            } label: {
                                Text("Add Exercise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(RepSyncTheme.primaryGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
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
                            } label: {
                                Text("Finish Workout")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(RepSyncTheme.primaryGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            dismissKeyboard()
                        }
                    )
                }

                if appModel.selectedMusicProvider != nil {
                    ActiveWorkoutMusicWidget()
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                }
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
            HStack {
                RepSyncHeaderButton(title: "<") {
                    appModel.leaveActiveWorkoutOpen()
                }
                Spacer()
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
                            .background(appModel.restTimerSecondsRemaining > 0 ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                RepSyncHeaderButton(title: "X", background: RepSyncTheme.destructive) {
                    if appModel.hasActiveWorkoutToDiscard() {
                        showsCancelConfirmation = true
                    } else {
                        appModel.cancelActiveWorkout()
                    }
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

    private func canDropActiveExercise(at index: Int) -> Bool {
        guard let draggingExerciseID,
              let sourceIndex = appModel.activeWorkoutState?.exercises.firstIndex(where: { $0.id == draggingExerciseID }) else {
            return true
        }
        return index != sourceIndex && index != sourceIndex + 1
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
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    Button {
                        appModel.removeActiveExercise(id: exercise.id)
                    } label: {
                        Text("X")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(RepSyncTheme.cardElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if !suggestions.isEmpty {
                    RepSyncSuggestionList(suggestions: suggestions) { suggestion in
                        appModel.applyActiveSuggestion(suggestion, to: exercise.id)
                    }
                }

                if exercise.isTrackingTypeLocked {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exercise Type")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                        RepSyncExerciseTypeBadge(trackingType: exercise.trackingType)
                    }
                } else if !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                                    .background(RepSyncTheme.cardElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                List {
                    ForEach($exercise.sets) { $set in
                        setRow(for: $set)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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

                Button {
                    dismissKeyboard()
                    appModel.addSet(to: exercise.id)
                } label: {
                    Text("Add Set")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var setListHeight: CGFloat {
        CGFloat(exercise.sets.count) * setListRowHeight
    }

    private var setListRowHeight: CGFloat {
        switch exercise.trackingType {
        case .durationDistance:
            return 148
        case .weightReps, .duration:
            return 100
        }
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
                        .font(.system(size: 20))
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
            .background(RepSyncTheme.input)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(RepSyncTheme.textSecondary)
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
                    .background(appModel.restTimerDurationSeconds == preset ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .buttonStyle(.plain)

                Button("Done") {
                    appModel.dismissRestTimerSheet()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RepSyncTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
