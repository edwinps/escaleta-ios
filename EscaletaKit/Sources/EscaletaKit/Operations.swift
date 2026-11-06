import Foundation

public enum OperationError: Error, Equatable, LocalizedError {
    case channelNotFound
    case renderLimitReached(max: Int)
    case emptyTitle

    public var errorDescription: String? {
        switch self {
        case .channelNotFound: "No se encontró el canal."
        case .renderLimitReached(let max): "Ya hay \(max) vídeos creándose. Marca uno como terminado para lanzar otro."
        case .emptyTitle: "Escribe el nombre del vídeo."
        }
    }
}

extension Snapshot {
    public var runningRenders: Int {
        videos.filter { $0.status == .open && $0.state(of: .firstEdit) == .inProgress }.count
    }

    // slow steps cycle pending -> in progress -> done, the rest just toggle
    public mutating func cycle(_ step: Step, channelID: UUID, now: Date) throws {
        guard channels.contains(where: { $0.id == channelID }) else { throw OperationError.channelNotFound }
        let existing = openVideoIndex(for: channelID)
        let current = existing.map { videos[$0].state(of: step) } ?? .pending

        let next: StepState
        if step.isSlow {
            switch current {
            case .pending: next = .inProgress
            case .inProgress: next = .done
            case .done: next = .pending
            }
        } else {
            next = current == .done ? .pending : .done
        }

        if step == .firstEdit, next == .inProgress, runningRenders >= settings.maxConcurrentRenders {
            throw OperationError.renderLimitReached(max: settings.maxConcurrentRenders)
        }

        let index = existing ?? createVideo(for: channelID, now: now)
        var progress = videos[index].progress[step] ?? StepProgress()
        switch next {
        case .pending:
            progress = StepProgress()
        case .inProgress:
            progress = StepProgress(state: .inProgress, startedAt: now, finishedAt: nil)
        case .done:
            progress.state = .done
            progress.finishedAt = now
        }
        videos[index].progress[step] = progress
    }

    public func publishWarning(channelID: UUID, at date: Date) -> Double? {
        let previous = videos
            .filter { $0.channelID == channelID && $0.status == .published }
            .compactMap(\.publishedAt)
            .filter { $0 <= date }
            .max()
        guard let previous else { return nil }
        let hours = date.timeIntervalSince(previous) / 3_600
        return hours < Double(settings.minHoursBetweenVideos) ? hours : nil
    }

    public mutating func publish(channelID: UUID, title: String, at date: Date, now: Date) throws {
        guard channels.contains(where: { $0.id == channelID }) else { throw OperationError.channelNotFound }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OperationError.emptyTitle }
        let index = openVideoIndex(for: channelID) ?? createVideo(for: channelID, now: now)
        videos[index].title = trimmed
        videos[index].status = .published
        videos[index].publishedAt = date
    }

    public mutating func upsert(_ channel: Channel) {
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
    }

    // MARK: - Helpers

    private func openVideoIndex(for channelID: UUID) -> Int? {
        videos.indices
            .filter { videos[$0].channelID == channelID && videos[$0].status == .open }
            .min { videos[$0].createdAt < videos[$1].createdAt }
    }

    private mutating func createVideo(for channelID: UUID, now: Date) -> Int {
        videos.append(Video(channelID: channelID, createdAt: now))
        return videos.count - 1
    }
}
