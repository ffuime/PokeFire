import SwiftUI

struct RoundedPolygon: Shape {
    let points: [CGPoint]
    var radius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        guard points.count > 2 else { return Path() }
        var path = Path()
        let count = points.count
        let start = CGPoint(x: (points[count - 1].x + points[0].x) / 2, y: (points[count - 1].y + points[0].y) / 2)
        path.move(to: start)
        for index in 0..<count {
            let corner = points[index]
            let next = points[(index + 1) % count]
            path.addArc(tangent1End: corner, tangent2End: next, radius: radius)
        }
        path.closeSubpath()
        return path
    }
}

enum DataKind: String, Identifiable, CaseIterable {
    case pokemon, move, ability, item

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pokemon: return "ポケモン"
        case .move: return "わざ"
        case .ability: return "とくせい"
        case .item: return "もちもの"
        }
    }

    var color: Color {
        switch self {
        case .pokemon: return Color.dynamic(0x535CA8, 0x5D66C2)
        case .move: return Color.dynamic(0xD6546A, 0xC64C61)
        case .ability: return Color.dynamic(0x1F9A9A, 0x1C8C8C)
        case .item: return Color.dynamic(0xE09A1B, 0xC9861A)
        }
    }
}

struct DataHome: View {
    @Environment(StatsModel.self) private var stats
    @State private var sheet: DataKind?

    private func regions(_ size: CGSize) -> [(DataKind, [CGPoint])] {
        let w = size.width
        let h = size.height
        let g: CGFloat = 10
        func y1(_ x: CGFloat) -> CGFloat { h * (0.5 - 0.12 * x / max(1, w)) }
        let xA = w * 0.6
        let xB = w * 0.5
        let ya = h * 0.79
        let yb = h * 0.71
        let xC = xA + (xB - xA) * (ya - y1(xA)) / (h - y1(xA))
        return [
            (.pokemon, [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: w, y: y1(w) - g / 2), CGPoint(x: 0, y: y1(0) - g / 2)]),
            (.move, [CGPoint(x: 0, y: y1(0) + g / 2), CGPoint(x: xA - g / 2, y: y1(xA) + g / 2), CGPoint(x: xB - g / 2, y: h), CGPoint(x: 0, y: h)]),
            (.ability, [CGPoint(x: xA + g / 2, y: y1(xA) + g / 2), CGPoint(x: w, y: y1(w) + g / 2), CGPoint(x: w, y: yb - g / 2), CGPoint(x: xC + g / 2, y: ya - g / 2)]),
            (.item, [CGPoint(x: xC + g / 2, y: ya + g / 2), CGPoint(x: w, y: yb + g / 2), CGPoint(x: w, y: h), CGPoint(x: xB + g / 2, y: h)]),
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                ForEach(regions(size), id: \.0) { kind, points in
                    let shape = RoundedPolygon(points: points, radius: 22)
                    Button {
                        Haptics.play(.medium)
                        sheet = kind
                    } label: {
                        ZStack(alignment: .topLeading) {
                            shape.fill(kind.color)
                            label(kind, points: points)
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(kind.title)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 62)
        .padding(.bottom, 10)
        .background(Palette.background.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            HStack(spacing: 10) {
                CircleIconButton(icon: "menu", label: "サイドバー") {
                    stats.drawerRequests += 1
                }
                Text("PokéData")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.leading, 12)
            .padding(.top, 6)
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .pokemon: DataPokemonSheet()
            case .move: DataMoveSheet()
            case .ability: DataAbilitySheet()
            case .item: DataItemSheet()
            }
        }
    }

    @ViewBuilder
    private func label(_ kind: DataKind, points: [CGPoint]) -> some View {
        let minX = points.map(\.x).min() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let width = maxX - minX
        let height = maxY - minY
        let size = min(width, height) * (kind == .pokemon ? 0.62 : kind == .move ? 0.5 : 0.5)
        let centerX = minX + width * (kind == .item ? 0.58 : 0.5)
        let centerY = minY + height * (kind == .pokemon ? 0.46 : kind == .move ? 0.5 : kind == .ability ? 0.48 : 0.56)
        DataIcon(kind: kind)
            .frame(width: size, height: size)
            .foregroundStyle(Color.white)
            .position(x: centerX, y: centerY)
    }
}

struct DataIcon: View {
    let kind: DataKind

