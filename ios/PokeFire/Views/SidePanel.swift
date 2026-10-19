import SwiftUI

struct SidePanel: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if role == .attacker, model.isConstantActive {
                    ConstantPanel()
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    PokemonCard(role: role, present: present)
                    if role == .attacker {
                        MoveCard(present: present)
                    }
                    if model.showsHP(role) {
                        HPCard(role: role)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    ForEach(model.visibleStats(role), id: \.self) { key in
                        StatCard(role: role, key: key)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    AbilityCard(role: role, present: present)
                    ItemCard(role: role, present: present)
                    ConditionCard(role: role)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 24)
            .animation(.snappy(duration: 0.3), value: model.visibleStats(role))
            .animation(.snappy(duration: 0.3), value: model.showsHP(role))
            .animation(.snappy(duration: 0.3), value: model.isConstantActive)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

struct TypeBadge: View {
    let type: String

    var body: some View {
        HStack(spacing: 4) {
            TypeIcon(type: type, size: 18)
            Text(type)
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.typeColor(type))
                .lineLimit(1)
        }
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .frame(height: 24)
        .background(Palette.typeColor(type).opacity(0.12), in: Capsule())
    }
}

struct PokemonCard: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void
    @State private var showForms = false
    @State private var spin = 0

    var body: some View {
        let side = model.side(role)
        let forms = model.data.otherForms(of: side.name)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    guard !forms.isEmpty else {
                        present(.pokemon(role))
                        return
                    }
                    spin += 1
                    Haptics.play(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showForms.toggle()
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        SpriteView(name: side.name, size: 80)
                            .background(Circle().fill(Palette.background))
                        if !forms.isEmpty {
                            Icon(name: "forms", size: 13)
                                .foregroundStyle(Palette.accent)
                                .rotationEffect(.degrees(Double(spin) * -360))
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: spin)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.white).shadow(color: .black.opacity(0.1), radius: 3, y: 1))
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(forms.isEmpty ? "ポケモンを選ぶ" : "ほかの姿")

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Haptics.play(.light)
                        present(.pokemon(role))
                    } label: {
                        HStack(spacing: 6) {
                            Text(side.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .contentTransition(.opacity)
                            Icon(name: "search", size: 16)
                                .foregroundStyle(Palette.accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("ポケモン \(side.name)")

                    Button {
                        Haptics.play(.light)
                        present(.types(role))
                    } label: {
                        HStack(spacing: 6) {
                            ForEach(side.types, id: \.self) { type in
                                TypeBadge(type: type)
                            }
                            if side.types.isEmpty {
                                Text("タイプなし")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Palette.secondary)
                            }
                            Icon(name: "edit", size: 14)
                                .foregroundStyle(Palette.secondary.opacity(0.7))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("タイプ \(side.types.joined(separator: "・"))")
                }
                Spacer(minLength: 0)
            }

            if showForms, !forms.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(forms.enumerated()), id: \.element) { index, name in
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showForms = false
                                }
                                model.selectPokemon(role, name, remember: false)
                            } label: {
                                VStack(spacing: 4) {
                                    SpriteView(name: name, size: 56)
                                    Text(name)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                        .lineLimit(1)
                                        .frame(maxWidth: 84)
                                }
                                .padding(8)
                                .background(Palette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                            .transition(.scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.04)))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            BaseStatsRow(role: role, present: present)
        }
        .card()
        .overlay(alignment: .topTrailing) {
            Icon(name: role == .attacker ? "tab_attack" : "shield", size: 70)
                .foregroundStyle((role == .attacker ? Palette.attack : Palette.accent).opacity(0.07))
                .padding(12)
                .allowsHitTesting(false)
        }
        .onChange(of: side.name) { _, _ in
            showForms = false
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
        HStack(spacing: 6) {
            ForEach(StatKey.baseKeys, id: \.self) { key in
                let active = highlighted.contains(key)
                let content = VStack(spacing: 2) {
                    Text(key.letter)
                        .font(.caption2.weight(.heavy))
                    NumberText(base[key])
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(active ? Palette.stat(key) : Palette.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(active ? Palette.stat(key).opacity(0.12) : Palette.background)
                )
                if key == .s {
                    Button {
                        Haptics.play(.light)
                        present(.speed)
                    } label: {
                        content
                            .overlay(alignment: .topTrailing) {
                                Icon(name: "speed", size: 10)
                                    .foregroundStyle(Palette.stat(.s).opacity(0.7))
                                    .padding(4)
                            }
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

struct MoveCard: View {
    @Environment(AppModel.self) private var model
    let present: (ActiveSheet) -> Void

    var body: some View {
        let side = model.attacker
        let move = model.data.moves[side.move]
        let range = model.multiHitRange
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("わざ").sectionTitle()
                Spacer()
                if let move {
                    TypeIcon(type: move.type, size: 22)
                    CategoryIcon(category: move.category, size: 20)
                        .foregroundStyle(Palette.secondary)
                    NumberText(model.movePowerText, value: Double(model.movePowerText))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(model.movePowerBoosted ? Palette.boosted : Palette.secondary)
                        .animation(.easeInOut(duration: 0.2), value: model.movePowerBoosted)
                }
            }

            SelectButton(text: side.move) {
                Haptics.play(.light)
                present(.move)
            }

            if (range == nil && !model.isAxel) || model.showsPowerUp {
                HStack(spacing: 8) {
                    if range == nil, !model.isAxel {
                        ToggleChip(title: "急所", isOn: side.crit || model.critLocked, locked: model.critLocked, tint: Palette.boosted) {
                            model.toggleCrit()
                        }
                    }
                    if model.showsPowerUp {
                        ToggleChip(title: "威力アップ", isOn: side.powerUp, tint: Palette.boosted) {
                            model.togglePowerUp()
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            if let range {
                CountSegments(title: "ヒット回数", range: range.min...range.max, value: side.hits) { model.setHits($0) }
                CountSegments(title: "急所回数", range: 0...max(0, side.hits), value: side.crits, tint: Palette.boosted) { model.setCrits($0) }
            }

            if model.isAxel {
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        let row = index < side.axel.count ? side.axel[index] : AxelRow()
                        HStack(spacing: 8) {
                            Text("\(index + 1)回目")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Palette.secondary)
                                .frame(width: 44, alignment: .leading)
                            ToggleChip(title: "威力\(Calc.axelPowers[index]) ヒット", isOn: row.hit) {
                                model.toggleAxelHit(index)
                            }
                            ToggleChip(title: "急所", isOn: row.crit, tint: Palette.boosted) {
                                model.toggleAxelCrit(index)
                            }
                            .disabled(!row.hit)
                            .opacity(row.hit ? 1 : 0.4)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .card()
        .animation(.snappy(duration: 0.25), value: side.move)
    }
}

struct HPCard: View {
    @Environment(AppModel.self) private var model
    let role: Role

    var body: some View {
        let side = model.side(role)
        let max = side.maxHP
        let now = min(max, Swift.max(1, side.hpNow))
        let ratio = max > 0 ? Double(now) / Double(max) : 1
        let percent = Swift.max(1, Int((ratio * 100).rounded(.down)))
        VStack(alignment: .leading, spacing: 8) {
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
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("のこりHP \(now)/\(max)")
    }
}

struct StatCard: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let key: StatKey

    var body: some View {
        let side = model.side(role)
        let value = side.ev(key)
        let real = side.real(key, opponentBaseA: model.side(role.other).base.a)
        let color = Palette.stat(key)
        let bonus = role == .defender && key == .b ? model.output.defRankBonus : 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(key.title).sectionTitle()
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
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(key.title)
    }
}

struct AbilityCard: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        let side = model.side(role)
        let candidates = side.pokemon?.abilities ?? []
        let control = model.abilityControl(role)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("とくせい").sectionTitle()
                Spacer(minLength: 8)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(candidates, id: \.self) { name in
                            let selected = side.ability == name
                            Button {
                                model.tapAbilityCandidate(role, name)
                            } label: {
                                Text(name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selected ? Color.white : Palette.accent)
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .background(selected ? Palette.accent : Palette.accent.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .fixedSize(horizontal: candidates.count <= 2, vertical: false)
            }

            HStack(spacing: 8) {
                SelectButton(text: side.ability) {
                    Haptics.play(.light)
                    present(.ability(role))
                }
                if control != .hidden {
                    ToggleChip(
                        title: control.label,
                        isOn: model.abilityActive(role),
                        locked: control == .locked,
                        tint: Palette.accent
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
        .card()
    }
}

struct ItemCard: View {
    @Environment(AppModel.self) private var model
    let role: Role
    let present: (ActiveSheet) -> Void

    var body: some View {
        let side = model.side(role)
        VStack(alignment: .leading, spacing: 10) {
            Text("もちもの").sectionTitle()
            SelectButton(text: side.item) {
                Haptics.play(.light)
                present(.item(role))
            }
            if role == .attacker, model.showsMetronome {
                CountSegments(title: "連続攻撃回数", range: 1...6, value: side.metronome, openEnded: true) { model.setMetronome($0) }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
        .animation(.snappy(duration: 0.25), value: model.showsMetronome)
    }
}

struct ConditionCard: View {
    @Environment(AppModel.self) private var model
    let role: Role

    var body: some View {
        let side = model.side(role)
        VStack(alignment: .leading, spacing: 10) {
            Text("じょうたい").sectionTitle()
            FlowLayout(spacing: 8) {
                ForEach(Rules.conditions(role), id: \.self) { name in
                    let locked = role == .attacker && name == "やけど" && model.burnLocked
                    ToggleChip(title: name, isOn: side.conditions.contains(name), locked: locked, tint: role == .attacker ? Palette.attack : Palette.accent) {
                        model.toggleCondition(role, name)
                    }
                }
            }
        }
        .card()
    }
}
