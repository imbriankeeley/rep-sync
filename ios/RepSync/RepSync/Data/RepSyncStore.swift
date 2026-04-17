import CoreData
import Foundation

struct ExerciseHistorySample {
    let date: Date
    let workoutName: String
    let summary: String
    let metricValue: Double
}

@MainActor
final class RepSyncStore {
    private let context: NSManagedObjectContext
    private let bodyweightStableThresholdLbsPerWeek = 0.1

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func fetchWorkoutTemplates() throws -> [WorkoutTemplate] {
        let request: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        return try context.fetch(request)
    }

    func fetchWorkoutTemplate(id: UUID) throws -> WorkoutTemplate? {
        let request: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    func fetchTemplateExercises(templateID: UUID) throws -> [TemplateExercise] {
        let request: NSFetchRequest<TemplateExercise> = TemplateExercise.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        request.predicate = NSPredicate(format: "templateID == %@", templateID as CVarArg)
        return try context.fetch(request)
    }

    func upsertWorkoutTemplate(id: UUID?, name: String, exercises: [WorkoutExerciseDraft]) throws -> UUID {
        let template = try id.flatMap(fetchWorkoutTemplate(id:)) ?? WorkoutTemplate(context: context)
        let isNew = template.id == nil
        template.id = template.id ?? UUID()
        template.name = name
        template.createdAt = template.createdAt ?? Date()
        template.updatedAt = Date()
        if isNew {
            template.orderIndex = Int64(try fetchWorkoutTemplates().count)
        }

        if let templateID = template.id {
            try fetchTemplateExercises(templateID: templateID).forEach(context.delete)
        }

        for (index, draft) in exercises.enumerated() {
            let exercise = TemplateExercise(context: context)
            exercise.id = UUID()
            exercise.name = draft.name
            exercise.orderIndex = Int64(index)
            exercise.setCount = Int64(max(draft.setCount, 1))
            exercise.templateID = template.id
            exercise.trackingType = draft.trackingType.rawValue
        }

        try save()
        return template.id ?? UUID()
    }

    func deleteWorkoutTemplate(id: UUID) throws {
        if let template = try fetchWorkoutTemplate(id: id) {
            try fetchTemplateExercises(templateID: id).forEach(context.delete)
            context.delete(template)
            try save()
            try normalizeTemplateOrder()
        }
    }

    func fetchCompletedWorkouts(on day: Date? = nil) throws -> [CompletedWorkout] {
        let request: NSFetchRequest<CompletedWorkout> = CompletedWorkout.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        if let day {
            let start = Calendar.repsync.startOfDay(for: day)
            let end = Calendar.repsync.date(byAdding: .day, value: 1, to: start) ?? start
            request.predicate = NSPredicate(format: "performedOn >= %@ AND performedOn < %@", start as NSDate, end as NSDate)
        }
        return try context.fetch(request)
    }

    func fetchCompletedWorkout(id: UUID) throws -> CompletedWorkout? {
        let request: NSFetchRequest<CompletedWorkout> = CompletedWorkout.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    func fetchCompletedExercises(workoutID: UUID) throws -> [CompletedExercise] {
        let request: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        request.predicate = NSPredicate(format: "workoutID == %@", workoutID as CVarArg)
        return try context.fetch(request)
    }

    func fetchCompletedSets(exerciseID: UUID) throws -> [CompletedSet] {
        let request: NSFetchRequest<CompletedSet> = CompletedSet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "setNumber", ascending: true)]
        request.predicate = NSPredicate(format: "exerciseID == %@", exerciseID as CVarArg)
        return try context.fetch(request)
    }

    func fetchAllCompletedWorkoutDates() throws -> Set<Date> {
        Set(try fetchCompletedWorkouts().compactMap { $0.performedOn }.map { Calendar.repsync.startOfDay(for: $0) })
    }

