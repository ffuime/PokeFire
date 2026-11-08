import CryptoKit
import Foundation
import Observation
import Security

struct GmailAccount: Codable, Equatable, Identifiable, Hashable {
    var email: String
    var name: String
    var picture: String?
    var refreshToken: String

    var id: String { email }
}

enum GmailError: LocalizedError {
    case missingClient
    case unauthorized
    case cancelled
    case http(Int, String)
    case invalid

    var errorDescription: String? {
        switch self {
        case .missingClient: return "Client ID が設定されていません。"
        case .unauthorized: return "ログインの有効期限が切れました。もう一度ログインしてください。"
        case .cancelled: return "キャンセルしました。"
        case .http(let code, let message): return "通信に失敗しました（\(code)）\(message.isEmpty ? "" : "\n\(message)")"
        case .invalid: return "データを読み取れませんでした。"
        }
    }
}

enum GmailKeychain {
    private static let service = "me.ffui.pokefire.gmail"
    private static let key = "accounts"

    static func load() -> [GmailAccount] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let accounts = try? JSONDecoder().decode([GmailAccount].self, from: data) else { return [] }
        return accounts
    }

    static func save(_ accounts: [GmailAccount]) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}

enum GmailAuth {
    static let clientKey = "gmail-client-id"
    static let consoleURL = URL(string: "https://console.cloud.google.com/apis/credentials")!
    static let scopes = [
        "openid", "email", "profile",
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.settings.basic",
    ]

    struct Tokens: Decodable {
        let accessToken: String
        let expiresIn: Int
        let refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    static var clientID: String {
        (UserDefaults.standard.string(forKey: clientKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scheme(_ id: String) -> String {
        "com.googleusercontent.apps." + id.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }

    static func redirect(_ id: String) -> String {
        scheme(id) + ":/oauth2redirect"
    }

    static func verifier() -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<64).map { _ in characters.randomElement()! })
    }

    static func challenge(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URL
    }

    static func authURL(_ id: String, challenge: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: id),
            URLQueryItem(name: "redirect_uri", value: redirect(id)),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account consent"),
        ]
        return components.url!
    }

    private static func post(_ fields: [String: String]) async throws -> Tokens {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 400 || status == 401 {
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.contains("invalid_grant") { throw GmailError.unauthorized }
            throw GmailError.http(status, text)
        }
        guard (200..<300).contains(status) else { throw GmailError.http(status, String(data: data, encoding: .utf8) ?? "") }
        return try JSONDecoder().decode(Tokens.self, from: data)
    }

    static func exchange(code: String, verifier: String, id: String) async throws -> Tokens {
        try await post([
            "code": code, "client_id": id, "redirect_uri": redirect(id),
            "grant_type": "authorization_code", "code_verifier": verifier,
        ])
    }

    static func refresh(_ token: String, id: String) async throws -> Tokens {
        try await post(["refresh_token": token, "client_id": id, "grant_type": "refresh_token"])
    }

    static func profile(_ accessToken: String) async throws -> (email: String, name: String, picture: String?) {
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let email = json["email"] as? String else {
            throw GmailError.invalid
        }
        return (email, json["name"] as? String ?? email, json["picture"] as? String)
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL text: String) {
        var value = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while value.count % 4 != 0 { value += "=" }
        self.init(base64Encoded: value, options: .ignoreUnknownCharacters)
    }
}

enum Mailbox: String, CaseIterable, Identifiable {
    case allInboxes, inbox, spam, trash, sent, scheduled, drafts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allInboxes: return "すべての受信トレイ"
        case .inbox: return "メイン"
        case .spam: return "迷惑メール"
        case .trash: return "ゴミ箱"
        case .sent: return "送信済み"
        case .scheduled: return "送信予定"
        case .drafts: return "下書き"
        }
    }

    var symbol: String {
        switch self {
        case .allInboxes: return "tray.2"
        case .inbox: return "tray"
        case .spam: return "exclamationmark.octagon"
        case .trash: return "trash"
        case .sent: return "paperplane"
        case .scheduled: return "clock"
        case .drafts: return "doc"
        }
    }

    var label: String {
        switch self {
        case .allInboxes, .inbox: return "INBOX"
        case .spam: return "SPAM"
        case .trash: return "TRASH"
        case .sent: return "SENT"
        case .scheduled: return "SCHEDULED"
        case .drafts: return "DRAFT"
        }
    }

    var includesSpamTrash: Bool { self == .spam || self == .trash }
    var showsRecipient: Bool { self == .sent || self == .scheduled || self == .drafts }
}

