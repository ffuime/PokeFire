import SwiftUI

@main
struct PokeFireApp: App {
    @UIApplicationDelegateAdaptor(PokelootAppDelegate.self) private var appDelegate
    @State private var launch = The1900Launch.shared
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
                    if url.host == "the1900" {
                        launch.handle(The1900Launch.shortcutType)
                    } else if url.host == "gmail" {
                        launch.handle(The1900Launch.gmailShortcutType)
                    } else {
                        model.open(url)
                    }
                }
                .fullScreenCover(isPresented: $launch.open) {
                    The1900View()
                }
                .background {
                    Color.clear
                        .fullScreenCover(isPresented: $launch.gmail) {
                            GmailView()
                        }
                }
        }
    }
}
