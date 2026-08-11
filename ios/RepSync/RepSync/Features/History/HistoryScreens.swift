import SwiftUI

struct DayViewScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var templateSourceWorkoutID: UUID?
    @State private var templateName = ""
    @State private var editingWorkoutDateID: UUID?
    @State private var editedWorkoutDate = Date()
    @State private var workoutToRemoveID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RepSyncHeaderButton(title: "<") { appModel.pop() }
                Text(DateFormatter.repsyncLongDate.string(from: appModel.dayViewState.selectedDate))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                Spacer().frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RepSyncTheme.card)

            List {
                Section {
                    if appModel.dayViewState.workouts.isEmpty {
                        Text("No workouts on this day")
                            .font(.system(size: 16))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(appModel.dayViewState.workouts) { workout in
                        completedWorkoutCard(workout)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    workoutToRemoveID = workout.id
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
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .overlay {
            if editingWorkoutDateID != nil {
                RepSyncCenteredOverlay(onDismiss: { editingWorkoutDateID = nil }) {
                    editWorkoutDateOverlay
                }
            }
        }
        .alert("Save as Template", isPresented: Binding(
            get: { templateSourceWorkoutID != nil },
            set: { if !$0 { templateSourceWorkoutID = nil } }
        )) {
            TextField("Workout Name", text: $templateName)
            Button("Cancel", role: .cancel) {
                templateSourceWorkoutID = nil
            }
            Button("Save") {
                if let templateSourceWorkoutID {
                    appModel.copyCompletedWorkoutToTemplate(
                        id: templateSourceWorkoutID,
                        templateName: templateName
                    )
                }
                templateSourceWorkoutID = nil
            }
        } message: {
            Text("Name this workout before saving it to your templates.")
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: editingWorkoutDateID)
        .alert("Remove Workout?", isPresented: Binding(
            get: { workoutToRemoveID != nil },
            set: { if !$0 { workoutToRemoveID = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                workoutToRemoveID = nil
            }
            Button("Remove", role: .destructive) {
                if let workoutToRemoveID {
                    appModel.deleteCompletedWorkout(id: workoutToRemoveID)
                }
                workoutToRemoveID = nil
            }
        } message: {
            Text("This completed workout will be removed permanently and cannot be undone.")
        }
    }

    private var editWorkoutDateOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Workout Date")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)

            DatePicker("Performed On", selection: $editedWorkoutDate, displayedComponents: .date)
                .tint(RepSyncTheme.primaryGreen)
                .foregroundStyle(RepSyncTheme.textPrimary)

            HStack(spacing: 12) {
                Button {
                    editingWorkoutDateID = nil
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    if let editingWorkoutDateID {
                        appModel.updateCompletedWorkoutDate(id: editingWorkoutDateID, on: editedWorkoutDate)
                    }
                    editingWorkoutDateID = nil
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .repsyncGlassButtonBackground(RepSyncTheme.primaryGreen, shape: .roundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionPill(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .repsyncGlassButtonBackground(fill, shape: .roundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func completedWorkoutCard(_ workout: CompletedWorkoutCardModel) -> some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                        if let subtitle = workout.subtitle {
                            Text(subtitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.primaryGreen)
                        }
                    }

                    Spacer()

                    Label(workout.durationText, systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }

                VStack(spacing: 8) {
                    ForEach(workout.exercises) { exercise in
                        Button {
                            appModel.showExerciseHistory(exercise.name)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(RepSyncTheme.primaryGreen)
                                        Text(exercise.trackingType.displayName)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(RepSyncTheme.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }

                                ForEach(exercise.sets) { set in
                                    HStack(spacing: 8) {
                                        Text("Set \(set.setNumber)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(RepSyncTheme.textSecondary)
                                            .frame(width: 48, alignment: .leading)
                                        if set.isBestSet {
                                            Image(systemName: "trophy.fill")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(RepSyncTheme.primaryGreen)
                                                .frame(width: 12)
                                        } else {
                                            Color.clear.frame(width: 12, height: 12)
                                        }
                                        Text(set.summary)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(RepSyncTheme.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }
                            .padding(12)
                            .background(RepSyncTheme.cardElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    actionPill("Template", fill: RepSyncTheme.primaryGreen.opacity(0.58)) {
                        templateSourceWorkoutID = workout.id
                        templateName = workout.title
                    }
                    actionPill("Edit", fill: RepSyncTheme.cardElevated) {
                        editingWorkoutDateID = workout.id
                        editedWorkoutDate = appModel.dayViewState.selectedDate
                    }
                }
            }
        }
    }
}

struct ExerciseHistoryScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RepSyncHeaderButton(title: "<") { appModel.pop() }
                Text(appModel.historyState.exerciseName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Spacer()
                    .frame(width: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RepSyncTheme.card)

            ScrollView {
                VStack(spacing: 12) {
                    RepSyncCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Performance")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)

                            HStack(spacing: 8) {
                                ForEach(appModel.historyState.stats, id: \.0) { stat in
                                    statCard(title: stat.0, value: stat.1)
                                }
                            }
                        }
                    }

                    RepSyncCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Trend")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                                Spacer()
                                Text("lbs")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .padding(.horizontal, 9)
                                    .frame(height: 24)
                                    .background(RepSyncTheme.cardElevated)
                                    .clipShape(Capsule())
                            }

                            RepSyncLineChart(points: appModel.historyState.points, label: "lbs")
                                .frame(height: 180)
                        }
                    }

                    RepSyncCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("History")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(RepSyncTheme.textPrimary)

                            if appModel.historyState.sessions.isEmpty {
                                Text("No completed sets logged yet.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(appModel.historyState.sessions) { session in
                                        sessionRow(session)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
        )
    }

    private func sessionRow(_ session: ExerciseSessionModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(session.dateText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)

                Spacer(minLength: 8)

                Text(session.workoutName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(RepSyncTheme.card)
                    .clipShape(Capsule())
            }

            Text(session.summary)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RepSyncTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
        )
    }
}