struct MailItem: Identifiable, Hashable {
    let account: String
    let messageID: String
    let threadID: String
    var fromName: String
    var fromEmail: String
    var toLine: String
    var subject: String
    var snippet: String
    var date: Date
    var labels: Set<String>

    var id: String { account + "/" + messageID }
    var unread: Bool { labels.contains("UNREAD") }
    var starred: Bool { labels.contains("STARRED") }
}

struct MailAttachment: Identifiable, Hashable {
    let attachmentID: String
    let filename: String
    let mimeType: String
    let size: Int
    let contentID: String?

    var id: String { attachmentID + filename }
}

struct MailContent {
    var html: String
    var plain: String
    var headers: [(name: String, value: String)]
    var attachments: [MailAttachment]

    func header(_ name: String) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    func all(_ name: String) -> [String] {
        headers.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }.map(\.value)
    }

    var unsubscribe: URL? {
        guard let value = header("List-Unsubscribe") else { return nil }
        let links = value.components(separatedBy: ",").compactMap { part -> URL? in
            let trimmed = part.trimmingCharacters(in: CharacterSet(charactersIn: " <>\t\r\n"))
            return URL(string: trimmed)
        }
        return links.first { $0.scheme?.hasPrefix("http") == true } ?? links.first { $0.scheme == "mailto" }
    }

    var encrypted: Bool {
        all("Received").contains { $0.contains("ESMTPS") || $0.contains("TLS") }
    }
}

enum MailText {
    static func address(_ value: String) -> (name: String, email: String) {
        let text = value.trimmingCharacters(in: .whitespaces)
        if let open = text.lastIndex(of: "<"), let close = text.lastIndex(of: ">"), open < close {
            let email = String(text[text.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            var name = String(text[..<open]).trimmingCharacters(in: .whitespaces)
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return (name.isEmpty ? email : name, email)
        }
        return (text, text)
    }

    static func entities(_ text: String) -> String {
        var value = text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        while let range = value.range(of: "&#(x?[0-9a-fA-F]+);", options: .regularExpression) {
            let token = value[range].dropFirst(2).dropLast()
            let code = token.hasPrefix("x") ? UInt32(token.dropFirst(), radix: 16) : UInt32(token)
            value.replaceSubrange(range, with: code.flatMap { UnicodeScalar($0) }.map { String(Character($0)) } ?? "")
        }
        return value.replacingOccurrences(of: "&amp;", with: "&")
    }

    static func plain(fromHTML html: String) -> String {
        var text = html
        for pattern in ["<style[\\s\\S]*?</style>", "<script[\\s\\S]*?</script>", "<head[\\s\\S]*?</head>"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</(p|div|tr|li|h[1-6])>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = entities(text)
        text = text.replacingOccurrences(of: "[ \\t]+\\n", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decode(_ data: Data, charset: String?) -> String {
        var encodings: [String.Encoding] = []
        if let charset {
            let cf = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
            if cf != kCFStringEncodingInvalidId {
                encodings.append(String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf)))
            }
        }
        encodings += [.utf8, .shiftJIS, .japaneseEUC, .iso2022JP, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return ""
    }

    static func charset(_ contentType: String?) -> String? {
        guard let contentType, let range = contentType.range(of: "charset=", options: .caseInsensitive) else { return nil }
        let rest = contentType[range.upperBound...]
        let value = rest.prefix { $0 != ";" }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
    }

    static func encodeHeader(_ text: String) -> String {
        if text.allSatisfy({ $0.isASCII }) { return text }
        return "=?UTF-8?B?\(Data(text.utf8).base64EncodedString())?="
    }

    static func listTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "H:mm"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: date)
    }

    static func fullTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: Date())
            ? "M月d日(E) H:mm" : "yyyy年M月d日(E) H:mm"
        return formatter.string(from: date)
    }
}

struct ComposeAttachment: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var mimeType: String
    var data: Data
}

