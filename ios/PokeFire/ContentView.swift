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
        .overlay(alignment: .top) {
            TopBar(store: store)
                .padding(.horizontal, 12)
                .padding(.top, 4)
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.light)
        .sheet(item: $store.shareItem) { item in
            ActivityView(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showEnvironment) {
            EnvironmentSheet(store: store)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.selection, trigger: store.result.judge)
        .onOpenURL { url in
            store.open(url)
        }
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

struct IconImage: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct GlassCircleButton: View {
    let icon: String
    var size: CGFloat = 20
    var haptic = "light"
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.play(haptic)
            action()
        } label: {
            IconImage(name: icon, size: size)
                .foregroundStyle(Color(red: 0.33, green: 0.36, blue: 0.5))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
    }
}

enum EnvironmentStyle {
    static let weathers: [(key: String, label: String)] = [("none", "なし"), ("sun", "にほんばれ"), ("rain", "あめ"), ("sand", "すなあらし"), ("snow", "ゆき")]
    static let fields: [(key: String, label: String)] = [("none", "なし"), ("electric", "エレキ"), ("grass", "グラス"), ("psycho", "サイコ"), ("mist", "ミスト")]

    static func label(_ kind: String, _ key: String) -> String {
        if key == "none" { return kind == "weather" ? "天候" : "フィールド" }
        let list = kind == "weather" ? weathers : fields
        return list.first(where: { $0.key == key })?.label ?? key
    }

    static func tint(_ key: String) -> Color {
        switch key {
        case "sun": return Color(red: 0.95, green: 0.55, blue: 0.2)
        case "rain": return Color(red: 0.25, green: 0.5, blue: 0.9)
        case "sand": return Color(red: 0.72, green: 0.58, blue: 0.36)
        case "snow": return Color(red: 0.35, green: 0.72, blue: 0.85)
        case "electric": return Color(red: 0.92, green: 0.72, blue: 0.1)
        case "grass": return Color(red: 0.3, green: 0.68, blue: 0.35)
        case "psycho": return Color(red: 0.88, green: 0.36, blue: 0.62)
        case "mist": return Color(red: 0.62, green: 0.5, blue: 0.85)
        default: return Color(red: 0.33, green: 0.36, blue: 0.66)
        }
    }
}

struct TopBar: View {
    @ObservedObject var store: WebStore

    var body: some View {
        HStack(spacing: 8) {
            if store.onMainPage {
                GlassCircleButton(icon: "history") {
                    store.openHistory()
                }
                Spacer(minLength: 4)
                EnvironmentPill(store: store)
                Spacer(minLength: 4)
                GlassCircleButton(icon: "help") {
                    store.openHelp()
                }
            } else {
                Spacer()
                GlassCircleButton(icon: "close", size: 26) {
                    store.goHome()
                }
            }
        }
        .opacity(store.onMainPage && (store.covered || !store.ready) ? 0 : 1)
        .allowsHitTesting(!(store.onMainPage && (store.covered || !store.ready)))
        .animation(.easeInOut(duration: 0.2), value: store.covered)
    }
}

struct EnvironmentPill: View {
    @ObservedObject var store: WebStore

    var body: some View {
        let environment = store.environment
        Button {
            Haptics.play("light")
            store.showEnvironment = true
        } label: {
            HStack(spacing: 6) {
                IconImage(name: "weather_\(environment.weather)", size: 16)
                    .foregroundStyle(EnvironmentStyle.tint(environment.weather))
                Text(EnvironmentStyle.label("weather", environment.weather))
                Text("・")
                    .foregroundStyle(.secondary)
                IconImage(name: "field_\(environment.field)", size: 16)
                    .foregroundStyle(EnvironmentStyle.tint(environment.field))
                Text(EnvironmentStyle.label("field", environment.field))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(red: 0.25, green: 0.27, blue: 0.35))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .animation(.snappy, value: environment)
    }
}

struct EnvironmentSheet: View {
    @ObservedObject var store: WebStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            row(title: "天候", kind: "weather", items: EnvironmentStyle.weathers, selected: store.environment.weather)
            row(title: "フィールド", kind: "field", items: EnvironmentStyle.fields, selected: store.environment.field)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(title: String, kind: String, items: [(key: String, label: String)], selected: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.key) { item in
                        let active = item.key == selected
                        Button {
                            Haptics.play("selection")
                            store.setEnvironment(kind, item.key)
                        } label: {
                            VStack(spacing: 6) {
                                IconImage(name: "\(kind)_\(item.key)", size: 24)
                                Text(item.label)
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(active ? Color.white : EnvironmentStyle.tint(item.key))
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(active ? .regular.tint(EnvironmentStyle.tint(item.key)).interactive() : .regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
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
                    Button {
                        Haptics.play("medium")
                        store.command("add('attack')")
                    } label: {
                        Label { Text("ポケモンの攻撃") } icon: { Image("tab_attack") }
                    }
                    Button {
                        Haptics.play("medium")
                        store.command("add('damage')")
                    } label: {
                        Label { Text("定数ダメージ") } icon: { Image("tab_damage") }
                    }
                    Button {
                        Haptics.play("medium")
                        store.command("add('heel')")
                    } label: {
                        Label { Text("定数回復") } icon: { Image("tab_heel") }
                    }
                } label: {
                    IconImage(name: "add", size: 18)
                        .foregroundStyle(Color(red: 0.25, green: 0.27, blue: 0.35))
                        .frame(width: 42, height: 42)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }
        }
    }
}

enum TabStyle {
    static func icon(_ kind: String) -> String {
        switch kind {
        case "damage": return "tab_damage"
        case "heel": return "tab_heel"
        default: return "tab_attack"
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
        Menu {
            Button {
                Haptics.play("light")
                store.command("move(\(position), -1)")
            } label: {
                Label { Text("左へ移動") } icon: { Image("move_left") }
            }
            .disabled(position == 0)
            Button {
                Haptics.play("light")
                store.command("move(\(position), 1)")
            } label: {
                Label { Text("右へ移動") } icon: { Image("move_right") }
            }
            .disabled(position >= store.tabs.count - 1)
            Divider()
            Button(role: .destructive) {
                Haptics.play("medium")
                store.command("remove(\(position))")
            } label: {
                Label { Text("削除") } icon: { Image("close") }
            }
            .disabled(store.tabs.count <= 1)
        } label: {
            HStack(spacing: 5) {
                Text("\(tab.index)")
                    .font(.system(size: 12, weight: .heavy))
                    .monospacedDigit()
                IconImage(name: TabStyle.icon(tab.kind), size: 14)
                Text(tab.label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(active ? Color.white : Color(red: 0.25, green: 0.27, blue: 0.35))
            .padding(.horizontal, 12)
            .frame(height: 34)
        } primaryAction: {
            guard !active else { return }
            Haptics.play("light")
            store.command("activate(\(position))")
        }
        .glassEffect(active ? .regular.tint(TabStyle.tint(tab.kind)).interactive() : .regular.interactive(), in: Capsule())
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
                    .contentTransition(.numericText())
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
                    IconImage(name: "speed", size: 19)
                        .foregroundStyle(Color(red: 0.22, green: 0.4, blue: 0.65))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())

                Spacer(minLength: 8)

                Text(result.judge)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(red: 0.22, green: 0.4, blue: 0.65))
                    .contentTransition(.numericText())
                if !result.rate.isEmpty {
                    Text(result.rate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
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
