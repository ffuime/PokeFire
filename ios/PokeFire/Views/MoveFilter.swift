import SwiftUI

enum CompareMode: String, CaseIterable {
    case equal = "ぴったり"
    case atLeast = "以上"
    case atMost = "以下"

    func test(_ value: Int, _ target: Int) -> Bool {
        switch self {
        case .equal: return value == target
        case .atLeast: return value >= target
        case .atMost: return value <= target
        }
    }
}

struct MoveFilter: Equatable {
    var types: Set<String> = []
    var category = ""
    var power: Int?
    var powerMode = CompareMode.atLeast
    var accuracy: Int?
    var accuracyMode = CompareMode.atLeast
    var pp: Int?
    var priority: Int?
    var target = ""
    var flags: Set<String> = []

    var isActive: Bool { self != MoveFilter() }

    static let groups: [(title: String, items: [String])] = [
        ("状態異常", ["まひ", "ねむり", "こおり", "やけど", "どく", "もうどく", "こんらん", "ひるみ"]),
        ("ランク上昇", ["こうげき", "ぼうぎょ", "とくこう", "とくぼう", "すばやさ"]),
        ("相手のランク下降", ["こうげき", "ぼうぎょ", "とくこう", "とくぼう", "すばやさ"]),
        ("自分のランク下降", ["こうげき", "ぼうぎょ", "とくこう", "とくぼう", "すばやさ"]),
        ("カテゴリ", ["パンチわざ", "音わざ", "踊りわざ", "切りわざ", "風わざ", "粉わざ", "弾わざ", "波動わざ", "噛みわざ", "爆発わざ", "メンタルわざ", "回復わざ"]),
        ("その他", ["自分が交代する", "相手に交代させる", "交代を禁止する", "バインド状態にする", "自分がひんしになる", "反動ダメージがある", "反動で動けなくなる", "連続攻撃わざ", "急所ランクアップ", "一撃必殺", "必ず命中する", "溜めわざ", "タイプ変更", "もちもの変更", "とくせい変更"]),
    ]

    static let ppOptions = [1, 8, 12, 16, 20]

    func matches(_ info: MoveInfo) -> Bool {
        if !types.isEmpty, !types.contains(info.type) { return false }
        if !category.isEmpty, info.category != category { return false }
        if let power {
            guard let value = info.power, powerMode.test(value, power) else { return false }
        }
        if let accuracy {
            if let value = info.accuracy {
                if !accuracyMode.test(value, accuracy) { return false }
            } else if accuracyMode != .atLeast {
                return false
            }
        }
        if let pp, info.pp != pp { return false }
        if let priority, info.priority != priority { return false }
        if !target.isEmpty, info.target != target { return false }
        for group in Self.groups {
            let selected = flags.filter { $0.hasPrefix(group.title + ":") }
            if !selected.isEmpty, selected.isDisjoint(with: info.flags) { return false }
        }
        return true
    }
}