    var body: some View {
        switch kind {
        case .pokemon:
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let line = size * 0.09
                let inner = size * 0.34
                ZStack {
                    Circle().strokeBorder(lineWidth: line)
                    HStack(spacing: inner) {
                        Rectangle().frame(height: line)
                        Rectangle().frame(height: line)
                    }
                    .padding(.horizontal, line / 2)
                    Circle().strokeBorder(lineWidth: line).frame(width: inner, height: inner)
                    Circle().frame(width: inner * 0.32, height: inner * 0.32)
                }
                .frame(width: size, height: size)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        case .move:
            Image("tab_attack")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        case .ability:
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
        case .item:
            Image(systemName: "bag.fill")
                .resizable()
                .scaledToFit()
        }
    }
}

struct DataListHeader: View {
    let title: String
    @Binding var query: String
    var focused: FocusState<Bool>.Binding
    let prompt: String
    var filterActive = false
    var onFilter: (() -> Void)?
    let onClose: () -> Void
    @State private var mode = 0

    var body: some View {
        SearchHeader(
            title: title,
            mode: $mode,
            query: $query,
            focused: focused,
            prompt: prompt,
            onSubmit: {},
            onClose: onClose,
            filterActive: filterActive,
            onFilter: onFilter
        )
    }
}

struct PokemonFilter: Equatable {
    enum Group: String, CaseIterable {
        case all = "すべて"
        case released = "内定"
        case unreleased = "未内定"
    }

    enum Sort: String, CaseIterable {
        case dex = "図鑑番号"
        case usage = "使用率"
        case total = "合計"
        case h = "H"
        case a = "A"
        case b = "B"
        case c = "C"
        case d = "D"
        case s = "S"
        case weight = "重さ"
    }

    var types: Set<String> = []
    var bothTypes = false
    var group = Group.all
    var mega = 0
    var ability = ""
    var moves = ""
    var mins: [String: String] = [:]
    var maxs: [String: String] = [:]
    var sort = Sort.dex
    var descending = false

    static let statKeys = ["H", "A", "B", "C", "D", "S", "合計", "重さ"]

    var isActive: Bool {
        var copy = self
        copy.sort = .dex
        copy.descending = false
        return copy != PokemonFilter()
    }
}

struct DataPokemonSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter = PokemonFilter()
    @State private var showFilter = false
    @State private var expanded: Set<String> = []
    @FocusState private var focused: Bool

    private func value(_ key: String, _ pokemon: Pokemon) -> Double {
        let base = pokemon.base
        switch key {
        case "H": return Double(base.h)
        case "A": return Double(base.a)
        case "B": return Double(base.b)
        case "C": return Double(base.c)
        case "D": return Double(base.d)
        case "S": return Double(base.s)
        case "合計": return Double(base.h + base.a + base.b + base.c + base.d + base.s)
        default: return pokemon.weight
        }
    }

