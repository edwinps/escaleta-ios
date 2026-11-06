import SwiftUI
import EscaletaKit

struct PublishTarget: Identifiable {
    let id = UUID()
    let channel: Channel
    let suggestedTitle: String
}

struct TodayView: View {
    let model: AppModel
    @State private var publishing: PublishTarget?

    var body: some View {
        // the plan depends on the clock, refresh every minute
        TimelineView(.everyMinute) { context in
            content(now: context.date)
        }
        .sheet(item: $publishing) { target in
            PublishSheet(model: model, target: target)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let plan = model.plan(at: now)
        let suggestion = model.suggestion(for: plan, at: now)
        let headline = SuggestionText.make(suggestion, channels: model.snapshot.channels)

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ahora").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(headline.title).font(.title2.bold())
                    Text(headline.subtitle).foregroundStyle(.secondary)
                    if let button = headline.button {
                        Button(button) { perform(suggestion) }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Hoy (\(plan.due.count))") {
                if plan.due.isEmpty {
                    Text("No queda ningún vídeo obligatorio para hoy.").foregroundStyle(.secondary)
                }
                ForEach(plan.due, id: \.channel.id) { status in
                    ChannelCard(status: status, now: now, model: model) {
                        publishing = PublishTarget(channel: status.channel, suggestedTitle: status.currentVideo?.title ?? "")
                    }
                }
            }

            if !plan.resting.isEmpty {
                Section("Descansan hoy") {
                    ForEach(plan.resting, id: \.channel.id) { status in
                        HStack {
                            Text(status.channel.name)
                            Spacer()
                            if let last = status.lastPublishedAt {
                                Text(last, style: .relative).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .alert("Aviso", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text(model.message ?? "")
        }
    }

    private func perform(_ suggestion: Suggestion) {
        guard case .task(let id, let action) = suggestion else { return }
        switch action {
        case .publish:
            if let channel = model.snapshot.channels.first(where: { $0.id == id }) {
                let title = model.snapshot.videos.first { $0.channelID == id && $0.status == .open }?.title ?? ""
                publishing = PublishTarget(channel: channel, suggestedTitle: title)
            }
        case .start(let step), .continue(let step):
            model.cycle(step, channelID: id)
        case .reviewRender:
            model.cycle(.firstEdit, channelID: id)
        }
    }
}

private struct ChannelCard: View {
    let status: ChannelStatus
    let now: Date
    let model: AppModel
    let onPublish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.channel.name).font(.headline)
                Text(status.channel.group.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary))
            }
            if let last = status.lastPublishedAt {
                (Text("Último: ") + Text(last, style: .relative) + Text(" atrás"))
                    .font(.footnote).foregroundStyle(status.lateness > 1 ? Color.red : Color.secondary)
            } else {
                Text("Sin publicaciones registradas.").font(.footnote).foregroundStyle(.secondary)
            }
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    stepButton(.topic)
                    stepButton(.script)
                    stepButton(.thumbnail)
                }
                GridRow {
                    stepButton(.firstEdit)
                    stepButton(.review)
                    Button("Publicar", action: onPublish)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stepButton(_ step: Step) -> some View {
        let state = status.currentVideo?.state(of: step) ?? .pending
        return Button { model.cycle(step, channelID: status.channel.id) } label: {
            Text(state == .done ? "✓ \(step.displayName)" : step.displayName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(state == .done ? .green : state == .inProgress ? .orange : .gray)
    }
}

private struct PublishSheet: View {
    let model: AppModel
    let target: PublishTarget
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date = Date()

    init(model: AppModel, target: PublishTarget) {
        self.model = model
        self.target = target
        _title = State(initialValue: target.suggestedTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre del vídeo", text: $title)
                DatePicker("Fecha y hora", selection: $date)
                if let hours = model.publishWarning(channelID: target.channel.id, at: date) {
                    Text("Solo pasan \(hours.formatted(.number.precision(.fractionLength(1)))) h desde el vídeo anterior. Puedes guardarlo igualmente.")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Publicar en \(target.channel.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if model.publish(channelID: target.channel.id, title: title, at: date) { dismiss() }
                    }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 260)
    }
}

#Preview("Hoy") {
    NavigationStack {
        TodayView(model: .preview)
            .navigationTitle("Escaleta")
    }
}

#Preview("Publicar") {
    let model = AppModel.preview
    return PublishSheet(model: model, target: PublishTarget(channel: model.snapshot.channels[0], suggestedTitle: ""))
}
