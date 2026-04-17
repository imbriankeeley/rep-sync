//
//  RepSyncTests.swift
//  RepSyncTests
//
//  Created by Brian Keeley on 4/17/26.
//

import XCTest
@testable import RepSync

final class RepSyncTests: XCTestCase {
    func testMockHomeCalendarContainsWorkoutDays() {
        XCTAssertFalse(HomeScreenState.mock.calendarDays.isEmpty)
        XCTAssertTrue(HomeScreenState.mock.calendarDays.contains(where: \.hasWorkout))
    }

    func testPersistenceControllerCreatesInMemoryContainer() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.container.persistentStoreCoordinator.persistentStores.first)
    }
}
