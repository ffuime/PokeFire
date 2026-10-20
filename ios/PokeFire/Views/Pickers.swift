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
            CloseButtonLabel()
                .foregroundStyle(Palette.ink)
        }
        .accessibilityLabel("閉じる")
    }
}

struct SearchHeader: View {
    let title: String
    var modes: [String] = []
    @Binding var mode: Int
    @Binding var query: String
    var focused: FocusState<Bool>.Binding
    let prompt: String
    let onSubmit: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if modes.isEmpty {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                } else {
                    Picker(title, selection: $mode) {
                        ForEach(modes.indices, id: \.self) { index in
                            Text(modes[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Button(action: onClose) {
                    CloseButtonLabel()
                        .foregroundStyle(Palette.ink)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("閉じる")
            }
            HStack(spacing: 8) {
                Icon(name: "search", size: 17)
                    .foregroundStyle(Palette.secondary)
                TextField(prompt, text: $query)
                    .focused(focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(onSubmit)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("検索文字を消す")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color(hex: 0xEEEEF1), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

struct PokemonPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let role: Role

    @State private var query = ""
    @State private var mode = 0
    @State private var revision = 0
    @FocusState private var focused: Bool

    private struct Row: Identifiable {
        var id: String { name }
        let name: String
        let nested: Bool
    }

    private var rows: [Row] {
        _ = revision
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
        VStack(spacing: 0) {
            SearchHeader(
                title: "\(role.title)のポケモン",
                modes: ["使用率", "履歴"],
                mode: $mode,
                query: $query,
                focused: $focused,
                prompt: "名前・ローマ字・タイプ・とくせい",
                onSubmit: { if let first = list.first { select(first.name) } },
                onClose: { dismiss() }
            )
            List {
                ForEach(list) { row in
                    Button {
                        select(row.name)
                    } label: {
                        PokemonRow(name: row.name, nested: row.nested, selected: row.name == current, rank: model.usage?.pokemons[row.name]?.rank)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: row.nested ? 34 : 16, bottom: 4, trailing: 16))
                    .listRowBackground(row.name == current ? Palette.accent.opacity(0.06) : Color.white)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if mode == 1 {
                            Button(role: .destructive) {
                                Haptics.play(.medium)
                                withAnimation {
                                    Storage.forgetPokemon(row.name)
                                    revision += 1
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                if !list.isEmpty {
                    UsageCredit()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list.isEmpty {
                    EmptyResult(text: mode == 1 && Storage.pokemonHistory.isEmpty ? "履歴はまだありません" : "見つかりません")
                }
            }
        }
        .onChange(of: mode) { _, _ in Haptics.play(.selection) }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            focused = true
        }
        .presentationDragIndicator(.visible)
    }

    private func select(_ name: String) {
        focused = false
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

    var hasHistory: Bool { self != .abilities }

    var history: [String] {
        switch self {
        case .moves: return Storage.moveHistory
        case .items: return Storage.itemHistory
        case .abilities: return []
        }
    }

    func forget(_ name: String) {
        switch self {
        case .moves: Storage.forgetMove(name)
        case .items: Storage.forgetItem(name)
        case .abilities: break
        }
    }
}

struct EntrySearchSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let kind: EntryKind
    let role: Role

    @State private var query = ""
    @State private var mode = 0
    @State private var revision = 0
    @FocusState private var focused: Bool

    private struct Row: Identifiable {
        var id: String { name }
        let name: String
        let effect: String
        let usage: String?
    }

    private func numberText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private func searchText(_ name: String) -> String {
        let data = model.data
        switch kind {
        case .moves: return data.moveSearchText(name)
        case .abilities: return data.abilities[name].map { data.effectSearchText(kind: "abilities", $0) } ?? ""
        case .items: return data.items[name].map { data.effectSearchText(kind: "items", $0) } ?? ""
        }
    }

    private func effect(_ name: String) -> String {
        let data = model.data
        switch kind {
        case .moves: return data.moves[name]?.effect ?? ""
        case .abilities: return data.abilities[name]?.effect ?? ""
        case .items: return data.items[name]?.effect ?? ""
        }
    }

    private func exists(_ name: String) -> Bool {
        let data = model.data
        switch kind {
        case .moves: return data.moves[name] != nil
        case .abilities: return data.abilities[name] != nil
        case .items: return data.items[name] != nil
        }
    }

    private var rows: [Row] {
        _ = revision
        let data = model.data
        let name = model.side(role).name
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
        let ordered: [String]
        if mode == 1, kind.hasHistory {
            ordered = kind.history.filter(exists)
        } else {
            let names: [String]
            switch kind {
            case .moves: names = data.moveOrder
            case .abilities: names = data.abilityOrder
            case .items: names = data.itemOrder
            }
            let indices = names.indices.sorted { lhs, rhs in
                let left = rankOf[names[lhs]] ?? (usage.count + lhs)
                let right = rankOf[names[rhs]] ?? (usage.count + rhs)
                return left < right
            }
            ordered = indices.map { names[$0] }
        }
        let tiers = Search.rank(ordered.map(searchText), query: query)
        let order = Search.ordered(ordered.count, tiers: tiers) { ordered[$0] }
        return order.map { index in
            let entryName = ordered[index]
            return Row(name: entryName, effect: effect(entryName), usage: percent[entryName])
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
        VStack(spacing: 0) {
            SearchHeader(
                title: kind.title,
                modes: kind.hasHistory ? ["使用率", "履歴"] : [],
                mode: $mode,
                query: $query,
                focused: $focused,
                prompt: "\(kind.title)の名前を検索…",
                onSubmit: { if let first = list.first { select(first.name) } },
                onClose: { dismiss() }
            )
            List {
                ForEach(list) { row in
                    Button {
                        select(row.name)
                    } label: {
                        EntryRow(kind: kind, name: row.name, effect: row.effect, usage: row.usage, selected: row.name == selected)
                    }
                    .listRowBackground(row.name == selected ? Palette.accent.opacity(0.06) : Color.white)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if mode == 1, kind.hasHistory {
                            Button(role: .destructive) {
                                Haptics.play(.medium)
                                withAnimation {
                                    kind.forget(row.name)
                                    revision += 1
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                if !list.isEmpty {
                    UsageCredit()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list.isEmpty {
                    EmptyResult(text: mode == 1 && kind.history.isEmpty ? "履歴はまだありません" : "見つかりません")
                }
            }
        }
        .onChange(of: mode) { _, _ in Haptics.play(.selection) }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            focused = true
        }
        .presentationDragIndicator(.visible)
    }

    private func select(_ name: String) {
        focused = false
        switch kind {
        case .moves:
            Storage.rememberMove(name)
            model.selectMove(name)
        case .abilities:
            model.selectAbility(role, name)
        case .items:
            Storage.rememberItem(name)
            model.selectItem(role, name)
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
            if kind == .items {
                SpriteIcon(name: name, size: 30)
            }
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
                                TypeIcon(type: type, size: 42)
                                    .opacity(selected ? 1 : 0.3)
                                    .scaleEffect(selected ? 1 : 0.88)
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
            .navigationTitle("タイプ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("リセット") { model.resetTypes(role) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("天候").sectionTitle()
            EnvironmentSegments(kind: "weather", keys: EnvironmentInfo.weathers.map { $0.key }, selected: model.weather) { model.setWeather($0) }
                .padding(.bottom, 10)
            Text("フィールド").sectionTitle()
            EnvironmentSegments(kind: "field", keys: EnvironmentInfo.fields.map { $0.key }, selected: model.field) { model.setField($0) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(290)])
        .presentationDragIndicator(.visible)
    }
}

struct EnvironmentSegments: View {
    let kind: String
    let keys: [String]
    let selected: String
    let onSelect: (String) -> Void

    private func image(_ key: String) -> UIImage {
        let base = UIImage(named: "\(kind)_\(key)") ?? UIImage()
        let size = CGSize(width: 30, height: 30)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            base.draw(in: CGRect(origin: .zero, size: size))
        }
        let color = key == "none" ? UIColor.systemGray : UIColor(Palette.environment(key))
        return resized.withTintColor(color, renderingMode: .alwaysOriginal)
    }

    var body: some View {
        NativeSegmented(
            segments: keys.map { .image(image($0)) },
            selected: keys.firstIndex(of: selected) ?? 0,
            height: 56,
            allowsReselect: true
        ) { index in
            if keys.indices.contains(index) { onSelect(keys[index]) }
        }
        .frame(height: 56)
    }
}
