import SwiftUI

enum DetailSelection: Hashable {
    case sum
    case tab(Int)
}

private struct DetailViewData {
    var sum: Bool
    var list: [CalcEntry]
    var constant: CalcEntry?
    var effective: DetailSelection?
    var constantMode: Bool
}

private func detailText(_ text: String) -> String {
    text == "うまく決まらなかった" ? "失敗" : text
}

private func statText(_ p: Fighter, _ keys: [StatKey], withRank: Bool = true) -> String {
    keys.compactMap { key -> String? in
        guard let value = p.evs[key] else { return nil }
        let nature = value.nature == 11 ? "↑" : value.nature == 9 ? "↓" : ""
        let rank = withRank && key != .h && value.rank != 0 ? " \(value.rank > 0 ? "+" : "")\(value.rank)" : ""
        return "\(key.letter)\(value.points)\(nature)\(rank)"
    }.joined(separator: " ")
}

struct DetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let openSpeed: () -> Void
    @State private var selection: DetailSelection?

    private func resolve() -> DetailViewData {
        let output = model.output
        let attacks = output.attacks
        if case .tab(let id) = selection {
            if let entry = attacks.first(where: { $0.tabID == id }) {
                return DetailViewData(sum: false, list: [entry], constant: nil, effective: selection, constantMode: false)
            }
            if let constant = output.entries.first(where: { $0.kind != .attack && $0.tabID == id }) {
                return DetailViewData(sum: false, list: [], constant: constant, effective: selection, constantMode: true)
            }
        }
        let multi = output.multi
        let effective: DetailSelection? = multi ? .sum : attacks.first.map { .tab($0.tabID) }
        return DetailViewData(
            sum: multi,
            list: multi ? attacks : Array(attacks.prefix(1)),
            constant: nil,
            effective: effective,
            constantMode: attacks.isEmpty
        )
    }

    var body: some View {
        let view = resolve()
        let output = model.output
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 18) {
                        if view.constantMode {
                            ConstantOverview(entry: view.constant)
                        } else if let first = view.list.first {
                            MatchOverview(view: view, first: first)
                                .holdToSave {
                                    CardImage.save(
                                        MatchOverview(view: view, first: first)
                                            .padding(20)
                                            .frame(width: 390)
                                            .background(Palette.card)
                                            .environment(model)
                                    )
                                }
                        }

                        FlowList(view: view) { next in
                            guard next != view.effective else { return }
                            Haptics.play(next == .sum ? .soft : .light)
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                selection = next
                            }
                        }
                    }
                    .card()

                    if !view.constantMode {
                        HPPMSection(list: view.list)
                        if !view.sum, let first = view.list.first {
                            CounterSection(entry: first)
                            if let firepower = first.result?.info?.firepower {
                                FirepowerCard(value: firepower)
                            }
                            AdjustSection(entry: first, key: "\(output.revision)-\(first.tabID)")
                        }
                    }

                    VStack(spacing: 6) {
                        Text("Pokéloot は非公式のファンツールです。株式会社ポケモン・任天堂・クリーチャーズ・ゲームフリークとは関係ありません。")
                            .font(.caption2)
                            .foregroundStyle(Palette.secondary)
                            .multilineTextAlignment(.center)
                        UsageCredit()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: view.effective)
            }
            .background(Palette.background)
            .navigationTitle("ダメージの詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.play(.light)
                        openSpeed()
                    } label: {
                        Icon(name: "speed", size: 20)
                            .foregroundStyle(Palette.rankDown)
                    }
                    .accessibilityLabel("すばやさ比較")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = model.shareURL() {
                        ShareLink(item: url, preview: SharePreview("Pokéloot の計算条件")) {
                            Icon(name: "share", size: 19)
                                .foregroundStyle(Palette.ink)
                        }
                        .accessibilityLabel("計算条件を共有")
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

private struct MatchOverview: View {
    @Environment(AppModel.self) private var model
    let view: DetailViewData
    let first: CalcEntry

    var body: some View {
        let output = model.output
        let list = view.list
        let sum = view.sum
        let def = output.def ?? Fighter()
        var names: [String] = []
        for entry in list {
            if let name = entry.atk?.name, !names.contains(name) { names.append(name) }
        }
        let single = names.count == 1
        func same(_ pick: (CalcEntry) -> String) -> String? {
            let values = Set(list.map(pick))
            return values.count == 1 ? values.first : nil
        }
        func visible(_ value: String?) -> Bool { !sum || (single && value != nil) }
        var offenseKeys: [StatKey] = []
        var defenseKeys: [StatKey] = []
        for entry in list {
            if let key = entry.result?.info?.offenseKey, !offenseKeys.contains(key) { offenseKeys.append(key) }
            let key = entry.result?.info?.defenseKey ?? .b
            if !defenseKeys.contains(key) { defenseKeys.append(key) }
        }
        let ranksSame = same { entry in offenseKeys.map { String(entry.atk?.evs[$0]?.rank ?? 0) }.joined(separator: ",") } != nil
        let defRanksSame = same { entry in defenseKeys.map { String((entry.def ?? def).evs[$0]?.rank ?? 0) }.joined(separator: ",") } != nil
        let atk = first.atk ?? Fighter()
        let atkTypes = same { ($0.atk?.types ?? []).joined(separator: ",") }
        let atkStat = statText(atk, offenseKeys, withRank: ranksSame)
        let hp = output.hp
        let hpRest = hp.now < hp.max ? " 残\(Format.fixed1(Double(hp.now) / Double(max(1, hp.max)) * 100))%" : ""
        let defStat = statText(first.def ?? def, [.h] + defenseKeys, withRank: defRanksSame) + hpRest
        let move = model.data.moves[atk.move]
        func orNone(_ text: String?) -> String {
            guard let text, !text.isEmpty else { return "なし" }
            return text
        }
        let ability = same { orNone($0.atk?.ability) }
        let item = same { orNone($0.atk.map { StatsCatalog.shared.itemSprite($0.item, pokemon: $0.name) }) }
        let envText = same { entry in
            let field = entry.field ?? Field()
            let weather = Calc.weatherNames[field.weather] ?? "天候なし"
            return "\(weather)・\(field.terrain.isEmpty ? "フィールドなし" : "\(field.terrain)フィールド")"
        }
        let summary = Calc.summarize(sum ? output.entries : list, hp, multi: sum)

        return VStack(spacing: 12) {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    FighterColumn(
                        names: names,
                        types: visible(atkTypes) ? atk.types : [],
                        title: names.joined(separator: "・"),
                        stat: visible(atkStat) ? atkStat : nil,
                        tint: Palette.attack
                    )
                    VStack(spacing: 6) {
                        Text(sum ? "合計ダメージ" : atk.move)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        if !sum, let move {
                            HStack(spacing: 4) {
                                TypeIcon(type: first.result?.info?.moveType ?? move.type, size: 20)
                                CategoryIcon(category: move.category, size: 18)
                                    .foregroundStyle(Palette.secondary)
                                NumberText(first.result?.info?.displayPower.map(String.init) ?? move.powerText)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Palette.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    FighterColumn(
                        names: [def.name],
                        types: visible("") ? def.types : [],
                        title: def.name,
                        stat: visible(defStat) ? defStat : nil,
                        tint: Palette.accent
                    )
                }

                if visible("") {
                    HStack(alignment: .top, spacing: 10) {
                        if visible(ability) || visible(item) {
                            OthersBox(ability: visible(ability) ? ability : nil, item: visible(item) ? item : nil, tint: Palette.attack)
                        } else {
                            Spacer().frame(maxWidth: .infinity)
                        }
                        OthersBox(ability: def.ability.isEmpty ? "なし" : def.ability, item: def.item.isEmpty ? "なし" : StatsCatalog.shared.itemSprite(def.item, pokemon: def.name), tint: Palette.accent)
                    }
                }

                if visible(envText), let envText {
                    Text(envText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Palette.background, in: Capsule())
                }
            }

            LogCard(hp: hp, min: summary.min, max: summary.max, judge: summary.text, rate: summary.rate, heal: false)
        }
    }
}

private struct FighterColumn: View {
    let names: [String]
    let types: [String]
    let title: String
    let stat: String?
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                HStack(spacing: names.count > 1 ? -22 : 0) {
                    ForEach(names, id: \.self) { name in
                        SpriteView(name: name, size: names.count > 1 ? 54 : 70)
                    }
                }
                .frame(height: 72)
                HStack(spacing: 2) {
                    ForEach(types, id: \.self) { type in
                        TypeIcon(type: type, size: 18)
                            .padding(2)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            Text(title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if let stat {
                NumberText(stat)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OthersBox: View {
    let ability: String?
    let item: String?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let ability {
                HStack(spacing: 6) {
                    SpriteIcon(name: "ability", size: 18)
                    Text(ability).lineLimit(1)
                }
            }
            if let item {
                HStack(spacing: 6) {
                    SpriteIcon(name: item, size: 18)
                        .opacity(item == "なし" ? 0 : 1)
                    Text(item).lineLimit(1)
                }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LogCard: View {
    let hp: HPInfo
    let min: Int
    let max: Int
    let judge: String
    let rate: String?
    let heal: Bool
    var healTotal = 0

    var body: some View {
        let base = Double(Swift.max(1, hp.max))
        let percent: String = {
            if heal { return "+\(Format.fixed1(Double(healTotal) / base * 100))%" }
            let low = "\(Format.fixed1(Double(min) / base * 100))%"
            let high = "\(Format.fixed1(Double(max) / base * 100))%"
            return min == max ? low : "\(low)～\(high)"
        }()
        let taken = heal ? "+\(healTotal)" : Format.pair(min, max)
        let sure = hp.max > 0 ? Swift.min(1, Swift.max(0, Double(hp.now - max) / Double(hp.max))) : 0
        let maybe = hp.max > 0 ? Swift.min(1, Swift.max(0, Double(hp.now - min) / Double(hp.max))) : 0
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                NumberText(percent)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(heal ? Palette.plus : Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                NumberText(taken)
                    .font(.headline)
                    .foregroundStyle(heal ? Palette.plus : Palette.ink)
                NumberText("/ \(hp.max)", value: Double(hp.max))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
            }
            DamageBar(sure: sure, maybe: maybe, color: Palette.hp(sure))
            HStack {
                Spacer()
                NumberText(detailText(judge))
                    .font(.headline)
                    .foregroundStyle(Palette.rankDown)
                if let rate {
                    NumberText(rate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                }
            }
        }
    }
}

private struct ConstantOverview: View {
    @Environment(AppModel.self) private var model
    let entry: CalcEntry?

    var body: some View {
        let output = model.output
        let def = output.def ?? Fighter()
        let kind = entry?.kind ?? .damage
        let constant = entry?.constant ?? ConstantBreakdown(parts: [], total: 0)
        let heal = kind == .heel
        let amount = heal ? -constant.total : constant.total
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 6) {
                    Icon(name: kind.icon, size: 34)
                        .foregroundStyle(Palette.tab(kind))
                        .frame(width: 70, height: 70)
                        .background(Palette.tab(kind).opacity(0.1), in: Circle())
                    Text(Constants.kinds[kind]?.title ?? "")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity)
                FighterColumn(names: [def.name], types: def.types, title: def.name, stat: statText(def, [.h]), tint: Palette.accent)
            }
            LogCard(
                hp: output.hp,
                min: amount,
                max: amount,
                judge: constant.parts.map(\.label).joined(separator: "・").isEmpty ? "なし" : constant.parts.map(\.label).joined(separator: "・"),
                rate: nil,
                heal: heal,
                healTotal: constant.total
            )
        }
    }
}

private struct FlowList: View {
    @Environment(AppModel.self) private var model
    let view: DetailViewData
    let onSelect: (DetailSelection) -> Void

    var body: some View {
        let output = model.output
        VStack(spacing: 8) {
            ForEach(Array(output.entries.enumerated()), id: \.element.tabID) { index, entry in
                let id = DetailSelection.tab(entry.tabID)
                let selected = view.effective == id
                FlowItem(entry: entry, index: index, selected: selected)
                    .onTapGesture {
                        let next: DetailSelection = selected && output.multi ? .sum : id
                        onSelect(next)
                    }
            }
            if output.multi {
                let summary = output.summary
                let selected = view.effective == .sum
                HStack(spacing: 12) {
                    Text("∑")
                        .font(.headline)
                        .foregroundStyle(selected ? Color.white : Palette.accent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(selected ? Palette.accent : Palette.accent.opacity(0.1)))
                    Text("合計ダメージ")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        NumberText(Format.percentPair(summary.min, summary.max, output.hp.max))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.boosted)
                        NumberText(Format.pair(summary.min, summary.max))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.boosted.opacity(0.75))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(selected ? Palette.card : Palette.background)
                        .shadow(color: selected ? Palette.accent.opacity(0.22) : .clear, radius: 12, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Palette.accent.opacity(0.45) : Color.clear, lineWidth: 0.75))
                )
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onTapGesture { onSelect(.sum) }
            }
        }
    }
}

private struct FlowItem: View {
    @Environment(AppModel.self) private var model
    let entry: CalcEntry
    let index: Int
    let selected: Bool

    var body: some View {
        let output = model.output
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(selected ? Color.white : Palette.tab(entry.kind))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(selected ? Palette.tab(entry.kind) : Palette.tab(entry.kind).opacity(0.1)))
                if entry.kind != .attack, let constant = entry.constant {
                    let sign = entry.kind == .damage ? "" : "+"
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Constants.kinds[entry.kind]?.title ?? "")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Text(constant.parts.isEmpty ? "なし" : constant.parts.map(\.label).joined(separator: "・"))
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        NumberText("\(sign)\(Format.fixed1(Double(constant.total) / Double(max(1, output.hp.max)) * 100))%")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(entry.kind == .heel ? Palette.plus : Palette.boosted)
                        NumberText("\(sign)\(constant.total)", value: Double(constant.total))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle((entry.kind == .heel ? Palette.plus : Palette.boosted).opacity(0.75))
                    }
                } else {
                    attackSummary(output: output)
                }
            }
            if selected, entry.kind == .attack, let result = entry.result, result.isOK {
                AttackBreakdown(entry: entry, result: result)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? Palette.card : Palette.background)
                .shadow(color: selected ? Palette.tab(entry.kind).opacity(0.22) : .clear, radius: 12, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Palette.tab(entry.kind).opacity(0.45) : Color.clear, lineWidth: 0.75))
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func attackSummary(output: CalcOutput) -> some View {
        let atk = entry.atk ?? Fighter()
        let result = entry.result
        let ok = result?.isOK ?? false
        let plan = result?.info?.plan
        let crits = plan?.filter(\.crit).count ?? 0
        let flagParts: [String?] = [
            atk.move,
            plan.map { "\($0.count)回" },
            atk.crit || crits > 0 ? "急所\(crits > 0 ? "\(crits)回" : "")" : nil,
            atk.powerUp ? "威力アップ" : nil,
            result?.info?.failed == true ? "失敗" : nil,
        ]
        let flags = flagParts.compactMap { $0 }.joined(separator: "・")
        VStack(alignment: .leading, spacing: 2) {
            Text("\(atk.name)→\(output.def?.name ?? "")")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(flags)
                .font(.caption)
                .foregroundStyle(Palette.secondary)
                .lineLimit(2)
        }
        Spacer(minLength: 4)
        VStack(alignment: .trailing, spacing: 2) {
            if ok, let result {
                let range = Calc.useRange(result)
                NumberText(Format.percentPair(range.min, range.max, output.hp.max))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.boosted)
                NumberText(Format.pair(range.min, range.max))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.boosted.opacity(0.75))
            } else {
                Text(detailText(result?.message ?? "-"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.minus)
                    .multilineTextAlignment(.trailing)
            }
        }
        if ok {
            Icon(name: "chevron_down", size: 14)
                .foregroundStyle(Palette.secondary.opacity(0.6))
                .rotationEffect(.degrees(selected ? 180 : 0))
        }
    }
}

