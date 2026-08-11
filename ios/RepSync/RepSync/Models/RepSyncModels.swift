import Foundation
import UIKit

enum RepSyncTab: String, CaseIterable, Hashable {
    case home = "Home"
    case leaderboard = "Leaderboard"
    case profile = "Profile"
}

enum MusicProvider: String, CaseIterable, Identifiable, Codable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"

    var id: String { rawValue }
}

enum AppleMusicConnectionState: Equatable {
    case notConnected
    case refreshing
    case ready
    case noLibrary
    case unsubscribed
    case limited
    case authorizationDenied
    case deviceUnavailable
    case libraryUnavailable
}

enum RepSyncRoute: Hashable {
    case workouts
    case workoutEditor
    case activeWorkout
    case dayView
    case exerciseHistory
    case bodyweightEntries
    case editProfile
    case rankedMovements
}

enum ExerciseTrackingKind: String, CaseIterable, Identifiable, Codable {
    case weightReps = "weight_reps"
    case duration = "duration"
    case durationDistance = "duration_distance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weightReps: return "Weight + Reps"
        case .duration: return "Time"
        case .durationDistance: return "Pace + Dist"
        }
    }
}

enum WorkoutWeekday: Int, CaseIterable, Identifiable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Su"
        case .monday: return "Mo"
        case .tuesday: return "Tu"
        case .wednesday: return "We"
        case .thursday: return "Th"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        }
    }

    var fullLabel: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

enum BiologicalSex: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

struct ActiveWorkoutBannerModel {
    let workoutName: String
    let elapsedText: String
}

struct CalendarDayModel: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let isInCurrentMonth: Bool
    let hasWorkout: Bool
}

struct HomeScreenState {
    var currentMonth: Date
    var calendarDays: [CalendarDayModel]

    var monthTitle: String {
        DateFormatter.repsyncMonthYear.string(from: currentMonth)
    }
}

struct WorkoutListItem: Identifiable {
    let id: UUID
    let name: String
    let exerciseCount: Int
    let exercises: [WorkoutExerciseSummary]
    let musicSummary: String?
}

struct WorkoutExerciseSummary: Identifiable {
    let id: UUID
    let name: String
    let setCount: Int
}

struct WorkoutsScreenState {
    var searchQuery = ""
    var workouts: [WorkoutListItem] = []
}

struct WorkoutExerciseDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var setCount: Int
    var trackingType: ExerciseTrackingKind
    var isSuggestedExercise: Bool

    init(id: UUID = UUID(), name: String = "", setCount: Int = 1, trackingType: ExerciseTrackingKind = .weightReps, isSuggestedExercise: Bool = false) {
        self.id = id
        self.name = name
        self.setCount = setCount
        self.trackingType = trackingType
        self.isSuggestedExercise = isSuggestedExercise
    }
}

struct WorkoutEditorScreenState {
    var templateID: UUID?
    var title = "New Workout"
    var workoutName = ""
    var exercises: [WorkoutExerciseDraft] = []
    var musicProvider: MusicProvider?
    var musicPlaylistID: String?
    var musicPlaylistName: String?
    var musicPlaylistURL: String?
}

struct ActiveSetDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var setNumber: Int
    var previous: String
    var weight: String
    var reps: String
    var minutes: String
    var seconds: String
    var distance: String
    var speed: String
    var isComplete: Bool

    init(id: UUID = UUID(), setNumber: Int, previous: String = "", weight: String = "", reps: String = "", minutes: String = "", seconds: String = "", distance: String = "", speed: String = "", isComplete: Bool = false) {
        self.id = id
        self.setNumber = setNumber
        self.previous = previous
        self.weight = weight
        self.reps = reps
        self.minutes = minutes
        self.seconds = seconds
        self.distance = distance
        self.speed = speed
        self.isComplete = isComplete
    }
}

struct ActiveExerciseDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var trackingType: ExerciseTrackingKind
    var sets: [ActiveSetDraft]
    var isSuggestedExercise: Bool
    var isTrackingTypeLocked: Bool

    init(id: UUID = UUID(), name: String = "", trackingType: ExerciseTrackingKind = .weightReps, sets: [ActiveSetDraft] = [ActiveSetDraft(setNumber: 1)], isSuggestedExercise: Bool = false, isTrackingTypeLocked: Bool = false) {
        self.id = id
        self.name = name
        self.trackingType = trackingType
        self.sets = sets
        self.isSuggestedExercise = isSuggestedExercise
        self.isTrackingTypeLocked = isTrackingTypeLocked
    }
}