    func saveCompletedWorkout(from draft: ActiveWorkoutScreenState) throws {
        let workout = CompletedWorkout(context: context)
        workout.id = UUID()
        workout.name = draft.workoutName
        workout.startedAt = draft.startedAt
        workout.endedAt = Date()
        workout.performedOn = Calendar.repsync.startOfDay(for: draft.startedAt)
        workout.isQuickWorkout = draft.isQuickWorkout

        for (exerciseIndex, exerciseDraft) in draft.exercises.enumerated() where !exerciseDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let exercise = CompletedExercise(context: context)
            exercise.id = UUID()
            exercise.name = exerciseDraft.name
            exercise.orderIndex = Int64(exerciseIndex)
            exercise.trackingType = exerciseDraft.trackingType.rawValue
            exercise.workoutID = workout.id

            for setDraft in exerciseDraft.sets {
                let set = CompletedSet(context: context)
                set.id = UUID()
                set.exerciseID = exercise.id
                set.setNumber = Int64(setDraft.setNumber)
                set.previousValue = setDraft.previous.isEmpty ? nil : setDraft.previous
                set.isCompleted = setDraft.isComplete
                set.weight = Double(setDraft.weight) ?? 0
                set.reps = Int64(Int(setDraft.reps) ?? 0)
                if let totalSeconds = totalSeconds(minutes: setDraft.minutes, seconds: setDraft.seconds) {
                    set.durationSeconds = totalSeconds
                }
                if let distance = Double(setDraft.distance), distance > 0 {
                    set.distance = distance
                }
            }
        }

