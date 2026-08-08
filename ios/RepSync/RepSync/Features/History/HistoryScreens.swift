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

            ScrollView {
                VStack(spacing: 12) {
                    if appModel.dayViewState.workouts.isEmpty {
                        Text("No workouts on this day")
                            .font(.system(size: 16))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                            .padding(.top, 48)
                    }

                    ForEach(appModel.dayViewState.workouts) { workout in
                        RepSyncCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(workout.title)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(RepSyncTheme.textPrimary)
                                        if let subtitle = workout.subtitle {
                                            Text(subtitle)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(RepSyncTheme.primaryGreen)
                                        }
                                    }
                                    Spacer()
                                    Text(workout.durationText)
                                        .font(.system(size: 16))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }

                                Divider().overlay(RepSyncTheme.divider)

                                ForEach(workout.exercises) { exercise in
                                    Button {
                                        appModel.showExerciseHistory(exercise.name)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(exercise.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(RepSyncTheme.primaryGreen)
                                            Text(exercise.trackingType.displayName)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(RepSyncTheme.textSecondary.opacity(0.6))

                                            ForEach(exercise.sets) { set in
                                                HStack {
                                                    Text("\(set.setNumber)")
                                                        .font(.system(size: 14))
                                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                                        .frame(width: 24, alignment: .leading)
                                                    if set.isBestSet {
                                                        Image(systemName: "trophy.fill")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundStyle(RepSyncTheme.primaryGreen)
                                                            .frame(width: 12)
                                                    } else {
                                                        Color.clear.frame(width: 12, height: 12)
                                                    }
                                                    Spacer()
                                                    Text(set.summary)
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundStyle(RepSyncTheme.textPrimary)
                                                }
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 3)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 8) {
                                    actionPill("Template", fill: RepSyncTheme.primaryGreen) {
                                        templateSourceWorkoutID = workout.id
                                        templateName = workout.title
                                    }
                                    actionPill("Edit", fill: RepSyncTheme.cardElevated) {
                                        editingWorkoutDateID = workout.id
                                        editedWorkoutDate = appModel.dayViewState.selectedDate
                                    }
                                    actionPill("Remove", fill: RepSyncTheme.destructive) { workoutToRemoveID = workout.id }
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
        .sheet(isPresented: Binding(
            get: { editingWorkoutDateID != nil },
            set: { if !$0 { editingWorkoutDateID = nil } }
        )) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Workout Date")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)

                DatePicker("Performed On", selection: $editedWorkoutDate, displayedComponents: .date)
                    .tint(RepSyncTheme.primaryGreen)
                    .foregroundStyle(RepSyncTheme.textPrimary)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        editingWorkoutDateID = nil
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)

                    Button("Save") {
                        if let editingWorkoutDateID {
                            appModel.updateCompletedWorkoutDate(id: editingWorkoutDateID, on: editedWorkoutDate)
                        }
                        editingWorkoutDateID = nil
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
            .presentationDetents([.medium])
        }
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

    private func actionPill(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ExerciseHistoryScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                RepSyncHeaderButton(title: "<") { appModel.pop() }
                Text(appModel.historyState.exerciseName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RepSyncTheme.card)

            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ForEach(appModel.historyState.stats, id: \.0) { stat in
                            VStack(spacing: 6) {
                                Text(stat.0)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                Text(stat.1)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RepSyncTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    RepSyncLineChart(points: appModel.historyState.points, label: "lbs")
                        .frame(height: 180)

                    HStack {
                        Text("History")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                        Spacer()
                    }

                    ForEach(appModel.historyState.sessions) { session in
                        RepSyncCard(padding: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.dateText)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textPrimary)
                                    Spacer()
                                    Text(session.workoutName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textSecondary)
                                }
                                Text(session.summary)
                                    .font(.system(size: 14))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
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
}