struct ActiveWorkoutScreenState: Codable {
    var templateID: UUID?
    var isQuickWorkout: Bool
    var workoutName: String
    var startedAt: Date
    var elapsedText: String
    var exercises: [ActiveExerciseDraft]
    var musicProvider: MusicProvider?
    var musicPlaylistID: String?
    var musicPlaylistName: String?
    var musicPlaylistURL: String?
}

struct CompletedExerciseRow: Identifiable {
    let id = UUID()
    let name: String
    let trackingType: ExerciseTrackingKind
    let sets: [CompletedSetRow]
}

struct CompletedSetRow: Identifiable {
    let id = UUID()
    let setNumber: Int
    let summary: String
    let isBestSet: Bool
}

struct CompletedWorkoutCardModel: Identifiable {
    let id: UUID
    let title: String
    let durationText: String
    let subtitle: String?
    let exercises: [CompletedExerciseRow]
}

struct DayViewScreenState {
    var selectedDate: Date
    var workouts: [CompletedWorkoutCardModel] = []
}

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

enum BodyweightChartRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case year = "1Y"
    case allTime = "All"

    var id: String { rawValue }

    var dayCount: Int? {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .year: return 365
        case .allTime: return nil
        }
    }
}

struct ExerciseSessionModel: Identifiable {
    let id = UUID()
    let dateText: String
    let workoutName: String
    let summary: String
}

struct ExerciseHistoryScreenState {
    var exerciseName = ""
    var stats: [(String, String)] = []
    var points: [ChartPoint] = []
    var sessions: [ExerciseSessionModel] = []
}

enum CanonicalLift: String, CaseIterable, Identifiable, Hashable {
    case benchPress
    case squat
    case deadlift
    case overheadPress
    case barbellRow
    case hackSquat
    case barbellCurl
    case dumbbellCurl
    case tricepExtension
    case seatedCableRow
    case latPulldown
    case latPushdown
    case cableKickback
    case hipThrust
    case legExtension
    case legPress
    case legCurl
    case calfRaise
    case legRaise
    case chestPress
    case chestFly
    case lateralRaise
    case romanianDeadlift
    case backExtension

    var id: String { rawValue }

    static var defaultTrackedLifts: [CanonicalLift] { allCases }

    var leaderboardSection: LeaderboardLiftSection {
        movementCategory.leaderboardSection
    }

    var movementCategory: StrengthMovementCategory {
        switch self {
        case .benchPress, .chestPress, .chestFly:
            return .horizontalPress
        case .barbellRow, .seatedCableRow:
            return .horizontalPull
        case .overheadPress, .lateralRaise:
            return .verticalPress
        case .latPulldown, .latPushdown:
            return .verticalPull
        case .squat, .hackSquat:
            return .squat
        case .deadlift, .romanianDeadlift:
            return .hinge
        case .hipThrust, .cableKickback, .backExtension:
            return .hipExtension
        case .legExtension, .legPress:
            return .kneeExtension
        case .legCurl:
            return .kneeFlexion
        case .barbellCurl, .dumbbellCurl:
            return .armFlexion
        case .tricepExtension:
            return .armExtension
        case .calfRaise, .legRaise:
            return .calvesCore
        }
    }

    static var defaultSuggestions: [ExerciseSuggestion] {
        allCases.map { ExerciseSuggestion(name: $0.displayName, trackingType: .weightReps) }
    }

    var displayName: String {
        switch self {
        case .benchPress: return "Bench Press"
        case .squat: return "Squat"
        case .deadlift: return "Deadlift"
        case .overheadPress: return "Overhead Press"
        case .barbellRow: return "Barbell Row"
        case .hackSquat: return "Hack Squat"
        case .barbellCurl: return "Barbell Curl"
        case .dumbbellCurl: return "Dumbbell Curl"
        case .tricepExtension: return "Tricep Extension"
        case .seatedCableRow: return "Seated Cable Row"
        case .latPulldown: return "Lat Pulldown"
        case .latPushdown: return "Lat Pushdown"
        case .cableKickback: return "Cable Kickback"
        case .hipThrust: return "Hip Thrust"
        case .legExtension: return "Leg Extension"
        case .legCurl: return "Leg Curl"
        case .calfRaise: return "Calf Raise"
        case .legRaise: return "Leg Raise"
        case .chestPress: return "Chest Press"
        case .chestFly: return "Chest Fly"
        case .lateralRaise: return "Lateral Raise"
        case .romanianDeadlift: return "Romanian Deadlift"
        case .backExtension: return "Back Extension"
        case .legPress: return "Leg Press"
        }
    }

