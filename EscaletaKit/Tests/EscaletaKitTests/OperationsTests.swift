import XCTest
@testable import EscaletaKit

final class OperationsTests: XCTestCase {
    private let channel = Channel(name: "A", group: .a, cadenceDays: 1)

    private func snapshot(settings: Settings = Settings()) -> Snapshot {
        Fixture.snapshot(channels: [channel], settings: settings)
    }

    func testFastStepTogglesAndCreatesVideo() throws {
        var snap = snapshot()
        try snap.cycle(.topic, channelID: channel.id, now: Fixture.now)
        XCTAssertEqual(snap.videos.count, 1)
        XCTAssertEqual(snap.videos[0].state(of: .topic), .done)
        try snap.cycle(.topic, channelID: channel.id, now: Fixture.now)
        XCTAssertEqual(snap.videos[0].state(of: .topic), .pending)
        XCTAssertEqual(snap.videos.count, 1)
    }

    func testSlowStepCyclesAndRecordsTimes() throws {
        var snap = snapshot()
        let start = Fixture.now
        let end = Fixture.now.addingTimeInterval(1_800)
        try snap.cycle(.thumbnail, channelID: channel.id, now: start)
        XCTAssertEqual(snap.videos[0].progress[.thumbnail], StepProgress(state: .inProgress, startedAt: start, finishedAt: nil))
        try snap.cycle(.thumbnail, channelID: channel.id, now: end)
        XCTAssertEqual(snap.videos[0].progress[.thumbnail], StepProgress(state: .done, startedAt: start, finishedAt: end))
        try snap.cycle(.thumbnail, channelID: channel.id, now: end)
        XCTAssertEqual(snap.videos[0].progress[.thumbnail], StepProgress())
    }

    func testRenderLimitBlocksNewRenderAndCreatesNoVideo() throws {
        var snap = snapshot(settings: Settings(maxConcurrentRenders: 1))
        let other = Channel(name: "B", group: .b, cadenceDays: 1)
        snap.channels.append(other)
        try snap.cycle(.firstEdit, channelID: channel.id, now: Fixture.now)
        XCTAssertThrowsError(try snap.cycle(.firstEdit, channelID: other.id, now: Fixture.now)) {
            XCTAssertEqual($0 as? OperationError, .renderLimitReached(max: 1))
        }
        XCTAssertEqual(snap.videos.count, 1)
        XCTAssertEqual(snap.runningRenders, 1)
    }

    func testUnknownChannelThrows() {
        var snap = snapshot()
        XCTAssertThrowsError(try snap.cycle(.topic, channelID: UUID(), now: Fixture.now)) {
            XCTAssertEqual($0 as? OperationError, .channelNotFound)
        }
    }

    func testPublishRequiresTitleAndMarksVideo() throws {
        var snap = snapshot()
        XCTAssertThrowsError(try snap.publish(channelID: channel.id, title: "   ", at: Fixture.now, now: Fixture.now)) {
            XCTAssertEqual($0 as? OperationError, .emptyTitle)
        }
        XCTAssertTrue(snap.videos.isEmpty)
        try snap.publish(channelID: channel.id, title: "  Hola  ", at: Fixture.now, now: Fixture.now)
        XCTAssertEqual(snap.videos[0].status, .published)
        XCTAssertEqual(snap.videos[0].title, "Hola")
        XCTAssertEqual(snap.videos[0].publishedAt, Fixture.now)
    }

    func testPublishWarningOnlyBelowMinimumGap() {
        var snap = snapshot()
        snap.videos.append(Fixture.published(channel, hoursAgo: 10))
        let warning = snap.publishWarning(channelID: channel.id, at: Fixture.now)
        XCTAssertEqual(try XCTUnwrap(warning), 10, accuracy: 0.001)
        XCTAssertNil(snap.publishWarning(channelID: channel.id, at: Fixture.now.addingTimeInterval(12 * 3_600)))
    }

    func testUpsertAddsThenReplaces() {
        var snap = snapshot()
        var edited = channel
        edited.name = "Renombrado"
        snap.upsert(edited)
        XCTAssertEqual(snap.channels.count, 1)
        XCTAssertEqual(snap.channels[0].name, "Renombrado")
        snap.upsert(Channel(name: "Otro", group: .c, cadenceDays: 2))
        XCTAssertEqual(snap.channels.count, 2)
    }
}
