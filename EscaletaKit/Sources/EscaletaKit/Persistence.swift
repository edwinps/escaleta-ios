import Foundation

public protocol SnapshotRepository {
    func load() throws -> Snapshot?
    func save(_ snapshot: Snapshot) throws
}

// iso8601 dates, so anything under a second is lost
public struct JSONFileRepository: SnapshotRepository {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Escaleta", isDirectory: true).appendingPathComponent("data.json")
    }

    public func load() throws -> Snapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: Data(contentsOf: url))
    }

    public func save(_ snapshot: Snapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }
}

public final class InMemoryRepository: SnapshotRepository {
    private var stored: Snapshot?

    public init(_ initial: Snapshot? = nil) {
        stored = initial
    }

    public func load() throws -> Snapshot? { stored }
    public func save(_ snapshot: Snapshot) throws { stored = snapshot }
}
