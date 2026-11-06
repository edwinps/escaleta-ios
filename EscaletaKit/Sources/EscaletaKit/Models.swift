import Foundation

public enum ChannelGroup: String, Codable, CaseIterable, Comparable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"

    public static func < (lhs: ChannelGroup, rhs: ChannelGroup) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

public struct Channel: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var group: ChannelGroup
    public var cadenceDays: Int
    public var isActive: Bool

    public init(id: UUID = UUID(), name: String, group: ChannelGroup, cadenceDays: Int, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.group = group
        self.cadenceDays = cadenceDays
        self.isActive = isActive
    }
}

public enum Step: String, Codable, CaseIterable, Sendable {
    case topic, script, thumbnail, firstEdit, review

    // slow steps run in the background, hence the in-progress state
    public var isSlow: Bool { self == .thumbnail || self == .firstEdit }
}

public enum StepState: String, Codable, Sendable {
    case pending, inProgress, done
}

public struct StepProgress: Codable, Equatable, Sendable {
    public var state: StepState
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(state: StepState = .pending, startedAt: Date? = nil, finishedAt: Date? = nil) {
        self.state = state
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public enum VideoStatus: String, Codable, Sendable {
    case open, published, discarded
}

public struct Video: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var channelID: UUID
    public var title: String
    public var status: VideoStatus
    public var createdAt: Date
    public var publishedAt: Date?
    public var progress: [Step: StepProgress]

    public init(
        id: UUID = UUID(),
        channelID: UUID,
        title: String = "",
        status: VideoStatus = .open,
        createdAt: Date,
        publishedAt: Date? = nil,
        progress: [Step: StepProgress] = [:]
    ) {
        self.id = id
        self.channelID = channelID
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.progress = progress
    }

    public func state(of step: Step) -> StepState {
        progress[step]?.state ?? .pending
    }

    public var isReadyToPublish: Bool {
        Step.allCases.allSatisfy { state(of: $0) == .done }
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var minHoursBetweenVideos: Int
    public var maxConcurrentRenders: Int
    public var renderReviewMinutes: Int

    public init(minHoursBetweenVideos: Int = 20, maxConcurrentRenders: Int = 4, renderReviewMinutes: Int = 30) {
        self.minHoursBetweenVideos = minHoursBetweenVideos
        self.maxConcurrentRenders = maxConcurrentRenders
        self.renderReviewMinutes = renderReviewMinutes
    }
}

public struct Snapshot: Codable, Equatable, Sendable {
    public var channels: [Channel]
    public var videos: [Video]
    public var settings: Settings

    public init(channels: [Channel] = [], videos: [Video] = [], settings: Settings = Settings()) {
        self.channels = channels
        self.videos = videos
        self.settings = settings
    }
}
