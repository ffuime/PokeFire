import SwiftUI

@main
struct PokeFireApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .tint(Palette.accent)
                .onOpenURL { url in
                    model.open(url)
                }
        }
    }
}