struct MoveFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: MoveFilter
    @State private var collapsed: Set<String> = []

    private static let powers = Array(stride(from: 5, through: 250, by: 5))
    private static let accuracies = Array(stride(from: 5, through: 100, by: 5))
    private static let priorities = Array((-7...7).reversed())

    private var targets: [String] {
        var seen: [String] = []
        for name in StatsCatalog.shared.moveOrder {
            if let target = StatsCatalog.shared.moves[name]?.target, !target.isEmpty, !seen.contains(target) {
                seen.append(target)
            }
        }
        return seen
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("タイプ") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                            ForEach(Palette.typeOrder, id: \.self) { type in
                                let selected = filter.types.contains(type)
                                Button {
                                    Haptics.play(.selection)
                                    if selected { filter.types.remove(type) } else { filter.types.insert(type) }
                                } label: {
                                    VStack(spacing: 4) {
                                        TypeIcon(type: type, size: 38)
                                            .opacity(selected || filter.types.isEmpty ? 1 : 0.3)
                                            .scaleEffect(selected ? 1 : 0.9)
                                        Text(type)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(selected ? Palette.ink : Palette.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                }
                                .buttonStyle(PressableStyle())
                                .animation(.snappy(duration: 0.2), value: selected)
                            }
                        }
                    }
                    section("分類") {
                        Picker("分類", selection: $filter.category) {
                            Text("すべて").tag("")
                            ForEach(["物理", "特殊", "変化"], id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    section("威力") {
                        wheelRow(value: $filter.power, values: Self.powers, mode: $filter.powerMode)
                    }
                    section("命中") {
                        wheelRow(value: $filter.accuracy, values: Self.accuracies, mode: $filter.accuracyMode)
                    }
                    section("PP") {
                        NativeSegmented(
                            segments: Self.ppOptions.map { .text("\($0)") },
                            selected: filter.pp.flatMap { Self.ppOptions.firstIndex(of: $0) } ?? -1,
                            height: 36,
                            allowsReselect: true
                        ) { index in
                            guard Self.ppOptions.indices.contains(index) else { return }
                            let value = Self.ppOptions[index]
                            filter.pp = filter.pp == value ? nil : value
                        }
                        .frame(height: 36)
                    }
                    section("優先度") {
                        Picker("優先度", selection: $filter.priority) {
                            Text("指定なし").tag(Int?.none)
                            ForEach(Self.priorities, id: \.self) { value in
                                Text(value > 0 ? "+\(value)" : "\(value)").tag(Int?.some(value))
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                    }
                    section("対象") {
                        Picker("対象", selection: $filter.target) {
                            Text("指定なし").tag("")
                            ForEach(targets, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    ForEach(MoveFilter.groups, id: \.title) { group in
                        section(group.title) {
                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element) { index, item in
                                    let key = "\(group.title):\(item)"
                                    if index > 0 { Divider() }
                                    Toggle(item, isOn: Binding(
                                        get: { filter.flags.contains(key) },
                                        set: { on in
                                            if on { filter.flags.insert(key) } else { filter.flags.remove(key) }
                                        }
                                    ))
                                    .font(.subheadline)
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.horizontal, 14)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") {
                        Haptics.play(.light)
                        filter = MoveFilter()
                    }
                    .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func wheelRow(value: Binding<Int?>, values: [Int], mode: Binding<CompareMode>) -> some View {
        HStack(spacing: 12) {
            Picker("数値", selection: value) {
                Text("指定なし").tag(Int?.none)
                ForEach(values, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            Picker("比較", selection: mode) {
                ForEach(CompareMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .disabled(value.wrappedValue == nil)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let open = !collapsed.contains(title)
        let count = activeCount(title)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title).sectionTitle()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Color.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Palette.accent))
                }
                Spacer()
                Icon(name: "chevron_down", size: 18)
                    .foregroundStyle(Palette.secondary)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.play(.light)
                withAnimation(.snappy(duration: 0.3)) {
                    if open { collapsed.insert(title) } else { collapsed.remove(title) }
                }
            }
            content()
                .frame(maxHeight: open ? nil : 0, alignment: .top)
                .mask { Rectangle().padding(.horizontal, -24) }
                .opacity(open ? 1 : 0)
                .allowsHitTesting(open)
        }
    }

    private func activeCount(_ title: String) -> Int {
        switch title {
        case "タイプ": return filter.types.count
        case "分類": return filter.category.isEmpty ? 0 : 1
        case "威力": return filter.power == nil ? 0 : 1
        case "命中": return filter.accuracy == nil ? 0 : 1
        case "PP": return filter.pp == nil ? 0 : 1
        case "優先度": return filter.priority == nil ? 0 : 1
        case "対象": return filter.target.isEmpty ? 0 : 1
        default: return filter.flags.filter { $0.hasPrefix(title + ":") }.count
        }
    }
}
