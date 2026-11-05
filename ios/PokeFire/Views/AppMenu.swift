import SwiftUI
import UIKit

enum AppSettings {
    static let autoSleepKey = "pokefire-auto-sleep"
    static let portraitTeamKey = "pokefire-team-portrait"
    static let appearanceKey = "pokefire-appearance"

    static func applyAppearance(_ value: String) {
        let style: UIUserInterfaceStyle
        switch value {
        case "light": style = .light
        case "dark": style = .dark
        default: style = .unspecified
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    static func scheme(_ value: String) -> ColorScheme? {
        switch value {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    static func applyAutoSleep(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !on
    }
}

struct AppMenuButton: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    var openHistory: (() -> Void)?
    var inToolbar = false
    @State private var showSettings = false

    private func go(_ mode: AppMode) {
        guard mode != stats.mode else { return }
        Haptics.play(.medium)
        withAnimation(.easeInOut(duration: 0.35)) {
            switch mode {
            case .fire: stats.exit()
            case .stats: stats.enter(from: model)
            case .box: stats.openBox()
            case .data: stats.openData()
            }
        }
    }

    var body: some View {
        Menu {
            if let openHistory, stats.mode != .box {
                Button(action: openHistory) {
                    Label {
                        Text(stats.isStats ? "ステータス履歴" : "ダメ計履歴")
                    } icon: {
                        Image("history")
                    }
                }
            }
            Section {
                Button { go(.fire) } label: {
                    Label {
                        Text("PokéFire")
                    } icon: {
                        fixedIcon("tab_attack", size: 18)
                    }
                }
                .disabled(stats.mode == .fire)
                Button { go(.stats) } label: {
                    Label {
                        Text("PokéStats")
                    } icon: {
                        menuSymbol("chart.pie")
                    }
                }
                .disabled(stats.mode == .stats)
                Button { go(.box) } label: {
                    Label {
                        Text("PokéBox")
                    } icon: {
                        menuSymbol("cube.box")
                    }
                }
                .disabled(stats.mode == .box)
            }
            Button {
                showSettings = true
            } label: {
                Label {
                    Text("設定")
                } icon: {
                    menuSymbol("gearshape")
                }
            }
        } label: {
            if inToolbar {
                fixedIcon("menu", size: 20)
                    .foregroundStyle(Palette.ink)
            } else {
                Icon(name: "menu", size: 20)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .accessibilityLabel("メニュー")
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.autoSleepKey) private var autoSleep = true
    @AppStorage(AppSettings.portraitTeamKey) private var portraitTeam = false
    @AppStorage(AppSettings.appearanceKey) private var appearance = "system"
    @State private var showThe1900 = false

    var body: some View {
        NavigationStack {
            Form {
                Section("外観") {
                    Picker("外観", selection: $appearance) {
                        Text("システム").tag("system")
                        Text("ライト").tag("light")
                        Text("ダーク").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("自動スリープ", isOn: $autoSleep)
                } footer: {
                    Text("オフにすると、アプリを開いている間は画面が消えなくなります。")
                }
                Section {
                    Toggle("チームの画像を縦長にする", isOn: $portraitTeam)
                } footer: {
                    Text("オンにすると、チームのサムネイルが横2×縦3の並びになります。")
                }
                Section("免責事項") {
                    Text("Pokéloot は個人が作成した非公式のツールで、任天堂・クリーチャーズ・ゲームフリーク・株式会社ポケモンとは関係ありません。")
                    Text("ポケモンの名前・画像などの著作権は各権利者に帰属します。")
                    Text("計算結果や使用率などのデータの正確さは保証できません。ご利用は自己責任でお願いします。")
                }
                .font(.footnote)
                .foregroundStyle(Palette.secondary)
                Section("My Own Tools") {
                    Button {
                        Haptics.play(.light)
                        showThe1900 = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "character.book.closed")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(T1900Color.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("THE 1900")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("英単語ターゲット1900のテストと単語カード")
                                    .font(.caption)
                                    .foregroundStyle(Palette.secondary)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.secondary.opacity(0.6))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .onChange(of: autoSleep) { _, value in
            AppSettings.applyAutoSleep(value)
        }
        .onChange(of: appearance) { _, value in
            AppSettings.applyAppearance(value)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showThe1900) {
            The1900View()
        }
    }
}

func fixedIcon(_ name: String, size: CGFloat) -> Image {
    guard let base = UIImage(named: name) else { return Image(name) }
    let rendered = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
        base.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return Image(uiImage: rendered.withRenderingMode(.alwaysTemplate))
}

func menuSymbol(_ name: String) -> Image {
    let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    guard let image = UIImage(systemName: name, withConfiguration: config) else { return Image(systemName: name) }
    return Image(uiImage: image.withRenderingMode(.alwaysTemplate))
}
