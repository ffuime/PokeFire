import Foundation

struct EVState: Equatable, Codable, Hashable {
    var points: Int
    var nature = 10
    var rank = 0
}

struct SideState: Equatable {
    var role: Role
    var name: String
    var types: [String]
    var evs: [StatKey: EVState]
    var ability: String
    var abilityOn = false
    var item = "なし"
    var conditions: [String] = []
    var hpNow = 0
    var hpMax = 0
    var move = ""
    var crit = false
    var powerUp = false
    var hits = 2
    var crits = 0
    var axel: [AxelRow] = Array(repeating: AxelRow(), count: 3)
    var metronome = 1
    var rankBoost = 0
    var fainted = 2
    var flingPower = 130
    var shiny = false
    var boxMoves: [String]?

    var pokemon: Pokemon? { GameData.shared.pokemons[name] }
    var base: BaseStats { pokemon?.base ?? BaseStats() }

    func ev(_ key: StatKey) -> EVState {
        evs[key] ?? EVState(points: 0)
    }

    func real(_ key: StatKey, opponentBaseA: Int? = nil) -> Int {
        let value = ev(key)
        switch key {
        case .h: return Calc.hpStat(base.h, value.points)
        case .vsa: return Calc.realStat(opponentBaseA ?? base.a, value.points, value.nature)
        default: return Calc.realStat(base[key], value.points, value.nature)
        }
    }

    var maxHP: Int { real(.h) }

    var hpRatio: Double {
        let total = maxHP
        return total > 0 ? Double(min(total, max(1, hpNow))) / Double(total) : 1
    }

    static func initial(_ role: Role) -> SideState {
        let evs = Dictionary(uniqueKeysWithValues: Rules.statKeys(role).map { key -> (StatKey, EVState) in
            let points: Int
            switch (role, key) {
            case (.attacker, .h), (.defender, .h): points = 2
            case (.attacker, .a), (.attacker, .vsa), (.attacker, .c): points = 32
            default: points = 0
            }
            return (key, EVState(points: points))
        })
        if role == .attacker {
            return SideState(role: role, name: "ガブリアス", types: ["ドラゴン", "じめん"], evs: evs, ability: "さめはだ", move: "げきりん")
        }
        return SideState(role: role, name: "メガリザードンX", types: ["ほのお", "ドラゴン"], evs: evs, ability: "かたいツメ", item: "メガストーン")
    }
}

struct OrderTab: Identifiable, Equatable {
    let id: Int
    var kind: TabKind
    var snapshot: SideState?
    var weather = "none"
    var field = "none"
    var defRanks: [StatKey: Int]?
    var constant = ConstantState()
}

struct AbilitySnapshot: Equatable {
    var name: String
    var on: Bool
    var toggleable: Bool
}

struct CountsSnapshot: Equatable {
    var hits: Int?
    var crits: Int?
    var axel: [AxelRow]
    var metronome: Int
    var rankBoost = 0
    var fainted = 2
    var flingPower = 130
}

struct SideSnapshot {
    var name: String?
    var types: [String]?
    var evs: [StatKey: EVState] = [:]
    var ability: AbilitySnapshot?
    var item: String?
    var hp: (now: Int, max: Int)?
    var conditions: [Role: [String]] = [:]
    var move: String?
    var weak: Bool?
    var powerUp: Bool?
    var counts: CountsSnapshot?

    mutating func assign(_ other: SideSnapshot) {
        if let name = other.name { self.name = name }
        if let types = other.types { self.types = types }
        for (key, value) in other.evs { evs[key] = value }
        if let ability = other.ability { self.ability = ability }
        if let item = other.item { self.item = item }
        if let hp = other.hp { self.hp = hp }
        for (role, list) in other.conditions { conditions[role] = list }
        if let move = other.move { self.move = move }
        if let weak = other.weak { self.weak = weak }
        if let powerUp = other.powerUp { self.powerUp = powerUp }
        if let counts = other.counts { self.counts = counts }
    }
}

struct ShareTab {
    var kind: TabKind
    var snapshot: SideSnapshot?
    var weather = "none"
    var field = "none"
    var defRanks: [StatKey: Int] = [:]
    var constant = ConstantState()
}

struct ShareData {
    var active: Int
    var weather: String
    var field: String
    var defender: SideSnapshot
    var tabs: [ShareTab]
}

