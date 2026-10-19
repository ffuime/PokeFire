import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

struct NativeBar: Decodable, Equatable {
    var width: Double = 0
    var color: String = ""
}

struct NativeResult: Decodable, Equatable {
    var percent: String = ""
    var damage: String = ""
    var hp: String = ""
    var judge: String = ""
    var rate: String = ""
    var sure: NativeBar = NativeBar()
    var maybe: NativeBar = NativeBar()
}

struct NativeTab: Decodable, Equatable, Identifiable {
    let id: Int
    let kind: String
    let label: String
    let index: Int
}

struct NativeEnvironment: Decodable, Equatable {
    var weather: String = "none"
    var field: String = "none"
}

struct NativeState: Decodable {
    let result: NativeResult
    let tabs: [NativeTab]
    let active: Int
    let covered: Bool
    let environment: NativeEnvironment
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func play(_ style: String) {
        switch style {
        case "selection":
            selection.selectionChanged()
            selection.prepare()
        case "medium":
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "rigid":
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case "soft":
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case "success":
            notification.notificationOccurred(.success)
        case "warning":
            notification.notificationOccurred(.warning)
        case "error":
            notification.notificationOccurred(.error)
        default:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

final class ScriptHandler: NSObject, WKScriptMessageHandler {
    private let onMessage: (Any) -> Void

    init(onMessage: @escaping (Any) -> Void) {
        self.onMessage = onMessage
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onMessage(message.body)
    }
}

final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL? = Bundle.main.url(forResource: "web", withExtension: nil)

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let root else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        var file = root.appendingPathComponent(String(url.path.drop(while: { $0 == "/" }))).standardizedFileURL
        var isDirectory: ObjCBool = false
        if url.path.isEmpty || (FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory) && isDirectory.boolValue) {
            file = file.appendingPathComponent("index.html")
        }
        guard file.path.hasPrefix(root.standardizedFileURL.path), let data = try? Data(contentsOf: file) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didFinish()
            return
        }
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let headers = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
            "Access-Control-Allow-Origin": "*",
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

@MainActor
final class WebStore: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let home = URL(string: "pokefire://app/index.html")!
    static let help = URL(string: "pokefire://app/help/index.html")!

    @Published var result = NativeResult()
    @Published var tabs: [NativeTab] = []
    @Published var active = 0
    @Published var covered = false
    @Published var onMainPage = true
    @Published var ready = false
    @Published var shareItem: ShareItem?
    @Published var environment = NativeEnvironment()
    @Published var showEnvironment = false

    private var pendingShare: String?
    let webView: WKWebView

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "pokefire")
        configuration.websiteDataStore = .default()
        let controller = WKUserContentController()
        configuration.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        controller.add(ScriptHandler { [weak self] body in
            MainActor.assumeIsolated {
                self?.handle(body)
            }
        }, name: "pokefire")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
        webView.load(URLRequest(url: Self.home))
    }

    func command(_ call: String) {
        webView.evaluateJavaScript("window.PokeFireNative && void window.PokeFireNative.\(call)", completionHandler: nil)
    }

    func setEnvironment(_ kind: String, _ key: String) {
        command("setEnvironment('\(kind)', '\(key)')")
    }

    func openHistory() {
        command("openHistory()")
    }

    func open(_ url: URL) {
        guard
            url.scheme == "pokefire",
            let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "s" })?.value,
            !code.isEmpty,
            code.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_" })
        else { return }
        if ready && onMainPage {
            command("openShare('\(code)')")
        } else {
            pendingShare = code
            if !onMainPage { goHome() }
        }
    }

    func openHelp() {
        webView.load(URLRequest(url: Self.help))
    }

    func goHome() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            webView.load(URLRequest(url: Self.home))
        }
    }

    private func handle(_ body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return }
        switch type {
        case "haptic":
            Haptics.play(message["style"] as? String ?? "light")
        case "share":
            if let text = message["url"] as? String, let url = URL(string: text) {
                shareItem = ShareItem(url: url)
            }
        case "state":
            guard
                let data = try? JSONSerialization.data(withJSONObject: message),
                let state = try? JSONDecoder().decode(NativeState.self, from: data)
            else { return }
            if result != state.result { result = state.result }
            if tabs != state.tabs { tabs = state.tabs }
            if active != state.active { active = state.active }
            if covered != state.covered { covered = state.covered }
            if environment != state.environment { environment = state.environment }
            if !ready {
                ready = true
                if let code = pendingShare {
                    pendingShare = nil
                    command("openShare('\(code)')")
                }
            }
        default:
            break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        if url.scheme == "pokefire" || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" {
            return .allow
        }
        if navigationAction.targetFrame?.isMainFrame ?? true {
            _ = await UIApplication.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onMainPage = !(webView.url?.path.contains("/help") ?? false)
        command("sync()")
        if onMainPage, ready, let code = pendingShare {
            pendingShare = nil
            command("openShare('\(code)')")
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

extension Color {
    init(css: String, fallback: Color = Color(white: 0.75)) {
        let text = css.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#"), text.count == 7, let value = Int(text.dropFirst(), radix: 16) {
            self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
            return
        }
        let numbers = text.split(whereSeparator: { !"0123456789.".contains($0) }).compactMap { Double($0) }
        if text.hasPrefix("rgb"), numbers.count >= 3 {
            self.init(red: numbers[0] / 255, green: numbers[1] / 255, blue: numbers[2] / 255)
            return
        }
        self = fallback
    }
}
