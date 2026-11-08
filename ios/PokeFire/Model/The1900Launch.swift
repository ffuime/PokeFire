import AppIntents
import Observation
import UIKit

@Observable
@MainActor
final class The1900Launch {
    static let shared = The1900Launch()
    static let shortcutType = "me.ffui.pokefire.the1900"

    var open = false
}

struct OpenThe1900Intent: AppIntent {
    static let title: LocalizedStringResource = "THE 1900を開く"
    static let description = IntentDescription("Pokéloot の THE 1900 を直接開きます。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        The1900Launch.shared.open = true
        return .result()
    }
}

struct PokelootShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenThe1900Intent(),
            phrases: ["\(.applicationName)でTHE 1900を開く"],
            shortTitle: "THE 1900",
            systemImageName: "character.book.closed"
        )
    }
}

final class PokelootAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if options.shortcutItem?.type == The1900Launch.shortcutType {
            The1900Launch.shared.open = true
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PokelootSceneDelegate.self
        return configuration
    }
}

final class PokelootSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let matched = shortcutItem.type == The1900Launch.shortcutType
        if matched { The1900Launch.shared.open = true }
        completionHandler(matched)
    }
}
