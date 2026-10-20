import Foundation

struct Adjustment: Codable, Equatable {
    var points: Int
    var nature: Int
}

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: String { key }
    var key: String
    var attackers: [String]
    var defender: String
    var moves: [String]
    var judge: String
    var rate: String
    var data: String
    var time: Double
    var pinned = false

    var title: String { "\(attackers.joined(separator: "・")) → \(defender)" }
    var date: Date { Date(timeIntervalSince1970: time / 1000) }
}

struct UsagePair: Codable, Equatable {
    var name: String?
    var pct: Double
}

struct NatureUsage: Codable, Equatable {
    var name: String?
    var pct: Double
    var up: StatKey?
    var down: StatKey?
}

struct SpreadUsage: Codable, Equatable {
    var pct: Double
    var points: [Int]
}

struct UsageEntry: Codable, Equatable {
    var rank: Int
    var moves: [UsagePair]
    var abilities: [UsagePair]
    var items: [UsagePair]
    var rawItems: [UsagePair] = []
    var natures: [NatureUsage] = []
    var spreads: [SpreadUsage] = []
}

struct UsageData: Codable, Equatable {
    var fetchedAt: Double
    var season: String
    var date: String
    var pokemons: [String: UsageEntry]
}

enum Storage {
    private static let defaults = UserDefaults.standard
    static let adjustmentsKey = "pokefire-adjustments"
    static let pokemonHistoryKey = "pokefire-pokemon-history"
    static let historyKey = "pokefire-history"
    static let usageKey = "pokefire-usage-v4"
    static let sessionKey = "pokefire-session"
    static let moveHistoryKey = "pokefire-move-history"
    static let itemHistoryKey = "pokefire-item-history"
    static let historyLimit = 60

    private static func read<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    static var adjustments: [String: [String: Adjustment]] {
        get { read([String: [String: Adjustment]].self, adjustmentsKey) ?? [:] }
        set { write(newValue, adjustmentsKey) }
    }

    static var pokemonHistory: [String] {
        get { read([String].self, pokemonHistoryKey) ?? [] }
        set { write(newValue, pokemonHistoryKey) }
    }

    static func rememberPokemon(_ name: String) {
        pokemonHistory = Array(([name] + pokemonHistory.filter { $0 != name }).prefix(30))
    }

    static var moveHistory: [String] {
        get { read([String].self, moveHistoryKey) ?? [] }
        set { write(newValue, moveHistoryKey) }
    }

    static var itemHistory: [String] {
        get { read([String].self, itemHistoryKey) ?? [] }
        set { write(newValue, itemHistoryKey) }
    }

    static func rememberMove(_ name: String) {
        moveHistory = Array(([name] + moveHistory.filter { $0 != name }).prefix(30))
    }

    static func forgetPokemon(_ name: String) {
        pokemonHistory.removeAll { $0 == name }
    }

    static func forgetMove(_ name: String) {
        moveHistory.removeAll { $0 == name }
    }

    static func forgetItem(_ name: String) {
        itemHistory.removeAll { $0 == name }
    }

    static func rememberItem(_ name: String) {
        guard name != "なし" else { return }
        itemHistory = Array(([name] + itemHistory.filter { $0 != name }).prefix(30))
    }

    static var history: [HistoryEntry] {
        get { read([HistoryEntry].self, historyKey) ?? [] }
        set {
            let pinned = newValue.filter(\.pinned)
            let rest = newValue.filter { !$0.pinned }.prefix(max(0, historyLimit - pinned.count))
            write((pinned + rest).sorted { $0.time > $1.time }, historyKey)
        }
    }

    static var usage: UsageData? {
        get { read(UsageData.self, usageKey) }
        set {
            if let newValue { write(newValue, usageKey) }
        }
    }

    static var session: String? {
        get { defaults.string(forKey: sessionKey) }
        set { defaults.set(newValue, forKey: sessionKey) }
    }
}

enum UsageLoader {
    static let source = URL(string: "https://championsbattledata.com")!
    static let megaStone = "メガストーン"
    static let ttl: Double = 6 * 60 * 60 * 1000