        try save()
    }

    func createTemplateCopy(from completedWorkoutID: UUID) throws {
        guard let completed = try fetchCompletedWorkout(id: completedWorkoutID) else { return }
        let exercises = try fetchCompletedExercises(workoutID: completedWorkoutID)
        let drafts = try exercises.map { exercise in
            let count = try exercise.id.map(fetchCompletedSets(exerciseID:)).map(\.count) ?? 0
            return WorkoutExerciseDraft(
                name: exercise.name ?? "",
                setCount: max(count, 1),
                trackingType: ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            )
        }
        _ = try upsertWorkoutTemplate(id: nil, name: completed.name ?? "Workout", exercises: drafts)
    }

    func deleteCompletedWorkout(id: UUID) throws {
        guard let completed = try fetchCompletedWorkout(id: id) else { return }
        let exercises = try fetchCompletedExercises(workoutID: id)
        for exercise in exercises {
            if let exerciseID = exercise.id {
                try fetchCompletedSets(exerciseID: exerciseID).forEach(context.delete)
            }
            context.delete(exercise)
        }
        context.delete(completed)
        try save()
    }

    func latestPreviousSummary(for exerciseName: String, setNumber: Int) throws -> String {
        let request: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        request.predicate = NSPredicate(format: "name == %@", exerciseName)
        let exercises = try context.fetch(request)

        var matches: [(workoutDate: Date, exercise: CompletedExercise, set: CompletedSet)] = []
        for exercise in exercises {
            guard let exerciseID = exercise.id,
                  let workoutID = exercise.workoutID,
                  let workout = try fetchCompletedWorkout(id: workoutID),
                  let workoutDate = workout.startedAt else { continue }

            let sets = try fetchCompletedSets(exerciseID: exerciseID)
            for set in sets where Int(set.setNumber) == setNumber {
                matches.append((workoutDate, exercise, set))
            }
        }

        guard let latest = matches.sorted(by: { $0.workoutDate > $1.workoutDate }).first else {
            return ""
        }

        let trackingType = ExerciseTrackingKind(rawValue: latest.exercise.trackingType ?? "") ?? .weightReps
        return formatCompletedSet(latest.set, trackingType: trackingType)
    }

    func exerciseSuggestions(matching query: String) throws -> [ExerciseSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var suggestionsByName: [String: ExerciseSuggestion] = [:]

        let templateRequest: NSFetchRequest<TemplateExercise> = TemplateExercise.fetchRequest()
        templateRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        templateRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", trimmed)
        for exercise in try context.fetch(templateRequest) {
            guard let name = exercise.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            let trackingType = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            suggestionsByName[name.lowercased()] = ExerciseSuggestion(name: name, trackingType: trackingType)
        }

        let completedRequest: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        completedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        completedRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", trimmed)
        for exercise in try context.fetch(completedRequest) {
            guard let name = exercise.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            if suggestionsByName[name.lowercased()] != nil {
                continue
            }
            let trackingType = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            suggestionsByName[name.lowercased()] = ExerciseSuggestion(name: name, trackingType: trackingType)
        }

        return suggestionsByName.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func makeActiveSetDrafts(for exerciseName: String, count: Int) throws -> [ActiveSetDraft] {
        let safeCount = max(count, 1)
        return try (1...safeCount).map { index in
            ActiveSetDraft(setNumber: index, previous: try latestPreviousSummary(for: exerciseName, setNumber: index))
        }
    }

    func fetchProfile() throws -> UserProfile? {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func stringPreference(for key: String) throws -> String? {
        try fetchPreference(for: key)?.stringValue
    }

    func boolPreference(for key: String) throws -> Bool? {
        try fetchPreference(for: key).map(\.boolValue)
    }

    func setStringPreference(_ value: String?, for key: String) throws {
        let preference = try fetchPreference(for: key) ?? AppPreference(context: context)
        preference.id = preference.id ?? UUID()
        preference.key = key
        preference.stringValue = value
        try save()
    }

    func setBoolPreference(_ value: Bool, for key: String) throws {
        let preference = try fetchPreference(for: key) ?? AppPreference(context: context)
        preference.id = preference.id ?? UUID()
        preference.key = key
        preference.boolValue = value
        try save()
    }

    func workoutMusicPreferences(for templateID: UUID) throws -> (provider: String?, playlistID: String?, playlistName: String?, playlistURL: String?) {
        (
            provider: try stringPreference(for: workoutMusicProviderKey(templateID)),
            playlistID: try stringPreference(for: workoutMusicPlaylistIDKey(templateID)),
            playlistName: try stringPreference(for: workoutMusicPlaylistNameKey(templateID)),
            playlistURL: try stringPreference(for: workoutMusicPlaylistURLKey(templateID))
        )
    }

    func setWorkoutMusicPreferences(
        templateID: UUID,
        provider: String?,
        playlistID: String?,
        playlistName: String?,
        playlistURL: String?
    ) throws {
        try setStringPreference(provider, for: workoutMusicProviderKey(templateID))
        try setStringPreference(playlistID, for: workoutMusicPlaylistIDKey(templateID))
        try setStringPreference(playlistName, for: workoutMusicPlaylistNameKey(templateID))
        try setStringPreference(playlistURL, for: workoutMusicPlaylistURLKey(templateID))
    }

    func upsertProfile(
        displayName: String,
        avatarPath: String?,
        workoutDays: Set<WorkoutWeekday>,
        reminderEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        reminderMessage: String
    ) throws {
        let profile = try fetchProfile() ?? UserProfile(context: context)
        profile.id = profile.id ?? UUID()
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmed.isEmpty ? nil : trimmed
        profile.avatarPath = avatarPath
        profile.reminderEnabled = reminderEnabled
        profile.reminderMessage = reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.reminderTime = Calendar.repsync.date(from: DateComponents(hour: reminderHour, minute: reminderMinute))
        profile.workoutDaysData = try? JSONEncoder().encode(workoutDays.map(\.rawValue).sorted())
        try save()
    }

    func fetchBodyweightEntries() throws -> [BodyweightEntry] {
        let request: NSFetchRequest<BodyweightEntry> = BodyweightEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "recordedOn", ascending: false)]
        return try context.fetch(request)
    }

    func fetchBodyweightEntry(id: UUID) throws -> BodyweightEntry? {
        let request: NSFetchRequest<BodyweightEntry> = BodyweightEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    func addBodyweightEntry(weight: Double, on date: Date = Date()) throws {
        let entry = BodyweightEntry(context: context)
        entry.id = UUID()
        entry.recordedOn = Calendar.repsync.startOfDay(for: date)
        entry.weight = weight
        try save()
    }

    func updateBodyweightEntry(id: UUID, weight: Double, on date: Date) throws {
        guard let entry = try fetchBodyweightEntry(id: id) else { return }
        entry.weight = weight
        entry.recordedOn = Calendar.repsync.startOfDay(for: date)
        try save()
    }

    func deleteBodyweightEntry(id: UUID) throws {
        guard let entry = try fetchBodyweightEntry(id: id) else { return }
        context.delete(entry)
        try save()
    }

    func exerciseHistory(for name: String) throws -> [ExerciseHistorySample] {
        let request: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        let exercises = try context.fetch(request)

        var samples: [ExerciseHistorySample] = []
        for exercise in exercises {
            guard let exerciseID = exercise.id,
                  let workoutID = exercise.workoutID,
                  let workout = try fetchCompletedWorkout(id: workoutID),
                  let date = workout.performedOn else { continue }

            let sets = try fetchCompletedSets(exerciseID: exerciseID)
            let trackingType = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            let metricValue: Double = {
                switch trackingType {
                case .weightReps:
                    return sets.map(\.weight).max() ?? 0
                case .duration:
                    return sets.map(\.durationSeconds).max() ?? 0
                case .durationDistance:
                    return sets.map(\.distance).max() ?? 0
                }
            }()

            samples.append(ExerciseHistorySample(
                date: date,
                workoutName: workout.name ?? "Workout",
                summary: sets.map { formatCompletedSet($0, trackingType: trackingType) }.joined(separator: ", "),
                metricValue: metricValue
            ))
        }
        return samples.sorted { $0.date > $1.date }
    }

    func makeProfileState() throws -> ProfileScreenState {
        let profile = try fetchProfile()
        let entries = try fetchBodyweightEntryModels()
        let latest = entries.first?.weightText ?? "-"
        let trendSummary = makeBodyweightTrendSummary(entries: entries)
        let trendHelperText: String? = {
            if entries.isEmpty {
                return nil
            }
            return trendSummary == nil ? "Log entries on different days to see your trend" : nil
        }()

        return ProfileScreenState(
            displayName: profile?.displayName ?? "Guest",
            avatarPath: profile?.avatarPath,
            workoutCount: try fetchCompletedWorkouts().count,
            streak: try currentWorkoutStreak(),
            latestWeight: latest,
            bodyweightTrendText: trendSummary?.text,
            bodyweightTrendIsStable: trendSummary?.isStable ?? false,
            bodyweightTrendHelperText: trendHelperText,
            chartPoints: entries.reversed().map { ChartPoint(date: $0.date, value: $0.value) },
            recentEntries: Array(entries.prefix(3)),
            workoutDays: decodeWorkoutDays(from: profile?.workoutDaysData),
            reminderEnabled: profile?.reminderEnabled ?? false,
            reminderHour: reminderComponents(from: profile?.reminderTime).hour,
            reminderMinute: reminderComponents(from: profile?.reminderTime).minute,
            reminderMessage: profile?.reminderMessage ?? "Time to train"
        )
    }

    func makeBodyweightEntriesState() throws -> BodyweightEntriesScreenState {
        let entries = try fetchBodyweightEntryModels()
        return BodyweightEntriesScreenState(entries: entries, filteredEntries: entries)
    }

    func makeHomeState(month: Date) throws -> HomeScreenState {
        let workoutDates = try fetchAllCompletedWorkoutDates()
        let monthStart = Calendar.repsync.date(from: Calendar.repsync.dateComponents([.year, .month], from: month)) ?? month
        let range = Calendar.repsync.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let firstWeekday = Calendar.repsync.component(.weekday, from: monthStart) - 1
        let leading = (0..<firstWeekday).compactMap { offset in
            Calendar.repsync.date(byAdding: .day, value: -(firstWeekday - offset), to: monthStart)
        }
        let monthDays = range.compactMap { day in
            Calendar.repsync.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        let total = leading + monthDays
        let trailingCount = (7 - (total.count % 7)) % 7
        let trailing = (1...trailingCount).compactMap { Calendar.repsync.date(byAdding: .day, value: $0, to: monthDays.last ?? monthStart) }
        let days = (leading + monthDays + trailing).map { day in
            CalendarDayModel(
                date: day,
                label: "\(Calendar.repsync.component(.day, from: day))",
                isInCurrentMonth: Calendar.repsync.isDate(day, equalTo: monthStart, toGranularity: .month),
                hasWorkout: workoutDates.contains(Calendar.repsync.startOfDay(for: day))
            )
        }
        return HomeScreenState(currentMonth: monthStart, calendarDays: days)
    }

    func makeDayViewState(for date: Date) throws -> DayViewScreenState {
        let workouts = try fetchCompletedWorkouts(on: date)
        let cards = try workouts.compactMap { workout -> CompletedWorkoutCardModel? in
            guard let workoutID = workout.id else { return nil }
            let exercises = try fetchCompletedExercises(workoutID: workoutID)
            let rows = try exercises.compactMap { exercise -> CompletedExerciseRow? in
                guard let exerciseID = exercise.id else { return nil }
                let sets = try fetchCompletedSets(exerciseID: exerciseID)
                let trackingType = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
                return CompletedExerciseRow(
                    name: exercise.name ?? "Exercise",
                    summary: sets.map { formatCompletedSet($0, trackingType: trackingType) }.joined(separator: ", ")
                )
            }

            return CompletedWorkoutCardModel(
                id: workoutID,
                title: workout.name ?? "Workout",
                durationText: formatDuration(startedAt: workout.startedAt, endedAt: workout.endedAt),
                subtitle: workout.isQuickWorkout ? "Quick Workout" : nil,
                exercises: rows
            )
        }
        return DayViewScreenState(selectedDate: date, workouts: cards)
    }

    func makeExerciseHistoryState(for exerciseName: String) throws -> ExerciseHistoryScreenState {
        let samples = try exerciseHistory(for: exerciseName)
        let points = samples.map { ChartPoint(date: $0.date, value: $0.metricValue) }.reversed()
        return ExerciseHistoryScreenState(
            exerciseName: exerciseName,
            stats: [
                ("PR", points.map(\.value).max().map(formatWeight) ?? "-"),
                ("Volume", formatWeight(samples.reduce(0) { $0 + $1.metricValue })),
                ("Sessions", "\(samples.count)")
            ],
            points: Array(points),
            sessions: samples.map {
                ExerciseSessionModel(
                    dateText: DateFormatter.repsyncShortDate.string(from: $0.date),
                    workoutName: $0.workoutName,
                    summary: $0.summary
                )
            }
        )
    }

    private func fetchBodyweightEntryModels() throws -> [BodyweightEntryModel] {
        var models: [BodyweightEntryModel] = []
        for entry in try fetchBodyweightEntries() {
            guard let id = entry.id, let date = entry.recordedOn else { continue }
            let value = entry.weight
            models.append(BodyweightEntryModel(
                id: id,
                date: date,
                dateText: DateFormatter.repsyncShortDate.string(from: date),
                weightText: "\(formatWeight(value)) lbs",
                value: value
            ))
        }
        return models
    }

    private func normalizeTemplateOrder() throws {
        let templates = try fetchWorkoutTemplates()
        for (index, template) in templates.enumerated() {
            template.orderIndex = Int64(index)
        }
        try save()
    }

    private func currentWorkoutStreak() throws -> Int {
        let dates = try fetchAllCompletedWorkoutDates().sorted(by: >)
        guard !dates.isEmpty else { return 0 }
        var streak = 0
        var cursor = Calendar.repsync.startOfDay(for: Date())
        if !dates.contains(cursor), let yesterday = Calendar.repsync.date(byAdding: .day, value: -1, to: cursor), dates.contains(yesterday) {
            cursor = yesterday
        }
        while dates.contains(cursor) {
            streak += 1
            guard let previous = Calendar.repsync.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    private func totalSeconds(minutes: String, seconds: String) -> Double? {
        let mins = Int(minutes) ?? 0
        let secs = Int(seconds) ?? 0
        let total = mins * 60 + secs
        return total > 0 ? Double(total) : nil
    }

    private func formatDuration(startedAt: Date?, endedAt: Date?) -> String {
        guard let startedAt else { return "-" }
        return formatElapsedTime(seconds: max(Int((endedAt ?? Date()).timeIntervalSince(startedAt)), 0))
    }

    private func formatCompletedSet(_ set: CompletedSet, trackingType: ExerciseTrackingKind) -> String {
        switch trackingType {
        case .weightReps:
            let weight = set.weight
            let reps = set.reps
            return "\(formatWeight(weight)) x \(reps)"
        case .duration:
            return formatElapsedTime(seconds: Int(set.durationSeconds))
        case .durationDistance:
            return "\(formatElapsedTime(seconds: Int(set.durationSeconds))) • \(formatWeight(set.distance)) mi"
        }
    }

    private func makeBodyweightTrendSummary(entries: [BodyweightEntryModel]) -> (text: String, isStable: Bool)? {
        guard entries.count >= 2 else { return nil }

        let newest = entries[0]
        let oldest = entries[entries.count - 1]
        let elapsedDays = Calendar.repsync.dateComponents([.day], from: oldest.date, to: newest.date).day ?? 0
        guard elapsedDays >= 1 else { return nil }

        let weeklyRate = ((newest.value - oldest.value) / Double(elapsedDays)) * 7
        let absoluteRate = abs(weeklyRate)

        if absoluteRate < bodyweightStableThresholdLbsPerWeek {
            return ("Holding steady", true)
        }

        let formattedRate = formatWeight(absoluteRate)
        return weeklyRate > 0
            ? ("Gaining \(formattedRate) lbs/week", false)
            : ("Losing \(formattedRate) lbs/week", false)
    }

    private func decodeWorkoutDays(from data: Data?) -> Set<WorkoutWeekday> {
        guard
            let data,
            let rawValues = try? JSONDecoder().decode([Int].self, from: data)
        else {
            return []
        }
        return Set(rawValues.compactMap(WorkoutWeekday.init(rawValue:)))
    }

    private func reminderComponents(from date: Date?) -> (hour: Int, minute: Int) {
        guard let date else { return (18, 0) }
        let components = Calendar.repsync.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 18, components.minute ?? 0)
    }

    private func fetchPreference(for key: String) throws -> AppPreference? {
        let request: NSFetchRequest<AppPreference> = AppPreference.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "key == %@", key)
        return try context.fetch(request).first
    }

    private func workoutMusicProviderKey(_ templateID: UUID) -> String {
        "workout_music_provider_\(templateID.uuidString)"
    }

    private func workoutMusicPlaylistIDKey(_ templateID: UUID) -> String {
        "workout_music_playlist_id_\(templateID.uuidString)"
    }

    private func workoutMusicPlaylistNameKey(_ templateID: UUID) -> String {
        "workout_music_playlist_name_\(templateID.uuidString)"
    }

    private func workoutMusicPlaylistURLKey(_ templateID: UUID) -> String {
        "workout_music_playlist_url_\(templateID.uuidString)"
    }
}
