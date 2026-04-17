import Combine
import CoreData
import Foundation
import UIKit
import SwiftUI
import MusicKit
import MediaPlayer
@preconcurrency import UserNotifications

@MainActor
final class RepSyncAppModel: ObservableObject {
    @Published var selectedTab: RepSyncTab = .home
    @Published var navigationPath: [RepSyncRoute] = []
    @Published var activeWorkoutBanner: ActiveWorkoutBannerModel?
    @Published var cloudKitMessage: String

    @Published var homeState: HomeScreenState
    @Published var workoutsState = WorkoutsScreenState()
    @Published var activeWorkoutState: ActiveWorkoutScreenState?
    @Published var dayViewState = DayViewScreenState(selectedDate: Date())
    @Published var historyState = ExerciseHistoryScreenState()
    @Published var profileState = ProfileScreenState()
    @Published var bodyweightEntriesState = BodyweightEntriesScreenState()
    @Published var workoutEditorState = WorkoutEditorScreenState()

    @Published var profileDraftName = ""
    @Published var profileDraftAvatarPath: String?
    @Published var profileDraftWorkoutDays: Set<WorkoutWeekday> = []
    @Published var profileDraftReminderEnabled = false
    @Published var profileDraftReminderHour = 18
    @Published var profileDraftReminderMinute = 0
    @Published var profileDraftReminderMessage = "Time to train"
    @Published var selectedMusicProvider: MusicProvider?
    @Published var hasDismissedMusicPrompt = false
    @Published var showsMusicProviderPicker = false
    @Published var appleMusicStatusText = "Not connected"
    @Published var appleMusicCanPlayCatalog = false
    @Published var musicNowPlaying: MusicNowPlayingModel?
    @Published var isAppleMusicPlaying = false
    @Published var musicMessage: String?
    @Published var appleMusicRecentItems: [MusicQuickPickItem] = []
    @Published var appleMusicLibraryPlaylists: [MusicQuickPickItem] = []
    @Published var newBodyweightValue = ""
    @Published var showsAddBodyweightSheet = false
    @Published var deletingBodyweight: BodyweightEntryModel?
    @Published var editingBodyweight: BodyweightEntryModel?
    @Published var editingBodyweightValue = ""
    @Published var editingBodyweightDate = Date()
    @Published var showsBodyweightFilterSheet = false
    @Published var bodyweightFilterStartDate = Calendar.repsync.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @Published var bodyweightFilterEndDate = Date()

    private let store: RepSyncStore
    private var timerCancellable: AnyCancellable?
    private var musicCancellables: Set<AnyCancellable> = []
    private var monthCursor = Calendar.repsync.startOfDay(for: Date())
    private var selectedTemplateID: UUID?
    private var selectedExerciseName = ""

    init(context: NSManagedObjectContext) {
        self.store = RepSyncStore(context: context)
        self.homeState = HomeScreenState(currentMonth: monthCursor, calendarDays: [])
        cloudKitMessage = CloudKitReadinessService.isICloudAvailable
            ? "iCloud is available on this device. Local data remains primary, and the store is ready for CloudKit container wiring in Xcode."
            : "Local data stays primary. CloudKit continuity will be enabled after the iCloud container identifier is configured in Xcode."
        configureMusicObservers()
        loadMusicPreferences()
        refreshAll()
    }

    var showsBottomBar: Bool {
        navigationPath.isEmpty
    }

    var isOnActiveWorkoutScreen: Bool {
        navigationPath.last == .activeWorkout
    }

    var shouldShowMusicWidget: Bool {
        selectedMusicProvider != nil || !hasDismissedMusicPrompt
    }

    var shouldShowMusicConnectPrompt: Bool {
        selectedMusicProvider == nil && !hasDismissedMusicPrompt
    }

    func refreshAll() {
        do {
            workoutsState.workouts = try store.fetchWorkoutTemplates().compactMap { template in
                guard let id = template.id else { return nil }
                let exerciseCount = (try? store.fetchTemplateExercises(templateID: id).count) ?? 0
                let musicPreferences = try? store.workoutMusicPreferences(for: id)
                let musicSummary = musicSummary(
                    providerRawValue: musicPreferences?.provider,
                    playlistName: musicPreferences?.playlistName
                )
                return WorkoutListItem(
                    id: id,
                    name: template.name ?? "Workout",
                    exerciseCount: exerciseCount,
                    musicSummary: musicSummary
                )
            }
            profileState = try store.makeProfileState()
            let latestBodyweightState = try store.makeBodyweightEntriesState()
            bodyweightEntriesState.entries = latestBodyweightState.entries
            if let startDate = bodyweightEntriesState.startDate, let endDate = bodyweightEntriesState.endDate {
                bodyweightEntriesState.filteredEntries = latestBodyweightState.entries.filter { entry in
                    let entryDate = Calendar.repsync.startOfDay(for: entry.date)
                    return entryDate >= startDate && entryDate <= endDate
                }
            } else {
                bodyweightEntriesState.filteredEntries = latestBodyweightState.entries
            }
            homeState = try store.makeHomeState(month: monthCursor)
            if navigationPath.contains(.dayView) {
                dayViewState = try store.makeDayViewState(for: dayViewState.selectedDate)
            }
            if navigationPath.contains(.exerciseHistory), !selectedExerciseName.isEmpty {
                historyState = try store.makeExerciseHistoryState(for: selectedExerciseName)
            }
            activeWorkoutBanner = activeWorkoutState.map { ActiveWorkoutBannerModel(workoutName: $0.workoutName, elapsedText: $0.elapsedText) }
        } catch {
            print("RepSync refresh failed: \(error)")
        }
    }