    private var aliases: Set<String> {
        switch self {
        case .benchPress:
            return ["bench", "bench press", "barbell bench", "barbell bench press", "flat bench", "flat bench press", "flat barbell bench", "flat barbell bench press"]
        case .squat:
            return ["squat", "squats", "back squat", "back squats", "barbell squat", "barbell squats", "barbell back squat", "barbell back squats", "low bar squat", "high bar squat"]
        case .deadlift:
            return ["deadlift", "deadlifts", "conventional deadlift", "conventional deadlifts", "barbell deadlift", "barbell deadlifts"]
        case .overheadPress:
            return ["overhead press", "ohp", "press", "standing press", "standing overhead press", "barbell overhead press", "military press"]
        case .barbellRow:
            return ["barbell row", "barbell rows", "bent over row", "bent over rows", "bent-over row", "bent-over rows", "bb row", "bb rows", "pendlay row", "pendlay rows"]
        case .hackSquat:
            return ["hack squat", "hack squats", "machine hack squat", "machine hack squats"]
        case .barbellCurl:
            return ["barbell curl", "barbell curls", "bb curl", "bb curls", "straight bar curl", "straight bar curls", "ez bar curl", "ez bar curls", "bicep curl", "bicep curls", "biceps curl", "biceps curls"]
        case .dumbbellCurl:
            return ["dumbbell curl", "dumbbell curls", "db curl", "db curls", "alternating dumbbell curl", "alternating dumbbell curls", "hammer curl", "hammer curls"]
        case .tricepExtension:
            return ["tricep extension", "tricep extensions", "triceps extension", "triceps extensions", "cable tricep extension", "cable tricep extensions", "overhead tricep extension", "overhead tricep extensions", "skull crusher", "skull crushers"]
        case .seatedCableRow:
            return ["seated cable row", "seated cable rows", "cable row", "cable rows", "low cable row", "low cable rows"]
        case .latPulldown:
            return ["lat pulldown", "lat pulldowns", "lat pull down", "lat pull downs", "pulldown", "pulldowns", "wide grip lat pulldown", "wide grip lat pulldowns"]
        case .latPushdown:
            return ["lat pushdown", "lat pushdowns", "lat push down", "lat push downs", "straight arm pulldown", "straight arm pulldowns", "straight arm pushdown", "straight arm pushdowns"]
        case .cableKickback:
            return ["cable kickback", "cable kickbacks", "glute cable kickback", "glute cable kickbacks"]
        case .hipThrust:
            return ["hip thrust", "hip thrusts", "barbell hip thrust", "barbell hip thrusts", "glute bridge", "glute bridges"]
        case .legExtension:
            return ["leg extension", "leg extensions"]
        case .legPress:
            return ["leg press", "leg presses", "machine leg press", "plate loaded leg press", "45 degree leg press"]
        case .legCurl:
            return ["leg curl", "leg curls", "seated leg curl", "seated leg curls", "lying leg curl", "lying leg curls", "hamstring curl", "hamstring curls"]
        case .calfRaise:
            return ["calf raise", "calf raises", "calve raise", "calve raises", "standing calf raise", "standing calf raises", "seated calf raise", "seated calf raises"]
        case .legRaise:
            return ["leg raise", "leg raises", "hanging leg raise", "hanging leg raises", "captain chair leg raise", "captain chair leg raises"]
        case .chestPress:
            return ["chest press", "machine chest press", "plate loaded chest press", "seated chest press"]
        case .chestFly:
            return ["chest fly", "chest flyes", "chest flies", "pec fly", "pec flyes", "pec deck", "cable fly", "cable flyes"]
        case .lateralRaise:
            return ["lateral raise", "lateral raises", "cable lateral raise", "cable lateral raises", "db lateral raise", "db lateral raises", "dumbbell lateral raise", "dumbbell lateral raises", "side lateral raise", "side lateral raises"]
        case .romanianDeadlift:
            return ["romanian deadlift", "romanian deadlifts", "romandian deadlift", "romandian deadlifts", "rdl", "rdls", "rdl s", "barbell rdl", "barbell rdls"]
        case .backExtension:
            return ["back extension", "back extensions", "hyperextension", "hyperextensions", "weighted back extension", "weighted back extensions"]
        }
    }

