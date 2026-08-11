import CoreData
import Foundation

struct ExerciseHistorySample {
    let date: Date
    let workoutName: String
    let summary: String
    let metricValue: Double
}

private struct CanonicalLiftPerformance {
    let lift: CanonicalLift
    let exerciseName: String
    let weight: Double
    let reps: Int
    let estimatedOneRepMax: Double
    let performedOn: Date
}

@MainActor
final class RepSyncStore {
    private let context: NSManagedObjectContext
    private let bodyweightStableThresholdLbsPerWeek = 0.1
    private let bodyweightTrendSmoothingFactor = 0.2
    private let bodyweightTrendMaxDailySwing = 2.5

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
            let exerciseName = normalizedExerciseName(draft.name)
            guard !exerciseName.isEmpty else { continue }
            let exercise = TemplateExercise(context: context)
            exercise.id = UUID()
            exercise.name = exerciseName
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

    func reorderWorkoutTemplates(ids: [UUID]) throws {
        let templates = try fetchWorkoutTemplates()
        let templatesByID = Dictionary(uniqueKeysWithValues: templates.compactMap { template -> (UUID, WorkoutTemplate)? in
            guard let id = template.id else { return nil }
            return (id, template)
        })

        var orderedTemplates = ids.compactMap { templatesByID[$0] }
        let reorderedIDs = Set(ids)
        orderedTemplates.append(contentsOf: templates.filter { template in
            guard let id = template.id else { return true }
            return !reorderedIDs.contains(id)
        })

        for (index, template) in orderedTemplates.enumerated() {
            template.orderIndex = Int64(index)
        }
        try save()
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
            let exerciseName = normalizedExerciseName(exerciseDraft.name)
            guard !exerciseName.isEmpty else { continue }
            let exercise = CompletedExercise(context: context)
            exercise.id = UUID()
            exercise.name = exerciseName
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

    func createTemplateCopy(from completedWorkoutID: UUID, templateName: String? = nil) throws {
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
        let resolvedName = templateName?.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try upsertWorkoutTemplate(
            id: nil,
            name: resolvedName?.isEmpty == false ? resolvedName! : (completed.name ?? "Workout"),
            exercises: drafts
        )
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

    func updateCompletedWorkoutDate(id: UUID, on date: Date) throws {
        guard let completed = try fetchCompletedWorkout(id: id) else { return }

        let targetDay = Calendar.repsync.startOfDay(for: date)
        if let startedAt = completed.startedAt {
            let timeComponents = Calendar.repsync.dateComponents([.hour, .minute, .second], from: startedAt)
            completed.startedAt = Calendar.repsync.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: timeComponents.second ?? 0, of: targetDay) ?? targetDay
        }

        if let endedAt = completed.endedAt,
           let startedAt = completed.startedAt {
            let duration = endedAt.timeIntervalSince(startedAt)
            completed.endedAt = startedAt.addingTimeInterval(max(duration, 0))
        }

        completed.performedOn = targetDay
        try save()
    }

    func latestPreviousSummary(for exerciseName: String, setNumber: Int) throws -> String {
        let canonicalName = normalizedExerciseName(exerciseName)
        let request: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        request.predicate = NSPredicate(format: "name ==[cd] %@", canonicalName)
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
        for suggestion in CanonicalLift.defaultSuggestions where suggestion.name.localizedCaseInsensitiveContains(trimmed) {
            suggestionsByName[exerciseNameMatchKey(suggestion.name)] = suggestion
        }

        let templateRequest: NSFetchRequest<TemplateExercise> = TemplateExercise.fetchRequest()
        templateRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        templateRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", trimmed)
        for exercise in try context.fetch(templateRequest) {
            guard let name = exercise.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            let trackingType = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            let canonicalName = normalizedExerciseName(name)
            suggestionsByName[exerciseNameMatchKey(canonicalName)] = ExerciseSuggestion(name: canonicalName, trackingType: trackingType)
        }

        let completedRequest: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        completedRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        completedRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", trimmed)
        for exercise in try context.fetch(completedRequest) {
            guard let name = exercise.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            let canonicalName = normalizedExerciseName(name)
            let key = exerciseNameMatchKey(canonicalName)
            if suggestionsByName[key] != nil {
                continue
            }
            let trackingType = ExerciseTrackingKind(rawValue: exercise.trackingType ?? "") ?? .weightReps
            suggestionsByName[key] = ExerciseSuggestion(name: canonicalName, trackingType: trackingType)
        }

        return suggestionsByName.values.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func exactExerciseSuggestion(matching query: String) throws -> ExerciseSuggestion? {
        let matchKey = exerciseNameMatchKey(query)
        guard !matchKey.isEmpty else { return nil }

        return try exerciseSuggestions(matching: normalizedExerciseName(query)).first {
            exerciseNameMatchKey($0.name) == matchKey
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

    func setBiometricPreferences(height: String, birthdate: Date?, sex: BiologicalSex) throws {
        try setStringPreference(height.trimmingCharacters(in: .whitespacesAndNewlines), for: profileHeightKey)
        try setStringPreference(birthdate.map(DateFormatter.repsyncISODate.string(from:)) ?? "", for: profileBirthdateKey)
        try setStringPreference(sex.rawValue, for: profileSexKey)
    }

    func leaderboardTrackedLifts() throws -> Set<CanonicalLift> {
        guard let rawValue = try stringPreference(for: leaderboardTrackedLiftsKey),
              !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Set(CanonicalLift.defaultTrackedLifts)
        }

        let lifts = rawValue
            .split(separator: ",")
            .compactMap { CanonicalLift(rawValue: String($0)) }
        return Set(lifts)
    }

    func setLeaderboardTrackedLifts(_ lifts: Set<CanonicalLift>) throws {
        let rawValue = CanonicalLift.allCases
            .filter { lifts.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")
        try setStringPreference(rawValue, for: leaderboardTrackedLiftsKey)
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

    func addBodyweightEntry(weight: Double, on date: Date = Date(), photoPath: String? = nil) throws {
        let entry = BodyweightEntry(context: context)
        entry.id = UUID()
        entry.recordedOn = Calendar.repsync.startOfDay(for: date)
        entry.weight = weight
        entry.photoPath = photoPath
        try save()
    }

    func updateBodyweightEntry(id: UUID, weight: Double, on date: Date, photoPath: String? = nil) throws {
        guard let entry = try fetchBodyweightEntry(id: id) else { return }
        entry.weight = weight
        entry.recordedOn = Calendar.repsync.startOfDay(for: date)
        entry.photoPath = photoPath
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

    func makeProfileState(bodyweightChartRange: BodyweightChartRange = .thirtyDays, currentDate: Date = Date()) throws -> ProfileScreenState {
        let profile = try fetchProfile()
        let entries = try fetchBodyweightEntryModels()
        let latest = entries.first?.weightText ?? "-"
        let trendSummary = makeBodyweightTrendSummary(entries: entries)
        let workoutDays = decodeWorkoutDays(from: profile?.workoutDaysData)
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
            streak: try currentWorkoutStreak(scheduledDays: workoutDays, currentDate: currentDate),
            height: formattedProfileHeight(try stringPreference(for: profileHeightKey)),
            age: formattedProfileAge(from: try profileBirthdate(), currentDate: currentDate),
            birthdate: try profileBirthdate(),
            sex: try stringPreference(for: profileSexKey).flatMap(BiologicalSex.init(rawValue:)) ?? .male,
            latestWeight: latest,
            bodyweightTrendText: trendSummary?.text,
            bodyweightTrendIsStable: trendSummary?.isStable ?? false,
            bodyweightTrendHelperText: trendHelperText,
            bodyweightTrendingWeightText: makeTrendingWeightText(entries: entries),
            bodyweightTenDayLowText: makeTenDayLowText(entries: entries),
            bodyweightChartRange: bodyweightChartRange,
            chartPoints: bodyweightChartPoints(entries: entries, range: bodyweightChartRange),
            trendChartPoints: bodyweightTrendChartPoints(entries: entries, range: bodyweightChartRange),
            recentEntries: Array(entries.prefix(3)),
            workoutDays: workoutDays,
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

    func makeLeaderboardState(currentDate: Date = Date()) throws -> LeaderboardScreenState {
        let entries = try fetchBodyweightEntryModels()
        let bodyweight = entries.first?.value
        let sex = try stringPreference(for: profileSexKey).flatMap(BiologicalSex.init(rawValue:)) ?? .male
        let birthdate = try profileBirthdate()
        let age = birthdate.flatMap { Calendar.repsync.dateComponents([.year], from: $0, to: currentDate).year }
        let height = formattedProfileHeight(try stringPreference(for: profileHeightKey))
        let performances = try bestCanonicalLiftPerformances()
        let completedWorkouts = try fetchCompletedWorkouts()

        let rows = StrengthMovementCategory.allCases.map { category in
            makeLeaderboardMovementRow(
                category: category,
                performances: performances,
                bodyweight: bodyweight,
                sex: sex,
                age: age
            )
        }
        let rankedRows = rows.filter { $0.rank != .unranked }
        let averageScore = rankedRows.isEmpty ? 0 : rankedRows.reduce(0) { $0 + $1.rank.score } / Double(rankedRows.count)
        let overallRank = rankLevel(forScore: averageScore)
        let bodyweightText = bodyweight.map { "\(formatBodyweight($0)) lbs" } ?? "-"
        let ageText = age.map(String.init) ?? "-"
        let classSummary = "\(sex.rawValue) • \(ageText) • \(bodyweightText)"
        let heightSuffix = height.isEmpty ? "" : " • \(height)"

        return LeaderboardScreenState(
            classSummary: classSummary + heightSuffix,
            bodyweightClass: bodyweight.map(bodyweightClassText) ?? "-",
            overallRank: overallRank,
            overallScoreText: rankedRows.isEmpty ? "Log a ranked lift" : "\(formatWeight(averageScore)) / 5",
            xpProgress: try makeLeaderboardXPProgress(from: completedWorkouts),
            rows: rows
        )
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
        let trailing = trailingCount == 0
            ? []
            : (1...trailingCount).compactMap { Calendar.repsync.date(byAdding: .day, value: $0, to: monthDays.last ?? monthStart) }
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
                let sortedSets = sets.sorted { $0.setNumber < $1.setNumber }
                let bestSetID = bestSet(in: sortedSets, trackingType: trackingType)?.id
                return CompletedExerciseRow(
                    name: exercise.name ?? "Exercise",
                    trackingType: trackingType,
                    sets: sortedSets.enumerated().map { index, set in
                        CompletedSetRow(
                            setNumber: index + 1,
                            summary: formatCompletedSet(set, trackingType: trackingType),
                            isBestSet: set.id == bestSetID && sortedSets.count > 1
                        )
                    }
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

    private func bestCanonicalLiftPerformances() throws -> [CanonicalLift: CanonicalLiftPerformance] {
        let request: NSFetchRequest<CompletedExercise> = CompletedExercise.fetchRequest()
        request.predicate = NSPredicate(format: "trackingType == %@", ExerciseTrackingKind.weightReps.rawValue)
        let exercises = try context.fetch(request)

        var bestByLift: [CanonicalLift: CanonicalLiftPerformance] = [:]
        for exercise in exercises {
            guard let exerciseID = exercise.id,
                  let exerciseName = exercise.name,
                  let lift = CanonicalLift.match(exerciseName: exerciseName),
                  let workoutID = exercise.workoutID,
                  let workout = try fetchCompletedWorkout(id: workoutID),
                  let performedOn = workout.performedOn else {
                continue
            }

            let completedSets = try fetchCompletedSets(exerciseID: exerciseID)
                .filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }
            for set in completedSets {
                let reps = Int(set.reps)
                let estimatedOneRepMax = estimatedOneRepMax(weight: set.weight, reps: reps)
                let performance = CanonicalLiftPerformance(
                    lift: lift,
                    exerciseName: exerciseName,
                    weight: set.weight,
                    reps: reps,
                    estimatedOneRepMax: estimatedOneRepMax,
                    performedOn: performedOn
                )
                if let current = bestByLift[lift] {
                    if performance.estimatedOneRepMax > current.estimatedOneRepMax ||
                        (performance.estimatedOneRepMax == current.estimatedOneRepMax && performance.performedOn > current.performedOn) {
                        bestByLift[lift] = performance
                    }
                } else {
                    bestByLift[lift] = performance
                }
            }
        }

        return bestByLift
    }

    private func makeLeaderboardXPProgress(from completedWorkouts: [CompletedWorkout]) throws -> LeaderboardXPProgress {
        let workoutDays = Set(completedWorkouts.compactMap { workout in
            workout.performedOn.map { Calendar.repsync.startOfDay(for: $0) }
        })
        let workoutDayXP = workoutDays.count * 100
        let consistencyXP = consistencyBonusXP(for: workoutDays)
        let progressionXP = try liftProgressionXP()
        let totalXP = workoutDayXP + consistencyXP + progressionXP

        return leaderboardXPProgress(totalXP: totalXP)
    }

    private func consistencyBonusXP(for workoutDays: Set<Date>) -> Int {
        let sortedDays = workoutDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var bonus = 0
        var streakLength = 1
        var previousDay = sortedDays[0]

        for day in sortedDays.dropFirst() {
            let expectedNextDay = Calendar.repsync.date(byAdding: .day, value: 1, to: previousDay)
            if let expectedNextDay, Calendar.repsync.isDate(day, inSameDayAs: expectedNextDay) {
                streakLength += 1
                bonus += min(100, 15 + ((streakLength - 1) * 10))
            } else {
                streakLength = 1
            }
            previousDay = day
        }

        return bonus
    }

    private func liftProgressionXP() throws -> Int {
        let workouts = try fetchCompletedWorkouts().sorted {
            ($0.performedOn ?? $0.startedAt ?? .distantPast) < ($1.performedOn ?? $1.startedAt ?? .distantPast)
        }
        var bestOneRepMaxByLift: [CanonicalLift: Double] = [:]
        var xp = 0

        for workout in workouts {
            guard let workoutID = workout.id else { continue }
            let exercises = try fetchCompletedExercises(workoutID: workoutID)
            for exercise in exercises {
                guard let exerciseID = exercise.id,
                      let exerciseName = exercise.name,
                      let lift = CanonicalLift.match(exerciseName: exerciseName) else {
                    continue
                }

                let sets = try fetchCompletedSets(exerciseID: exerciseID)
                    .filter { $0.isCompleted && $0.weight > 0 && $0.reps > 0 }

                for set in sets {
                    let oneRepMax = estimatedOneRepMax(weight: set.weight, reps: Int(set.reps))
                    let currentBest = bestOneRepMaxByLift[lift] ?? 0
                    guard oneRepMax > currentBest else { continue }

                    if currentBest > 0 {
                        let improvement = oneRepMax - currentBest
                        xp += 75 + min(225, Int(improvement.rounded(.down)) * 4)
                    }
                    bestOneRepMaxByLift[lift] = oneRepMax
                }
            }
        }

        return xp
    }

    private func leaderboardXPProgress(totalXP: Int) -> LeaderboardXPProgress {
        var level = 1
        var spentXP = 0

        while level < 100 {
            let requiredXP = leaderboardXPRequired(forLevel: level)
            guard totalXP >= spentXP + requiredXP else { break }
            spentXP += requiredXP
            level += 1
        }

        let nextLevelXP = level >= 100 ? 0 : leaderboardXPRequired(forLevel: level)
        let currentLevelXP = level >= 100 ? 0 : max(totalXP - spentXP, 0)
        let progress = level >= 100 ? 1 : min(Double(currentLevelXP) / Double(max(nextLevelXP, 1)), 1)

        return LeaderboardXPProgress(
            level: level,
            totalXP: totalXP,
            currentLevelXP: currentLevelXP,
            nextLevelXP: nextLevelXP,
            progress: progress,
            title: "Level \(level)",
            iconName: leaderboardLevelIconName(for: level)
        )
    }

    private func leaderboardXPRequired(forLevel level: Int) -> Int {
        let clampedLevel = max(1, min(level, 99))
        return 100 + Int(pow(Double(clampedLevel), 1.45) * 38)
    }

    private func leaderboardLevelIconName(for level: Int) -> String {
        switch level {
        case 90...100: return "trophy.fill"
        case 80..<90: return "crown.fill"
        case 70..<80: return "star.circle.fill"
        case 60..<70: return "shield.fill"
        case 50..<60: return "bolt.shield.fill"
        case 40..<50: return "flame.fill"
        case 30..<40: return "medal.fill"
        case 20..<30: return "bolt.fill"
        case 10..<20: return "dumbbell.fill"
        default: return "figure.walk"
        }
    }

    private func makeLeaderboardLiftRow(
        lift: CanonicalLift,
        performance: CanonicalLiftPerformance?,
        bodyweight: Double?,
        sex: BiologicalSex,
        age: Int?
    ) -> LeaderboardLiftRow {
        guard let performance else {
            return LeaderboardLiftRow(
                id: lift.movementCategory,
                category: lift.movementCategory,
                rank: .unranked,
                bestSetText: "No matched lift",
                estimatedOneRepMaxText: "-",
                nextRankText: "Log \(lift.displayName)",
                sourceExerciseName: nil,
                contributingExercisesText: lift.movementCategory.contributingExerciseText
            )
        }

        let bestSetText = "\(formatWeight(performance.weight)) x \(performance.reps)"
        let oneRepMaxText = "\(formatWeight(performance.estimatedOneRepMax)) lb"

        guard let bodyweight, bodyweight > 0 else {
            return LeaderboardLiftRow(
                id: lift.movementCategory,
                category: lift.movementCategory,
                rank: .unranked,
                bestSetText: bestSetText,
                estimatedOneRepMaxText: oneRepMaxText,
                nextRankText: "Log bodyweight to rank",
                sourceExerciseName: performance.exerciseName,
                contributingExercisesText: lift.movementCategory.contributingExerciseText
            )
        }

        let rank = strengthRank(
            lift: lift,
            estimatedOneRepMax: performance.estimatedOneRepMax,
            bodyweight: bodyweight,
            sex: sex,
            age: age
        )
        let nextRankText = nextStrengthRankTarget(
            lift: lift,
            rank: rank,
            bodyweight: bodyweight,
            sex: sex,
            age: age
        )

        return LeaderboardLiftRow(
            id: lift.movementCategory,
            category: lift.movementCategory,
            rank: rank,
            bestSetText: bestSetText,
            estimatedOneRepMaxText: oneRepMaxText,
            nextRankText: nextRankText,
            sourceExerciseName: performance.exerciseName,
            contributingExercisesText: lift.movementCategory.contributingExerciseText
        )
    }

    private func makeLeaderboardMovementRow(
        category: StrengthMovementCategory,
        performances: [CanonicalLift: CanonicalLiftPerformance],
        bodyweight: Double?,
        sex: BiologicalSex,
        age: Int?
    ) -> LeaderboardLiftRow {
        let liftRows = category.contributingLifts.map { lift in
            makeLeaderboardLiftRow(
                lift: lift,
                performance: performances[lift],
                bodyweight: bodyweight,
                sex: sex,
                age: age
            )
        }

        let bestRow = liftRows.max { lhs, rhs in
            if lhs.rank.score == rhs.rank.score {
                return oneRepMaxValue(from: lhs.estimatedOneRepMaxText) < oneRepMaxValue(from: rhs.estimatedOneRepMaxText)
            }
            return lhs.rank.score < rhs.rank.score
        }

        guard let bestRow, bestRow.rank != .unranked else {
            return LeaderboardLiftRow(
                id: category,
                category: category,
                rank: .unranked,
                bestSetText: "No matched exercise",
                estimatedOneRepMaxText: "-",
                nextRankText: "Log \(category.contributingLifts.first?.displayName ?? category.displayName)",
                sourceExerciseName: nil,
                contributingExercisesText: category.contributingExerciseText
            )
        }

        return LeaderboardLiftRow(
            id: category,
            category: category,
            rank: bestRow.rank,
            bestSetText: bestRow.bestSetText,
            estimatedOneRepMaxText: bestRow.estimatedOneRepMaxText,
            nextRankText: bestRow.nextRankText,
            sourceExerciseName: bestRow.sourceExerciseName,
            contributingExercisesText: category.contributingExerciseText
        )
    }

    private func oneRepMaxValue(from text: String) -> Double {
        Double(text.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()) ?? 0
    }

    private func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 1 else { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    private func strengthRank(
        lift: CanonicalLift,
        estimatedOneRepMax: Double,
        bodyweight: Double,
        sex: BiologicalSex,
        age: Int?
    ) -> StrengthRankLevel {
        let adjustedBodyweight = bodyweight * ageFactor(for: age)
        guard adjustedBodyweight > 0 else { return .unranked }
        let ratio = estimatedOneRepMax / adjustedBodyweight
        let thresholds = strengthRatioThresholds(lift: lift, sex: sex)

        if ratio >= thresholds.elite { return .elite }
        if ratio >= thresholds.advanced { return .advanced }
        if ratio >= thresholds.intermediate { return .intermediate }
        if ratio >= thresholds.novice { return .novice }
        return .untrained
    }

    private func nextStrengthRankTarget(
        lift: CanonicalLift,
        rank: StrengthRankLevel,
        bodyweight: Double,
        sex: BiologicalSex,
        age: Int?
    ) -> String? {
        let thresholds = strengthRatioThresholds(lift: lift, sex: sex)
        let next: (label: String, ratio: Double)?
        switch rank {
        case .unranked:
            next = ("Novice", thresholds.novice)
        case .untrained:
            next = ("Novice", thresholds.novice)
        case .novice:
            next = ("Intermediate", thresholds.intermediate)
        case .intermediate:
            next = ("Advanced", thresholds.advanced)
        case .advanced:
            next = ("Elite", thresholds.elite)
        case .elite:
            next = nil
        }

        guard let next else { return "Top offline rank" }
        let target = (bodyweight * ageFactor(for: age) * next.ratio / 5).rounded() * 5
        return "\(formatWeight(target)) lb for \(next.label)"
    }

    private func strengthRatioThresholds(
        lift: CanonicalLift,
        sex: BiologicalSex
    ) -> (novice: Double, intermediate: Double, advanced: Double, elite: Double) {
        switch (lift, sex) {
        case (.benchPress, .male): return (0.75, 1.00, 1.50, 2.00)
        case (.benchPress, .female): return (0.40, 0.65, 1.00, 1.35)
        case (.squat, .male): return (1.00, 1.50, 2.00, 2.50)
        case (.squat, .female): return (0.75, 1.00, 1.50, 2.00)
        case (.deadlift, .male): return (1.25, 1.75, 2.50, 3.00)
        case (.deadlift, .female): return (1.00, 1.25, 2.00, 2.50)
        case (.overheadPress, .male): return (0.45, 0.65, 0.90, 1.20)
        case (.overheadPress, .female): return (0.30, 0.45, 0.65, 0.90)
        case (.barbellRow, .male): return (0.70, 1.00, 1.30, 1.60)
        case (.barbellRow, .female): return (0.45, 0.70, 1.00, 1.25)
        case (.hackSquat, .male): return (1.20, 1.75, 2.40, 3.00)
        case (.hackSquat, .female): return (0.90, 1.30, 1.85, 2.35)
        case (.barbellCurl, .male): return (0.30, 0.45, 0.65, 0.85)
        case (.barbellCurl, .female): return (0.18, 0.30, 0.45, 0.60)
        case (.dumbbellCurl, .male): return (0.16, 0.24, 0.34, 0.45)
        case (.dumbbellCurl, .female): return (0.10, 0.16, 0.24, 0.32)
        case (.tricepExtension, .male): return (0.25, 0.40, 0.60, 0.80)
        case (.tricepExtension, .female): return (0.16, 0.28, 0.42, 0.58)
        case (.seatedCableRow, .male): return (0.65, 0.95, 1.30, 1.65)
        case (.seatedCableRow, .female): return (0.45, 0.70, 1.00, 1.30)
        case (.latPulldown, .male): return (0.55, 0.80, 1.10, 1.45)
        case (.latPulldown, .female): return (0.35, 0.55, 0.85, 1.10)
        case (.latPushdown, .male): return (0.25, 0.40, 0.60, 0.80)
        case (.latPushdown, .female): return (0.16, 0.28, 0.42, 0.58)
        case (.cableKickback, .male): return (0.12, 0.20, 0.30, 0.42)
        case (.cableKickback, .female): return (0.10, 0.18, 0.28, 0.38)
        case (.hipThrust, .male): return (1.00, 1.50, 2.20, 2.80)
        case (.hipThrust, .female): return (0.85, 1.25, 1.90, 2.50)
        case (.legExtension, .male): return (0.55, 0.85, 1.20, 1.60)
        case (.legExtension, .female): return (0.40, 0.65, 0.95, 1.25)
        case (.legPress, .male): return (1.50, 2.25, 3.00, 3.75)
        case (.legPress, .female): return (1.10, 1.70, 2.35, 3.00)
        case (.legCurl, .male): return (0.35, 0.55, 0.80, 1.05)
        case (.legCurl, .female): return (0.28, 0.45, 0.68, 0.90)
        case (.calfRaise, .male): return (0.80, 1.20, 1.70, 2.25)
        case (.calfRaise, .female): return (0.60, 0.95, 1.35, 1.80)
        case (.legRaise, .male): return (0.05, 0.12, 0.25, 0.40)
        case (.legRaise, .female): return (0.05, 0.10, 0.20, 0.34)
        case (.chestPress, .male): return (0.65, 0.95, 1.35, 1.75)
        case (.chestPress, .female): return (0.38, 0.60, 0.90, 1.20)
        case (.chestFly, .male): return (0.22, 0.35, 0.52, 0.70)
        case (.chestFly, .female): return (0.14, 0.24, 0.36, 0.50)
        case (.lateralRaise, .male): return (0.10, 0.16, 0.24, 0.34)
        case (.lateralRaise, .female): return (0.06, 0.11, 0.18, 0.26)
        case (.romanianDeadlift, .male): return (0.90, 1.35, 1.90, 2.40)
        case (.romanianDeadlift, .female): return (0.70, 1.05, 1.55, 2.00)
        case (.backExtension, .male): return (0.30, 0.55, 0.90, 1.25)
        case (.backExtension, .female): return (0.20, 0.40, 0.70, 1.00)
        }
    }

    private func ageFactor(for age: Int?) -> Double {
        guard let age else { return 1.0 }
        switch age {
        case ..<20: return 0.90
        case 20..<40: return 1.00
        case 40..<50: return 0.92
        case 50..<60: return 0.84
        case 60..<70: return 0.76
        default: return 0.68
        }
    }

    private func rankLevel(forScore score: Double) -> StrengthRankLevel {
        switch score {
        case 4.5...: return .elite
        case 3.5..<4.5: return .advanced
        case 2.5..<3.5: return .intermediate
        case 1.5..<2.5: return .novice
        case 0.5..<1.5: return .untrained
        default: return .unranked
        }
    }

    private func bodyweightClassText(_ bodyweight: Double) -> String {
        let classes: [Double] = [114, 123, 132, 148, 165, 181, 198, 220, 242, 275, 308]
        if let upperBound = classes.first(where: { bodyweight <= $0 }) {
            return "\(Int(upperBound)) lb class"
        }
        return "SHW"
    }

    private func fetchBodyweightEntryModels() throws -> [BodyweightEntryModel] {
        var models: [BodyweightEntryModel] = []
        let entries = try fetchBodyweightEntries()
        for (index, entry) in entries.enumerated() {
            guard let id = entry.id, let date = entry.recordedOn else { continue }
            let value = entry.weight
            let previousValue = entries.indices.contains(index + 1) ? entries[index + 1].weight : nil
            let fluctuation = previousValue.map { value - $0 }
            let roundedFluctuation = fluctuation.map { (abs($0) * 10).rounded() / 10 }
            let roundedFluctuationValue = roundedFluctuation ?? 0
            let fluctuationText = formatBodyweight(roundedFluctuationValue)
            let fluctuationDirection: BodyweightFluctuationDirection? = {
                guard let fluctuation, roundedFluctuationValue > 0 else { return .flat }
                return fluctuation > 0 ? .up : .down
            }()
            models.append(BodyweightEntryModel(
                id: id,
                date: date,
                dateText: DateFormatter.repsyncShortDate.string(from: date),
                weightText: "\(formatBodyweight(value)) lbs",
                fluctuationText: fluctuationText,
                fluctuationDirection: fluctuationDirection,
                value: value,
                photoPath: entry.photoPath
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

    private func currentWorkoutStreak(scheduledDays: Set<WorkoutWeekday>, currentDate: Date) throws -> Int {
        let dates = try fetchAllCompletedWorkoutDates()
        guard !dates.isEmpty else { return 0 }

        guard !scheduledDays.isEmpty else {
            return calendarDayWorkoutStreak(dates: dates, currentDate: currentDate)
        }

        var streak = 0
        var cursor = Calendar.repsync.startOfDay(for: currentDate)
        let todayWeekday = workoutWeekday(for: cursor)

        if !scheduledDays.contains(todayWeekday) || !dates.contains(cursor) {
            guard let previousScheduledDate = previousScheduledWorkoutDate(before: cursor, scheduledDays: scheduledDays) else {
                return 0
            }
            cursor = previousScheduledDate
        }

        while scheduledDays.contains(workoutWeekday(for: cursor)) && dates.contains(cursor) {
            streak += 1
            guard let previous = previousScheduledWorkoutDate(before: cursor, scheduledDays: scheduledDays) else { break }
            cursor = previous
        }

        return streak
    }

    private func calendarDayWorkoutStreak(dates: Set<Date>, currentDate: Date) -> Int {
        var streak = 0
        var cursor = Calendar.repsync.startOfDay(for: currentDate)
        if !dates.contains(cursor),
           let yesterday = Calendar.repsync.date(byAdding: .day, value: -1, to: cursor),
           dates.contains(yesterday) {
            cursor = yesterday
        }

        while dates.contains(cursor) {
            streak += 1
            guard let previous = Calendar.repsync.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    private func previousScheduledWorkoutDate(before date: Date, scheduledDays: Set<WorkoutWeekday>) -> Date? {
        guard !scheduledDays.isEmpty else { return nil }

        var cursor = Calendar.repsync.startOfDay(for: date)
        for _ in 0..<7 {
            guard let previous = Calendar.repsync.date(byAdding: .day, value: -1, to: cursor) else { return nil }
            cursor = previous
            if scheduledDays.contains(workoutWeekday(for: cursor)) {
                return cursor
            }
        }

        return nil
    }

    private func workoutWeekday(for date: Date) -> WorkoutWeekday {
        let rawValue = Calendar.repsync.component(.weekday, from: date)
        return WorkoutWeekday(rawValue: rawValue) ?? .sunday
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

    private func bestSet(in sets: [CompletedSet], trackingType: ExerciseTrackingKind) -> CompletedSet? {
        switch trackingType {
        case .weightReps:
            return sets.max {
                if $0.weight == $1.weight {
                    return $0.reps < $1.reps
                }
                return $0.weight < $1.weight
            }
        case .duration:
            return sets.max { $0.durationSeconds < $1.durationSeconds }
        case .durationDistance:
            return sets.max {
                if $0.distance == $1.distance {
                    return $0.durationSeconds < $1.durationSeconds
                }
                return $0.distance < $1.distance
            }
        }
    }

    private func makeBodyweightTrendSummary(entries: [BodyweightEntryModel]) -> (text: String, isStable: Bool)? {
        let trendSamples = bodyweightTrendSamples(entries: entries)
        guard let firstSample = trendSamples.first,
              let latestSample = trendSamples.last,
              trendSamples.count >= 2 else {
            return nil
        }

        let daySpan = Calendar.repsync.dateComponents([.day], from: firstSample.date, to: latestSample.date).day ?? 0
        guard daySpan > 0 else { return nil }

        let weeklyRate = ((latestSample.value - firstSample.value) / Double(daySpan)) * 7
        let roundedRate = (weeklyRate * 10).rounded() / 10
        let absoluteRate = abs(roundedRate)

        if absoluteRate < bodyweightStableThresholdLbsPerWeek {
            return ("Maintaining 0.0 lbs/week", true)
        }

        let formattedRate = formatWeight(absoluteRate)
        return weeklyRate > 0
            ? ("Gaining \(formattedRate) lbs/week", false)
            : ("Losing \(formattedRate) lbs/week", false)
    }

    private func bodyweightTrendSamples(entries: [BodyweightEntryModel]) -> [(date: Date, value: Double)] {
        guard let newestDate = entries.map(\.date).max(),
              let windowStart = Calendar.repsync.date(byAdding: .day, value: -14, to: newestDate) else {
            return []
        }

        let dailySamples = bodyweightDailySamples(entries: entries, startDate: windowStart, endDate: newestDate)
        return smoothedBodyweightSamples(dailySamples)
    }

    private func makeTrendingWeightText(entries: [BodyweightEntryModel]) -> String? {
        let samples = bodyweightTrendSamples(entries: entries)
        guard let latestTrend = samples.last else { return nil }

        return "\(formatBodyweight(latestTrend.value)) lbs"
    }

    private func smoothedBodyweightSamples(_ dailySamples: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
        guard let firstSample = dailySamples.first else { return [] }

        var trendValue = firstSample.value
        var smoothedSamples = [(date: Date, value: Double)]()
        smoothedSamples.append((date: firstSample.date, value: trendValue))

        for sample in dailySamples.dropFirst() {
            let cappedValue = min(
                max(sample.value, trendValue - bodyweightTrendMaxDailySwing),
                trendValue + bodyweightTrendMaxDailySwing
            )
            trendValue += bodyweightTrendSmoothingFactor * (cappedValue - trendValue)
            smoothedSamples.append((date: sample.date, value: trendValue))
        }

        return smoothedSamples
    }

    private func makeTenDayLowText(entries: [BodyweightEntryModel]) -> String? {
        guard let newestDate = entries.map(\.date).max(),
              let windowStart = Calendar.repsync.date(byAdding: .day, value: -9, to: newestDate) else {
            return nil
        }

        guard let low = bodyweightDailySamples(entries: entries, startDate: windowStart, endDate: newestDate)
            .min(by: { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.date < rhs.date
                }
                return lhs.value < rhs.value
            }) else {
            return nil
        }

        return "\(formatBodyweight(low.value)) lbs on \(DateFormatter.repsyncShortDate.string(from: low.date))"
    }

    private func bodyweightDailySamples(entries: [BodyweightEntryModel], startDate: Date, endDate: Date) -> [(date: Date, value: Double)] {
        let entriesInWindow = entries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }
        let valuesByDay = Dictionary(grouping: entriesInWindow) { entry in
            Calendar.repsync.startOfDay(for: entry.date)
        }

        return valuesByDay.map { date, entries in
            let average = entries.reduce(0) { $0 + $1.value } / Double(entries.count)
            return (date: date, value: average)
        }
        .sorted { $0.date < $1.date }
    }

    private func bodyweightChartPoints(entries: [BodyweightEntryModel], range: BodyweightChartRange) -> [ChartPoint] {
        let dailySamples = bodyweightDailySamples(entries: entries, range: range)
        let bucketedSamples = downsampleBodyweightSamples(dailySamples, maxPointCount: 30)

        return bucketedSamples.map { sample in
            ChartPoint(date: sample.date, value: sample.value)
        }
    }

    private func bodyweightTrendChartPoints(entries: [BodyweightEntryModel], range: BodyweightChartRange) -> [ChartPoint] {
        let dailySamples = bodyweightDailySamples(entries: entries, range: range)
        let smoothedSamples = smoothedBodyweightSamples(dailySamples)
        let bucketedSamples = downsampleBodyweightSamples(smoothedSamples, maxPointCount: 30)

        return bucketedSamples.map { sample in
            ChartPoint(date: sample.date, value: sample.value)
        }
    }

    private func bodyweightDailySamples(entries: [BodyweightEntryModel], range: BodyweightChartRange) -> [(date: Date, value: Double)] {
        guard let newestDate = entries.map(\.date).max() else { return [] }

        let windowStart = range.dayCount.flatMap { dayCount in
            Calendar.repsync.date(byAdding: .day, value: -(dayCount - 1), to: newestDate)
        }

        let entriesInWindow = entries.filter { entry in
            guard let windowStart else { return entry.date <= newestDate }
            return entry.date >= windowStart && entry.date <= newestDate
        }
        let valuesByDay = Dictionary(grouping: entriesInWindow) { entry in
            Calendar.repsync.startOfDay(for: entry.date)
        }

        return valuesByDay.map { date, entries in
            let average = entries.reduce(0) { $0 + $1.value } / Double(entries.count)
            return (date: date, value: average)
        }
        .sorted { $0.date < $1.date }
    }

    private func downsampleBodyweightSamples(_ samples: [(date: Date, value: Double)], maxPointCount: Int) -> [(date: Date, value: Double)] {
        guard samples.count > maxPointCount, maxPointCount > 1 else { return samples }

        return (0..<maxPointCount).compactMap { bucketIndex in
            let startIndex = Int((Double(bucketIndex) * Double(samples.count)) / Double(maxPointCount))
            let endIndex = Int((Double(bucketIndex + 1) * Double(samples.count)) / Double(maxPointCount))
            let bucket = Array(samples[startIndex..<max(endIndex, startIndex + 1)])
            guard !bucket.isEmpty else { return nil }

            let averageWeight = bucket.reduce(0) { $0 + $1.value } / Double(bucket.count)
            return (date: bucket[bucket.count / 2].date, value: averageWeight)
        }
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

    private func profileBirthdate() throws -> Date? {
        guard let value = try stringPreference(for: profileBirthdateKey),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return DateFormatter.repsyncISODate.date(from: value)
    }

    private func formattedProfileAge(from birthdate: Date?, currentDate: Date) -> String {
        guard let birthdate else { return "" }
        let age = Calendar.repsync.dateComponents([.year], from: birthdate, to: currentDate).year ?? 0
        return age >= 0 ? "\(age)" : ""
    }

    private func formattedProfileHeight(_ storedHeight: String?) -> String {
        guard let storedHeight,
              let totalInches = Double(storedHeight),
              totalInches > 0 else {
            return ""
        }

        let roundedHalfInches = (totalInches * 2).rounded() / 2
        let feet = Int(roundedHalfInches / 12)
        let inches = roundedHalfInches - Double(feet * 12)
        return "\(feet)'\(formatWeight(inches))\""
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

    private let profileHeightKey = "profile_height"
    private let profileBirthdateKey = "profile_birthdate"
    private let profileSexKey = "profile_sex"
    private let leaderboardTrackedLiftsKey = "leaderboard_tracked_lifts"

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
