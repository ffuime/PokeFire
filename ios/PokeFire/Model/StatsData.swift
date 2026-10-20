import Foundation

struct MoveInfo {
    let name: String
    let type: String
    let category: String
    let power: Int?
    let accuracy: Int?
    let pp: Int?
    let effect: String
    let target: String
    let remarks: [String]
    var flags: Set<String> = []
    var priority = 0

    var powerText: String { power.map(String.init) ?? "-" }
    var accuracyText: String { accuracy.map(String.init) ?? "-" }
    var ppText: String { pp.map(String.init) ?? "-" }
}

struct ItemInfo {
    let name: String
    let effect: String
    let mega: Bool
}

final class StatsCatalog {
    static let shared = StatsCatalog()

    let moves: [String: MoveInfo]
    let moveOrder: [String]
    let items: [String: ItemInfo]
    let itemOrder: [String]
    let moveNames: [String: String]
    let itemNames: [String: String]
    let abilityNames: [String: String]

    private init() {
        let json: JSON = {
            guard
                let url = Bundle.main.url(forResource: "stats", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let json = try? JSON.parse(data)
            else { return .object(JSONObject()) }
            return json
        }()

        var moves: [String: MoveInfo] = [:]
        var moveOrder: [String] = []
        for (name, value) in json["moves"]?.object?.entries ?? [] {
            let remarks = (value["remarks"]?.string ?? "")
                .split(whereSeparator: { $0 == "、" || $0 == "," })
                .map { $0.trimmingCharacters(in: .whitespaces) }
            moves[name] = MoveInfo(
                name: name,
                type: value["type"]?.string ?? "",
                category: value["category"]?.string ?? "",
                power: value["power"]?.int,
                accuracy: value["accuracy"]?.int,
                pp: value["pp"]?.int,
                effect: value["effect"]?.string ?? "",
                target: value["target"]?.string ?? "",
                remarks: remarks,
                flags: Set(value["flags"]?.stringList ?? []),
                priority: value["priority"]?.int ?? 0
            )
            moveOrder.append(name)
        }
        self.moves = moves
        self.moveOrder = moveOrder

        var items: [String: ItemInfo] = [:]
        var itemOrder: [String] = []
        for (name, value) in json["items"]?.object?.entries ?? [] {
            items[name] = ItemInfo(name: name, effect: value["effect"]?.string ?? "", mega: value["mega"] != nil)
            itemOrder.append(name)
        }
        self.items = items
        self.itemOrder = itemOrder

        func table(_ key: String) -> [String: String] {
            var map: [String: String] = [:]
            for (from, to) in json["names"]?[key]?.object?.entries ?? [] {
                if let to = to.string { map[from] = to }
            }
            return map
        }
        let usage = GameData.shared.usageNames
        moveNames = usage.moves.merging(table("moves")) { _, new in new }
        itemNames = usage.items.merging(table("items")) { _, new in new }
        abilityNames = usage.abilities.merging(table("abilities")) { _, new in new }
    }

    func moveInfo(_ name: String) -> MoveInfo? {
        if let info = moves[name] { return info }
        guard let move = GameData.shared.moves[name] else { return nil }
        return MoveInfo(name: name, type: move.type, category: move.category, power: move.power, accuracy: nil, pp: nil, effect: move.effect, target: "", remarks: move.remarks)
    }

    func itemEffect(_ name: String) -> String {
        items[name]?.effect ?? GameData.shared.items[name]?.effect ?? ""
    }
}

enum Natures {
    static let names: [String: String] = [
        "Adamant": "いじっぱり", "Bashful": "てれや", "Bold": "ずぶとい", "Brave": "ゆうかん", "Calm": "おだやか",
        "Careful": "しんちょう", "Docile": "すなお", "Gentle": "おとなしい", "Hardy": "がんばりや", "Hasty": "せっかち",
        "Impish": "わんぱく", "Jolly": "ようき", "Lax": "のうてんき", "Lonely": "さみしがり", "Mild": "おっとり",
        "Modest": "ひかえめ", "Naive": "むじゃき", "Naughty": "やんちゃ", "Quiet": "れいせい", "Quirky": "きまぐれ",
        "Rash": "うっかりや", "Relaxed": "のんき", "Sassy": "なまいき", "Serious": "まじめ", "Timid": "おくびょう",
    ]

    static let stats: [String: StatKey] = [
        "Attack": .a, "Defense": .b, "Sp. Atk": .c, "Sp. Def": .d, "Speed": .s,
    ]
}

enum TypeChart {
    struct Row: Identifiable {
        let id: String
        let label: String
        let icon: String
        let color: UInt32
        let background: UInt32
        let types: [String]
    }