enum EnvironmentInfo {
    static let weathers: [(key: String, label: String, name: String)] = [
        ("none", "なし", ""), ("sun", "にほんばれ", "はれ"), ("rain", "あめ", "あめ"), ("sand", "すなあらし", "すなあらし"), ("snow", "ゆき", "ゆき"),
    ]
    static let variants: [(key: String, label: String, name: String, extreme: String)] = [
        ("harshsun", "おおひでり", "はれ", "おおひでり"), ("heavyrain", "おおあめ", "あめ", "おおあめ"),
        ("winds-sun", "らんきりゅう", "", "らんきりゅう"), ("winds-rain", "らんきりゅう", "", "らんきりゅう"),
        ("winds-sand", "らんきりゅう", "", "らんきりゅう"), ("winds-snow", "らんきりゅう", "", "らんきりゅう"),
    ]

    static func base(_ key: String) -> String {
        switch key {
        case "harshsun": return "sun"
        case "heavyrain": return "rain"
        default: return key.hasPrefix("winds-") ? String(key.dropFirst(6)) : key
        }
    }

    static func options(_ base: String) -> [(key: String, label: String)] {
        let own: [(key: String, label: String)] = weathers.first { $0.key == base }.map { [($0.key, $0.label)] } ?? []
        let extra: [(key: String, label: String)] = base == "sun" ? [("harshsun", "おおひでり")] : base == "rain" ? [("heavyrain", "おおあめ")] : []
        return own + extra + [("winds-\(base)", "らんきりゅう")]
    }

    static func isValid(weather key: String) -> Bool {
        weathers.contains { $0.key == key } || variants.contains { $0.key == key }
    }

    static let fields: [(key: String, label: String, name: String)] = [
        ("none", "なし", ""), ("electric", "エレキ", "エレキ"), ("grass", "グラス", "グラス"), ("psycho", "サイコ", "サイコ"), ("mist", "ミスト", "ミスト"),
    ]

    static func weatherName(_ key: String) -> String {
        variants.first { $0.key == key }?.name ?? weathers.first { $0.key == key }?.name ?? ""
    }

    static func terrainName(_ key: String) -> String {
        fields.first { $0.key == key }?.name ?? ""
    }

    static func field(weather: String, field: String) -> Field {
        Field(weather: weatherName(weather), terrain: terrainName(field), extreme: variants.first { $0.key == weather }?.extreme ?? "")
    }

    static func label(weather key: String) -> String {
        key == "none" ? "天候なし" : variants.first { $0.key == key }?.label ?? weathers.first { $0.key == key }?.label ?? key
    }

    static func label(field key: String) -> String {
        key == "none" ? "フィールドなし" : "\(fields.first { $0.key == key }?.label ?? key)フィールド"
    }
}

enum ShareCodec {
    static let base = "https://ffui.me/poke/fire/"
    static let defaultCounts = [-1, -1, 21, 1, 0, 2, 130]

    static func trimTail(_ list: [JSON]) -> [JSON] {
        var out = list
        while let last = out.last, !last.isTruthy {
            out.removeLast()
        }
        return out
    }

    static func natureMark(_ nature: Int) -> String {
        nature == 11 ? "+" : nature == 9 ? "-" : ""
    }

    static func packEvs(_ side: SideState, withRank: Bool) -> String {
        let keys = Rules.statKeys(side.role)
        var parts = StatKey.shareOrder.map { key -> String in
            guard keys.contains(key), let value = side.evs[key] else { return "" }
            let rank = withRank && key.hasRank && value.rank != 0 ? "r\(value.rank)" : ""
            return "\(value.points)\(key.hasNature ? natureMark(value.nature) : "")\(rank)"
        }
        while let last = parts.last, last.isEmpty {
            parts.removeLast()
        }
        return parts.joined(separator: ".")
    }

    static func unpackEvs(_ code: String) -> [StatKey: EVState] {
        var evs: [StatKey: EVState] = [:]
        let pattern = try? NSRegularExpression(pattern: "^(\\d+)([+-]?)(?:r(-?\\d+))?$")
        for (index, part) in code.split(separator: ".", omittingEmptySubsequences: false).enumerated() where index < StatKey.shareOrder.count {
            let text = String(part)
            let range = NSRange(text.startIndex..., in: text)
            guard let match = pattern?.firstMatch(in: text, range: range) else { continue }
            func group(_ i: Int) -> String? {
                guard let r = Range(match.range(at: i), in: text) else { return nil }
                return String(text[r])
            }
            let points = Int(group(1) ?? "0") ?? 0
            let mark = group(2) ?? ""
            let rank = Int(group(3) ?? "0") ?? 0
            evs[StatKey.shareOrder[index]] = EVState(points: points, nature: mark == "+" ? 11 : mark == "-" ? 9 : 10, rank: rank)
        }
        return evs
    }

    static func abilityState(_ side: SideState) -> (on: Bool, toggleable: Bool) {
        let control = Rules.abilityControl(side.role, side.ability)
        switch control {
        case .locked: return (true, false)
        case .toggle: return (side.abilityOn, true)
        case .changeType, .rank, .environment, .disguise: return (false, true)
        case .hidden: return (false, false)
        }
    }

