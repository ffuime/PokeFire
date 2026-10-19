import SwiftUI

private struct SpeedCombo: Hashable {
    let scarf: Bool
    let nature: Int
    let points: Int
}

private struct SpeedColumn {
    let role: Role
    let name: String
    let mega: Bool
    let fixed: (slow: Int, none: Int, semi: Int, max: Int)
    let scarf: (none: Int, semi: Int, max: Int)
    let now: Int
    let nowScarf: Int
    let combos: [Int: [SpeedCombo]]
}

struct SpeedSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Role?
    @State private var cursor: Int?

    private func columns() -> [SpeedColumn] {
        let field = model.output.field
        return Role.allCases.map { role in
            let p = model.liveFighter(role)
            let base = p.base.s
            func at(_ points: Int, _ nature: Int, _ scarf: Bool = false) -> Int {
                Calc.speedStat(p, field.weather, field.terrain, scarf: scarf, real: Calc.realStat(base, points, nature))
            }
            var combos: [Int: [SpeedCombo]] = [:]
            for scarf in [false, true] {
                for nature in [11, 10, 9] {
                    for points in 0...32 {
                        let value = at(points, nature, scarf)
                        var list = combos[value] ?? []
                        if !list.contains(where: { $0.scarf == scarf && $0.nature == nature }) {
                            list.append(SpeedCombo(scarf: scarf, nature: nature, points: points))
                        }
                        combos[value] = list
                    }
                }
            }
            return SpeedColumn(
                role: role,
                name: p.name,
                mega: model.data.megaParent(p.name) != nil,
                fixed: (at(0, 9), at(0, 10), at(32, 10), at(32, 11)),
                scarf: (at(0, 10, true), at(32, 10, true), at(32, 11, true)),
                now: Calc.speedStat(p, field.weather, field.terrain),
                nowScarf: Calc.speedStat(p, field.weather, field.terrain, scarf: true),
                combos: combos
            )
        }
    }

    var body: some View {
        let data = columns()
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if data.count == 2 {
                        HStack(spacing: 10) {
                            speedItem(data[0])
                            Text(data[0].now > data[1].now ? ">" : data[0].now < data[1].now ? "<" : "=")
                                .font(.title.weight(.heavy))
                                .foregroundStyle(Palette.secondary.opacity(0.6))
                                .contentTransition(.opacity)
                            speedItem(data[1])
                        }
                        Text(data[0].now == data[1].now ? "同速（先攻はランダム）" : "\(data[0].now > data[1].now ? "攻撃側" : "防御側")が先に動きます")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.secondary)
                            .contentTransition(.opacity)
                    }

                    if let role = selected {
                        SpeedEditor(role: role)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Text("ポケモンをタップすると、すばやさを調整できます")
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }

                    SpeedGraph(columns: data, cursor: $cursor)
                        .frame(height: 460)
                        .card(padding: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selected)
            }
            .background(Palette.background)
            .navigationTitle("すばやさ比較")
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

    private func speedItem(_ column: SpeedColumn) -> some View {
        let isSelected = selected == column.role
        let tint = column.role == .attacker ? Palette.attack : Palette.accent
        return Button {
            Haptics.play(.light)
            selected = isSelected ? nil : column.role
        } label: {
            VStack(spacing: 4) {
                SpriteView(name: column.name, size: 56)
                Text(column.role.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                NumberText(column.now)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(isSelected ? tint : Color.clear, lineWidth: 2))
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(column.role.title) \(column.name) すばやさ\(column.now)")
    }
}

private struct SpeedEditor: View {
    @Environment(AppModel.self) private var model
    let role: Role

    var body: some View {
        let side = model.side(role)
        let tint = role == .attacker ? Palette.attack : Palette.accent
        VStack(spacing: 10) {
            StatCard(role: role, key: .s)
            FlowLayout(spacing: 8) {
                if Calc.speedAbilities[side.ability] != nil {
                    ToggleChip(title: side.ability, isOn: model.speedAbilityActive(role), tint: tint) {
                        model.toggleSpeedAbility(role)
                    }
                }
                ForEach(Rules.speedConditionNames, id: \.self) { name in
                    ToggleChip(title: name, isOn: model.speedConditions[role]?.contains(name) ?? false, tint: tint) {
                        model.toggleSpeedCondition(role, name)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}

private struct GraphMetrics {
    let lo: Int
    let hi: Int
    let height: CGFloat
    let width: CGFloat
    let axisWidth: CGFloat = 34
    let columnWidth: CGFloat

    init(lo: Int, hi: Int, size: CGSize, count: Int) {
        self.lo = lo
        self.hi = hi
        height = size.height
        width = max(1, size.width - 34)
        columnWidth = width / CGFloat(max(1, count))
    }

    func y(_ value: Int) -> CGFloat {
        CGFloat(hi - value) / CGFloat(max(1, hi - lo)) * height
    }

    func value(at location: CGFloat) -> Int {
        let ratio = max(0, min(1, Double(location / max(1, height))))
        return Int(Calc.jsRound(Double(hi) - ratio * Double(hi - lo)))
    }
}

private struct SpeedGraph: View {
    let columns: [SpeedColumn]
    @Binding var cursor: Int?

    private var bounds: (lo: Int, hi: Int) {
        let values = columns.flatMap { [$0.fixed.slow, $0.scarf.max, $0.now, $0.nowScarf] }
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max(8, Double(high - low) * 0.05)
        let lo = max(0, Int((Double(low) - pad).rounded(.down)))
        let hi = Int((Double(high) + pad).rounded(.up))
        return (lo, max(lo + 1, hi))
    }

    var body: some View {
        let range = bounds
        GeometryReader { geometry in
            let metrics = GraphMetrics(lo: range.lo, hi: range.hi, size: geometry.size, count: columns.count)
            ZStack(alignment: .topLeading) {
                ticks(metrics)
                ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                    columnView(column, index: index, metrics: metrics)
                }
                cursorView(metrics)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let next = metrics.value(at: gesture.location.y)
                        if next != cursor {
                            Haptics.play(.selection)
                            cursor = next
                        }
                    }
            )
        }
        .animation(.snappy(duration: 0.3), value: range.lo)
        .animation(.snappy(duration: 0.3), value: range.hi)
    }

    private func ticks(_ metrics: GraphMetrics) -> some View {
        let start = Int((Double(metrics.lo) / 50).rounded(.up)) * 50
        let values = Array(stride(from: start, through: metrics.hi, by: 50))
        return ForEach(values, id: \.self) { tick in
            Rectangle()
                .fill(Palette.track.opacity(0.7))
                .frame(width: metrics.width, height: 1)
                .position(x: metrics.axisWidth + metrics.width / 2, y: metrics.y(tick))
            Text("\(tick)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.secondary)
                .position(x: metrics.axisWidth / 2 - 2, y: metrics.y(tick))
        }
    }

    private func columnView(_ column: SpeedColumn, index: Int, metrics: GraphMetrics) -> some View {
        let tint = column.role == .attacker ? Palette.attack : Palette.accent
        let center = metrics.axisWidth + metrics.columnWidth * (CGFloat(index) + 0.5)
        let barX = center - 8
        let scarfX = center + 8
        let guides = [column.fixed.slow, column.fixed.none, column.fixed.semi, column.fixed.max, column.scarf.none, column.scarf.semi, column.scarf.max]
        let marks: [(String, Int)] = [("最", column.fixed.max), ("準", column.fixed.semi), ("無", column.fixed.none), ("遅", column.fixed.slow)]
        let scarfMarks: [(String, Int)] = [("最", column.scarf.max), ("準", column.scarf.semi), ("無", column.scarf.none)]
        let barTop = metrics.y(column.fixed.max)
        let barBottom = metrics.y(column.fixed.slow)
        let scarfTop = metrics.y(column.scarf.max)
        let scarfBottom = metrics.y(column.scarf.none)
        return ZStack(alignment: .topLeading) {
            ForEach(guides.indices, id: \.self) { guide in
                Rectangle()
                    .fill(tint.opacity(0.1))
                    .frame(width: metrics.width, height: 1)
                    .position(x: metrics.axisWidth + metrics.width / 2, y: metrics.y(guides[guide]))
            }
            Capsule()
                .fill(tint.opacity(column.mega ? 0.55 : 0.85))
                .frame(width: 8, height: max(8, barBottom - barTop))
                .position(x: barX, y: (barTop + barBottom) / 2)
            Capsule()
                .fill(tint.opacity(0.3))
                .frame(width: 8, height: max(8, scarfBottom - scarfTop))
                .position(x: scarfX, y: (scarfTop + scarfBottom) / 2)
            ForEach(marks.indices, id: \.self) { mark in
                markLabel(marks[mark].0, marks[mark].1, scarf: false, tint: tint)
                    .position(x: barX - 30, y: metrics.y(marks[mark].1))
            }
            ForEach(scarfMarks.indices, id: \.self) { mark in
                markLabel(scarfMarks[mark].0, scarfMarks[mark].1, scarf: true, tint: tint)
                    .position(x: scarfX + 32, y: metrics.y(scarfMarks[mark].1))
            }
            nowLabel(column.now, scarf: false, tint: tint)
                .position(x: barX - 30, y: metrics.y(column.now))
            nowLabel(column.nowScarf, scarf: true, tint: tint)
                .position(x: scarfX + 32, y: metrics.y(column.nowScarf))
        }
    }

    @ViewBuilder
    private func cursorView(_ metrics: GraphMetrics) -> some View {
        if let cursor, cursor >= metrics.lo, cursor <= metrics.hi {
            let lineY = metrics.y(cursor)
            Rectangle()
                .fill(Palette.ink)
                .frame(width: metrics.width, height: 1.5)
                .position(x: metrics.axisWidth + metrics.width / 2, y: lineY)
            Text("\(cursor)")
                .font(.caption2.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Palette.ink, in: Capsule())
                .position(x: metrics.axisWidth / 2 - 2, y: lineY)
            ForEach(columns.indices, id: \.self) { index in
                comboTip(columns[index].combos[cursor] ?? [])
                    .position(x: metrics.axisWidth + metrics.columnWidth * (CGFloat(index) + 0.5), y: max(14, lineY - 16))
            }
        }
    }

    private func markLabel(_ title: String, _ value: Int, scarf: Bool, tint: Color) -> some View {
        HStack(spacing: 2) {
            if scarf {
                Image("scarf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
            }
            Text(title)
                .font(.system(size: 9, weight: .heavy))
            Text("\(value)")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(tint.opacity(0.75))
        .fixedSize()
    }

    private func nowLabel(_ value: Int, scarf: Bool, tint: Color) -> some View {
        HStack(spacing: 2) {
            Text("★")
                .font(.system(size: 9, weight: .heavy))
            if scarf {
                Image("scarf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
            }
            Text("\(value)")
                .font(.system(size: 11, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint, in: Capsule())
        .fixedSize()
    }

    private func comboTip(_ combos: [SpeedCombo]) -> some View {
        HStack(spacing: 4) {
            if combos.isEmpty {
                Text("-")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.secondary)
            }
            ForEach(combos, id: \.self) { combo in
                HStack(spacing: 1) {
                    if combo.scarf {
                        Image("scarf")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 11, height: 11)
                    }
                    Text("\(combo.points)\(combo.nature == 11 ? "+" : combo.nature == 9 ? "-" : "")")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(combo.nature == 11 ? Palette.rankUp : combo.nature == 9 ? Palette.rankDown : Palette.ink)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .fixedSize()
    }
}
