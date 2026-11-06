import Foundation
import EscaletaKit

extension Step {
    var displayName: String {
        switch self {
        case .topic: "Tema"
        case .script: "Guion"
        case .thumbnail: "Miniatura"
        case .firstEdit: "1.ª edición"
        case .review: "Revisión"
        }
    }
}

extension ChannelGroup {
    var displayName: String {
        switch self {
        case .a: "A: monetizado"
        case .b: "B: siguiente en monetizar"
        case .c: "C: el resto"
        }
    }
}

struct Headline {
    var title: String
    var subtitle: String
    var button: String?
}

enum SuggestionText {
    static func make(_ suggestion: Suggestion, channels: [Channel]) -> Headline {
        func name(_ id: UUID) -> String { channels.first { $0.id == id }?.name ?? "canal eliminado" }
        switch suggestion {
        case .task(let id, let action):
            let channel = name(id)
            switch action {
            case .start(.topic): return Headline(title: "Elige el tema de \(channel)", subtitle: "Es el siguiente en el orden.", button: "Tema elegido")
            case .start(.script): return Headline(title: "Escribe el guion de \(channel)", subtitle: "Ya tiene el tema.", button: "Guion hecho")
            case .start(.thumbnail): return Headline(title: "Haz la miniatura de \(channel)", subtitle: "Este paso necesita tu atención.", button: "Empezar miniatura")
            case .start(.firstEdit): return Headline(title: "Lanza la 1.ª edición de \(channel)", subtitle: "Solo te ocupa un momento y luego haces otra cosa.", button: "Empezar a crear")
            case .start(.review): return Headline(title: "Revisa el vídeo de \(channel)", subtitle: "Audios de fondo, suscríbete y subtítulos.", button: "Revisión hecha")
            case .continue(let step): return Headline(title: "Sigue con \(step.displayName.lowercased()) de \(channel)", subtitle: "Ya la habías empezado.", button: "\(step.displayName) hecha")
            case .reviewRender: return Headline(title: "Revisa la 1.ª edición de \(channel)", subtitle: "Lleva un buen rato creándose.", button: "Ya terminó")
            case .publish: return Headline(title: "Publica el vídeo de \(channel)", subtitle: "Está terminado y ya puede salir.", button: "Publicar")
            }
        case .waitingForRenders(let count):
            return Headline(title: "Esperando \(count) \(count == 1 ? "vídeo" : "vídeos")", subtitle: "Se están creando. Marca cada uno cuando termine.", button: nil)
        case .waitingToPublish(let id, let date):
            return Headline(title: "\(name(id)) sale a las \(date.formatted(date: .omitted, time: .shortened))", subtitle: "Antes no se cumple el mínimo de horas desde el último vídeo.", button: nil)
        case .nothingActionable:
            return Headline(title: "Queda algo pendiente", subtitle: "Revisa los pasos de la lista.", button: nil)
        case .allDone:
            return Headline(title: "Hoy está todo hecho", subtitle: "No queda ningún vídeo obligatorio para hoy.", button: nil)
        }
    }
}