    static func packSide(_ side: SideState) -> JSON {
        let types = side.types.joined(separator: "/")
        let original = (side.pokemon?.types ?? []).joined(separator: "/")
        let ability = abilityState(side)
        let maxHP = side.maxHP
        var out: [JSON] = [
            JSON(side.name),
            types == original ? JSON(0) : JSON(types),
            JSON(packEvs(side, withRank: side.role == .attacker)),
            JSON(side.ability),
            JSON(ability.on ? 2 : ability.toggleable ? 1 : 0),
            JSON(side.item == "なし" ? "" : side.item),
            side.hpNow < maxHP ? JSON("\(side.hpNow)/\(maxHP)") : JSON(0),
            JSON(side.conditions.joined(separator: "/")),
        ]
        if side.role == .attacker {
            let range = Calc.multiHitRange(side.move, side.ability)
            let bits = side.axel.prefix(3).enumerated().reduce(0) { bits, row in
                bits | (row.element.hit ? 1 << (row.offset * 2) : 0) | (row.element.crit ? 2 << (row.offset * 2) : 0)
            }
            let counts = [range != nil ? side.hits : -1, range != nil ? side.crits : -1, bits, side.metronome, side.rankBoost, side.fainted, side.flingPower]
            out.append(JSON(side.move))
            out.append(JSON((side.crit ? 1 : 0) | (side.powerUp ? 2 : 0)))
            out.append(counts == defaultCounts ? JSON(0) : .array(counts.map { JSON($0) }))
        }
        return .array(trimTail(out))
    }

    static func unpackSide(_ packed: JSON, role: Role) -> SideSnapshot {
        let list = packed.array ?? []
        func item(_ index: Int) -> JSON? { index < list.count ? list[index] : nil }
        func text(_ index: Int) -> String {
            guard let value = item(index) else { return "" }
            if let string = value.string { return string }
            return ""
        }
        let name = text(0)
        let typesText = text(1)
        let abilityState = item(4)?.int ?? 0
        let itemText = text(5)
        let hpText = text(6)
        let conditionsText = text(7)
        var snapshot = SideSnapshot()
        snapshot.name = name
        snapshot.types = typesText.isEmpty ? (GameData.shared.pokemons[name]?.types ?? []) : typesText.split(separator: "/").map(String.init)
        snapshot.ability = AbilitySnapshot(name: text(3), on: abilityState == 2, toggleable: abilityState > 0)
        snapshot.item = itemText.isEmpty ? "なし" : itemText
        if !hpText.isEmpty {
            let parts = hpText.split(separator: "/").compactMap { Int($0) }
            snapshot.hp = parts.count == 2 ? (parts[0], parts[1]) : (1, 1)
        } else {
            snapshot.hp = (1, 1)
        }
        snapshot.conditions[role] = conditionsText.isEmpty ? [] : conditionsText.split(separator: "/").map(String.init)
        snapshot.evs = unpackEvs(text(2))
        if role == .attacker {
            snapshot.move = text(8)
            let flags = item(9)?.int ?? 0
            snapshot.weak = flags & 1 != 0
            snapshot.powerUp = flags & 2 != 0
            let counts = item(10)?.array?.compactMap(\.int) ?? defaultCounts
            let values = counts.count >= 4 ? counts + defaultCounts.dropFirst(counts.count) : defaultCounts
            snapshot.counts = CountsSnapshot(
                hits: values[0] < 0 ? nil : values[0],
                crits: values[1] < 0 ? nil : values[1],
                axel: (0..<3).map { AxelRow(hit: values[2] & (1 << ($0 * 2)) != 0, crit: values[2] & (2 << ($0 * 2)) != 0) },
                metronome: values[3],
                rankBoost: values[4],
                fainted: values[5],
                flingPower: values[6]
            )
        }
        return snapshot
    }

    static func packEnvironment(weather: String, field: String) -> String {
        var parts = [weather == "none" ? "" : weather, field == "none" ? "" : field]
        while let last = parts.last, last.isEmpty {
            parts.removeLast()
        }
        return parts.joined(separator: ".")
    }

    static func unpackEnvironment(_ code: String) -> (weather: String, field: String) {
        let parts = code.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let weather = parts.first ?? ""
        let field = parts.count > 1 ? parts[1] : ""
        let validWeather = EnvironmentInfo.isValid(weather: weather) ? weather : "none"
        let validField = EnvironmentInfo.fields.contains { $0.key == field } ? field : "none"
        return (weather.isEmpty ? "none" : validWeather, field.isEmpty ? "none" : validField)
    }

