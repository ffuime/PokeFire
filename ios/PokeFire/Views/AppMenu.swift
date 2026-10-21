import SwiftUI
import UIKit

enum AppSettings {
    static let autoSleepKey = "pokefire-auto-sleep"
    static let portraitTeamKey = "pokefire-team-portrait"

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
                        Image("tab_attack")
                    }
                }
                .disabled(stats.mode == .fire)
                Button { go(.stats) } label: {
                    Label("PokéStats", systemImage: "chart.pie")
                }
                .disabled(stats.mode == .stats)
                Button { go(.box) } label: {
                    Label("PokéBox", systemImage: "cube.box")
                }
                .disabled(stats.mode == .box)
            }
            Button {
                showSettings = true
            } label: {
                Label("設定", systemImage: "gearshape")
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("自動スリープ", isOn: $autoSleep)
                } footer: {
                    Text("オフにすると、アプリを開いている間は画面が消えなくなります。")
                }
                Section {
                    Toggle("チームの画像を縦長にする", isOn: $portraitTeam)
                } footer: {
                    Text("オンにすると、チームの一枚絵が横2×縦3の並びになります。")
                }
                Section("免責事項") {
                    Text("Pokélett は個人が作成した非公式のツールで、任天堂・クリーチャーズ・ゲームフリーク・株式会社ポケモンとは関係ありません。")
                    Text("ポケモンの名前・画像などの著作権は各権利者に帰属します。")
                    Text("計算結果や使用率などのデータの正確さは保証できません。ご利用は自己責任でお願いします。")
                }
                .font(.footnote)
                .foregroundStyle(Palette.secondary)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

func fixedIcon(_ name: String, size: CGFloat) -> Image {
    guard let base = UIImage(named: name) else { return Image(name) }
    let rendered = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
        base.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return Image(uiImage: rendered.withRenderingMode(.alwaysTemplate))
}
