import XCTest
@testable import EscaletaKit

final class PlannerTests: XCTestCase {
    func testChannelWithoutPublicationsIsDueAndMostLate() {
        let fresh = Channel(name: "Nuevo", group: .c, cadenceDays: 3)
        let snapshot = Fixture.snapshot(channels: [fresh])
        let plan = Planner.plan(snapshot: snapshot, now: Fixture.now, calendar: Fixture.calendar)
        XCTAssertEqual(plan.due.map(\.channel.name), ["Nuevo"])
        XCTAssertNil(plan.due[0].lastPublishedAt)
        XCTAssertEqual(plan.due[0].lateness, .infinity)
    }

    func testDueDependsOnCadenceUntilEndOfToday() {
        let daily = Channel(name: "Diario", group: .a, cadenceDays: 1)
        let sparse = Channel(name: "Espaciado", group: .a, cadenceDays: 3)
        let snapshot = Fixture.snapshot(
            channels: [daily, sparse],
            videos: [Fixture.published(daily, hoursAgo: 10), Fixture.published(sparse, hoursAgo: 30)]
        )
        let plan = Planner.plan(snapshot: snapshot, now: Fixture.now, calendar: Fixture.calendar)
        XCTAssertTrue(plan.due.isEmpty)
        XCTAssertEqual(Set(plan.resting.map(\.channel.name)), ["Diario", "Espaciado"])
    }

    func testChannelBecomesDueIfCadenceEndsBeforeMidnight() {
        let daily = Channel(name: "Diario", group: .a, cadenceDays: 1)
        // due again at 16:00, still today
        let snapshot = Fixture.snapshot(channels: [daily], videos: [Fixture.published(daily, hoursAgo: 20)])
        let plan = Planner.plan(snapshot: snapshot, now: Fixture.now, calendar: Fixture.calendar)
        XCTAssertEqual(plan.due.map(\.channel.name), ["Diario"])
    }

    func testOrderIsGroupThenLatenessThenName() {
        let a = Channel(name: "Zeta", group: .a, cadenceDays: 1)
        let b1 = Channel(name: "Beta", group: .b, cadenceDays: 1)
        let b2 = Channel(name: "Alfa", group: .b, cadenceDays: 1)
        let snapshot = Fixture.snapshot(
            channels: [b1, a, b2],
            videos: [Fixture.published(a, hoursAgo: 30), Fixture.published(b1, hoursAgo: 30), Fixture.published(b2, hoursAgo: 80)]
        )
        let plan = Planner.plan(snapshot: snapshot, now: Fixture.now, calendar: Fixture.calendar)
        XCTAssertEqual(plan.due.map(\.channel.name), ["Zeta", "Alfa", "Beta"])
    }

    func testInactiveChannelsAreIgnored() {
        let paused = Channel(name: "Pausa", group: .a, cadenceDays: 1, isActive: false)
        let plan = Planner.plan(snapshot: Fixture.snapshot(channels: [paused]), now: Fixture.now, calendar: Fixture.calendar)
        XCTAssertTrue(plan.due.isEmpty)
        XCTAssertTrue(plan.resting.isEmpty)
    }

    func testEarliestPublishUsesMinimumGap() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let snapshot = Fixture.snapshot(channels: [channel], videos: [Fixture.published(channel, hoursAgo: 30)])
        let status = Planner.status(for: channel, snapshot: snapshot, now: Fixture.now, calendar: Fixture.calendar)
        XCTAssertEqual(status.earliestPublishAt, Fixture.hoursAgo(30).addingTimeInterval(20 * 3_600))
    }
}
