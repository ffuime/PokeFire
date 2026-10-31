import SwiftUI

enum SpeedTier {
    case slowest, none, semi, fastest

    var label: String {
        switch self {
        case .slowest: return "最遅"
        case .none: return "無振"
        case .semi: return "準速"
        case .fastest: return "最速"
        }
    }

    var color: Color {
        switch self {
        case .slowest: return Color(hex: 0x3E7BD6)
        case .none: return Color(hex: 0x8A8FA8)
        case .semi: return Color(hex: 0x3FA45B)
        case .fastest: return Color(hex: 0xE5534B)
        }
    }

    var points: Int { self == .semi || self == .fastest ? 32 : 0 }
    var nature: Int { self == .fastest ? 11 : self == .slowest ? 9 : 10 }
}

struct SpeedLineEntry: Identifiable {
    var id: String { "\(name)|\(tier.label)|\(scarf)|\(ability ?? "")|\(move ?? "")|\(uses)" }
    let name: String
    let speed: Int
    let tier: SpeedTier
    var scarf = false
    var ability: String?
    var move: String?
    var uses = 0
}

enum SpeedLine {
    private static func boost(_ info: MoveInfo) -> Int? {
        guard info.flags.contains("ランク上昇:すばやさ") else { return nil }
        guard let range = info.effect.range(of: "素早さ[^。]*?([0-9])段階上", options: .regularExpression) else { return 1 }
        let digits = info.effect[range].filter(\.isNumber)
        return digits.last.flatMap { Int(String($0)) } ?? 1
    }

    private static func speed(_ base: Int, _ tier: SpeedTier, rank: Int = 0, scarf: Bool = false, abilityMod: Int? = nil) -> Int {
        var mods: [Int] = []
        if scarf { mods.append(6144) }
        if let abilityMod { mods.append(abilityMod) }
        let real = Calc.realStat(base, tier.points, tier.nature)
        return max(1, Calc.applyMod(Calc.applyRank(real, rank), Calc.chainMods(mods)))
    }

    @MainActor
    static func build(model: AppModel, top50: Bool) -> [Int: [SpeedLineEntry]] {
        let data = model.data
        let catalog = StatsCatalog.shared
        var result: [Int: [SpeedLineEntry]] = [:]
        func add(_ entry: SpeedLineEntry) {
            result[entry.speed, default: []].append(entry)
        }
        for name in data.pokemonOrder {
            guard let pokemon = data.pokemons[name] else { continue }
            if top50 {
                guard let rank = model.usage?.pokemons[name]?.rank, rank <= 50 else { continue }
            }
            let mega = data.megaParent(name) != nil
            let base = pokemon.base.s
            for tier in [SpeedTier.slowest, .none, .semi, .fastest] {
                add(SpeedLineEntry(name: name, speed: speed(base, tier), tier: tier))
            }
            if !mega {
                for tier in [SpeedTier.semi, .fastest] {
                    add(SpeedLineEntry(name: name, speed: speed(base, tier, scarf: true), tier: tier, scarf: true))
                }
            }
            let moves = (model.usage?.pokemons[name]?.moves ?? []).prefix(10).compactMap(\.name)
            for move in moves {
                guard let info = catalog.moveInfo(move), let amount = boost(info) else { continue }
                for uses in 1...2 {
                    let rank = min(6, amount * uses)
                    for tier in [SpeedTier.semi, .fastest] {
                        add(SpeedLineEntry(name: name, speed: speed(base, tier, rank: rank), tier: tier, move: move, uses: uses))
                        if info.category != "変化", !mega {
                            add(SpeedLineEntry(name: name, speed: speed(base, tier, rank: rank, scarf: true), tier: tier, scarf: true, move: move, uses: uses))
                        }
                    }
                }
            }
            for ability in pokemon.abilities {
                guard let rule = Calc.speedAbilities[ability] else { continue }
                for tier in [SpeedTier.semi, .fastest] {
                    add(SpeedLineEntry(name: name, speed: speed(base, tier, abilityMod: rule.mod), tier: tier, ability: ability))
                    if !mega {
                        add(SpeedLineEntry(name: name, speed: speed(base, tier, scarf: true, abilityMod: rule.mod), tier: tier, scarf: true, ability: ability))
                    }
                }
            }
        }
        return result
    }
}