    private var excludedPhrases: Set<String> {
        switch self {
        case .benchPress:
            return ["incline bench", "decline bench", "dumbbell bench", "db bench", "close grip bench", "smith bench", "machine bench"]
        case .squat:
            return ["front squat", "hack squat", "goblet squat", "split squat", "bulgarian split squat", "smith squat", "leg press"]
        case .deadlift:
            return ["romanian deadlift", "rdl", "stiff leg deadlift", "sumo deadlift", "trap bar deadlift", "rack pull"]
        case .overheadPress:
            return ["dumbbell press", "db press", "bench press", "incline press", "push press", "machine shoulder press", "seated press"]
        case .barbellRow:
            return ["dumbbell row", "db row", "cable row", "machine row", "t bar row", "seal row"]
        case .hackSquat, .barbellCurl, .dumbbellCurl, .tricepExtension, .seatedCableRow, .latPulldown, .latPushdown, .cableKickback, .hipThrust, .legExtension, .legPress, .legCurl, .calfRaise, .legRaise, .chestPress, .chestFly, .lateralRaise, .romanianDeadlift, .backExtension:
            return []
        }
    }

    static func match(exerciseName: String) -> CanonicalLift? {
        let key = liftMatchKey(exerciseName)
        guard !key.isEmpty else { return nil }

        for lift in CanonicalLift.allCases {
            if lift.excludedPhrases.contains(where: { key.contains($0) }) {
                continue
            }
            if lift.aliases.contains(key) {
                return lift
            }
        }

        return nil
    }
}

enum LeaderboardLiftSection: String, CaseIterable, Identifiable {
    case upperBody = "Upper Body"
    case lowerBody = "Lower Body"
    case accessories = "Accessories"

    var id: String { rawValue }
}

enum StrengthMovementCategory: String, CaseIterable, Identifiable, Hashable {
    case horizontalPress
    case horizontalPull
    case verticalPress
    case verticalPull
    case squat
    case hinge
    case hipExtension
    case kneeExtension
    case kneeFlexion
    case armFlexion
    case armExtension
    case calvesCore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontalPress: return "Horizontal Press"
        case .horizontalPull: return "Horizontal Pull"
        case .verticalPress: return "Vertical Press"
        case .verticalPull: return "Vertical Pull"
        case .squat: return "Squat Pattern"
        case .hinge: return "Hinge"
        case .hipExtension: return "Hip Extension"
        case .kneeExtension: return "Knee Extension"
        case .kneeFlexion: return "Knee Flexion"
        case .armFlexion: return "Arm Flexion"
        case .armExtension: return "Arm Extension"
        case .calvesCore: return "Calves / Core"
        }
    }

    var leaderboardSection: LeaderboardLiftSection {
        switch self {
        case .horizontalPress, .horizontalPull, .verticalPress, .verticalPull:
            return .upperBody
        case .squat, .hinge, .hipExtension, .kneeExtension, .kneeFlexion:
            return .lowerBody
        case .armFlexion, .armExtension, .calvesCore:
            return .accessories
        }
    }

    var contributingLifts: [CanonicalLift] {
        CanonicalLift.allCases.filter { $0.movementCategory == self }
    }

    var contributingExerciseText: String {
        contributingLifts.map(\.displayName).joined(separator: ", ")
    }
}

enum StrengthRankLevel: String, CaseIterable, Identifiable {
    case unranked = "Unranked"
    case untrained = "Untrained"
    case novice = "Novice"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case elite = "Elite"

    var id: String { rawValue }

    var score: Double {
        switch self {
        case .unranked: return 0
        case .untrained: return 1
        case .novice: return 2
        case .intermediate: return 3
        case .advanced: return 4
        case .elite: return 5
        }
    }
}

struct LeaderboardLiftRow: Identifiable {
    let id: StrengthMovementCategory
    let category: StrengthMovementCategory
    let rank: StrengthRankLevel
    let bestSetText: String
    let estimatedOneRepMaxText: String
    let nextRankText: String?
    let sourceExerciseName: String?
    let contributingExercisesText: String
}

struct LeaderboardXPProgress {
    var level = 1
    var totalXP = 0
    var currentLevelXP = 0
    var nextLevelXP = 100
    var progress = 0.0
    var title = "Level 1"
    var iconName = "figure.walk"

