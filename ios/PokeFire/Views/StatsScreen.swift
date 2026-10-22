import SwiftUI

struct StatsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let role: Role
    let present: (ActiveSheet) -> Void
    @State private var editing: StatKey?

    var body: some View {
        let side = stats.side(role)
        let entry = model.usage?.pokemons[side.name]
        ScrollView {
            PullTopMarker()
            VStack(alignment: .leading, spacing: 26) {
                StatsHeader(role: role, present: present)
                VStack(alignment: .trailing, spacing: 10) {
                    StatsBaseRow(role: role, editing: $editing, present: present)
                    AddToBoxButton(role: role)
                }
                .zIndex(2)
                StatsAbilityRow(role: role, present: present)
                TypeChartCard(role: role)
                VStack(alignment: .leading, spacing: 10) {
                    Text("バトルデータ").sectionTitle()
                    SeasonPicker()
                    if let entry, !entry.moves.isEmpty {
                        MoveUsageSection(pairs: Array(entry.moves.prefix(10)), present: present)
                    } else if model.usage != nil {
                        Text("このシーズンのデータはありません")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                    }
                }
                if entry != nil {
                    UsageCarousel(role: role, present: present)
                }
                if let entry, !entry.spreads.isEmpty {
                    SpreadSection(role: role, spreads: entry.spreads)
                }
                Button {
                    Haptics.play(.light)
                    present(.learnset(role))
                } label: {
                    HStack(spacing: 8) {
                        Icon(name: "search", size: 17)
                        Text("覚えるわざを見る")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(UnevenBox().fill(Palette.field))
                    .contentShape(UnevenBox())
                }
                .buttonStyle(PressableStyle())
                CalcHandoff(role: role)
                UsageCredit()
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                PanelShape(role: role)
                    .fill(Palette.card)
                    .shadow(color: .black.opacity(0.1), radius: 18, y: 4)
            }
            .padding(.leading, role == .attacker ? 0 : 16)
            .padding(.trailing, role == .attacker ? 16 : 0)
            .padding(.top, 6)
            .padding(.bottom, 24)
            .animation(.snappy(duration: 0.3), value: stats.chartCollapsed)
        }
        .scrollIndicators(.hidden)
        .modeSwitchPull(label: "PokéFire", icon: "tab_attack", tint: Palette.attack, distance: 52) {
            withAnimation(.easeInOut(duration: 0.35)) { stats.exit() }
        }
        .onChange(of: side.name) { _, _ in editing = nil }
    }
}

struct StatsHeader: View {
    @Environment(StatsModel.self) private var stats
    let role: Role
    let present: (ActiveSheet) -> Void
    @State private var showForms = false
    @State private var formsOpenCount = 0
    @State private var spin = 0

