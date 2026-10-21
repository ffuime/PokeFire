import SwiftUI

enum BoxSheet: Identifiable {
    case species, stats, moves(Int), ability, item, nature, speedLine

    var id: String {
        switch self {
        case .species: return "species"
        case .stats: return "stats"
        case .moves(let index): return "moves-\(index)"
        case .ability: return "ability"
        case .item: return "item"
        case .nature: return "nature"
        case .speedLine: return "speed-line"
        }
    }
}

extension Color {
    static func washed(_ hex: UInt32, white: Double = 0.85) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return Color(.sRGB, red: r * (1 - white) + white, green: g * (1 - white) + white, blue: b * (1 - white) + white)
    }
}

struct BoxEditor: View {
    @Environment(BoxModel.self) private var box
    let ids: [UUID]
    let start: Int
    let teamID: UUID?
    @State private var index: Int?
    @State private var sheet: BoxSheet?

    var body: some View {
        let current = min(max(0, index ?? start), max(0, ids.count - 1))
        if ids.isEmpty || box.pokemon(ids[current]) == nil {
            EmptyResult(text: "ポケモンが見つかりません")
        } else {
            let id = ids[current]
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if ids.count > 1 {
                        VStack(spacing: 10) {
                            TabView(selection: Binding(get: { current }, set: { index = $0 })) {
                                ForEach(Array(ids.enumerated()), id: \.offset) { offset, member in
                                    if let entry = box.pokemon(member) {
                                        BoxCard(entry: entry) { part in
                                            if offset == current { sheet = part }
                                        }
                                        .padding(.horizontal, 16)
                                        .tag(offset)
                                    }
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .frame(height: BoxCard.height + 12)
                            HStack(spacing: 6) {
                                ForEach(ids.indices, id: \.self) { dot in
                                    Capsule()
                                        .fill(dot == current ? Palette.ink.opacity(0.7) : Palette.secondary.opacity(0.3))
                                        .frame(width: dot == current ? 16 : 6, height: 6)
                                }
                            }
                            .animation(.snappy(duration: 0.25), value: current)
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: current) { _, _ in Haptics.play(.selection) }
                    } else if let entry = box.pokemon(id) {
                        BoxCard(entry: entry) { sheet = $0 }
                            .padding(.horizontal, 16)
                    }
                    BoxEditorBody(id: id, sheet: $sheet)
                        .id(id)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .navigationTitle(box.pokemon(id)?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct BoxCard: View {
    let entry: BoxPokemon
    var onTap: ((BoxSheet) -> Void)?

    static let height: CGFloat = 176

    private func tap(_ part: BoxSheet) {
        guard let onTap else { return }
        Haptics.play(.light)
        onTap(part)
    }

    var body: some View {
        let types = entry.pokemon?.types ?? []
        let first = Palette.types[types.first ?? ""]?.color ?? 0x999999
        let second = Palette.types[types.count > 1 ? types[1] : types.first ?? ""]?.color ?? first
        ZStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(types, id: \.self) { TypeIcon(type: $0, size: 18) }
                    Text(entry.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .contentShape(Rectangle())
                .onTapGesture { tap(.species) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(entry.ability.isEmpty ? "とくせい" : entry.ability)
                .font(.footnote.weight(.bold))
                .opacity(entry.ability.isEmpty ? 0.5 : 1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentShape(Rectangle())
                .onTapGesture { tap(.ability) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<4, id: \.self) { slot in
                    let move = slot < entry.moves.count ? entry.moves[slot] : ""
                    HStack(spacing: 5) {
                        if let info = StatsCatalog.shared.moveInfo(move) {
                            TypeIcon(type: info.type, size: 16)
                        } else {
                            Text("?")
                                .font(.system(size: 11, weight: .heavy))
                                .frame(width: 16, height: 16)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 3))
                        }
                        Text(move.isEmpty ? "わざを入力" : move)
                            .font(.caption.weight(.semibold))
                            .opacity(move.isEmpty ? 0.5 : 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: 130, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { tap(.moves(slot)) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            HStack(spacing: 6) {
                column(StatKey.baseKeys.map { Text($0.letter) }, alignment: .center, width: 14)
                column(StatKey.baseKeys.map { Text("\(entry.real($0))") }, alignment: .trailing, width: 30)
                column(StatKey.baseKeys.map { pointText($0) }, alignment: .trailing, width: 34)
            }
            .contentShape(Rectangle())
            .onTapGesture { tap(.stats) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            SpriteView(name: entry.name, size: 92)
                .frame(width: 92, height: 92)
                .contentShape(Rectangle())
                .onTapGesture { tap(.species) }
                .overlay(alignment: .bottomTrailing) {
                    if !entry.item.isEmpty {
                        SpriteIcon(name: entry.item, size: 30)
                            .onTapGesture { tap(.item) }
                    }
                }
                .offset(x: -4, y: 6)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(height: Self.height)
        .background {
            ZStack {
                LinearGradient(colors: [Color.washed(first, white: 0.7), Color.washed(second, white: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                CardGlints(seed: entry.id.hashValue)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
    }

    private func pointText(_ key: StatKey) -> Text {
        let points = entry.point(key)
        let nature = entry.nature(key)
        if points == 0, nature == 10 { return Text("-") }
        switch nature {
        case 11: return Text("+\(points)↑").foregroundStyle(Palette.rankUp)
        case 9: return Text("+\(points)↓").foregroundStyle(Palette.rankDown)
        default: return Text("+\(points)")
        }
    }

    private func column(_ items: [Text], alignment: HorizontalAlignment, width: CGFloat) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            ForEach(items.indices, id: \.self) { index in
                items[index]
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(height: 17)
            }
        }
        .frame(width: width, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

struct BoxEditorBody: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    let id: UUID
    @Binding var sheet: BoxSheet?
    @State private var showForms = false
    @State private var formsOpenCount = 0
    @State private var spin = 0

    var body: some View {
        if let entry = box.pokemon(id) {
            content(entry)
                .sheet(item: $sheet) { item in
                    sheetContent(item, entry)
                }
        }
    }

    @ViewBuilder
    private func content(_ entry: BoxPokemon) -> some View {
        let forms = model.data.otherForms(of: entry.name)
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                ModeSprite(name: entry.name, hasForms: !forms.isEmpty, spin: spin) {
                    guard !forms.isEmpty else {
                        sheet = .species
                        return
                    }
                    spin += 1
                    Haptics.play(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        showForms.toggle()
                        if showForms { formsOpenCount += 1 }
                    }
                } onLongPress: {}
                ZStack(alignment: .leading) {
                    if showForms, !forms.isEmpty {
                        FormsStrip(forms: forms, openCount: formsOpenCount) { name in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { showForms = false }
                            box.update(id) { $0.name = name }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            PokemonNameButton(name: entry.name) {
                                Haptics.play(.light)
                                sheet = .species
                            }
                            TextField("ニックネーム（任意）", text: Binding(
                                get: { box.pokemon(id)?.nickname ?? "" },
                                set: { value in box.update(id) { $0.nickname = value } }
                            ))
                            .font(.subheadline)
                            .padding(.horizontal, 4)
                            .frame(height: 30)
                            HStack(spacing: 4) {
                                ForEach(entry.pokemon?.types ?? [], id: \.self) { TypeBadge(type: $0) }
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }

            BoxBaseRow(entry: entry) {
                Haptics.play(.light)
                sheet = .stats
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("わざ").sectionTitle()
                List {
                    ForEach(Array(entry.moves.prefix(4).enumerated()), id: \.offset) { slot, move in
                        BoxMoveButton(move: move) {
                            Haptics.play(.light)
                            sheet = .moves(slot)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        Haptics.play(.medium)
                        box.update(id) { $0.moves.move(fromOffsets: from, toOffset: to) }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: 4 * 54)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("とくせい").sectionTitle()
                SelectButton(text: entry.ability) {
                    Haptics.play(.light)
                    sheet = .ability
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("もちもの").sectionTitle()
                SelectButton(text: entry.item, sprite: entry.item.isEmpty ? nil : entry.item) {
                    Haptics.play(.light)
                    sheet = .item
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("能力補正").sectionTitle()
                SelectButton(text: entry.natureName, placeholder: "なし") {
                    Haptics.play(.light)
                    sheet = .nature
                }
            }

            BoxCalcHandoff(entry: entry)
        }
        .onChange(of: entry.name) { _, _ in showForms = false }
    }

    @ViewBuilder
    private func sheetContent(_ item: BoxSheet, _ entry: BoxPokemon) -> some View {
        switch item {
        case .species:
            PokemonPicker(role: .attacker, currentName: entry.name) { name in
                box.update(id) { $0.name = name }
            }
        case .stats:
            BoxStatsSheet(id: id) {
                sheet = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    sheet = .speedLine
                }
            }
        case .moves(let slot):
            BoxMoveSheet(id: id, focus: slot)
        case .ability:
            EntrySearchSheet(kind: .abilities, role: .attacker, pokemonName: entry.name, currentValue: entry.ability) { name in
                box.update(id) { $0.ability = name == "なし" ? "" : name }
            }
        case .item:
            EntrySearchSheet(kind: .items, role: .attacker, pokemonName: entry.name, currentValue: entry.item) { name in
                box.update(id) { $0.item = name == "なし" ? "" : name }
            }
        case .nature:
            NatureSheet(id: id)
        case .speedLine:
            SpeedLineSheet(currentName: entry.name, currentSpeed: entry.real(.s)) { line in
                guard line.name == entry.name else { return false }
                box.setPoint(id, .s, line.tier.points)
                box.setNature(id, .s, line.tier.nature, usage: model.usage?.pokemons[entry.name]?.natures ?? [])
                return true
            }
        }
    }
}

struct BoxBaseRow: View {
    let entry: BoxPokemon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                ForEach(StatKey.baseKeys, id: \.self) { key in
                    VStack(spacing: 1) {
                        Text(key.letter)
                            .font(.caption2.weight(.heavy))
                            .opacity(0.7)
                        NumberText(entry.base[key])
                            .font(.subheadline.weight(.bold))
                        Text(realText(key))
                            .font(.caption2.weight(.heavy))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(Palette.stat(key).opacity(0.55))
                            .contentTransition(.numericText(value: Double(entry.real(key))))
                            .animation(.snappy(duration: 0.25), value: realText(key))
                    }
                    .foregroundStyle(Palette.stat(key))
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("能力ポイントを調整")
    }

    private func realText(_ key: StatKey) -> String {
        let points = entry.point(key)
        let nature = entry.nature(key)
        let arrow = nature == 11 ? "↑" : nature == 9 ? "↓" : ""
        guard points > 0 || !arrow.isEmpty else { return "\(entry.real(key))" }
        return "\(entry.real(key))(+\(points)\(arrow))"
    }
}

struct BoxMoveButton: View {
    let move: String
    let action: () -> Void

    var body: some View {
        let info = StatsCatalog.shared.moveInfo(move)
        Button(action: action) {
            HStack(spacing: 10) {
                if let info {
                    TypeIcon(type: info.type, size: 22)
                } else {
                    Icon(name: "search", size: 18)
                        .foregroundStyle(Color(hex: 0xAAAAAA))
                        .frame(width: 22)
                }
                Text(move.isEmpty ? "わざを選択" : move)
                    .foregroundStyle(move.isEmpty ? Palette.secondary : Color.black)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let info {
                    CategoryIcon(category: info.category, size: 16)
                        .foregroundStyle(CategoryChip.color(info.category))
                    Text(info.powerText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(UnevenBox().fill(Color.white))
            .overlay(UnevenBox().stroke(Color(hex: 0xDDDDDD), lineWidth: 1))
            .contentShape(UnevenBox())
        }
        .buttonStyle(PressableStyle())
    }
}

struct BoxCalcHandoff: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let entry: BoxPokemon

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("このポケモンでダメ計する").sectionTitle()
            HStack(spacing: 8) {
                ForEach(Role.allCases, id: \.self) { target in
                    let tint = target == .attacker ? Palette.attack : Palette.accent
                    Button {
                        Haptics.play(.medium)
                        model.applyBox(entry, to: target)
                        withAnimation(.easeInOut(duration: 0.35)) {
                            stats.exit(page: target)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Icon(name: target == .attacker ? "tab_attack" : "shield", size: 17)
                            Text(target.title)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(UnevenBox().fill(tint.opacity(0.1)))
                        .contentShape(UnevenBox())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

struct BoxStatsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    let openSpeedLine: () -> Void

    private func label(_ points: [Int]) -> String {
        let letters = ["H", "A", "B", "C", "D", "S"]
        let parts = points.enumerated().compactMap { index, value in
            value > 0 && index < letters.count ? "\(letters[index])\(value)" : nil
        }
        return parts.isEmpty ? "無振り" : parts.joined(separator: "-")
    }

    var body: some View {
        if let entry = box.pokemon(id) {
            let spreads = Array((model.usage?.pokemons[entry.name]?.spreads ?? []).prefix(3))
            let natures = model.usage?.pokemons[entry.name]?.natures ?? []
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        if !spreads.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(Array(spreads.enumerated()), id: \.offset) { _, spread in
                                    Button {
                                        Haptics.play(.light)
                                        withAnimation(.snappy(duration: 0.25)) { box.applySpread(id, spread.points) }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(label(spread.points))
                                                .font(.caption.weight(.heavy))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                            Text("\(Format.fixed1(spread.pct))%")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Palette.secondary)
                                        }
                                        .foregroundStyle(Palette.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(hex: 0xDDDDDD), lineWidth: 1))
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        ForEach(StatKey.baseKeys, id: \.self) { key in
                            statEditor(entry, key, natures: natures)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
                .background(Palette.background)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        let remain = BoxPokemon.pointLimit - entry.totalPoints
                        HStack(spacing: 6) {
                            Text("能力ポイント")
                                .font(.headline)
                            Text("残り")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.secondary)
                            Text("\(remain)")
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(remain == 0 ? Palette.secondary : Palette.accent)
                                .contentTransition(.numericText(value: Double(remain)))
                                .animation(.snappy(duration: 0.25), value: remain)
                        }
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

    private func statEditor(_ entry: BoxPokemon, _ key: StatKey, natures: [NatureUsage]) -> some View {
        let color = Palette.stat(key)
        let cap = min(32, BoxPokemon.pointLimit - (entry.totalPoints - entry.point(key)))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(key.title).sectionTitle()
                Spacer()
                NumberText(entry.real(key))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
            }
            HStack(spacing: 12) {
                SegmentBar(count: 32, value: entry.point(key), color: color) { value in
                    withAnimation(.snappy(duration: 0.25)) { box.setPoint(id, key, min(value, cap)) }
                }
                .frame(height: 26)
                NumberText(entry.point(key))
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, alignment: .trailing)
            }
            if key.hasNature {
                HStack {
                    NatureControl(nature: entry.nature(key)) { value in
                        withAnimation(.snappy(duration: 0.25)) {
                            box.setNature(id, key, value, usage: natures)
                        }
                    }
                    Spacer()
                    if key == .s {
                        Button {
                            Haptics.play(.light)
                            openSpeedLine()
                        } label: {
                            Text("すばやさライン")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Palette.stat(.s))
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    }
                }
            }
        }
    }
}

struct NatureSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    var body: some View {
        let entry = box.pokemon(id)
        let usage = model.usage?.pokemons[entry?.name ?? ""]?.natures ?? []
        let used = usage.compactMap { item in item.name.map { ($0, item.pct) } }
        let usedNames = Set(used.map(\.0))
        let others = NatureTable.all.filter { !usedNames.contains($0.name) }
        NavigationStack {
            List {
                if !used.isEmpty {
                    Section("使用率") {
                        ForEach(used, id: \.0) { name, pct in
                            row(name, pct: pct, selected: entry?.natureName == name)
                        }
                    }
                }
                Section("その他") {
                    ForEach(others, id: \.name) { info in
                        row(info.name, pct: nil, selected: entry?.natureName == info.name)
                    }
                }
            }
            .navigationTitle("能力補正")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ name: String, pct: Double?, selected: Bool) -> some View {
        let info = NatureTable.named(name)
        return Button {
            Haptics.play(.light)
            box.setNatureNamed(id, name)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selected ? Palette.accent : Palette.ink)
                    if let info {
                        NatureCaption(nature: NatureUsage(name: name, pct: 0, up: info.up, down: info.down))
                            .font(.caption.weight(.bold))
                    }
                }
                Spacer()
                if let pct {
                    Text("\(Format.fixed1(pct))%")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct BoxMoveSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State var focus: Int
    @State private var query = ""
    @State private var mode = 0
    @FocusState private var focused: Bool

    private struct MoveGroup: Identifiable {
        let id: String
        let rows: [MoveInfo]
    }

    private func searchText(_ info: MoveInfo) -> String {
        Search.tiers([
            .text(Search.textOf(kind: "moves", name: info.name)),
            .list([info.type]),
            .list([info.category, Search.categoryReadings[info.category] ?? ""]),
            .text("=\(info.powerText)"),
            .list([info.effect]),
        ])
    }

    private func groups(_ entry: BoxPokemon) -> [MoveGroup] {
        let catalog = StatsCatalog.shared
        let usage = (model.usage?.pokemons[entry.name]?.moves ?? []).compactMap(\.name).filter { catalog.moves[$0] != nil }
        var lists: [(String, [String])] = [("使用率", usage)]
        if let learnable = model.learnset(entry.name) {
            let set = Set(learnable)
            lists.append(("覚えるわざ", catalog.moveOrder.filter { set.contains($0) }))
            lists.append(("その他", catalog.moveOrder.filter { !set.contains($0) }))
        } else {
            let set = Set(usage)
            lists.append(("その他", catalog.moveOrder.filter { !set.contains($0) }))
        }
        return lists.compactMap { title, names in
            let infos = names.compactMap { catalog.moveInfo($0) }
            let tiers = Search.rank(infos.map(searchText), query: query)
            let rows = Search.ordered(infos.count, tiers: tiers) { infos[$0].name }.map { infos[$0] }
            return rows.isEmpty ? nil : MoveGroup(id: title, rows: rows)
        }
    }

    private func pick(_ name: String, _ entry: BoxPokemon) {
        Haptics.play(.light)
        box.update(id) { item in
            while item.moves.count < 4 { item.moves.append("") }
            if let existing = item.moves.firstIndex(of: name), existing != focus { item.moves[existing] = "" }
            item.moves[focus] = name
        }
        let moves: [String] = box.pokemon(id)?.moves ?? []
        let empty: [Int] = moves.indices.filter { moves[$0].isEmpty }
        let after: Int? = empty.first { $0 > focus }
        if let next = after ?? empty.first {
            withAnimation(.snappy(duration: 0.25)) { focus = next }
        } else {
            dismiss()
        }
    }

    private func clear(_ slot: Int) {
        Haptics.play(.medium)
        box.update(id) { item in
            if slot < item.moves.count { item.moves[slot] = "" }
        }
        withAnimation(.snappy(duration: 0.25)) { focus = slot }
    }

    var body: some View {
        if let entry = box.pokemon(id) {
            let sections = groups(entry)
            let usage = Dictionary((model.usage?.pokemons[entry.name]?.moves ?? []).compactMap { pair in pair.name.map { ($0, pair.pct) } }, uniquingKeysWith: { first, _ in first })
            VStack(spacing: 0) {
                HStack {
                    Text("わざ")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        CloseButtonLabel()
                            .foregroundStyle(Palette.ink)
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel("閉じる")
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 6)
                List {
                    ForEach(Array(entry.moves.prefix(4).enumerated()), id: \.offset) { slot, _ in
                        slotRow(slot, entry)
                            .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { from, to in
                        Haptics.play(.medium)
                        let moved = from.first.map { $0 == focus } ?? false
                        box.update(id) { $0.moves.move(fromOffsets: from, toOffset: to) }
                        if moved { focus = to > (from.first ?? 0) ? to - 1 : to }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: 4 * 46)
                HStack(spacing: 8) {
                    Icon(name: "search", size: 17)
                        .foregroundStyle(Palette.secondary)
                    TextField("わざの名前を検索…", text: $query)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { if let first = sections.first?.rows.first { pick(first.name, entry) } }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Palette.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color(hex: 0xEEEEF1), in: Capsule())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                List {
                    ForEach(sections) { group in
                        Section {
                            ForEach(group.rows, id: \.name) { info in
                                Button {
                                    pick(info.name, entry)
                                } label: {
                                    HStack(spacing: 10) {
                                        TypeIcon(type: info.type, size: 22)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(info.name)
                                                    .font(.body.weight(.semibold))
                                                    .foregroundStyle(entry.moves.contains(info.name) ? Palette.accent : Palette.ink)
                                                if let pct = usage[info.name] {
                                                    Text("\(Format.fixed1(pct))%")
                                                        .font(.caption.weight(.bold))
                                                        .monospacedDigit()
                                                        .foregroundStyle(Palette.accent)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 1)
                                                        .background(Palette.accent.opacity(0.1), in: Capsule())
                                                }
                                            }
                                            if !info.effect.isEmpty {
                                                Text(info.effect)
                                                    .font(.caption)
                                                    .foregroundStyle(Palette.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer(minLength: 4)
                                        CategoryIcon(category: info.category, size: 18)
                                            .foregroundStyle(CategoryChip.color(info.category))
                                        Text(info.powerText)
                                            .font(.subheadline.weight(.bold))
                                            .monospacedDigit()
                                            .foregroundStyle(Palette.secondary)
                                            .frame(minWidth: 28, alignment: .trailing)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(group.id)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Palette.secondary)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.immediately)
            }
            .presentationDragIndicator(.visible)
        }
    }

    private func slotRow(_ slot: Int, _ entry: BoxPokemon) -> some View {
        let move = slot < entry.moves.count ? entry.moves[slot] : ""
        let active = focus == slot
        let info = StatsCatalog.shared.moveInfo(move)
        return HStack(spacing: 10) {
            Text("\(slot + 1)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(active ? Color.white : Palette.accent)
                .frame(width: 22, height: 22)
                .background(Circle().fill(active ? Palette.accent : Palette.accent.opacity(0.1)))
            if let info {
                TypeIcon(type: info.type, size: 18)
            }
            Text(move.isEmpty ? "わざを選択" : move)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(move.isEmpty ? Palette.secondary : Palette.ink)
            Spacer()
            if !move.isEmpty {
                Button {
                    clear(slot)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("わざを外す")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(active ? Color.white : Palette.background)
                .shadow(color: active ? Palette.accent.opacity(0.18) : .clear, radius: 8, y: 2)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(active ? Palette.accent.opacity(0.5) : .clear, lineWidth: 1))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.play(.selection)
            withAnimation(.snappy(duration: 0.25)) { focus = slot }
        }
    }
}

struct BoxImportSheet: View {
    @Environment(BoxModel.self) private var box
    @Environment(\.dismiss) private var dismiss
    let onPick: (BoxPokemon) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(box.pokemons.sorted { $0.updated > $1.updated }) { entry in
                    Button {
                        onPick(entry)
                        dismiss()
                    } label: {
                        BoxPokemonRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if box.pokemons.isEmpty {
                    EmptyResult(text: "PokéBox にポケモンがいません")
                }
            }
            .navigationTitle("PokéBoxから")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct CardGlints: View {
    let seed: Int

    private struct Glint {
        let radius: CGFloat
        let opacity: Double
        let speedX: Double
        let speedY: Double
        let phaseX: Double
        let phaseY: Double
    }

    private var glints: [Glint] {
        var state = UInt64(bitPattern: Int64(seed)) | 1
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        return (0..<5).map { _ in
            Glint(
                radius: 22 + next() * 26,
                opacity: 0.35 + next() * 0.35,
                speedX: 0.08 + next() * 0.14,
                speedY: 0.07 + next() * 0.13,
                phaseX: next() * .pi * 2,
                phaseY: next() * .pi * 2
            )
        }
    }

    var body: some View {
        let list = glints
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { graphics, size in
                graphics.addFilter(.blur(radius: 16))
                for glint in list {
                    let x = (0.5 + 0.45 * sin(time * glint.speedX + glint.phaseX) * cos(time * glint.speedX * 0.37 + glint.phaseY)) * size.width
                    let y = (0.5 + 0.45 * sin(time * glint.speedY + glint.phaseY) * cos(time * glint.speedY * 0.53 + glint.phaseX)) * size.height
                    let pulse = 0.75 + 0.25 * sin(time * (glint.speedX + glint.speedY) * 2 + glint.phaseX)
                    let rect = CGRect(x: x - glint.radius, y: y - glint.radius, width: glint.radius * 2, height: glint.radius * 2)
                    graphics.fill(Path(ellipseIn: rect), with: .color(.white.opacity(glint.opacity * pulse)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
