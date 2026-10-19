import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var store = WebStore()

    private var barsHidden: Bool {
        store.covered || !store.onMainPage || !store.ready
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.941, green: 0.941, blue: 0.941)
                .ignoresSafeArea()

            WebView(webView: store.webView)
                .ignoresSafeArea(.container, edges: .bottom)

            VStack(spacing: 10) {
                TabStrip(store: store)
                ResultCard(store: store)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .opacity(barsHidden ? 0 : 1)
            .offset(y: barsHidden ? 48 : 0)
            .allowsHitTesting(!barsHidden)
            .animation(.spring(duration: 0.35), value: barsHidden)
        }
        .overlay(alignment: .topTrailing) {
            TopMenu(store: store)
                .padding(.trailing, 12)
                .padding(.top, 4)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $store.shareItem) { item in
            ActivityView(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .sensoryFeedback(.selection, trigger: store.result.judge)
    }
}

struct WebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TopMenu: View {
    @ObservedObject var store: WebStore

    var body: some View {
        Group {
            if store.onMainPage {
                Menu {
                    Button("共有", systemImage: "square.and.arrow.up") {
                        store.command("share()")
                    }
                    Button("すばやさ比較", systemImage: "figure.run") {
                        store.command("openSpeed()")
                    }
                    Button("ヘルプ", systemImage: "questionmark.circle") {
                        store.openHelp()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .opacity(store.covered ? 0 : 1)
                .allowsHitTesting(!store.covered)
            } else {
                Button {
                    Haptics.play("light")
                    store.goHome()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.covered)
    }
}

struct TabStrip: View {
    @ObservedObject var store: WebStore

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(store.tabs) { tab in
                                TabChip(store: store, tab: tab, active: tab.index - 1 == store.active)
                                    .id(tab.id)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                    .onChange(of: store.active) { _, value in
                        guard store.tabs.indices.contains(value) else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(store.tabs[value].id, anchor: .center)
                        }
                    }
                }

                Menu {
                    Button("ポケモンの攻撃", systemImage: TabStyle.symbol("attack")) {
                        Haptics.play("medium")
                        store.command("add('attack')")
                    }
                    Button("定数ダメージ", systemImage: TabStyle.symbol("damage")) {
                        Haptics.play("medium")
                        store.command("add('damage')")
                    }
                    Button("定数回復", systemImage: TabStyle.symbol("heel")) {
                        Haptics.play("medium")
                        store.command("add('heel')")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
    }
}

enum TabStyle {
    static func symbol(_ kind: String) -> String {
        switch kind {
        case "damage": return "heart.slash.fill"
        case "heel": return "heart.fill"
        default: return "bolt.fill"
        }
    }

    static func tint(_ kind: String) -> Color {
        switch kind {
        case "damage": return Color(red: 0.42, green: 0.31, blue: 0.77)
        case "heel": return Color(red: 0.2, green: 0.66, blue: 0.42)
        default: return Color(red: 0.84, green: 0.33, blue: 0.4)
        }
    }
}

struct TabChip: View {
    @ObservedObject var store: WebStore
    let tab: NativeTab
    let active: Bool

    var body: some View {
        let position = tab.index - 1
        Button {
            guard !active else { return }
            Haptics.play("light")
            store.command("activate(\(position))")
        } label: {
            HStack(spacing: 5) {
                Text("\(tab.index)")
                    .font(.system(size: 12, weight: .heavy))
                    .monospacedDigit()
                Image(systemName: TabStyle.symbol(tab.kind))
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(active ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint(TabStyle.tint(tab.kind)).interactive() : .regular.interactive(), in: Capsule())
        .contextMenu {
            Button("左へ移動", systemImage: "arrow.left") {
                Haptics.play("light")
                store.command("move(\(position), -1)")
            }
            .disabled(position == 0)
            Button("右へ移動", systemImage: "arrow.right") {
                Haptics.play("light")
                store.command("move(\(position), 1)")
            }
            .disabled(position >= store.tabs.count - 1)
            Divider()
            Button("削除", systemImage: "trash", role: .destructive) {
                Haptics.play("medium")
                store.command("remove(\(position))")
            }
            .disabled(store.tabs.count <= 1)
        }
    }
}

struct ResultCard: View {
    @ObservedObject var store: WebStore

    var body: some View {
        let result = store.result
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(result.percent)
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                Text(result.damage)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                Text("/ \(result.hp)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HPBar(sure: result.sure, maybe: result.maybe)

            HStack(spacing: 8) {
                Button {
                    Haptics.play("light")
                    store.command("openSpeed()")
                } label: {
                    Image(systemName: "figure.run")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())

                Spacer(minLength: 8)

                Text(result.judge)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.22, green: 0.4, blue: 0.65))
                if !result.rate.isEmpty {
                    Text(result.rate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(16)
        .contentShape(RoundedRectangle(cornerRadius: 28))
        .onTapGesture {
            Haptics.play("light")
            store.command("openDetail()")
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 28))
        .animation(.snappy, value: result)
    }
}

struct HPBar: View {
    let sure: NativeBar
    let maybe: NativeBar

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(Color(css: maybe.color).opacity(0.4))
                    .frame(width: geometry.size.width * min(1, max(0, maybe.width)))
                Capsule()
                    .fill(Color(css: sure.color))
                    .frame(width: geometry.size.width * min(1, max(0, sure.width)))
            }
        }
        .frame(height: 8)
    }
}
