import AppIntents
import Observation
import UIKit

@Observable
@MainActor
final class The1900Launch {
    static let shared = The1900Launch()
    static let shortcutType = "me.ffui.pokefire.the1900"
    static let gmailShortcutType = "me.ffui.pokefire.gmail"

    var open = false
    var gmail = false

    @discardableResult
    func handle(_ type: String) -> Bool {
        switch type {
        case Self.shortcutType:
            gmail = false
            open = true
        case Self.gmailShortcutType:
            open = false
            gmail = true
        default:
            return false
        }
        return true
    }
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

struct OpenGmailIntent: AppIntent {
    static let title: LocalizedStringResource = "Gmailを開く"
    static let description = IntentDescription("Pokéloot の Gmail を直接開きます。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        The1900Launch.shared.handle(The1900Launch.gmailShortcutType)
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
        AppShortcut(
            intent: OpenGmailIntent(),
            phrases: ["\(.applicationName)でGmailを開く"],
            shortTitle: "Gmail",
            systemImageName: "envelope"
        )
    }
}

final class PokelootAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let type = options.shortcutItem?.type {
            The1900Launch.shared.handle(type)
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
        completionHandler(The1900Launch.shared.handle(shortcutItem.type))
    }
}