    var xpSummary: String {
        "\(currentLevelXP) / \(nextLevelXP) XP"
    }
}

struct LevelUpEvent: Identifiable, Equatable {
    let id = UUID()
    let previousLevel: Int
    let newLevel: Int
    let iconName: String
}

struct LeaderboardScreenState {
    var classSummary = "Set biometrics to unlock your class"
    var bodyweightClass = "-"
    var overallRank = StrengthRankLevel.unranked
    var overallScoreText = "-"
    var xpProgress = LeaderboardXPProgress()
    var rows: [LeaderboardLiftRow] = StrengthMovementCategory.allCases.map {
        LeaderboardLiftRow(
            id: $0,
            category: $0,
            rank: .unranked,
            bestSetText: "No matched lift",
            estimatedOneRepMaxText: "-",
            nextRankText: nil,
            sourceExerciseName: nil,
            contributingExercisesText: $0.contributingExerciseText
        )
    }
}

struct BodyweightEntryModel: Identifiable {
    let id: UUID
    let date: Date
    let dateText: String
    let weightText: String
    let fluctuationText: String?
    let fluctuationDirection: BodyweightFluctuationDirection?
    let value: Double
    let photoPath: String?
}

enum BodyweightFluctuationDirection: Equatable {
    case up
    case down
    case flat
}

struct ExerciseSuggestion: Identifiable, Hashable {
    let id: String
    let name: String
    let trackingType: ExerciseTrackingKind

    init(name: String, trackingType: ExerciseTrackingKind) {
        self.id = "\(name.lowercased())::\(trackingType.rawValue)"
        self.name = name
        self.trackingType = trackingType
    }
}

struct MusicNowPlayingModel {
    let title: String
    let artist: String
    let artwork: UIImage?
}

struct MusicQuickPickItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let artworkURL: URL?
}

struct ProfileScreenState {
    var displayName = "Guest"
    var avatarPath: String?
    var workoutCount = 0
    var streak = 0
    var height = ""
    var age = ""
    var birthdate: Date?
    var sex: BiologicalSex = .male
    var latestWeight = "-"
    var bodyweightTrendText: String?
    var bodyweightTrendIsStable = false
    var bodyweightTrendHelperText: String?
    var bodyweightTrendingWeightText: String?
    var bodyweightTenDayLowText: String?
    var bodyweightChartRange: BodyweightChartRange = .thirtyDays
    var chartPoints: [ChartPoint] = []
    var trendChartPoints: [ChartPoint] = []
    var recentEntries: [BodyweightEntryModel] = []
    var workoutDays: Set<WorkoutWeekday> = []
    var reminderEnabled = false
    var reminderHour = 18
    var reminderMinute = 0
    var reminderMessage = "Time to train"
}

struct BodyweightEntriesScreenState {
    var entries: [BodyweightEntryModel] = []
    var filteredEntries: [BodyweightEntryModel] = []
    var startDate: Date?
    var endDate: Date?

    var filterText: String {
        guard let startDate, let endDate else { return "All Time" }
        return "\(DateFormatter.repsyncShortDate.string(from: startDate)) - \(DateFormatter.repsyncShortDate.string(from: endDate))"
    }
}

extension DateFormatter {
    static let repsyncMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let repsyncLongDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    static let repsyncShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static let repsyncISODate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Calendar {
    static let repsync = Calendar(identifier: .gregorian)
}

func formatElapsedTime(from startedAt: Date) -> String {
    let elapsed = max(Int(Date().timeIntervalSince(startedAt)), 0)
    return formatElapsedTime(seconds: elapsed)
}

func formatElapsedTime(seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

func formatWeight(_ value: Double) -> String {
    if value.rounded(.towardZero) == value {
        return String(Int(value))
    }
    return String(format: "%.1f", value)
}

func formatBodyweight(_ value: Double) -> String {
    String(format: "%.1f", value)
}

func normalizedExerciseName(_ value: String) -> String {
    let words = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init)

    return words
        .map { word in
            guard let first = word.first else { return word }
            return first.uppercased() + word.dropFirst().lowercased()
        }
        .joined(separator: " ")
}

func exerciseNameMatchKey(_ value: String) -> String {
    normalizedExerciseName(value)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
}

func liftMatchKey(_ value: String) -> String {
    let folded = value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()

    let scalars = folded.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
    }

    return String(scalars)
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}
