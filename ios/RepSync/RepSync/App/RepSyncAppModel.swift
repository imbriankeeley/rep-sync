import Combine
import CoreData
import Foundation
import UIKit
import SwiftUI
import MusicKit
import MediaPlayer
import AudioToolbox
#if canImport(SpotifyiOS)
import SpotifyiOS
#endif
@preconcurrency import UserNotifications

@MainActor
final class RepSyncAppModel: NSObject, ObservableObject {
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
    @Published var leaderboardState = LeaderboardScreenState()
    @Published var trackedLeaderboardLifts: Set<CanonicalLift> = Set(CanonicalLift.defaultTrackedLifts)
    @Published var bodyweightEntriesState = BodyweightEntriesScreenState()
    @Published var workoutEditorState = WorkoutEditorScreenState()

    @Published var profileDraftName = ""
    @Published var profileDraftAvatarPath: String?
    @Published var profileDraftWorkoutDays: Set<WorkoutWeekday> = []
    @Published var profileDraftReminderEnabled = false
    @Published var profileDraftReminderHour = 18
    @Published var profileDraftReminderMinute = 0
    @Published var profileDraftReminderMessage = "Time to train"
    @Published var profileDraftHeightFeet = 5
    @Published var profileDraftHeightInches = 8.0
    @Published var profileDraftBirthdate = Calendar.repsync.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @Published var profileDraftHasBirthdate = false
    @Published var profileDraftSex: BiologicalSex = .male
    @Published var profileDraftTrainingAge: TrainingAge = .beginner
    @Published var selectedMusicProvider: MusicProvider?
    @Published var hasDismissedMusicPrompt = false
    @Published var showsMusicProviderPicker = false
    @Published var appleMusicConnectionState: AppleMusicConnectionState = .notConnected
    @Published var appleMusicStatusText = "Not connected"
    @Published var appleMusicCanPlayCatalog = false
    @Published var isRefreshingAppleMusic = false
    @Published var appleMusicRefreshSummary: String?
    @Published var musicNowPlaying: MusicNowPlayingModel?
    @Published var isAppleMusicPlaying = false
    @Published var isSpotifyConnected = false
    @Published var isSpotifyPlaying = false
    @Published var spotifyStatusText = "Spotify not connected"
    @Published var spotifyDebugText: String?
    @Published var spotifyCallbackSummary: String?
    @Published var musicMessage: String?
    @Published var appleMusicRecentItems: [MusicQuickPickItem] = []
    @Published var appleMusicLibraryPlaylists: [MusicQuickPickItem] = []
    @Published var newBodyweightValue = ""
    @Published var newBodyweightPhotoPath: String?
    @Published var showsAddBodyweightSheet = false
    @Published var deletingBodyweight: BodyweightEntryModel?
    @Published var editingBodyweight: BodyweightEntryModel?
    @Published var editingBodyweightValue = ""
    @Published var editingBodyweightDate = Date()
    @Published var editingBodyweightPhotoPath: String?
    @Published var showsBodyweightFilterSheet = false
    @Published var showsBodyweightCompareSheet = false
    @Published var bodyweightCompareFirstEntryID: UUID?
    @Published var bodyweightCompareSecondEntryID: UUID?
    @Published var previewingBodyweightPhotoPath: String?
    @Published var bodyweightFilterStartDate = Calendar.repsync.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @Published var bodyweightFilterEndDate = Date()
    @Published var selectedBodyweightChartRange: BodyweightChartRange = .thirtyDays
    @Published var restTimerDurationSeconds = 90
    @Published var restTimerSecondsRemaining = 0
    @Published var showsRestTimerSheet = false
    @Published var customRestTimerSeconds = ""

    private let store: RepSyncStore
    private var timerCancellable: AnyCancellable?
    private var restTimerCancellable: AnyCancellable?
    private var restTimerEndsAt: Date?
    private var musicCancellables: Set<AnyCancellable> = []
    private var monthCursor = Calendar.repsync.startOfDay(for: Date())
    private var selectedTemplateID: UUID?
    private var selectedExerciseName = ""
    private var lastHandledSpotifyCallback = ""
    private var lastHandledSpotifyCallbackDate = Date.distantPast
    private var spotifyShouldReconnectOnActive = false
#if canImport(SpotifyiOS)
    private let spotifyClientID = "e3a791e9606849dd8c92d496e22b0162"
    private let spotifyRedirectURL = URL(string: "repsync-spotify://spotify-login-callback")!
    private lazy var spotifyConfiguration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: spotifyClientID, redirectURL: spotifyRedirectURL)
        configuration.playURI = ""
        return configuration
    }()
    private lazy var spotifySessionManager = SPTSessionManager(configuration: spotifyConfiguration, delegate: self)
    private lazy var spotifyAppRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: spotifyConfiguration, logLevel: .debug)
        appRemote.delegate = self
        return appRemote
    }()
