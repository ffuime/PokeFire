import Foundation
import Observation

enum AppMode: String {
    case fire, stats, box
}

struct StatsSide: Codable, Equatable {
    var name: String
    var points: [String: Int] = [:]
    var natures: [String: Int] = [:]
    var shiny: Bool?

    var isShiny: Bool { shiny ?? false }

    var pokemon: Pokemon? { GameData.shared.pokemons[name] }
    var base: BaseStats { pokemon?.base ?? BaseStats() }

    func point(_ key: StatKey) -> Int { points[key.rawValue] ?? 0 }
    func nature(_ key: StatKey) -> Int { key == .h ? 10 : natures[key.rawValue] ?? 10 }

    func real(_ key: StatKey) -> Int {
        key == .h ? Calc.hpStat(base.h, point(.h)) : Calc.realStat(base[key], point(key), nature(key))
    }
}

struct SpeedBoost: Equatable {
    var ability: String?
    var rank = 0
}

struct StatsHistoryEntry: Codable, Identifiable, Equatable {
    var id: String { key }
    var key: String
    var attacker: StatsSide
    var defender: StatsSide
    var time: Double
    var pinned = false

    var title: String { "\(attacker.name)・\(defender.name)" }
    var date: Date { Date(timeIntervalSince1970: time / 1000) }
}

@Observable
@MainActor
final class StatsModel {
    private struct Saved: Codable {
        var mode: String
        var attacker: StatsSide
        var defender: StatsSide
        var chartCollapsed: Bool
    }

    private static let key = "pokefire-stats"
    private static let historyKey = "pokefire-stats-history"

    var mode: AppMode = .fire
    var attacker = StatsSide(name: "ガブリアス")
    var defender = StatsSide(name: "メガリザードンX")
    var chartCollapsed = false
    var considerAbilities = true
    var history: [StatsHistoryEntry] = []
    var pendingPage: Role?
    var boxAtRoot = true
    var speedBoosts: [Role: SpeedBoost] = [:]
    @ObservationIgnored private var historyTask: Task<Void, Never>?

