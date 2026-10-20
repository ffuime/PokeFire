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
    @Environment(StatsModel.self) private var stats
    @Environment(\.dismiss) private var dismiss
    let role: Role
    @State private var top50 = false
    @State private var lines: [Int: [SpeedLineEntry]] = [:]

    private static let abilityColor = Color(hex: 0x4A90E2)
    private static let moveColor = Color(hex: 0xC99A06)

    var body: some View {
        let current = stats.side(role)
        let values = lines.keys.sorted(by: >)
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(values, id: \.self) { value in
                            let entries = lines[value] ?? []
                            let mine = entries.contains { $0.name == current.name }
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
                                            row(entry, highlighted: entry.name == current.name)
                                        }
                                    }
                                } else {
                                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                                        ForEach(entries) { entry in
                                            row(entry, highlighted: entry.name == current.name)
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
                .task(id: top50) {
                    lines = SpeedLine.build(model: model, top50: top50)
                    try? await Task.sleep(for: .milliseconds(80))
                    let target = current.real(.s)
                    let keys = lines.keys.sorted(by: >)
                    if let nearest = keys.min(by: { abs($0 - target) < abs($1 - target) }) {
                        proxy.scrollTo(nearest, anchor: .center)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                GlassEffectContainer(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            SpriteView(name: current.name, size: 30)
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                            Text("S")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Palette.stat(.s))
                            NumberText(current.real(.s))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

    private func row(_ entry: SpeedLineEntry, highlighted: Bool) -> some View {
        Button {
            stats.applySpeedLine(role, name: entry.name, points: entry.tier.points, nature: entry.tier.nature)
            dismiss()
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