private struct AttackBreakdown: View {
    let entry: CalcEntry
    let result: CalcResult

    private struct TableGroup: Identifiable {
        let id: String
        let row: [Int]
        var count: Int
    }

    private var groups: [TableGroup] {
        guard !result.fixed else { return [] }
        let plan = result.info?.plan
        let axel = entry.atk?.move == "トリプルアクセル"
        var list: [TableGroup] = []
        for (index, row) in result.hits.enumerated() {
            let key: String
            if let plan, index < plan.count {
                let p = plan[index]
                key = "\(axel ? "威力\(p.power ?? 0) " : "")\(p.crit ? "急所" : "通常")"
            } else {
                key = result.hits.count > 1 ? "\(index + 1)発目" : "ダメージ"
            }
            if let found = list.firstIndex(where: { $0.id == key }) {
                list[found].count += 1
            } else {
                list.append(TableGroup(id: key, row: row, count: 1))
            }
        }
        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let table = groups
            if let first = table.first {
                ScrollView(.horizontal) {
                    Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 6) {
                        GridRow {
                            Text("乱数")
                                .gridColumnAlignment(.leading)
                            ForEach(0..<first.row.count, id: \.self) { index in
                                Text("\(85 + index)")
                            }
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.secondary)
                        Divider()
                        ForEach(table) { group in
                            GridRow {
                                Text(group.count > 1 ? "\(group.id)×\(group.count)" : group.id)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Palette.secondary)
                                ForEach(Array(group.row.enumerated()), id: \.offset) { _, damage in
                                    Text("\(damage)")
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .scrollIndicators(.hidden)
            }
            if let notes = result.info?.notes, !notes.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                        HStack(spacing: 4) {
                            Text(note.label)
                                .font(.caption)
                            Text(Format.mul(note.mul))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(note.good ? Palette.plus : Palette.minus)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill((note.good ? Palette.plus : Palette.minus).opacity(0.06)))
                        .overlay(Capsule().strokeBorder(note.good ? Palette.plus : Palette.minus, lineWidth: 1))
                    }
                }
            }
        }
    }
}

