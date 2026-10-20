import Foundation

enum AbilityControl: Equatable {
    case hidden, locked, toggle, changeType, rank, environment, disguise

    var isToggleable: Bool {
        self == .toggle || self == .changeType || self == .rank
    }

    var label: String {
        self == .changeType ? "タイプ変更" : "発動"
    }
}

enum Rules {
    struct Activation {
        let always: Set<String>
        let toggle: Set<String>
        let defaultOn: Set<String>
        let changeType: Set<String>
    }

    static let activation: [Role: Activation] = [
        .attacker: Activation(
            always: [
                "ちからもち", "ヨガパワー", "はりきり", "テクニシャン", "てつのこぶし", "すてみ", "かたいツメ", "がんじょうあご", "メガランチャー", "きれあじ",
                "パンクロック", "スカイスキン", "フェアリースキン", "フリーズスキン", "ドラゴンスキン", "うるおいボイス", "てきおうりょく", "スナイパー", "ちからずく",
                "はがねのせいしん", "フェアリーオーラ", "ほのおのたてがみ", "すいほう", "かたやぶり", "てんねん", "ノーてんき", "すりぬけ", "スキルリンク", "おやこあい",
                "ヘヴィメタル", "ライトメタル", "メガソーラー", "すなのちから", "サンパワー", "ぶきよう", "すいすい", "ようりょくそ", "すなかき", "ゆきかき", "サーフテール",
                "ふゆう", "うなぎのぼり",
            ],
            toggle: [
                "もうか", "しんりょく", "げきりゅう", "むしのしらせ", "こんじょう", "アナライズ", "とうそうしん", "プラス", "マイナス", "もらいび", "はりこみ",
                "かるわざ", "はやあし", "でんきにかえる",
            ],
            defaultOn: [],
            changeType: ["へんげんじざい", "リベロ"]
        ),
        .defender: Activation(
            always: [
                "あついしぼう", "たいねつ", "かんそうはだ", "きよめのしお", "すいほう", "ファーコート", "もふもふ", "はどうのぼうご", "ハードロック", "フィルター",
                "ふゆう", "うなぎのぼり", "ちくでん", "でんきエンジン", "ひらいしん", "ちょすい", "そうしょく", "どしょく", "もらいび", "ぼうおん", "ぼうだん",
                "てんねん", "ノーてんき", "パンクロック", "くさのけがわ", "フェアリーオーラ", "ヘヴィメタル", "ライトメタル", "ぶきよう", "じゅくせい",
                "すいすい", "ようりょくそ", "すなかき", "ゆきかき", "サーフテール",
            ],
            toggle: ["ふしぎなうろこ", "かるわざ", "はやあし", "マルチスケイル"],
            defaultOn: ["マルチスケイル"],
            changeType: []
        ),
    ]

    enum Target {
        case current, opponent
    }

    static let rankAbilities: [String: [(Target, StatKey, Int)]] = [
        "まけんき": [(.current, .a, 2)],
        "かちき": [(.current, .c, 2)],
        "じしんかじょう": [(.current, .a, 1)],
        "せいぎのこころ": [(.current, .a, 1)],
        "ねつこうかん": [(.current, .a, 1)],
        "そうしょく": [(.current, .a, 1)],
        "いかりのつぼ": [(.current, .a, 12)],
        "ぎゃくじょう": [(.current, .c, 1)],
        "ひらいしん": [(.current, .c, 1)],
        "かそく": [(.current, .s, 1)],
        "ふくつのこころ": [(.current, .s, 1)],
        "びびり": [(.current, .s, 1)],
        "でんきエンジン": [(.current, .s, 1)],
        "じきゅうりょく": [(.current, .b, 1)],
        "くだけるよろい": [(.current, .b, -1), (.current, .s, 2)],
        "いかく": [(.opponent, .a, -1)],
        "ぬめぬめ": [(.opponent, .s, -1)],
    ]

    static let weatherAbilities: [String: String] = [
        "ひでり": "sun", "あめふらし": "rain", "すなおこし": "sand", "すなはき": "sand", "ゆきふらし": "snow",
    ]