struct ComposeDraft: Equatable {
    var account: String
    var to = ""
    var cc = ""
    var subject = ""
    var body = ""
    var attachments: [ComposeAttachment] = []
    var threadID: String?
    var inReplyTo: String?
    var references: String?

    var isEmpty: Bool {
        to.trimmingCharacters(in: .whitespaces).isEmpty && subject.isEmpty && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty
    }

    func mime(from sender: GmailAccount?) -> Data {
        let boundary = "pokeloot-" + UUID().uuidString
        var lines: [String] = []
        if let sender {
            lines.append("From: \(MailText.encodeHeader(sender.name)) <\(sender.email)>")
        }
        lines.append("To: \(to)")
        if !cc.trimmingCharacters(in: .whitespaces).isEmpty { lines.append("Cc: \(cc)") }
        lines.append("Subject: \(MailText.encodeHeader(subject))")
        lines.append("MIME-Version: 1.0")
        if let inReplyTo { lines.append("In-Reply-To: \(inReplyTo)") }
        if let references { lines.append("References: \(references)") }
        func wrap(_ data: Data) -> String {
            data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
        }
        let text = [
            "Content-Type: text/plain; charset=\"UTF-8\"",
            "Content-Transfer-Encoding: base64",
            "",
            wrap(Data(body.utf8)),
        ]
        if attachments.isEmpty {
            lines += text
        } else {
            lines.append("Content-Type: multipart/mixed; boundary=\"\(boundary)\"")
            lines.append("")
            lines.append("--\(boundary)")
            lines += text
            for file in attachments {
                let name = MailText.encodeHeader(file.name)
                lines.append("--\(boundary)")
                lines.append("Content-Type: \(file.mimeType); name=\"\(name)\"")
                lines.append("Content-Disposition: attachment; filename=\"\(name)\"")
                lines.append("Content-Transfer-Encoding: base64")
                lines.append("")
                lines.append(wrap(file.data))
            }
            lines.append("--\(boundary)--")
        }
        return Data(lines.joined(separator: "\r\n").utf8)
    }
}

enum GmailAPI {
    static let base = "https://gmail.googleapis.com/gmail/v1/users/me/"
    static let upload = "https://gmail.googleapis.com/upload/gmail/v1/users/me/"

    static func request(_ token: String, _ path: String, query: [URLQueryItem] = [], method: String = "GET", json: [String: Any]? = nil, root: String = base, body: Data? = nil, contentType: String? = nil) async throws -> Data {
        var components = URLComponents(string: root + path)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        } else if let body {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw GmailError.unauthorized }
        guard (200..<300).contains(status) else {
            var message = ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any] {
                message = error["message"] as? String ?? ""
            }
            throw GmailError.http(status, message)
        }
        return data
    }

    static func object(_ data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw GmailError.invalid }
        return json
    }

    static func item(_ json: [String: Any], account: String) -> MailItem? {
        guard let id = json["id"] as? String else { return nil }
        let headers = (json["payload"] as? [String: Any])?["headers"] as? [[String: Any]] ?? []
        func header(_ name: String) -> String {
            headers.first { ($0["name"] as? String)?.caseInsensitiveCompare(name) == .orderedSame }?["value"] as? String ?? ""
        }
        let from = MailText.address(header("From"))
        let millis = Double(json["internalDate"] as? String ?? "") ?? 0
        let toLine = header("To").components(separatedBy: ",").map { MailText.address($0).name }.joined(separator: ", ")
        return MailItem(
            account: account,
            messageID: id,
            threadID: json["threadId"] as? String ?? id,
            fromName: from.name,
            fromEmail: from.email,
            toLine: toLine,
            subject: header("Subject"),
            snippet: MailText.entities(json["snippet"] as? String ?? ""),
            date: Date(timeIntervalSince1970: millis / 1000),
            labels: Set(json["labelIds"] as? [String] ?? [])
        )
    }

    static func content(_ json: [String: Any]) -> MailContent {
        var html = ""
        var plain = ""
        var attachments: [MailAttachment] = []
        let payload = json["payload"] as? [String: Any] ?? [:]
        let topHeaders = (payload["headers"] as? [[String: Any]] ?? []).map {
            (name: $0["name"] as? String ?? "", value: $0["value"] as? String ?? "")
        }
        func walk(_ part: [String: Any]) {
            let mime = (part["mimeType"] as? String ?? "").lowercased()
            let filename = part["filename"] as? String ?? ""
            let body = part["body"] as? [String: Any] ?? [:]
            let headers = part["headers"] as? [[String: Any]] ?? []
            func header(_ name: String) -> String? {
                headers.first { ($0["name"] as? String)?.caseInsensitiveCompare(name) == .orderedSame }?["value"] as? String
            }
            if let children = part["parts"] as? [[String: Any]] {
                children.forEach(walk)
                return
            }
            if let attachmentID = body["attachmentId"] as? String {
                let cid = header("Content-ID")?.trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
                attachments.append(MailAttachment(
                    attachmentID: attachmentID,
                    filename: filename.isEmpty ? "添付ファイル" : filename,
                    mimeType: mime,
                    size: body["size"] as? Int ?? 0,
                    contentID: cid
                ))
                return
            }
            guard filename.isEmpty, let encoded = body["data"] as? String, let data = Data(base64URL: encoded) else { return }
            let text = MailText.decode(data, charset: MailText.charset(header("Content-Type")))
            if mime == "text/html", html.isEmpty { html = text }
            if mime == "text/plain", plain.isEmpty { plain = text }
        }
        walk(payload)
        return MailContent(html: html, plain: plain, headers: topHeaders, attachments: attachments)
    }
}