    func showWorkouts() {
        refreshAll()
        navigationPath.append(.workouts)
    }

    func showQuickWorkout() {
        if activeWorkoutState != nil {
            resumeActiveWorkout()
            return
        }
        activeWorkoutState = ActiveWorkoutScreenState(
            templateID: nil,
            isQuickWorkout: true,
            workoutName: "Quick Workout",
            startedAt: Date(),
            elapsedText: "0:00",
            exercises: []
        )
        startTimer()
        navigationPath.append(.activeWorkout)
        activeWorkoutBanner = nil
    }

    func showNewWorkout(templateID: UUID? = nil) {
        selectedTemplateID = templateID
        if let templateID, let state = try? makeWorkoutEditorState(id: templateID) {
            workoutEditorState = state
        } else {
            workoutEditorState = WorkoutEditorScreenState(
                templateID: nil,
                title: "New Workout",
                workoutName: "",
                exercises: [],
                musicProvider: selectedMusicProvider
            )
        }
        navigationPath.append(.workoutEditor)
    }

    func showDayView(for date: Date) {
        dayViewState.selectedDate = date
        if let state = try? store.makeDayViewState(for: date) {
            dayViewState = state
        }
        navigationPath.append(.dayView)
    }

    func showExerciseHistory(_ name: String) {
        selectedExerciseName = name
        if let state = try? store.makeExerciseHistoryState(for: name) {
            historyState = state
        }
        navigationPath.append(.exerciseHistory)
    }

    func showBodyweightEntries() {
        refreshAll()
        navigationPath.append(.bodyweightEntries)
    }

    func showEditProfile() {
        profileDraftName = profileState.displayName == "Guest" ? "" : profileState.displayName
        profileDraftAvatarPath = profileState.avatarPath
        profileDraftWorkoutDays = profileState.workoutDays
        profileDraftReminderEnabled = profileState.reminderEnabled
        profileDraftReminderHour = profileState.reminderHour
        profileDraftReminderMinute = profileState.reminderMinute
        profileDraftReminderMessage = profileState.reminderMessage
        navigationPath.append(.editProfile)
    }

