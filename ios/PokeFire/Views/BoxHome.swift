import SwiftUI

enum BoxRoute: Hashable {
    case pokemon(UUID)
    case team(UUID)
    case member(UUID, Int)
}

enum BoxSort: String, CaseIterable {
    case dex, stats, created, updated

    var title: String {
        switch self {
        case .dex: return "図鑑番号順"
        case .stats: return "種族値順"
        case .created: return "作成順"
        case .updated: return "更新順"
        }
    }
}

struct BoxRoot: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    @State private var path: [BoxRoute] = []
    @State private var tab = 0
    @State private var query = ""
    @AppStorage("pokefire-box-sort") private var boxSort = BoxSort.created.rawValue
    @AppStorage("pokefire-team-sort") private var teamSort = BoxSort.created.rawValue
    @AppStorage("pokefire-box-favorites-first") private var favoritesFirst = false
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<UUID> = []
    @State private var showPicker = false
    @State private var askTeamName = false
    @State private var teamName = ""
    @State private var confirmDelete = false
    @State private var autoPick: UUID?
    @Environment(StatsModel.self) private var stats

    private var editing: Bool { editMode.isEditing }

    private var suggestions: [String] {
        let key = Search.normalize(query)
        guard !key.isEmpty else { return [] }
        let data = model.data
        return data.pokemonOrder.filter { Search.normalize(data.pokemonSearchText($0)).contains(key) }.prefix(8).map { $0 }
    }

    private func matches(_ entry: BoxPokemon) -> Bool {
        let key = Search.normalize(query)
        guard !key.isEmpty else { return true }
        return Search.normalize(entry.name + " " + entry.nickname).contains(key)
    }

    private var pokemons: [BoxPokemon] {
        let sort = BoxSort(rawValue: boxSort) ?? .created
        let data = model.data
        let order = Dictionary(uniqueKeysWithValues: data.pokemonOrder.enumerated().map { ($1, $0) })
        let list = box.pokemons.filter(matches).sorted { lhs, rhs in
            if favoritesFirst, lhs.favorite != rhs.favorite { return lhs.favorite }
            switch sort {
            case .dex:
                return (order[lhs.name] ?? 0, lhs.created) < (order[rhs.name] ?? 0, rhs.created)
            case .stats:
                let left = StatKey.baseKeys.reduce(0) { $0 + lhs.base[$1] }
                let right = StatKey.baseKeys.reduce(0) { $0 + rhs.base[$1] }
                return left != right ? left > right : lhs.created > rhs.created
            case .created:
                return lhs.created > rhs.created
            case .updated:
                return lhs.updated > rhs.updated
            }
        }
        return list
    }

    private var teams: [BoxTeam] {
        let key = Search.normalize(query)
        let sort = BoxSort(rawValue: teamSort) ?? .created
        return box.teams.filter { team in
            guard !key.isEmpty else { return true }
            if Search.normalize(team.name).contains(key) { return true }
            return team.members.compactMap { box.pokemon($0) }.contains { Search.normalize($0.name + " " + $0.nickname).contains(key) }
        }
        .sorted { lhs, rhs in
            if favoritesFirst, lhs.favorite != rhs.favorite { return lhs.favorite }
            return sort == .updated ? lhs.updated > rhs.updated : lhs.created > rhs.created
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $tab) {
                Tab("ボックス", systemImage: "person.crop.square", value: 0) {
                    boxList
                }
                Tab("チーム", systemImage: "rectangle.stack", value: 1) {
                    teamList
                }
            }
            .navigationTitle("PokéBox")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "チーム名またはポケモン名で検索…")
            .searchSuggestions {
                ForEach(suggestions, id: \.self) { name in
                    Label {
                        Text(name)
                    } icon: {
                        SpriteView(name: name, size: 28)
                    }
                    .searchCompletion(name)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppMenuButton(inToolbar: true)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                    Button {
                        withAnimation {
                            editMode = editing ? .inactive : .active
                            selection = []
                        }
                    } label: {
                        Image(systemName: editing ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .accessibilityLabel(editing ? "選択を終了" : "選択")
                }
            }
            .onChange(of: path) { _, value in
                stats.boxAtRoot = value.isEmpty
            }
            .onChange(of: tab) { _, _ in
                selection = []
                editMode = .inactive
            }
            .navigationDestination(for: BoxRoute.self) { route in
                switch route {
                case .pokemon(let id):
                    BoxEditor(ids: [id], start: 0, teamID: nil)
                case .team(let id):
                    TeamDetail(teamID: id, path: $path, autoPick: autoPick == id) {
                        autoPick = nil
                    }
                case .member(let teamID, let index):
                    BoxEditor(ids: box.team(teamID)?.members ?? [], start: index, teamID: teamID)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PokemonPicker(role: .attacker, currentName: "") { name in
                let entry = box.create(name, usage: model.usage)
                path.append(.pokemon(entry.id))
            }
        }
        .sheet(isPresented: $askTeamName) {
            TeamNameSheet(title: "チームを作成", action: "チームを作成", placeholder: box.nextTeamName(), name: $teamName) {
                let team = box.createTeam(teamName)
                autoPick = team.id
                path.append(.team(team.id))
            }
        }
        .confirmationDialog("選択した\(selection.count)件を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                withAnimation {
                    if tab == 0 { box.delete(selection) } else { box.deleteTeams(selection) }
                    selection = []
                    editMode = .inactive
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            if tab == 0 {
                Picker("並び替え", selection: $boxSort) {
                    ForEach(BoxSort.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } else {
                Picker("並び替え", selection: $teamSort) {
                    ForEach([BoxSort.created, .updated], id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section {
                Toggle("お気に入り優先", isOn: $favoritesFirst)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("並び替え")
    }

    private var addButton: some View {
        Button {
            Haptics.play(.light)
            if tab == 0 {
                showPicker = true
            } else {
                teamName = ""
                askTeamName = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .padding(20)
        .accessibilityLabel(tab == 0 ? "ポケモンを追加" : "チームを作成")
    }

    private var editBar: some View {
        HStack(spacing: 12) {
            if tab == 0, (1...6).contains(selection.count) {
                Button {
                    let team = box.createTeam("")
                    box.updateTeam(team.id) { $0.members = pokemons.map(\.id).filter { selection.contains($0) } }
                    selection = []
                    editMode = .inactive
                    tab = 1
                    path.append(.team(team.id))
                } label: {
                    Label("チームを作る", systemImage: "rectangle.stack.badge.plus")
                        .font(.body.weight(.bold))
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                }
                .buttonStyle(.glassProminent)
            }
            Spacer()
            SelectionDeleteButton(count: selection.count) {
                confirmDelete = true
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var bottomControls: some View {
        if editing {
            editBar
        } else {
            addButton
        }
    }

    private var boxList: some View {
        let list = pokemons
        return List(selection: $selection) {
            ForEach(list) { entry in
                NavigationLink(value: BoxRoute.pokemon(entry.id)) {
                    BoxPokemonRow(entry: entry)
                }
                .contextMenu {
                    Button {
                        box.toggleFavorite(entry.id)
                    } label: {
                        Label(entry.favorite ? "お気に入りを解除" : "お気に入り", systemImage: entry.favorite ? "star.slash" : "star")
                    }
                    Button {
                        withAnimation { box.duplicate(entry.id) }
                    } label: {
                        Label("複製", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        withAnimation { box.delete([entry.id]) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { box.delete([entry.id]) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        box.toggleFavorite(entry.id)
                    } label: {
                        Label(entry.favorite ? "解除" : "お気に入り", systemImage: entry.favorite ? "star.slash" : "star.fill")
                    }
                    .tint(.yellow)
                    Button {
                        withAnimation { box.duplicate(entry.id) }
                    } label: {
                        Label("複製", systemImage: "plus.square.on.square")
                    }
                    .tint(Palette.accent)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .onChange(of: selection) { _, value in
            if !editing, !value.isEmpty { selection = [] }
        }
        .overlay {
            if list.isEmpty {
                EmptyResult(text: query.isEmpty ? "＋からポケモンを登録できます" : "見つかりません")
            }
        }
        .overlay(alignment: editing ? .bottom : .bottomTrailing) {
            bottomControls
        }
    }

    private var teamList: some View {
        let list = teams
        return List(selection: $selection) {
            ForEach(list) { team in
                NavigationLink(value: BoxRoute.team(team.id)) {
                    TeamRow(team: team)
                }
                .contextMenu {
                    Button {
                        box.toggleTeamFavorite(team.id)
                    } label: {
                        Label(team.favorite ? "お気に入りを解除" : "お気に入り", systemImage: team.favorite ? "star.slash" : "star")
                    }
                    Button {
                        withAnimation { box.duplicateTeam(team.id) }
                    } label: {
                        Label("複製", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        withAnimation { box.deleteTeams([team.id]) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { box.deleteTeams([team.id]) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        box.toggleTeamFavorite(team.id)
                    } label: {
                        Label(team.favorite ? "解除" : "お気に入り", systemImage: team.favorite ? "star.slash" : "star.fill")
                    }
                    .tint(.yellow)
                    Button {
                        withAnimation { box.duplicateTeam(team.id) }
                    } label: {
                        Label("複製", systemImage: "plus.square.on.square")
                    }
                    .tint(Palette.accent)
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .onChange(of: selection) { _, value in
            if !editing, !value.isEmpty { selection = [] }
        }
        .overlay {
            if list.isEmpty {
                EmptyResult(text: query.isEmpty ? "＋からチームを作成できます" : "見つかりません")
            }
        }
        .overlay(alignment: editing ? .bottom : .bottomTrailing) {
            bottomControls
        }
    }
}

struct FavoriteStar: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(hex: 0xF2B705))
    }
}

struct BoxPokemonRow: View {
    let entry: BoxPokemon

    var body: some View {
        HStack(spacing: 12) {
            SpriteView(name: entry.name, size: 52, shiny: entry.isShiny)
                .frame(width: 52, height: 52)
                .overlay(alignment: .bottomTrailing) {
                    if !entry.item.isEmpty {
                        SpriteIcon(name: entry.item, size: 20)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if entry.favorite { FavoriteStar() }
                }
                if !entry.nickname.isEmpty {
                    Text(entry.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                }
                Text([entry.ability, entry.natureName].filter { !$0.isEmpty }.joined(separator: "・"))
                    .font(.caption)
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(entry.pokemon?.types ?? [], id: \.self) { type in
                    TypeIcon(type: type, size: 22)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct TeamRow: View {
    @Environment(BoxModel.self) private var box
    let team: BoxTeam

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(team.name)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if team.favorite { FavoriteStar() }
            }
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { index in
                    let member = index < team.members.count ? box.pokemon(team.members[index]) : nil
                    ZStack(alignment: .bottomTrailing) {
                        if let member {
                            SpriteView(name: member.name, size: 44, shiny: member.isShiny)
                            if !member.item.isEmpty {
                                SpriteIcon(name: member.item, size: 16)
                            }
                        } else {
                            Circle()
                                .fill(Palette.background)
                                .frame(width: 30, height: 30)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TeamDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    let teamID: UUID
    @Binding var path: [BoxRoute]
    let autoPick: Bool
    let consumedAutoPick: () -> Void
    @State private var showMembers = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var editMode: EditMode = .inactive
    @State private var selection: Set<UUID> = []

    private var editing: Bool { editMode.isEditing }

    var body: some View {
        let team = box.team(teamID)
        let members = (team?.members ?? []).compactMap { box.pokemon($0) }
        List(selection: $selection) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, entry in
                NavigationLink(value: BoxRoute.member(teamID, index)) {
                    BoxPokemonRow(entry: entry)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            box.updateTeam(teamID) { $0.members.removeAll { $0 == entry.id } }
                        }
                    } label: {
                        Label("外す", systemImage: "minus.circle")
                    }
                    .tint(.red)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation {
                            box.updateTeam(teamID) { $0.members.removeAll { $0 == entry.id } }
                        }
                    } label: {
                        Label("チームから外す", systemImage: "minus.circle")
                    }
                }
            }
            .onMove { from, to in
                box.updateTeam(teamID) { $0.members.move(fromOffsets: from, toOffset: to) }
            }
            if members.count < 6, !editing {
                Button {
                    showMembers = true
                } label: {
                    Label("ポケモンを追加", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .onChange(of: selection) { _, value in
            if !editing, !value.isEmpty { selection = [] }
        }
        .navigationTitle(team?.name ?? "チーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    newName = team?.name ?? ""
                    renaming = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("名前を編集")
                Button {
                    withAnimation {
                        editMode = editing ? .inactive : .active
                        selection = []
                    }
                } label: {
                    Image(systemName: editing ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .accessibilityLabel(editing ? "選択を終了" : "選択")
            }
        }
        .overlay(alignment: .bottom) {
            if editing {
                HStack {
                    Spacer()
                    SelectionDeleteButton(count: selection.count, title: "チームから外す", icon: "minus.circle") {
                        withAnimation {
                            box.updateTeam(teamID) { $0.members.removeAll { selection.contains($0) } }
                            selection = []
                            editMode = .inactive
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $renaming) {
            TeamNameSheet(title: "名前を編集", action: "変更", placeholder: team?.name ?? "チーム", name: $newName) {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { box.updateTeam(teamID) { $0.name = trimmed } }
            }
        }
        .sheet(isPresented: $showMembers) {
            MemberPicker(teamID: teamID) { created in
                if let index = box.team(teamID)?.members.firstIndex(of: created) {
                    path.append(.member(teamID, index))
                } else {
                    path.append(.pokemon(created))
                }
            }
        }
        .task {
            if autoPick {
                consumedAutoPick()
                try? await Task.sleep(for: .milliseconds(350))
                showMembers = true
            }
        }
    }
}

struct TeamNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let action: String
    let placeholder: String
    @Binding var name: String
    let onConfirm: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)
            TextField(placeholder, text: $name)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(confirm)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(hex: 0xEEEEF1), in: Capsule())
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Text("キャンセル")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.glass)
                Button(action: confirm) {
                    Text(action)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(230)])
        .presentationDragIndicator(.visible)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            focused = true
        }
    }

    private func confirm() {
        onConfirm()
        dismiss()
    }
}

struct MemberPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(BoxModel.self) private var box
    @Environment(\.dismiss) private var dismiss
    let teamID: UUID
    let onCreated: (UUID) -> Void
    @State private var picked: [UUID] = []
    @State private var showPicker = false

    var body: some View {
        let team = box.team(teamID)
        let existing = Set(team?.members ?? [])
        let room = 6 - existing.count
        let candidates = box.pokemons.filter { !existing.contains($0.id) }.sorted { $0.created > $1.created }
        NavigationStack {
            List {
                Button {
                    showPicker = true
                } label: {
                    Label("あたらしいポケモンを作成", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .disabled(room <= 0)
                Section {
                    ForEach(candidates) { entry in
                        let selected = picked.contains(entry.id)
                        Button {
                            Haptics.play(.selection)
                            if selected {
                                picked.removeAll { $0 == entry.id }
                            } else if picked.count < room {
                                picked.append(entry.id)
                            }
                        } label: {
                            HStack {
                                BoxPokemonRow(entry: entry)
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selected ? Palette.accent : Palette.secondary.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!selected && picked.count >= room)
                    }
                } header: {
                    Text("ボックス（あと\(max(0, room - picked.count))体）")
                }
            }
            .navigationTitle("ポケモンを選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加") {
                        box.updateTeam(teamID) { $0.members.append(contentsOf: picked) }
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(picked.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PokemonPicker(role: .attacker, currentName: "") { name in
                let entry = box.create(name, usage: model.usage)
                box.updateTeam(teamID) { $0.members.append(contentsOf: picked + [entry.id]) }
                dismiss()
                onCreated(entry.id)
            }
        }
    }
}

struct SelectionDeleteButton: View {
    let count: Int
    var title = "削除"
    var icon = "trash"
    let action: () -> Void

    var body: some View {
        let active = count > 0
        Button(role: .destructive, action: action) {
            Label(count > 0 ? "\(title)（\(count)）" : title, systemImage: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(active ? Color.white : Color.red.opacity(0.5))
                .padding(.horizontal, 10)
                .frame(height: 40)
                .contentTransition(.numericText(value: Double(count)))
        }
        .buttonStyle(.glassProminent)
        .tint(active ? .red : Color.red.opacity(0.12))
        .disabled(!active)
        .animation(.snappy(duration: 0.25), value: active)
        .animation(.snappy(duration: 0.25), value: count)
    }
}
