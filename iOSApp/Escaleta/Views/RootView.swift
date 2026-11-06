import SwiftUI

struct RootView: View {
    let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        TabView {
            NavigationStack {
                TodayView(model: model).navigationTitle("Escaleta")
            }
            .tabItem { Label("Hoy", systemImage: "list.bullet.rectangle") }

            ChannelsView(model: model)
                .tabItem { Label("Canales", systemImage: "tv") }
        }
    }
}

#Preview {
    RootView(model: .preview)
}
