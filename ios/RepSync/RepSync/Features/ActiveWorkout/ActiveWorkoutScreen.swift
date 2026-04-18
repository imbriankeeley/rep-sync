import SwiftUI

struct ActiveWorkoutScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsCancelConfirmation = false
    @State private var showsFinishWarning = false
    @State private var finishWarningMessage = ""
    @State private var finishWarningAllowsOverride = false

    var body: some View {
        if let state = appModel.activeWorkoutState {
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
            }
            .background(RepSyncTheme.background.ignoresSafeArea())
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
                        appModel.showRestTimerSheet()
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
                    .contextMenu {
                        if appModel.restTimerSecondsRemaining > 0 {
                            Button("Stop Rest Timer") {
                                appModel.cancelRestTimer()
                            }
                        }
                    }
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Set \(set.setNumber)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                            Spacer()
                            if !set.previous.isEmpty {
                                Text(set.previous)
                                    .font(.system(size: 13))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                            }
                            Button {
                                appModel.toggleSetCompleted(for: exercise.id, setID: set.id)
                            } label: {
                                Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(set.isComplete ? RepSyncTheme.checkmark : RepSyncTheme.textSecondary)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }

                        fields(for: $set, trackingType: exercise.trackingType)
                    }
                    .padding(12)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
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
                workoutField("Lbs", text: set.weight)
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
                    workoutField("Miles", text: set.distance)
                    workoutField("MPH", text: set.speed)
                }
            }
        }
    }

    private func workoutField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .keyboardType(.decimalPad)
            .foregroundStyle(RepSyncTheme.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RepSyncTheme.input)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