    func pop() {
        if navigationPath.last == .activeWorkout, activeWorkoutState != nil {
            cancelActiveWorkout()
        } else if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func saveWorkoutEditor() {
        let cleanedExercises = workoutEditorState.exercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !workoutEditorState.workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !cleanedExercises.isEmpty else { return }
        do {
            let templateID = try store.upsertWorkoutTemplate(
                id: workoutEditorState.templateID,
                name: workoutEditorState.workoutName,
                exercises: cleanedExercises
            )
            try store.setWorkoutMusicPreferences(
                templateID: templateID,
                provider: workoutEditorState.musicProvider?.rawValue,
                playlistID: normalizedString(workoutEditorState.musicPlaylistID),
                playlistName: normalizedString(workoutEditorState.musicPlaylistName),
                playlistURL: normalizedString(workoutEditorState.musicPlaylistURL)
            )
            navigationPath.removeLast()
            refreshAll()
        } catch {
            print("Failed to save workout template: \(error)")
        }
    }

    func deleteWorkout(id: UUID) {
        do {
            try store.deleteWorkoutTemplate(id: id)
            refreshAll()
        } catch {
            print("Failed to delete workout: \(error)")
        }
    }

    func startWorkout(id: UUID) {
        if activeWorkoutState != nil {
            resumeActiveWorkout()
            return
        }
        guard let template = try? store.fetchWorkoutTemplate(id: id) else { return }
        let templateExercises = (try? store.fetchTemplateExercises(templateID: id)) ?? []
        let musicPreferences = try? store.workoutMusicPreferences(for: id)
        let exercises = templateExercises.map { exercise in
            let tracking = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            let count = max(Int(exercise.setCount), 1)
            let sets = (1...count).map { index in
                ActiveSetDraft(setNumber: index, previous: (try? store.latestPreviousSummary(for: exercise.name ?? "", setNumber: index)) ?? "")
            }
            return ActiveExerciseDraft(name: exercise.name ?? "", trackingType: tracking, sets: sets, isSuggestedExercise: true, isTrackingTypeLocked: true)
        }
        activeWorkoutState = ActiveWorkoutScreenState(
            templateID: id,
            isQuickWorkout: false,
            workoutName: template.name ?? "Workout",
            startedAt: Date(),
            elapsedText: "0:00",
            exercises: exercises,
            musicProvider: musicPreferences?.provider.flatMap(MusicProvider.init(rawValue:)),
            musicPlaylistID: musicPreferences?.playlistID,
            musicPlaylistName: musicPreferences?.playlistName,
            musicPlaylistURL: musicPreferences?.playlistURL
        )
        startTimer()
        navigationPath.append(.activeWorkout)
        activeWorkoutBanner = nil
    }

    func finishActiveWorkout() {
        guard let activeWorkoutState else { return }
        do {
            try store.saveCompletedWorkout(from: activeWorkoutState)
            closeActiveWorkout(popNavigation: true)
            refreshAll()
        } catch {
            print("Failed to finish workout: \(error)")
        }
    }

    func cancelActiveWorkout(popNavigation: Bool = true) {
        closeActiveWorkout(popNavigation: popNavigation)
    }

    private func closeActiveWorkout(popNavigation: Bool) {
        timerCancellable?.cancel()
        timerCancellable = nil

        if popNavigation, navigationPath.last == .activeWorkout {
            navigationPath.removeLast()
        }

        activeWorkoutBanner = nil
        Task { @MainActor [weak self] in
            self?.activeWorkoutState = nil
        }
    }

    func resumeActiveWorkout() {
        guard activeWorkoutState != nil else { return }
        if navigationPath.last != .activeWorkout {
            navigationPath.append(.activeWorkout)
        }
        activeWorkoutBanner = nil
    }

    func leaveActiveWorkoutOpen() {
        guard activeWorkoutState != nil else { return }
        if navigationPath.last == .activeWorkout {
            navigationPath.removeLast()
        }
        refreshBanner()
    }

    func saveProfile() {
        do {
            if let existingAvatarPath = profileState.avatarPath,
               existingAvatarPath != profileDraftAvatarPath {
                try? FileManager.default.removeItem(atPath: existingAvatarPath)
            }
            try store.upsertProfile(
                displayName: profileDraftName,
                avatarPath: profileDraftAvatarPath,
                workoutDays: profileDraftWorkoutDays,
                reminderEnabled: profileDraftReminderEnabled,
                reminderHour: profileDraftReminderHour,
                reminderMinute: profileDraftReminderMinute,
                reminderMessage: profileDraftReminderMessage
            )
            scheduleWorkoutRemindersIfNeeded()
            refreshAll()
            navigationPath.removeLast()
        } catch {
            print("Failed to save profile: \(error)")
        }
    }

    func addBodyweight() {
        guard let value = Double(newBodyweightValue), value > 0 else { return }
        do {
            try store.addBodyweightEntry(weight: value)
            newBodyweightValue = ""
            showsAddBodyweightSheet = false
            refreshAll()
        } catch {
            print("Failed to add bodyweight: \(error)")
        }
    }

    func showAddBodyweightSheet() {
        newBodyweightValue = ""
        showsAddBodyweightSheet = true
    }

    func dismissAddBodyweightSheet() {
        showsAddBodyweightSheet = false
        newBodyweightValue = ""
    }

    func beginEditBodyweight(_ entry: BodyweightEntryModel) {
        editingBodyweight = entry
        editingBodyweightValue = formatWeight(entry.value)
        editingBodyweightDate = entry.date
    }

    func saveEditedBodyweight() {
        guard let editingBodyweight, let value = Double(editingBodyweightValue), value > 0 else { return }
        do {
            try store.updateBodyweightEntry(id: editingBodyweight.id, weight: value, on: editingBodyweightDate)
            self.editingBodyweight = nil
            editingBodyweightValue = ""
            editingBodyweightDate = Date()
            refreshAll()
        } catch {
            print("Failed to update bodyweight: \(error)")
        }
    }

    func deleteBodyweight(_ entry: BodyweightEntryModel) {
        do {
            try store.deleteBodyweightEntry(id: entry.id)
            if editingBodyweight?.id == entry.id {
                editingBodyweight = nil
                editingBodyweightValue = ""
                editingBodyweightDate = Date()
            }
            if deletingBodyweight?.id == entry.id {
                deletingBodyweight = nil
            }
            refreshAll()
        } catch {
            print("Failed to delete bodyweight: \(error)")
        }
    }

    func confirmDeleteBodyweight(_ entry: BodyweightEntryModel) {
        deletingBodyweight = entry
    }

    func dismissDeleteBodyweightConfirmation() {
        deletingBodyweight = nil
    }

    func previousMonth() {
        monthCursor = Calendar.repsync.date(byAdding: .month, value: -1, to: monthCursor) ?? monthCursor
        refreshAll()
    }

    func nextMonth() {
        monthCursor = Calendar.repsync.date(byAdding: .month, value: 1, to: monthCursor) ?? monthCursor
        refreshAll()
    }

    func addExerciseToEditor() {
        workoutEditorState.exercises.append(WorkoutExerciseDraft())
    }

    func removeEditorExercise(id: UUID) {
        workoutEditorState.exercises.removeAll { $0.id == id }
    }

    func addExerciseToActiveWorkout() {
        activeWorkoutState?.exercises.append(ActiveExerciseDraft())
        refreshBanner()
    }

    func removeActiveExercise(id: UUID) {
        activeWorkoutState?.exercises.removeAll { $0.id == id }
        refreshBanner()
    }

    func addSet(to exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextNumber = (activeWorkoutState?.exercises[index].sets.count ?? 0) + 1
        let name = activeWorkoutState?.exercises[index].name ?? ""
        let previous = (try? store.latestPreviousSummary(for: name, setNumber: nextNumber)) ?? ""
        activeWorkoutState?.exercises[index].sets.append(ActiveSetDraft(setNumber: nextNumber, previous: previous))
        refreshBanner()
    }

    func exerciseSuggestions(for query: String) -> [ExerciseSuggestion] {
        (try? store.exerciseSuggestions(matching: query)) ?? []
    }

    func applyEditorSuggestion(_ suggestion: ExerciseSuggestion, to exerciseID: UUID) {
        guard let index = workoutEditorState.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        workoutEditorState.exercises[index].name = suggestion.name
        workoutEditorState.exercises[index].trackingType = suggestion.trackingType
        workoutEditorState.exercises[index].isSuggestedExercise = true
    }

    func clearEditorSuggestionFlag(for exerciseID: UUID) {
        guard let index = workoutEditorState.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        workoutEditorState.exercises[index].isSuggestedExercise = false
    }

    func applyActiveSuggestion(_ suggestion: ExerciseSuggestion, to exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let existingSetCount = max(activeWorkoutState?.exercises[index].sets.count ?? 1, 1)
        let sets = (try? store.makeActiveSetDrafts(for: suggestion.name, count: existingSetCount)) ?? [ActiveSetDraft(setNumber: 1)]
        activeWorkoutState?.exercises[index].name = suggestion.name
        activeWorkoutState?.exercises[index].trackingType = suggestion.trackingType
        activeWorkoutState?.exercises[index].sets = sets
        activeWorkoutState?.exercises[index].isSuggestedExercise = true
        activeWorkoutState?.exercises[index].isTrackingTypeLocked = true
        refreshBanner()
    }

    func clearActiveSuggestionFlag(for exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        activeWorkoutState?.exercises[index].isSuggestedExercise = false
    }

    func lockTrackingType(_ trackingType: ExerciseTrackingKind, for exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        activeWorkoutState?.exercises[index].trackingType = trackingType
        activeWorkoutState?.exercises[index].isTrackingTypeLocked = true
    }

    func finishWorkoutWarningMessage() -> String? {
        guard let activeWorkoutState else { return nil }

        let incompleteExercises = activeWorkoutState.exercises.filter { exercise in
            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return false }
            return exercise.sets.contains { set in
                !set.isComplete || setIsMissingRequiredValues(set, trackingType: exercise.trackingType)
            }
        }

        guard !incompleteExercises.isEmpty else { return nil }

        return "Some sets are still unchecked or missing values. Review the workout before saving, or finish anyway if you intend to leave them incomplete."
    }