#endif

    init(context: NSManagedObjectContext) {
        self.store = RepSyncStore(context: context)
        self.homeState = HomeScreenState(currentMonth: monthCursor, calendarDays: [])
        cloudKitMessage = CloudKitReadinessService.isICloudAvailable
            ? "iCloud is available on this device. Local data remains primary, and the store is ready for CloudKit container wiring in Xcode."
            : "Local data stays primary. CloudKit continuity will be enabled after the iCloud container identifier is configured in Xcode."
        super.init()
        configureMusicObservers()
        loadBodyweightChartRangePreference()
        loadLeaderboardTrackedLiftsPreference()
        loadMusicPreferences()
        loadRestTimerPreference()
        loadPersistedRestTimer()
        loadPersistedActiveWorkout()
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

    var appleMusicDisplayMessage: String {
        if let musicMessage, !musicMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return musicMessage
        }

        switch appleMusicConnectionState {
        case .notConnected:
            return "Connect Apple Music to browse playlists and control playback during workouts."
        case .refreshing:
            return "Loading your Apple Music library and recent mixes."
        case .ready:
            return "Use the widget to control your workout audio."
        case .noLibrary:
            return "No Apple Music playlists were found yet. Add one in Music and refresh again."
        case .unsubscribed:
            return "Apple Music is authorized, but playback may stay limited until a subscription is active."
        case .limited:
            return "Apple Music access is available, but some playback or library features may still be limited on this device."
        case .authorizationDenied:
            return "Grant Apple Music access in Settings to use playback controls here."
        case .deviceUnavailable:
            return "Apple Music playback and app launch need a physical iPhone."
        case .libraryUnavailable:
            return "Apple Music library browsing is unavailable right now. RepSync will keep your last loaded playlists when possible."
        }
    }

    var hasCurrentAppleMusicWorkoutMix: Bool {
        guard let activeWorkoutState, activeWorkoutState.musicProvider == .appleMusic else { return false }
        return normalizedString(activeWorkoutState.musicPlaylistID) != nil || normalizedString(activeWorkoutState.musicPlaylistName) != nil
    }

    var currentAppleMusicWorkoutMixLabel: String? {
        guard let activeWorkoutState, activeWorkoutState.musicProvider == .appleMusic else { return nil }
        return normalizedString(activeWorkoutState.musicPlaylistName)
    }

    var allAppleMusicBrowseItems: [MusicQuickPickItem] {
        var seen = Set<String>()
        return (appleMusicLibraryPlaylists + appleMusicRecentItems).filter { item in
            seen.insert(item.id).inserted
        }
    }

    func refreshAll() {
        do {
            workoutsState.workouts = try store.fetchWorkoutTemplates().compactMap { template in
                guard let id = template.id else { return nil }
                let exercises = (try? store.fetchTemplateExercises(templateID: id)) ?? []
                let exerciseCount = exercises.count
                let musicPreferences = try? store.workoutMusicPreferences(for: id)
                let musicSummary = musicSummary(
                    providerRawValue: musicPreferences?.provider,
                    playlistName: musicPreferences?.playlistName
                )
                return WorkoutListItem(
                    id: id,
                    name: template.name ?? "Workout",
                    exerciseCount: exerciseCount,
                    exercises: exercises.map {
                        WorkoutExerciseSummary(
                            id: $0.id ?? UUID(),
                            name: $0.name ?? "",
                            setCount: max(Int($0.setCount), 1)
                        )
                    },
                    musicSummary: musicSummary
                )
            }
            profileState = try store.makeProfileState(bodyweightChartRange: selectedBodyweightChartRange)
            trackedLeaderboardLifts = try store.leaderboardTrackedLifts()
            leaderboardState = try store.makeLeaderboardState()
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
        persistActiveWorkout()
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
        let parsedHeight = parseProfileHeight(profileState.height)
        profileDraftHeightFeet = parsedHeight.feet
        profileDraftHeightInches = parsedHeight.inches
        profileDraftBirthdate = profileState.birthdate ?? (Calendar.repsync.date(byAdding: .year, value: -18, to: Date()) ?? Date())
        profileDraftHasBirthdate = profileState.birthdate != nil
        profileDraftSex = profileState.sex
        profileDraftTrainingAge = profileState.trainingAge
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
        let cleanedExercises = workoutEditorState.exercises.compactMap { draft -> WorkoutExerciseDraft? in
            let name = normalizedExerciseName(draft.name)
            guard !name.isEmpty else { return nil }
            let suggestion = try? store.exactExerciseSuggestion(matching: name)
            var updated = draft
            updated.name = suggestion?.name ?? name
            updated.trackingType = suggestion?.trackingType ?? draft.trackingType
            updated.isSuggestedExercise = suggestion != nil
            return updated
        }
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
        persistActiveWorkout()
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
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        restTimerSecondsRemaining = 0
        restTimerEndsAt = nil
        clearPersistedActiveWorkout()
        clearPersistedRestTimer()
        cancelRestTimerNotification()
        let shouldPopNavigation = popNavigation && navigationPath.last == .activeWorkout
        activeWorkoutState = nil
        activeWorkoutBanner = nil

        if shouldPopNavigation {
            navigationPath.removeLast()
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
                try? deleteProfileAvatar(namedOrPathed: existingAvatarPath)
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
            try store.setBiometricPreferences(
                height: formattedHeightPreference(feet: profileDraftHeightFeet, inches: profileDraftHeightInches),
                birthdate: profileDraftHasBirthdate ? profileDraftBirthdate : nil,
                sex: profileDraftSex,
                trainingAge: profileDraftTrainingAge
            )
            scheduleWorkoutRemindersIfNeeded()
            refreshAll()
            navigationPath.removeLast()
        } catch {
            print("Failed to save profile: \(error)")
        }
    }

    private func parseProfileHeight(_ value: String) -> (feet: Int, inches: Double) {
        if value.contains("'") {
            let cleanedValue = value.replacingOccurrences(of: "\"", with: "")
            let parts = cleanedValue.split(separator: "'", maxSplits: 1).map(String.init)
            if parts.count == 2,
               let feet = Int(parts[0]),
               let inches = Double(parts[1]) {
                return (max(3, min(8, feet)), min(11.5, max(0, (inches * 2).rounded() / 2)))
            }
        }

        let numericValue = value
            .replacingOccurrences(of: "in", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let totalInches = Double(numericValue), totalInches > 0 else {
            return (5, 8.0)
        }

        let roundedHalfInches = (totalInches * 2).rounded() / 2
        let feet = max(3, min(8, Int(roundedHalfInches / 12)))
        let inches = min(11.5, roundedHalfInches - Double(feet * 12))
        return (feet, inches)
    }

    private func formattedHeightPreference(feet: Int, inches: Double) -> String {
        let totalInches = Double(feet * 12) + inches
        return formatWeight(totalInches)
    }

    private func moveItem<Item: Identifiable>(id: UUID, to targetIndex: Int, in items: inout [Item]) where Item.ID == UUID {
        guard let fromIndex = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        let item = items.remove(at: fromIndex)
        let adjustedToIndex = max(0, min(fromIndex < targetIndex ? targetIndex - 1 : targetIndex, items.count))
        items.insert(item, at: adjustedToIndex)
    }

    func addBodyweight() {
        guard let value = Double(newBodyweightValue), value > 0 else { return }
        do {
            try store.addBodyweightEntry(weight: value, photoPath: newBodyweightPhotoPath)
            newBodyweightValue = ""
            newBodyweightPhotoPath = nil
            showsAddBodyweightSheet = false
            refreshAll()
        } catch {
            print("Failed to add bodyweight: \(error)")
        }
    }

    func showAddBodyweightSheet() {
        newBodyweightValue = ""
        newBodyweightPhotoPath = nil
        showsAddBodyweightSheet = true
    }

    func dismissAddBodyweightSheet() {
        if let newBodyweightPhotoPath {
            try? deleteBodyweightPhoto(namedOrPathed: newBodyweightPhotoPath)
        }
        showsAddBodyweightSheet = false
        newBodyweightValue = ""
        newBodyweightPhotoPath = nil
    }

    func beginEditBodyweight(_ entry: BodyweightEntryModel) {
        editingBodyweight = entry
        editingBodyweightValue = formatWeight(entry.value)
        editingBodyweightDate = entry.date
        editingBodyweightPhotoPath = entry.photoPath
    }

    func saveEditedBodyweight() {
        guard let editingBodyweight, let value = Double(editingBodyweightValue), value > 0 else { return }
        do {
            try store.updateBodyweightEntry(
                id: editingBodyweight.id,
                weight: value,
                on: editingBodyweightDate,
                photoPath: editingBodyweightPhotoPath
            )
            if let oldPhotoPath = editingBodyweight.photoPath,
               oldPhotoPath != editingBodyweightPhotoPath {
                try? deleteBodyweightPhoto(namedOrPathed: oldPhotoPath)
            }
            self.editingBodyweight = nil
            editingBodyweightValue = ""
            editingBodyweightDate = Date()
            editingBodyweightPhotoPath = nil
            refreshAll()
        } catch {
            print("Failed to update bodyweight: \(error)")
        }
    }

    func deleteBodyweight(_ entry: BodyweightEntryModel) {
        do {
            if let photoPath = entry.photoPath {
                try? deleteBodyweightPhoto(namedOrPathed: photoPath)
            }
            try store.deleteBodyweightEntry(id: entry.id)
            if editingBodyweight?.id == entry.id {
                editingBodyweight = nil
                editingBodyweightValue = ""
                editingBodyweightDate = Date()
                editingBodyweightPhotoPath = nil
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

    var bodyweightPhotoEntries: [BodyweightEntryModel] {
        bodyweightEntriesState.entries.filter { normalizedString($0.photoPath) != nil }
    }

    var bodyweightCompareFirstEntry: BodyweightEntryModel? {
        bodyweightPhotoEntries.first { $0.id == bodyweightCompareFirstEntryID } ?? bodyweightPhotoEntries.first
    }

    var bodyweightCompareSecondEntry: BodyweightEntryModel? {
        bodyweightPhotoEntries.first { $0.id == bodyweightCompareSecondEntryID } ?? bodyweightPhotoEntries.dropFirst().first ?? bodyweightPhotoEntries.first
    }

    func showBodyweightCompare() {
        let entries = bodyweightPhotoEntries
        bodyweightCompareFirstEntryID = entries.first?.id
        bodyweightCompareSecondEntryID = entries.dropFirst().first?.id ?? entries.first?.id
        showsBodyweightCompareSheet = true
    }

    func dismissBodyweightCompare() {
        showsBodyweightCompareSheet = false
    }

    func saveNewBodyweightPhotoData(_ data: Data) {
        do {
            if let newBodyweightPhotoPath {
                try? deleteBodyweightPhoto(namedOrPathed: newBodyweightPhotoPath)
            }
            newBodyweightPhotoPath = try writeBodyweightPhoto(data)
        } catch {
            print("Failed to save bodyweight photo: \(error)")
        }
    }

    func saveEditingBodyweightPhotoData(_ data: Data) {
        do {
            if let editingBodyweightPhotoPath, editingBodyweightPhotoPath != editingBodyweight?.photoPath {
                try? deleteBodyweightPhoto(namedOrPathed: editingBodyweightPhotoPath)
            }
            editingBodyweightPhotoPath = try writeBodyweightPhoto(data)
        } catch {
            print("Failed to save bodyweight photo: \(error)")
        }
    }

    func removeNewBodyweightPhoto() {
        if let newBodyweightPhotoPath {
            try? deleteBodyweightPhoto(namedOrPathed: newBodyweightPhotoPath)
        }
        newBodyweightPhotoPath = nil
    }

    func removeEditingBodyweightPhoto() {
        if let editingBodyweightPhotoPath, editingBodyweightPhotoPath != editingBodyweight?.photoPath {
            try? deleteBodyweightPhoto(namedOrPathed: editingBodyweightPhotoPath)
        }
        editingBodyweightPhotoPath = nil
    }

    func previewBodyweightPhoto(_ path: String?) {
        guard normalizedString(path) != nil else { return }
        previewingBodyweightPhotoPath = path
    }

    func dismissBodyweightPhotoPreview() {
        previewingBodyweightPhotoPath = nil
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

    func moveEditorExercise(id: UUID, to index: Int) {
        var state = workoutEditorState
        moveItem(id: id, to: index, in: &state.exercises)
        workoutEditorState = state
    }

    func addExerciseToActiveWorkout() {
        activeWorkoutState?.exercises.append(ActiveExerciseDraft())
        activeWorkoutDidChange()
    }

    func removeActiveExercise(id: UUID) {
        activeWorkoutState?.exercises.removeAll { $0.id == id }
        activeWorkoutDidChange()
    }

    func moveActiveExercise(id: UUID, to index: Int) {
        guard var state = activeWorkoutState else { return }
        moveItem(id: id, to: index, in: &state.exercises)
        activeWorkoutState = state
    }

    func commitActiveExerciseOrder() {
        activeWorkoutDidChange()
    }

    func addSet(to exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let nextNumber = (activeWorkoutState?.exercises[index].sets.count ?? 0) + 1
        let name = activeWorkoutState?.exercises[index].name ?? ""
        let previous = (try? store.latestPreviousSummary(for: name, setNumber: nextNumber)) ?? ""
        activeWorkoutState?.exercises[index].sets.append(ActiveSetDraft(setNumber: nextNumber, previous: previous))
        activeWorkoutDidChange()
    }

    func removeSet(from exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }),
              var exercise = activeWorkoutState?.exercises[exerciseIndex],
              exercise.sets.count > 1 else {
            return
        }

        exercise.sets.removeAll { $0.id == setID }
        exercise.sets = exercise.sets.enumerated().map { index, set in
            var updatedSet = set
            updatedSet.setNumber = index + 1
            return updatedSet
        }
        activeWorkoutState?.exercises[exerciseIndex] = exercise
        activeWorkoutDidChange()
    }

    func exerciseSuggestions(for query: String) -> [ExerciseSuggestion] {
        if exactExerciseSuggestion(for: query) != nil {
            return []
        }
        return (try? store.exerciseSuggestions(matching: query)) ?? []
    }

    func exactExerciseSuggestion(for query: String) -> ExerciseSuggestion? {
        try? store.exactExerciseSuggestion(matching: query)
    }

    func updateActiveWorkout(_ state: ActiveWorkoutScreenState) {
        activeWorkoutState = state
        activeWorkoutDidChange()
    }

    func updateActiveExercise(_ exercise: ActiveExerciseDraft) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        activeWorkoutState?.exercises[index] = exercise
        activeWorkoutDidChange()
    }

    func moveWorkout(id: UUID, to index: Int) {
        var state = workoutsState
        moveItem(id: id, to: index, in: &state.workouts)
        workoutsState = state
    }

    func commitWorkoutOrder() {
        do {
            try store.reorderWorkoutTemplates(ids: workoutsState.workouts.map(\.id))
        } catch {
            print("Failed to reorder workouts: \(error)")
            refreshAll()
        }
    }

    func resolveActiveExerciseName(for exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let typedName = activeWorkoutState?.exercises[index].name ?? ""
        guard let suggestion = exactExerciseSuggestion(for: typedName) else { return }
        applyActiveSuggestion(suggestion, to: exerciseID)
    }

    func resolveEditorExerciseName(for exerciseID: UUID) {
        guard let index = workoutEditorState.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let typedName = workoutEditorState.exercises[index].name
        guard let suggestion = exactExerciseSuggestion(for: typedName) else { return }
        applyEditorSuggestion(suggestion, to: exerciseID)
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
        activeWorkoutDidChange()
    }

    func clearActiveSuggestionFlag(for exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        activeWorkoutState?.exercises[index].isSuggestedExercise = false
        activeWorkoutDidChange()
    }

    func lockTrackingType(_ trackingType: ExerciseTrackingKind, for exerciseID: UUID) {
        guard let index = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let canonicalName = normalizedExerciseName(activeWorkoutState?.exercises[index].name ?? "")
        if !canonicalName.isEmpty {
            activeWorkoutState?.exercises[index].name = canonicalName
        }
        activeWorkoutState?.exercises[index].trackingType = trackingType
        activeWorkoutState?.exercises[index].isTrackingTypeLocked = true
        activeWorkoutDidChange()
    }

    func toggleSetCompleted(for exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = activeWorkoutState?.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        guard let exercise = activeWorkoutState?.exercises[exerciseIndex] else { return }
        let set = exercise.sets[setIndex]

        if set.isComplete == false,
           setIsMissingRequiredValues(set, trackingType: exercise.trackingType) {
            return
        }

        activeWorkoutState?.exercises[exerciseIndex].sets[setIndex].isComplete.toggle()
        if activeWorkoutState?.exercises[exerciseIndex].sets[setIndex].isComplete == true {
            startRestTimer()
        }
        activeWorkoutDidChange()
    }

    func canToggleSetCompleted(for exerciseID: UUID, setID: UUID) -> Bool {
        guard let exerciseIndex = activeWorkoutState?.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = activeWorkoutState?.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }),
              let exercise = activeWorkoutState?.exercises[exerciseIndex] else {
            return false
        }

        let set = exercise.sets[setIndex]
        if set.isComplete {
            return true
        }
        return !setIsMissingRequiredValues(set, trackingType: exercise.trackingType)
    }

    func showRestTimerSheet() {
        customRestTimerSeconds = restTimerDurationSeconds > 0 ? "\(restTimerDurationSeconds)" : ""
        showsRestTimerSheet = true
    }

    func dismissRestTimerSheet() {
        showsRestTimerSheet = false
    }

    func setRestTimerDuration(seconds: Int) {
        restTimerDurationSeconds = max(seconds, 0)
        customRestTimerSeconds = restTimerDurationSeconds > 0 ? "\(restTimerDurationSeconds)" : ""
        persistRestTimerPreference()
        showsRestTimerSheet = false
    }

    func applyCustomRestTimerDuration() {
        guard let seconds = Int(customRestTimerSeconds), seconds >= 0 else { return }
        setRestTimerDuration(seconds: seconds)
    }

    func cancelRestTimer() {
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        restTimerSecondsRemaining = 0
        restTimerEndsAt = nil
        clearPersistedRestTimer()
        cancelRestTimerNotification()
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
                try? deleteProfileAvatar(namedOrPathed: previousDraft)
            }
            let filename = try writeProfileAvatar(data)
            profileDraftAvatarPath = filename
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

    func selectBodyweightChartRange(_ range: BodyweightChartRange) {
        selectedBodyweightChartRange = range
        do {
            try store.setStringPreference(range.rawValue, for: bodyweightChartRangeKey)
            profileState = try store.makeProfileState(bodyweightChartRange: selectedBodyweightChartRange)
        } catch {
            print("Failed to update bodyweight chart range: \(error)")
        }
    }

    func toggleLeaderboardLift(_ lift: CanonicalLift) {
        if trackedLeaderboardLifts.contains(lift) {
            trackedLeaderboardLifts.remove(lift)
        } else {
            trackedLeaderboardLifts.insert(lift)
        }

        do {
            try store.setLeaderboardTrackedLifts(trackedLeaderboardLifts)
            leaderboardState = try store.makeLeaderboardState()
        } catch {
            print("Failed to update leaderboard tracked lifts: \(error)")
            loadLeaderboardTrackedLiftsPreference()
        }
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
            disconnectSpotify()
            Task {
                await connectAppleMusic()
            }
        case .spotify:
            appleMusicConnectionState = .notConnected
            appleMusicCanPlayCatalog = false
            musicNowPlaying = nil
            isAppleMusicPlaying = false
            appleMusicRecentItems = []
            appleMusicLibraryPlaylists = []
            appleMusicStatusText = "Spotify selected"
            spotifyStatusText = "Spotify selected"
            spotifyDebugText = nil
            spotifyCallbackSummary = nil
            musicMessage = "Connect Spotify to use play, pause, skip, and workout mix controls inside RepSync."
        }
    }

    func connectAppleMusic() async {
        if isRunningInSimulator {
            appleMusicConnectionState = .deviceUnavailable
            appleMusicStatusText = "Apple Music requires a physical iPhone"
            appleMusicCanPlayCatalog = false
            appleMusicRefreshSummary = nil
            musicNowPlaying = nil
            isAppleMusicPlaying = false
            musicMessage = "Apple Music playback and app launch are unavailable in the iOS Simulator."
            return
        }

        isRefreshingAppleMusic = true
        appleMusicConnectionState = .refreshing
        defer { isRefreshingAppleMusic = false }

        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            appleMusicConnectionState = .authorizationDenied
            appleMusicStatusText = "Apple Music access was not granted."
            appleMusicCanPlayCatalog = false
            appleMusicRefreshSummary = nil
            musicNowPlaying = nil
            isAppleMusicPlaying = false
            musicMessage = "Grant Apple Music access in Settings to use playback controls here."
            return
        }

        do {
            let subscription = try await MusicSubscription.current
            appleMusicCanPlayCatalog = subscription.canPlayCatalogContent
            if subscription.canPlayCatalogContent {
                appleMusicConnectionState = .ready
                appleMusicStatusText = "Apple Music connected"
                musicMessage = nil
            } else if subscription.canBecomeSubscriber {
                appleMusicConnectionState = .unsubscribed
                appleMusicStatusText = "Apple Music connected, but no playback subscription was detected."
                musicMessage = "You can authorize the app now and finish subscription setup later in the Music app."
            } else {
                appleMusicConnectionState = .limited
                appleMusicStatusText = "Apple Music connected with limited playback access."
                musicMessage = "Playback controls may be unavailable until Apple Music access is fully available on this device."
            }
            await refreshAppleMusicQuickPicks()
        } catch {
            appleMusicConnectionState = .libraryUnavailable
            appleMusicCanPlayCatalog = false
            appleMusicStatusText = "Apple Music connected, but subscription status could not be verified."
            musicMessage = "RepSync can still try to show playback controls, but catalog playback may be limited."
            appleMusicRefreshSummary = appleMusicLibraryPlaylists.isEmpty && appleMusicRecentItems.isEmpty
                ? nil
                : "Showing your last loaded Apple Music playlists."
        }
        refreshAppleMusicNowPlaying()
    }

    func refreshAppleMusicConnection() {
        appleMusicStatusText = "Refreshing Apple Music"
        appleMusicConnectionState = .refreshing
        musicMessage = "Loading your Apple Music playlists and recent mixes."
        Task {
            await connectAppleMusic()
        }
    }

    func toggleAppleMusicPlayback() {
        if isRunningInSimulator {
            appleMusicConnectionState = .deviceUnavailable
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
            appleMusicConnectionState = .deviceUnavailable
            musicMessage = "Apple Music playback controls are unavailable in the iOS Simulator. Use a physical device to test playback."
            return
        }
        MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
        refreshAppleMusicNowPlaying()
    }

    func openAppleMusicApp() {
        if isRunningInSimulator {
            appleMusicConnectionState = .deviceUnavailable
            musicMessage = "The Music app cannot be opened from the iOS Simulator. Test this action on a physical device."
            return
        }
        guard let url = URL(string: "music://") else { return }
        guard UIApplication.shared.canOpenURL(url) else {
            appleMusicConnectionState = .deviceUnavailable
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
                appleMusicConnectionState = .ready
                musicMessage = "Now playing \(item.title)."
                refreshAppleMusicNowPlaying()
            } catch {
                appleMusicConnectionState = .libraryUnavailable
                musicMessage = "RepSync could not start \(item.title). Open it in Music and try again."
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

    func playCurrentWorkoutMix() {
        guard let activeWorkoutState else { return }

        switch activeWorkoutState.musicProvider {
        case .appleMusic:
            guard let item = appleMusicQuickPick(
                playlistID: normalizedString(activeWorkoutState.musicPlaylistID),
                playlistName: normalizedString(activeWorkoutState.musicPlaylistName),
                fallbackSubtitle: "Saved for \(activeWorkoutState.workoutName)"
            ) else {
                musicMessage = "This workout does not have a saved Apple Music mix yet."
                return
            }
            playAppleMusicQuickPick(item)
        case .spotify:
            if isSpotifyConnected,
               let playlistURL = normalizedString(activeWorkoutState.musicPlaylistURL) {
                playSpotifyURI(from: playlistURL)
            } else if let playlistURL = normalizedString(activeWorkoutState.musicPlaylistURL) {
                openSpotifyURL(playlistURL)
            } else {
                connectSpotify()
            }
        case nil:
            break
        }
    }

    func connectSpotify() {
#if canImport(SpotifyiOS)
        if isRunningInSimulator {
            spotifyStatusText = "Spotify App Remote requires a physical iPhone."
            musicMessage = "Use your iPhone with the Spotify app installed to finish connection and playback testing."
            return
        }

        let scope: SPTScope = [.appRemoteControl, .userReadPlaybackState]
        spotifyStatusText = "Opening Spotify"
        spotifyDebugText = "Starting Spotify session authorization."
        musicMessage = "Approve RepSync in Spotify, then return here automatically."
        spotifyShouldReconnectOnActive = true
        let options: AuthorizationOptions = .default
        spotifySessionManager.initiateSession(with: scope, options: options, campaign: nil)
#else
        spotifyStatusText = "Spotify SDK unavailable"
        musicMessage = "Rebuild the project after linking SpotifyiOS.xcframework if controls do not appear."
#endif
    }

    func disconnectSpotify() {
#if canImport(SpotifyiOS)
        if spotifyAppRemote.isConnected {
            spotifyAppRemote.disconnect()
        }
#endif
        isSpotifyConnected = false
        isSpotifyPlaying = false
        spotifyShouldReconnectOnActive = false
        spotifyDebugText = nil
        spotifyCallbackSummary = nil
        spotifyStatusText = selectedMusicProvider == .spotify ? "Spotify selected" : "Spotify not connected"
    }

    func toggleSpotifyPlayback() {
#if canImport(SpotifyiOS)
        guard spotifyAppRemote.isConnected else {
            connectSpotify()
            return
        }

        if isSpotifyPlaying {
            spotifyAppRemote.playerAPI?.pause(nil)
        } else {
            spotifyAppRemote.playerAPI?.resume(nil)
        }
#else
        connectSpotify()
#endif
    }

    func skipSpotifyTrack() {
#if canImport(SpotifyiOS)
        guard spotifyAppRemote.isConnected else {
            connectSpotify()
            return
        }
        spotifyAppRemote.playerAPI?.skip(toNext: nil)
#else
        connectSpotify()
#endif
    }

    func openSpotifyApp() {
        if let url = URL(string: "spotify://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let webURL = URL(string: "https://open.spotify.com") {
            UIApplication.shared.open(webURL)
        }
    }

    func openSpotifyURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            openSpotifyApp()
            return
        }
        UIApplication.shared.open(url)
    }

    func handleIncomingURL(_ url: URL) {
#if canImport(SpotifyiOS)
        if url.scheme == spotifyRedirectURL.scheme {
            let absoluteURL = url.absoluteString
            let now = Date()
            if absoluteURL == lastHandledSpotifyCallback,
               now.timeIntervalSince(lastHandledSpotifyCallbackDate) < 2 {
                return
            }
            lastHandledSpotifyCallback = absoluteURL
            lastHandledSpotifyCallbackDate = now
            spotifyStatusText = "Finishing Spotify sign in"
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let queryItems = components?.queryItems ?? []
            let hasCode = queryItems.contains(where: { $0.name == "code" && !($0.value ?? "").isEmpty })
            let errorValue = queryItems.first(where: { $0.name == "error" })?.value
            let stateValue = queryItems.first(where: { $0.name == "state" })?.value
            spotifyCallbackSummary = "cb code:\(hasCode ? "yes" : "no") err:\(errorValue ?? "-") state:\(stateValue == nil ? "no" : "yes")"
            if let errorValue, !errorValue.isEmpty {
                spotifyDebugText = "Callback error=\(errorValue)"
            } else if hasCode {
                spotifyDebugText = "Callback includes auth code."
            } else if let stateValue, !stateValue.isEmpty {
                spotifyDebugText = "Callback has state only."
            } else {
                spotifyDebugText = "Callback missing code/error."
            }
            let handled = spotifySessionManager.application(UIApplication.shared, open: url, options: [:])
            if !handled {
                spotifyShouldReconnectOnActive = false
                spotifyStatusText = "Spotify sign in failed"
                spotifyDebugText = "Session manager rejected callback."
                spotifyCallbackSummary = (spotifyCallbackSummary ?? "cb unknown") + " handled:no"
                musicMessage = "Spotify returned to RepSync, but the callback was rejected. Recheck the Spotify dashboard bundle ID and redirect URI."
            } else {
                spotifyCallbackSummary = (spotifyCallbackSummary ?? "cb unknown") + " handled:yes"
            }
            return
        }
#endif
        if url.scheme == "music" {
            refreshAppleMusicNowPlaying()
        }
    }

    func handleSceneDidBecomeActive() {
        restoreRestTimerCountdownIfNeeded()
        if activeWorkoutState == nil {
            loadPersistedActiveWorkout()
        } else {
            updateActiveWorkoutElapsedText()
        }
#if canImport(SpotifyiOS)
        guard selectedMusicProvider == .spotify else { return }
        guard spotifyShouldReconnectOnActive || spotifyAppRemote.connectionParameters.accessToken != nil else { return }
        guard !spotifyAppRemote.isConnected else { return }

        spotifyStatusText = "Connecting to Spotify"
        spotifyDebugText = spotifyAppRemote.connectionParameters.accessToken == nil
            ? "App became active without Spotify access token."
            : "App became active with Spotify token. Attempting App Remote connect."
        if musicMessage == nil || musicMessage?.contains("Approve RepSync in Spotify") == true {
            musicMessage = "Restoring Spotify controls in RepSync."
        }
        spotifyAppRemote.connect()
#endif
    }

    func handleSceneWillResignActive() {
        persistActiveWorkout()
        persistRestTimer()
#if canImport(SpotifyiOS)
        guard selectedMusicProvider == .spotify else { return }
        guard spotifyAppRemote.isConnected else { return }
        spotifyAppRemote.disconnect()
#endif
    }

    func copyCompletedWorkoutToTemplate(id: UUID, templateName: String? = nil) {
        do {
            try store.createTemplateCopy(from: id, templateName: templateName)
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

    func updateCompletedWorkoutDate(id: UUID, on date: Date) {
        do {
            try store.updateCompletedWorkoutDate(id: id, on: date)
            dayViewState = (try? store.makeDayViewState(for: dayViewState.selectedDate)) ?? dayViewState
            refreshAll()
        } catch {
            print("Failed to update completed workout date: \(error)")
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
                self.updateActiveWorkoutElapsedText()
            }
        updateActiveWorkoutElapsedText()
        refreshBanner()
    }

    private func startRestTimer() {
        guard restTimerDurationSeconds > 0 else { return }
        restTimerCancellable?.cancel()
        restTimerEndsAt = Date().addingTimeInterval(TimeInterval(restTimerDurationSeconds))
        updateRestTimerCountdown()
        persistRestTimer()
        scheduleRestTimerNotification(seconds: restTimerDurationSeconds)
        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateRestTimerCountdown()
            }
    }

    private func updateActiveWorkoutElapsedText() {
        guard var state = activeWorkoutState else { return }
        state.elapsedText = formatElapsedTime(from: state.startedAt)
        activeWorkoutState = state
        refreshBanner()
    }

    private func updateRestTimerCountdown() {
        guard let restTimerEndsAt else {
            restTimerSecondsRemaining = 0
            return
        }

        let remaining = max(Int(ceil(restTimerEndsAt.timeIntervalSinceNow)), 0)
        restTimerSecondsRemaining = remaining

        if remaining == 0 {
            restTimerCancellable?.cancel()
            restTimerCancellable = nil
            self.restTimerEndsAt = nil
            clearPersistedRestTimer()
            cancelRestTimerNotification()
            notifyRestTimerCompleted()
        }
    }

    private func restoreRestTimerCountdownIfNeeded() {
        guard let restTimerEndsAt else {
            restTimerSecondsRemaining = 0
            return
        }

        if restTimerEndsAt <= Date() {
            restTimerCancellable?.cancel()
            restTimerCancellable = nil
            self.restTimerEndsAt = nil
            restTimerSecondsRemaining = 0
            clearPersistedRestTimer()
            return
        }

        restTimerCancellable?.cancel()
        updateRestTimerCountdown()
        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRestTimerCountdown()
            }
    }

    private func activeWorkoutDidChange() {
        updateActiveWorkoutElapsedText()
        persistActiveWorkout()
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
            return set.minutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                set.seconds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .durationDistance:
            return set.minutes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                set.seconds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                set.distance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                set.speed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func writeProfileAvatar(_ data: Data) throws -> String {
        let filename = "profile-avatar-\(UUID().uuidString).jpg"
        let fileURL = try profileAvatarDirectory().appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    private func deleteProfileAvatar(namedOrPathed value: String) throws {
        let fileManager = FileManager.default
        let directURL = URL(fileURLWithPath: value)

        if fileManager.fileExists(atPath: directURL.path) {
            try fileManager.removeItem(at: directURL)
            return
        }

        let filename = directURL.lastPathComponent
        guard !filename.isEmpty else { return }

        let resolvedURL = try profileAvatarDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: resolvedURL.path) {
            try fileManager.removeItem(at: resolvedURL)
        }
    }

    private func profileAvatarDirectory() throws -> URL {
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
        return directory
    }

    private func writeBodyweightPhoto(_ data: Data) throws -> String {
        guard UIImage(data: data) != nil else {
            throw NSError(domain: "RepSyncBodyweightPhoto", code: 1)
        }

        let filename = "bodyweight-photo-\(UUID().uuidString).jpg"
        let fileURL = try bodyweightPhotoDirectory().appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    private func deleteBodyweightPhoto(namedOrPathed value: String) throws {
        let fileManager = FileManager.default
        let directURL = URL(fileURLWithPath: value)

        if fileManager.fileExists(atPath: directURL.path) {
            try fileManager.removeItem(at: directURL)
            return
        }

        let filename = directURL.lastPathComponent
        guard !filename.isEmpty else { return }

        let resolvedURL = try bodyweightPhotoDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: resolvedURL.path) {
            try fileManager.removeItem(at: resolvedURL)
        }
    }

    private func bodyweightPhotoDirectory() throws -> URL {
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("RepSyncBodyweightPhotos", isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
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
            spotifyStatusText = "Spotify selected"
            musicMessage = "Connect Spotify to use play, pause, skip, and workout mix controls inside RepSync."
        }
    }

    private func loadRestTimerPreference() {
        do {
            if let storedValue = try store.stringPreference(for: restTimerDurationKey),
               let seconds = Int(storedValue),
               seconds >= 0 {
                restTimerDurationSeconds = seconds
            }
            customRestTimerSeconds = "\(restTimerDurationSeconds)"
        } catch {
            print("Failed to load rest timer preference: \(error)")
        }
    }

    private func persistRestTimerPreference() {
        do {
            try store.setStringPreference("\(restTimerDurationSeconds)", for: restTimerDurationKey)
        } catch {
            print("Failed to persist rest timer preference: \(error)")
        }
    }

    private func loadBodyweightChartRangePreference() {
        do {
            if let rawValue = try store.stringPreference(for: bodyweightChartRangeKey),
               let range = BodyweightChartRange(rawValue: rawValue) {
                selectedBodyweightChartRange = range
            }
        } catch {
            print("Failed to load bodyweight chart range preference: \(error)")
        }
    }

    private func loadLeaderboardTrackedLiftsPreference() {
        do {
            trackedLeaderboardLifts = try store.leaderboardTrackedLifts()
        } catch {
            print("Failed to load leaderboard tracked lifts: \(error)")
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
        let existingLibraryPlaylists = appleMusicLibraryPlaylists
        let existingRecentItems = appleMusicRecentItems

        var loadedLibraryPlaylists = existingLibraryPlaylists
        var loadedRecentItems = existingRecentItems
        var didLoadAnySource = false
        var encounteredFailure = false

        do {
            var playlistRequest = MusicLibraryRequest<Playlist>()
            playlistRequest.limit = 20
            let playlistResponse = try await playlistRequest.response()
            loadedLibraryPlaylists = playlistResponse.items.compactMap { playlist in
                let title = playlist.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return MusicQuickPickItem(
                    id: playlist.id.rawValue,
                    title: title,
                    subtitle: playlist.curatorName ?? "Library playlist",
                    artworkURL: playlist.artwork?.url(width: 160, height: 160)
                )
            }
            appleMusicLibraryPlaylists = loadedLibraryPlaylists
            didLoadAnySource = true
        } catch {
            encounteredFailure = true
        }

        do {
            var recentRequest = MusicRecentlyPlayedContainerRequest()
            recentRequest.limit = 20
            let recentResponse = try await recentRequest.response()
            loadedRecentItems = recentResponse.items.compactMap { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return MusicQuickPickItem(
                    id: item.id.rawValue,
                    title: title,
                    subtitle: item.subtitle ?? "Recently played",
                    artworkURL: item.artwork?.url(width: 160, height: 160)
                )
            }
            appleMusicRecentItems = loadedRecentItems
            didLoadAnySource = true
        } catch {
            encounteredFailure = true
        }

        if !didLoadAnySource {
            appleMusicLibraryPlaylists = existingLibraryPlaylists
            appleMusicRecentItems = existingRecentItems
            appleMusicConnectionState = existingLibraryPlaylists.isEmpty && existingRecentItems.isEmpty ? .libraryUnavailable : appleMusicConnectionState
            if existingLibraryPlaylists.isEmpty && existingRecentItems.isEmpty {
                musicMessage = "RepSync could not load your Apple Music library yet. Open Music once on this device, then refresh again."
                appleMusicRefreshSummary = nil
            } else {
                musicMessage = "RepSync could not refresh Apple Music right now. Showing your last loaded playlists."
                appleMusicRefreshSummary = "Showing your last loaded Apple Music playlists."
            }
            return
        }

        if loadedLibraryPlaylists.isEmpty && loadedRecentItems.isEmpty {
            appleMusicConnectionState = .noLibrary
            appleMusicRefreshSummary = "No Apple Music playlists found yet"
            musicMessage = "No Apple Music playlists were found yet. Add one in Music and refresh again."
        } else {
            if appleMusicConnectionState == .refreshing || appleMusicConnectionState == .libraryUnavailable || appleMusicConnectionState == .noLibrary {
                appleMusicConnectionState = appleMusicCanPlayCatalog ? .ready : appleMusicConnectionState
                if !appleMusicCanPlayCatalog, appleMusicConnectionState == .refreshing {
                    appleMusicConnectionState = .limited
                }
            }
            appleMusicRefreshSummary = encounteredFailure
                ? "Partially updated. Some Apple Music sections could not refresh."
                : "Updated just now"
            if encounteredFailure {
                musicMessage = "RepSync refreshed the Apple Music data it could load and kept the rest stable."
            } else if musicMessage?.contains("Apple Music") == true || musicMessage?.contains("playlist") == true {
                musicMessage = nil
            }
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

    private func appleMusicQuickPick(playlistID: String?, playlistName: String?, fallbackSubtitle: String) -> MusicQuickPickItem? {
        if let playlistID,
           let exactMatch = allAppleMusicBrowseItems.first(where: { $0.id == playlistID }) {
            return exactMatch
        }

        if let playlistID, let playlistName {
            return MusicQuickPickItem(
                id: playlistID,
                title: playlistName,
                subtitle: fallbackSubtitle,
                artworkURL: nil
            )
        }

        if let playlistName,
           let nameMatch = allAppleMusicBrowseItems.first(where: { $0.title.caseInsensitiveCompare(playlistName) == .orderedSame }) {
            return nameMatch
        }

        return nil
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
        }
    }

    private func normalizedString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func notifyRestTimerCompleted() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func scheduleRestTimerNotification(seconds: Int) {
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Your rest timer is up."
        content.sound = .default

        let identifier = restTimerNotificationIdentifier
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(seconds, 1)), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(request)
        }
    }

    private func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerNotificationIdentifier])
    }

    private func persistActiveWorkout() {
        guard let activeWorkoutState else {
            clearPersistedActiveWorkout()
            return
        }

        do {
            let data = try JSONEncoder().encode(activeWorkoutState)
            try store.setStringPreference(String(decoding: data, as: UTF8.self), for: activeWorkoutStateKey)
        } catch {
            print("Failed to persist active workout: \(error)")
        }
    }

    private func loadPersistedActiveWorkout() {
        do {
            guard let storedValue = try store.stringPreference(for: activeWorkoutStateKey),
                  let data = storedValue.data(using: .utf8) else {
                return
            }

            var restoredState = try JSONDecoder().decode(ActiveWorkoutScreenState.self, from: data)
            restoredState.elapsedText = formatElapsedTime(from: restoredState.startedAt)
            activeWorkoutState = restoredState
            startTimer()
            refreshBanner()
        } catch {
            print("Failed to restore active workout: \(error)")
            clearPersistedActiveWorkout()
        }
    }

    private func clearPersistedActiveWorkout() {
        do {
            try store.setStringPreference(nil, for: activeWorkoutStateKey)
        } catch {
            print("Failed to clear active workout draft: \(error)")
        }
    }

    private func persistRestTimer() {
        do {
            let value = restTimerEndsAt.map { "\($0.timeIntervalSince1970)" }
            try store.setStringPreference(value, for: restTimerEndsAtKey)
        } catch {
            print("Failed to persist rest timer: \(error)")
        }
    }

    private func loadPersistedRestTimer() {
        do {
            guard let storedValue = try store.stringPreference(for: restTimerEndsAtKey),
                  let timestamp = TimeInterval(storedValue) else {
                return
            }

            restTimerEndsAt = Date(timeIntervalSince1970: timestamp)
            restoreRestTimerCountdownIfNeeded()
        } catch {
            print("Failed to restore rest timer: \(error)")
            clearPersistedRestTimer()
        }
    }

    private func clearPersistedRestTimer() {
        do {
            try store.setStringPreference(nil, for: restTimerEndsAtKey)
        } catch {
            print("Failed to clear rest timer: \(error)")
        }
    }

    private var isRunningInSimulator: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }

#if canImport(SpotifyiOS)
    private func playSpotifyURI(from value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("spotify:") {
            spotifyAppRemote.playerAPI?.play(trimmed, callback: nil)
            return
        }

        if let url = URL(string: trimmed),
           let host = url.host,
           url.pathComponents.count >= 3 {
            let uri = "spotify:\(host):\(url.pathComponents[2])"
            spotifyAppRemote.playerAPI?.play(uri, callback: nil)
            return
        }

        openSpotifyURL(trimmed)
    }

    private func updateSpotifyPlayerState(_ playerState: SPTAppRemotePlayerState) {
        isSpotifyPlaying = !playerState.isPaused
        isSpotifyConnected = true
        spotifyStatusText = "Spotify connected"
        musicNowPlaying = MusicNowPlayingModel(
            title: playerState.track.name,
            artist: playerState.track.artist.name,
            artwork: musicNowPlaying?.artwork
        )

        spotifyAppRemote.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 80, height: 80)) { [weak self] image, _ in
            guard let self else { return }
            Task { @MainActor in
                guard let current = self.musicNowPlaying else { return }
                self.musicNowPlaying = MusicNowPlayingModel(
                    title: current.title,
                    artist: current.artist,
                    artwork: image as? UIImage
                )
            }
        }
    }
