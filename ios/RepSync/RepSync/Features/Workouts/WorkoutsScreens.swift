import SwiftUI

struct WorkoutsListScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var selectedWorkout: WorkoutListItem?

    private var filteredWorkouts: [WorkoutListItem] {
        let query = appModel.workoutsState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appModel.workoutsState.workouts }
        return appModel.workoutsState.workouts.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RepSyncTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        RepSyncHeaderButton(title: "<") { appModel.pop() }
                        Spacer()
                        Text("Workouts")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(RepSyncTheme.textPrimary)
                        Spacer()
                        Color.clear.frame(width: 40, height: 40)
                    }

                    TextField("Search workouts...", text: $appModel.workoutsState.searchQuery)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(RepSyncTheme.input)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RepSyncTheme.card)

                ScrollView {
                    VStack(spacing: 8) {
                        Spacer().frame(height: 8)
                        if filteredWorkouts.isEmpty {
                            Text(appModel.workoutsState.searchQuery.isEmpty ? "No workouts yet.\nTap + to create one." : "No workouts found")
                                .font(.system(size: 16))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 48)
                        }

                        ForEach(filteredWorkouts) { workout in
                            RepSyncCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(workout.name)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(RepSyncTheme.textPrimary)

                                    Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                                        .font(.system(size: 14))
                                        .foregroundStyle(RepSyncTheme.textSecondary)

                                    if let musicSummary = workout.musicSummary {
                                        Text(musicSummary)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(RepSyncTheme.primaryGreen)
                                            .lineLimit(2)
                                    }

                                    HStack(spacing: 8) {
                                        pillButton("Start", fill: RepSyncTheme.primaryGreen) { appModel.startWorkout(id: workout.id) }
                                        pillButton("Edit", fill: RepSyncTheme.cardElevated) { appModel.showNewWorkout(templateID: workout.id) }
                                        pillButton("Delete", fill: RepSyncTheme.destructive) { appModel.deleteWorkout(id: workout.id) }
                                    }
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                        }
                        Spacer().frame(height: 96)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }

            Button {
                appModel.showNewWorkout()
            } label: {
                Text("+")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(RepSyncTheme.cardElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailSheet(
                workout: workout,
                onStart: { appModel.startWorkout(id: workout.id) },
                onEdit: { appModel.showNewWorkout(templateID: workout.id) },
                onDelete: { appModel.deleteWorkout(id: workout.id) }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func pillButton(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutDetailSheet: View {
    let workout: WorkoutListItem
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                    Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    if let musicSummary = workout.musicSummary {
                        Text(musicSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RepSyncTheme.primaryGreen)
                    }
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textSecondary)
            }

            Divider().overlay(RepSyncTheme.divider)

            if workout.exercises.isEmpty {
                Text("No exercises saved yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(RepSyncTheme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(workout.exercises) { exercise in
                        HStack {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                            Spacer()
                            Text("\(exercise.setCount) set\(exercise.setCount == 1 ? "" : "s")")
                                .font(.system(size: 13))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                pillButton("Start", fill: RepSyncTheme.primaryGreen) {
                    dismiss()
                    onStart()
                }
                pillButton("Edit", fill: RepSyncTheme.cardElevated) {
                    dismiss()
                    onEdit()
                }
                pillButton("Delete", fill: RepSyncTheme.destructive) {
                    dismiss()
                    onDelete()
                }
            }
        }
        .padding(24)
        .background(RepSyncTheme.background)
    }

    private func pillButton(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutEditorScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RepSyncHeaderButton(title: "<") { appModel.pop() }
                Spacer()
                Text(appModel.workoutEditorState.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                Spacer()
                Button("Save") { appModel.saveWorkoutEditor() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(RepSyncTheme.primaryGreen)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RepSyncTheme.card)

            ScrollView {
                VStack(spacing: 12) {
                    RepSyncCard(padding: 20) {
                        HStack {
                            Text("Name:")
                                .font(.system(size: 16))
                                .foregroundStyle(RepSyncTheme.textSecondary)

                            TextField("Push", text: $appModel.workoutEditorState.workoutName)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(RepSyncTheme.textPrimary)
                        }
                    }

                    WorkoutAudioEditorCard()

                    ForEach($appModel.workoutEditorState.exercises) { $exercise in
                        WorkoutExerciseEditorCard(exercise: $exercise)
                    }

                    Button {
                        appModel.addExerciseToEditor()
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

private struct WorkoutAudioEditorCard: View {
    @EnvironmentObject private var appModel: RepSyncAppModel

    private var selectedPlaylistName: String? {
        appModel.workoutEditorState.musicPlaylistName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? appModel.workoutEditorState.musicPlaylistName
            : nil
    }

    private var appleQuickPicks: [MusicQuickPickItem] {
        let library = Array(appModel.appleMusicLibraryPlaylists.prefix(3))
        let libraryIDs = Set(library.map(\.id))
        let recents = appModel.appleMusicRecentItems.filter { !libraryIDs.contains($0.id) }
        return library + Array(recents.prefix(max(0, 3 - library.count)))
    }

    var body: some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout Audio")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)

                if appModel.selectedMusicProvider == .appleMusic {
                    Text("Pick a playlist to keep this workout consistent every time you start it.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)

                    if let selectedPlaylistName {
                        HStack(spacing: 8) {
                            Text(selectedPlaylistName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(RepSyncTheme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Button("Clear") {
                                appModel.clearWorkoutEditorPlaylistSelection()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if appleQuickPicks.isEmpty {
                        Text("Connect Apple Music on the Home or Profile screen to load your recent playlists here.")
                            .font(.system(size: 13))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(appleQuickPicks) { item in
                                Button {
                                    appModel.applyAppleMusicPlaylistToWorkoutEditor(item)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(RepSyncTheme.textPrimary)
                                                .lineLimit(1)
                                            Text(item.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundStyle(RepSyncTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text("Use")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(RepSyncTheme.primaryGreen)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(RepSyncTheme.cardElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if appModel.selectedMusicProvider == .spotify {
                    Text("Paste a Spotify playlist link for this workout. RepSync will open it in Spotify from the home widget.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)

                    TextField(
                        "https://open.spotify.com/playlist/...",
                        text: Binding(
                            get: { appModel.workoutEditorState.musicPlaylistURL ?? "" },
                            set: { appModel.setWorkoutEditorSpotifyURL($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RepSyncTheme.input)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Paste a Spotify playlist link")
                        .font(.system(size: 12))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                } else if appModel.selectedMusicProvider == .youtubeMusic {
                    Text("Paste a YouTube Music playlist link for this workout. RepSync will open it from the home widget.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)

                    TextField(
                        "https://music.youtube.com/playlist?list=...",
                        text: Binding(
                            get: { appModel.workoutEditorState.musicPlaylistURL ?? "" },
                            set: { appModel.setWorkoutEditorYouTubeMusicURL($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RepSyncTheme.input)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("Paste a YouTube Music playlist link")
                        .font(.system(size: 12))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                } else {
                    Text("Choose Apple Music, Spotify, or YouTube Music on the Home or Profile screen to attach a playlist to this workout.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }
            }
        }
    }
}

private struct WorkoutExerciseEditorCard: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @Binding var exercise: WorkoutExerciseDraft

    private var suggestions: [ExerciseSuggestion] {
        let query = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(
            appModel.exerciseSuggestions(for: query)
                .filter { $0.name.caseInsensitiveCompare(query) != .orderedSame }
                .prefix(5)
        )
    }

    var body: some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    TextField("Exercise name", text: $exercise.name)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .onChange(of: exercise.name) { _, _ in
                            appModel.clearEditorSuggestionFlag(for: exercise.id)
                        }

                    Button {
                        appModel.removeEditorExercise(id: exercise.id)
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
                        appModel.applyEditorSuggestion(suggestion, to: exercise.id)
                    }
                }

                Picker("Tracking Type", selection: $exercise.trackingType) {
                    ForEach(ExerciseTrackingKind.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Sets")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    Spacer()
                    Button("-") { exercise.setCount = max(exercise.setCount - 1, 1) }
                        .buttonStyle(.plain)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(Circle())
                    Text("\(exercise.setCount)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 24)
                    Button("+") { exercise.setCount += 1 }
                        .buttonStyle(.plain)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(RepSyncTheme.cardElevated)
                        .clipShape(Circle())
                }
            }
        }
    }
}
