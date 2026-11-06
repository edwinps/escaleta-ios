import SwiftUI
import EscaletaKit

@main
struct EscaletaApp: App {
    @State private var model = AppModel(repository: JSONFileRepository(url: JSONFileRepository.defaultURL))

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
