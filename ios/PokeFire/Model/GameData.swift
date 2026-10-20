import Foundation

enum StatKey: String, CaseIterable, Codable, Hashable {
    case h, a, vsa, b, c, d, s

    static let baseKeys: [StatKey] = [.h, .a, .b, .c, .d, .s]
    static let shareOrder: [StatKey] = [.h, .a, .vsa, .b, .c, .d, .s]

    var letter: String {
        switch self {
        case .h: return "H"
        case .a, .vsa: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .s: return "S"
        }
    }

    var title: String {
        switch self {
        case .h: return "HP"
        case .a: return "こうげき"
        case .vsa: return "相手のこうげき"
        case .b: return "ぼうぎょ"
        case .c: return "とくこう"
        case .d: return "とくぼう"
        case .s: return "すばやさ"
        }
    }

    var statName: String {
        switch self {
        case .h: return "HP"
        case .a: return "こうげき"
        case .vsa: return "相手のこうげき"
        case .b: return "ぼうぎょ"
        case .c: return "とくこう"
        case .d: return "とくぼう"
        case .s: return "すばやさ"
        }
    }

    var hasNature: Bool { self != .h }
    var hasRank: Bool { self != .h }
}

struct BaseStats: Equatable {
    var h = 0, a = 0, b = 0, c = 0, d = 0, s = 0

    subscript(key: StatKey) -> Int {
        switch key {
        case .h: return h
        case .a, .vsa: return a
        case .b: return b
        case .c: return c
        case .d: return d
        case .s: return s
        }
    }
}

struct Pokemon {
    let name: String
    let num: String
    let types: [String]
    let abilities: [String]
    let base: BaseStats
    let weight: Double
    let form: Int?

    var spriteURL: URL? {
        URL(string: "https://pokesol.app/api/images/assets/pokemons/\(num)\(form.map { $0 > 0 ? "_0\($0)" : "" } ?? "").png")
    }
}

struct Move {
    let name: String
    let type: String
    let category: String
    let power: Int?
    let powerText: String
    let effect: String
    let remarks: [String]
}

struct Effect {
    let name: String
    let effect: String
}

struct UsageNames {
    var pokemons: [String: String] = [:]
    var moves: [String: String] = [:]
    var abilities: [String: String] = [:]
    var items: [String: String] = [:]
    var pokemonOrder: [String] = []
}

final class GameData {
    static let shared = GameData()

    let pokemons: [String: Pokemon]
    let pokemonOrder: [String]
    let moves: [String: Move]
    let moveOrder: [String]
    let abilities: [String: Effect]
    let abilityOrder: [String]
    let items: [String: Effect]
    let itemOrder: [String]
    let aliases: [String: [String: [String]]]
    let usageNames: UsageNames
    private var megaParentCache: [String: String] = [:]
    private var formsCache: [String: [String]] = [:]
    private var searchCache: [String: String] = [:]

