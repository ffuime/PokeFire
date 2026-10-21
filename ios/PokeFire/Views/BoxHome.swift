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
                Tab("ボックス", systemImage: "square.grid.2x2", value: 0) {
                    boxList
                }
                Tab("チーム", systemImage: "person.3", value: 1) {
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
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AppMenuButton()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                    Button(editing ? "完了" : "選択") {
                        withAnimation {
                            editMode = editing ? .inactive : .active
                            selection = []
                        }
                    }
                }
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
        .alert("チームを作成", isPresented: $askTeamName) {
            TextField("チーム名（任意）", text: $teamName)
            Button("キャンセル", role: .cancel) {}
            Button("チームを作成") {
                let team = box.createTeam(teamName)
                autoPick = team.id
                path.append(.team(team.id))
            }
            .keyboardShortcut(.defaultAction)
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
                    Label("チームを作る", systemImage: "person.3")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glass)
            }
            Spacer()
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("削除", systemImage: "trash")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glass)
            .disabled(selection.isEmpty)
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { box.delete([entry.id]) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { box.deleteTeams([team.id]) }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
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
            SpriteView(name: entry.name, size: 52)
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
                            SpriteView(name: member.name, size: 44)
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

    var body: some View {
        let team = box.team(teamID)
        let members = (team?.members ?? []).compactMap { box.pokemon($0) }
        List {
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
                }
            }
            .onMove { from, to in
                box.updateTeam(teamID) { $0.members.move(fromOffsets: from, toOffset: to) }
            }
            if members.count < 6 {
                Button {
                    showMembers = true
                } label: {
                    Label("ポケモンを追加", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(team?.name ?? "チーム")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newName = team?.name ?? ""
                        renaming = true
                    } label: {
                        Label("名前を変更", systemImage: "pencil")
                    }
                    EditButton()
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .alert("チーム名", isPresented: $renaming) {
            TextField("チーム名", text: $newName)
            Button("キャンセル", role: .cancel) {}
            Button("変更") {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { box.updateTeam(teamID) { $0.name = trimmed } }
            }
            .keyboardShortcut(.defaultAction)
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