private struct HPPMSection: View {
    @Environment(AppModel.self) private var model
    let list: [CalcEntry]

    var body: some View {
        let def = model.output.def ?? Fighter()
        let effects = list.flatMap { Calc.hpEffects($0, def: def) }
        if let maxHP = effects.first?.max, maxHP > 0 {
            let totals = [0, 1].map { index in effects.reduce(0) { $0 + $1.p[index] } }
            let lo = totals.min() ?? 0
            let hi = totals.max() ?? 0
            let plus = lo + hi >= 0
            let small = min(abs(lo), abs(hi))
            let large = max(abs(lo), abs(hi))
            let color = plus ? Palette.plus : Palette.minus
            let base = Double(maxHP)
            let bars: (Double, Double) = plus
                ? (Double(small) / base, Double(large) / base)
                : (Double(max(0, maxHP - large)) / base, Double(max(0, maxHP - small)) / base)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("攻撃側の反動・回復").sectionTitle()
                    Spacer()
                    NumberText(Format.absPair(lo, hi))
                        .font(.headline)
                        .foregroundStyle(color)
                    NumberText(Format.percentPair(small, large, maxHP))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color.opacity(0.6))
                }
                DamageBar(sure: bars.0, maybe: bars.1, color: plus ? Color(hex: 0x00C950) : Color(hex: 0xFB2C36))
                VStack(spacing: 6) {
                    ForEach(Array(effects.enumerated()), id: \.offset) { _, effect in
                        let positive = effect.lo + effect.hi >= 0
                        let a = min(abs(effect.lo), abs(effect.hi))
                        let b = max(abs(effect.lo), abs(effect.hi))
                        HStack {
                            Text(effect.name)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                NumberText(Format.pair(a, b))
                                    .font(.subheadline.weight(.bold))
                                NumberText(Format.percentPair(a, b, effect.max))
                                    .font(.caption2.weight(.bold))
                                    .opacity(0.6)
                            }
                            .foregroundStyle(positive ? Palette.plus : Palette.minus)
                        }
                    }
                }
            }
            .card()
        }
    }
}

