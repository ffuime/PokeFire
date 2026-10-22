import SwiftUI

struct PanelShape: Shape {
    let role: Role

    func path(in rect: CGRect) -> Path {
        let small: CGFloat = 28
        let large: CGFloat = 56
        let attacker = role == .attacker
        return UnevenRoundedRectangle(
            topLeadingRadius: attacker ? small : large,
            bottomLeadingRadius: attacker ? small : large,
            bottomTrailingRadius: attacker ? large : small,
            topTrailingRadius: attacker ? large : small,
            style: .continuous
        ).path(in: rect)
    }
}

struct SidePanel: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let role: Role
    let present: (ActiveSheet) -> Void
    @State private var pulled = false

    var body: some View {
        ScrollView {
            PullTopMarker()
            VStack(alignment: .leading, spacing: 26) {
                if role == .attacker, model.isConstantActive {
                    ConstantPanel()
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    PokemonHeader(role: role, present: present)
                    if role == .attacker {
                        MoveSection(present: present)
                    }
                    if model.showsHP(role) {
                        HPSection(role: role)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    ForEach(model.visibleStats(role), id: \.self) { key in
                        StatSection(role: role, key: key)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    AbilitySection(role: role, present: present)
                    ItemSection(role: role, present: present)
                    ConditionSection(role: role)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    PanelShape(role: role).fill(Palette.card)
                    Icon(name: role == .attacker ? "watermark_attack" : "watermark_defense", size: 190)
                        .foregroundStyle(role == .attacker ? Color(hex: 0xD65F5F, opacity: 0.2) : Color(hex: 0x508ACB, opacity: 0.2))
                        .padding(.top, 6)
                        .padding(.trailing, role == .attacker ? 24 : 10)
                }
                .clipShape(PanelShape(role: role))
                .shadow(color: .black.opacity(0.1), radius: 18, y: 4)
            }
            .padding(.leading, role == .attacker ? 0 : 16)
            .padding(.trailing, role == .attacker ? 16 : 0)
            .padding(.top, 6)
            .padding(.bottom, 24)
            .animation(.snappy(duration: 0.3), value: model.visibleStats(role))
            .animation(.snappy(duration: 0.3), value: model.showsHP(role))
            .animation(.snappy(duration: 0.3), value: model.isConstantActive)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .modeSwitchPull(label: "PokéStats", icon: "search", tint: Palette.accent, distance: 52) {
            withAnimation(.easeInOut(duration: 0.35)) { stats.enter(from: model) }
        }
    }
}

struct TypeBadge: View {
    let type: String

    var body: some View {
        HStack(spacing: 3) {
            TypeIcon(type: type, size: 20)
            Text(type)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white)
                .fixedSize()
        }
        .padding(.leading, 1)
        .padding(.trailing, 7)
        .frame(height: 22)
        .background(Palette.typeColor(type), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct PokemonHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let role: Role
    let present: (ActiveSheet) -> Void
    @State private var showForms = false
    @State private var formsOpenCount = 0
    @State private var spin = 0

    var body: some View {
        let side = model.side(role)
        let forms = model.data.otherForms(of: side.name)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ModeSprite(name: side.name, hasForms: true, spin: spin, shiny: side.shiny) {
                    spin += 1
                    Haptics.play(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        showForms.toggle()
                        if showForms { formsOpenCount += 1 }
                    }
                } onLongPress: {
                    withAnimation(.easeInOut(duration: 0.35)) { stats.enter(from: model) }
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
                            model.selectPokemon(role, name, remember: false)
                        }
                    } else {
                        info(side)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }

            VStack(alignment: .trailing, spacing: 10) {
                BaseStatsRow(role: role, present: present)
                Button {
                    model.applyTopSet(role)
                } label: {
                    Label("上位の型を入れる", systemImage: "wand.and.stars")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Palette.accent.opacity(0.08), in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .onChange(of: side.name) { _, _ in
            showForms = false
        }
    }

    private func info(_ side: SideState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.play(.light)
                present(.pokemon(role))
            } label: {
                HStack(spacing: 10) {
                    Text(side.name)
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
            .accessibilityLabel("ポケモン \(side.name)")

            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(side.types, id: \.self) { type in
                        TypeBadge(type: type)
                    }
                    if side.types.isEmpty {
                        Text("タイプなし")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.secondary)
                            .fixedSize()
                    }
                    Icon(name: "edit", size: 16)
                        .foregroundStyle(Palette.boosted)
                        .frame(width: 22, height: 22)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.play(.light)
                    present(.types(role))
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("タイプ \(side.types.joined(separator: "・"))")
            .accessibilityAddTraits(.isButton)
        }
    }
}

struct FormsStrip: View {
    let forms: [String]
    var openCount = 0
    var onBox: (() -> Void)?
    let onSelect: (String) -> Void
    @State private var shown = 0

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if let onBox {
                    Button(action: onBox) {
                        VStack(spacing: 2) {
                            Image(systemName: "cube.box")
                                .font(.system(size: 22, weight: .semibold))
                            Text("ボックス")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(Palette.accent)
                        .frame(width: 70, height: 70)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.accent.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .scaleEffect(shown > 0 || forms.isEmpty ? 1 : 0.2)
                    .accessibilityLabel("ボックスから持ってくる")
                }
                ForEach(Array(forms.enumerated()), id: \.element) { index, name in
                    Button {
                        onSelect(name)
                    } label: {
                        SpriteView(name: name, size: 56)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .scaleEffect(index < shown ? 1 : 0.2)
                    .opacity(index < shown ? 1 : 0)
                    .accessibilityLabel(name)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .scrollIndicators(.hidden)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.06),
                    .init(color: .black, location: 0.94),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .task(id: openCount) {
            shown = 0
            try? await Task.sleep(for: .milliseconds(40))
            for index in forms.indices {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.58)) {
                    shown = index + 1
                }
                Haptics.play(.soft)
                try? await Task.sleep(for: .milliseconds(70))
            }
        }
    }
}

struct BaseStatsRow: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        let base = model.side(role).base
        let highlighted = model.highlightedBaseStats(role)
        HStack(spacing: 0) {
            ForEach(StatKey.baseKeys, id: \.self) { key in
                let active = highlighted.contains(key)
                let content = VStack(spacing: 1) {
                    Text(key.letter)
                        .font(.caption2.weight(.heavy))
                        .opacity(0.7)
                    NumberText(base[key])
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(active ? Palette.stat(key) : Color(hex: 0xAAAAAA))
                .frame(maxWidth: .infinity)
                if key == .s {
                    Button {
                        Haptics.play(.light)
                        present(.speed)
                    } label: {
                        content
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("すばやさ比較")
                } else {
                    content
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: highlighted)
    }
}

struct MoveSection: View {
    @Environment(AppModel.self) private var model
    let present: (ActiveSheet) -> Void
    @State private var editingBoost = false

    var body: some View {
        let side = model.attacker
        let move = model.data.moves[side.move]
        let range = model.multiHitRange
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("わざ").sectionTitle()
                Spacer()
                if let move {
                    TypeIcon(type: move.type, size: 18)
                    CategoryIcon(category: move.category, size: 16)
                        .foregroundStyle(Palette.secondary)
                    NumberText(model.movePowerText, value: Double(model.movePowerText))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(model.movePowerBoosted ? Palette.boosted : Palette.secondary)
                        .animation(.easeInOut(duration: 0.2), value: model.movePowerBoosted)
                }
            }

            SelectButton(text: side.move, translucent: true) {
                Haptics.play(.light)
                present(.move)
            }

            if (range == nil && !model.isAxel) || model.showsPowerUp || range != nil || model.showsFling {
                FlowLayout(spacing: 6) {
                    if range == nil, !model.isAxel {
                        ToggleChip(title: "急所", isOn: side.crit || model.critLocked, locked: model.critLocked) {
                            model.toggleCrit()
                        }
                    }
                    if model.showsRankBoost {
                        Button {
                            Haptics.play(.light)
                            editingBoost = true
                        } label: {
                            PillLabel(title: "ランク上昇", value: "×\(model.rankBoostTotal)")
                        }
                        .buttonStyle(PressableStyle())
                        .popover(isPresented: $editingBoost, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                            RankBoostPanel()
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                    if model.showsPowerUp {
                        ToggleChip(title: "威力アップ", isOn: side.powerUp) {
                            model.togglePowerUp()
                        }
                    }
                    if model.showsFainted {
                        CountPill(title: "ひんし数", range: 0...5, value: side.fainted, openEnded: true, unit: "匹", pickerRange: 0...100) { model.setFainted($0) }
                    }
                    if model.showsFling {
                        Menu {
                            Picker("威力", selection: Binding(get: { side.flingPower }, set: { model.setFlingPower($0) })) {
                                ForEach(Calc.flingPowers, id: \.self) { power in
                                    Text("\(power)").tag(power)
                                }
                            }
                        } label: {
                            PillLabel(title: "威力", value: "\(side.flingPower)")
                        }
                    }
                    if let range {
                        CountPill(title: "ヒット回数", range: range.min...range.max, value: side.hits) { model.setHits($0) }
                        CountPill(title: "急所回数", range: 0...max(0, side.hits), value: side.crits) { model.setCrits($0) }
                    }
                }
            }

            if model.isAxel {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        let row = index < side.axel.count ? side.axel[index] : AxelRow()
                        HStack(spacing: 6) {
                            Text("\(index + 1)回目")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Palette.secondary)
                                .frame(width: 48, alignment: .leading)
                            ToggleChip(title: "威力\(Calc.axelPowers[index]) ヒット", isOn: row.hit) {
                                model.toggleAxelHit(index)
                            }
                            ToggleChip(title: "急所", isOn: row.crit) {
                                model.toggleAxelCrit(index)
                            }
                            .disabled(!row.hit)
                            .opacity(row.hit ? 1 : 0.4)
                        }
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: side.move)
    }
}

struct HPSection: View {
    @Environment(AppModel.self) private var model
    let role: Role

    var body: some View {
        let side = model.side(role)
        let max = side.maxHP
        let now = min(max, Swift.max(1, side.hpNow))
        let ratio = max > 0 ? Double(now) / Double(max) : 1
        let percent = Swift.max(1, Int((ratio * 100).rounded(.down)))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("のこりHP").sectionTitle()
                Spacer()
                NumberText("\(percent)%", value: Double(percent))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.hp(ratio))
                NumberText(now)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                NumberText("/\(max)", value: Double(max))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
            }
            RatioBar(ratio: ratio, color: Palette.hp(ratio)) { model.setHP(role, ratio: $0) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("のこりHP \(now)/\(max)")
    }
}

struct StatSection: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let key: StatKey

    var body: some View {
        StatEditor(role: role, key: key)
    }
}

struct StatEditor: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let key: StatKey
    var title: String?

    var body: some View {
        let side = model.side(role)
        let value = side.ev(key)
        let real = side.real(key, opponentBaseA: model.side(role.other).base.a)
        let color = Palette.stat(key)
        let bonus = role == .defender && key == .b ? model.output.defRankBonus : 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title ?? key.title).sectionTitle()
                if bonus > 0 {
                    Text("じきゅうりょく +\(bonus)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.rankUp)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Palette.rankUp.opacity(0.1), in: Capsule())
                        .contentTransition(.numericText(value: Double(bonus)))
                }
                Spacer()
                NumberText(real)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(color)
            }

            HStack(spacing: 12) {
                SegmentBar(count: 32, value: value.points, color: color) { model.setPoints(role, key, $0) }
                NumberText(value.points)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, alignment: .trailing)
            }

            if key.hasNature {
                HStack(spacing: 10) {
                    NatureControl(nature: value.nature) { model.setNature(role, key, $0) }
                    Spacer(minLength: 0)
                    RankControl(
                        rank: model.displayedRank(role, key),
                        onStep: { model.stepRank(role, key, $0) },
                        onSet: { model.setRank(role, key, displayed: $0) }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(key.title)
    }
}

struct AbilitySection: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        let side = model.side(role)
        let candidates = side.pokemon?.abilities ?? []
        let control = model.abilityControl(role)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("とくせい").sectionTitle()
                Spacer(minLength: 8)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(candidates, id: \.self) { name in
                            let selected = side.ability == name
                            Button {
                                model.tapAbilityCandidate(role, name)
                            } label: {
                                ZStack {
                                    Text(name)
                                        .font(.subheadline.weight(.regular))
                                        .opacity(selected ? 0 : 1)
                                    Text(name)
                                        .font(.subheadline.weight(.heavy))
                                        .opacity(selected ? 1 : 0)
                                }
                                .fixedSize()
                                .foregroundStyle(selected ? Palette.accent : Color(hex: 0xB0B0B0))
                                .scaleEffect(selected ? 1.06 : 0.84, anchor: .bottom)
                                .animation(.spring(response: 0.42, dampingFraction: 0.52), value: selected)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .fixedSize(horizontal: candidates.count <= 2, vertical: false)
            }

            VStack(alignment: .leading, spacing: 8) {
                SelectButton(text: side.ability) {
                    Haptics.play(.light)
                    present(.ability(role))
                }
                if control != .hidden {
                    ToggleChip(
                        title: control.label,
                        isOn: model.abilityActive(role),
                        locked: control == .locked
                    ) {
                        model.abilityButtonTapped(role)
                    }
                    .disabled(model.abilityDisabled(role) && control != .locked)
                    .opacity(model.abilityDisabled(role) && control == .toggle ? 0.45 : 1)
                    .fixedSize()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: control)
        }
    }
}

struct ItemSection: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        let side = model.side(role)
        VStack(alignment: .leading, spacing: 10) {
            Text("もちもの").sectionTitle()
            SelectButton(text: side.item, sprite: StatsCatalog.shared.itemSprite(side.item, pokemon: side.name)) {
                Haptics.play(.light)
                present(.item(role))
            }
            if let ratio = model.itemConstantRatio(role) {
                ToggleChip(title: "発動", isOn: model.constantActive(ratio)) {
                    model.toggleConstant(ratio, label: side.item)
                }
                .disabled(model.isConstantActive)
                .opacity(model.isConstantActive ? 0.45 : 1)
                .fixedSize()
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if role == .attacker, model.showsMetronome {
                CountPill(title: "連続攻撃回数", range: 1...6, value: side.metronome, openEnded: true) { model.setMetronome($0) }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.25), value: model.showsMetronome)
    }
}

struct ConditionSection: View {
    @Environment(AppModel.self) private var model
    let role: Role

    var body: some View {
        let side = model.side(role)
        VStack(alignment: .leading, spacing: 10) {
            Text("じょうたい").sectionTitle()
            FlowLayout(spacing: 6) {
                ForEach(Rules.conditions(role), id: \.self) { name in
                    let locked = role == .attacker && name == "やけど" && model.burnLocked
                    ToggleChip(title: name, isOn: side.conditions.contains(name), locked: locked) {
                        model.toggleCondition(role, name)
                    }
                }
            }
        }
    }
}