@Observable
@MainActor
final class MailFeed {
    var items: [MailItem] = []
    var loading = false
    var exhausted = false
    var error: String?
    @ObservationIgnored var tokens: [String: String] = [:]
    @ObservationIgnored var generation = 0
}

struct MailToast: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let undo: Bool

    static func == (lhs: MailToast, rhs: MailToast) -> Bool { lhs.id == rhs.id }
}

@Observable
@MainActor
final class GmailStore {
    static let shared = GmailStore()
    private static let selectedKey = "gmail-selected-account"
    private static let mailboxKey = "gmail-mailbox"

    var accounts: [GmailAccount] = []
    var selected: String?
    var mailbox: Mailbox = .inbox
    var query = ""
    var unread: [String: Int] = [:]
    let all = MailFeed()
    let starred = MailFeed()
    var toast: MailToast?
    var signingIn = false
    var authError: String?
    @ObservationIgnored private var access: [String: (token: String, expiry: Date)] = [:]
    @ObservationIgnored private var undoAction: (() async -> Void)?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init() {
        accounts = GmailKeychain.load()
        let saved = UserDefaults.standard.string(forKey: Self.selectedKey)
        selected = accounts.first { $0.email == saved }?.email ?? accounts.first?.email
        mailbox = Mailbox(rawValue: UserDefaults.standard.string(forKey: Self.mailboxKey) ?? "") ?? .inbox
    }

    var account: GmailAccount? { accounts.first { $0.email == selected } }

    func accountInfo(_ email: String) -> GmailAccount? { accounts.first { $0.email == email } }

    private func scope(_ feed: MailFeed) -> [String] {
        if mailbox == .allInboxes { return accounts.map(\.email) }
        return selected.map { [$0] } ?? []
    }

    func select(account email: String) {
        guard selected != email else { return }
        selected = email
        UserDefaults.standard.set(email, forKey: Self.selectedKey)
        if mailbox == .allInboxes { mailbox = .inbox }
        reloadAll()
    }

    func select(mailbox box: Mailbox) {
        mailbox = box
        UserDefaults.standard.set(box.rawValue, forKey: Self.mailboxKey)
        reloadAll()
    }

    func search(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed != query else { return }
        query = trimmed
        reloadAll()
    }

    func reloadAll() {
        Task { await load(all, reset: true) }
        Task { await load(starred, reset: true) }
        Task { await refreshUnread() }
    }

    func token(_ email: String) async throws -> String {
        if let cached = access[email], cached.expiry > Date().addingTimeInterval(60) { return cached.token }
        guard let account = accountInfo(email) else { throw GmailError.unauthorized }
        let id = GmailAuth.clientID
        guard !id.isEmpty else { throw GmailError.missingClient }
        let tokens = try await GmailAuth.refresh(account.refreshToken, id: id)
        access[email] = (tokens.accessToken, Date().addingTimeInterval(Double(tokens.expiresIn)))
        return tokens.accessToken
    }