    func activeWorkoutHasNamedExercises() -> Bool {
        guard let activeWorkoutState else { return false }
        return activeWorkoutState.exercises.contains { exercise in
            !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func activeWorkoutHasCompletedSets() -> Bool {
        guard let activeWorkoutState else { return false }
        return activeWorkoutState.exercises.contains { exercise in
            let trimmedName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return false }
            return exercise.sets.contains(where: \.isComplete)
        }
    }

    func hasActiveWorkoutToDiscard() -> Bool {
        guard let activeWorkoutState else { return false }
        if !activeWorkoutState.workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           activeWorkoutState.workoutName != "Quick Workout" {
            return true
        }

        return activeWorkoutState.exercises.contains { exercise in
            if !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            return exercise.sets.contains { set in
                set.isComplete ||
                !set.weight.isEmpty ||
                !set.reps.isEmpty ||
                !set.minutes.isEmpty ||
                !set.seconds.isEmpty ||
                !set.distance.isEmpty ||
                !set.speed.isEmpty
            }
        }
    }

    func saveProfileAvatarData(_ data: Data) {
        guard UIImage(data: data) != nil else { return }
        do {
            if let previousDraft = profileDraftAvatarPath,
               previousDraft != profileState.avatarPath {
                try? FileManager.default.removeItem(atPath: previousDraft)
            }
            let path = try writeProfileAvatar(data)
            profileDraftAvatarPath = path
        } catch {
            print("Failed to save avatar image: \(error)")
        }
    }

    func removeProfileAvatar() {
        profileDraftAvatarPath = nil
    }

    func toggleProfileWorkoutDay(_ day: WorkoutWeekday) {
        if profileDraftWorkoutDays.contains(day) {
            profileDraftWorkoutDays.remove(day)
        } else {
            profileDraftWorkoutDays.insert(day)
        }
    }

    func updateProfileReminderTime(_ date: Date) {
        let components = Calendar.repsync.dateComponents([.hour, .minute], from: date)
        profileDraftReminderHour = components.hour ?? profileDraftReminderHour
        profileDraftReminderMinute = components.minute ?? profileDraftReminderMinute
    }

    func profileReminderTimeDate() -> Date {
        Calendar.repsync.date(from: DateComponents(hour: profileDraftReminderHour, minute: profileDraftReminderMinute)) ?? Date()
    }

    func showBodyweightFilter() {
        if let startDate = bodyweightEntriesState.startDate {
            bodyweightFilterStartDate = startDate
        } else if let earliest = bodyweightEntriesState.entries.last?.date {
            bodyweightFilterStartDate = earliest
        }

        if let endDate = bodyweightEntriesState.endDate {
            bodyweightFilterEndDate = endDate
        } else {
            bodyweightFilterEndDate = bodyweightEntriesState.entries.first?.date ?? Date()
        }
        showsBodyweightFilterSheet = true
    }

    func dismissBodyweightFilter() {
        showsBodyweightFilterSheet = false
    }

    func applyBodyweightFilter() {
        let start = Calendar.repsync.startOfDay(for: min(bodyweightFilterStartDate, bodyweightFilterEndDate))
        let end = Calendar.repsync.startOfDay(for: max(bodyweightFilterStartDate, bodyweightFilterEndDate))
        bodyweightEntriesState.startDate = start
        bodyweightEntriesState.endDate = end
        bodyweightEntriesState.filteredEntries = bodyweightEntriesState.entries.filter { entry in
            let entryDate = Calendar.repsync.startOfDay(for: entry.date)
            return entryDate >= start && entryDate <= end
        }
        showsBodyweightFilterSheet = false
    }

    func clearBodyweightFilter() {
        bodyweightEntriesState.startDate = nil
        bodyweightEntriesState.endDate = nil
        bodyweightEntriesState.filteredEntries = bodyweightEntriesState.entries
        showsBodyweightFilterSheet = false
    }

    func dismissMusicPrompt() {
        hasDismissedMusicPrompt = true
        do {
            try store.setBoolPreference(true, for: musicPromptDismissedKey)
        } catch {
            print("Failed to persist music prompt dismissal: \(error)")
        }
    }

    func showMusicProviderPicker() {
        showsMusicProviderPicker = true
    }

    func selectMusicProvider(_ provider: MusicProvider) {
        selectedMusicProvider = provider
        hasDismissedMusicPrompt = false
        showsMusicProviderPicker = false
        do {
            try store.setStringPreference(provider.rawValue, for: musicProviderKey)
            try store.setBoolPreference(false, for: musicPromptDismissedKey)
        } catch {
            print("Failed to persist music provider selection: \(error)")
        }

        switch provider {
        case .appleMusic:
            Task {
                await connectAppleMusic()
            }
        case .spotify:
            appleMusicCanPlayCatalog = false
            musicNowPlaying = nil
            isAppleMusicPlaying = false
            appleMusicRecentItems = []
            appleMusicLibraryPlaylists = []
            appleMusicStatusText = "Spotify selected"
            musicMessage = "Spotify is set as your workout audio provider. RepSync can open playlists in Spotify while the full SDK bridge is still pending."
        case .youtubeMusic:
            appleMusicCanPlayCatalog = false
            musicNowPlaying = nil
            isAppleMusicPlaying = false
            appleMusicRecentItems = []
            appleMusicLibraryPlaylists = []
            appleMusicStatusText = "YouTube Music selected"
            musicMessage = "YouTube Music is set as your workout audio provider. RepSync can open playlists in YouTube Music while deeper integration is still a URL bridge."
        }
    }

    func connectAppleMusic() async {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            appleMusicStatusText = "Apple Music access was not granted."
            appleMusicCanPlayCatalog = false
            musicNowPlaying = nil
            isAppleMusicPlaying = false
            musicMessage = "Grant Apple Music access in Settings to use playback controls here."
            return
        }

        do {
            let subscription = try await MusicSubscription.current
            appleMusicCanPlayCatalog = subscription.canPlayCatalogContent
            if subscription.canPlayCatalogContent {
                appleMusicStatusText = "Apple Music connected"
                musicMessage = nil
            } else if subscription.canBecomeSubscriber {
                appleMusicStatusText = "Apple Music connected, but no playback subscription was detected."
                musicMessage = "You can authorize the app now and finish subscription setup later in the Music app."
            } else {
                appleMusicStatusText = "Apple Music connected with limited playback access."
                musicMessage = "Playback controls may be unavailable until Apple Music access is fully available on this device."
            }
            await refreshAppleMusicQuickPicks()
        } catch {
            appleMusicCanPlayCatalog = false
            appleMusicStatusText = "Apple Music connected, but subscription status could not be verified."
            musicMessage = "RepSync can still try to show playback controls, but catalog playback may be limited."
            appleMusicRecentItems = []
            appleMusicLibraryPlaylists = []
        }
        refreshAppleMusicNowPlaying()
    }