    private init() {
        func load(_ name: String) -> JSON {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let json = try? JSON.parse(data)
            else { return .object(JSONObject()) }
            return json
        }

        var pokemons: [String: Pokemon] = [:]
        var pokemonOrder: [String] = []
        for (name, value) in load("pokemons").object?.entries ?? [] {
            let stats = value["basestats"]
            let base = BaseStats(
                h: stats?["h"]?.int ?? 0,
                a: stats?["a"]?.int ?? 0,
                b: stats?["b"]?.int ?? 0,
                c: stats?["c"]?.int ?? 0,
                d: stats?["d"]?.int ?? 0,
                s: stats?["s"]?.int ?? 0
            )
            pokemons[name] = Pokemon(
                name: name,
                num: value["num"]?.string ?? "",
                types: value["types"]?.stringList ?? [],
                abilities: value["abilities"]?.stringList ?? [],
                base: base,
                weight: value["weight"]?.double ?? 0,
                form: value["form"]?.int
            )
            pokemonOrder.append(name)
        }
        self.pokemons = pokemons
        self.pokemonOrder = pokemonOrder

        var moves: [String: Move] = [:]
        var moveOrder: [String] = []
        for (name, value) in load("moves").object?.entries ?? [] {
            let power = value["power"]?.int
            let powerText = power.map(String.init) ?? value["power"]?.string ?? "-"
            let remarks = (value["remarks"]?.string ?? "")
                .split(whereSeparator: { $0 == "、" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespaces) }
            moves[name] = Move(
                name: name,
                type: value["type"]?.string ?? "",
                category: value["category"]?.string ?? "",
                power: power,
                powerText: powerText,
                effect: value["effect"]?.string ?? "",
                remarks: remarks
            )
            moveOrder.append(name)
        }
        self.moves = moves
        self.moveOrder = moveOrder

        func effects(_ file: String) -> ([String: Effect], [String]) {
            var map: [String: Effect] = [:]
            var order: [String] = []
            for (name, value) in load(file).object?.entries ?? [] {
                map[name] = Effect(name: name, effect: value["effect"]?.string ?? "")
                order.append(name)
            }
            return (map, order)
        }
        let abilityData = effects("abilities")
        abilities = abilityData.0
        abilityOrder = abilityData.1
        var itemData = effects("items")
        for (name, value) in load("stats")["items"]?.object?.entries ?? [] where itemData.0[name] == nil && value["mega"] == nil {
            itemData.0[name] = Effect(name: name, effect: value["effect"]?.string ?? "")
            itemData.1.append(name)
        }
        items = itemData.0
        itemOrder = itemData.1

        var aliases: [String: [String: [String]]] = [:]
        for (kind, table) in load("aliases").object?.entries ?? [] {
            var map: [String: [String]] = [:]
            for (name, list) in table.object?.entries ?? [] {
                map[name] = list.stringList
            }
            aliases[kind] = map
        }
        self.aliases = aliases

        let names = load("usage_names")
        func table(_ key: String) -> [String: String] {
            var map: [String: String] = [:]
            for (from, to) in names[key]?.object?.entries ?? [] {
                if let to = to.string { map[from] = to }
            }
            return map
        }
        var usageNames = UsageNames(
            pokemons: table("pokemons"),
            moves: table("moves"),
            abilities: table("abilities"),
            items: table("items")
        )
        usageNames.pokemonOrder = names["pokemons"]?.object?.keys ?? []
        self.usageNames = usageNames
    }

    static func baseName(_ name: String) -> String {
        var result = name
        if let range = result.range(of: "\\(.*\\)$", options: .regularExpression) {
            result.removeSubrange(range)
        }
        if let last = result.last, "XYZ".contains(last) {
            result.removeLast()
        }
        return result
    }

    func megaParent(_ name: String) -> String? {
        guard name.hasPrefix("メガ"), let pokemon = pokemons[name] else { return nil }
        if let cached = megaParentCache[name] { return cached.isEmpty ? nil : cached }
        let rest = String(name.dropFirst(2))
        let candidates = pokemonOrder.filter { other in
            other != name && pokemons[other]?.num == pokemon.num && GameData.baseName(other) == GameData.baseName(rest)
        }
        let parent = candidates.first(where: { $0 == rest }) ?? candidates.first
        megaParentCache[name] = parent ?? ""
        return parent
    }

    func otherForms(of name: String) -> [String] {
        guard let current = pokemons[name] else { return [] }
        if let cached = formsCache[name] { return cached }
        let forms = pokemonOrder.filter { $0 != name && pokemons[$0]?.num == current.num }
        formsCache[name] = forms
        return forms
    }

    func usageName(of name: String) -> String {
        if name.hasPrefix("メガ"), pokemons[name] != nil, let parent = megaParent(name) {
            return parent
        }
        return name
    }

    private func cachedSearch(_ key: String, _ make: () -> String) -> String {
        if let hit = searchCache[key] { return hit }
        let value = make()
        searchCache[key] = value
        return value
    }

    func pokemonSearchText(_ name: String) -> String {
        guard let pokemon = pokemons[name] else { return "" }
        return cachedSearch("p:" + name) { Search.tiers([
            .text(Search.textOf(kind: "pokemons", name: name)),
            .list(pokemon.types),
            .list(pokemon.abilities),
        ]) }
    }

    func moveSearchText(_ name: String) -> String {
        guard let move = moves[name] else { return "" }
        return cachedSearch("m:" + name) { Search.tiers([
            .text(Search.textOf(kind: "moves", name: name)),
            .list([move.type]),
            .list([move.category, Search.categoryReadings[move.category] ?? ""]),
            .text("=\(move.powerText)"),
            .list([move.effect]),
        ]) }
    }

    func effectSearchText(kind: String, _ entry: Effect) -> String {
        cachedSearch("\(kind):" + entry.name) {
            Search.tiers([
                .text(Search.textOf(kind: kind, name: entry.name)),
                .list([entry.effect]),
            ])
        }
    }
}