struct SpeedLineSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let currentName: String
    let currentSpeed: Int
    let onPick: (SpeedLineEntry) -> Bool
    @State private var top50 = false
    @State private var lines: [Int: [SpeedLineEntry]] = [:]
    @State private var tuning = false
    @State private var tuned = false
    @State private var points = 32
    @State private var nature = 10
    @State private var rank = 0
    @State private var scarf = false
    @State private var abilityOn = false
    @State private var tailwind = false
    @State private var paralysis = false

    private var base: Int { GameData.shared.pokemons[currentName]?.base.s ?? 0 }

    private var speedAbility: (name: String, mod: Int)? {
        for ability in GameData.shared.pokemons[currentName]?.abilities ?? [] {
            if let rule = Calc.speedAbilities[ability] { return (ability, rule.mod) }
        }
        return nil
    }

    private var tunedSpeed: Int {
        var mods: [Int] = []
        if scarf { mods.append(6144) }
        if abilityOn, let ability = speedAbility { mods.append(ability.mod) }
        if tailwind { mods.append(8192) }
        var value = Calc.applyMod(Calc.applyRank(Calc.realStat(base, points, nature), rank), Calc.chainMods(mods))
        if paralysis, speedAbility?.name != "はやあし" || !abilityOn { value /= 2 }
        return max(1, value)
    }

    private var shownSpeed: Int { tuned ? tunedSpeed : currentSpeed }

    private func seed() {
        for nature in [10, 11, 9] {
            if let points = (0...32).first(where: { Calc.realStat(base, $0, nature) == currentSpeed }) {
                self.points = points
                self.nature = nature
                return
            }
        }
    }

    private func edit(_ body: () -> Void) {
        body()
        tuned = true
        Haptics.play(.selection)
    }

    private static let abilityColor = Color(hex: 0x4A90E2)
    private static let moveColor = Color(hex: 0xC99A06)

    var body: some View {
        let values = lines.keys.sorted(by: >)
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(values, id: \.self) { value in
                            let entries = lines[value] ?? []
                            let mine = entries.contains { $0.name == currentName }
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(value)")
                                    .font(.title3.weight(.bold))
                                    .monospacedDigit()
                                    .foregroundStyle(mine ? Palette.accent : Palette.ink)
                                    .frame(width: 52, alignment: .trailing)
                                    .padding(.top, 10)
                                if entries.contains(where: { $0.ability != nil || $0.move != nil }) {
                                    VStack(spacing: 4) {
                                        ForEach(entries) { entry in
                                            row(entry, highlighted: entry.name == currentName)
                                        }
                                    }
                                } else {
                                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                                        ForEach(entries) { entry in
                                            row(entry, highlighted: entry.name == currentName)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(mine ? Palette.accent.opacity(0.05) : Color.clear)
                            .id(value)
                            Divider()
                                .padding(.leading, 80)
                        }
                    }
                    .padding(.bottom, 80)
                }
                .onChange(of: shownSpeed) { _, target in
                    let keys = lines.keys.sorted(by: >)
                    if let nearest = keys.min(by: { abs($0 - target) < abs($1 - target) }) {
                        withAnimation(.snappy(duration: 0.3)) { proxy.scrollTo(nearest, anchor: .center) }
                    }
                }
                .task(id: top50) {
                    if !tuned { seed() }
                    lines = SpeedLine.build(model: model, top50: top50)
                    try? await Task.sleep(for: .milliseconds(80))
                    let target = shownSpeed
                    let keys = lines.keys.sorted(by: >)
                    if let nearest = keys.min(by: { abs($0 - target) < abs($1 - target) }) {
                        proxy.scrollTo(nearest, anchor: .center)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                GlassEffectContainer(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Button {
                            Haptics.play(.light)
                            tuning = true
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                SpriteView(name: currentName, size: 30)
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                                Text("S")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Palette.stat(.s))
                                NumberText(shownSpeed)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(tuned && tunedSpeed != Calc.realStat(base, points, nature) ? Palette.boosted : Palette.ink)
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .popover(isPresented: $tuning, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                            tuner
                                .presentationCompactAdaptation(.popover)
                        }
                        Toggle("使用率TOP50まで", isOn: $top50)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize()
                            .padding(.leading, 16)
                            .padding(.trailing, 12)
                            .frame(height: 48)
                            .glassEffect(.regular, in: Capsule())
                    }
                }
                .padding(16)
            }
            .navigationTitle("すばやさライン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var tuner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("すばやさ").sectionTitle()
                Spacer()
                NumberText(tunedSpeed)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.stat(.s))
            }
            HStack(spacing: 12) {
                SegmentBar(count: 32, value: points, color: Palette.stat(.s)) { value in edit { points = value } }
                NumberText(points)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, alignment: .trailing)
            }
            HStack(spacing: 10) {
                NatureControl(nature: nature) { value in edit { nature = value } }
                Spacer(minLength: 0)
                RankControl(
                    rank: rank,
                    onStep: { step in edit { rank = Calc.clampRank(rank + step) } },
                    onSet: { value in edit { rank = Calc.clampRank(value) } }
                )
            }
            FlowLayout(spacing: 6) {
                ToggleChip(title: "スカーフ", isOn: scarf) { edit { scarf.toggle() } }
                if let ability = speedAbility {
                    ToggleChip(title: ability.name, isOn: abilityOn) { edit { abilityOn.toggle() } }
                }
                ToggleChip(title: "おいかぜ", isOn: tailwind) { edit { tailwind.toggle() } }
                ToggleChip(title: "まひ", isOn: paralysis) { edit { paralysis.toggle() } }
            }
        }
        .padding(18)
        .frame(width: 340)
    }

    private func row(_ entry: SpeedLineEntry, highlighted: Bool) -> some View {
        Button {
            if onPick(entry) { dismiss() }
        } label: {
            HStack(spacing: 8) {
                SpriteView(name: entry.name, size: 34)
                HStack(spacing: 4) {
                    Text(entry.tier.label)
                        .foregroundStyle(entry.tier.color)
                    if entry.scarf {
                        SpriteIcon(name: "こだわりスカーフ", size: 18)
                    }
                    if let ability = entry.ability {
                        Text("+ \(ability)")
                            .foregroundStyle(Self.abilityColor)
                    }
                    if let move = entry.move {
                        Text("+ \(move)×\(entry.uses)")
                            .foregroundStyle(Self.moveColor)
                    }
                }
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highlighted ? Palette.accent.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(entry.name) \(entry.tier.label) \(entry.speed)")
    }
}
