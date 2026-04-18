import SwiftUI

struct DayViewScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var templateSourceWorkoutID: UUID?
    @State private var templateName = ""

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
                                        HStack {
                                            Text(exercise.name)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(RepSyncTheme.textPrimary)
                                            Spacer()
                                            Text(exercise.summary)
                                                .font(.system(size: 14))
                                                .foregroundStyle(RepSyncTheme.textSecondary)
                                                .multilineTextAlignment(.trailing)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }

                                HStack(spacing: 8) {
                                    actionPill("Copy", fill: RepSyncTheme.cardElevated) { appModel.copyCompletedWorkoutToTemplate(id: workout.id) }
                                    actionPill("Template", fill: RepSyncTheme.cardElevated) {
                                        templateSourceWorkoutID = workout.id
                                        templateName = workout.title
                                    }
                                    actionPill("Remove", fill: RepSyncTheme.destructive) { appModel.deleteCompletedWorkout(id: workout.id) }
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