    static let fieldAbilities: [String: String] = [
        "エレキメイカー": "electric", "グラスメイカー": "grass", "サイコメイカー": "psycho", "ミストメイカー": "mist", "こぼれダネ": "grass",
    ]

    static let disguiseAbility = "ばけのかわ"

    static let intimidateReactions: [String: [(StatKey, Int)]] = [
        "きもったま": [],
        "マイペース": [],
        "どんかん": [],
        "せいしんりょく": [],
        "クリアボディ": [],
        "しろいけむり": [],
        "ミラーアーマー": [],
        "あまのじゃく": [(.a, 1)],
        "まけんき": [(.a, -1), (.a, 2)],
        "かちき": [(.a, -1), (.c, 2)],
        "びびり": [(.a, -1), (.s, 1)],
        "ばんけん": [(.a, 1)],
    ]

    static let rankStatNames: [StatKey: String] = [.a: "こうげき", .b: "ぼうぎょ", .c: "とくこう", .d: "とくぼう", .s: "すばやさ"]

    static func statKeys(_ role: Role) -> [StatKey] {
        role == .attacker ? [.h, .a, .vsa, .c, .b, .s] : [.h, .b, .d, .s]
    }

    static func rankKeys(_ role: Role) -> [StatKey] {
        statKeys(role).filter(\.hasRank)
    }

    static func conditions(_ role: Role) -> [String] {
        role == .attacker ? ["やけど", "じゅうでん", "地面にいる"] : ["リフレクター", "ひかりのかべ", "地面にいる", "無防備状態"]
    }

    static let speedConditionNames = ["まひ", "おいかぜ", "くろいてっきゅう"]

    static func defaultPoints(_ key: StatKey) -> Int {
        switch key {
        case .h: return 2
        case .a, .c: return 32
        default: return 0
        }
    }

    struct StatRule {
        let basestat: [StatKey]
        let evs: [StatKey]
    }

    static let moveStatExceptions: [String: StatRule] = [
        "ボディプレス": StatRule(basestat: [.b], evs: [.b]),
        "イカサマ": StatRule(basestat: [], evs: [.vsa]),
        "いのちがけ": StatRule(basestat: [.h], evs: [.h]),
        "がむしゃら": StatRule(basestat: [.h], evs: [.h]),
    ]
    static let moveStatExtra: [String: [StatKey]] = [
        "エレキボール": [.s],
        "ジャイロボール": [.s],
        "ふんか": [.h],
        "しおふき": [.h],
        "きしかいせい": [.h],
        "じたばた": [.h],
    ]
    static let defenderStatExceptions: [String: StatRule] = [
        "いのちがけ": StatRule(basestat: [.h], evs: [.h]),
        "がむしゃら": StatRule(basestat: [.h], evs: [.h]),
        "いかりのまえば": StatRule(basestat: [.h], evs: [.h]),
        "ちきゅうなげ": StatRule(basestat: [.h], evs: [.h]),
        "ナイトヘッド": StatRule(basestat: [.h], evs: [.h]),
        "サイコショック": StatRule(basestat: [.h, .b], evs: [.h, .b]),
    ]
    static let defenderStatExtra: [String: [StatKey]] = [
        "エレキボール": [.s],
        "ジャイロボール": [.s],
    ]

    static let hpReferenceMoves: Set<String> = ["ふんか", "しおふき", "ドラゴンエナジー", "じたばた", "きしかいせい", "いのちがけ", "がむしゃら"]

    static func statRule(_ role: Role, move: String) -> (basestat: [StatKey], evs: [StatKey]) {
        guard let data = GameData.shared.moves[move] else {
            return role == .attacker ? ([.a], [.a]) : ([.h, .b], [.h, .b])
        }
        let special = data.category == "特殊"
        if role == .attacker {
            let key: StatKey = special ? .c : .a
            let rule = moveStatExceptions[move] ?? StatRule(basestat: [key], evs: [key])
            return (rule.basestat, rule.evs + (moveStatExtra[move] ?? []))
        }
        let key: StatKey = special ? .d : .b
        let rule = defenderStatExceptions[move] ?? StatRule(basestat: [.h, key], evs: [.h, key])
        return (rule.basestat, rule.evs + (defenderStatExtra[move] ?? []))
    }