    static var nowMillis: Double { Date().timeIntervalSince1970 * 1000 }

    static func load() async -> UsageData? {
        let cached = Storage.usage
        if let cached, nowMillis - cached.fetchedAt < ttl { return cached }
        do {
            let fresh = try await fetch()
            Storage.usage = fresh
            return fresh
        } catch {
            return cached
        }
    }

    private static func getJSON(_ path: String) async throws -> JSON {
        guard let url = URL(string: path, relativeTo: source) else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        return try JSON.parse(data)
    }

    private static func fetch() async throws -> UsageData {
        let names = GameData.shared.usageNames
        let catalog = StatsCatalog.shared
        var fireItems = names.items
        for (en, ja) in catalog.itemNames where !(catalog.items[ja]?.mega ?? false) && fireItems[en] == nil {
            fireItems[en] = ja
        }
        let index = try await getJSON("/data/meta/index.json")
        guard let season = index["seasons"]?.array?.first(where: { season in
            (season["formats"]?.stringList.contains("Singles") ?? false) && !(season["dates"]?.array?.isEmpty ?? true)
        }), let seasonName = season["season"].flatMap({ $0.string ?? $0.int.map(String.init) }),
              let date = season["dates"]?.array?.first?.string else { throw URLError(.cannotParseResponse) }
        let day = try await getJSON("/data/meta/\(seasonName)/\(date)/Singles.json")
        func pairs(_ rows: JSON?, _ table: [String: String]) -> [UsagePair] {
            (rows?.array ?? []).map { row in
                UsagePair(name: row[0]?.string.flatMap { table[$0] }, pct: row[1]?.double ?? 0)
            }
        }
        func items(_ rows: JSON?) -> [UsagePair] {
            var order: [String] = []
            var merged: [String: Double] = [:]
            for (index, row) in (rows?.array ?? []).enumerated() {
                let name = row[0]?.string ?? ""
                let pct = row[1]?.double ?? 0
                let ja: String
                if let mapped = fireItems[name] {
                    ja = mapped
                } else if name.range(of: "ite( [XYZ])?$", options: .regularExpression) != nil {
                    ja = megaStone
                } else {
                    ja = "?\(index)"
                }
                if merged[ja] == nil { order.append(ja) }
                merged[ja, default: 0] += pct
            }
            return order.enumerated()
                .sorted { lhs, rhs in
                    let left = merged[lhs.element] ?? 0
                    let right = merged[rhs.element] ?? 0
                    return left != right ? left > right : lhs.offset < rhs.offset
                }
                .map { UsagePair(name: $0.element.hasPrefix("?") ? nil : $0.element, pct: Calc.jsRound((merged[$0.element] ?? 0) * 10) / 10) }
        }
        var pokemons: [String: UsageEntry] = [:]
        for ja in names.pokemonOrder {
            guard let en = names.pokemons[ja], let entry = day["pokemon"]?[en] else { continue }
            pokemons[ja] = UsageEntry(
                rank: entry["position"]?.int ?? Int.max,
                moves: pairs(entry["move"], catalog.moveNames),
                abilities: pairs(entry["ability"], catalog.abilityNames),
                items: items(entry["held_item"]),
                rawItems: pairs(entry["held_item"], catalog.itemNames),
                natures: (entry["stat_alignment"]?.array ?? []).map { row in
                    NatureUsage(
                        name: row[0]?.string.flatMap { Natures.names[$0] },
                        pct: row[1]?.double ?? 0,
                        up: row[2]?.string.flatMap { Natures.stats[$0] },
                        down: row[3]?.string.flatMap { Natures.stats[$0] }
                    )
                },
                spreads: (entry["stat_points"]?.array ?? []).map { row in
                    SpreadUsage(pct: row[0]?.double ?? 0, points: (1...6).map { row[$0]?.int ?? 0 })
                }
            )
        }
        return UsageData(fetchedAt: nowMillis, season: seasonName, date: date, pokemons: pokemons)
    }
}
