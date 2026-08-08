//
//  RepSyncTests.swift
//  RepSyncTests
//
//  Created by Brian Keeley on 4/17/26.
//

import CoreData
import XCTest
@testable import RepSync

final class RepSyncTests: XCTestCase {
    func testHomeCalendarStateFormatsMonthTitle() {
        let date = Calendar.repsync.date(from: DateComponents(year: 2026, month: 4, day: 17)) ?? Date()
        let state = HomeScreenState(currentMonth: date, calendarDays: [])

        XCTAssertEqual(state.monthTitle, "April 2026")
    }

    func testPersistenceControllerCreatesInMemoryContainer() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container.persistentStoreCoordinator.persistentStores.first)
    }

    func testExerciseNameNormalizationCollapsesCaseAndWhitespace() {
        XCTAssertEqual(normalizedExerciseName("  bench   press "), "Bench Press")
        XCTAssertEqual(exerciseNameMatchKey("plank"), exerciseNameMatchKey("Plank"))
    }

    func testCanonicalLiftMatchingIncludesBenchButExcludesInclineBench() {
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Bench"), .benchPress)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Flat Barbell Bench Press"), .benchPress)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Squats"), .squat)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Deadlifts"), .deadlift)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Bent Over Rows"), .barbellRow)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Cable Lateral Raises"), .lateralRaise)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "RDLs"), .romanianDeadlift)
        XCTAssertEqual(CanonicalLift.match(exerciseName: "Barbell Shrugs"), .shrug)
        XCTAssertNil(CanonicalLift.match(exerciseName: "Incline Bench Press"))
        XCTAssertNil(CanonicalLift.match(exerciseName: "Dumbbell Bench Press"))
    }

    @MainActor
    func testBodyweightTrendUsesLatestFourteenDays() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)
        let olderDate = testDate(year: 2026, month: 3, day: 1)
        let startDate = testDate(year: 2026, month: 4, day: 1)
        let middleDate = testDate(year: 2026, month: 4, day: 8)
        let endDate = testDate(year: 2026, month: 4, day: 15)

        try store.addBodyweightEntry(weight: 250, on: olderDate)
        try store.addBodyweightEntry(weight: 180.0, on: startDate)
        try store.addBodyweightEntry(weight: 180.7, on: middleDate)
        try store.addBodyweightEntry(weight: 181.4, on: endDate)

        let state = try store.makeProfileState()

        XCTAssertEqual(state.bodyweightTrendText, "Gaining 0.2 lbs/week")
        XCTAssertFalse(state.bodyweightTrendIsStable)
    }

    @MainActor
    func testBodyweightTrendReportsMaintainingWhenFourteenDayTrendIsFlat() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)

        try store.addBodyweightEntry(weight: 180.0, on: testDate(year: 2026, month: 4, day: 1))
        try store.addBodyweightEntry(weight: 180.0, on: testDate(year: 2026, month: 4, day: 8))
        try store.addBodyweightEntry(weight: 180.0, on: testDate(year: 2026, month: 4, day: 15))

        let state = try store.makeProfileState()

        XCTAssertEqual(state.bodyweightTrendText, "Maintaining 0.0 lbs/week")
        XCTAssertTrue(state.bodyweightTrendIsStable)
    }

    @MainActor
    func testBodyweightProfileShowsTrendingWeightAndTenDayLow() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)

        try store.addBodyweightEntry(weight: 200, on: testDate(year: 2026, month: 4, day: 1))
        try store.addBodyweightEntry(weight: 181, on: testDate(year: 2026, month: 4, day: 8))
        try store.addBodyweightEntry(weight: 179, on: testDate(year: 2026, month: 4, day: 14))
        try store.addBodyweightEntry(weight: 180, on: testDate(year: 2026, month: 4, day: 17))

        let state = try store.makeProfileState()

        XCTAssertEqual(state.bodyweightTrendingWeightText, "180.5 lbs")
        XCTAssertEqual(state.bodyweightTenDayLowText, "179 lbs on Apr 14, 2026")
    }

    @MainActor
    func testBodyweightTrendCapsOutlierBeforeSmoothing() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)

        try store.addBodyweightEntry(weight: 180.0, on: testDate(year: 2026, month: 4, day: 1))
        try store.addBodyweightEntry(weight: 179.5, on: testDate(year: 2026, month: 4, day: 8))
        try store.addBodyweightEntry(weight: 190.0, on: testDate(year: 2026, month: 4, day: 15))

        let state = try store.makeProfileState()

        XCTAssertEqual(state.bodyweightTrendText, "Gaining 0.2 lbs/week")
        XCTAssertEqual(state.bodyweightTrendingWeightText, "180.4 lbs")
    }

    @MainActor
    func testBodyweightChartDefaultsToThirtyDayWindow() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)
        let startDate = testDate(year: 2026, month: 4, day: 1)

        for dayOffset in 0..<45 {
            let date = Calendar.repsync.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            try store.addBodyweightEntry(weight: 180 + Double(dayOffset), on: date)
        }

        let state = try store.makeProfileState()

        XCTAssertEqual(state.bodyweightChartRange, .thirtyDays)
        XCTAssertEqual(state.chartPoints.count, 30)
        XCTAssertEqual(state.trendChartPoints.count, 30)
        XCTAssertEqual(state.chartPoints.first?.value, 195)
        XCTAssertEqual(state.chartPoints.last?.value, 224)
    }

    @MainActor
    func testBodyweightChartDownsamplesAllTimeData() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)
        let startDate = testDate(year: 2026, month: 1, day: 1)

        for dayOffset in 0..<120 {
            let date = Calendar.repsync.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            try store.addBodyweightEntry(weight: 180 + Double(dayOffset) / 10, on: date)
        }

        let state = try store.makeProfileState(bodyweightChartRange: .allTime)

        XCTAssertEqual(state.bodyweightChartRange, .allTime)
        XCTAssertLessThanOrEqual(state.chartPoints.count, 30)
    }

    @MainActor
    func testProfileBiometricsPersistAndWeightComesFromBodyweightLog() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)

        try store.setBiometricPreferences(
            height: "72.5",
            birthdate: testDate(year: 1992, month: 4, day: 17),
            sex: .female,
            trainingAge: .intermediate
        )
        try store.addBodyweightEntry(weight: 184.5, on: testDate(year: 2026, month: 4, day: 17))

        let state = try store.makeProfileState(currentDate: testDate(year: 2026, month: 4, day: 17))

        XCTAssertEqual(state.height, "6'0.5\"")
        XCTAssertEqual(state.age, "34")
        XCTAssertEqual(state.birthdate, testDate(year: 1992, month: 4, day: 17))
        XCTAssertEqual(state.sex, .female)
        XCTAssertEqual(state.trainingAge, .intermediate)
        XCTAssertEqual(state.latestWeight, "184.5 lbs")
    }

    @MainActor
    func testLeaderboardRanksMatchedBenchFromCompletedWorkout() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)
        try store.setBiometricPreferences(
            height: "70",
            birthdate: testDate(year: 2000, month: 4, day: 17),
            sex: .male,
            trainingAge: .intermediate
        )
        try store.addBodyweightEntry(weight: 180, on: testDate(year: 2026, month: 4, day: 17))
        try store.saveCompletedWorkout(from: ActiveWorkoutScreenState(
            templateID: nil,
            isQuickWorkout: true,
            workoutName: "Push",
            startedAt: testDate(year: 2026, month: 4, day: 17),
            elapsedText: "0:00",
            exercises: [
                ActiveExerciseDraft(
                    name: "Bench",
                    trackingType: .weightReps,
                    sets: [
                        ActiveSetDraft(setNumber: 1, weight: "185", reps: "5", isComplete: true)
                    ],
                    isTrackingTypeLocked: true
                ),
                ActiveExerciseDraft(
                    name: "Incline Bench Press",
                    trackingType: .weightReps,
                    sets: [
                        ActiveSetDraft(setNumber: 1, weight: "225", reps: "5", isComplete: true)
                    ],
                    isTrackingTypeLocked: true
                )
            ]
        ))

        let state = try store.makeLeaderboardState(currentDate: testDate(year: 2026, month: 4, day: 17))
        let bench = try XCTUnwrap(state.rows.first { $0.lift == .benchPress })

        XCTAssertEqual(bench.rank, .intermediate)
        XCTAssertEqual(bench.bestSetText, "185 x 5")
        XCTAssertEqual(bench.sourceExerciseName, "Bench")
    }

    @MainActor
    func testLeaderboardOnlyShowsTrackedLifts() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)

        try store.setLeaderboardTrackedLifts([.benchPress, .romanianDeadlift])

        let state = try store.makeLeaderboardState(currentDate: testDate(year: 2026, month: 4, day: 17))

        XCTAssertEqual(state.rows.map(\.lift), [.benchPress, .romanianDeadlift])
    }

    @MainActor
    func testBodyweightEntryPersistsPhotoPath() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)

        try store.addBodyweightEntry(weight: 184.5, on: testDate(year: 2026, month: 4, day: 17), photoPath: "photo.jpg")

        let state = try store.makeBodyweightEntriesState()

        XCTAssertEqual(state.entries.first?.photoPath, "photo.jpg")
    }

    @MainActor
    func testWorkoutStreakSkipsUnscheduledDays() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)
        try store.upsertProfile(
            displayName: "Tester",
            avatarPath: nil,
            workoutDays: [.monday, .tuesday, .thursday, .friday],
            reminderEnabled: false,
            reminderHour: 18,
            reminderMinute: 0,
            reminderMessage: "Time to train"
        )

        for date in [
            testDate(year: 2026, month: 4, day: 6),
            testDate(year: 2026, month: 4, day: 7),
            testDate(year: 2026, month: 4, day: 9),
            testDate(year: 2026, month: 4, day: 10),
            testDate(year: 2026, month: 4, day: 13),
            testDate(year: 2026, month: 4, day: 14),
            testDate(year: 2026, month: 4, day: 16),
            testDate(year: 2026, month: 4, day: 17)
        ] {
            try logWorkout(on: date, store: store)
        }

        let saturdayState = try store.makeProfileState(currentDate: testDate(year: 2026, month: 4, day: 18))
        let sundayState = try store.makeProfileState(currentDate: testDate(year: 2026, month: 4, day: 19))

        XCTAssertEqual(saturdayState.streak, 8)
        XCTAssertEqual(sundayState.streak, 8)
    }

    @MainActor
    func testWorkoutStreakDoesNotResetBeforeScheduledDayIsLogged() throws {
        let store = RepSyncStore(context: PersistenceController(inMemory: true).container.viewContext)
        try store.upsertProfile(
            displayName: "Tester",
            avatarPath: nil,
            workoutDays: [.monday, .tuesday, .thursday, .friday],
            reminderEnabled: false,
            reminderHour: 18,
            reminderMinute: 0,
            reminderMessage: "Time to train"
        )

        for date in [
            testDate(year: 2026, month: 4, day: 6),
            testDate(year: 2026, month: 4, day: 7),
            testDate(year: 2026, month: 4, day: 9),
            testDate(year: 2026, month: 4, day: 10),
            testDate(year: 2026, month: 4, day: 13),
            testDate(year: 2026, month: 4, day: 14),
            testDate(year: 2026, month: 4, day: 16)
        ] {
            try logWorkout(on: date, store: store)
        }

        let state = try store.makeProfileState(currentDate: testDate(year: 2026, month: 4, day: 17))

        XCTAssertEqual(state.streak, 7)
    }

    @MainActor
    func testActiveWorkoutStateCodableRoundTripPreservesEnteredSets() throws {
        let state = ActiveWorkoutScreenState(
            templateID: nil,
            isQuickWorkout: true,
            workoutName: "Quick Workout",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            elapsedText: "0:12",
            exercises: [
                ActiveExerciseDraft(
                    name: "Bench Press",
                    sets: [
                        ActiveSetDraft(setNumber: 1, weight: "135", reps: "8", isComplete: true)
                    ],
                    isTrackingTypeLocked: true
                )
            ]
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ActiveWorkoutScreenState.self, from: data)

        XCTAssertEqual(decoded.workoutName, "Quick Workout")
        XCTAssertEqual(decoded.exercises.first?.name, "Bench Press")
        XCTAssertEqual(decoded.exercises.first?.sets.first?.weight, "135")
        XCTAssertEqual(decoded.exercises.first?.sets.first?.isComplete, true)
    }

    private func testDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.repsync.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    @MainActor
    private func logWorkout(on date: Date, store: RepSyncStore) throws {
        let workout = ActiveWorkoutScreenState(
            templateID: nil,
            isQuickWorkout: true,
            workoutName: "Logged Workout",
            startedAt: date,
            elapsedText: "0:00",
            exercises: []
        )
        try store.saveCompletedWorkout(from: workout)
    }
}