    var body: some View {
        let side = stats.side(role)
        let forms = GameData.shared.otherForms(of: side.name)
        HStack(spacing: 12) {
            ModeSprite(name: side.name, hasForms: true, spin: spin, shiny: side.isShiny) {
                spin += 1
                Haptics.play(.light)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    showForms.toggle()
                    if showForms { formsOpenCount += 1 }
                }
            } onLongPress: {
                withAnimation(.easeInOut(duration: 0.35)) { stats.exit() }
            }

            ZStack(alignment: .leading) {
                if showForms {
                    FormsStrip(forms: forms, openCount: formsOpenCount, onBox: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            showForms = false
                        }
                        present(.boxImport(role))
                    }) { name in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            showForms = false
                        }
                        stats.select(role, name)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        PokemonNameButton(name: side.name) {
                            Haptics.play(.light)
                            present(.statsPokemon(role))
                        }
                        ScrollView(.horizontal) {
                            HStack(spacing: 4) {
                                ForEach(side.pokemon?.types ?? [], id: \.self) { type in
                                    TypeBadge(type: type)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        }
        .onChange(of: side.name) { _, _ in showForms = false }
    }
}

struct ModeSprite: View {
    let name: String
    let hasForms: Bool
    let spin: Int
    var shiny = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    @State private var pressing = false
    @State private var hold: CGFloat = 0
    @State private var token = 0

    private let duration = 0.45

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(pressing ? 0.08 : 0))
                Circle()
                    .trim(from: 0, to: hold)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(hold > 0 ? 1 : 0)
                SpriteView(name: name, size: 84, shiny: shiny)
            }
            .frame(width: 92, height: 92)
            if hasForms {
                Icon(name: "forms", size: 15)
                    .foregroundStyle(Palette.accent)
                    .rotationEffect(.degrees(Double(spin) * -360))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: spin)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.card).shadow(color: .black.opacity(0.15), radius: 6, y: 1))
            }
        }
        .scaleEffect(pressing ? 0.92 : 1)
        .animation(.snappy(duration: 0.2), value: pressing)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: duration) {
            guard let onLongPress else { return }
            Haptics.play(.heavy)
            onLongPress()
            withAnimation(.easeOut(duration: 0.2)) { hold = 0 }
        } onPressingChanged: { value in
            guard onLongPress != nil else { return }
            pressing = value
            token += 1
            let current = token
            if value {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard pressing, current == token else { return }
                    hold = 0
                    withAnimation(.linear(duration: duration - 0.15)) { hold = 1 }
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { hold = 0 }
            }
        }
        .accessibilityLabel(hasForms ? "ほかの姿" : "ポケモンを選ぶ")
        .accessibilityHint("長押しでモードを切り替え")
        .accessibilityAddTraits(.isButton)
    }
}

struct PokemonNameButton: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                Icon(name: "chevron_down", size: 16)
                    .foregroundStyle(Color(hex: 0xAAAAAA))
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background {
                ZStack {
                    UnevenBox(strong: 28, weak: 6).fill(.ultraThinMaterial)
                    UnevenBox(strong: 28, weak: 6).fill(Color.white.opacity(0.6))
                }
            }
            .overlay(UnevenBox(strong: 28, weak: 6).stroke(Palette.separator, lineWidth: 1))
            .contentShape(UnevenBox(strong: 28, weak: 6))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("ポケモン \(name)")
    }
}

struct StatsBaseRow: View {
    @Environment(StatsModel.self) private var stats
    let role: Role
    @Binding var editing: StatKey?
    let present: (ActiveSheet) -> Void
    @State private var height: CGFloat = 52