    func toggleAppleMusicPlayback() {
        if isRunningInSimulator {
            musicMessage = "Apple Music playback controls are unavailable in the iOS Simulator. Use a physical device to test playback."
            return
        }
        let player = MPMusicPlayerController.systemMusicPlayer
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
        refreshAppleMusicNowPlaying()
    }

    func skipAppleMusicTrack() {
        if isRunningInSimulator {
            musicMessage = "Apple Music playback controls are unavailable in the iOS Simulator. Use a physical device to test playback."
            return
        }
        MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
        refreshAppleMusicNowPlaying()
    }

    func openAppleMusicApp() {
        if isRunningInSimulator {
            musicMessage = "The Music app cannot be opened from the iOS Simulator. Test this action on a physical device."
            return
        }
        guard let url = URL(string: "music://") else { return }
        guard UIApplication.shared.canOpenURL(url) else {
            musicMessage = "The Music app is not available on this device."
            return
        }
        UIApplication.shared.open(url)
    }

    func playAppleMusicQuickPick(_ item: MusicQuickPickItem) {
        Task {
            do {
                let playlist = try await appleMusicPlaylist(id: item.id)
                let player = ApplicationMusicPlayer.shared
                player.queue = ApplicationMusicPlayer.Queue(arrayLiteral: playlist)
                try await player.play()
                refreshAppleMusicNowPlaying()
            } catch {
                musicMessage = "RepSync could not start that playlist. Open it in Music and try again."
            }
        }
    }

