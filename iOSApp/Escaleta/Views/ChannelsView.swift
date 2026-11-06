import SwiftUI
import EscaletaKit

struct ChannelsView: View {
    let model: AppModel
    @State private var editing: ChannelDraft?

    var body: some View {
        NavigationStack {
            List {
                Text("El grupo A va primero, luego B y C. El ritmo marca cada cuántos días toca un vídeo.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(sorted) { channel in
                    Button { editing = ChannelDraft(channel: channel) } label: {
                        VStack(alignment: .leading) {
                            Text(channel.name).font(.headline)
                            Text("Grupo \(channel.group.rawValue) · \(channel.cadenceDays == 1 ? "a diario" : "cada \(channel.cadenceDays) días")\(channel.isActive ? "" : " · en pausa")")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Canales")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Añadir canal") {
                        editing = ChannelDraft(channel: Channel(name: "", group: .c, cadenceDays: 2))
                    }
                }
            }
            .sheet(item: $editing) { draft in
                ChannelEditor(model: model, draft: draft)
            }
        }
    }

    private var sorted: [Channel] {
        model.snapshot.channels.sorted { ($0.group, $0.name) < ($1.group, $1.name) }
    }
}

struct ChannelDraft: Identifiable {
    let id = UUID()
    var channel: Channel
}

private struct ChannelEditor: View {
    let model: AppModel
    @State var draft: ChannelDraft
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, draft: ChannelDraft) {
        self.model = model
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $draft.channel.name)
                Picker("Prioridad", selection: $draft.channel.group) {
                    ForEach(ChannelGroup.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Stepper("Un vídeo cada \(draft.channel.cadenceDays) día\(draft.channel.cadenceDays == 1 ? "" : "s")",
                        value: $draft.channel.cadenceDays, in: 1...7)
                Toggle("Activo", isOn: $draft.channel.isActive)
            }
            .navigationTitle("Canal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        model.save(channel: draft.channel)
                        dismiss()
                    }
                    .disabled(draft.channel.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 260)
    }
}

#Preview("Canales") {
    ChannelsView(model: .preview)
}

#Preview("Editar canal") {
    ChannelEditor(
        model: .preview,
        draft: ChannelDraft(channel: Channel(name: "Taller Cero", group: .a, cadenceDays: 1))
    )
}
