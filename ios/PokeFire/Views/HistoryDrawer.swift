import SwiftUI

struct HistoryDrawer: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let isOpen: Bool
    let close: () -> Void
    let dragChanged: (CGFloat) -> Void
    let dragEnded: (CGFloat, CGFloat) -> Void

    @State private var query = ""
    @State private var searching = false
    @FocusState private var focused: Bool
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var dragAccepted: Bool?
    @State private var showHelp = false

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
        timeText(entry.time)
    }

    private static func timeText(_ time: Double) -> String {
        let date = Date(timeIntervalSince1970: time / 1000)
        let group = groupTitle(time)
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
            ModeSwitcherList(close: close)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, stats.mode == .box ? 0 : 14)
            if stats.mode == .box {
                Spacer(minLength: 0)
            } else {
            HStack(spacing: 12) {
                Text("履歴")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.black)
                Spacer()
                HStack(spacing: 0) {
                Button {
                    Haptics.play(.light)
                    showHelp = true
                } label: {
                    Icon(name: "help", size: 20)
                        .foregroundStyle(Color.black)
                        .frame(width: 50, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("ヘルプ")
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
                    Group {
                        if searching {
                            CloseButtonLabel(size: 17)
                        } else {
                            Icon(name: "search", size: 20)
                        }
                    }
                    .foregroundStyle(Color.black)
                        .frame(width: 50, height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(searching ? "検索を閉じる" : "履歴を検索")
                }
                .padding(.horizontal, 4)
                .glassEffect(.regular.interactive(), in: Capsule())
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
                        .onChange(of: focused) { _, value in
                            if !value, searching {
                                withAnimation(.snappy) {
                                    searching = false
                                    query = ""
                                }
                            }
                        }
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

            if stats.isStats {
                statsContent
            } else if sections.isEmpty {
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
                .scrollDismissesKeyboard(.immediately)
                .environment(\.defaultMinListRowHeight, 10)
            }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .onChange(of: isOpen) { _, open in
            if !open {
                focused = false
                if searching {
                    searching = false
                    query = ""
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 14, coordinateSpace: .global)
                .onChanged { value in
                    if dragAccepted == nil {
                        let horizontal = abs(value.translation.width) > abs(value.translation.height)
                        let onRow = rowFrames.values.contains { $0.contains(value.startLocation) }
                        dragAccepted = horizontal && value.translation.width < 0 && !onRow
                    }
                    if dragAccepted == true {
                        dragChanged(value.translation.width)
                    }
                }
                .onEnded { value in
                    if dragAccepted == true {
                        dragEnded(value.translation.width, value.predictedEndTranslation.width)
                    }
                    dragAccepted = nil
                }
        )
        .animation(.snappy, value: model.history)
        .animation(.snappy, value: stats.history)
    }

    private struct StatsGroup: Identifiable {
        var id: String { title }
        let title: String
        var entries: [StatsHistoryEntry]
    }

    private var statsGroups: [StatsGroup] {
        let key = Search.normalize(query)
        let list = stats.history.filter { key.isEmpty || Search.normalize($0.title).contains(key) }
        var result: [StatsGroup] = []
        let pinned = list.filter(\.pinned)
        if !pinned.isEmpty { result.append(StatsGroup(title: "ピン留め", entries: pinned)) }
        for entry in list where !entry.pinned {
            let title = Self.groupTitle(entry.time)
            if result.last?.title == title {
                result[result.count - 1].entries.append(entry)
            } else {
                result.append(StatsGroup(title: title, entries: [entry]))
            }
        }
        return result
    }

    @ViewBuilder
    private var statsContent: some View {
        let sections = statsGroups
        if sections.isEmpty {
            Text(query.isEmpty ? "Stats Mode で見たポケモンが\nここに自動で残ります" : "見つかりません")
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
                        statsRow(entry)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .environment(\.defaultMinListRowHeight, 10)
        }
    }

    private func statsRow(_ entry: StatsHistoryEntry) -> some View {
        Button {
            close()
            stats.applyHistory(entry)
        } label: {
            HStack(spacing: 8) {
                SpriteView(name: entry.attacker.name, size: 46)
                VStack(spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        if entry.pinned {
                            Icon(name: "pin", size: 11)
                                .foregroundStyle(Palette.accent)
                        }
                        Text(Self.timeText(entry.time))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                SpriteView(name: entry.defender.name, size: 46)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            rowFrames["stats-" + entry.key] = frame
        }
        .onDisappear {
            rowFrames["stats-" + entry.key] = nil
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                stats.deleteHistory(entry)
            } label: {
                Label {
                    Text("削除")
                } icon: {
                    Image("trash")
                }
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                stats.togglePin(entry)
            } label: {
                Label {
                    Text(entry.pinned ? "解除" : "ピン留め")
                } icon: {
                    Image("pin")
                }
            }
            .tint(Palette.accent)
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        let judge = entry.judge.isEmpty ? "" : entry.judge + (entry.rate.isEmpty ? "" : "（\(entry.rate)）")
        let sub = [Self.timeText(entry), entry.moves.joined(separator: "・"), judge].filter { !$0.isEmpty }.joined(separator: " ・ ")
        return Button {
            close()
            model.applyHistory(entry)
        } label: {
            HStack(spacing: 8) {
                HStack(spacing: -16) {
                    ForEach(Array(entry.attackers.prefix(2)), id: \.self) { name in
                        SpriteView(name: name, size: 46)
                    }
                }
                .frame(minWidth: 46, alignment: .leading)
                VStack(spacing: 3) {
                    Text(entry.moves.joined(separator: "・"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        if entry.pinned {
                            Icon(name: "pin", size: 11)
                                .foregroundStyle(Palette.accent)
                        }
                        Text(Self.timeText(entry))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                SpriteView(name: entry.defender, size: 46)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title) \(sub)")
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            rowFrames[entry.key] = frame
        }
        .onDisappear {
            rowFrames[entry.key] = nil
        }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
            .tint(.red)
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

struct ModeSwitcherList: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let close: () -> Void

    private struct Item: Identifiable {
        let id: AppMode
        let title: String
        let subtitle: String
        let symbol: String?
        let image: String?
        let tint: Color
    }

    private let items: [Item] = [
        Item(id: .fire, title: "PokéFire", subtitle: "ダメージ計算", symbol: nil, image: "tab_attack", tint: Palette.attack),
        Item(id: .stats, title: "PokéStats", subtitle: "使用率・ステータス", symbol: "chart.pie", image: nil, tint: Palette.accent),
        Item(id: .box, title: "PokéBox", subtitle: "ポケモン・チーム管理", symbol: "archivebox", image: nil, tint: Color(hex: 0x20A6A6)),
    ]

    private func go(_ mode: AppMode) {
        close()
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
        VStack(spacing: 4) {
            ForEach(items) { item in
                let current = stats.mode == item.id
                Button {
                    go(item.id)
                } label: {
                    HStack(spacing: 12) {
                        Group {
                            if let image = item.image {
                                Icon(name: image, size: 18)
                            } else if let symbol = item.symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(current ? Color.white : item.tint)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(current ? item.tint : item.tint.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(Color.black)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(current ? Color(hex: 0xF2F2F4) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(current ? .isSelected : [])
            }
        }
    }
}