    private var rows: [String] {
        let data = model.data
        let released = Set(data.pokemonOrder)
        var names = data.allPokemonOrder
        switch filter.group {
        case .released: names = names.filter { released.contains($0) }
        case .unreleased: names = names.filter { !released.contains($0) }
        case .all: break
        }
        if filter.mega == 1 { names = names.filter { data.megaParent($0) != nil } }
        if filter.mega == 2 { names = names.filter { data.megaParent($0) == nil } }
        if !filter.types.isEmpty {
            names = names.filter { name in
                let types = Set(data.pokemons[name]?.types ?? [])
                return filter.bothTypes ? filter.types.isSubset(of: types) : !filter.types.isDisjoint(with: types)
            }
        }
        let ability = filter.ability.trimmingCharacters(in: .whitespaces)
        if !ability.isEmpty {
            let key = Search.normalize(ability)
            names = names.filter { name in (data.pokemons[name]?.abilities ?? []).contains { Search.normalize($0).contains(key) } }
        }
        let moveWords = filter.moves.split(whereSeparator: { " 、,/".contains($0) }).map(String.init)
        if !moveWords.isEmpty {
            names = names.filter { name in
                guard let learnable = model.learnset(name) else { return false }
                return moveWords.allSatisfy { word in learnable.contains { $0.contains(word) } }
            }
        }
        for key in PokemonFilter.statKeys {
            if let low = Double(filter.mins[key] ?? "") {
                names = names.filter { data.pokemons[$0].map { value(key, $0) >= low } ?? false }
            }
            if let high = Double(filter.maxs[key] ?? "") {
                names = names.filter { data.pokemons[$0].map { value(key, $0) <= high } ?? false }
            }
        }
        if !query.isEmpty {
            let tiers = Search.rank(names.map { data.pokemonSearchText($0) }, query: query)
            names = Search.ordered(names.count, tiers: tiers) { names[$0] }.map { names[$0] }
        }
        let index = Dictionary(uniqueKeysWithValues: data.allPokemonOrder.enumerated().map { ($1, $0) })
        let sortKey: (String) -> Double = { name in
            guard let pokemon = data.pokemons[name] else { return 0 }
            switch filter.sort {
            case .dex: return Double(Int(pokemon.num) ?? 0) * 100 + Double(index[name] ?? 0) / 10000
            case .usage: return Double(self.model.usage?.pokemons[name]?.rank ?? 100_000)
            case .total: return value("合計", pokemon)
            case .weight: return value("重さ", pokemon)
            default: return value(filter.sort.rawValue, pokemon)
            }
        }
        if query.isEmpty || filter.sort != .dex {
            names.sort { lhs, rhs in
                let l = sortKey(lhs)
                let r = sortKey(rhs)
                if l == r { return (index[lhs] ?? 0) < (index[rhs] ?? 0) }
                let ascending = [.dex, .usage].contains(filter.sort) ? !filter.descending : filter.descending
                return ascending ? l < r : l > r
            }
        }
        return names
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            DataListHeader(
                title: "ポケモン",
                query: $query,
                focused: $focused,
                prompt: "名前・タイプ・とくせいで検索…",
                filterActive: filter.isActive,
                onFilter: {
                    focused = false
                    showFilter = true
                },
                onClose: { dismiss() }
            )
            HStack {
                Text("\(list.count)件")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Menu {
                    Picker("並び順", selection: $filter.sort) {
                        ForEach(PokemonFilter.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("逆順", isOn: $filter.descending)
                } label: {
                    Label(filter.sort.rawValue, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.bold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            List {
                ForEach(list, id: \.self) { name in
                    DataPokemonRow(name: name, sort: filter.sort, open: expanded.contains(name)) {
                        focused = false
                        stats.select(.attacker, name)
                        withAnimation(.easeInOut(duration: 0.35)) { stats.openStats() }
                        dismiss()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.play(.light)
                        withAnimation(.snappy(duration: 0.28)) {
                            if expanded.contains(name) { expanded.remove(name) } else { expanded.insert(name) }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list.isEmpty { EmptyResult(text: "見つかりません") }
            }
        }
        .sheet(isPresented: $showFilter) {
            PokemonFilterSheet(filter: $filter)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct DataPokemonRow: View {
    let name: String
    let sort: PokemonFilter.Sort
    var open = false
    var openStats: () -> Void = {}

    var body: some View {
        let pokemon = GameData.shared.pokemons[name]
        let base = pokemon?.base ?? BaseStats()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SpriteView(name: name, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(StatKey.baseKeys.map { String(base[$0]) }.joined(separator: "-"))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    ForEach(pokemon?.types ?? [], id: \.self) { TypeIcon(type: $0, size: 20) }
                }
            }
            if open {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("とくせい")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.secondary)
                            .frame(width: 48, alignment: .leading)
                        Text((pokemon?.abilities ?? []).joined(separator: " / "))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("重さ")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.secondary)
                            .frame(width: 48, alignment: .leading)
                        Text(String(format: "%gkg", pokemon?.weight ?? 0))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                    Button(action: openStats) {
                        Label("PokéStatsで見る", systemImage: "chart.pie")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 2)
                }
                .padding(.leading, 56)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
    }
}

struct PokemonFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: PokemonFilter

    var body: some View {
        NavigationStack {
            Form {
                Section("タイプ") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                        ForEach(Palette.typeOrder, id: \.self) { type in
                            let selected = filter.types.contains(type)
                            Button {
                                Haptics.play(.selection)
                                if selected { filter.types.remove(type) } else { filter.types.insert(type) }
                            } label: {
                                VStack(spacing: 4) {
                                    TypeIcon(type: type, size: 34)
                                        .opacity(selected || filter.types.isEmpty ? 1 : 0.3)
                                    Text(type)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(selected ? Palette.ink : Palette.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    Picker("条件", selection: $filter.bothTypes) {
                        Text("いずれかを含む").tag(false)
                        Text("すべてを含む").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Section("区分") {
                    Picker("内定", selection: $filter.group) {
                        ForEach(PokemonFilter.Group.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("メガシンカ", selection: $filter.mega) {
                        Text("すべて").tag(0)
                        Text("メガのみ").tag(1)
                        Text("メガを除く").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("とくせい（一部でも可）", text: $filter.ability)
                    TextField("覚えるわざ（空白区切りで複数）", text: $filter.moves)
                } header: {
                    Text("とくせい・わざ")
                } footer: {
                    Text("覚えるわざは、内定ポケモンのみ絞り込めます。")
                }
                Section("種族値・重さ") {
                    ForEach(PokemonFilter.statKeys, id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.subheadline.weight(.bold))
                                .frame(width: 44, alignment: .leading)
                            TextField("下限", text: Binding(get: { filter.mins[key] ?? "" }, set: { filter.mins[key] = $0 }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                            Text("〜")
                                .foregroundStyle(Palette.secondary)
                            TextField("上限", text: Binding(get: { filter.maxs[key] ?? "" }, set: { filter.maxs[key] = $0 }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                Section("並び順") {
                    Picker("並び順", selection: $filter.sort) {
                        ForEach(PokemonFilter.Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("逆順", isOn: $filter.descending)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") { filter = PokemonFilter() }
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
}

struct DataMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter = MoveFilter()
    @State private var showFilter = false
    @State private var learnersOf: String?
    @FocusState private var focused: Bool

    private func searchText(_ info: MoveInfo) -> String {
        Search.tiers([
            .text(Search.textOf(kind: "moves", name: info.name)),
            .list([info.type]),
            .list([info.category, Search.categoryReadings[info.category] ?? ""]),
            .text("=\(info.powerText)"),
            .list([info.effect]),
        ])
    }

    private var rows: [MoveInfo] {
        let catalog = StatsCatalog.shared
        let infos = StatsCatalog.sortedMoves(catalog.moveOrder).compactMap { catalog.moveInfo($0) }.filter { filter.matches($0) }
        guard !query.isEmpty else { return infos }
        let tiers = Search.rank(infos.map(searchText), query: query)
        return Search.ordered(infos.count, tiers: tiers) { infos[$0].name }.map { infos[$0] }
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            DataListHeader(
                title: "わざ",
                query: $query,
                focused: $focused,
                prompt: "わざの名前・タイプ・効果で検索…",
                filterActive: filter.isActive,
                onFilter: {
                    focused = false
                    showFilter = true
                },
                onClose: { dismiss() }
            )
            HStack {
                Text("\(list.count)件")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(list.enumerated()), id: \.element.name) { index, info in
                        if query.isEmpty, index == 0 || list[index - 1].type != info.type {
                            HStack(spacing: 6) {
                                TypeIcon(type: info.type, size: 18)
                                Text(info.type)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Palette.secondary)
                            }
                            .padding(.top, index == 0 ? 4 : 14)
                            .padding(.leading, 6)
                        }
                        LearnsetRow(info: info, open: false) {
                            Haptics.play(.light)
                            learnersOf = info.name
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list.isEmpty { EmptyResult(text: "見つかりません") }
            }
        }
        .sheet(isPresented: $showFilter) {
            MoveFilterSheet(filter: $filter)
        }
        .sheet(item: Binding(get: { learnersOf.map { MoveRef(name: $0) } }, set: { learnersOf = $0?.name })) { ref in
            MoveLearnersSheet(name: ref.name) {
                dismiss()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct DataEntryRow: View {
    let name: String
    let effect: String
    let unimplemented: Bool
    let open: Bool
    var sprite: String?
    var holders: [String] = []
    var onPokemon: ((String) -> Void)?

    var expandable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                if let sprite {
                    SpriteIcon(name: sprite, size: 28)
                }
                if unimplemented { UnimplementedMark() }
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 4)
                if expandable {
                    Icon(name: "chevron_down", size: 14)
                        .foregroundStyle(Palette.secondary.opacity(0.6))
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            }
            Text(effect.isEmpty ? "説明はありません" : effect)
                .font(.footnote)
                .foregroundStyle(Palette.secondary)
                .lineLimit(open || !expandable ? nil : 1)
                .fixedSize(horizontal: false, vertical: open || !expandable)
            if open, !holders.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 4)], spacing: 4) {
                    ForEach(holders, id: \.self) { holder in
                        Button {
                            onPokemon?(holder)
                        } label: {
                            SpriteView(name: holder, size: 44)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(open ? Palette.card : Color.clear)
                .shadow(color: open ? .black.opacity(0.08) : .clear, radius: 10, y: 3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DataAbilitySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var state = 0
    @State private var expanded: Set<String> = []
    @FocusState private var focused: Bool

    private var rows: [String] {
        let data = model.data
        var names = data.abilityOrder.filter { $0 != "なし" } + data.unreleasedAbilityOrder
        if state == 1 { names = names.filter { !data.isUnimplemented(ability: $0) } }
        if state == 2 { names = names.filter { data.isUnimplemented(ability: $0) } }
        guard !query.isEmpty else { return names }
        let texts = names.map { name in data.abilities[name].map { data.effectSearchText(kind: "abilities", $0) } ?? name }
        let tiers = Search.rank(texts, query: query)
        return Search.ordered(names.count, tiers: tiers) { names[$0] }.map { names[$0] }
    }

    private func holders(_ ability: String) -> [String] {
        model.data.allPokemonOrder.filter { model.data.pokemons[$0]?.abilities.contains(ability) ?? false }
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            DataListHeader(title: "とくせい", query: $query, focused: $focused, prompt: "とくせいの名前・効果で検索…", onClose: { dismiss() })
            Picker("実装", selection: $state) {
                Text("すべて").tag(0)
                Text("実装済み").tag(1)
                Text("未実装").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(list, id: \.self) { name in
                        let open = expanded.contains(name)
                        DataEntryRow(
                            name: name,
                            effect: model.data.abilities[name]?.effect ?? "",
                            unimplemented: model.data.isUnimplemented(ability: name),
                            open: open,
                            holders: open ? holders(name) : [],
                            onPokemon: { pokemon in
                                stats.select(.attacker, pokemon)
                                withAnimation(.easeInOut(duration: 0.35)) { stats.openStats() }
                                dismiss()
                            }
                        )
                        .onTapGesture {
                            Haptics.play(.light)
                            withAnimation(.snappy(duration: 0.28)) {
                                if open { expanded.remove(name) } else { expanded.insert(name) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list.isEmpty { EmptyResult(text: "見つかりません") }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct DataItemSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var state = 0
    @State private var category = 0
    @State private var expanded: Set<String> = []
    @FocusState private var focused: Bool

    private var all: [String] {
        let data = model.data
        let catalog = StatsCatalog.shared
        let megas = catalog.itemOrder.filter { catalog.items[$0]?.mega ?? false }
        return data.itemOrder.filter { $0 != "なし" && $0 != UsageLoader.megaStone } + data.unreleasedItemOrder + megas
    }

    private func effect(_ name: String) -> String {
        model.data.items[name]?.effect ?? StatsCatalog.shared.itemEffect(name)
    }

    private var rows: [String] {
        let data = model.data
        let catalog = StatsCatalog.shared
        var names = all
        if state == 1 { names = names.filter { !data.isUnimplemented(item: $0) } }
        if state == 2 { names = names.filter { data.isUnimplemented(item: $0) } }
        switch category {
        case 1: names = names.filter { $0.hasSuffix("のみ") }
        case 2: names = names.filter { catalog.items[$0]?.mega ?? false }
        case 3: names = names.filter { !$0.hasSuffix("のみ") && !(catalog.items[$0]?.mega ?? false) }
        default: break
        }
        guard !query.isEmpty else { return names }
        let tiers = Search.rank(names.map { Search.tiers([.text(Search.textOf(kind: "items", name: $0)), .list([effect($0)])]) }, query: query)
        return Search.ordered(names.count, tiers: tiers) { names[$0] }.map { names[$0] }
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            DataListHeader(title: "もちもの", query: $query, focused: $focused, prompt: "もちものの名前・効果で検索…", onClose: { dismiss() })
            VStack(spacing: 8) {
                Picker("実装", selection: $state) {
                    Text("すべて").tag(0)
                    Text("実装済み").tag(1)
                    Text("未実装").tag(2)
                }
                Picker("分類", selection: $category) {
                    Text("すべて").tag(0)
                    Text("きのみ").tag(1)
                    Text("メガストーン").tag(2)
                    Text("その他").tag(3)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(list, id: \.self) { name in
                        DataEntryRow(
                            name: name,
                            effect: effect(name),
                            unimplemented: model.data.isUnimplemented(item: name),
                            open: false,
                            sprite: name,
                            expandable: false
                        )
                        Divider().padding(.leading, 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list.isEmpty { EmptyResult(text: "見つかりません") }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct MoveRef: Identifiable {
    var id: String { name }
    let name: String
}

struct MoveLearnersSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Environment(\.dismiss) private var dismiss
    let name: String
    let closeParent: () -> Void

    private var learners: [String] {
        guard let learnsets = model.learnsets else { return [] }
        let data = model.data
        let english = Set(learnsets.filter { $0.value.contains(name) }.map(\.key))
        return data.pokemonOrder.filter { pokemon in
            guard let en = data.usageNames.pokemons[pokemon] else { return false }
            return english.contains(en)
        }
    }

    var body: some View {
        let list = learners
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Palette.ink)
                if let info = StatsCatalog.shared.moveInfo(name) {
                    MoveDetailContent(info: info)
                }
                Text("覚えるポケモン（\(list.count)）")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondary)
                    .padding(.top, 4)
                if model.learnsets == nil {
                    ProgressView()
                } else if list.isEmpty {
                    Text("覚えるポケモンのデータはありません")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(list, id: \.self) { pokemon in
                        Button {
                            stats.select(.attacker, pokemon)
                            withAnimation(.easeInOut(duration: 0.35)) { stats.openStats() }
                            dismiss()
                            closeParent()
                        } label: {
                            SpriteView(name: pokemon, size: 52)
                                .frame(width: 60, height: 60)
                                .background(Palette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(pokemon)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
