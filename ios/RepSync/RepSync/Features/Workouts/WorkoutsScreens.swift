import SwiftUI

struct WorkoutsListScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var selectedWorkout: WorkoutListItem?
    @State private var workoutToRemove: WorkoutListItem?

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
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(RepSyncTheme.divider.opacity(0.35), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(RepSyncTheme.card)

                List {
                    Section {
                        if filteredWorkouts.isEmpty {
                            Text(appModel.workoutsState.searchQuery.isEmpty ? "No workouts yet." : "No workouts found")
                                .font(.system(size: 16))
                                .foregroundStyle(RepSyncTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        ForEach(Array(filteredWorkouts.enumerated()), id: \.element.id) { index, workout in
                            workoutCard(workout)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .onTapGesture {
                                    selectedWorkout = workout
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        workoutToRemove = workout
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                    .tint(RepSyncTheme.destructive)
                                }
                                .listRowInsets(EdgeInsets(top: index == 0 ? 12 : 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .onMove { source, destination in
                            guard appModel.workoutsState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            appModel.moveWorkouts(fromOffsets: source, toOffset: destination)
                        }

                        if appModel.workoutsState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            addWorkoutCard
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 16, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Remove Workout?", isPresented: Binding(
            get: { workoutToRemove != nil },
            set: { if !$0 { workoutToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                workoutToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let workoutToRemove {
                    appModel.deleteWorkout(id: workoutToRemove.id)
                }
                selectedWorkout = nil
                workoutToRemove = nil
            }
        } message: {
            Text("This workout template will be removed permanently and cannot be undone.")
        }
        .overlay {
            if let selectedWorkout {
                RepSyncCenteredOverlay(onDismiss: { self.selectedWorkout = nil }) {
                    WorkoutDetailSheet(
                        workout: selectedWorkout,
                        onClose: { self.selectedWorkout = nil },
                        onStart: {
                            self.selectedWorkout = nil
                            appModel.startWorkout(id: selectedWorkout.id)
                        },
                        onEdit: {
                            self.selectedWorkout = nil
                            appModel.showNewWorkout(templateID: selectedWorkout.id)
                        }
                    )
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedWorkout?.id)
    }

    private func pillButton(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        let isStartButton = title == "Start"

        return Button(action: action) {
            Text(title)
                .font(.system(size: isStartButton ? 14 : 13, weight: .semibold))
                .foregroundStyle(isStartButton ? RepSyncTheme.primaryGreen : RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .repsyncGlassButtonBackground(isStartButton ? RepSyncTheme.primaryGreen.opacity(0.58) : fill, shape: .roundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func workoutCard(_ workout: WorkoutListItem) -> some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(workout.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textPrimary)

                Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundStyle(RepSyncTheme.textSecondary)

                HStack(spacing: 8) {
                    pillButton("Start", fill: RepSyncTheme.primaryGreen) { appModel.startWorkout(id: workout.id) }
                    pillButton("Edit", fill: RepSyncTheme.cardElevated) { appModel.showNewWorkout(templateID: workout.id) }
                }
            }
        }
    }

    private var addWorkoutCard: some View {
        RepSyncGhostAddCard(title: "Add Workout") {
            appModel.showNewWorkout()
        }
    }
}

private struct WorkoutDetailSheet: View {
    let workout: WorkoutListItem
    let onClose: () -> Void
    let onStart: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                Text("\(workout.exerciseCount) exercise\(workout.exerciseCount == 1 ? "" : "s")")
                    .font(.system(size: 14))
                    .foregroundStyle(RepSyncTheme.textSecondary)
            }
            .padding(.top, 12)

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
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                pillButton("Start", fill: RepSyncTheme.primaryGreen) {
                    onStart()
                }
                pillButton("Edit", fill: RepSyncTheme.cardElevated) {
                    onEdit()
                }
            }
        }
    }

    private func pillButton(_ title: String, fill: Color, action: @escaping () -> Void) -> some View {
        let isStartButton = title == "Start"

        return Button(action: action) {
            Text(title)
                .font(.system(size: isStartButton ? 14 : 13, weight: .semibold))
                .foregroundStyle(isStartButton ? RepSyncTheme.primaryGreen : RepSyncTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .repsyncGlassButtonBackground(isStartButton ? RepSyncTheme.primaryGreen.opacity(0.58) : fill, shape: .roundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutEditorScreen: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var exerciseToRemove: WorkoutExerciseDraft?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RepSyncHeaderButton(title: "<") { appModel.pop() }
                Spacer()
                Text(appModel.workoutEditorState.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                Spacer()
                RepSyncSaveButton { appModel.saveWorkoutEditor() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RepSyncTheme.card)

            List {
                Section {
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
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    ForEach(appModel.workoutEditorState.exercises) { exercise in
                        if let exerciseBinding = binding(for: exercise.id) {
                            WorkoutExerciseEditorCard(exercise: exerciseBinding)
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
                        appModel.moveEditorExercises(fromOffsets: source, toOffset: destination)
                    }

                    RepSyncGhostAddCard(title: "Add Exercise") {
                        appModel.addExerciseToEditor()
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(RepSyncTheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .alert("Remove Exercise?", isPresented: Binding(
            get: { exerciseToRemove != nil },
            set: { if !$0 { exerciseToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                exerciseToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let exerciseToRemove {
                    appModel.removeEditorExercise(id: exerciseToRemove.id)
                }
                exerciseToRemove = nil
            }
        } message: {
            Text("This exercise will be removed from the workout.")
        }
    }

    private func binding(for exerciseID: UUID) -> Binding<WorkoutExerciseDraft>? {
        guard let fallbackExercise = appModel.workoutEditorState.exercises.first(where: { $0.id == exerciseID }) else {
            return nil
        }

        return Binding(
            get: {
                appModel.workoutEditorState.exercises.first(where: { $0.id == exerciseID }) ?? fallbackExercise
            },
            set: { updatedExercise in
                guard let index = appModel.workoutEditorState.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
                appModel.workoutEditorState.exercises[index] = updatedExercise
            }
        )
    }
}

private struct WorkoutAudioEditorCard: View {
    @EnvironmentObject private var appModel: RepSyncAppModel
    @State private var showsAppleMusicPicker = false

    private var selectedPlaylistName: String? {
        appModel.workoutEditorState.musicPlaylistName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? appModel.workoutEditorState.musicPlaylistName
            : nil
    }

    private var hasSpotifyPlaylistLink: Bool {
        appModel.workoutEditorState.musicPlaylistURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var libraryPlaylists: [MusicQuickPickItem] {
        Array(appModel.appleMusicLibraryPlaylists.prefix(3))
    }

    private var recentItems: [MusicQuickPickItem] {
        Array(appModel.appleMusicRecentItems.filter { item in
            !libraryPlaylists.contains(where: { $0.id == item.id })
        }.prefix(3))
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

                    Button(appModel.isRefreshingAppleMusic ? "Refreshing Apple Music..." : "Refresh Apple Music Library") {
                        appModel.refreshAppleMusicConnection()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))

                    Button("Browse All Apple Music Playlists") {
                        showsAppleMusicPicker = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .roundedRectangle(cornerRadius: 10))

                    if let refreshSummary = appModel.appleMusicRefreshSummary,
                       !refreshSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(refreshSummary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    }

                    if let selectedPlaylistName {
                        attachedAudioRow(title: selectedPlaylistName, subtitle: "Apple Music playlist")
                    }

                    if libraryPlaylists.isEmpty && recentItems.isEmpty {
                        Text(appModel.appleMusicDisplayMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(RepSyncTheme.textSecondary)
                    } else {
                        VStack(spacing: 8) {
                            if !libraryPlaylists.isEmpty {
                                Text("Library Playlists")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(libraryPlaylists) { item in
                                    appleMusicPlaylistSelectionRow(item)
                                }
                            }

                            if !recentItems.isEmpty {
                                Text("Recently Played")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(RepSyncTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, libraryPlaylists.isEmpty ? 0 : 4)

                                ForEach(recentItems) { item in
                                    appleMusicPlaylistSelectionRow(item)
                                }
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

                    if hasSpotifyPlaylistLink {
                        attachedAudioRow(title: "Spotify Playlist", subtitle: "Attached to this workout")
                    }
                } else {
                    Text("Choose Apple Music or Spotify on the Home or Profile screen to attach a playlist to this workout.")
                        .font(.system(size: 14))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showsAppleMusicPicker) {
            AppleMusicPlaylistPickerSheet(
                items: appModel.allAppleMusicBrowseItems,
                onRefresh: { appModel.refreshAppleMusicConnection() },
                onSelect: { item in
                    appModel.applyAppleMusicPlaylistToWorkoutEditor(item)
                    showsAppleMusicPicker = false
                }
            )
            .environmentObject(appModel)
            .presentationDetents([.large])
        }
    }

    private func attachedAudioRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RepSyncTheme.primaryGreen)
                .frame(width: 30, height: 30)
                .background(RepSyncTheme.primaryGreen.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RepSyncTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Button("Disconnect") {
                appModel.disconnectWorkoutEditorAudio()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(RepSyncTheme.destructive)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RepSyncTheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
        )
    }

    private func appleMusicPlaylistSelectionRow(_ item: MusicQuickPickItem) -> some View {
        let isSelected = appModel.workoutEditorState.musicPlaylistID == item.id

        return Button {
            appModel.applyAppleMusicPlaylistToWorkoutEditor(item)
        } label: {
            HStack(spacing: 12) {
                workoutPlaylistArtwork(url: item.artworkURL)

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
                Text(isSelected ? "Selected" : "Use")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? RepSyncTheme.textOnLight : RepSyncTheme.primaryGreen)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? RepSyncTheme.primaryGreen : RepSyncTheme.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? RepSyncTheme.primaryGreen.opacity(0.55) : RepSyncTheme.divider.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                            appModel.resolveEditorExerciseName(for: exercise.id)
                        }

                    Spacer(minLength: 8)

                    trackingTypeMenu
                }

                if !suggestions.isEmpty {
                    RepSyncSuggestionList(suggestions: suggestions) { suggestion in
                        appModel.applyEditorSuggestion(suggestion, to: exercise.id)
                    }
                }

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
                        .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .circle)
                    Text("\(exercise.setCount)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 24)
                    Button("+") { exercise.setCount += 1 }
                        .buttonStyle(.plain)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                        .frame(width: 28, height: 28)
                        .repsyncGlassButtonBackground(RepSyncTheme.cardElevated, shape: .circle)
                }
            }
        }
    }

    private var trackingTypeMenu: some View {
        Menu {
            ForEach(ExerciseTrackingKind.allCases) { type in
                Button(type.displayName) {
                    exercise.trackingType = type
                }
            }
        } label: {
            RepSyncExerciseTypeBadge(trackingType: exercise.trackingType)
        }
    }
}

private struct WorkoutExerciseDragPreview: View {
    let exercise: WorkoutExerciseDraft

    var body: some View {
        RepSyncCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Exercise" : exercise.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                RepSyncExerciseTypeBadge(trackingType: exercise.trackingType)

                HStack {
                    Text("Sets")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RepSyncTheme.textSecondary)
                    Spacer()
                    Text("\(exercise.setCount)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(RepSyncTheme.textPrimary)
                }
            }
        }
    }
}

private struct WorkoutPlaylistArtwork: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(RepSyncTheme.card)
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RepSyncTheme.textSecondary)
            )
    }
}

private func workoutPlaylistArtwork(url: URL?) -> some View {
    WorkoutPlaylistArtwork(url: url)
}
