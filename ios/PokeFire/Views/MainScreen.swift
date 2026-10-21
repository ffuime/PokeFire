import SwiftUI

enum ActiveSheet: Identifiable, Hashable {
    case detail, speed, environment, help
    case pokemon(Role)
    case types(Role)
    case move
    case ability(Role)
    case item(Role)
    case statsPokemon(Role)
    case abilityInfo(Role, String)
    case moveInfo(String)
    case itemInfo(String)
    case learnset(Role)
    case statsSpeed
    case speedLine(Role)
    case boxImport(Role)

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
        case .statsPokemon(let role): return "stats-pokemon-\(role.rawValue)"
        case .abilityInfo(let role, let name): return "ability-info-\(role.rawValue)-\(name)"
        case .moveInfo(let name): return "move-info-\(name)"
        case .itemInfo(let name): return "item-info-\(name)"
        case .learnset(let role): return "learnset-\(role.rawValue)"
        case .statsSpeed: return "stats-speed"
        case .speedLine(let role): return "speed-line-\(role.rawValue)"
        case .boxImport(let role): return "box-import-\(role.rawValue)"
        }
    }
}

struct MainScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    let openDrawer: () -> Void

    @State private var page: Role? = .attacker
    @State private var sheet: ActiveSheet?
    @State private var progress: CGFloat = 0
    @State private var pulled = false
    @State private var showEnvironment = false

    private func present(_ item: ActiveSheet) {
        sheet = item
    }

    private func closeEnvironment() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            showEnvironment = false
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(Role.allCases, id: \.self) { role in
                    Group {
                        if stats.isStats {
                            StatsPanel(role: role, present: { present($0) })
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        } else {
                            SidePanel(role: role, present: { present($0) })
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                    }
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
            progress = value
            if value < -0.08, !pulled {
                pulled = true
                openDrawer()
            } else if value >= 0, pulled {
                pulled = false
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            MainHeader(page: $page, progress: progress, openDrawer: openDrawer, present: { present($0) })
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !stats.isStats {
                ResultCard(present: { present($0) })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background {
            EnvironmentBackdrop(weather: stats.isStats ? "none" : model.weather, field: stats.isStats ? "none" : model.field)
        }
        .sheet(item: $sheet) { item in
            sheetContent(item)
        }
        .onChange(of: page) { _, value in
            if value != nil { Haptics.play(.selection) }
        }
        .onChange(of: stats.pendingPage) { _, value in
            guard let value else { return }
            stats.pendingPage = nil
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page = value }
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
        case .statsPokemon(let role):
            PokemonPicker(role: role, currentName: stats.side(role).name) { stats.select(role, $0) }
        case .abilityInfo(let role, let name):
            AbilityInfoSheet(role: role, name: name)
        case .moveInfo(let name):
            MoveInfoSheet(name: name)
        case .itemInfo(let name):
            ItemInfoSheet(name: name)
        case .learnset(let role):
            LearnsetSheet(role: role)
        case .statsSpeed:
            SpeedSheet(statsMode: true)
        case .speedLine(let role):
            SpeedLineSheet(currentName: stats.side(role).name, currentSpeed: stats.side(role).real(.s)) { entry in
                stats.applySpeedLine(role, name: entry.name, points: entry.tier.points, nature: entry.tier.nature)
                return true
            }
        case .boxImport(let role):
            BoxImportSheet { entry in
                if stats.isStats {
                    stats.applyBox(role, entry)
                } else {
                    model.applyBox(entry, to: role)
                }
            }
        }
    }
}

struct EnvironmentPanel: View {
    @Environment(AppModel.self) private var model
    let close: () -> Void
    @State private var dragY: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("天候").sectionTitle()
                Spacer()
                Text(EnvironmentInfo.label(weather: model.weather))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.environment(model.weather))
            }
            EnvironmentSegments(kind: "weather", keys: EnvironmentInfo.weathers.map { $0.key }, selected: model.weather) { model.setWeather($0) }
            HStack {
                Text("フィールド").sectionTitle()
                Spacer()
                Text(EnvironmentInfo.label(field: model.field))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.environment(model.field))
            }
            .padding(.top, 6)
            EnvironmentSegments(kind: "field", keys: EnvironmentInfo.fields.map { $0.key }, selected: model.field) { model.setField($0) }
            Capsule()
                .fill(Palette.secondary.opacity(0.35))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.16), radius: 28, y: 10)
        )
        .offset(y: min(0, dragY))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    dragY = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height < -40 || value.predictedEndTranslation.height < -120 {
                        close()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragY = 0
                    }
                }
        )
    }
}

