import SwiftUI
import UIKit

struct ActiveWorkoutScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsCancelConfirmation = false
    @State private var showsFinishWarning = false
    @State private var finishWarningMessage = ""
    @State private var finishWarningAllowsOverride = false

    var body: some View {
        if let state = appModel.activeWorkoutState {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    header

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(state.exercises) { exercise in
                                if let exerciseBinding = binding(for: exercise.id) {
                                    ActiveExerciseCard(exercise: exerciseBinding)
                                }
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
                    .scrollDismissesKeyboard(.immediately)
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
                guard appModel.activeWorkoutState != nil else { return }
                appModel.activeWorkoutState?[keyPath: keyPath] = $0
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
                guard let index = appModel.activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else {
                    return
                }
                appModel.activeWorkoutState?.exercises[index] = updatedExercise
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

                ForEach($exercise.sets) { $set in
                    SwipeableSetCard(
                        isRemovable: exercise.sets.count > 1 && set.setNumber > 1,
                        onRemove: {
                            dismissKeyboard()
                            appModel.removeSet(from: exercise.id, setID: set.id)
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 12) {
                                setNumberButton(for: $set, totalSetCount: exercise.sets.count)
                                Spacer()
                                if !set.previous.isEmpty {
                                    Text(set.previous)
                                        .font(.system(size: 13))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }
                                Button {
                                    dismissKeyboard()
                                    appModel.toggleSetCompleted(for: exercise.id, setID: set.id)
                                } label: {
                                    Image(systemName: set.isComplete ? "checkmark.circle.fill" : "checkmark.circle")
                                        .foregroundStyle(set.isComplete ? RepSyncTheme.checkmark : RepSyncTheme.textSecondary)
                                        .font(.system(size: 20))
                                        .opacity(appModel.canToggleSetCompleted(for: exercise.id, setID: set.id) ? 1 : 0.4)
                                }
                                .buttonStyle(.plain)
                                .disabled(!appModel.canToggleSetCompleted(for: exercise.id, setID: set.id))
                            }

                            fields(for: $set, trackingType: exercise.trackingType)
                        }
                    }
                }

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

private struct SwipeableSetCard<Content: View>: View {
    private let actionWidth: CGFloat = 96
    private let revealThreshold: CGFloat = 46
    private let fullSwipeThreshold: CGFloat = 140
    private let removalAnimationDuration: Double = 0.22
    private let maxDragDistance: CGFloat = UIScreen.main.bounds.width + 60

    let isRemovable: Bool
    let onRemove: () -> Void
    @ViewBuilder let content: Content

    @State private var settledOffset: CGFloat = 0
    @State private var isRemoving = false
    @GestureState private var dragOffset: CGFloat = 0

    private var effectiveOffset: CGFloat {
        min(0, settledOffset + dragOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isRemovable ? RepSyncTheme.destructive : RepSyncTheme.cardElevated)

            if isRemovable {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        animateRemoval()
                    } label: {
                        Text("Remove")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                            .frame(width: actionWidth)
                            .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            content
                .padding(12)
                .background(RepSyncTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(x: effectiveOffset)
                .opacity(isRemoving ? 0.9 : 1)
                .scaleEffect(isRemoving ? 0.985 : 1, anchor: .center)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .gesture(isRemovable ? swipeGesture : nil)
        .allowsHitTesting(!isRemoving)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.84), value: settledOffset)
        .animation(.easeOut(duration: removalAnimationDuration), value: isRemoving)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                guard !isRemoving else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let translation = value.translation.width
                if translation <= 0 {
                    state = max(-maxDragDistance, translation)
                } else if settledOffset < 0 {
                    state = min(-settledOffset, translation)
                }
            }
            .onEnded { value in
                guard !isRemoving else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let finalOffset = min(0, settledOffset + value.translation.width)
                if finalOffset <= -fullSwipeThreshold {
                    animateRemoval()
                } else if finalOffset <= -revealThreshold {
                    settledOffset = -actionWidth
                } else {
                    settledOffset = 0
                }
            }
    }

    private func animateRemoval() {
        guard !isRemoving else { return }

        isRemoving = true
        withAnimation(.easeOut(duration: removalAnimationDuration)) {
            settledOffset = -(UIScreen.main.bounds.width + 60)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + removalAnimationDuration) {
            onRemove()
        }
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
