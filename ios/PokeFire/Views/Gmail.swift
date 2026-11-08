import AuthenticationServices
import PhotosUI
import QuickLook
import SwiftUI
import Translation
import UniformTypeIdentifiers
import WebKit

extension GmailStore {
    func signIn(with session: WebAuthenticationSession) async {
        await signIn { url, scheme in
            try await session.authenticate(using: url, callbackURLScheme: scheme, preferredBrowserSession: .ephemeral)
        }
    }
}

struct ComposeRequest: Identifiable {
    let id = UUID()
    var title: String
    var draft: ComposeDraft
}

private enum MailColor {
    static let palette: [UInt32] = [0xE8710A, 0x1E8E3E, 0x1A73E8, 0xD93025, 0x9334E6, 0x12A4AF, 0xF29900, 0xC5221F, 0x188038, 0x5F6368, 0xE52592, 0x4285F4]

    static func color(_ seed: String) -> Color {
        let sum = seed.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
        return Color(hex: palette[sum % palette.count])
    }
}

private struct MailAvatar: View {
    let name: String
    let email: String
    var size: CGFloat = 40

    private var initial: String {
        let source = name.trimmingCharacters(in: .whitespaces).isEmpty ? email : name
        return source.first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(MailColor.color(email)))
            .accessibilityHidden(true)
    }
}

private struct AccountAvatar: View {
    let account: GmailAccount?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let account, let picture = account.picture, let url = URL(string: picture) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    MailAvatar(name: account.name, email: account.email, size: size)
                }
            } else if let account {
                MailAvatar(name: account.name, email: account.email, size: size)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct GmailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var store = GmailStore.shared
    @State private var tab = 0
    @State private var showSidebar = false
    @State private var showSettings = false
    @State private var compose: ComposeRequest?
    @State private var path: [MailItem] = []
    @AppStorage(GmailAuth.clientKey) private var clientID = ""

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.accounts.isEmpty {
                    signInView
                } else {
                    TabView(selection: $tab) {
                        Tab("すべて", systemImage: "envelope", value: 0) {
                            list(store.all, starred: false)
                        }
                        Tab("スター", systemImage: "star", value: 1) {
                            list(store.starred, starred: true)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MailItem.self) { item in
                MailDetailView(item: item) { request in compose = request }
            }
        }
        .overlay { sidebar }
        .sheet(isPresented: $showSettings) {
            GmailSettingsSheet()
        }
        .sheet(item: $compose) { request in
            ComposeView(title: request.title, draft: request.draft)
        }
        .task {
            if !store.accounts.isEmpty, store.all.items.isEmpty { store.reloadAll() }
        }
    }

    private func newMail() -> ComposeRequest {
        ComposeRequest(title: "作成", draft: ComposeDraft(account: store.selected ?? store.accounts.first?.email ?? ""))
    }

    private func list(_ feed: MailFeed, starred: Bool) -> some View {
        MailListView(
            feed: feed,
            starred: starred,
            onSidebar: { setSidebar(true) },
            onCompose: { compose = newMail() },
            onAddAccount: { Task { await store.signIn(with: webAuth) } },
            onSettings: { showSettings = true }
        )
    }

    private func setSidebar(_ open: Bool) {
        Haptics.play(.light)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) { showSidebar = open }
    }

    @ViewBuilder
    private var sidebar: some View {
        ZStack(alignment: .leading) {
            if showSidebar {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { setSidebar(false) }
                    .transition(.opacity)
                GmailSidebar(
                    store: store,
                    close: { setSidebar(false) },
                    onSettings: {
                        setSidebar(false)
                        showSettings = true
                    },
                    onExit: { dismiss() }
                )
                .transition(.move(edge: .leading))
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { value in
                            if value.translation.width < -50 { setSidebar(false) }
                        }
                )
            }
        }
    }

    private var signInView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "envelope.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color(hex: 0xEA4335))
            Text("Gmail")
                .font(.system(size: 34, weight: .bold))
            Text(clientID.trimmingCharacters(in: .whitespaces).isEmpty
                 ? "はじめに、設定で Google Cloud の Client ID を入力してください。"
                 : "Google アカウントでログインすると、メールの閲覧・送信ができます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if clientID.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("設定を開く") { showSettings = true }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            } else {
                Button {
                    Task { await store.signIn(with: webAuth) }
                } label: {
                    if store.signingIn {
                        ProgressView()
                    } else {
                        Text("Google でログイン")
                    }
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(store.signingIn)
                Button("設定") { showSettings = true }
                    .font(.subheadline)
            }
            if let error = store.authError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            Button {
                Haptics.play(.light)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .padding(.leading, 16)
            .padding(.top, 6)
            .accessibilityLabel("戻る")
        }
    }
}