    static func packRanks(_ ranks: [StatKey: Int]?) -> String {
        Rules.rankKeys(.defender).compactMap { key in
            guard let rank = ranks?[key], rank != 0 else { return nil }
            return "\(key.rawValue)\(rank)"
        }.joined(separator: ".")
    }

    static func unpackRanks(_ code: String) -> [StatKey: Int] {
        var ranks = Dictionary(uniqueKeysWithValues: Rules.rankKeys(.defender).map { ($0, 0) })
        for part in code.split(separator: ".") {
            let text = String(part)
            guard let index = text.firstIndex(where: { $0 == "-" || $0.isNumber }) else { continue }
            let key = String(text[..<index])
            if let stat = StatKey(rawValue: key), let value = Int(text[index...]) {
                ranks[stat] = value
            }
        }
        return ranks
    }

    static func packConstant(_ state: ConstantState) -> JSON {
        var object = JSONObject()
        if state.section != "ratio" { object["section"] = JSON(state.section) }
        if !state.ratios.isEmpty {
            var ratios = JSONObject()
            for ratio in Constants.ratios.values.flatMap({ $0 }).map(\.key) where state.ratios[ratio] != nil && ratios[ratio] == nil {
                ratios[ratio] = JSON(state.ratios[ratio] ?? 0)
            }
            for (key, value) in state.ratios where ratios[key] == nil {
                ratios[key] = JSON(value)
            }
            object["ratios"] = .object(ratios)
        }
        if !state.toxic.isEmpty {
            var toxic = JSONObject()
            for turn in state.toxic.keys.sorted() {
                toxic[String(turn)] = JSON(state.toxic[turn] ?? 0)
            }
            object["toxic"] = .object(toxic)
        }
        if state.fixed != 0 { object["fixed"] = JSON(state.fixed) }
        if !state.inputs.isEmpty {
            object["inputs"] = .array(state.inputs.map { input in
                var entry = JSONObject()
                entry["value"] = JSON(input.value)
                entry["count"] = JSON(input.count)
                return .object(entry)
            })
        }
        return .object(object)
    }

    static func unpackConstant(_ json: JSON?) -> ConstantState {
        var state = ConstantState()
        guard let object = json?.object else { return state }
        if let section = object["section"]?.string { state.section = section }
        for (key, value) in object["ratios"]?.object?.entries ?? [] {
            state.ratios[key] = value.int ?? 0
        }
        for (key, value) in object["toxic"]?.object?.entries ?? [] {
            if let turn = Int(key) { state.toxic[turn] = value.int ?? 0 }
        }
        state.fixed = object["fixed"]?.int ?? 0
        state.inputs = (object["inputs"]?.array ?? []).map { ConstantInput(value: $0["value"]?.int ?? 0, count: $0["count"]?.int ?? 0) }
        return state
    }

    static func expand(_ raw: JSON) -> ShareData? {
        guard let list = raw.array, list.first?.int == 2, list.count >= 2 else { return nil }
        let defender = unpackSide(list[1], role: .defender)
        let tabs = (list.count > 2 ? list[2].array ?? [] : []).map { tab -> ShareTab in
            let parts = tab.array ?? []
            if let code = parts.first?.string {
                let kind: TabKind = code == "h" ? .heel : .damage
                return ShareTab(kind: kind, constant: unpackConstant(parts.count > 1 ? parts[1] : nil))
            }
            let environment = unpackEnvironment(parts.count > 1 ? parts[1].string ?? "" : "")
            return ShareTab(
                kind: .attack,
                snapshot: unpackSide(parts.first ?? .array([]), role: .attacker),
                weather: environment.weather,
                field: environment.field,
                defRanks: unpackRanks(parts.count > 2 ? parts[2].string ?? "" : "")
            )
        }
        let environment = unpackEnvironment(list.count > 4 ? list[4].string ?? "" : "")
        return ShareData(
            active: list.count > 3 ? list[3].int ?? 0 : 0,
            weather: environment.weather,
            field: environment.field,
            defender: defender,
            tabs: tabs
        )
    }

    static func encode(_ json: JSON) -> String? {
        let data = Data(json.serialized().utf8)
        guard let compressed = try? (data as NSData).compressed(using: .zlib) as Data else { return nil }
        return compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ code: String) -> JSON? {
        var text = code.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 {
            text += "="
        }
        guard
            let data = Data(base64Encoded: text),
            let raw = try? (data as NSData).decompressed(using: .zlib) as Data
        else { return nil }
        return try? JSON.parse(raw)
    }

    static func url(code: String) -> URL? {
        URL(string: "\(base)#s=\(code)")
    }

    static func code(from url: URL) -> String? {
        if url.scheme == "pokefire" {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "s" })?.value
        }
        guard let fragment = url.fragment else { return nil }
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2, parts[0] == "s" { return String(parts[1]) }
        }
        return nil
    }
}