private struct CounterSection: View {
    @Environment(AppModel.self) private var model
    let entry: CalcEntry

    var body: some View {
        if let rows = Calc.counterRows(entry, def: entry.def ?? model.output.def ?? Fighter()) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ダメージ反射").sectionTitle()
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.name)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(Format.mul(row.mult))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                NumberText(row.text)
                                    .font(.subheadline.weight(.bold))
                                if !row.percent.isEmpty {
                                    NumberText(row.percent)
                                        .font(.caption2.weight(.bold))
                                        .opacity(0.6)
                                }
                            }
                            .foregroundStyle(Palette.minus)
                        }
                        DamageBar(sure: row.ratios[0], maybe: row.ratios[1], color: Palette.hp(row.ratios[0]), height: 8)
                    }
                }
            }
            .card()
        }
    }
}

private struct FirepowerCard: View {
    let value: Int

    var body: some View {
        HStack(alignment: .center) {
            Text("火力指数").sectionTitle()
            Spacer()
            NumberText(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.boosted)
        }
        .card()
    }
}

private struct AdjustSection: View {
    let entry: CalcEntry
    let key: String
    var preset: AdjustTable?
    @State private var table: AdjustTable?
    @State private var loadedKey = ""

    init(entry: CalcEntry, key: String, preset: AdjustTable? = nil) {
        self.entry = entry
        self.key = key
        self.preset = preset
        _table = State(initialValue: preset)
        _loadedKey = State(initialValue: preset == nil ? "" : key)
    }