    var isStats: Bool { mode == .stats }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let list = try? JSONDecoder().decode([StatsHistoryEntry].self, from: data) {
            history = list
        }
        guard
            let data = UserDefaults.standard.data(forKey: Self.key),
            let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return }
        mode = AppMode(rawValue: saved.mode) ?? .fire
        attacker = saved.attacker
        defender = saved.defender
        chartCollapsed = saved.chartCollapsed
    }

    private func save() {
        let saved = Saved(mode: mode.rawValue, attacker: attacker, defender: defender, chartCollapsed: chartCollapsed)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func side(_ role: Role) -> StatsSide {
        role == .attacker ? attacker : defender
    }

    private func update(_ role: Role, _ body: (inout StatsSide) -> Void) {
        var side = self.side(role)
        let before = side.name
        body(&side)
        if side.name != before { speedBoosts[role] = nil }
        if role == .attacker {
            attacker = side
        } else {
            defender = side
        }
        save()
        scheduleHistory()
    }

    func enter(from model: AppModel) {
        for role in Role.allCases {
            let source = model.side(role)
            var side = StatsSide(name: source.name)
            side.shiny = source.shiny ? true : nil
            for key in StatKey.baseKeys {
                if let value = source.evs[key] {
                    side.points[key.rawValue] = value.points
                    if key.hasNature { side.natures[key.rawValue] = value.nature }
                }
            }
            if role == .attacker {
                attacker = side
            } else {
                defender = side
            }
        }
        mode = .stats
        save()
        scheduleHistory()
    }

    func openBox() {
        mode = .box
        save()
    }

    func applyBox(_ role: Role, _ entry: BoxPokemon) {
        update(role) { side in
            side.name = entry.name
            side.shiny = entry.isShiny ? true : nil
            side.points = [:]
            side.natures = [:]
            for key in StatKey.baseKeys {
                side.points[key.rawValue] = entry.point(key)
                if key.hasNature { side.natures[key.rawValue] = entry.nature(key) }
            }
        }
        Haptics.play(.medium)
    }

    func exit(page: Role? = nil) {
        mode = .fire
        pendingPage = page
        save()
    }

    private func scheduleHistory() {
        historyTask?.cancel()
        historyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, let self else { return }
            self.recordHistory()
        }
    }

    private func saveHistory() {
        let pinned = history.filter(\.pinned)
        let rest = history.filter { !$0.pinned }.prefix(max(0, Storage.historyLimit - pinned.count))
        history = (pinned + rest).sorted { $0.time > $1.time }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    private func recordHistory() {
        let key = "\(attacker.name)|\(defender.name)"
        let pinned = history.first { $0.key == key }?.pinned ?? false
        let entry = StatsHistoryEntry(key: key, attacker: attacker, defender: defender, time: Date().timeIntervalSince1970 * 1000, pinned: pinned)
        history = [entry] + history.filter { $0.key != key }
        saveHistory()
    }

    func applyHistory(_ entry: StatsHistoryEntry) {
        historyTask?.cancel()
        attacker = entry.attacker
        defender = entry.defender
        save()
        Haptics.play(.medium)
    }

    func togglePin(_ entry: StatsHistoryEntry) {
        guard let index = history.firstIndex(where: { $0.key == entry.key }) else { return }
        history[index].pinned.toggle()
        saveHistory()
        Haptics.play(.light)
    }

    func deleteHistory(_ entry: StatsHistoryEntry) {
        history.removeAll { $0.key == entry.key }
        saveHistory()
        Haptics.play(.medium)
    }

    func select(_ role: Role, _ name: String) {
        guard GameData.shared.pokemons[name] != nil else { return }
        update(role) { side in
            if side.name != name { side.shiny = nil }
            side.name = name
        }
        Haptics.play(.light)
    }

    func setPoints(_ role: Role, _ key: StatKey, _ value: Int) {
        update(role) { $0.points[key.rawValue] = max(0, min(32, value)) }
    }

    func applySpeedLine(_ role: Role, name: String, points: Int, nature: Int) {
        guard GameData.shared.pokemons[name] != nil else { return }
        update(role) { side in
            side.name = name
            side.points = [StatKey.s.rawValue: points]
            side.natures = [StatKey.s.rawValue: nature]
        }
        Haptics.play(.medium)
    }

    func applySpread(_ role: Role, _ points: [Int]) {
        update(role) { side in
            for (index, key) in StatKey.baseKeys.enumerated() where index < points.count {
                side.points[key.rawValue] = max(0, min(32, points[index]))
            }
        }
        Haptics.play(.success)
    }

    func setNature(_ role: Role, _ key: StatKey, _ value: Int) {
        update(role) { $0.natures[key.rawValue] = value }
        Haptics.play(.selection)
    }

    func speedBoost(_ role: Role) -> SpeedBoost {
        speedBoosts[role] ?? SpeedBoost()
    }

    func toggleSpeedAbility(_ role: Role, _ ability: String) {
        var boost = speedBoost(role)
        boost.ability = boost.ability == ability ? nil : ability
        speedBoosts[role] = boost
        Haptics.play(.light)
    }

    func setSpeedRank(_ role: Role, _ rank: Int) {
        var boost = speedBoost(role)
        boost.rank = Calc.clampRank(rank)
        speedBoosts[role] = boost
        Haptics.play(.selection)
    }

    func boostedSpeed(_ role: Role) -> Int {
        let side = self.side(role)
        let boost = speedBoost(role)
        var mods: [Int] = []
        if let ability = boost.ability, let rule = Calc.speedAbilities[ability] { mods.append(rule.mod) }
        return max(1, Calc.applyMod(Calc.applyRank(side.real(.s), boost.rank), Calc.chainMods(mods)))
    }

    func toggleChart() {
        chartCollapsed.toggle()
        save()
        Haptics.play(.light)
    }
}
