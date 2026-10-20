import SwiftUI

@main
struct PokeFireApp: App {
    @State private var model = AppModel()
    @State private var stats = StatsModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(stats)
                .preferredColorScheme(.light)
                .tint(Palette.accent)
                .onOpenURL { url in
                    model.open(url)
                }
        }
    }
}
