import XCTest
@testable import EscaletaKit

final class PersistenceTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("escaleta-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("data.json")
    }

    func testRoundTripThroughFile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var snap = SeedData.makeSnapshot(now: Fixture.now)
        try snap.cycle(.thumbnail, channelID: snap.channels[0].id, now: Fixture.now)

        let repository = JSONFileRepository(url: url)
        XCTAssertNil(try repository.load())
        try repository.save(snap)
        XCTAssertEqual(try repository.load(), snap)
    }

    func testCorruptFileThrowsInsteadOfReturningNil() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("no es json".utf8).write(to: url)
        XCTAssertThrowsError(try JSONFileRepository(url: url).load())
    }

    func testSeedHasTenUniqueChannelsWithHistory() {
        let snap = SeedData.makeSnapshot(now: Fixture.now)
        XCTAssertEqual(snap.channels.count, 10)
        XCTAssertEqual(Set(snap.channels.map(\.name)).count, 10)
        XCTAssertEqual(snap.videos.count, 10)
        XCTAssertTrue(snap.videos.allSatisfy { $0.status == .published })
    }
}
