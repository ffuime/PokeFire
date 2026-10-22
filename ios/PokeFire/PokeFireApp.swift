import SwiftUI

@main
struct PokeFireApp: App {
    @State private var model = AppModel()
    @State private var stats = StatsModel()
    @State private var box = BoxModel()
    @AppStorage(AppSettings.appearanceKey) private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(stats)
                .environment(box)
                .onAppear {
                    AppSettings.applyAppearance(appearance)
                    AppSettings.applyAutoSleep(UserDefaults.standard.object(forKey: AppSettings.autoSleepKey) as? Bool ?? true)
                }
                .tint(Palette.accent)
                .onOpenURL { url in
                    model.open(url)
                }
        }
    }
}