    func applyAppleMusicPlaylistToWorkoutEditor(_ item: MusicQuickPickItem) {
        workoutEditorState.musicProvider = .appleMusic
        workoutEditorState.musicPlaylistID = item.id
        workoutEditorState.musicPlaylistName = item.title
        workoutEditorState.musicPlaylistURL = nil
    }

    func clearWorkoutEditorPlaylistSelection() {
        workoutEditorState.musicPlaylistID = nil
        workoutEditorState.musicPlaylistName = nil
        workoutEditorState.musicPlaylistURL = nil
        workoutEditorState.musicProvider = selectedMusicProvider
    }

    func setWorkoutEditorSpotifyURL(_ urlString: String) {
        workoutEditorState.musicProvider = .spotify
        workoutEditorState.musicPlaylistURL = urlString
        workoutEditorState.musicPlaylistID = nil
        if workoutEditorState.musicPlaylistName?.isEmpty ?? true {
            workoutEditorState.musicPlaylistName = "Spotify Playlist"
        }
    }

    func setWorkoutEditorYouTubeMusicURL(_ urlString: String) {
        workoutEditorState.musicProvider = .youtubeMusic
        workoutEditorState.musicPlaylistURL = urlString
        workoutEditorState.musicPlaylistID = nil
        if workoutEditorState.musicPlaylistName?.isEmpty ?? true {
            workoutEditorState.musicPlaylistName = "YouTube Music Playlist"
        }
    }

