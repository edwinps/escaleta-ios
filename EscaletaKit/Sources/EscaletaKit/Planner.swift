import Foundation

public struct ChannelStatus: Equatable, Sendable {
    public let channel: Channel
    public let lastPublishedAt: Date?
    public let earliestPublishAt: Date?
    public let isDue: Bool
    // infinity when nothing was published yet
    public let lateness: Double
    public let openVideos: [Video]

    public var currentVideo: Video? { openVideos.first }
}

public struct DayPlan: Equatable, Sendable {
    public let due: [ChannelStatus]
    public let resting: [ChannelStatus]
}

public enum TaskAction: Equatable, Sendable {
    case start(Step)
    case `continue`(Step)
    case reviewRender
    case publish
}

public enum Suggestion: Equatable, Sendable {
    case task(channelID: UUID, action: TaskAction)
    case waitingForRenders(count: Int)
    case waitingToPublish(channelID: UUID, at: Date)
    case nothingActionable
    case allDone
}

public enum Planner {
    public static func plan(snapshot: Snapshot, now: Date, calendar: Calendar = .current) -> DayPlan {
        let statuses = snapshot.channels
            .filter(\.isActive)
            .map { status(for: $0, snapshot: snapshot, now: now, calendar: calendar) }
        return DayPlan(
            due: statuses.filter(\.isDue).sorted(by: workingOrder),
            resting: statuses.filter { !$0.isDue }.sorted(by: workingOrder)
        )
    }

    public static func status(for channel: Channel, snapshot: Snapshot, now: Date, calendar: Calendar = .current) -> ChannelStatus {
        let last = snapshot.videos
            .filter { $0.channelID == channel.id && $0.status == .published }
            .compactMap(\.publishedAt)
            .max()
        let cadence = TimeInterval(max(channel.cadenceDays, 1)) * 86_400
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!.addingTimeInterval(-1)
        let open = snapshot.videos
            .filter { $0.channelID == channel.id && $0.status == .open }
            .sorted { $0.createdAt < $1.createdAt }

        return ChannelStatus(
            channel: channel,
            lastPublishedAt: last,
            earliestPublishAt: last.map { $0.addingTimeInterval(TimeInterval(snapshot.settings.minHoursBetweenVideos) * 3_600) },
            isDue: last.map { $0.addingTimeInterval(cadence) <= endOfToday } ?? true,
            lateness: last.map { now.timeIntervalSince($0) / cadence } ?? .infinity,
            openVideos: open
        )
    }

    // group, then most overdue, then name
    static func workingOrder(_ a: ChannelStatus, _ b: ChannelStatus) -> Bool {
        if a.channel.group != b.channel.group { return a.channel.group < b.channel.group }
        if a.lateness != b.lateness { return a.lateness > b.lateness }
        return a.channel.name < b.channel.name
    }

    public static func suggestion(plan: DayPlan, snapshot: Snapshot, now: Date) -> Suggestion {
        let settings = snapshot.settings
        let cards = plan.due

        // render running for a while
        let reviewAfter = TimeInterval(settings.renderReviewMinutes) * 60
        let overdueRender = snapshot.videos
            .filter { $0.status == .open && $0.state(of: .firstEdit) == .inProgress }
            .compactMap { video -> (UUID, Date)? in
                guard let started = video.progress[.firstEdit]?.startedAt, now.timeIntervalSince(started) >= reviewAfter else { return nil }
                return (video.channelID, started)
            }
            .min { $0.1 < $1.1 }
        if let overdueRender { return .task(channelID: overdueRender.0, action: .reviewRender) }

        func state(_ card: ChannelStatus, _ step: Step) -> StepState {
            card.currentVideo?.state(of: step) ?? .pending
        }

        // thumbnail already started
        for card in cards where state(card, .thumbnail) == .inProgress {
            return .task(channelID: card.channel.id, action: .continue(.thumbnail))
        }
        // free render slot: start one right away
        if snapshot.runningRenders < settings.maxConcurrentRenders {
            for card in cards where state(card, .script) == .done && state(card, .firstEdit) == .pending {
                return .task(channelID: card.channel.id, action: .start(.firstEdit))
            }
        }
        // ready to publish
        for card in cards {
            guard let video = card.currentVideo, video.isReadyToPublish else { continue }
            if card.earliestPublishAt.map({ $0 <= now }) ?? true {
                return .task(channelID: card.channel.id, action: .publish)
            }
        }
        // review a finished render
        for card in cards where state(card, .firstEdit) == .done && state(card, .review) != .done {
            return .task(channelID: card.channel.id, action: .start(.review))
        }
        // thumbnails after the background work
        for card in cards where state(card, .script) == .done && state(card, .thumbnail) == .pending {
            return .task(channelID: card.channel.id, action: .start(.thumbnail))
        }
        // topic, then script
        for card in cards {
            if state(card, .topic) != .done { return .task(channelID: card.channel.id, action: .start(.topic)) }
            if state(card, .script) != .done { return .task(channelID: card.channel.id, action: .start(.script)) }
        }

        if snapshot.runningRenders > 0 { return .waitingForRenders(count: snapshot.runningRenders) }
        let waiting = cards
            .filter { $0.currentVideo?.isReadyToPublish == true }
            .compactMap { card in card.earliestPublishAt.map { (card.channel.id, $0) } }
            .min { $0.1 < $1.1 }
        if let waiting { return .waitingToPublish(channelID: waiting.0, at: waiting.1) }
        return cards.isEmpty ? .allDone : .nothingActionable
    }
}
