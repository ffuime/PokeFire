import SwiftUI

enum ActiveSheet: Identifiable, Hashable {
    case detail, speed, environment, help
    case pokemon(Role)
    case types(Role)
    case move
    case ability(Role)
    case item(Role)

    var id: String {
        switch self {
        case .detail: return "detail"
        case .speed: return "speed"
        case .environment: return "environment"
        case .help: return "help"
        case .pokemon(let role): return "pokemon-\(role.rawValue)"
        case .types(let role): return "types-\(role.rawValue)"
        case .move: return "move"
        case .ability(let role): return "ability-\(role.rawValue)"
        case .item(let role): return "item-\(role.rawValue)"
        }
    }
}

struct MainScreen: View {
    @Environment(AppModel.self) private var model
    let openDrawer: () -> Void

    @State private var page: Role? = .attacker
    @State private var sheet: ActiveSheet?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Role.allCases, id: \.self) { role in
                    SidePanel(role: role, present: { sheet = $0 })
                        .containerRelativeFrame(.horizontal)
                        .id(role)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            MainHeader(page: $page, openDrawer: openDrawer, present: { sheet = $0 })
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ResultCard(present: { sheet = $0 })
        }
        .background(Palette.background.ignoresSafeArea())
        .sheet(item: $sheet) { item in
            sheetContent(item)
        }
        .onChange(of: page) { _, value in
            if value != nil { Haptics.play(.selection) }
        }
    }

    @ViewBuilder
    private func sheetContent(_ item: ActiveSheet) -> some View {
        switch item {
        case .detail:
            DetailSheet(openSpeed: { sheet = .speed })
        case .speed:
            SpeedSheet()
        case .environment:
            EnvironmentSheet()
        case .help:
            HelpView()
        case .pokemon(let role):
            PokemonPicker(role: role)
        case .types(let role):
            TypeSheet(role: role)
        case .move:
            EntrySearchSheet(kind: .moves, role: .attacker)
        case .ability(let role):
            EntrySearchSheet(kind: .abilities, role: role)
        case .item(let role):
            EntrySearchSheet(kind: .items, role: role)
        }
    }
}

struct MainHeader: View {
    @Environment(AppModel.self) private var model
    @Binding var page: Role?
    let openDrawer: () -> Void
    let present: (ActiveSheet) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                CircleIconButton(icon: "history", label: "履歴", action: openDrawer)
                Spacer(minLength: 0)
                EnvironmentPill { present(.environment) }
                Spacer(minLength: 0)
                CircleIconButton(icon: "help", label: "ヘルプ") { present(.help) }
            }
            TabStrip()
            SideSwitcher(page: $page)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Palette.background, location: 0),
                    .init(color: Palette.background.opacity(0.94), location: 0.75),
                    .init(color: Palette.background.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct EnvironmentPill: View {
    @Environment(AppModel.self) private var model
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon(name: "weather_\(model.weather)", size: 16)
                    .foregroundStyle(Palette.environment(model.weather))
                Text(EnvironmentInfo.label(weather: model.weather))
                Text("・")
                    .foregroundStyle(Palette.secondary.opacity(0.6))
                Icon(name: "field_\(model.field)", size: 16)
                    .foregroundStyle(Palette.environment(model.field))
                Text(EnvironmentInfo.label(field: model.field))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .contentShape(Capsule())
            .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .animation(.snappy, value: model.weather)
        .animation(.snappy, value: model.field)
        .accessibilityLabel("天候とフィールド")
    }
}

struct TabStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(model.tabs.enumerated()), id: \.element.id) { index, tab in
                            TabChip(tab: tab, index: index)
                                .id(tab.id)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.tabs.map(\.id))
                }
                .scrollIndicators(.hidden)
                .onChange(of: model.active) { _, value in
                    guard model.tabs.indices.contains(value) else { return }
                    withAnimation(.snappy) {
                        proxy.scrollTo(model.tabs[value].id, anchor: .center)
                    }
                }
            }

            Menu {
                ForEach([TabKind.attack, .damage, .heel], id: \.self) { kind in
                    Button {
                        model.addTab(kind)
                    } label: {
                        Label {
                            Text(kind.menuLabel)
                        } icon: {
                            Image(kind.icon)
                        }
                    }
                }
            } label: {
                Icon(name: "add", size: 18)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("タブを追加")
        }
    }
}

struct TabChip: View {
    @Environment(AppModel.self) private var model
    let tab: OrderTab
    let index: Int

    private var isActive: Bool { index == model.active }

