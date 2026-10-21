import SwiftUI
import UIKit

enum AppSettings {
    static let autoSleepKey = "pokefire-auto-sleep"

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
                Icon(name: "menu", size: 20)
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("自動スリープ", isOn: $autoSleep)
                } footer: {
                    Text("オフにすると、アプリを開いている間は画面が消えなくなります。")
                }
                Section("出典") {
                    Link(destination: URL(string: "https://championsbattledata.com")!) {
                        LabeledContent("使用率・覚えるわざ", value: "Pokémon Champions Battle Data")
                    }
                    Link(destination: URL(string: "https://gamewith.jp/pokemon-champions/")!) {
                        LabeledContent("わざ・もちものの情報と画像", value: "GameWith")
                    }
                    Link(destination: URL(string: "https://pokeapi.co")!) {
                        LabeledContent("英語名の対応", value: "PokéAPI")
                    }
                    Link(destination: URL(string: "https://pokesol.app")!) {
                        LabeledContent("ポケモンの画像", value: "pokesol")
                    }
                }
                Section("免責事項") {
                    Text("PokéFire は個人が作成した非公式のツールで、任天堂・クリーチャーズ・ゲームフリーク・株式会社ポケモンとは関係ありません。")
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
