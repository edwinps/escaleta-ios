import XCTest
@testable import EscaletaKit

final class SuggestionTests: XCTestCase {
    private func suggestion(_ snapshot: Snapshot) -> Suggestion {
        let plan = Planner.plan(snapshot: snapshot, now: Fixture.now, calendar: Fixture.calendar)
        return Planner.suggestion(plan: plan, snapshot: snapshot, now: Fixture.now)
    }

    private func video(for channel: Channel, _ done: [Step], running: [Step: Double] = [:]) -> Video {
        var video = Video(channelID: channel.id, createdAt: Fixture.hoursAgo(5))
        for step in done { video.progress[step] = StepProgress(state: .done, finishedAt: Fixture.hoursAgo(1)) }
        for (step, minutes) in running {
            video.progress[step] = StepProgress(state: .inProgress, startedAt: Fixture.now.addingTimeInterval(-minutes * 60))
        }
        return video
    }

    func testStartsWithTopicWhenNothingExists() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        XCTAssertEqual(suggestion(Fixture.snapshot(channels: [channel])), .task(channelID: channel.id, action: .start(.topic)))
    }

    func testScriptFollowsTopic() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let snapshot = Fixture.snapshot(channels: [channel], videos: [video(for: channel, [.topic])])
        XCTAssertEqual(suggestion(snapshot), .task(channelID: channel.id, action: .start(.script)))
    }

    func testFirstEditIsLaunchedBeforeThumbnailWhenSlotsAreFree() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let snapshot = Fixture.snapshot(channels: [channel], videos: [video(for: channel, [.topic, .script])])
        XCTAssertEqual(suggestion(snapshot), .task(channelID: channel.id, action: .start(.firstEdit)))
    }

    func testThumbnailWhenRenderSlotsAreFull() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let other = Channel(name: "B", group: .b, cadenceDays: 1)
        let snapshot = Fixture.snapshot(
            channels: [channel, other],
            videos: [video(for: channel, [.topic, .script]), video(for: other, [.topic, .script], running: [.firstEdit: 5])],
            settings: Settings(maxConcurrentRenders: 1)
        )
        XCTAssertEqual(suggestion(snapshot), .task(channelID: channel.id, action: .start(.thumbnail)))
    }

    func testLongRenderAsksForReview() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let snapshot = Fixture.snapshot(channels: [channel], videos: [video(for: channel, [.topic, .script], running: [.firstEdit: 45])])
        XCTAssertEqual(suggestion(snapshot), .task(channelID: channel.id, action: .reviewRender))
    }

    func testShortRenderMeansWaiting() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let snapshot = Fixture.snapshot(
            channels: [channel],
            videos: [video(for: channel, [.topic, .script, .thumbnail], running: [.firstEdit: 5])]
        )
        XCTAssertEqual(suggestion(snapshot), .waitingForRenders(count: 1))
    }

    func testPublishWhenReadyAndGapRespected() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let ready = video(for: channel, Step.allCases)
        let snapshot = Fixture.snapshot(channels: [channel], videos: [ready, Fixture.published(channel, hoursAgo: 30)])
        XCTAssertEqual(suggestion(snapshot), .task(channelID: channel.id, action: .publish))
    }

    func testWaitsToPublishWhenGapNotReached() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 1)
        let ready = video(for: channel, Step.allCases)
        // due today, but the 40 h minimum gap is not met yet
        let snapshot = Fixture.snapshot(channels: [channel], videos: [ready, Fixture.published(channel, hoursAgo: 22)],
                                        settings: Settings(minHoursBetweenVideos: 40))
        XCTAssertEqual(suggestion(snapshot), .waitingToPublish(channelID: channel.id, at: Fixture.hoursAgo(22).addingTimeInterval(40 * 3_600)))
    }

    func testAllDoneWhenNothingIsDue() {
        let channel = Channel(name: "A", group: .a, cadenceDays: 7)
        let snapshot = Fixture.snapshot(channels: [channel], videos: [Fixture.published(channel, hoursAgo: 2)])
        XCTAssertEqual(suggestion(snapshot), .allDone)
    }
}