#endif

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
    private let bodyweightChartRangeKey = "bodyweight_chart_range"
    private let restTimerDurationKey = "rest_timer_duration_seconds"
    private let activeWorkoutStateKey = "active_workout_state_json"
    private let restTimerEndsAtKey = "rest_timer_ends_at"
    private let restTimerNotificationIdentifier = "active-rest-timer-complete"
}

#if canImport(SpotifyiOS)
extension RepSyncAppModel: SPTSessionManagerDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    nonisolated func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        Task { @MainActor in
            self.spotifyShouldReconnectOnActive = false
            self.spotifyStatusText = "Spotify authorization failed"
            self.spotifyDebugText = "Session manager authorization failed."
            self.musicMessage = error.localizedDescription
        }
    }

    nonisolated func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        Task { @MainActor in
            self.spotifyAppRemote.connectionParameters.accessToken = session.accessToken
            self.spotifyDebugText = "Spotify session renewed."
        }
    }

    nonisolated func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        Task { @MainActor in
            self.spotifyAppRemote.connectionParameters.accessToken = session.accessToken
            self.spotifyShouldReconnectOnActive = true
            self.spotifyStatusText = "Connecting to Spotify"
            self.spotifyDebugText = "Spotify access token received. Connecting App Remote."
            self.musicMessage = nil
            self.spotifyAppRemote.connect()
        }
    }

    nonisolated func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        Task { @MainActor in
            self.isSpotifyConnected = true
            self.spotifyShouldReconnectOnActive = false
            self.spotifyStatusText = "Spotify connected"
            self.spotifyDebugText = "App Remote connection established."
            self.musicMessage = nil
            appRemote.playerAPI?.delegate = self
            appRemote.playerAPI?.subscribe(toPlayerState: { _, error in
                if let error {
                    Task { @MainActor in
                        self.musicMessage = error.localizedDescription
                    }
                }
            })
            appRemote.playerAPI?.getPlayerState { playerState, error in
                if let playerState = playerState as? SPTAppRemotePlayerState {
                    Task { @MainActor in
                        self.updateSpotifyPlayerState(playerState)
                    }
                } else if let error {
                    Task { @MainActor in
                        self.musicMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        Task { @MainActor in
            self.isSpotifyConnected = false
            self.isSpotifyPlaying = false
            self.spotifyStatusText = "Spotify disconnected"
            if let error {
                self.spotifyShouldReconnectOnActive = true
                self.spotifyDebugText = "App Remote disconnected with error."
                self.musicMessage = error.localizedDescription
            } else if self.selectedMusicProvider == .spotify,
                      self.spotifyAppRemote.connectionParameters.accessToken != nil {
                self.spotifyShouldReconnectOnActive = true
                self.spotifyDebugText = "App Remote disconnected without error."
                self.musicMessage = "Spotify was disconnected. RepSync will reconnect when the app becomes active again."
            }
        }
    }

    nonisolated func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        Task { @MainActor in
            self.isSpotifyConnected = false
            self.isSpotifyPlaying = false
            self.spotifyShouldReconnectOnActive = true
            self.spotifyStatusText = "Spotify connection failed"
            self.spotifyDebugText = "App Remote connection attempt failed."
            self.musicMessage = error?.localizedDescription ?? "RepSync could not connect to Spotify."
        }
    }

    nonisolated func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        Task { @MainActor in
            self.updateSpotifyPlayerState(playerState)
        }
    }
}
#endif
