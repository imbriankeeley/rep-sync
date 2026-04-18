import Foundation
import UIKit

enum RepSyncTab: String, CaseIterable, Hashable {
    case home = "Home"
    case profile = "Profile"
}

enum MusicProvider: String, CaseIterable, Identifiable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"

    var id: String { rawValue }
}

enum RepSyncRoute: Hashable {
    case workouts
    case workoutEditor
    case activeWorkout
    case dayView
    case exerciseHistory
    case bodyweightEntries
    case editProfile
}

enum ExerciseTrackingKind: String, CaseIterable, Identifiable {
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

struct ActiveSetDraft: Identifiable, Equatable {
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

struct ActiveExerciseDraft: Identifiable, Equatable {
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

struct ActiveWorkoutScreenState {
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
    let summary: String
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

struct BodyweightEntryModel: Identifiable {
    let id: UUID
    let date: Date
    let dateText: String
    let weightText: String
    let value: Double
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
    var latestWeight = "-"
    var bodyweightTrendText: String?
    var bodyweightTrendIsStable = false
    var bodyweightTrendHelperText: String?
    var chartPoints: [ChartPoint] = []
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