    @ViewBuilder
    private func line(_ cell: AdjustCell?, key: StatKey, up: Bool, letter: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(letter ? (key == .h ? "H" : "\(key.letter)\(up ? "×1.1" : "×1.0")") : (up ? "×1.1" : "×1.0"))
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.secondary)
                .frame(minWidth: letter ? 40 : 30, alignment: .leading)
            if let cell, let points = cell.points {
                Text("\(cell.real)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("(+\(points)\(up ? "↑" : ""))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(up ? Palette.rankUp : Palette.secondary)
            } else {
                Text("不可")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.minus)
            }
        }
        .monospacedDigit()
    }

    var body: some View {
        Group {
            if let table, loadedKey == key {
                VStack(alignment: .leading, spacing: 12) {
                    Text("調整ライン").sectionTitle()
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 5) {
                                Icon(name: "tab_attack", size: 15)
                                    .foregroundStyle(Palette.attack)
                                Text("確定1発")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Palette.ink)
                            }
                            if table.offenseKey == .vsa {
                                Text("-")
                                    .font(.footnote)
                                    .foregroundStyle(Palette.secondary)
                            } else {
                                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                                    line(row.ko, key: table.offenseKey, up: index == 1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 5) {
                                Icon(name: "shield", size: 15)
                                    .foregroundStyle(Palette.accent)
                                Text("確定耐え")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Palette.ink)
                            }
                            if let h = table.rows.first?.h {
                                line(h, key: .h, up: false, letter: true)
                            }
                            ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                                line(row.wall, key: table.defenseKey, up: index == 1, letter: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .card()
                .holdToSave {
                    CardImage.save(
                        AdjustSection(entry: entry, key: key, preset: table)
                            .padding(12)
                            .frame(width: 390)
                            .background(Palette.background)
                    )
                }
            }
        }
        .task(id: key) {
            guard preset == nil else { return }
            await Task.yield()
            table = Calc.adjustTable(entry)
            loadedKey = key
        }
    }

    @ViewBuilder
    private func cell(_ cell: AdjustCell?, dash: Bool) -> some View {
        if dash {
            Text("-").font(.footnote).foregroundStyle(Palette.secondary)
        } else if let cell {
            HStack(spacing: 2) {
                if !cell.label.isEmpty {
                    Text("\(cell.label):")
                        .font(.caption2)
                        .foregroundStyle(Palette.secondary)
                }
                if let points = cell.points {
                    Text("+\(points)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("（\(cell.real)）")
                        .font(.caption2)
                        .foregroundStyle(Palette.secondary)
                } else {
                    Text("不可")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.minus)
                }
            }
            .monospacedDigit()
        } else {
            Color.clear.frame(height: 1)
        }
    }
}
