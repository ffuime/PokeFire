import SwiftUI

struct UsageCredit: View {
    var body: some View {
        Link(destination: UsageLoader.source) {
            Text("Battle data provided by Pokémon Champions Battle Data")
                .font(.caption2)
                .foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}

struct EmptyResult: View {
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Icon(name: "search", size: 34)
                .foregroundStyle(Palette.secondary.opacity(0.5))
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

struct CloseToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Icon(name: "xmark", size: 16)
                .foregroundStyle(Palette.ink)
        }
        .accessibilityLabel("閉じる")
    }
}

struct PokemonPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let role: Role

    @State private var query = ""
    @State private var mode = 0
    @State private var searching = false

    private struct Row: Identifiable {
        var id: String { name }
        let name: String
        let nested: Bool
    }

    private var rows: [Row] {
        let data = model.data
        let base: [String] = mode == 0
            ? model.pokemonOrder()
            : Storage.pokemonHistory.filter { data.pokemons[$0] != nil }
        let tiers = Search.rank(base.map { data.pokemonSearchText($0) }, query: query)
        let order = Search.ordered(base.count, tiers: tiers) { index in
            mode == 0 ? (data.megaParent(base[index]) ?? base[index]) : base[index]
        }
        let names = order.map { base[$0] }
        let visible = Set(names)
        return names.map { name in
            Row(name: name, nested: mode == 0 && (data.megaParent(name).map { visible.contains($0) } ?? false))
        }
    }

    var body: some View {
        let list = rows
        let current = model.side(role).name
        NavigationStack {
            List {
                ForEach(list) { row in
                    Button {
                        select(row.name)
                    } label: {
                        PokemonRow(name: row.name, nested: row.nested, selected: row.name == current, rank: model.usage?.pokemons[row.name]?.rank)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: row.nested ? 34 : 16, bottom: 4, trailing: 16))
                    .listRowBackground(row.name == current ? Palette.accent.opacity(0.06) : Color.white)
                }
                if !list.isEmpty {
                    UsageCredit()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .overlay {
                if list.isEmpty {
                    EmptyResult(text: mode == 1 && Storage.pokemonHistory.isEmpty ? "履歴はまだありません" : "見つかりません")
                }
            }
            .searchable(text: $query, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always), prompt: "名前・ローマ字・タイプ・とくせい")
            .onSubmit(of: .search) {
                if let first = list.first { select(first.name) }
            }
            .navigationTitle("\(role.title)のポケモン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("並び", selection: $mode) {
                        Text("使用率").tag(0)
                        Text("履歴").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
            .onChange(of: mode) { _, _ in Haptics.play(.selection) }
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                searching = true
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func select(_ name: String) {
        model.selectPokemon(role, name)
        dismiss()
    }
}

struct PokemonRow: View {
    let name: String
    let nested: Bool
    let selected: Bool
    let rank: Int?

    var body: some View {
        let pokemon = GameData.shared.pokemons[name]
        HStack(spacing: 12) {
            if nested {
                Rectangle()
                    .fill(Palette.track)
                    .frame(width: 2, height: 30)
            }
            SpriteView(name: name, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let rank, rank != Int.max, !nested {
                    Text("使用率 \(rank)位")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(pokemon?.types ?? [], id: \.self) { type in
                    TypeIcon(type: type, size: 22)
                }
            }
            if selected {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .contentShape(Rectangle())
    }
}

enum EntryKind {
    case moves, abilities, items

    var title: String {
        switch self {
        case .moves: return "わざ"
        case .abilities: return "とくせい"
        case .items: return "もちもの"
        }
    }

    var usageKey: String {
        switch self {
        case .moves: return "moves"
        case .abilities: return "abilities"
        case .items: return "items"
        }
    }
}

struct EntrySearchSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let kind: EntryKind
    let role: Role

    @State private var query = ""
    @State private var searching = false

    private struct Row: Identifiable {
        var id: String { name }
        let name: String
        let effect: String
        let usage: String?
    }

    private func numberText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private var rows: [Row] {
        let data = model.data
        let name = model.side(role).name
        let names: [String]
        let texts: [String]
        switch kind {
        case .moves:
            names = data.moveOrder
            texts = names.map { data.moveSearchText($0) }
        case .abilities:
            names = data.abilityOrder
            texts = names.map { data.abilities[$0].map { data.effectSearchText(kind: "abilities", $0) } ?? "" }
        case .items:
            names = data.itemOrder
            texts = names.map { data.items[$0].map { data.effectSearchText(kind: "items", $0) } ?? "" }
        }
        var usage: [(String, Double)] = []
        if kind == .abilities, data.usageName(of: name) != name, let first = data.pokemons[name]?.abilities.first {
            usage = [(first, 100)]
        } else if let entry = model.usage?.pokemons[name] {
            let pairs: [UsagePair]
            switch kind {
            case .moves: pairs = entry.moves
            case .abilities: pairs = entry.abilities
            case .items: pairs = entry.items
            }
            usage = pairs.compactMap { pair in pair.name.map { ($0, pair.pct) } }
        }
        var rankOf: [String: Int] = [:]
        var percent: [String: String] = [:]
        for (index, pair) in usage.enumerated() where rankOf[pair.0] == nil {
            rankOf[pair.0] = index
            percent[pair.0] = "\(numberText(pair.1))%"
        }
        let indices = names.indices.sorted { lhs, rhs in
            let left = rankOf[names[lhs]] ?? (usage.count + lhs)
            let right = rankOf[names[rhs]] ?? (usage.count + rhs)
            return left < right
        }
        let orderedNames = indices.map { names[$0] }
        let orderedTexts = indices.map { texts[$0] }
        let tiers = Search.rank(orderedTexts, query: query)
        let order = Search.ordered(orderedNames.count, tiers: tiers) { orderedNames[$0] }
        return order.map { index in
            let entryName = orderedNames[index]
            let effect: String
            switch kind {
            case .moves: effect = data.moves[entryName]?.effect ?? ""
            case .abilities: effect = data.abilities[entryName]?.effect ?? ""
            case .items: effect = data.items[entryName]?.effect ?? ""
            }
            return Row(name: entryName, effect: effect, usage: percent[entryName])
        }
    }

    private var current: String {
        switch kind {
        case .moves: return model.attacker.move
        case .abilities: return model.side(role).ability
        case .items: return model.side(role).item
        }
    }

    var body: some View {
        let list = rows
        let selected = current
        NavigationStack {
            List {
                ForEach(list) { row in
                    Button {
                        select(row.name)
                    } label: {
                        EntryRow(kind: kind, name: row.name, effect: row.effect, usage: row.usage, selected: row.name == selected)
                    }
                    .listRowBackground(row.name == selected ? Palette.accent.opacity(0.06) : Color.white)
                }
                if !list.isEmpty {
                    UsageCredit()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .overlay {
                if list.isEmpty { EmptyResult(text: "見つかりません") }
            }
            .searchable(text: $query, isPresented: $searching, placement: .navigationBarDrawer(displayMode: .always), prompt: "\(kind.title)の名前を検索…")
            .onSubmit(of: .search) {
                if let first = list.first { select(first.name) }
            }
            .navigationTitle("\(kind.title)（\(model.side(role).name)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                searching = true
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func select(_ name: String) {
        switch kind {
        case .moves: model.selectMove(name)
        case .abilities: model.selectAbility(role, name)
        case .items: model.selectItem(role, name)
        }
        dismiss()
    }
}

struct EntryRow: View {
    let kind: EntryKind
    let name: String
    let effect: String
    let usage: String?
    let selected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selected ? Palette.accent : Palette.ink)
                    if let usage {
                        Text(usage)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Palette.accent.opacity(0.1), in: Capsule())
                    }
                }
                if !effect.isEmpty {
                    Text(effect)
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            if kind == .moves, let move = GameData.shared.moves[name] {
                HStack(spacing: 6) {
                    TypeIcon(type: move.type, size: 22)
                    CategoryIcon(category: move.category, size: 20)
                        .foregroundStyle(Palette.secondary)
                    Text(move.powerText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.secondary)
                        .frame(minWidth: 28, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct TypeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let role: Role

    var body: some View {
        let side = model.side(role)
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 14) {
                    ForEach(Palette.typeOrder, id: \.self) { type in
                        let selected = side.types.contains(type)
                        Button {
                            model.toggleType(role, type)
                        } label: {
                            VStack(spacing: 4) {
                                TypeIcon(type: type, size: 40)
                                    .opacity(selected ? 1 : 0.35)
                                    .scaleEffect(selected ? 1 : 0.9)
                                    .overlay {
                                        if selected {
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Palette.ink.opacity(0.8), lineWidth: 2)
                                                .padding(-3)
                                        }
                                    }
                                Text(type)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(selected ? Palette.ink : Palette.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .buttonStyle(PressableStyle())
                        .animation(.snappy(duration: 0.2), value: selected)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(20)
            }
            .navigationTitle("\(side.name)のタイプ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") { model.resetTypes(role) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct EnvironmentSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("天候・フィールド")
                .font(.headline)
                .frame(maxWidth: .infinity)
            row(title: "天候", kind: "weather", items: EnvironmentInfo.weathers.map { ($0.key, $0.label) }, selected: model.weather) { model.setWeather($0) }
            row(title: "フィールド", kind: "field", items: EnvironmentInfo.fields.map { ($0.key, $0.label) }, selected: model.field) { model.setField($0) }
            Text("選んでいるものをもう一度タップすると「なし」に戻ります。")
                .font(.caption)
                .foregroundStyle(Palette.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }

    private func row(title: String, kind: String, items: [(String, String)], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).sectionTitle()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        let active = item.0 == selected
                        Button {
                            onSelect(item.0)
                        } label: {
                            VStack(spacing: 6) {
                                Icon(name: "\(kind)_\(item.0)", size: 26)
                                Text(item.1)
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(active ? Color.white : Palette.environment(item.0))
                            .frame(maxWidth: .infinity)
                            .frame(height: 74)
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .glassEffect(active ? .regular.tint(Palette.environment(item.0)).interactive() : .regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel(item.1)
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
            }
        }
    }
}
