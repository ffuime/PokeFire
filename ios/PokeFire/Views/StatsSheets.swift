import SwiftUI

struct AbilityInfoSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Environment(\.dismiss) private var dismiss
    let role: Role
    let name: String
    @State private var headerHeight: CGFloat = 120

    private let cell: CGFloat = 64
    private let spacing: CGFloat = 8

    private var holders: [String] {
        let data = model.data
        let rank = { (name: String) in model.usage?.pokemons[name]?.rank ?? Int.max }
        return data.pokemonOrder.enumerated()
            .filter { data.pokemons[$0.element]?.abilities.contains(name) ?? false }
            .sorted { lhs, rhs in
                let left = rank(lhs.element)
                let right = rank(rhs.element)
                return left != right ? left < right : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    var body: some View {
        let list = holders
        let current = stats.side(role).name
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text(model.data.abilities[name]?.effect ?? "")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("このとくせいを持つポケモン")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.secondary)
                        .padding(.top, 4)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: cell, maximum: cell + 12), spacing: spacing)], alignment: .leading, spacing: spacing) {
                    ForEach(list, id: \.self) { pokemon in
                        Button {
                            stats.select(role, pokemon)
                            dismiss()
                        } label: {
                            SpriteView(name: pokemon, size: cell - 12)
                                .frame(width: cell, height: cell)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(pokemon == current ? Palette.accent.opacity(0.12) : Palette.background)
                                )
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
        .presentationDetents([.height(headerHeight + 28 + 16 + cell * 1.5 + spacing + 8), .large])
        .presentationDragIndicator(.visible)
    }
}

struct CategoryChip: View {
    let category: String

    static func color(_ category: String) -> Color {
        switch category {
        case "物理": return Color(hex: 0xE07845)
        case "特殊": return Color(hex: 0x4A90E2)
        default: return Color(hex: 0x8A8FA8)
        }
    }

    var body: some View {
        let color = Self.color(category)
        HStack(spacing: 5) {
            CategoryIcon(category: category, size: 15)
            Text(category)
                .font(.subheadline.weight(.bold))
                .fixedSize()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct InfoChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .foregroundStyle(Palette.secondary)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Palette.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MoveDetailContent: View {
    let info: MoveInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8) {
                TypeChip(type: info.type, height: 26)
                CategoryChip(category: info.category)
                Text("威力 \(info.powerText) / 命中 \(info.accuracyText) / PP \(info.ppText)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondary)
                    .fixedSize()
                    .frame(height: 26)
            }
            if !info.effect.isEmpty {
                Text(info.effect)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !info.target.isEmpty || !info.remarks.isEmpty {
                FlowLayout(spacing: 6) {
                    if !info.target.isEmpty {
                        InfoChip(text: info.target)
                    }
                    ForEach(info.remarks, id: \.self) { remark in
                        Text(remark)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                            .fixedSize()
                            .frame(height: 28)
                    }
                }
            }
        }
    }
}

struct MoveInfoSheet: View {
    let name: String
    @State private var height: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(name)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Palette.ink)
                if let info = StatsCatalog.shared.moveInfo(name) {
                    MoveDetailContent(info: info)
                } else {
                    Text("このわざの情報はありません")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .padding(.bottom, 20)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .presentationDetents([.height(height + 12), .large])
        .presentationDragIndicator(.visible)
    }
}

struct ItemInfoSheet: View {
    let name: String
    @State private var height: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SpriteIcon(name: name, size: 48)
                Text(name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.ink)
            }
            Text(StatsCatalog.shared.itemEffect(name))
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height + 12)])
        .presentationDragIndicator(.visible)
    }
}

struct LearnsetSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Environment(\.dismiss) private var dismiss
    let role: Role
    @State private var query = ""
    @State private var mode = 0
    @State private var expanded: Set<String> = []
    @State private var filter = MoveFilter()
    @State private var showFilter = false
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

    private var rows: [MoveInfo]? {
        guard let learnable = model.learnset(stats.side(role).name) else { return nil }
        let catalog = StatsCatalog.shared
        let set = Set(learnable)
        let infos = StatsCatalog.sortedMoves(catalog.moveOrder.filter { set.contains($0) }).compactMap { catalog.moveInfo($0) }.filter { filter.matches($0) }
        let tiers = Search.rank(infos.map(searchText), query: query)
        return Search.ordered(infos.count, tiers: tiers) { infos[$0].name }.map { infos[$0] }
    }

    var body: some View {
        let list = rows
        VStack(spacing: 0) {
            SearchHeader(
                title: "\(stats.side(role).name)の覚えるわざ",
                mode: $mode,
                query: $query,
                focused: $focused,
                prompt: "わざの名前・タイプを検索…",
                onSubmit: { focused = false },
                onClose: { dismiss() },
                filterActive: filter.isActive,
                onFilter: {
                    focused = false
                    Haptics.play(.light)
                    showFilter = true
                }
            )
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array((list ?? []).enumerated()), id: \.element.name) { index, info in
                        if query.isEmpty, index == 0 || (list ?? [])[index - 1].type != info.type {
                            HStack(spacing: 6) {
                                TypeIcon(type: info.type, size: 18)
                                Text(info.type)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Palette.secondary)
                            }
                            .padding(.top, index == 0 ? 4 : 14)
                            .padding(.leading, 6)
                        }
                        LearnsetRow(info: info, open: expanded.contains(info.name)) {
                            Haptics.play(.light)
                            withAnimation(.snappy(duration: 0.28)) {
                                if expanded.contains(info.name) {
                                    expanded.remove(info.name)
                                } else {
                                    expanded.insert(info.name)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if list == nil {
                    if model.learnsets == nil {
                        ProgressView()
                    } else {
                        EmptyResult(text: "覚えるわざのデータがありません")
                    }
                } else if list?.isEmpty ?? true {
                    EmptyResult(text: "見つかりません")
                }
            }
        }
        .sheet(isPresented: $showFilter) {
            MoveFilterSheet(filter: $filter)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct LearnsetRow: View {
    let info: MoveInfo
    let open: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                TypeIcon(type: info.type, size: 22)
                Text(info.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 4)
                CategoryIcon(category: info.category, size: 18)
                    .foregroundStyle(CategoryChip.color(info.category))
                Text(info.powerText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondary)
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .frame(height: 44)
            MoveDetailContent(info: info)
                .padding(.bottom, 12)
                .frame(maxHeight: open ? nil : 0, alignment: .top)
                .clipped()
                .opacity(open ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(open ? Palette.card : Color.clear)
                .shadow(color: open ? .black.opacity(0.08) : .clear, radius: 10, y: 3)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: toggle)
    }
}