    private static let immune: [String: [String]] = [
        "ふゆう": ["じめん"], "うなぎのぼり": ["じめん"], "どしょく": ["じめん"],
        "ちょすい": ["みず"], "よびみず": ["みず"], "かんそうはだ": ["みず"],
        "ちくでん": ["でんき"], "ひらいしん": ["でんき"], "でんきエンジン": ["でんき"],
        "もらいび": ["ほのお"], "そうしょく": ["くさ"],
    ]

    private static let scaled: [String: [String: Double]] = [
        "あついしぼう": ["ほのお": 0.5, "こおり": 0.5],
        "たいねつ": ["ほのお": 0.5],
        "すいほう": ["ほのお": 0.5],
        "きよめのしお": ["ゴースト": 0.5],
        "もふもふ": ["ほのお": 2],
        "かんそうはだ": ["ほのお": 1.25],
    ]

    private static let superReducers: Set<String> = ["ハードロック", "フィルター", "プリズムアーマー"]

    static func multiplier(_ attack: String, types: [String], abilities: [String]) -> Double {
        let base = types.reduce(1.0) { $0 * (Calc.typeChart[attack]?[$1] ?? 1) }
        var value = base
        for ability in abilities {
            if immune[ability]?.contains(attack) ?? false { value = 0 }
            if let factor = scaled[ability]?[attack] { value *= factor }
        }
        if base > 1, abilities.contains(where: { superReducers.contains($0) }) { value *= 0.75 }
        if abilities.contains("ふしぎなまもり"), base <= 1 { value = 0 }
        return value
    }

    static func label(_ value: Double) -> String {
        if value == 0 { return "×0" }
        if value < 1 {
            let inverse = 1 / value
            if abs(inverse - inverse.rounded()) < 0.0001 { return "×1/\(Int(inverse.rounded()))" }
        }
        return "×" + String(format: "%g", value)
    }

    static func rows(types: [String], abilities: [String]) -> [Row] {
        var buckets: [Double: [String]] = [:]
        for attack in Palette.typeOrder {
            let value = multiplier(attack, types: types, abilities: abilities)
            if abs(value - 1) < 0.0001 { continue }
            buckets[value, default: []].append(attack)
        }
        return buckets.keys.sorted(by: >).map { value in
            let style: (String, UInt32, UInt32)
            switch value {
            case 0: style = ("eff_zero", 0x6B7280, 0xF3F4F6)
            case 4...: style = ("eff_x4", 0xB8433A, 0xFAEFEF)
            case 1...: style = ("eff_x2", 0xC8622A, 0xFCF4EE)
            case 0.5...: style = ("eff_half", 0x3E6FA5, 0xEEF2FA)
            default: style = ("eff_quarter", 0x2A5275, 0xE8EEF6)
            }
            return Row(id: String(value), label: label(value), icon: style.0, color: style.1, background: style.2, types: buckets[value] ?? [])
        }
    }
}

enum LearnsetLoader {
    static let url = URL(string: "https://championsbattledata.com/data/pokemon-index.json")!
    static let ttl: Double = 3 * 24 * 60 * 60 * 1000

    private struct Cache: Codable {
        var fetchedAt: Double
        var moves: [String: [String]]
    }

    private static var file: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("pokefire-learnsets.json")
    }

    private static func readCache() -> Cache? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Cache.self, from: data)
    }

    static func load() async -> [String: [String]]? {
        let cached = readCache()
        if let cached, UsageLoader.nowMillis - cached.fetchedAt < ttl { return cached.moves }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
            let moves = try await Task.detached(priority: .utility) { try parse(data) }.value
            let cache = Cache(fetchedAt: UsageLoader.nowMillis, moves: moves)
            if let encoded = try? JSONEncoder().encode(cache) {
                try? encoded.write(to: file, options: .atomic)
            }
            return moves
        } catch {
            return cached?.moves
        }
    }

    private static func parse(_ data: Data) throws -> [String: [String]] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = root["pokemon"] as? [[String: Any]]
        else { throw URLError(.cannotParseResponse) }
        let names = StatsCatalog.shared.moveNames
        var result: [String: [String]] = [:]
        for entry in list {
            guard let name = entry["name"] as? String, let learnable = entry["learnableMoveNames"] as? [String] else { continue }
            result[name] = learnable.compactMap { names[$0] }
        }
        return result
    }
}