    private func tap(_ key: StatKey) {
        Haptics.play(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            editing = editing == key ? nil : key
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { editing = nil }
    }

    private func realText(_ side: StatsSide, _ key: StatKey) -> String {
        let points = side.point(key)
        let nature = side.nature(key)
        let arrow = nature == 11 ? "↑" : nature == 9 ? "↓" : ""
        guard points > 0 || !arrow.isEmpty else { return "\(side.real(key))" }
        return "\(side.real(key))(+\(points)\(arrow))"
    }

    var body: some View {
        let side = stats.side(role)
        HStack(spacing: 0) {
            ForEach(StatKey.baseKeys, id: \.self) { key in
                let active = editing == key
                VStack(spacing: 1) {
                    Text(key.letter)
                        .font(.caption2.weight(.heavy))
                        .opacity(0.7)
                    NumberText(side.base[key])
                        .font(.subheadline.weight(.bold))
                    Text(realText(side, key))
                        .font(.caption2.weight(.heavy))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(Palette.stat(key).opacity(0.55))
                        .contentTransition(.numericText(value: Double(side.real(key))))
                        .animation(.snappy(duration: 0.25), value: realText(side, key))
                }
                .foregroundStyle(Palette.stat(key))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(active ? Palette.stat(key).opacity(0.1) : Color.clear))
                .contentShape(Rectangle())
                .onTapGesture { tap(key) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .overlay(alignment: .top) {
            if let key = editing {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    ZStack(alignment: .top) {
                        Color.black.opacity(0.0001)
                            .frame(width: width + 400, height: 3000)
                            .offset(y: -1000)
                            .contentShape(Rectangle())
                            .onTapGesture { close() }
                        HStack(spacing: 0) {
                            ForEach(StatKey.baseKeys, id: \.self) { column in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { tap(column) }
                            }
                        }
                        .frame(width: width, height: height)
                        StatsBubble(role: role, key: key, close: close, present: present)
                            .frame(width: width)
                            .offset(y: height + 14)
                            .transition(.scale(scale: 0.6, anchor: UnitPoint(x: StatsBubble.ratio(key), y: 0)).combined(with: .opacity))
                    }
                    .frame(width: width, alignment: .top)
                }
            }
        }
    }
}

struct StatsStatFields: View {
    @Environment(StatsModel.self) private var stats
    let role: Role
    let key: StatKey

    var body: some View {
        let side = stats.side(role)
        let color = Palette.stat(key)
        let shown = key == .s ? stats.boostedSpeed(role) : side.real(key)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(key.title).sectionTitle()
                Spacer()
                NumberText(shown)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(shown != side.real(key) ? Palette.boosted : color)
            }
            HStack(spacing: 12) {
                SegmentBar(count: 32, value: side.point(key), color: color) { value in
                    withAnimation(.snappy(duration: 0.25)) { stats.setPoints(role, key, value) }
                }
                NumberText(side.point(key))
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, alignment: .trailing)
            }
            if key.hasNature {
                NatureControl(nature: side.nature(key)) { value in
                    withAnimation(.snappy(duration: 0.25)) { stats.setNature(role, key, value) }
                }
            }
            if key == .s {
                let boost = stats.speedBoost(role)
                let abilities = (side.pokemon?.abilities ?? []).filter { Calc.speedAbilities[$0] != nil }
                HStack(spacing: 8) {
                    ForEach(abilities, id: \.self) { ability in
                        ToggleChip(title: ability, isOn: boost.ability == ability) {
                            withAnimation(.snappy(duration: 0.25)) { stats.toggleSpeedAbility(role, ability) }
                        }
                        .fixedSize()
                    }
                    Spacer(minLength: 0)
                    RankControl(
                        rank: boost.rank,
                        onStep: { step in withAnimation(.snappy(duration: 0.25)) { stats.setSpeedRank(role, boost.rank + step) } },
                        onSet: { value in withAnimation(.snappy(duration: 0.25)) { stats.setSpeedRank(role, value) } }
                    )
                }
            }
        }
    }
}

