import SwiftUI

struct HistoryDrawer: View {
    @Environment(AppModel.self) private var model
    let close: () -> Void

    @State private var query = ""
    @State private var searching = false
    @FocusState private var focused: Bool

    private struct HistoryGroup: Identifiable {
        var id: String { title }
        let title: String
        var entries: [HistoryEntry]
    }

    private static func groupTitle(_ time: Double) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date()).timeIntervalSince1970 * 1000
        let day = 86_400_000.0
        if time >= today { return "今日" }
        if time >= today - day { return "昨日" }
        if time >= today - day * 7 { return "過去7日間" }
        return "それ以前"
    }

    private static func timeText(_ entry: HistoryEntry) -> String {
        let date = entry.date
        let group = groupTitle(entry.time)
        let calendar = Calendar.current
        if group == "今日" || group == "昨日" {
            return String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
        }
        return "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))"
    }

    private var groups: [HistoryGroup] {
        let key = Search.normalize(query)
        let list = model.history.filter { entry in
            key.isEmpty || Search.normalize([entry.title, entry.moves.joined(separator: " "), entry.judge].joined(separator: " ")).contains(key)
        }
        var result: [HistoryGroup] = []
        let pinned = list.filter(\.pinned)
        if !pinned.isEmpty { result.append(HistoryGroup(title: "ピン留め", entries: pinned)) }
        for entry in list where !entry.pinned {
            let title = Self.groupTitle(entry.time)
            if result.last?.title == title, !(result.last?.title == "ピン留め") {
                result[result.count - 1].entries.append(entry)
            } else {
                result.append(HistoryGroup(title: title, entries: [entry]))
            }
        }
        return result
    }

    var body: some View {
        let sections = groups
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("履歴")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.black)
                Spacer()
                Button {
                    Haptics.play(.light)
                    withAnimation(.snappy) {
                        searching.toggle()
                    }
                    if searching {
                        focused = true
                    } else {
                        query = ""
                        focused = false
                    }
                } label: {
                    Icon(name: searching ? "xmark" : "search", size: 20)
                        .foregroundStyle(Color.black)
                        .frame(width: 46, height: 46)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel(searching ? "検索を閉じる" : "履歴を検索")
            }
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if searching {
                HStack(spacing: 8) {
                    Icon(name: "search", size: 16)
                        .foregroundStyle(Palette.secondary)
                    TextField("ポケモン・わざで検索", text: $query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color(hex: 0xF2F2F4), in: Capsule())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if sections.isEmpty {
                Text(query.isEmpty ? "計算した対面が\nここに自動で残ります" : "見つかりません")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections) { section in
                        Text(section.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                            .padding(.top, 14)
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        ForEach(section.entries) { entry in
                            row(entry)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 10)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .animation(.snappy, value: model.history)
    }

    private func row(_ entry: HistoryEntry) -> some View {
        let judge = entry.judge.isEmpty ? "" : entry.judge + (entry.rate.isEmpty ? "" : "（\(entry.rate)）")
        let sub = [Self.timeText(entry), entry.moves.joined(separator: "・"), judge].filter { !$0.isEmpty }.joined(separator: " ・ ")
        return Button {
            close()
            model.applyHistory(entry)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if entry.pinned {
                        Icon(name: "pin", size: 13)
                            .foregroundStyle(Palette.accent)
                    }
                    Text(entry.title)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                }
                Text(sub)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                model.deleteHistory(entry)
            } label: {
                Label {
                    Text("削除")
                } icon: {
                    Image("trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                model.togglePin(entry)
            } label: {
                Label {
                    Text(entry.pinned ? "解除" : "ピン留め")
                } icon: {
                    Image("pin")
                }
            }
            .tint(Palette.accent)
        }
        .contextMenu {
            Button {
                close()
                model.applyHistory(entry)
            } label: {
                Label {
                    Text("この条件を開く")
                } icon: {
                    Image("history")
                }
            }
            Button {
                model.togglePin(entry)
            } label: {
                Label {
                    Text(entry.pinned ? "ピン留めを解除" : "ピン留め")
                } icon: {
                    Image("pin")
                }
            }
            if let url = model.historyShareURL(entry) {
                ShareLink(item: url, preview: SharePreview(entry.title)) {
                    Label {
                        Text("共有")
                    } icon: {
                        Image("share")
                    }
                }
            }
            Divider()
            Button(role: .destructive) {
                model.deleteHistory(entry)
            } label: {
                Label {
                    Text("削除")
                } icon: {
                    Image("trash")
                }
            }
        } preview: {
            HistoryPreview(entry: entry)
        }
    }
}

private struct HistoryPreview: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: -10) {
                ForEach(Array(entry.attackers.prefix(3)), id: \.self) { name in
                    SpriteView(name: name, size: 64)
                }
                Icon(name: "move_right", size: 22)
                    .foregroundStyle(Palette.secondary.opacity(0.5))
                    .padding(.horizontal, 16)
                SpriteView(name: entry.defender, size: 64)
            }
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(entry.moves.joined(separator: "・"))
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.judge)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.rankDown)
                if !entry.rate.isEmpty {
                    Text(entry.rate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                }
            }
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(Palette.secondary)
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
        .background(Color.white)
    }
}
