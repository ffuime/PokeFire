import Foundation
import Observation

struct NatureInfo {
    let name: String
    let up: StatKey?
    let down: StatKey?
}

enum NatureTable {
    static let all: [NatureInfo] = [
        NatureInfo(name: "さみしがり", up: .a, down: .b), NatureInfo(name: "いじっぱり", up: .a, down: .c),
        NatureInfo(name: "やんちゃ", up: .a, down: .d), NatureInfo(name: "ゆうかん", up: .a, down: .s),
        NatureInfo(name: "ずぶとい", up: .b, down: .a), NatureInfo(name: "わんぱく", up: .b, down: .c),
        NatureInfo(name: "のうてんき", up: .b, down: .d), NatureInfo(name: "のんき", up: .b, down: .s),
        NatureInfo(name: "ひかえめ", up: .c, down: .a), NatureInfo(name: "おっとり", up: .c, down: .b),
        NatureInfo(name: "うっかりや", up: .c, down: .d), NatureInfo(name: "れいせい", up: .c, down: .s),
        NatureInfo(name: "おだやか", up: .d, down: .a), NatureInfo(name: "おとなしい", up: .d, down: .b),
        NatureInfo(name: "しんちょう", up: .d, down: .c), NatureInfo(name: "なまいき", up: .d, down: .s),
        NatureInfo(name: "おくびょう", up: .s, down: .a), NatureInfo(name: "せっかち", up: .s, down: .b),
        NatureInfo(name: "ようき", up: .s, down: .c), NatureInfo(name: "むじゃき", up: .s, down: .d),
        NatureInfo(name: "がんばりや", up: nil, down: nil), NatureInfo(name: "すなお", up: nil, down: nil),
        NatureInfo(name: "てれや", up: nil, down: nil), NatureInfo(name: "きまぐれ", up: nil, down: nil),
        NatureInfo(name: "まじめ", up: nil, down: nil),
    ]

    static func named(_ name: String) -> NatureInfo? {
        all.first { $0.name == name }
    }

    static func name(up: StatKey?, down: StatKey?) -> String? {
        guard let up, let down else { return nil }
        return all.first { $0.up == up && $0.down == down }?.name
    }
}

struct BoxPokemon: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var nickname = ""
    var points: [String: Int] = [:]
    var up: StatKey?
    var down: StatKey?
    var neutral = false
    var moves: [String] = ["", "", "", ""] {
        didSet {
            while moves.count < 4 { moves.append("") }
        }
    }
    var ability = ""
    var item = ""
    var favorite = false
    var shiny: Bool?
    var created = Date().timeIntervalSince1970
    var updated = Date().timeIntervalSince1970

    static let pointLimit = 66

    var isShiny: Bool { shiny ?? false }

    var pokemon: Pokemon? { GameData.shared.pokemons[name] }
    var base: BaseStats { pokemon?.base ?? BaseStats() }
    var title: String { nickname.isEmpty ? name : nickname }

    func point(_ key: StatKey) -> Int { points[key.rawValue] ?? 0 }
    var totalPoints: Int { StatKey.baseKeys.reduce(0) { $0 + point($1) } }

    func nature(_ key: StatKey) -> Int {
        if key == up { return 11 }
        if key == down { return 9 }
        return 10
    }

    func real(_ key: StatKey) -> Int {
        key == .h ? Calc.hpStat(base.h, point(.h)) : Calc.realStat(base[key], point(key), nature(key))
    }

    var natureName: String {
        if let name = NatureTable.name(up: up, down: down) { return name }
        if neutral, up == nil, down == nil { return "まじめ" }
        var parts: [String] = []
        if let up { parts.append("\(up.letter)↑") }
        if let down { parts.append("\(down.letter)↓") }
        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }

    var filledMoves: [String] { moves.filter { !$0.isEmpty } }
}

struct BoxTeam: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var members: [UUID] = []
    var favorite = false
    var created = Date().timeIntervalSince1970
    var updated = Date().timeIntervalSince1970
}

@Observable
@MainActor
final class BoxModel {
    private struct Saved: Codable {
        var pokemons: [BoxPokemon]
        var teams: [BoxTeam]
    }

    var pokemons: [BoxPokemon] = []
    var teams: [BoxTeam] = []