    func playCurrentWorkoutMix() {
        guard let activeWorkoutState else { return }

        switch activeWorkoutState.musicProvider {
        case .appleMusic:
            guard let playlistID = normalizedString(activeWorkoutState.musicPlaylistID),
                  let playlistName = normalizedString(activeWorkoutState.musicPlaylistName) else {
                openAppleMusicApp()
                return
            }
            playAppleMusicQuickPick(
                MusicQuickPickItem(
                    id: playlistID,
                    title: playlistName,
                    subtitle: activeWorkoutState.workoutName,
                    artworkURL: nil
                )
            )
        case .spotify:
            if let playlistURL = normalizedString(activeWorkoutState.musicPlaylistURL) {
                openSpotifyURL(playlistURL)
            } else {
                openSpotifyApp()
            }
        case .youtubeMusic:
            if let playlistURL = normalizedString(activeWorkoutState.musicPlaylistURL) {
                openYouTubeMusicURL(playlistURL)
            } else {
                openYouTubeMusicApp()
            }
        case nil:
            break
        }
    }

    func openSpotifyApp() {
        if let url = URL(string: "spotify://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://open.spotify.com") {
            UIApplication.shared.open(webURL)
        }
    }

    func openSpotifyURL(_ urlString: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            openSpotifyApp()
            return
        }
        UIApplication.shared.open(url)
    }

    func openYouTubeMusicApp() {
        if let webURL = URL(string: "https://music.youtube.com") {
            UIApplication.shared.open(webURL)
        }
    }

    func openYouTubeMusicURL(_ urlString: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            openYouTubeMusicApp()
            return
        }
        UIApplication.shared.open(url)
    }

    func copyCompletedWorkoutToTemplate(id: UUID) {
        do {
            try store.createTemplateCopy(from: id)
            refreshAll()
        } catch {
            print("Failed to copy workout to template: \(error)")
        }
    }

    func deleteCompletedWorkout(id: UUID) {
        do {
            try store.deleteCompletedWorkout(id: id)
            dayViewState = (try? store.makeDayViewState(for: dayViewState.selectedDate)) ?? dayViewState
            refreshAll()
        } catch {
            print("Failed to delete completed workout: \(error)")
        }
    }

    private func makeWorkoutEditorState(id: UUID) throws -> WorkoutEditorScreenState {
        guard let template = try store.fetchWorkoutTemplate(id: id) else {
            return WorkoutEditorScreenState()
        }
        let musicPreferences = try store.workoutMusicPreferences(for: id)
        let exercises = try store.fetchTemplateExercises(templateID: id).map {
            WorkoutExerciseDraft(
                name: $0.name ?? "",
                setCount: max(Int($0.setCount), 1),
                trackingType: ExerciseTrackingKind(rawValue: $0.trackingType ?? "") ?? .weightReps
            )
        }
        return WorkoutEditorScreenState(
            templateID: id,
            title: "Edit Workout",
            workoutName: template.name ?? "",
            exercises: exercises,
            musicProvider: musicPreferences.provider.flatMap(MusicProvider.init(rawValue:)),
            musicPlaylistID: musicPreferences.playlistID,
            musicPlaylistName: musicPreferences.playlistName,
            musicPlaylistURL: musicPreferences.playlistURL
        )
    }

    private func startTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard var state = self.activeWorkoutState else { return }
                state.elapsedText = formatElapsedTime(from: state.startedAt)
                self.activeWorkoutState = state
                self.refreshBanner()
            }
        refreshBanner()
    }

    private func refreshBanner() {
        activeWorkoutBanner = activeWorkoutState.map { ActiveWorkoutBannerModel(workoutName: $0.workoutName, elapsedText: $0.elapsedText) }
    }

    private func setIsMissingRequiredValues(_ set: ActiveSetDraft, trackingType: ExerciseTrackingKind) -> Bool {
        switch trackingType {
        case .weightReps:
            return set.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                set.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .duration:
            let totalSeconds = (Int(set.minutes) ?? 0) * 60 + (Int(set.seconds) ?? 0)
            return totalSeconds <= 0
        case .durationDistance:
            let totalSeconds = (Int(set.minutes) ?? 0) * 60 + (Int(set.seconds) ?? 0)
            let distance = Double(set.distance) ?? 0
            return totalSeconds <= 0 || distance <= 0
        }
    }

    private func writeProfileAvatar(_ data: Data) throws -> String {
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("RepSync", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let fileURL = directory.appendingPathComponent("profile-avatar-\(UUID().uuidString).jpg")
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    private func loadMusicPreferences() {
        do {
            if let providerRawValue = try store.stringPreference(for: musicProviderKey) {
                selectedMusicProvider = MusicProvider(rawValue: providerRawValue)
            }
            hasDismissedMusicPrompt = try store.boolPreference(for: musicPromptDismissedKey) ?? false
        } catch {
            print("Failed to load music preferences: \(error)")
        }

        if selectedMusicProvider == .appleMusic {
            Task {
                await connectAppleMusic()
            }
        } else if selectedMusicProvider == .spotify {
            appleMusicStatusText = "Spotify selected"
            musicMessage = "Spotify is set as your workout audio provider. RepSync can open playlists in Spotify while the full SDK bridge is still pending."
        } else if selectedMusicProvider == .youtubeMusic {
            appleMusicStatusText = "YouTube Music selected"
            musicMessage = "YouTube Music is set as your workout audio provider. RepSync can open playlists in YouTube Music while deeper integration is still a URL bridge."
        }
    }

    private func configureMusicObservers() {
        let player = MPMusicPlayerController.systemMusicPlayer
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
            .merge(with: NotificationCenter.default.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange, object: player))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshAppleMusicNowPlaying()
            }
            .store(in: &musicCancellables)
    }

    private func refreshAppleMusicNowPlaying() {
        let player = MPMusicPlayerController.systemMusicPlayer
        isAppleMusicPlaying = player.playbackState == .playing

        guard let item = player.nowPlayingItem else {
            musicNowPlaying = nil
            return
        }

        let artworkImage = item.artwork?.image(at: CGSize(width: 72, height: 72))
        musicNowPlaying = MusicNowPlayingModel(
            title: item.title ?? "Unknown Track",
            artist: item.artist ?? item.albumTitle ?? "Apple Music",
            artwork: artworkImage
        )
    }

    private func refreshAppleMusicQuickPicks() async {
        do {
            var playlistRequest = MusicLibraryRequest<Playlist>()
            playlistRequest.limit = 6
            let playlistResponse = try await playlistRequest.response()
            let libraryPlaylists: [MusicQuickPickItem] = playlistResponse.items.compactMap { playlist in
                let title = playlist.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return MusicQuickPickItem(
                    id: playlist.id.rawValue,
                    title: title,
                    subtitle: playlist.curatorName ?? "Library playlist",
                    artworkURL: playlist.artwork?.url(width: 160, height: 160)
                )
            }
            appleMusicLibraryPlaylists = libraryPlaylists

            let libraryPlaylistIDs = Set(libraryPlaylists.map { $0.id })
            var recentRequest = MusicRecentlyPlayedContainerRequest()
            recentRequest.limit = 6
            let recentResponse = try await recentRequest.response()
            appleMusicRecentItems = recentResponse.items.compactMap { item in
                guard libraryPlaylistIDs.contains(item.id.rawValue) else { return nil }
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return MusicQuickPickItem(
                    id: item.id.rawValue,
                    title: title,
                    subtitle: item.subtitle ?? "Recently played",
                    artworkURL: item.artwork?.url(width: 160, height: 160)
                )
            }
        } catch {
            appleMusicRecentItems = []
            appleMusicLibraryPlaylists = []
        }
    }

    private func appleMusicPlaylist(id: String) async throws -> Playlist {
        let playlistID = MusicItemID(id)
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: playlistID)
        request.limit = 1
        if let playlist = try await request.response().items.first {
            return playlist
        }

        var catalogRequest = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: playlistID)
        catalogRequest.limit = 1
        if let playlist = try await catalogRequest.response().items.first {
            return playlist
        }

        throw NSError(domain: "RepSyncMusic", code: 404)
    }

    private func musicSummary(providerRawValue: String?, playlistName: String?) -> String? {
        guard let providerRawValue, let provider = MusicProvider(rawValue: providerRawValue) else {
            return nil
        }
        let playlistName = normalizedString(playlistName)
        switch provider {
        case .appleMusic:
            return playlistName.map { "Apple Music: \($0)" } ?? "Apple Music connected"
        case .spotify:
            return playlistName.map { "Spotify: \($0)" } ?? "Spotify linked"
        case .youtubeMusic:
            return playlistName.map { "YouTube Music: \($0)" } ?? "YouTube Music linked"
        }
    }

    private func normalizedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isRunningInSimulator: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }

    private func scheduleWorkoutRemindersIfNeeded() {
        let identifiers = WorkoutWeekday.allCases.map { "workout-reminder-\($0.rawValue)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

        guard profileDraftReminderEnabled, !profileDraftWorkoutDays.isEmpty else { return }

        let selectedDays = profileDraftWorkoutDays
        let reminderHour = profileDraftReminderHour
        let reminderMinute = profileDraftReminderMinute
        let reminderMessage = profileDraftReminderMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Time to train"
            : profileDraftReminderMessage

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let notificationCenter = UNUserNotificationCenter.current()

            for day in selectedDays {
                var components = DateComponents()
                components.weekday = day.rawValue
                components.hour = reminderHour
                components.minute = reminderMinute

                let content = UNMutableNotificationContent()
                content.title = "Workout Reminder"
                content.body = reminderMessage
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "workout-reminder-\(day.rawValue)",
                    content: content,
                    trigger: trigger
                )
                notificationCenter.add(request)
            }
        }
    }

    private let musicProviderKey = "music_provider"
    private let musicPromptDismissedKey = "music_prompt_dismissed"
}