    private var title: String {
        guard tab.kind == .attack else { return tab.kind.shortLabel }
        let name = isActive ? model.attacker.name : tab.snapshot?.name ?? model.attacker.name
        return name.isEmpty ? tab.kind.shortLabel : name
    }

    var body: some View {
        Menu {
            Button {
                model.moveTab(index, by: -1)
            } label: {
                Label {
                    Text("左へ移動")
                } icon: {
                    Image("move_left")
                }
            }
            .disabled(index == 0)
            Button {
                model.moveTab(index, by: 1)
            } label: {
                Label {
                    Text("右へ移動")
                } icon: {
                    Image("move_right")
                }
            }
            .disabled(index >= model.tabs.count - 1)
            Divider()
            Button(role: .destructive) {
                model.removeTab(index)
            } label: {
                Label {
                    Text("削除")
                } icon: {
                    Image(systemName: "xmark")
                }
            }
            .disabled(model.tabs.count <= 1)
        } label: {
            HStack(spacing: 5) {
                Text("\(index + 1)")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(index)))
                Icon(name: tab.kind.icon, size: 14)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 110)
            }
            .foregroundStyle(isActive ? Color.white : Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Capsule())
        } primaryAction: {
            model.activate(index)
        }
        .glassEffect(isActive ? .regular.tint(Palette.tab(tab.kind)).interactive() : .regular.interactive(), in: Capsule())
        .animation(.snappy(duration: 0.25), value: isActive)
        .accessibilityLabel("\(index + 1)番目 \(tab.kind.menuLabel) \(title)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

struct SideSwitcher: View {
    @Environment(AppModel.self) private var model
    @Binding var page: Role?
    @State private var turns = 0

    var body: some View {
        HStack(spacing: 6) {
            sideButton(.attacker)
            Button {
                turns += 1
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    model.swapSides()
                }
            } label: {
                Icon(name: "swap", size: 18)
                    .foregroundStyle(model.isConstantActive ? Palette.secondary.opacity(0.4) : Palette.accent)
                    .rotationEffect(.degrees(Double(turns) * 180))
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: turns)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .disabled(model.isConstantActive)
            .accessibilityLabel("攻守交代")
            sideButton(.defender)
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
    }

    private func sideButton(_ role: Role) -> some View {
        let selected = (page ?? .attacker) == role
        let side = model.side(role)
        let constant = role == .attacker && model.isConstantActive
        let kind = model.activeTab?.kind ?? .attack
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                page = role
            }
        } label: {
            HStack(spacing: 6) {
                if constant {
                    Icon(name: kind.icon, size: 20)
                        .foregroundStyle(Palette.tab(kind))
                        .frame(width: 30, height: 30)
                } else {
                    SpriteView(name: side.name, size: 30)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(role.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(role == .attacker ? Palette.attack : Palette.accent)
                    Text(constant ? Constants.kinds[kind]?.title ?? "" : side.name)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .background {
                if selected {
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .animation(.snappy(duration: 0.25), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ResultCard: View {
    @Environment(AppModel.self) private var model
    let present: (ActiveSheet) -> Void

    var body: some View {
        let output = model.output
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                NumberText(output.percentText)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                NumberText(output.damageText)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                NumberText("/ \(output.hp.max)", value: Double(output.hp.max))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondary)
            }

            DamageBar(sure: output.sureRatio, maybe: output.maybeRatio, color: Palette.hp(output.sureRatio))

            HStack(spacing: 8) {
                Button {
                    Haptics.play(.light)
                    present(.speed)
                } label: {
                    Icon(name: "speed", size: 19)
                        .foregroundStyle(Palette.rankDown)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("すばやさ比較")

                if output.multi {
                    Text("\(model.tabs.count)件の加算")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                        .contentTransition(.numericText(value: Double(model.tabs.count)))
                }

                Spacer(minLength: 8)

                NumberText(output.summary.text)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.rankDown)
                if let rate = output.summary.rate {
                    NumberText(rate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .animation(.snappy, value: output.summary.rate)
        }
        .padding(16)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            Haptics.play(.light)
            present(.detail)
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .contextMenu {
            Button {
                present(.detail)
            } label: {
                Label {
                    Text("ダメージの詳細")
                } icon: {
                    Image("chevron_up")
                }
            }
            Button {
                present(.speed)
            } label: {
                Label {
                    Text("すばやさ比較")
                } icon: {
                    Image("speed")
                }
            }
            if let url = model.shareURL() {
                ShareLink(item: url) {
                    Label {
                        Text("計算条件を共有")
                    } icon: {
                        Image("share")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップでダメージの詳細")
    }
}