    func call(_ email: String, _ path: String, query: [URLQueryItem] = [], method: String = "GET", json: [String: Any]? = nil, root: String = GmailAPI.base, body: Data? = nil, contentType: String? = nil) async throws -> Data {
        do {
            return try await GmailAPI.request(try await token(email), path, query: query, method: method, json: json, root: root, body: body, contentType: contentType)
        } catch GmailError.unauthorized {
            access[email] = nil
            return try await GmailAPI.request(try await token(email), path, query: query, method: method, json: json, root: root, body: body, contentType: contentType)
        }
    }

    func signIn(_ authenticate: (URL, String) async throws -> URL) async {
        let id = GmailAuth.clientID
        guard !id.isEmpty else {
            authError = GmailError.missingClient.localizedDescription
            return
        }
        signingIn = true
        authError = nil
        defer { signingIn = false }
        do {
            let verifier = GmailAuth.verifier()
            let callback = try await authenticate(GmailAuth.authURL(id, challenge: GmailAuth.challenge(verifier)), GmailAuth.scheme(id))
            guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw GmailError.invalid
            }
            let tokens = try await GmailAuth.exchange(code: code, verifier: verifier, id: id)
            let profile = try await GmailAuth.profile(tokens.accessToken)
            let existing = accountInfo(profile.email)
            guard let refresh = tokens.refreshToken ?? existing?.refreshToken else { throw GmailError.invalid }
            let account = GmailAccount(email: profile.email, name: profile.name, picture: profile.picture, refreshToken: refresh)
            if let index = accounts.firstIndex(where: { $0.email == account.email }) {
                accounts[index] = account
            } else {
                accounts.append(account)
            }
            access[account.email] = (tokens.accessToken, Date().addingTimeInterval(Double(tokens.expiresIn)))
            GmailKeychain.save(accounts)
            selected = account.email
            UserDefaults.standard.set(account.email, forKey: Self.selectedKey)
            Haptics.play(.success)
            reloadAll()
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 { return }
            authError = error.localizedDescription
        }
    }

    func signOut(_ email: String) {
        accounts.removeAll { $0.email == email }
        access[email] = nil
        unread[email] = nil
        GmailKeychain.save(accounts)
        if selected == email {
            selected = accounts.first?.email
            UserDefaults.standard.set(selected, forKey: Self.selectedKey)
        }
        reloadAll()
    }

    func refreshUnread() async {
        for email in accounts.map(\.email) {
            if let data = try? await call(email, "labels/INBOX"), let json = try? GmailAPI.object(data) {
                unread[email] = json["messagesUnread"] as? Int ?? 0
            }
        }
    }

    func load(_ feed: MailFeed, reset: Bool) async {
        let starredFeed = feed === starred
        if reset {
            feed.generation += 1
            feed.tokens = [:]
            feed.exhausted = false
            feed.error = nil
        } else if feed.loading || feed.exhausted {
            return
        }
        let generation = feed.generation
        let emails = scope(feed)
        guard !emails.isEmpty else {
            feed.items = []
            feed.exhausted = true
            return
        }
        feed.loading = true
        defer { if feed.generation == generation { feed.loading = false } }
        let label = starredFeed ? "STARRED" : mailbox.label
        let spamTrash = !starredFeed && mailbox.includesSpamTrash
        var collected: [MailItem] = []
        var nextTokens = feed.tokens
        var failure: Error?
        for email in emails {
            if !reset, nextTokens[email] == nil { continue }
            var query = [URLQueryItem(name: "labelIds", value: label), URLQueryItem(name: "maxResults", value: "25")]
            if spamTrash { query.append(URLQueryItem(name: "includeSpamTrash", value: "true")) }
            if !self.query.isEmpty { query.append(URLQueryItem(name: "q", value: self.query)) }
            if let token = nextTokens[email] { query.append(URLQueryItem(name: "pageToken", value: token)) }
            do {
                let json = try GmailAPI.object(try await call(email, "messages", query: query))
                nextTokens[email] = json["nextPageToken"] as? String
                let ids = (json["messages"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
                collected += await metadata(email, ids)
            } catch {
                nextTokens[email] = nil
                failure = error
            }
        }
        guard feed.generation == generation else { return }
        feed.tokens = nextTokens.compactMapValues { $0 }
        feed.exhausted = feed.tokens.isEmpty
        let merged = (reset ? [] : feed.items) + collected
        var seen = Set<String>()
        feed.items = merged.filter { seen.insert($0.id).inserted }.sorted { $0.date > $1.date }
        if let failure, collected.isEmpty { feed.error = failure.localizedDescription }
    }

    private func metadata(_ email: String, _ ids: [String]) async -> [MailItem] {
        guard let token = try? await token(email) else { return [] }
        return await withTaskGroup(of: MailItem?.self) { group in
            for id in ids {
                group.addTask {
                    let query = [
                        URLQueryItem(name: "format", value: "metadata"),
                        URLQueryItem(name: "metadataHeaders", value: "From"),
                        URLQueryItem(name: "metadataHeaders", value: "To"),
                        URLQueryItem(name: "metadataHeaders", value: "Subject"),
                    ]
                    guard let data = try? await GmailAPI.request(token, "messages/\(id)", query: query),
                          let json = try? GmailAPI.object(data) else { return nil }
                    return GmailAPI.item(json, account: email)
                }
            }
            var result: [MailItem] = []
            for await item in group {
                if let item { result.append(item) }
            }
            return result
        }
    }

    func item(_ id: String) -> MailItem? {
        all.items.first { $0.id == id } ?? starred.items.first { $0.id == id }
    }

    private func update(_ id: String, _ body: (inout MailItem) -> Void) {
        for feed in [all, starred] {
            if let index = feed.items.firstIndex(where: { $0.id == id }) {
                body(&feed.items[index])
            }
        }
    }

    private func modify(_ item: MailItem, add: [String], remove: [String]) async -> Bool {
        let json: [String: Any] = ["addLabelIds": add, "removeLabelIds": remove]
        return (try? await call(item.account, "messages/\(item.messageID)/modify", method: "POST", json: json)) != nil
    }

    func setRead(_ item: MailItem, _ read: Bool) {
        guard item.unread == read else { return }
        update(item.id) { read ? $0.labels.remove("UNREAD") : $0.labels.insert("UNREAD") }
        unread[item.account, default: 0] += read ? -1 : 1
        Task {
            let ok = await modify(item, add: read ? [] : ["UNREAD"], remove: read ? ["UNREAD"] : [])
            if !ok {
                update(item.id) { read ? $0.labels.insert("UNREAD") : $0.labels.remove("UNREAD") }
                showToast("既読の切り替えに失敗しました")
            }
            await refreshUnread()
        }
    }

    func toggleStar(_ item: MailItem) {
        let star = !item.starred
        update(item.id) { star ? $0.labels.insert("STARRED") : $0.labels.remove("STARRED") }
        if star {
            var copy = item
            copy.labels.insert("STARRED")
            if !starred.items.contains(where: { $0.id == item.id }) {
                starred.items.append(copy)
                starred.items.sort { $0.date > $1.date }
            }
        }
        Task {
            let ok = await modify(item, add: star ? ["STARRED"] : [], remove: star ? [] : ["STARRED"])
            if !ok {
                update(item.id) { star ? $0.labels.remove("STARRED") : $0.labels.insert("STARRED") }
                showToast("スターの切り替えに失敗しました")
            }
        }
    }

    func trash(_ item: MailItem) {
        let restore = mailbox == .trash
        let positions = [all, starred].map { feed in feed.items.firstIndex { $0.id == item.id } }
        for feed in [all, starred] { feed.items.removeAll { $0.id == item.id } }
        Haptics.play(.medium)
        Task {
            let path = "messages/\(item.messageID)/\(restore ? "untrash" : "trash")"
            guard (try? await call(item.account, path, method: "POST")) != nil else {
                reinsert(item, positions)
                showToast(restore ? "元に戻せませんでした" : "削除に失敗しました")
                return
            }
            await refreshUnread()
        }
        showToast(restore ? "受信トレイに戻しました" : "ゴミ箱に移動しました", undo: true) { [weak self] in
            guard let self else { return }
            let back = "messages/\(item.messageID)/\(restore ? "trash" : "untrash")"
            if (try? await self.call(item.account, back, method: "POST")) != nil {
                self.reinsert(item, positions)
                await self.refreshUnread()
            }
        }
    }

    private func reinsert(_ item: MailItem, _ positions: [Int?]) {
        for (feed, position) in zip([all, starred], positions) {
            guard let position, !feed.items.contains(where: { $0.id == item.id }) else { continue }
            feed.items.insert(item, at: min(position, feed.items.count))
        }
    }

    func block(_ item: MailItem) async {
        let json: [String: Any] = [
            "criteria": ["from": item.fromEmail],
            "action": ["addLabelIds": ["TRASH"], "removeLabelIds": ["INBOX"]],
        ]
        do {
            _ = try await call(item.account, "settings/filters", method: "POST", json: json)
            for feed in [all, starred] { feed.items.removeAll { $0.id == item.id } }
            _ = try? await call(item.account, "messages/\(item.messageID)/trash", method: "POST")
            showToast("\(item.fromEmail) をブロックしました")
            Haptics.play(.success)
        } catch {
            showToast("ブロックに失敗しました")
        }
    }

    func content(_ item: MailItem) async throws -> MailContent {
        let data = try await call(item.account, "messages/\(item.messageID)", query: [URLQueryItem(name: "format", value: "full")])
        var content = GmailAPI.content(try GmailAPI.object(data))
        let inline = content.attachments.filter { $0.contentID != nil && $0.mimeType.hasPrefix("image/") }
        if !content.html.isEmpty, !inline.isEmpty {
            var embedded = Set<String>()
            for part in inline {
                guard let cid = part.contentID, content.html.contains("cid:\(cid)"),
                      let bytes = try? await attachment(item, part) else { continue }
                content.html = content.html.replacingOccurrences(of: "cid:\(cid)", with: "data:\(part.mimeType);base64,\(bytes.base64EncodedString())")
                embedded.insert(part.id)
            }
            content.attachments.removeAll { embedded.contains($0.id) }
        }
        return content
    }

    func attachment(_ item: MailItem, _ part: MailAttachment) async throws -> Data {
        let data = try await call(item.account, "messages/\(item.messageID)/attachments/\(part.attachmentID)")
        guard let encoded = try GmailAPI.object(data)["data"] as? String, let bytes = Data(base64URL: encoded) else { throw GmailError.invalid }
        return bytes
    }

    private func multipart(_ metadata: [String: Any], _ mime: Data) throws -> (Data, String) {
        let boundary = "pokeloot-upload-" + UUID().uuidString
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8))
        body.append(try JSONSerialization.data(withJSONObject: metadata))
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: message/rfc822\r\n\r\n".utf8))
        body.append(mime)
        body.append(Data("\r\n--\(boundary)--".utf8))
        return (body, "multipart/related; boundary=\(boundary)")
    }

    func send(_ draft: ComposeDraft) async throws {
        var metadata: [String: Any] = [:]
        if let thread = draft.threadID { metadata["threadId"] = thread }
        let (body, type) = try multipart(metadata, draft.mime(from: accountInfo(draft.account)))
        _ = try await call(draft.account, "messages/send", query: [URLQueryItem(name: "uploadType", value: "multipart")], method: "POST", root: GmailAPI.upload, body: body, contentType: type)
        showToast("送信しました")
        Haptics.play(.success)
        if mailbox == .sent { Task { await load(all, reset: true) } }
    }

    func saveDraft(_ draft: ComposeDraft) async throws {
        var message: [String: Any] = [:]
        if let thread = draft.threadID { message["threadId"] = thread }
        let (body, type) = try multipart(["message": message], draft.mime(from: accountInfo(draft.account)))
        _ = try await call(draft.account, "drafts", query: [URLQueryItem(name: "uploadType", value: "multipart")], method: "POST", root: GmailAPI.upload, body: body, contentType: type)
        showToast("下書きを保存しました")
        if mailbox == .drafts { Task { await load(all, reset: true) } }
    }

    func showToast(_ text: String, undo: Bool = false, action: (() async -> Void)? = nil) {
        toastTask?.cancel()
        undoAction = action
        toast = MailToast(text: text, undo: undo && action != nil)
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(undo ? 5 : 2.5))
            guard !Task.isCancelled else { return }
            self?.dismissToast()
        }
    }

    func dismissToast() {
        undoAction = nil
        toast = nil
    }

    func performUndo() {
        let action = undoAction
        dismissToast()
        Haptics.play(.light)
        if let action { Task { await action() } }
    }
}