    static func hasRankAbility(_ role: Role, _ ability: String) -> Bool {
        (rankAbilities[ability] ?? []).contains { target, key, _ in
            rankKeys(target == .current ? role : role.other).contains(key)
        }
    }

    static func abilityControl(_ role: Role, _ ability: String) -> AbilityControl {
        guard let rules = activation[role] else { return .hidden }
        if weatherAbilities[ability] != nil || fieldAbilities[ability] != nil { return .environment }
        if role == .defender, ability == disguiseAbility { return .disguise }
        if rules.changeType.contains(ability) { return .changeType }
        if rules.always.contains(ability) { return .locked }
        if rules.toggle.contains(ability) { return .toggle }
        if hasRankAbility(role, ability) { return .rank }
        return .hidden
    }

    static func defaultAbilityOn(_ role: Role, _ ability: String) -> Bool {
        activation[role]?.defaultOn.contains(ability) ?? false
    }
}

struct ConstantRatio {
    let key: String
    let label: String?
    let ratio: (Int, Int)
    let mode: String
    let examples: [String]

    var title: String { label ?? key }
}

struct ConstantKindInfo {
    let title: String
    let unit: String
    let fixed: Int
    let fixedExample: String
    let sections: [(key: String, label: String)]
}

struct ConstantInput: Equatable, Identifiable {
    var id = UUID()
    var value = 0
    var count = 0
}

struct ConstantState: Equatable {
    var section = "ratio"
    var ratios: [String: Int] = [:]
    var toxic: [Int: Int] = [:]
    var fixed = 0
    var inputs: [ConstantInput] = []
}

enum Constants {
    static let ratios: [TabKind: [ConstantRatio]] = [
        .damage: [
            ConstantRatio(key: "1/32", label: nil, ratio: (1, 32), mode: "floor", examples: ["ステルスロック（いわ1/4倍）"]),
            ConstantRatio(key: "1/16", label: nil, ratio: (1, 16), mode: "floor", examples: ["やけど", "すなあらし", "ステルスロック（いわ1/2倍）"]),
            ConstantRatio(key: "1/10", label: nil, ratio: (1, 10), mode: "floor", examples: ["いのちのたま"]),
            ConstantRatio(key: "1/8", label: nil, ratio: (1, 8), mode: "floor", examples: ["ステルスロック", "どく", "やどりぎのタネ", "まきつく・しめつける等", "まきびし（1回）", "しおづけ", "くっつきバリ", "さめはだ", "てつのトゲ", "かんそうはだ（はれ）", "サンパワー", "ナイトメア"]),
            ConstantRatio(key: "1/6", label: nil, ratio: (1, 6), mode: "floor", examples: ["ゴツゴツメット", "まきびし（2回）"]),
            ConstantRatio(key: "1/4r", label: "1/4（四捨五入）", ratio: (1, 4), mode: "round", examples: ["わるあがき"]),
            ConstantRatio(key: "1/4f", label: "1/4（切り捨て）", ratio: (1, 4), mode: "floor", examples: ["ステルスロック（いわ2倍）", "まきびし（3回）", "のろい", "あくむ", "しおづけ（みず・はがね）", "みがわり"]),
            ConstantRatio(key: "1/2c", label: "1/2（切り上げ）", ratio: (1, 2), mode: "ceil", examples: ["てっていこうせん", "ビックリヘッド", "クロロブラスト"]),
        ],
        .heel: [
            ConstantRatio(key: "1/16f", label: "1/16（切り捨て）", ratio: (1, 16), mode: "floor", examples: ["たべのこし", "くろいヘドロ", "アクアリング", "ねをはる", "グラスフィールド", "あめうけざら", "アイスボディ"]),
            ConstantRatio(key: "1/8f", label: "1/8（切り捨て）", ratio: (1, 8), mode: "floor", examples: ["ポイズンヒール", "かんそうはだ（あめ）"]),
            ConstantRatio(key: "1/4f", label: "1/4（切り捨て）", ratio: (1, 4), mode: "floor", examples: ["オボンのみ", "ちくでん", "ちょすい", "どしょく", "かんそうはだ（みず技）"]),
            ConstantRatio(key: "1/4p", label: "1/4（五捨五超入）", ratio: (1, 4), mode: "poke", examples: ["いのちのしずく", "ジャングルヒール", "あさのひざし・つきのひかり・こうごうせい（はれ以外の天気）"]),
            ConstantRatio(key: "1/4r", label: "1/4（四捨五入）", ratio: (1, 4), mode: "round", examples: []),
            ConstantRatio(key: "1/3f", label: "1/3（切り捨て）", ratio: (1, 3), mode: "floor", examples: ["さいせいりょく", "フィラのみ等"]),
            ConstantRatio(key: "1/2f", label: "1/2（切り捨て）", ratio: (1, 2), mode: "floor", examples: ["ねがいごと"]),
            ConstantRatio(key: "1/2p", label: "1/2（五捨五超入）", ratio: (1, 2), mode: "poke", examples: ["じこさいせい", "はねやすめ", "タマゴうみ", "ミルクのみ", "なまける", "かいふくしれい", "すなあつめ", "あさのひざし・つきのひかり・こうごうせい"]),
            ConstantRatio(key: "1/2r", label: "1/2（四捨五入）", ratio: (1, 2), mode: "round", examples: []),
            ConstantRatio(key: "2/3p", label: "2/3（五捨五超入）", ratio: (2, 3), mode: "poke", examples: ["あさのひざし・つきのひかり・こうごうせい（はれ）", "すなあつめ（すなあらし）"]),
        ],
    ]