struct RankBoostPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SegmentBar(count: Calc.rankBoostLimit, value: model.rankBoostTotal, color: Palette.accent) {
            model.setRankBoostTotal($0)
        }
        .padding(16)
        .frame(width: 320)
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
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Binding var page: Role?
    let progress: CGFloat
    let openDrawer: () -> Void
    let present: (ActiveSheet) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AppMenuButton(openHistory: openDrawer)
                Spacer(minLength: 0)
                if stats.isStats {
                    Text("PokéStats")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Palette.accent)
                        .frame(height: 42)
                        .transition(.opacity)
                } else {
                    EnvironmentPill { present(.environment) }
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                Color.clear.frame(width: 44, height: 44)
            }
            if !stats.isStats {
                TabStrip()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            SideSwitcher(page: $page, progress: progress)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let down = value.translation.height
                    if !stats.isStats, down > 44, down > abs(value.translation.width) * 1.4 {
                        Haptics.play(.light)
                        present(.environment)
                    }
                }
        )
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
    @State private var confirmReset = false

    private var items: [TabItem] {
        model.tabs.enumerated().map { index, tab in
            let name = index == model.active ? model.attacker.name : tab.snapshot?.name ?? model.attacker.name
            let title = tab.kind == .attack && !name.isEmpty ? name : tab.kind.shortLabel
            return TabItem(id: tab.id, kind: tab.kind, title: title)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            TabCollection(items: items, active: model.active, model: model) {
                confirmReset = true
            }
            .frame(height: 44)
            .confirmationDialog("すべての条件をリセットしますか？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("リセット", role: .destructive) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        model.resetAll()
                    }
                }
            } message: {
                Text("タブ・ポケモン・調整・天候・フィールドが初期状態に戻ります。")
            }

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

struct SideSwitcher: View {
    @Environment(AppModel.self) private var model
    @Environment(StatsModel.self) private var stats
    @Binding var page: Role?
    let progress: CGFloat
    @State private var turns = 0
    @State private var dragX: CGFloat?
    @State private var pendingTarget: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let swapWidth: CGFloat = stats.isStats ? 0 : 44
            let spacing: CGFloat = stats.isStats ? 0 : 4
            let side = max(1, (geometry.size.width - swapWidth - spacing * 2) / 2)
            let travel = side + swapWidth + spacing * 2
            let settled = min(1, max(0, pendingTarget ?? progress)) * travel
            let lensX = dragX.map { min(max(0, $0 - side / 2), travel) } ?? settled
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.045))
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: side - 4, height: geometry.size.height - 8)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .scaleEffect(dragX == nil ? 1 : 1.08)
                    .offset(x: lensX + 2)
                HStack(spacing: spacing) {
                    sideLabel(.attacker)
                        .frame(width: side)
                    if !stats.isStats {
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
                            .frame(width: swapWidth, height: swapWidth)
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(model.isConstantActive)
                    .accessibilityLabel("攻守交代")
                    }
                    sideLabel(.defender)
                        .frame(width: side)
                }
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragX = value.location.x
                    }
                    .onEnded { value in
                        if abs(value.translation.height) > 20, abs(value.translation.height) > abs(value.translation.width) {
                            dragX = nil
                            return
                        }
                        let target: Role = value.location.x < geometry.size.width / 2 ? .attacker : .defender
                        let goal: CGFloat = target == .attacker ? 0 : 1
                        pendingTarget = abs(progress - goal) < 0.02 ? nil : goal
                        dragX = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(900))
                            pendingTarget = nil
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            page = target
                        }
                    }
            )
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.8), value: lensX)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragX == nil)
        }
        .frame(height: 50)
        .onChange(of: progress) { _, value in
            if let goal = pendingTarget, abs(value - goal) < 0.02 {
                pendingTarget = nil
            }
        }
    }

    private func sideLabel(_ role: Role) -> some View {
        let name = stats.isStats ? stats.side(role).name : model.side(role).name
        let constant = !stats.isStats && role == .attacker && model.isConstantActive
        let kind = model.activeTab?.kind ?? .attack
        return HStack(spacing: 6) {
            if constant {
                Icon(name: kind.icon, size: 20)
                    .foregroundStyle(Palette.tab(kind))
                    .frame(width: 30, height: 30)
            } else {
                SpriteView(name: name, size: 30)
            }
            VStack(alignment: .leading, spacing: 0) {
                if !constant, !stats.isStats {
                    Text(role.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(role == .attacker ? Palette.attack : Palette.accent)
                }
                Text(constant ? Constants.kinds[kind]?.title ?? "" : name)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let up = -value.translation.height
                    if up > 36, up > abs(value.translation.width) * 1.2 {
                        Haptics.play(.light)
                        present(.detail)
                    }
                }
        )
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