struct SeasonPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let current = model.season ?? model.usage?.season ?? model.seasons.first?.name ?? ""
        let label = model.seasons.first { $0.name == current }?.label ?? current
        Menu {
            Picker("シーズン", selection: Binding(get: { current }, set: { model.selectSeason($0) })) {
                ForEach(model.seasons) { season in
                    Text(season.label).tag(season.name)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(label.isEmpty ? "シーズン" : label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if model.loadingSeason {
                    ProgressView().controlSize(.small)
                } else {
                    Icon(name: "chevron_down", size: 14)
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(UnevenBox(strong: 16, weak: 5).fill(Palette.card))
            .overlay(UnevenBox(strong: 16, weak: 5).stroke(Palette.separator, lineWidth: 1))
        }
        .disabled(model.seasons.isEmpty)
    }
}

struct AddToBoxButton: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Environment(BoxModel.self) private var box
    let role: Role

    var body: some View {
        Button {
            Haptics.play(.success)
            box.addFromStats(stats.side(role), usage: model.usage)
            NotificationCenter.default.post(name: .pokefireToast, object: "PokéBoxに追加しました")
        } label: {
            Label("PokéBoxに追加", systemImage: "cube.box")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Palette.accent.opacity(0.08), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct StatsBubble: View {
    let role: Role
    let key: StatKey
    let close: () -> Void
    let present: (ActiveSheet) -> Void

    static func ratio(_ key: StatKey) -> CGFloat {
        let index = StatKey.baseKeys.firstIndex(of: key) ?? 0
        return (CGFloat(index) + 0.5) / CGFloat(StatKey.baseKeys.count)
    }

    var body: some View {
        let tailRatio = Self.ratio(key)
        VStack(alignment: .leading, spacing: 14) {
            StatsStatFields(role: role, key: key)
            if key == .s {
                HStack(spacing: 8) {
                    Button {
                        Haptics.play(.light)
                        close()
                        present(.speedLine(role))
                    } label: {
                        Text("すばやさライン")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.stat(.s))
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    Spacer()
                    Button {
                        Haptics.play(.light)
                        close()
                        present(.statsSpeed)
                    } label: {
                        Icon(name: "speed", size: 19)
                            .foregroundStyle(Palette.rankDown)
                            .frame(width: 38, height: 38)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel("すばやさ比較")
                }
            }
        }
        .padding(18)
        .background(
            StatsBubbleShape(tailRatio: tailRatio)
                .fill(Palette.card)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: key)
        )
        .keyframeAnimator(initialValue: CGFloat(1), trigger: key) { content, scale in
            content.scaleEffect(scale, anchor: UnitPoint(x: tailRatio, y: 0))
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(CGFloat(0.93), duration: 0.12)
                SpringKeyframe(CGFloat(1), duration: 0.35, spring: .bouncy)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

struct StatsBubbleShape: Shape {
    var tailRatio: CGFloat

    var animatableData: CGFloat {
        get { tailRatio }
        set { tailRatio = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = RoundedRectangle(cornerRadius: 26, style: .continuous).path(in: rect)
        let x = min(rect.maxX - 30, max(rect.minX + 30, rect.minX + rect.width * tailRatio))
        var tail = Path()
        tail.move(to: CGPoint(x: x - 12, y: rect.minY + 1))
        tail.addLine(to: CGPoint(x: x, y: rect.minY - 12))
        tail.addLine(to: CGPoint(x: x + 12, y: rect.minY + 1))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

struct StatsAbilityRow: View {
    @Environment(StatsModel.self) private var stats
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        let abilities = stats.side(role).pokemon?.abilities ?? []
        VStack(alignment: .leading, spacing: 10) {
            Text("とくせい").sectionTitle()
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(abilities, id: \.self) { name in
                        Button {
                            Haptics.play(.light)
                            present(.abilityInfo(role, name))
                        } label: {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(UnevenBox(strong: 16, weak: 5).fill(Palette.card))
                                .overlay(UnevenBox(strong: 16, weak: 5).stroke(Palette.separator, lineWidth: 1))
                                .contentShape(UnevenBox(strong: 16, weak: 5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct TypeChip: View {
    let type: String
    var height: CGFloat = 24

    var body: some View {
        HStack(spacing: 6) {
            if let id = Palette.types[type]?.id {
                Icon(name: "glyph_\(id)", size: height * 0.82)
                    .foregroundStyle(Color.white)
            }
            Text(type)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.white)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(Palette.typeColor(type), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct TypeChartCard: View {
    @Environment(StatsModel.self) private var stats
    let role: Role

    var body: some View {
        @Bindable var stats = stats
        let side = stats.side(role)
        let abilities = stats.considerAbilities ? side.pokemon?.abilities ?? [] : []
        let rows = TypeChart.rows(types: side.pokemon?.types ?? [], abilities: abilities)
        let collapsed = stats.chartCollapsed
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("タイプ相性").sectionTitle()
                Spacer()
                Icon(name: "chevron_down", size: 20)
                    .foregroundStyle(Palette.secondary)
                    .rotationEffect(.degrees(collapsed ? 0 : 180))
                    .frame(width: 34, height: 30)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.32)) { stats.toggleChart() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(collapsed ? "タイプ相性を開く" : "タイプ相性を最小化")
            VStack(spacing: 6) {
                ForEach(rows) { row in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 2) {
                            Icon(name: row.icon, size: 24)
                                .foregroundStyle(Color(hex: row.color))
                            Text(row.label)
                                .font(.caption.weight(.heavy))
                                .monospacedDigit()
                                .foregroundStyle(Color(hex: row.color))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 48)
                        FlowLayout(spacing: 4) {
                            ForEach(row.types, id: \.self) { type in
                                TypeChip(type: type)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color(hex: row.background), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if TypeChart.considersAny(side.pokemon?.abilities ?? []) {
                HStack {
                    Spacer()
                    Toggle("とくせいを考慮", isOn: $stats.considerAbilities)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                        .fixedSize()
                        .padding(.trailing, 2)
                }
                }
            }
            .animation(.snappy(duration: 0.3), value: stats.considerAbilities)
            .frame(maxHeight: collapsed ? 0 : nil, alignment: .top)
            .mask { Rectangle().padding(.horizontal, -24) }
            .opacity(collapsed ? 0 : 1)
            .allowsHitTesting(!collapsed)
        }
    }
}

struct Outlined<Content: View>: View {
    let color: Color
    var outline = Palette.bar
    var width: CGFloat = 1.2
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * .pi / 4
                content()
                    .foregroundStyle(outline)
                    .offset(x: cos(angle) * width, y: sin(angle) * width)
            }
            content()
                .foregroundStyle(color)
        }
    }
}

struct MoveUsageSection: View {
    let pairs: [UsagePair]
    let present: (ActiveSheet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 6) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    MoveUsageRow(pair: pair) {
                        if let name = pair.name {
                            Haptics.play(.light)
                            present(.moveInfo(name))
                        }
                    }
                }
            }
        }
    }
}

struct MoveUsageRow: View {
    let pair: UsagePair
    let action: () -> Void

    var body: some View {
        let info = pair.name.flatMap { StatsCatalog.shared.moveInfo($0) }
        let color = info.map { Palette.typeColor($0.type) } ?? Palette.secondary
        let ratio = min(1, max(0, pair.pct / 100))
        Button(action: action) {
            HStack(spacing: 8) {
                if let info, let id = Palette.types[info.type]?.id {
                    Outlined(color: .white, outline: color) {
                        Icon(name: "glyph_\(id)", size: 20)
                    }
                }
                Outlined(color: color) {
                    Text(pair.name ?? "不明なわざ")
                        .font(.subheadline.weight(.heavy))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Outlined(color: color) {
                    Text("\(Format.fixed1(pair.pct))%")
                        .font(.subheadline.weight(.heavy))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Palette.bar
                        color.frame(width: geometry.size.width * ratio)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(pair.name ?? "不明") \(Format.fixed1(pair.pct))%")
    }
}

struct UsageSlice: Identifiable {
    let id: Int
    let name: String?
    let label: String
    let pct: Double
    let color: Color
    var nature: NatureUsage?
}

enum UsageKind {
    case abilities, items, natures

    var title: String {
        switch self {
        case .abilities: return "とくせい"
        case .items: return "もちもの"
        case .natures: return "能力補正"
        }
    }

    var sprite: String {
        switch self {
        case .abilities: return "ability"
        case .items: return "こだわりスカーフ"
        case .natures: return "ちからのハチマキ"
        }
    }
}

enum SliceColors {
    static let list: [UInt32] = [0x535CA8, 0xE07845, 0x20A6A6, 0xD65F9B, 0x7BAE3F, 0xE6B422, 0x4A90E2, 0x9B78B8, 0xC9573C, 0x5FA88A]
    static let other = Color(hex: 0xD0D0D5)

    static func color(_ index: Int) -> Color {
        Color(hex: list[index % list.count])
    }
}

struct UsageCarousel: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let role: Role
    let present: (ActiveSheet) -> Void

    private func slices(_ kind: UsageKind) -> [UsageSlice] {
        let name = stats.side(role).name
        let entry = model.usage?.pokemons[name]
        var result: [UsageSlice] = []
        var total = 0.0
        switch kind {
        case .abilities, .items:
            let pairs = kind == .abilities ? model.usageAbilities(name) : entry?.rawItems ?? []
            for (index, pair) in pairs.enumerated() where pair.pct > 0 {
                result.append(UsageSlice(id: index, name: pair.name, label: pair.name ?? "不明", pct: pair.pct, color: SliceColors.color(index)))
                total += pair.pct
            }
        case .natures:
            for (index, nature) in (entry?.natures ?? []).enumerated() where nature.pct > 0 {
                result.append(UsageSlice(id: index, name: nature.name, label: nature.name ?? "不明", pct: nature.pct, color: SliceColors.color(index), nature: nature))
                total += nature.pct
            }
        }
        if !result.isEmpty, total < 99.95 {
            result.append(UsageSlice(id: result.count, name: nil, label: "その他", pct: 100 - total, color: SliceColors.other))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach([UsageKind.abilities, .items, .natures], id: \.self) { kind in
                        UsageCard(kind: kind, slices: slices(kind)) { slice in
                            guard let name = slice.name else { return }
                            switch kind {
                            case .abilities: present(.abilityInfo(role, name))
                            case .items: present(.itemInfo(name))
                            case .natures: break
                            }
                        }
                        .containerRelativeFrame(.horizontal) { length, _ in
                            (length - 10) / 1.5
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
        }
    }
}

struct NatureCaption: View {
    let nature: NatureUsage
    var short = false

    private func label(_ key: StatKey) -> String {
        short ? key.letter : key.statName
    }

    var body: some View {
        if let up = nature.up, let down = nature.down {
            Text("\(Text("\(label(up))↑").foregroundStyle(Palette.rankUp)) \(Text("\(label(down))↓").foregroundStyle(Palette.rankDown))")
        } else {
            Text("補正なし").foregroundStyle(Palette.secondary)
        }
    }
}

struct UsageCard: View {
    let kind: UsageKind
    let slices: [UsageSlice]
    let open: (UsageSlice) -> Void
    @State private var selected: Int?
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SpriteIcon(name: kind.sprite, size: 22)
                Text(kind.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ZStack(alignment: .bottomTrailing) {
                PieChart(slices: slices, selected: $selected, onMiss: toggle)
                    .frame(height: 104)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .top) {
                        if let selected, let slice = slices.first(where: { $0.id == selected }) {
                            tooltip(slice)
                                .offset(y: -19)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                Button(action: toggle) {
                    Icon(name: "chevron_down", size: 20)
                        .foregroundStyle(Palette.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(expanded ? "一覧を閉じる" : "一覧を開く")
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
            VStack(spacing: 2) {
                ForEach(slices.filter { $0.name != nil }) { slice in
                    row(slice)
                }
            }
            .frame(maxHeight: expanded ? nil : 0, alignment: .top)
            .clipped()
            .opacity(expanded ? 1 : 0)
            .allowsHitTesting(expanded)
            if slices.isEmpty {
                Text("データなし")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .padding(12)
        .background(Palette.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: toggle)
    }

    private func toggle() {
        Haptics.play(.light)
        withAnimation(.snappy(duration: 0.32)) {
            selected = nil
            expanded.toggle()
        }
    }

    @ViewBuilder
    private func tooltip(_ slice: UsageSlice) -> some View {
        let content = HStack(spacing: 0) {
            if let nature = slice.nature, slice.name != nil {
                Text("\(slice.label)（\(natureText(nature))）")
            } else {
                Text(slice.label)
            }
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Palette.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(Palette.card).shadow(color: .black.opacity(0.16), radius: 8, y: 2))
        if kind != .natures, slice.name != nil {
            Button {
                Haptics.play(.light)
                open(slice)
            } label: {
                content
            }
            .buttonStyle(PressableStyle())
        } else {
            content
        }
    }

    private func natureText(_ nature: NatureUsage) -> Text {
        if let up = nature.up, let down = nature.down {
            return Text("\(Text("\(up.letter)↑").foregroundStyle(Palette.rankUp)) \(Text("\(down.letter)↓").foregroundStyle(Palette.rankDown))")
        }
        return Text("補正なし")
    }

    private func row(_ slice: UsageSlice) -> some View {
        let rank = slice.id + 1
        let content = HStack(spacing: 6) {
            Text("\(rank)")
                .font(.caption2.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(slice.color)
                .frame(width: 20, height: 20)
                .background(Circle().fill(slice.color.opacity(0.14)))
            if kind == .items, let name = slice.name {
                SpriteIcon(name: name, size: 18)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(slice.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let nature = slice.nature {
                    NatureCaption(nature: nature)
                        .font(.system(size: 9, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 2)
            Text("\(Format.fixed1(slice.pct))%")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Palette.secondary)
        }
        .frame(height: 42)
        .contentShape(Rectangle())
        return Group {
            if kind != .natures {
                Button {
                    Haptics.play(.light)
                    open(slice)
                } label: {
                    content
                }
                .buttonStyle(PressableStyle())
            } else {
                content
            }
        }
    }
}

struct PieChart: View {
    let slices: [UsageSlice]
    @Binding var selected: Int?
    var onMiss: () -> Void = {}

    private struct Span: Identifiable {
        var id: Int { slice.id }
        let slice: UsageSlice
        let start: Double
        let end: Double
    }

    private func ranges() -> [Span] {
        let total = max(0.0001, slices.reduce(0) { $0 + $1.pct })
        var start = 0.0
        return slices.map { slice in
            let end = start + slice.pct / total
            defer { start = end }
            return Span(slice: slice, start: start, end: end)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2
            ZStack {
                ForEach(ranges()) { span in
                    let active = selected == span.id
                    PieSlice(start: span.start, end: span.end, inner: 0.52)
                        .fill(span.slice.color)
                        .opacity(selected == nil || active ? 1 : 0.4)
                        .scaleEffect(active ? 1.06 : 1)
                }
            }
            .frame(width: size, height: size)
            .position(center)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let dx = location.x - center.x
                let dy = location.y - center.y
                let distance = sqrt(dx * dx + dy * dy)
                guard distance <= radius * 1.1, distance >= radius * 0.4 else {
                    onMiss()
                    return
                }
                var angle = atan2(dx, -dy) / (2 * .pi)
                if angle < 0 { angle += 1 }
                let hit = ranges().first { angle >= $0.start && angle < $0.end }?.id
                Haptics.play(.selection)
                selected = hit == selected ? nil : hit
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}

struct PieSlice: Shape {
    let start: Double
    let end: Double
    let inner: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let innerRadius = outer * inner
        let gap = min(0.004, (end - start) / 4)
        let a0 = Angle.radians((start + gap) * 2 * .pi - .pi / 2)
        let a1 = Angle.radians((end - gap) * 2 * .pi - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: a0, endAngle: a1, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: a1, endAngle: a0, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct SpreadSection: View {
    @Environment(StatsModel.self) private var stats
    let role: Role
    let spreads: [SpreadUsage]
    @State private var asking: Int?

    private static let letters = ["H", "A", "B", "C", "D", "S"]

    private func color(_ value: Int) -> Color {
        switch value {
        case 30...: return Color(hex: 0xE5534B)
        case 11...29: return Color(hex: 0x3FA45B)
        case 1...10: return Color(hex: 0xE0A21B)
        default: return Color(hex: 0xA0A0A8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("のうりょくポイント").sectionTitle()
            VStack(spacing: 0) {
                ForEach(Array(spreads.enumerated()), id: \.offset) { index, spread in
                    if index > 0 {
                        Divider()
                    }
                    row(index, spread)
                }
            }
        }
    }

    private func row(_ index: Int, _ spread: SpreadUsage) -> some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .font(.caption.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Palette.accent.opacity(0.1)))
            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { stat in
                    let value = stat < spread.points.count ? spread.points[stat] : 0
                    Text("\(Self.letters[stat])\(value)")
                        .font(.caption2.weight(.heavy))
                        .monospacedDigit()
                        .foregroundStyle(color(value))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(color(value).opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            Text("\(Format.fixed1(spread.pct))%")
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.play(.light)
            asking = index
        }
        .popover(isPresented: Binding(get: { asking == index }, set: { if !$0 { asking = nil } }), attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("こののうりょくポイントをお手本にしますか？")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("キャンセル") { asking = nil }
                        .buttonStyle(.glass)
                    Button("お手本にする") {
                        stats.applySpread(role, spread.points)
                        asking = nil
                    }
                    .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .frame(width: 280)
            .presentationCompactAdaptation(.popover)
        }
    }
}

struct PullTopKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

struct PullTopMarker: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .frame(maxWidth: .infinity)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: PullTopKey.self, value: geometry.frame(in: .named("modePull")).minY)
                }
            }
    }
}

struct ModeSwitchPull: ViewModifier {
    let label: String
    let icon: String
    let tint: Color
    let distance: CGFloat
    let onTrigger: () -> Void
    @State private var progress: CGFloat = 0
    @State private var fired = false
    @State private var visibleTop: CGFloat = 0

    @State private var armed = false
    @State private var pullAmount: CGFloat = 0
    @State private var topY: CGFloat?

    private let deadZone: CGFloat = 110

    private func evaluate(_ pull: CGFloat) {
        let value = max(0, min(1, (pull - deadZone) / distance))
        let step = Int(value * 8)
        let previous = Int(progress * 8)
        if value != progress { progress = value }
        if fired {
            if pull < 4 { fired = false }
            return
        }
        if value >= 1, !armed {
            armed = true
            Haptics.play(.rigid)
        } else if value < 1, armed {
            armed = false
        } else if value > 0, value < 1, step != previous {
            Haptics.play(.selection)
        }
    }

    private func released() {
        guard armed, !fired else { return }
        armed = false
        fired = true
        Haptics.play(.success)
        onTrigger()
    }

    func body(content: Content) -> some View {
        content
            .scrollBounceBehavior(.always, axes: .vertical)
            .coordinateSpace(.named("modePull"))
            .onPreferenceChange(PullTopKey.self) { value in
                topY = value
            }
            .onScrollGeometryChange(for: [CGFloat].self) { geometry in
                [-(geometry.contentOffset.y + geometry.contentInsets.top), geometry.contentInsets.top]
            } action: { _, values in
                visibleTop = values[1]
                pullAmount = max(0, values[0])
                evaluate(values[0])
            }
            .onScrollPhaseChange { old, new in
                if old == .interacting, new != .interacting { released() }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(tint.opacity(0.15), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Icon(name: icon, size: 17)
                            .foregroundStyle(tint)
                    }
                    .frame(width: 40, height: 40)
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }
                .opacity(Double(min(1, progress * 3)))
                .scaleEffect(0.7 + 0.3 * progress)
                .frame(maxWidth: .infinity)
                .offset(y: max(0, (topY.map { $0 - pullAmount / 2 } ?? (visibleTop + pullAmount / 2)) - 36))
                .allowsHitTesting(false)
            }
    }
}

extension View {
    func modeSwitchPull(label: String, icon: String, tint: Color, distance: CGFloat, onTrigger: @escaping () -> Void) -> some View {
        modifier(ModeSwitchPull(label: label, icon: icon, tint: tint, distance: distance, onTrigger: onTrigger))
    }
}

struct CalcHandoff: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let role: Role

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("このポケモンでダメ計する").sectionTitle()
            HStack(spacing: 8) {
                ForEach(Role.allCases, id: \.self) { target in
                    let tint = target == .attacker ? Palette.attack : Palette.accent
                    Button {
                        Haptics.play(.medium)
                        model.applyStats(stats.side(role), to: target)
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