private struct MailListView: View {
    let feed: MailFeed
    let starred: Bool
    let onSidebar: () -> Void
    let onCompose: () -> Void
    let onAddAccount: () -> Void
    let onSettings: () -> Void
    @State private var store = GmailStore.shared
    @State private var text = GmailStore.shared.query
    @FocusState private var searching: Bool

    var body: some View {
        List {
            Section {
                ForEach(feed.items) { item in
                    ZStack {
                        NavigationLink(value: item) { EmptyView() }
                            .opacity(0)
                        MailRow(item: item, recipient: !starred && store.mailbox.showsRecipient)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Haptics.play(.light)
                            store.setRead(item, item.unread)
                        } label: {
                            Label(item.unread ? "既読にする" : "未読にする", systemImage: item.unread ? "envelope.open.fill" : "envelope.badge.fill")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            store.trash(item)
                        } label: {
                            if store.mailbox == .trash && !starred {
                                Label("戻す", systemImage: "arrow.uturn.backward")
                            } else {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onAppear {
                        if item.id == feed.items.last?.id {
                            Task { await store.load(feed, reset: false) }
                        }
                    }
                }
                if feed.loading, !feed.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
            } header: {
                Text(starred ? "スター付き" : store.mailbox.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await store.load(feed, reset: true)
            await store.refreshUnread()
            Haptics.play(.success)
        }
        .overlay {
            if feed.items.isEmpty {
                if feed.loading {
                    ProgressView()
                } else if let error = feed.error {
                    ContentUnavailableView("読み込めませんでした", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ContentUnavailableView(
                        starred ? "スター付きのメールはありません" : store.query.isEmpty ? "メールはありません" : "一致するメールはありません",
                        systemImage: starred ? "star" : store.query.isEmpty ? store.mailbox.symbol : "magnifyingglass"
                    )
                }
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) { searchBar }
        .overlay(alignment: .bottom) { bottomControls }
        .animation(.snappy(duration: 0.3), value: store.toast)
    }

    private var searchBar: some View {
        HStack(spacing: 2) {
            Button {
                searching = false
                onSidebar()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("サイドバーを開く")
            TextField("メールを検索", text: $text)
                .focused($searching)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { store.search(text) }
            if !text.isEmpty {
                Button {
                    text = ""
                    store.search("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索をクリア")
            }
            Menu {
                Section {
                    ForEach(store.accounts) { account in
                        Button {
                            Haptics.play(.selection)
                            store.select(account: account.email)
                        } label: {
                            if account.email == store.selected {
                                Label(account.email, systemImage: "checkmark")
                            } else {
                                Text(account.email)
                            }
                        }
                    }
                }
                Button(action: onAddAccount) {
                    Label("アカウントを追加", systemImage: "person.badge.plus")
                }
                Button(action: onSettings) {
                    Label("アカウントを管理", systemImage: "person.crop.circle")
                }
            } label: {
                AccountAvatar(account: store.account, size: 32)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("アカウントを切り替え")
        }
        .padding(.horizontal, 4)
        .frame(height: 52)
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var bottomControls: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Button {
                Haptics.play(.light)
                onCompose()
            } label: {
                Label("作成", systemImage: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .frame(height: 54)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.3)).interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let toast = store.toast {
                HStack(spacing: 12) {
                    Text(toast.text)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if toast.undo {
                        Button("元に戻す") { store.performUndo() }
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: Capsule())
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

private struct MailRow: View {
    let item: MailItem
    let recipient: Bool
    @State private var store = GmailStore.shared

    var body: some View {
        let unread = item.unread
        let who = recipient ? "宛先: \(item.toLine)" : item.fromName
        HStack(alignment: .top, spacing: 12) {
            MailAvatar(name: item.fromName, email: item.fromEmail, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(who)
                        .font(.system(size: 16, weight: unread ? .bold : .regular))
                        .lineLimit(1)
                    if store.mailbox == .allInboxes, store.accounts.count > 1 {
                        Circle()
                            .fill(MailColor.color(item.account))
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 6)
                    Text(MailText.listTime(item.date))
                        .font(.system(size: 12, weight: unread ? .bold : .regular))
                        .foregroundStyle(unread ? Color.primary : Color.secondary)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.subject.isEmpty ? "（件名なし）" : item.subject)
                            .font(.system(size: 15, weight: unread ? .semibold : .regular))
                            .lineLimit(1)
                        Text(item.snippet)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Button {
                        Haptics.play(.light)
                        store.toggleStar(item)
                    } label: {
                        Image(systemName: item.starred ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundStyle(item.starred ? Color.yellow : Color.secondary.opacity(0.6))
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.starred ? "スターを外す" : "スターを付ける")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(unread ? "未読" : "")
    }
}

private struct GmailSidebar: View {
    let store: GmailStore
    let close: () -> Void
    let onSettings: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gmail")
                    .font(.system(size: 26, weight: .bold))
                if let account = store.account {
                    Text(account.email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)
            row(.allInboxes, count: store.unread.values.reduce(0, +))
            divider
            row(.inbox, count: store.selected.flatMap { store.unread[$0] } ?? 0)
            row(.spam)
            row(.trash)
            divider
            row(.sent)
            row(.scheduled)
            row(.drafts)
            Spacer(minLength: 12)
            divider
            action("設定", symbol: "gearshape", run: onSettings)
            action("Pokéloot に戻る", symbol: "rectangle.portrait.and.arrow.right", run: onExit)
                .padding(.bottom, 8)
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(bottomTrailingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .ignoresSafeArea()
        )
    }

    private var divider: some View {
        Divider()
            .padding(.vertical, 6)
            .padding(.leading, 24)
    }

    private func row(_ box: Mailbox, count: Int = 0) -> some View {
        let active = store.mailbox == box
        return Button {
            Haptics.play(.selection)
            store.select(mailbox: box)
            close()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: active ? box.symbol + ".fill" : box.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 24)
                Text(box.title)
                    .font(.system(size: 16, weight: active ? .semibold : .regular))
                Spacer(minLength: 4)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(active ? Color.accentColor : Color.primary)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Capsule().fill(active ? Color.accentColor.opacity(0.14) : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func action(_ title: String, symbol: String, run: @escaping () -> Void) -> some View {
        Button {
            Haptics.play(.light)
            run()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16))
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

private struct MailDetailView: View {
    let item: MailItem
    let onCompose: (ComposeRequest) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var scheme
    @State private var store = GmailStore.shared
    @State private var content: MailContent?
    @State private var error: String?
    @State private var bodyHeight: CGFloat = 1
    @State private var showInfo = false
    @State private var showTranslate = false
    @State private var confirmBlock = false
    @State private var confirmUnsubscribe = false
    @State private var preview: URL?
    @State private var downloading: String?
    @State private var forwarding = false

    private var current: MailItem { store.item(item.id) ?? item }

    private var plainText: String {
        guard let content else { return item.snippet }
        let text = content.plain.isEmpty ? MailText.plain(fromHTML: content.html) : content.plain
        return String(text.prefix(6000))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                Text(current.subject.isEmpty ? "（件名なし）" : current.subject)
                    .font(.system(size: 24, weight: .bold))
                    .textSelection(.enabled)
                if let content {
                    MailBodyView(html: page(content), height: $bodyHeight)
                        .frame(height: max(1, bodyHeight))
                        .padding(scheme == .dark ? 12 : 0)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(scheme == .dark ? Color.white : Color.clear)
                        )
                    if !content.attachments.isEmpty {
                        attachments(content.attachments)
                    }
                    HStack(spacing: 10) {
                        Button {
                            Haptics.play(.light)
                            onCompose(reply())
                        } label: {
                            Label("返信", systemImage: "arrowshape.turn.up.left")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            forward()
                        } label: {
                            Label("転送", systemImage: "arrowshape.turn.up.right")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(forwarding)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .padding(.top, 6)
                } else if let error {
                    ContentUnavailableView("読み込めませんでした", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        onCompose(reply())
                    } label: {
                        Label("返信", systemImage: "arrowshape.turn.up.left")
                    }
                    Button {
                        forward()
                    } label: {
                        Label("転送", systemImage: "arrowshape.turn.up.right")
                    }
                    Button {
                        showTranslate = true
                    } label: {
                        Label("翻訳", systemImage: "translate")
                    }
                    .disabled(content == nil)
                    Divider()
                    Button(role: .destructive) {
                        store.trash(current)
                        dismiss()
                    } label: {
                        Label(store.mailbox == .trash ? "受信トレイに戻す" : "削除", systemImage: store.mailbox == .trash ? "arrow.uturn.backward" : "trash")
                    }
                    Button(role: .destructive) {
                        confirmBlock = true
                    } label: {
                        Label("\(current.fromName)をブロック", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("その他の操作")
            }
        }
        .task {
            await load()
        }
        .sheet(isPresented: $showInfo) {
            MailInfoSheet(item: current, content: content)
        }
        .translationPresentation(isPresented: $showTranslate, text: plainText)
        .confirmationDialog("\(current.fromEmail) をブロックしますか？", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("ブロック", role: .destructive) {
                Task {
                    await store.block(current)
                    dismiss()
                }
            }
        } message: {
            Text("今後このアドレスから届くメールは、自動でゴミ箱に移動します。")
        }
        .confirmationDialog("登録解除しますか？", isPresented: $confirmUnsubscribe, titleVisibility: .visible) {
            Button("登録解除") { unsubscribe() }
        } message: {
            Text("送信者が用意した登録解除のページまたは宛先を開きます。")
        }
        .quickLookPreview($preview)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            MailAvatar(name: current.fromName, email: current.fromEmail, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(current.fromName)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Button {
                    Haptics.play(.light)
                    showInfo = true
                } label: {
                    HStack(spacing: 3) {
                        Text("From: \(current.fromEmail)")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("詳細を表示します")
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                if content?.unsubscribe != nil {
                    Button("登録解除") { confirmUnsubscribe = true }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.mini)
                }
                Text(MailText.fullTime(current.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func attachments(_ list: [MailAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("添付ファイル \(list.count)件")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(list) { part in
                Button {
                    open(part)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon(part.mimeType))
                            .font(.system(size: 20))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(part.filename)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(part.size), countStyle: .file))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if downloading == part.id {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func icon(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("video/") { return "film" }
        if mime.hasPrefix("audio/") { return "waveform" }
        if mime.contains("pdf") { return "doc.richtext" }
        if mime.contains("zip") { return "doc.zipper" }
        return "doc"
    }

    private func load() async {
        if current.unread { store.setRead(current, true) }
        guard content == nil else { return }
        do {
            content = try await store.content(current)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func open(_ part: MailAttachment) {
        guard downloading == nil else { return }
        downloading = part.id
        Task {
            defer { downloading = nil }
            do {
                let data = try await store.attachment(current, part)
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent(part.filename.replacingOccurrences(of: "/", with: "_"))
                try data.write(to: url)
                preview = url
            } catch {
                store.showToast("添付ファイルを開けませんでした")
            }
        }
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func linkify(_ text: String) -> String {
        text.replacingOccurrences(of: "(https?://[^\\s<>\"]+)", with: "<a href='$1'>$1</a>", options: .regularExpression)
    }

    private func page(_ content: MailContent) -> String {
        let inner = content.html.isEmpty ? "<div class='plain'>\(linkify(escape(content.plain)))</div>" : content.html
        return """
        <!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1, user-scalable=no'>
        <style>html,body{margin:0;padding:0;background:#ffffff;color:#1c1c1e;font-family:-apple-system,sans-serif;font-size:16px;line-height:1.55;-webkit-text-size-adjust:100%;overflow-wrap:anywhere}img{max-width:100%;height:auto}.plain{white-space:pre-wrap;padding:2px 0}a{color:#0b57d0}blockquote{margin-left:8px;padding-left:10px;border-left:3px solid #d0d7de}</style>
        </head><body>\(inner)
        <script>(function(){function fit(){var w=document.documentElement.clientWidth;var s=document.documentElement.scrollWidth;if(s>w+1){var m=document.querySelector('meta[name=viewport]');if(m){m.setAttribute('content','width='+s+', user-scalable=no');}}}function report(){fit();window.webkit.messageHandlers.height.postMessage({h:document.body.scrollHeight,w:document.documentElement.clientWidth});}report();window.addEventListener('load',report);Array.prototype.forEach.call(document.images,function(i){i.addEventListener('load',report);});if(window.ResizeObserver){new ResizeObserver(report).observe(document.body);}})();</script>
        </body></html>
        """
    }

    private func quote() -> String {
        let lines = plainText.components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
        return "\n\n\(MailText.fullTime(current.date)) \(current.fromName) <\(current.fromEmail)>:\n\(lines)"
    }

    private func reply() -> ComposeRequest {
        var draft = ComposeDraft(account: current.account)
        let target = content?.header("Reply-To") ?? content?.header("From") ?? current.fromEmail
        draft.to = MailText.address(target).email
        let subject = current.subject
        draft.subject = subject.lowercased().hasPrefix("re:") ? subject : "Re: " + subject
        draft.threadID = current.threadID
        let messageID = content?.header("Message-ID")
        draft.inReplyTo = messageID
        let references = [content?.header("References"), messageID].compactMap { $0 }.joined(separator: " ")
        draft.references = references.isEmpty ? nil : references
        draft.body = quote()
        return ComposeRequest(title: "返信", draft: draft)
    }

    private func forward() {
        guard !forwarding else { return }
        Haptics.play(.light)
        var draft = ComposeDraft(account: current.account)
        let subject = current.subject
        draft.subject = subject.lowercased().hasPrefix("fwd:") ? subject : "Fwd: " + subject
        draft.body = "\n\n---------- 転送メッセージ ----------\nFrom: \(current.fromName) <\(current.fromEmail)>\nDate: \(MailText.fullTime(current.date))\nSubject: \(subject)\nTo: \(content?.header("To") ?? "")\n\n\(plainText)"
        let parts = content?.attachments ?? []
        guard !parts.isEmpty else {
            onCompose(ComposeRequest(title: "転送", draft: draft))
            return
        }
        forwarding = true
        Task {
            for part in parts {
                if let data = try? await store.attachment(current, part) {
                    draft.attachments.append(ComposeAttachment(name: part.filename, mimeType: part.mimeType.isEmpty ? "application/octet-stream" : part.mimeType, data: data))
                }
            }
            forwarding = false
            onCompose(ComposeRequest(title: "転送", draft: draft))
        }
    }

    private func unsubscribe() {
        guard let url = content?.unsubscribe else { return }
        if url.scheme == "mailto" {
            var draft = ComposeDraft(account: current.account)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            draft.to = components?.path ?? ""
            draft.subject = components?.queryItems?.first { $0.name.lowercased() == "subject" }?.value ?? "unsubscribe"
            draft.body = components?.queryItems?.first { $0.name.lowercased() == "body" }?.value ?? ""
            onCompose(ComposeRequest(title: "登録解除", draft: draft))
        } else {
            openURL(url)
        }
    }
}

@MainActor
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

private struct MailBodyView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = [.link, .phoneNumber]
        configuration.userContentController.add(WeakScriptHandler(context.coordinator), name: "height")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.isOpaque = false
        view.backgroundColor = .clear
        view.overrideUserInterfaceStyle = .light
        context.coordinator.webView = view
        context.coordinator.loaded = html
        view.loadHTMLString(html, baseURL: nil)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loaded != html {
            context.coordinator.loaded = html
            view.loadHTMLString(html, baseURL: nil)
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MailBodyView
        var loaded = ""
        weak var webView: WKWebView?

        init(_ parent: MailBodyView) {
            self.parent = parent
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let h = (body["h"] as? NSNumber)?.doubleValue,
                  let w = (body["w"] as? NSNumber)?.doubleValue, w > 0,
                  let view = webView else { return }
            let scale = view.bounds.width > 0 ? view.bounds.width / w : 1
            let next = ceil(h * scale)
            if abs(parent.height - next) > 1 {
                DispatchQueue.main.async { self.parent.height = next }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}

private struct MailInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: MailItem
    let content: MailContent?

    var body: some View {
        NavigationStack {
            List {
                row("差出人", content?.header("From") ?? "\(item.fromName) <\(item.fromEmail)>")
                if let replyTo = content?.header("Reply-To") {
                    row("返信先", replyTo)
                }
                row("宛先", content?.header("To") ?? item.toLine)
                if let cc = content?.header("Cc") {
                    row("Cc", cc)
                }
                row("日付", MailText.fullTime(item.date))
                row("件名", item.subject.isEmpty ? "（件名なし）" : item.subject)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: content?.encrypted == true ? "lock.fill" : "lock.open")
                        .foregroundStyle(content?.encrypted == true ? Color.green : Color.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("セキュリティ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(content?.encrypted == true ? "標準の暗号化（TLS）" : "暗号化の情報はありません")
                    }
                }
            }
            .navigationTitle("詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State private var draft: ComposeDraft
    @State private var store = GmailStore.shared
    @State private var showCc: Bool
    @State private var sending = false
    @State private var error: String?
    @State private var confirmClose = false
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var photos: [PhotosPickerItem] = []
    @FocusState private var focus: Field?
    private let original: ComposeDraft

    private enum Field { case to, cc, subject, body }

    init(title: String, draft: ComposeDraft) {
        self.title = title
        _draft = State(initialValue: draft)
        _showCc = State(initialValue: !draft.cc.isEmpty)
        original = draft
    }

    private var totalSize: Int { draft.attachments.reduce(0) { $0 + $1.data.count } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    line("差出人") {
                        if store.accounts.count > 1 {
                            Menu {
                                ForEach(store.accounts) { account in
                                    Button(account.email) { draft.account = account.email }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(draft.account)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.primary)
                            }
                        } else {
                            Text(draft.account)
                                .lineLimit(1)
                        }
                    }
                    Divider()
                    line("宛先") {
                        TextField("", text: $draft.to)
                            .focused($focus, equals: .to)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !showCc {
                            Button {
                                withAnimation(.snappy) { showCc = true }
                                focus = .cc
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cc を追加")
                        }
                    }
                    if showCc {
                        Divider()
                        line("Cc") {
                            TextField("", text: $draft.cc)
                                .focused($focus, equals: .cc)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    Divider()
                    TextField("件名", text: $draft.subject)
                        .focused($focus, equals: .subject)
                        .font(.system(size: 17, weight: .semibold))
                        .padding(.vertical, 14)
                    Divider()
                    if !draft.attachments.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(draft.attachments) { file in
                                    HStack(spacing: 6) {
                                        Image(systemName: file.mimeType.hasPrefix("image/") ? "photo" : "doc")
                                            .foregroundStyle(Color.accentColor)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(file.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .lineLimit(1)
                                            Text(ByteCountFormatter.string(fromByteCount: Int64(file.data.count), countStyle: .file))
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: 150, alignment: .leading)
                                        Button {
                                            withAnimation(.snappy) { draft.attachments.removeAll { $0.id == file.id } }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(file.name) を外す")
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .scrollIndicators(.hidden)
                        Divider()
                    }
                    TextField("本文", text: $draft.body, axis: .vertical)
                        .focused($focus, equals: .body)
                        .lineLimit(14, reservesSpace: true)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if draft == original || draft.isEmpty {
                            dismiss()
                        } else {
                            confirmClose = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showPhotos = true
                        } label: {
                            Label("写真を添付", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showFiles = true
                        } label: {
                            Label("ファイルを添付", systemImage: "doc")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .accessibilityLabel("添付")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        send()
                    } label: {
                        if sending {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(sending || draft.to.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("送信")
                }
            }
            .confirmationDialog("下書きを保存しますか？", isPresented: $confirmClose, titleVisibility: .visible) {
                Button("下書きを保存") {
                    Task {
                        try? await store.saveDraft(draft)
                        dismiss()
                    }
                }
                Button("破棄", role: .destructive) { dismiss() }
            }
            .alert("送信できませんでした", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
            .photosPicker(isPresented: $showPhotos, selection: $photos, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
            .onChange(of: photos) { _, items in
                guard !items.isEmpty else { return }
                Task { await addPhotos(items) }
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else { continue }
                    let type = UTType(filenameExtension: url.pathExtension)
                    draft.attachments.append(ComposeAttachment(name: url.lastPathComponent, mimeType: type?.preferredMIMEType ?? "application/octet-stream", data: data))
                }
            }
            .onAppear {
                if draft.to.isEmpty {
                    focus = .to
                } else if draft.body.hasPrefix("\n") {
                    focus = .body
                }
            }
        }
        .interactiveDismissDisabled(!(draft == original || draft.isEmpty))
    }

    private func line<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .frame(minHeight: 48)
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        for (offset, item) in items.enumerated() {
            guard var data = try? await item.loadTransferable(type: Data.self) else { continue }
            var type = item.supportedContentTypes.first ?? .jpeg
            if type.conforms(to: .heic) || type.conforms(to: .heif), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) {
                data = jpeg
                type = .jpeg
            }
            let ext = type.preferredFilenameExtension ?? "jpg"
            draft.attachments.append(ComposeAttachment(
                name: "photo-\(draft.attachments.count + offset + 1).\(ext)",
                mimeType: type.preferredMIMEType ?? "application/octet-stream",
                data: data
            ))
        }
        photos = []
    }

    private func send() {
        guard totalSize <= 24 * 1024 * 1024 else {
            error = "添付ファイルの合計が大きすぎます（25MBまで）。"
            return
        }
        sending = true
        Task {
            do {
                try await store.send(draft)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            sending = false
        }
    }
}

struct GmailSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var store = GmailStore.shared
    @AppStorage(GmailAuth.clientKey) private var clientID = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(store.accounts) { account in
                        HStack(spacing: 12) {
                            AccountAvatar(account: account, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(account.name)
                                    .font(.body.weight(.medium))
                                Text(account.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if account.email == store.selected {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.select(account: account.email) }
                    }
                    .onDelete { offsets in
                        for email in offsets.map({ store.accounts[$0].email }) { store.signOut(email) }
                    }
                    Button {
                        Task { await store.signIn(with: webAuth) }
                    } label: {
                        if store.signingIn {
                            ProgressView()
                        } else {
                            Label("アカウントを追加", systemImage: "person.badge.plus")
                        }
                    }
                    .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty || store.signingIn)
                    if let error = store.authError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("アカウント")
                } footer: {
                    Text("左にスワイプでログアウトできます。")
                }
                Section {
                    TextField("xxxx.apps.googleusercontent.com", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())
                } header: {
                    Text("Google Cloud の Client ID")
                } footer: {
                    Text("種類が「iOS」の OAuth クライアント ID を入力します。")
                }
                Section("設定手順") {
                    step(1, "Google Cloud Console で新しいプロジェクトを作成します。")
                    step(2, "「API とサービス」→「ライブラリ」で Gmail API を有効にします。")
                    step(3, "「OAuth 同意画面」（Google Auth Platform）を作成します。対象は「外部」にし、使う Gmail アドレスをテストユーザーに追加します。")
                    step(4, "「クライアント」→「クライアントを作成」で種類「iOS」を選び、バンドル ID に me.ffui.pokefire を入力します。")
                    step(5, "作成された Client ID を上の欄に貼り付け、アカウントを追加します。")
                    Text("同意画面が「テスト中」のままだと、7日ごとにログインし直す必要があります。「本番環境」に公開すると不要になります（ログイン時に「Google で確認されていません」と出るので、「詳細」から続行してください）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link(destination: GmailAuth.consoleURL) {
                        Label("Google Cloud Console を開く", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .navigationTitle("Gmail の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
        }
    }
}
