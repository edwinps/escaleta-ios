import SwiftUI
import Observation
import EscaletaKit

@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: Snapshot
    var message: String?
    private let repository: SnapshotRepository
    private var canSave = true

    init(repository: SnapshotRepository, now: Date = Date()) {
        self.repository = repository
        do {
            if let stored = try repository.load() {
                snapshot = stored
            } else {
                snapshot = SeedData.makeSnapshot(now: now)
                try repository.save(snapshot)
            }
        } catch {
            // never overwrite a file we could not read
            snapshot = SeedData.makeSnapshot(now: now)
            canSave = false
            message = "No se pudieron leer tus datos guardados. Los cambios no se guardarán en esta sesión."
        }
    }

    func plan(at now: Date) -> DayPlan {
        Planner.plan(snapshot: snapshot, now: now)
    }

    func suggestion(for plan: DayPlan, at now: Date) -> Suggestion {
        Planner.suggestion(plan: plan, snapshot: snapshot, now: now)
    }

    func cycle(_ step: Step, channelID: UUID) {
        apply { try $0.cycle(step, channelID: channelID, now: Date()) }
    }

    func publish(channelID: UUID, title: String, at date: Date) -> Bool {
        apply { try $0.publish(channelID: channelID, title: title, at: date, now: Date()) }
    }

    func save(channel: Channel) {
        apply { $0.upsert(channel) }
    }

    func publishWarning(channelID: UUID, at date: Date) -> Double? {
        snapshot.publishWarning(channelID: channelID, at: date)
    }

    @discardableResult
    private func apply(_ change: (inout Snapshot) throws -> Void) -> Bool {
        var copy = snapshot
        do {
            try change(&copy)
        } catch {
            message = error.localizedDescription
            return false
        }
        snapshot = copy
        if canSave {
            do { try repository.save(copy) } catch { message = "No se pudo guardar. Inténtalo de nuevo." }
        }
        return true
    }
}

#if DEBUG
extension AppModel {
    // in-memory, seeded with the sample channels
    static var preview: AppModel {
        AppModel(repository: InMemoryRepository())
    }
}
#endif
