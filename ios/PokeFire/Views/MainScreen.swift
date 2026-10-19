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
    @State private var pulled = false
    @State private var turns = 0

    private var sideTitles: [String] {
        let kind = model.activeTab?.kind ?? .attack
        let attacker = model.isConstantActive ? (Constants.kinds[kind]?.title ?? "") : model.attacker.name
        return [attacker, model.defender.name]
    }

    var body: some View {
        NavigationStack {
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
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x / max(1, geometry.containerSize.width)
            } action: { _, value in
                if value < -0.08, !pulled {
                    pulled = true
                    openDrawer()
                } else if value >= 0, pulled {
                    pulled = false
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                MainHeader(present: { sheet = $0 })
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ResultCard(present: { sheet = $0 })
            }
            .background {
                EnvironmentBackdrop(weather: model.weather, field: model.field)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: openDrawer) {
                        Image("menu")
                            .renderingMode(.template)
                    }
                    .accessibilityLabel("履歴")
                }
                ToolbarItem(placement: .principal) {
                    NativeSegmented(
                        segments: sideTitles.map { .text($0) },
                        selected: (page ?? .attacker) == .attacker ? 0 : 1,
                        fontSize: 13
                    ) { index in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            page = index == 0 ? .attacker : .defender
                        }
                    }
                    .frame(width: 236, height: 34)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        turns += 1
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                            model.swapSides()
                        }
                    } label: {
                        Image("swap")
                            .renderingMode(.template)
                            .rotationEffect(.degrees(Double(turns) * 180))
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: turns)
                    }
                    .disabled(model.isConstantActive)
                    .accessibilityLabel("攻守交代")
                }
            }
        }
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

struct EnvironmentBackdrop: View {
    let weather: String
    let field: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.background
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Palette.environment(weather).opacity(0.42), Palette.background.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.45)
                    .opacity(weather == "none" ? 0 : 1)
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [Palette.background.opacity(0), Palette.environment(field).opacity(0.42)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.45)
                    .opacity(field == "none" ? 0 : 1)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: weather)
        .animation(.easeInOut(duration: 0.5), value: field)
    }
}

struct MainHeader: View {
    let present: (ActiveSheet) -> Void

    var body: some View {
        VStack(spacing: 8) {
            EnvironmentPill { present(.environment) }
            TabStrip()
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}

struct EnvironmentPill: View {
    @Environment(AppModel.self) private var model
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Icon(name: "weather_\(model.weather)", size: 22)
                    .foregroundStyle(Palette.environment(model.weather))
                Text(EnvironmentInfo.label(weather: model.weather))
                Text("・")
                    .foregroundStyle(Palette.secondary.opacity(0.6))
                Icon(name: "field_\(model.field)", size: 22)
                    .foregroundStyle(Palette.environment(model.field))
                Text(EnvironmentInfo.label(field: model.field))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 14)
            .frame(height: 42)
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

    private var items: [TabItem] {
        model.tabs.enumerated().map { index, tab in
            let name = index == model.active ? model.attacker.name : tab.snapshot?.name ?? model.attacker.name
            let title = tab.kind == .attack && !name.isEmpty ? name : tab.kind.shortLabel
            return TabItem(id: tab.id, kind: tab.kind, title: title)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            TabCollection(items: items, active: model.active, model: model)
                .frame(height: 44)

            Menu {
                ForEach([TabKind.attack, .damage, .heel], id: \.self) { kind in
                    Button {
                        model.addTab(kind)
                    } label: {
                        Label {
                            Text(kind.menuLabel)
                        } icon: {
                            tintedImage(kind.icon, Palette.tab(kind))
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
