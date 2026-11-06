import Foundation

public enum SeedData {
    private static let channels: [(name: String, group: ChannelGroup, cadence: Int, hoursSinceLast: Double)] = [
        ("Faros del Norte", .a, 1, 30),
        ("Taller Cero", .a, 1, 52),
        ("Bajo la Lupa", .a, 1, 10),
        ("Atlas Dormido", .b, 2, 60),
        ("Huerto Urbano", .b, 2, 20),
        ("Cuentos de Sobremesa", .b, 2, 75),
        ("Mundo Mineral", .c, 3, 40),
        ("Ruta Sin Mapa", .c, 3, 100),
        ("Sabores de Lata", .c, 3, 24),
        ("Pulso Digital", .c, 3, 130),
    ]

    public static func makeSnapshot(now: Date) -> Snapshot {
        var snapshot = Snapshot()
        for entry in channels {
            let channel = Channel(name: entry.name, group: entry.group, cadenceDays: entry.cadence)
            snapshot.channels.append(channel)
            snapshot.videos.append(Video(
                channelID: channel.id,
                title: "Vídeo anterior",
                status: .published,
                createdAt: now.addingTimeInterval(-(entry.hoursSinceLast + 48) * 3_600),
                publishedAt: now.addingTimeInterval(-entry.hoursSinceLast * 3_600)
            ))
        }
        return snapshot
    }
}