    static let kinds: [TabKind: ConstantKindInfo] = [
        .damage: ConstantKindInfo(title: "定数ダメージ", unit: "ダメージ", fixed: 50, fixedExample: "ちきゅうなげ・ナイトヘッド", sections: [("ratio", "割合"), ("toxic", "もうどく"), ("fixed", "固定")]),
        .heel: ConstantKindInfo(title: "定数回復", unit: "回復", fixed: 10, fixedExample: "オレンのみ", sections: [("ratio", "割合"), ("fixed", "固定")]),
    ]

    static let toxicTurns = Array(1...15)

    static func round(_ mode: String, _ value: Int, _ ratio: (Int, Int)) -> Int {
        let (n, d) = ratio
        switch mode {
        case "poke":
            return (value * (n * 4096 / d) + 2047) / 4096
        case "ceil":
            return Int((Double(value * n) / Double(d)).rounded(.up))
        case "round":
            return Int(Calc.jsRound(Double(value * n) / Double(d)))
        default:
            return value * n / d
        }
    }

    static func ratioAmount(_ max: Int, _ ratio: ConstantRatio) -> Int {
        Swift.max(1, round(ratio.mode, max, ratio.ratio))
    }

    static func toxicAmount(_ max: Int, _ turn: Int) -> Int {
        Swift.max(1, max * turn / 16)
    }

    static func breakdown(_ state: ConstantState, kind: TabKind, max: Int) -> ConstantBreakdown {
        guard let info = kinds[kind] else { return ConstantBreakdown(parts: [], total: 0) }
        var parts: [ConstantPart] = []
        func add(_ label: String, _ count: Int, _ amount: Int) {
            if count > 0, amount > 0 { parts.append(ConstantPart(label: "\(label)×\(count)", amount: amount * count)) }
        }
        for ratio in ratios[kind] ?? [] {
            add(ratio.title, state.ratios[ratio.key] ?? 0, ratioAmount(max, ratio))
        }
        if kind == .damage {
            for turn in toxicTurns {
                add("もうどく\(turn)T", state.toxic[turn] ?? 0, toxicAmount(max, turn))
            }
        }
        add("\(info.fixed)", state.fixed, info.fixed)
        for input in state.inputs {
            add("\(input.value)", input.count, input.value)
        }
        return ConstantBreakdown(parts: parts, total: parts.reduce(0) { $0 + $1.amount })
    }
}
