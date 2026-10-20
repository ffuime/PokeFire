import Foundation
import Observation

enum AppMode: String {
    case fire, stats
}

struct StatsSide: Codable, Equatable {
    var name: String
    var points: [String: Int] = [:]
    var natures: [String: Int] = [:]

    var pokemon: Pokemon? { GameData.shared.pokemons[name] }
    var base: BaseStats { pokemon?.base ?? BaseStats() }

    func point(_ key: StatKey) -> Int { points[key.rawValue] ?? 0 }
    func nature(_ key: StatKey) -> Int { key == .h ? 10 : natures[key.rawValue] ?? 10 }

    func real(_ key: StatKey) -> Int {
        key == .h ? Calc.hpStat(base.h, point(.h)) : Calc.realStat(base[key], point(key), nature(key))
    }
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

    var mode: AppMode = .fire
    var attacker = StatsSide(name: "ガブリアス")
    var defender = StatsSide(name: "メガリザードンX")
    var chartCollapsed = false
    var considerAbilities = true

    var isStats: Bool { mode == .stats }

    init() {
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
        body(&side)
        if role == .attacker {
            attacker = side
        } else {
            defender = side
        }
        save()
    }

    func enter(from model: AppModel) {
        for role in Role.allCases {
            let source = model.side(role)
            var side = StatsSide(name: source.name)
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
    }

    func exit() {
        mode = .fire
        save()
    }

    func select(_ role: Role, _ name: String) {
        guard GameData.shared.pokemons[name] != nil else { return }
        update(role) { $0.name = name }
        Haptics.play(.light)
    }

    func setPoints(_ role: Role, _ key: StatKey, _ value: Int) {
        update(role) { $0.points[key.rawValue] = max(0, min(32, value)) }
    }

    func setNature(_ role: Role, _ key: StatKey, _ value: Int) {
        update(role) { $0.natures[key.rawValue] = value }
        Haptics.play(.selection)
    }

    func toggleChart() {
        chartCollapsed.toggle()
        save()
        Haptics.play(.light)
    }
}
