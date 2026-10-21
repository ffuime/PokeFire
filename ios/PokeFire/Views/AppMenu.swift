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
                    Label("PokéBox", systemImage: "archivebox")
                }
                .disabled(stats.mode == .box)
            }
            Button {
                showSettings = true
            } label: {
                Label("設定", systemImage: "gearshape")
            }
        } label: {
            Icon(name: "menu", size: 20)
                .foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: Circle())
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
