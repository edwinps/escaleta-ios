import Foundation
@testable import EscaletaKit

enum Fixture {
    static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // 2026-03-10 12:00 UTC
    static let now = Date(timeIntervalSince1970: 1_773_144_000)

    static func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3_600) }

    static func published(_ channel: Channel, hoursAgo: Double) -> Video {
        Video(channelID: channel.id, title: "Anterior", status: .published,
              createdAt: self.hoursAgo(hoursAgo + 24), publishedAt: self.hoursAgo(hoursAgo))
    }

    static func snapshot(channels: [Channel], videos: [Video] = [], settings: Settings = Settings()) -> Snapshot {
        Snapshot(channels: channels, videos: videos, settings: settings)
    }
}