    private static var file: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pokefire-box.json")
    }

    init() {
        guard
            let data = try? Data(contentsOf: Self.file),
            let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return }
        pokemons = saved.pokemons
        teams = saved.teams
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Saved(pokemons: pokemons, teams: teams)) {
            try? data.write(to: Self.file, options: .atomic)
        }
    }

    func pokemon(_ id: UUID) -> BoxPokemon? {
        pokemons.first { $0.id == id }
    }

    func team(_ id: UUID) -> BoxTeam? {
        teams.first { $0.id == id }
    }

    @discardableResult
    func create(_ name: String, usage: UsageData?) -> BoxPokemon {
        var entry = BoxPokemon(name: name)
        let data = GameData.shared
        if data.usageName(of: name) != name, let first = data.pokemons[name]?.abilities.first {
            entry.ability = first
        } else if let top = usage?.pokemons[name]?.abilities.compactMap(\.name).first {
            entry.ability = top
        } else {
            entry.ability = data.pokemons[name]?.abilities.first ?? ""
        }
        pokemons.append(entry)
        save()
        return entry
    }

    func update(_ id: UUID, _ body: (inout BoxPokemon) -> Void) {
        guard let index = pokemons.firstIndex(where: { $0.id == id }) else { return }
        var entry = pokemons[index]
        body(&entry)
        entry.updated = Date().timeIntervalSince1970
        pokemons[index] = entry
        for teamIndex in teams.indices where teams[teamIndex].members.contains(id) {
            teams[teamIndex].updated = entry.updated
        }
        save()
    }

    func delete(_ ids: Set<UUID>) {
        pokemons.removeAll { ids.contains($0.id) }
        for index in teams.indices {
            teams[index].members.removeAll { ids.contains($0) }
        }
        save()
    }

    func duplicate(_ id: UUID) {
        guard let source = pokemon(id), let index = pokemons.firstIndex(where: { $0.id == id }) else { return }
        var copy = source
        copy.id = UUID()
        copy.favorite = false
        copy.created = Date().timeIntervalSince1970
        copy.updated = copy.created
        pokemons.insert(copy, at: index + 1)
        save()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = pokemons.firstIndex(where: { $0.id == id }) else { return }
        pokemons[index].favorite.toggle()
        save()
    }

    func setPoint(_ id: UUID, _ key: StatKey, _ value: Int) {
        update(id) { entry in
            let others = entry.totalPoints - entry.point(key)
            entry.points[key.rawValue] = max(0, min(32, min(value, BoxPokemon.pointLimit - others)))
        }
    }

    func applySpread(_ id: UUID, _ points: [Int]) {
        update(id) { entry in
            var total = 0
            for (index, key) in StatKey.baseKeys.enumerated() {
                let value = index < points.count ? max(0, min(32, points[index])) : 0
                let allowed = min(value, BoxPokemon.pointLimit - total)
                entry.points[key.rawValue] = allowed
                total += allowed
            }
        }
    }

    func setNature(_ id: UUID, _ key: StatKey, _ value: Int, usage: [NatureUsage]) {
        update(id) { entry in
            entry.neutral = false
            switch value {
            case 11:
                let hadDown = entry.down
                entry.up = key
                if entry.down == key { entry.down = nil }
                if hadDown == nil || entry.down == nil {
                    entry.down = usage.first { $0.up == key && $0.down != nil }?.down
                }
            case 9:
                let hadUp = entry.up
                entry.down = key
                if entry.up == key { entry.up = nil }
                if hadUp == nil || entry.up == nil {
                    entry.up = usage.first { $0.down == key && $0.up != nil }?.up
                }
            default:
                if entry.up == key { entry.up = nil }
                if entry.down == key { entry.down = nil }
            }
        }
    }

    func setNatureNamed(_ id: UUID, _ name: String) {
        guard let info = NatureTable.named(name) else { return }
        update(id) { entry in
            entry.up = info.up
            entry.down = info.down
            entry.neutral = info.up == nil
        }
    }

    func nextTeamName() -> String {
        var number = teams.count + 1
        while teams.contains(where: { $0.name == "チーム\(number)" }) { number += 1 }
        return "チーム\(number)"
    }

    @discardableResult
    func createTeam(_ name: String) -> BoxTeam {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let team = BoxTeam(name: trimmed.isEmpty ? nextTeamName() : trimmed)
        teams.append(team)
        save()
        return team
    }

    func updateTeam(_ id: UUID, _ body: (inout BoxTeam) -> Void) {
        guard let index = teams.firstIndex(where: { $0.id == id }) else { return }
        body(&teams[index])
        teams[index].updated = Date().timeIntervalSince1970
        save()
    }

    func deleteTeams(_ ids: Set<UUID>) {
        teams.removeAll { ids.contains($0.id) }
        save()
    }

    func duplicateTeam(_ id: UUID) {
        guard let source = team(id), let index = teams.firstIndex(where: { $0.id == id }) else { return }
        var copy = source
        copy.id = UUID()
        copy.name = source.name + " のコピー"
        copy.favorite = false
        copy.created = Date().timeIntervalSince1970
        copy.updated = copy.created
        teams.insert(copy, at: index + 1)
        save()
    }

    func toggleTeamFavorite(_ id: UUID) {
        guard let index = teams.firstIndex(where: { $0.id == id }) else { return }
        teams[index].favorite.toggle()
        save()
    }
}
