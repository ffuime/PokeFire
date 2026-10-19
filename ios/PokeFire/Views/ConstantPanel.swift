import SwiftUI

struct ConstantPanel: View {
    @Environment(AppModel.self) private var model
    @FocusState private var focused: UUID?

    var body: some View {
        if let tab = model.activeTab, tab.kind != .attack, let info = Constants.kinds[tab.kind] {
            let maxHP = model.constantMaxHP()
            let breakdown = Constants.breakdown(tab.constant, kind: tab.kind, max: maxHP)
            let tint = Palette.tab(tab.kind)
            let sign = tab.kind == .damage ? "-" : "+"
            let ratios = Constants.ratios[tab.kind] ?? []
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Icon(name: tab.kind.icon, size: 26)
                            .foregroundStyle(tint)
                            .frame(width: 48, height: 48)
                            .background(tint.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Palette.ink)
                            NumberText("防御側の最大HP \(maxHP)", value: Double(maxHP))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.secondary)
                        }
                        Spacer()
                        NumberText("\(sign)\(breakdown.total)", value: Double(breakdown.total))
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    ScrollView(.horizontal) {
                        Text(breakdown.parts.isEmpty ? "未選択" : breakdown.parts.map(\.label).joined(separator: "・"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondary.opacity(breakdown.parts.isEmpty ? 0.45 : 1))
                            .lineLimit(1)
                            .fixedSize()
                            .contentTransition(.opacity)
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: 18)
                }

                Picker("区分", selection: Binding(get: { tab.constant.section }, set: { model.setConstantSection($0) })) {
                    ForEach(info.sections.indices, id: \.self) { index in
                        Text(info.sections[index].label).tag(info.sections[index].key)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 0) {
                    switch tab.constant.section {
                    case "toxic":
                        ForEach(Constants.toxicTurns, id: \.self) { turn in
                            ConstantRow(
                                title: "\(turn)ターン目",
                                amount: Constants.toxicAmount(maxHP, turn),
                                examples: nil,
                                count: tab.constant.toxic[turn] ?? 0,
                                tint: tint
                            ) { model.stepConstant(toxic: turn, $0) }
                            if turn != Constants.toxicTurns.last { Divider().padding(.leading, 16) }
                        }
                    case "fixed":
                        ConstantRow(
                            title: "\(info.fixed)\(info.unit)",
                            amount: nil,
                            examples: info.fixedExample,
                            count: tab.constant.fixed,
                            tint: tint
                        ) { model.stepConstantFixed($0) }
                        ForEach(tab.constant.inputs) { input in
                            Divider().padding(.leading, 16)
                            HStack(spacing: 8) {
                                TextField("0", text: Binding(
                                    get: { input.value == 0 ? "" : String(input.value) },
                                    set: { model.setConstantInput(input.id, value: Int($0.filter(\.isNumber).prefix(5)) ?? 0) }
                                ))
                                .keyboardType(.numberPad)
                                .focused($focused, equals: input.id)
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .padding(.horizontal, 12)
                                .frame(width: 96, height: 40)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text(info.unit)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.secondary)
                                Button {
                                    model.removeConstantInput(input.id)
                                } label: {
                                    Icon(name: "trash", size: 16)
                                        .foregroundStyle(Palette.minus.opacity(0.8))
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("削除")
                                Spacer(minLength: 0)
                                ConstantCounter(count: input.count, tint: tint) { model.stepConstant(input: input.id, $0) }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        Divider().padding(.leading, 16)
                        Button {
                            let id = model.addConstantInput()
                            Task { @MainActor in
                                focused = id
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Icon(name: "plus", size: 16)
                                Text("\(info.unit)量を追加")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(tint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    default:
                        ForEach(Array(ratios.enumerated()), id: \.element.key) { index, ratio in
                            ConstantRow(
                                title: ratio.title,
                                amount: Constants.ratioAmount(maxHP, ratio),
                                examples: ratio.examples.isEmpty ? "-" : ratio.examples.joined(separator: "・"),
                                count: tab.constant.ratios[ratio.key] ?? 0,
                                tint: tint
                            ) { model.stepConstant(ratio: ratio.key, $0) }
                            if index < ratios.count - 1 { Divider().padding(.leading, 16) }
                        }
                    }
                }
                .background(Palette.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .animation(.snappy(duration: 0.25), value: tab.constant.inputs.map(\.id))

                Text(tab.kind == .heel ? "回復は減っているHPの分までしか入らず、ひんしになった後は回復しません。" : "防御側の最大HPを基準に計算します。")
                    .font(.caption)
                    .foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = nil }
                }
            }
        }
    }
}

struct ConstantRow: View {
    let title: String
    let amount: Int?
    let examples: String?
    let count: Int
    let tint: Color
    let onStep: (Int) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(count > 0 ? tint : Palette.ink)
                    if let amount {
                        NumberText(String(amount), value: Double(amount))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                }
                if let examples {
                    Text(examples)
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            ConstantCounter(count: count, tint: tint, onStep: onStep)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(count > 0 ? tint.opacity(0.05) : Color.clear)
        .animation(.snappy(duration: 0.2), value: count > 0)
    }
}

struct ConstantCounter: View {
    let count: Int
    let tint: Color
    let onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onStep(-1)
            } label: {
                Icon(name: "minus", size: 15)
                    .frame(width: 36, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .disabled(count == 0)
            .opacity(count == 0 ? 0.3 : 1)
            NumberText(count)
                .font(.headline)
                .frame(minWidth: 24)
            Button {
                onStep(1)
            } label: {
                Icon(name: "plus", size: 15)
                    .frame(width: 36, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(count > 0 ? tint : Palette.ink)
        .background(Capsule().fill(count > 0 ? tint.opacity(0.12) : Color.white))
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(count)回")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onStep(1)
            case .decrement: onStep(-1)
            @unknown default: break
            }
        }
    }
}
