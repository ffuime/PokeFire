import Foundation

enum Role: String, CaseIterable, Codable, Hashable {
    case attacker, defender

    var other: Role { self == .attacker ? .defender : .attacker }
    var title: String { self == .attacker ? "攻撃側" : "防御側" }
}

enum TabKind: String, Codable, Hashable {
    case attack, damage, heel

    var shortLabel: String {
        switch self {
        case .attack: return "攻撃"
        case .damage: return "ダメージ"
        case .heel: return "回復"
        }
    }

    var menuLabel: String {
        switch self {
        case .attack: return "ポケモンの攻撃"
        case .damage: return "定数ダメージ"
        case .heel: return "定数回復"
        }
    }

    var icon: String {
        switch self {
        case .attack: return "tab_attack"
        case .damage: return "tab_damage"
        case .heel: return "tab_heel"
        }
    }
}

struct AxelRow: Codable, Equatable, Hashable {
    var hit = true
    var crit = false
}

struct StatValue: Equatable {
    var real: Int
    var points: Int
    var rank: Int
    var nature: Int
}

struct Field: Equatable {
    var weather = ""
    var terrain = ""
}

struct Fighter {
    var role: Role = .attacker
    var name = ""
    var base = BaseStats()
    var types: [String] = []
    var ability = ""
    var abilityOn = false
    var item = ""
    var conditions: [String] = []
    var crit = false
    var hits: Int?
    var crits: Int?
    var axel: [AxelRow] = []
    var metronome: Int?
    var powerUp = false
    var move = ""
    var evs: [StatKey: StatValue] = [:]
    var hpNow = 0
    var speedConditions: [String] = []
    var speedAbility: Bool?
    var rankBoost = 0
    var fainted = 2
    var flingPower = 130
    var single = false
}

struct Note: Hashable {
    let label: String
    let mul: Double
    let good: Bool
}

struct PlanRow: Equatable {
    var power: Int?
    var crit: Bool
    var hit = true
}

struct OwnContext {
    var attack: Int
    var bpMods: [Int]
    var technicianIndex: Int
    var finalMod: Int
}

struct CalcContext {
    var atk: Fighter
    var eff: Double
    var isCrit: Bool
    var weatherMod: Int
    var bpMods: [Int]
    var technicianIndex: Int
    var attack: Int
    var defense: Int
    var stab: Int
    var burn: Bool
    var finalMod: Int
    var own: OwnContext
}

struct CalcInfo {
    var moveType = ""
    var category = ""
    var isContact = false
    var notes: [Note] = []
    var basePower: Int?
    var displayPower: Int?
    var offenseKey: StatKey?
    var defenseKey: StatKey?
    var firepower: Int?
    var plan: [PlanRow]?
    var failed = false
}

enum CalcStatus {
    case ok, nomove, status, unsupported, immune
}

struct CalcResult {
    var status: CalcStatus
    var message = ""
    var hits: [[Int]] = []
    var info: CalcInfo?
    var ctx: CalcContext?
    var fixed = false

    static func fail(_ status: CalcStatus, _ message: String) -> CalcResult {
        CalcResult(status: status, message: message)
    }

    var isOK: Bool { status == .ok }
}

struct ConstantPart: Hashable {
    let label: String
    let amount: Int
}

struct ConstantBreakdown {
    var parts: [ConstantPart]
    var total: Int
}

struct CalcEntry {
    var tabID: Int
    var kind: TabKind
    var atk: Fighter?
    var def: Fighter?
    var field: Field?
    var result: CalcResult?
    var constant: ConstantBreakdown?
}

struct HPInfo: Equatable {
    var max: Int
    var now: Int
}

struct Summary: Equatable {
    var text: String
    var rate: String?
    var min: Int
    var max: Int
}

struct HPEffect: Identifiable {
    var id: String { name }
    let name: String
    var p: [Int]
    let max: Int
    var lo: Int { p.min() ?? 0 }
    var hi: Int { p.max() ?? 0 }
}

struct CounterRow: Identifiable {
    var id: String { name }
    let name: String
    let mult: Double
    let text: String
    let percent: String
    let ratios: [Double]
}

struct AdjustCell {
    let label: String
    let points: Int?
    let real: Int
}

struct AdjustRowData {
    let ko: AdjustCell?
    let h: AdjustCell?
    let wall: AdjustCell
}

struct AdjustTable {
    let offenseKey: StatKey
    let defenseKey: StatKey
    let rows: [AdjustRowData]
}

enum Calc {
    static let level = 50

    static let typeChart: [String: [String: Double]] = [
        "ノーマル": ["いわ": 0.5, "ゴースト": 0, "はがね": 0.5],
        "ほのお": ["ほのお": 0.5, "みず": 0.5, "くさ": 2, "こおり": 2, "むし": 2, "いわ": 0.5, "ドラゴン": 0.5, "はがね": 2],
        "みず": ["ほのお": 2, "みず": 0.5, "くさ": 0.5, "じめん": 2, "いわ": 2, "ドラゴン": 0.5],
        "くさ": ["ほのお": 0.5, "みず": 2, "くさ": 0.5, "どく": 0.5, "じめん": 2, "ひこう": 0.5, "むし": 0.5, "いわ": 2, "ドラゴン": 0.5, "はがね": 0.5],
        "でんき": ["みず": 2, "くさ": 0.5, "でんき": 0.5, "じめん": 0, "ひこう": 2, "ドラゴン": 0.5],
        "こおり": ["ほのお": 0.5, "みず": 0.5, "くさ": 2, "こおり": 0.5, "じめん": 2, "ひこう": 2, "ドラゴン": 2, "はがね": 0.5],
        "かくとう": ["ノーマル": 2, "こおり": 2, "どく": 0.5, "ひこう": 0.5, "エスパー": 0.5, "むし": 0.5, "いわ": 2, "ゴースト": 0, "あく": 2, "はがね": 2, "フェアリー": 0.5],
        "どく": ["くさ": 2, "どく": 0.5, "じめん": 0.5, "いわ": 0.5, "ゴースト": 0.5, "はがね": 0, "フェアリー": 2],
        "じめん": ["ほのお": 2, "くさ": 0.5, "でんき": 2, "どく": 2, "ひこう": 0, "むし": 0.5, "いわ": 2, "はがね": 2],
        "ひこう": ["くさ": 2, "でんき": 0.5, "かくとう": 2, "むし": 2, "いわ": 0.5, "はがね": 0.5],
        "エスパー": ["かくとう": 2, "どく": 2, "エスパー": 0.5, "あく": 0, "はがね": 0.5],
        "むし": ["ほのお": 0.5, "くさ": 2, "かくとう": 0.5, "どく": 0.5, "ひこう": 0.5, "エスパー": 2, "ゴースト": 0.5, "あく": 2, "はがね": 0.5, "フェアリー": 0.5],
        "いわ": ["ほのお": 2, "こおり": 2, "かくとう": 0.5, "じめん": 0.5, "ひこう": 2, "むし": 2, "はがね": 0.5],
        "ゴースト": ["ノーマル": 0, "エスパー": 2, "ゴースト": 2, "あく": 0.5],
        "ドラゴン": ["ドラゴン": 2, "はがね": 0.5, "フェアリー": 0],
        "あく": ["かくとう": 0.5, "エスパー": 2, "ゴースト": 2, "あく": 0.5, "フェアリー": 0.5],
        "はがね": ["ほのお": 0.5, "みず": 0.5, "でんき": 0.5, "こおり": 2, "いわ": 2, "はがね": 0.5, "フェアリー": 2],
        "フェアリー": ["ほのお": 0.5, "かくとう": 2, "どく": 0.5, "ドラゴン": 2, "あく": 2, "はがね": 0.5],
    ]

    static let secondaryMoves: Set<String> = [
        "Gのちから", "10まんボルト", "3ぼんのや", "アイアンテール", "アイアンヘッド", "アクアステップ", "アクアブレイク", "あくのはどう", "アシッドボム", "いびき",
        "いわなだれ", "うたかたのアリア", "うらみつらみ", "エアスラッシュ", "エナジーボール", "エレキネット", "オーラぐるま", "かえんほうしゃ", "かえんボール", "かかとおとし",
        "かげぬい", "かみくだく", "かみつく", "かみなり", "かみなりのキバ", "かみなりパンチ", "がんせきアックス", "がんせきふうじ", "きあいだま", "キラースピン", "くさわけ",
        "クロスポイズン", "げんしのちから", "こうそくスピン", "こおりのキバ", "こごえるかぜ", "ゴッドバード", "コメットパンチ", "サイコキネシス", "サイコノイズ", "シェルアームズ",
        "シェルブレード", "しおづけ", "じごくづき", "しっとのほのお", "じならし", "しねんのずつき", "シャカシャカほう", "シャドーボール", "じゃれつく", "じんつうりき",
        "ソウルクラッシュ", "だいちのちから", "だいもんじ", "たきのぼり", "だくりゅう", "ダストシュート", "チャージビーム", "つららおとし", "とびかかる", "とびつく", "とびはねる",
        "トライアタック", "トロピカルキック", "でんじほう", "ナイトバースト", "どくづき", "どくどくのキバ", "どくばりセンボン", "ドラゴンダイブ", "ドラムアタック", "どろかけ",
        "ニトロチャージ", "ねこだまし", "のしかかり", "ねっさのだいち", "ねっとう", "ねっぷう", "はいよるいちげき", "はがねのつばさ", "ばくれつパンチ", "はやてがえし",
        "バリアーラッシュ", "バークアウト", "ひけん・ちえなみ", "ひゃっきやこう", "ひやみず", "ひょうざんおろし", "びりびりちくちく", "フェイタルクロー", "ぶきみなじゅもん", "ふぶき",
        "フリーズドライ", "フレアソング", "フレアドライブ", "ブレイククロー", "ブレイズキック", "ふんえん", "ヘドロウェーブ", "ヘドロばくだん", "ほうでん", "ぼうふう",
        "ほっぺすりすり", "ほのおのキバ", "ほのおのパンチ", "ほのおのまい", "ほのおのムチ", "ボルテッカー", "マジカルフレイム", "マッドショット", "みずあめボム", "みずのはどう",
        "みわくのボイス", "むしのさざめき", "むしのていこう", "ムーンフォース", "ラスターカノン", "りんごさん", "ルミナコリジョン", "れいとうパンチ", "れいとうビーム", "れんごく",
        "ローキック", "ワイドブレイカー",
    ]

    static let recoilMoves: Set<String> = [
        "ウェーブタックル", "ウッドハンマー", "かかとおとし", "サンダーダイブ", "すてみタックル", "とびひざげり", "はめつのひかり", "フレアドライブ", "ブレイブバード", "ボルテッカー",
        "もろはのずつき", "ワイルドボルト",
    ]

    static let recoilRatio: [String: Double] = [
        "ウェーブタックル": 1.0 / 3, "ウッドハンマー": 1.0 / 3, "すてみタックル": 1.0 / 3, "フレアドライブ": 1.0 / 3, "ブレイブバード": 1.0 / 3, "ボルテッカー": 1.0 / 3,
        "もろはのずつき": 1.0 / 2, "はめつのひかり": 1.0 / 2, "ワイルドボルト": 1.0 / 4,
    ]

    static let drainRatio: [String: Double] = [
        "ウッドホーン": 1.0 / 2, "ギガドレイン": 1.0 / 2, "きゅうけつ": 1.0 / 2, "シャカシャカほう": 1.0 / 2, "ドレインパンチ": 1.0 / 2, "パラボラチャージ": 1.0 / 2,
        "むねんのつるぎ": 1.0 / 2, "ドレインキッス": 3.0 / 4,
    ]

    static let selfKOMoves: Set<String> = ["じばく", "だいばくはつ", "ミストバースト", "いのちがけ"]

    static let fixedMultiHit: [String: [Int]] = [
        "ダブルアタック": [35, 35],
        "ダブルウイング": [40, 40],
        "ツインビーム": [40, 40],
        "ドラゴンアロー": [50, 50],
        "トリプルアクセル": [20, 40, 60],
        "ネズミざん": Array(repeating: 20, count: 10),
    ]

    static let variableMultiHit: Set<String> = ["スイープビンタ", "スケイルショット", "タネマシンガン", "つららばり", "ボーンラッシュ", "ミサイルばり", "みずしゅりけん", "ロックブラスト"]
    static let ohkoMoves: Set<String> = ["じわれ", "ぜったいれいど", "つのドリル", "ハサミギロチン"]
    static let unsupportedMoves: Set<String> = ["カウンター", "ほうふく", "ミラーコート", "メタルバースト", "はきだす", "ふくろだたき"]
    static let alwaysCritMoves: Set<String> = ["こおりのいぶき", "トリックフラワー", "やまあらし"]
    static let screenBreakMoves: Set<String> = ["かわらわり", "サイコファング", "レイジングブル"]
    static let axelPowers = [20, 40, 60]

    enum PowerUpKind {
        case base, power, damage, custom
    }

    struct PowerUp {
        let kind: PowerUpKind
        var mod = 0
        var label: String?
    }

    static let powerUpMoves: [String: PowerUp] = [
        "しっぺがえし": PowerUp(kind: .base), "じだんだ": PowerUp(kind: .base), "やけっぱち": PowerUp(kind: .base), "ダメおし": PowerUp(kind: .base),
        "ゆきなだれ": PowerUp(kind: .base), "たたりめ": PowerUp(kind: .base), "ひゃっきやこう": PowerUp(kind: .base), "どくばりセンボン": PowerUp(kind: .base),
        "きまぐレーザー": PowerUp(kind: .base), "りんしょう": PowerUp(kind: .base),
        "アクロバット": PowerUp(kind: .base), "はたきおとす": PowerUp(kind: .custom),
        "からげんき": PowerUp(kind: .power, mod: 8192), "うっぷんばらし": PowerUp(kind: .power, mod: 8192), "ベノムショック": PowerUp(kind: .power, mod: 8192),
        "Gのちから": PowerUp(kind: .power, mod: 6144),
        "じしん": PowerUp(kind: .damage, label: "地中状態"), "なみのり": PowerUp(kind: .damage, label: "水中状態"), "うずしお": PowerUp(kind: .damage, label: "水中状態"),
        "サンダーダイブ": PowerUp(kind: .damage), "ドラゴンダイブ": PowerUp(kind: .damage), "のしかかり": PowerUp(kind: .damage),
        "ヒートスタンプ": PowerUp(kind: .damage), "ヘビーボンバー": PowerUp(kind: .damage), "フライングプレス": PowerUp(kind: .damage),
    ]

    static let halfBerries: [String: String] = [
        "オッカのみ": "ほのお", "イトケのみ": "みず", "ソクノのみ": "でんき", "リンドのみ": "くさ", "ヤチェのみ": "こおり", "ヨプのみ": "かくとう",
        "ビアーのみ": "どく", "シュカのみ": "じめん", "バコウのみ": "ひこう", "ウタンのみ": "エスパー", "タンガのみ": "むし", "ヨロギのみ": "いわ",
        "カシブのみ": "ゴースト", "ハバンのみ": "ドラゴン", "ナモのみ": "あく", "リリバのみ": "はがね", "ロゼルのみ": "フェアリー", "ホズのみ": "ノーマル",
    ]
    static let ragingBullTypes = ["パルデアケンタロス(かくとう)": "かくとう", "パルデアケンタロス(ほのお)": "ほのお", "パルデアケンタロス(みず)": "みず"]
    static let skinAbilities = ["スカイスキン": "ひこう", "フェアリースキン": "フェアリー", "フリーズスキン": "こおり", "ドラゴンスキン": "ドラゴン", "エレキスキン": "でんき"]
    static let plateItems: [String: String] = [
        "ひのたまプレート": "ほのお", "しずくプレート": "みず", "いかずちプレート": "でんき", "みどりのプレート": "くさ", "つららのプレート": "こおり",
        "こぶしのプレート": "かくとう", "もうどくプレート": "どく", "だいちのプレート": "じめん", "あおぞらプレート": "ひこう", "ふしぎのプレート": "エスパー",
        "たまむしプレート": "むし", "がんせきプレート": "いわ", "もののけプレート": "ゴースト", "りゅうのプレート": "ドラゴン", "こわもてプレート": "あく",
        "こうてつプレート": "はがね", "せいれいプレート": "フェアリー",
    ]
    static let orbItems: [String: (owner: String, types: [String])] = [
        "こころのしずく": ("ラティ", ["エスパー", "ドラゴン"]),
        "こんごうだま": ("ディアルガ", ["ドラゴン", "はがね"]), "だいこんごうだま": ("ディアルガ", ["ドラゴン", "はがね"]),
        "しらたま": ("パルキア", ["ドラゴン", "みず"]), "だいしらたま": ("パルキア", ["ドラゴン", "みず"]),
        "はっきんだま": ("ギラティナ", ["ドラゴン", "ゴースト"]), "だいはっきんだま": ("ギラティナ", ["ドラゴン", "ゴースト"]),
    ]

    static func highestStat(_ p: Fighter) -> StatKey {
        let keys: [StatKey] = [.a, .b, .c, .d, .s]
        func value(_ key: StatKey) -> Int { p.evs[key]?.real ?? realStat(p.base[key], 0, 10) }
        var best = StatKey.a
        for key in keys where value(key) > value(best) { best = key }
        return best
    }
    static let typeBoostItems: [String: String] = [
        "シルクのスカーフ": "ノーマル", "もくたん": "ほのお", "しんぴのしずく": "みず", "きせきのタネ": "くさ", "じしゃく": "でんき",
        "とけないこおり": "こおり", "くろおび": "かくとう", "どくバリ": "どく", "やわらかいすな": "じめん", "するどいくちばし": "ひこう",
        "まがったスプーン": "エスパー", "ぎんのこな": "むし", "かたいいし": "いわ", "のろいのおふだ": "ゴースト", "りゅうのキバ": "ドラゴン",
        "くろいメガネ": "あく", "メタルコート": "はがね", "ようせいのハネ": "フェアリー",
    ]
    static let pinchAbilities = ["もうか": "ほのお", "しんりょく": "くさ", "げきりゅう": "みず", "むしのしらせ": "むし"]
    static let immuneAbilities: [String: String] = [
        "ちくでん": "でんき", "でんきエンジン": "でんき", "ひらいしん": "でんき",
        "ちょすい": "みず", "かんそうはだ": "みず",
        "もらいび": "ほのお", "そうしょく": "くさ", "どしょく": "じめん",
    ]
    static let terrainTypes = ["エレキ": "でんき", "グラス": "くさ", "サイコ": "エスパー", "ミスト": "フェアリー"]
    static let weatherBallTypes = ["はれ": "ほのお", "あめ": "みず", "すなあらし": "いわ", "ゆき": "こおり"]
    static let weatherNames = ["はれ": "にほんばれ", "あめ": "あめ", "すなあらし": "すなあらし", "ゆき": "ゆき"]

    struct SpeedAbility {
        let mod: Int
        var weather: String?
        var terrain: String?
        var toggle = false
    }

    static let speedAbilities: [String: SpeedAbility] = [
        "すいすい": SpeedAbility(mod: 8192, weather: "あめ"),
        "ようりょくそ": SpeedAbility(mod: 8192, weather: "はれ"),
        "すなかき": SpeedAbility(mod: 8192, weather: "すなあらし"),
        "ゆきかき": SpeedAbility(mod: 8192, weather: "ゆき"),
        "サーフテール": SpeedAbility(mod: 8192, terrain: "エレキ"),
        "かるわざ": SpeedAbility(mod: 8192, toggle: true),
        "はやあし": SpeedAbility(mod: 6144, toggle: true),
    ]

    static func chainMods(_ mods: [Int]) -> Int {
        mods.reduce(4096) { ($0 * $1 + 2048) / 4096 }
    }

    static func applyMod(_ value: Int, _ mod: Int) -> Int {
        (value * mod + 2047) / 4096
    }

    static func rankRatio(_ rank: Int) -> Double {
        rank >= 0 ? Double(2 + rank) / 2 : 2 / Double(2 - rank)
    }

    static func applyRank(_ value: Int, _ rank: Int) -> Int {
        rank >= 0 ? value * (2 + rank) / 2 : value * 2 / (2 - rank)
    }

    static func clampRank(_ rank: Int) -> Int {
        max(-6, min(6, rank))
    }

    static func jsRound(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }

    static func realStat(_ base: Int, _ points: Int, _ nature: Int = 10) -> Int {
        (base + 20 + points) * nature / 10
    }

    static func hpStat(_ base: Int, _ points: Int) -> Int {
        base + 75 + points
    }

    static func multiHitRange(_ move: String, _ ability: String) -> (min: Int, max: Int, def: Int)? {
        if move == "ネズミざん" { return (1, 10, 10) }
        if let fixed = fixedMultiHit[move], move != "トリプルアクセル" { return (fixed.count, fixed.count, fixed.count) }
        if !variableMultiHit.contains(move) { return nil }
        return ability == "スキルリンク" ? (5, 5, 5) : (2, 5, 2)
    }

    static let flingPowers = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 130]
    static let rankBoostMoves: Set<String> = ["アシストパワー", "つけあがる"]
    static let rankBoostLimit = 42

    static func rankBoostKey(_ move: String) -> StatKey {
        GameData.shared.moves[move]?.category == "物理" ? .a : .c
    }

    static func rankSum(_ atk: Fighter) -> Int {
        max(0, atk.evs[rankBoostKey(atk.move)]?.rank ?? 0)
    }

    static func hitPlan(_ atk: Fighter) -> [PlanRow]? {
        if atk.move == "トリプルアクセル" {
            let rows = atk.axel.isEmpty ? axelPowers.map { _ in AxelRow() } : atk.axel
            return rows.prefix(axelPowers.count).enumerated()
                .map { PlanRow(power: axelPowers[$0.offset], crit: $0.element.crit, hit: $0.element.hit) }
                .filter(\.hit)
        }
        guard let range = multiHitRange(atk.move, atk.ability) else { return nil }
        let count = min(range.max, max(range.min, atk.hits ?? range.def))
        let crits = min(count, max(0, atk.crits ?? 0))
        let power = fixedMultiHit[atk.move]?.first
        return (0..<count).map { PlanRow(power: power, crit: $0 < crits) }
    }

    static func firepowerOf(_ ctx: CalcContext, _ basePower: Int) -> Double {
        var mods = ctx.own.bpMods
        if ctx.atk.ability == "テクニシャン", basePower <= 60 {
            mods.insert(6144, at: min(ctx.own.technicianIndex, mods.count))
        }
        let power = max(1, applyMod(basePower, chainMods(mods)))
        let scale = 4096.0 * 4096.0 * 4096.0
        return Double(ctx.own.attack) * Double(power) * Double(ctx.weatherMod) * Double(ctx.stab) * Double(ctx.own.finalMod) / scale
            * (ctx.isCrit ? 1.5 : 1) * (ctx.burn ? 0.5 : 1)
    }

    static func withDefRanks(_ def: Fighter, _ ranks: [StatKey: Int]?, bonus: Int = 0) -> Fighter {
        var copy = def
        for (key, value) in def.evs {
            if ranks?[key] == nil, !(key == .b && bonus != 0) { continue }
            var updated = value
            updated.rank = clampRank((ranks?[key] ?? value.rank) + (key == .b ? bonus : 0))
            copy.evs[key] = updated
        }
        return copy
    }

    static func calcDamage(_ atk: Fighter, _ def: Fighter, _ field: Field) -> CalcResult {
        guard let plan = hitPlan(atk) else { return calcCore(atk, def, field) }
        let stamina = def.ability == "じきゅうりょく" && def.evs[.b] != nil
        let scales = def.ability == "マルチスケイル" && def.abilityOn
        var cores: [String: CalcResult] = [:]
        func coreAt(_ crit: Bool, _ index: Int = 0) -> CalcResult {
            let step = max(0, stamina ? min(index, 6 - (def.evs[.b]?.rank ?? 0)) : 0)
            let scaleOff = scales && index > 0
            let key = "\(crit):\(step):\(scaleOff)"
            if let cached = cores[key] { return cached }
            var target = step > 0 ? withDefRanks(def, nil, bonus: step) : def
            if scaleOff { target.abilityOn = false }
            var attacker = atk
            attacker.crit = crit
            attacker.single = true
            let result = calcCore(attacker, target, field)
            cores[key] = result
            return result
        }
        let base = coreAt(false)
        guard base.isOK, let baseInfo = base.info, let baseCtx = base.ctx else { return base }
        if plan.isEmpty { return .fail(.immune, "ヒットなし") }
        let crits = plan.filter(\.crit).count
        var info = baseInfo
        if crits > 0 { info.notes.append(Note(label: "急所\(crits)回", mul: 1.5, good: true)) }
        let basePower = baseInfo.basePower ?? 0
        let hits = plan.enumerated().map { index, row in
            hitDamages(coreAt(row.crit, index).ctx ?? baseCtx, row.power ?? basePower)
        }
        let firepower = plan.reduce(0.0) { sum, row in
            sum + firepowerOf(coreAt(row.crit).ctx ?? baseCtx, row.power ?? basePower)
        }
        info.plan = plan
        info.firepower = Int(jsRound(firepower))
        return CalcResult(status: .ok, hits: hits, info: info)
    }

    static func hpOf(_ p: Fighter) -> HPInfo {
        let max = p.evs[.h]?.real ?? 0
        return HPInfo(max: max, now: p.hpNow > 0 ? min(p.hpNow, max) : max)
    }

    static func isGrounded(_ p: Fighter) -> Bool {
        if p.item == "くろいてっきゅう" || p.conditions.contains("地面にいる") { return true }
        if p.types.contains("ひこう") { return false }
        if ["ふゆう", "うなぎのぼり"].contains(p.ability) { return false }
        return p.item != "ふうせん"
    }

    static func typeEffectiveness(_ moveType: String, _ defTypes: [String], groundedFlying: Bool = false) -> Double {
        defTypes.reduce(1.0) { mul, defType in
            if moveType == "じめん", defType == "ひこう", groundedFlying { return mul }
            return mul * (typeChart[moveType]?[defType] ?? 1)
        }
    }

    static func speedAbilityActive(_ p: Fighter, _ weather: String, _ terrain: String) -> Bool {
        guard let rule = speedAbilities[p.ability] else { return false }
        if rule.toggle { return p.abilityOn || (p.ability == "はやあし" && p.speedConditions.contains("まひ")) }
        if let override = p.speedAbility { return override }
        if let ruleWeather = rule.weather { return ruleWeather == weather }
        return rule.terrain == terrain
    }

    static func speedStat(_ p: Fighter, _ weather: String, _ terrain: String, scarf: Bool = false, real: Int? = nil) -> Int {
        let conditions = p.speedConditions
        var mods: [Int] = []
        if p.item == "くろいてっきゅう" || conditions.contains("くろいてっきゅう") { mods.append(2048) }
        if scarf { mods.append(6144) }
        if speedAbilityActive(p, weather, terrain), let rule = speedAbilities[p.ability] { mods.append(rule.mod) }
        if conditions.contains("おいかぜ") { mods.append(8192) }
        var speed = applyMod(applyRank(real ?? p.evs[.s]?.real ?? 0, p.evs[.s]?.rank ?? 0), chainMods(mods))
        if conditions.contains("まひ"), p.ability != "はやあし" { speed /= 2 }
        return max(1, speed)
    }

    static func effectiveSpeed(_ p: Fighter, _ weather: String, _ terrain: String) -> Int {
        p.evs[.s] != nil ? speedStat(p, weather, terrain) : 0
    }

    static func hitDamages(_ ctx: CalcContext, _ basePower: Int, parentalSecond: Bool = false) -> [Int] {
        var bpMods = ctx.bpMods
        if ctx.atk.ability == "テクニシャン", basePower <= 60 {
            bpMods.insert(6144, at: min(ctx.technicianIndex, bpMods.count))
        }
        let power = max(1, applyMod(basePower, chainMods(bpMods)))
        let levelFactor = level * 2 / 5 + 2
        var base = levelFactor * power * ctx.attack / ctx.defense / 50 + 2
        if parentalSecond { base = applyMod(base, 1024) }
        if ctx.weatherMod != 4096 { base = applyMod(base, ctx.weatherMod) }
        if ctx.isCrit { base = applyMod(base, 6144) }
        return (0..<16).map { i in
            var damage = base * (85 + i) / 100
            if ctx.stab != 4096 { damage = applyMod(damage, ctx.stab) }
            damage = Int((Double(damage) * ctx.eff).rounded(.down))
            if ctx.burn { damage = applyMod(damage, 2048) }
            if ctx.finalMod != 4096 { damage = applyMod(damage, ctx.finalMod) }
            return max(1, damage)
        }
    }

    static func calcCore(_ atk: Fighter, _ def: Fighter, _ field: Field) -> CalcResult {
        let data = GameData.shared
        guard let move = data.moves[atk.move] else { return .fail(.nomove, "わざを選んでください") }
        if move.category == "変化" { return .fail(.status, "変化技です") }
        if unsupportedMoves.contains(atk.move) { return .fail(.unsupported, "この技は計算できません") }

        let moldBreaker = atk.ability == "かたやぶり"
        let defAbility = moldBreaker ? "" : def.ability
        let weather = [atk.ability, def.ability].contains(where: { $0 == "ノーてんき" || $0 == "エアロック" }) ? "" : field.weather
        let moveWeather = atk.ability == "メガソーラー" ? "はれ" : weather
        let terrain = field.terrain
        let terrainName = "\(terrain)フィールド"
        let atkGrounded = isGrounded(atk)
        var defForGround = def
        defForGround.ability = defAbility
        let defGrounded = isGrounded(defForGround)
        let atkItem = atk.ability == "ぶきよう" ? "" : atk.item
        let defItem = def.ability == "ぶきよう" ? "" : def.item
        let remarks = move.remarks
        let has = { (flag: String) in remarks.contains(flag) }
        let isContact = has("接触")

        var moveType = move.type
        if atk.move == "レイジングブル", let bull = ragingBullTypes[atk.name] { moveType = bull }
        var skinBoost = false
        var basePower = move.power ?? 0
        if let skin = skinAbilities[atk.ability], moveType == "ノーマル" {
            moveType = skin
            skinBoost = true
        }
        if atk.ability == "ノーマルスキン", moveType != "ノーマル" {
            moveType = "ノーマル"
            skinBoost = true
        }
        if atk.ability == "うるおいボイス", has("音") { moveType = "みず" }
        if atk.move == "ウェザーボール", let ballType = weatherBallTypes[moveWeather] {
            moveType = ballType
            basePower *= 2
        }
        if atk.move == "だいちのはどう", let pulseType = terrainTypes[terrain], atkGrounded {
            moveType = pulseType
            basePower *= 2
        }

        var eff = typeEffectiveness(moveType, def.types, groundedFlying: defGrounded)
        if atk.ability == "しんがん", ["ノーマル", "かくとう"].contains(moveType), def.types.contains("ゴースト") {
            eff = typeEffectiveness(moveType, def.types.filter { $0 != "ゴースト" }, groundedFlying: defGrounded)
        }
        if atk.move == "フライングプレス" { eff *= typeEffectiveness("ひこう", def.types) }
        if atk.move == "フリーズドライ", def.types.contains("みず") { eff *= 4 }
        if moveType == "じめん", !defGrounded { eff = 0 }
        if immuneAbilities[defAbility] == moveType { eff = 0 }
        if defAbility == "ぼうおん", has("音") { eff = 0 }
        if defAbility == "ぼうだん", has("弾") { eff = 0 }
        if defAbility == "よびみず", moveType == "みず" { eff = 0 }
        if defAbility == "こんがりボディ", moveType == "ほのお" { eff = 0 }
        if defAbility == "かぜのり", has("風") { eff = 0 }
        if defAbility == "ふしぎなまもり", eff <= 1 { eff = 0 }
        if defAbility == "テラスシェル", def.abilityOn, eff > 0 { eff = 0.5 }
        if eff == 0 { return .fail(.immune, "効果なし") }

        let priorityText = remarks.first(where: { $0.hasPrefix("優先度") })?.replacingOccurrences(of: "優先度", with: "") ?? "0"
        let priority = Int(priorityText) ?? 0
        if terrain == "サイコ", defGrounded, priority > 0 { return .fail(.immune, "フィールドにより無効") }
        let failed = (atk.move == "アイアンローラー" && terrain.isEmpty) || (atk.move == "ポルターガイスト" && defItem.isEmpty)

        let defHP = hpOf(def)
        let atkHP = hpOf(atk)
        var info = CalcInfo(moveType: moveType, category: move.category, isContact: isContact)
        info.failed = failed

        func fixed(_ damage: Int, _ message: String, failing: Bool = false) -> CalcResult {
            var fixedInfo = info
            fixedInfo.displayPower = move.power
            if failing { fixedInfo.failed = true }
            return CalcResult(status: .ok, message: message, hits: [Array(repeating: max(1, damage), count: 16)], info: fixedInfo, fixed: true)
        }
        if ohkoMoves.contains(atk.move) {
            if atk.move == "ぜったいれいど", def.types.contains("こおり") { return .fail(.immune, "効果なし") }
            return fixed(defHP.max, "一撃必殺")
        }
        if ["ちきゅうなげ", "ナイトヘッド"].contains(atk.move) { return fixed(level, "固定ダメージ") }
        if atk.move == "いかりのまえば" { return fixed(defHP.now / 2, "相手のHPの半分") }
        if atk.move == "いのちがけ" { return fixed(atkHP.now, "自分のHP分") }
        if atk.move == "がむしゃら" {
            if defHP.now <= atkHP.now { return fixed(1, "相手と自分のHPの差", failing: true) }
            return fixed(defHP.now - atkHP.now, "相手と自分のHPの差")
        }

        let atkSpeed = effectiveSpeed(atk, weather, terrain)
        let defSpeed = effectiveSpeed(def, weather, terrain)
        func weightOf(_ p: Fighter, isDefender: Bool) -> Double {
            let weight = data.pokemons[p.name]?.weight ?? 0
            let ability = isDefender ? defAbility : p.ability
            if ability == "ヘヴィメタル" { return weight * 2 }
            if ability == "ライトメタル" { return (weight * 5).rounded(.down) / 10 }
            return weight
        }
        switch atk.move {
        case "エレキボール":
            let ratio = defSpeed > 0 ? Double(atkSpeed) / Double(defSpeed) : 0
            basePower = ratio >= 4 ? 150 : ratio >= 3 ? 120 : ratio >= 2 ? 80 : ratio >= 1 ? 60 : 40
        case "ジャイロボール":
            basePower = min(150, 25 * defSpeed / max(1, atkSpeed) + 1)
        case "くさむすび", "けたぐり":
            let w = weightOf(def, isDefender: true)
            basePower = w >= 200 ? 120 : w >= 100 ? 100 : w >= 50 ? 80 : w >= 25 ? 60 : w >= 10 ? 40 : 20
        case "ヒートスタンプ", "ヘビーボンバー":
            let ratio = weightOf(def, isDefender: true) / max(0.1, weightOf(atk, isDefender: false))
            basePower = ratio <= 1.0 / 5 ? 120 : ratio <= 1.0 / 4 ? 100 : ratio <= 1.0 / 3 ? 80 : ratio <= 1.0 / 2 ? 60 : 40
        case "ふんか", "しおふき", "ドラゴンエナジー":
            basePower = max(1, 150 * atkHP.now / max(1, atkHP.max))
        case "きしかいせい", "じたばた":
            let p = 48 * atkHP.now / max(1, atkHP.max)
            basePower = p <= 1 ? 200 : p <= 4 ? 150 : p <= 9 ? 100 : p <= 16 ? 80 : p <= 32 ? 40 : 20
        case "ハードプレス":
            basePower = max(1, 100 * defHP.now / max(1, defHP.max))
        case "アシストパワー", "つけあがる":
            basePower = 20 + 20 * (rankSum(atk) + max(0, atk.rankBoost))
        case "おはかまいり":
            basePower = 50 + 50 * min(100, max(0, atk.fainted))
        case "なげつける":
            basePower = max(1, atk.flingPower)
        case "ライジングボルト":
            if terrain == "エレキ", defGrounded { basePower *= 2 }
        default:
            break
        }
        let powerUp = atk.powerUp ? powerUpMoves[atk.move] : nil
        if powerUp?.kind == .base { basePower *= 2 }
        if basePower == 0 { return .fail(.unsupported, "この技は計算できません") }

        let solarWeak = ["ソーラービーム", "ソーラーブレード"].contains(atk.move) && ["あめ", "すなあらし", "ゆき"].contains(moveWeather)
        let knockOff = atk.move == "はたきおとす" && atk.powerUp
        let expanding = atk.move == "ワイドフォース" && terrain == "サイコ" && atkGrounded
        var displayMods: [Int] = []
        if knockOff { displayMods.append(6144) }
        if expanding { displayMods.append(6144) }
        if solarWeak { displayMods.append(2048) }
        if powerUp?.kind == .power, let mod = powerUp?.mod { displayMods.append(mod) }
        if powerUp?.kind == .damage { displayMods.append(8192) }
        info.basePower = basePower
        info.displayPower = max(1, applyMod(basePower, chainMods(displayMods)))

        let isPhysical = move.category == "物理"
        let isCrit = atk.crit || alwaysCritMoves.contains(atk.move)
        var notes: [Note] = []
        func note(_ label: String, _ mul: Double, _ good: Bool? = nil) {
            if mul != 1 { notes.append(Note(label: label, mul: mul, good: good ?? (mul > 1))) }
        }

        var bpMods: [Int] = []
        var bpOwn: [Int] = []
        func bp(_ mod: Int, _ label: String, _ opp: Bool = false) {
            bpMods.append(mod)
            if !opp { bpOwn.append(mod) }
            note(label, Double(mod) / 4096, mod > 4096)
        }
        if skinBoost { bp(4915, atk.ability) }
        if atk.ability == "てつのこぶし", has("パンチ") { bp(4915, atk.ability) }
        if atk.ability == "すてみ", recoilMoves.contains(atk.move) { bp(4915, atk.ability) }
        if atk.ability == "とうそうしん", atk.abilityOn { bp(5120, atk.ability) }
        if atk.ability == "かたいツメ", isContact { bp(5325, atk.ability) }
        if atk.ability == "アナライズ", atk.abilityOn { bp(5325, atk.ability) }
        if atk.ability == "すなのちから", weather == "すなあらし", ["いわ", "じめん", "はがね"].contains(moveType) { bp(5325, atk.ability) }
        if atk.ability == "ちからずく", secondaryMoves.contains(atk.move) { bp(5325, atk.ability) }
        if atk.ability == "パンクロック", has("音") { bp(5325, atk.ability) }
        let auraMod = [atk.ability, def.ability].contains("オーラブレイク") ? 3072 : 5448
        if moveType == "フェアリー", [atk.ability, def.ability].contains("フェアリーオーラ") { bp(auraMod, "フェアリーオーラ", atk.ability != "フェアリーオーラ") }
        if moveType == "あく", [atk.ability, def.ability].contains("ダークオーラ") { bp(auraMod, "ダークオーラ", atk.ability != "ダークオーラ") }
        if atk.ability == "どくぼうそう", atk.abilityOn, isPhysical { bp(6144, atk.ability) }
        if atk.ability == "ねつぼうそう", atk.abilityOn, !isPhysical { bp(6144, atk.ability) }
        let technicianIndex = bpMods.count
        let technicianOwnIndex = bpOwn.count
        let powers = fixedMultiHit[atk.move] ?? [basePower]
        if atk.ability == "テクニシャン", powers.contains(where: { $0 <= 60 }) { note("テクニシャン", 1.5) }
        if atk.ability == "がんじょうあご", has("噛み") { bp(6144, atk.ability) }
        if atk.ability == "メガランチャー", has("波動") { bp(6144, atk.ability) }
        if atk.ability == "きれあじ", has("切り") { bp(6144, atk.ability) }
        if atk.ability == "はがねのせいしん", moveType == "はがね" { bp(6144, atk.ability) }
        if atk.ability == "ほのおのたてがみ", moveType == "ほのお" { bp(6144, atk.ability) }
        if defAbility == "かんそうはだ", moveType == "ほのお" { bp(5120, defAbility, true) }
        if atkItem == "ちからのハチマキ", isPhysical { bp(4505, atkItem) }
        if atkItem == "ものしりメガネ", !isPhysical { bp(4505, atkItem) }
        if typeBoostItems[atkItem] == moveType { bp(4915, atkItem) }
        if atkItem == "ノーマルジュエル", moveType == "ノーマル" { bp(5325, atkItem) }
        if plateItems[atkItem] == moveType { bp(4915, atkItem) }
        if atkItem == "パンチグローブ", has("パンチ") { bp(4505, atkItem) }
        if let orb = orbItems[atkItem], atk.name.contains(orb.owner), orb.types.contains(moveType) { bp(4915, atkItem) }
        if solarWeak { bp(2048, weatherNames[moveWeather] ?? "") }
        if knockOff { bp(6144, "はたきおとす", true) }
        if expanding { bp(6144, terrainName) }
        if powerUp?.kind == .power, let mod = powerUp?.mod { bp(mod, "威力アップ") }
        if moveType == "でんき", atk.conditions.contains("じゅうでん") {
            bp(8192, "じゅうでん")
        } else if moveType == "でんき", atk.ability == "でんきにかえる", atk.abilityOn {
            bp(8192, atk.ability)
        }
        if atkGrounded, terrainTypes[terrain] == moveType, terrain != "ミスト" { bp(5325, terrainName) }
        if defGrounded, terrain == "グラス", ["じしん", "じならし"].contains(atk.move) { bp(2048, terrainName) }
        if defGrounded, terrain == "ミスト", moveType == "ドラゴン" { bp(2048, terrainName) }

        let offenseKey: StatKey = atk.move == "ボディプレス" ? .b : atk.move == "イカサマ" ? .vsa : isPhysical ? .a : .c
        guard let offense = atk.evs[offenseKey] else { return .fail(.unsupported, "能力値が見つかりません") }
        var atkRank = offense.rank
        if atk.ability == "たんじゅん" { atkRank = clampRank(atkRank * 2) }
        if ["エレクトロビーム", "メテオビーム"].contains(atk.move) { atkRank = min(6, atkRank + 1) }
        let ownRank = isCrit && atkRank < 0 ? 0 : atkRank
        if defAbility == "てんねん" { atkRank = 0 }
        if isCrit, atkRank < 0 { atkRank = 0 }
        note("\(offenseKey.statName)ランク", rankRatio(atkRank))

        var atkMods: [Int] = []
        var atkOwn: [Int] = []
        func am(_ mod: Int, _ label: String, _ opp: Bool = false) {
            atkMods.append(mod)
            if !opp { atkOwn.append(mod) }
            note(label, Double(mod) / 4096, mod > 4096)
        }
        let gutsActive = atk.ability == "こんじょう" && atk.abilityOn
        if isPhysical, ["ちからもち", "ヨガパワー"].contains(atk.ability) { am(8192, atk.ability) }
        if isPhysical, atk.ability == "はりきり" { am(6144, atk.ability) }
        if isPhysical, gutsActive { am(6144, atk.ability) }
        if pinchAbilities[atk.ability] == moveType, atk.abilityOn { am(6144, atk.ability) }
        if !isPhysical, atk.ability == "サンパワー", moveWeather == "はれ" { am(6144, atk.ability) }
        if !isPhysical, ["プラス", "マイナス"].contains(atk.ability), atk.abilityOn { am(6144, atk.ability) }
        if atk.ability == "もらいび", atk.abilityOn, moveType == "ほのお" { am(6144, atk.ability) }
        if atk.ability == "すいほう", moveType == "みず" { am(8192, atk.ability) }
        if atk.ability == "はりこみ", atk.abilityOn { am(8192, atk.ability) }
        if atk.ability == "はがねつかい", moveType == "はがね" { am(6144, atk.ability) }
        if atk.ability == "トランジスタ", moveType == "でんき" { am(5325, atk.ability) }
        if atk.ability == "りゅうのあぎと", moveType == "ドラゴン" { am(6144, atk.ability) }
        if atk.ability == "いわはこび", moveType == "いわ" { am(6144, atk.ability) }
        if isPhysical, atk.ability == "ごりむちゅう" { am(6144, atk.ability) }
        if isPhysical, atk.ability == "スロースタート", atk.abilityOn { am(2048, atk.ability) }
        if atk.ability == "よわき", atk.abilityOn { am(2048, atk.ability) }
        if isPhysical, atk.ability == "ひひいろのこどう", moveWeather == "はれ" { am(5461, atk.ability) }
        if !isPhysical, atk.ability == "ハドロンエンジン", terrain == "エレキ" { am(5461, atk.ability) }
        if ["こだいかっせい", "クォークチャージ"].contains(atk.ability), atk.abilityOn, highestStat(atk) == offenseKey { am(5325, atk.ability) }
        if isPhysical, def.ability == "わざわいのおふだ", atk.ability != "わざわいのおふだ" { am(3072, def.ability, true) }
        if !isPhysical, def.ability == "わざわいのうつわ", atk.ability != "わざわいのうつわ" { am(3072, def.ability, true) }
        if isPhysical, atkItem == "こだわりハチマキ" { am(6144, atkItem) }
        if !isPhysical, atkItem == "こだわりメガネ" { am(6144, atkItem) }
        if atkItem == "でんきだま", atk.name == "ピカチュウ" { am(8192, atkItem) }
        if defAbility == "あついしぼう", ["ほのお", "こおり"].contains(moveType) { am(2048, defAbility, true) }
        if ["たいねつ", "すいほう"].contains(defAbility), moveType == "ほのお" { am(2048, defAbility, true) }
        if defAbility == "きよめのしお", moveType == "ゴースト" { am(2048, defAbility, true) }
        let attack = max(1, applyMod(applyRank(offense.real, atkRank), chainMods(atkMods)))

        let useDefense = isPhysical || atk.move == "サイコショック"
        let defenseKey: StatKey = useDefense ? .b : .d
        guard let defense0 = def.evs[defenseKey] else { return .fail(.unsupported, "能力値が見つかりません") }
        var defRank = defense0.rank
        if defAbility == "たんじゅん" { defRank = clampRank(defRank * 2) }
        if atk.ability == "てんねん" || ["DDラリアット", "せいなるつるぎ"].contains(atk.move) { defRank = 0 }
        if isCrit, defRank > 0 { defRank = 0 }
        note("\(defenseKey.statName)ランク", rankRatio(defRank), defRank < 0)
        var defMods: [Int] = []
        func dm(_ mod: Int, _ label: String) {
            defMods.append(mod)
            note(label, Double(mod) / 4096, mod < 4096)
        }
        if useDefense, defAbility == "ファーコート" { dm(8192, defAbility) }
        if useDefense, defAbility == "ふしぎなうろこ", def.abilityOn { dm(6144, defAbility) }
        if useDefense, defAbility == "くさのけがわ", terrain == "グラス" { dm(6144, defAbility) }
        if !useDefense, defItem == "とつげきチョッキ" { dm(6144, defItem) }
        if defItem == "しんかのきせき" { dm(6144, defItem) }
        if useDefense, atk.ability == "わざわいのつるぎ", def.ability != "わざわいのつるぎ" { dm(3072, atk.ability) }
        if !useDefense, atk.ability == "わざわいのたま", def.ability != "わざわいのたま" { dm(3072, atk.ability) }
        if ["こだいかっせい", "クォークチャージ"].contains(defAbility), def.abilityOn, highestStat(def) == defenseKey { dm(5325, defAbility) }
        if !useDefense, weather == "すなあらし", def.types.contains("いわ") { dm(6144, "すなあらし") }
        if useDefense, weather == "ゆき", def.types.contains("こおり") { dm(6144, "ゆき") }
        let defense = max(1, applyMod(applyRank(defense0.real, defRank), chainMods(defMods)))

        var weatherMod = 4096
        if moveWeather == "はれ" { weatherMod = moveType == "ほのお" ? 6144 : moveType == "みず" ? 2048 : 4096 }
        if moveWeather == "あめ" { weatherMod = moveType == "みず" ? 6144 : moveType == "ほのお" ? 2048 : 4096 }
        note(weatherNames[moveWeather] ?? "", Double(weatherMod) / 4096)
        if isCrit { note("急所", 1.5) }

        let stabActive = atk.types.contains(moveType)
        let stab = stabActive ? (atk.ability == "てきおうりょく" ? 8192 : 6144) : 4096
        note("タイプ一致", Double(stab) / 4096)
        note("タイプ相性", eff)

        let burn = isPhysical && atk.conditions.contains("やけど") && !gutsActive && atk.move != "からげんき"
        if burn { note("やけど", 0.5) }

        let superEffective = eff > 1
        var finalMods: [Int] = []
        var finalOwn: [Int] = []
        func fm(_ mod: Int, _ label: String, _ opp: Bool = false) {
            finalMods.append(mod)
            if !opp { finalOwn.append(mod) }
            note(label, Double(mod) / 4096, mod > 4096)
        }
        let screenName = isPhysical ? "リフレクター" : "ひかりのかべ"
        if def.conditions.contains(screenName), !isCrit, atk.ability != "すりぬけ", !screenBreakMoves.contains(atk.move) { fm(2048, screenName, true) }
        if isCrit, atk.ability == "スナイパー" { fm(6144, atk.ability) }
        if defAbility == "もふもふ", moveType == "ほのお" { fm(8192, defAbility, true) }
        if defAbility == "マルチスケイル", def.abilityOn { fm(2048, defAbility, true) }
        if ["もふもふ", "はどうのぼうご"].contains(defAbility), isContact { fm(2048, defAbility, true) }
        if defAbility == "パンクロック", has("音") { fm(2048, defAbility, true) }
        if ["ハードロック", "フィルター"].contains(defAbility), superEffective { fm(3072, defAbility, true) }
        if def.ability == "プリズムアーマー", superEffective { fm(3072, def.ability, true) }
        if defAbility == "ファントムガード", def.abilityOn { fm(2048, defAbility, true) }
        if defAbility == "こおりのりんぷん", !isPhysical { fm(2048, defAbility, true) }
        if atk.ability == "いろめがね", eff < 1 { fm(8192, atk.ability) }
        if atk.ability == "ブレインフォース", superEffective { fm(5120, atk.ability) }
        if atkItem == "たつじんのおび", superEffective { fm(4915, atkItem, true) }
        if atkItem == "いのちのたま" { fm(5324, atkItem) }
        if atkItem == "メトロノーム", let metronome = atk.metronome, metronome > 1 {
            let mods = [4915, 5734, 6553, 7372, 8192]
            fm(mods[min(metronome, 6) - 2], "\(atkItem)（\(metronome >= 6 ? "6回目以上" : "\(metronome)回目")）")
        }
        if let berryType = halfBerries[defItem], berryType == moveType, superEffective || berryType == "ノーマル" {
            fm(defAbility == "じゅくせい" ? 1024 : 2048, defItem, true)
        }
        if powerUp?.kind == .damage { fm(8192, powerUp?.label ?? "威力アップ") }
        if def.conditions.contains("無防備状態") { fm(8192, "無防備状態", true) }

        info.notes = notes
        info.offenseKey = offenseKey
        info.defenseKey = defenseKey
        let ctx = CalcContext(
            atk: atk, eff: eff, isCrit: isCrit, weatherMod: weatherMod, bpMods: bpMods, technicianIndex: technicianIndex,
            attack: attack, defense: defense, stab: stab, burn: burn, finalMod: chainMods(finalMods),
            own: OwnContext(
                attack: max(1, applyMod(applyRank(offense.real, ownRank), chainMods(atkOwn))),
                bpMods: bpOwn,
                technicianIndex: technicianOwnIndex,
                finalMod: chainMods(finalOwn)
            )
        )

        if atk.single { return CalcResult(status: .ok, info: info, ctx: ctx) }
        let parental = atk.ability == "おやこあい"
        let hits = parental
            ? [hitDamages(ctx, basePower), hitDamages(ctx, basePower, parentalSecond: true)]
            : [hitDamages(ctx, basePower)]
        info.firepower = Int(jsRound(firepowerOf(ctx, basePower) * (parental ? 1.25 : 1)))
        return CalcResult(status: .ok, hits: hits, info: info, ctx: ctx)
    }

    typealias Distribution = [Int: Double]

    static func convolve(_ a: Distribution, _ b: Distribution, cap: Int) -> Distribution {
        var next: Distribution = [:]
        for (x, p) in a {
            for (y, q) in b {
                let key = min(cap, x + y)
                next[key, default: 0] += p * q
            }
        }
        return next
    }

    static func uniform(_ damages: [Int]) -> Distribution {
        var dist: Distribution = [:]
        let share = 1 / Double(damages.count)
        for damage in damages {
            dist[damage, default: 0] += share
        }
        return dist
    }

    static func useDistribution(_ result: CalcResult, _ hp: Int) -> Distribution {
        result.hits.reduce([0: 1]) { convolve($0, uniform($1), cap: hp) }
    }

    static func knockOut(_ perUse: Distribution, _ hp: Int) -> (hits: Int, rate: Double)? {
        if hp <= 0 { return nil }
        var dist: Distribution = [0: 1]
        for n in 1...10 {
            dist = convolve(dist, perUse, cap: hp)
            let rate = dist[hp] ?? 0
            if rate > 1e-9 { return (n, min(1, rate)) }
        }
        return (Int.max, 0)
    }

    static func useRange(_ result: CalcResult) -> (min: Int, max: Int) {
        (
            result.hits.reduce(0) { $0 + ($1.min() ?? 0) },
            result.hits.reduce(0) { $0 + ($1.max() ?? 0) }
        )
    }

    static func constantSign(_ kind: TabKind) -> Int {
        kind == .damage ? 1 : -1
    }

    static func summarize(_ list: [CalcEntry], _ hp: HPInfo, multi: Bool) -> Summary {
        let ok = list.filter { $0.constant != nil || $0.result?.isOK == true }
        if ok.isEmpty {
            return Summary(text: list.first(where: { $0.result != nil })?.result?.message ?? "計算できません", rate: nil, min: 0, max: 0)
        }
        var pathHP = [hp.now, hp.now]
        var pathDamage = [0, 0]
        func hit(_ amounts: [Int]) {
            for i in 0..<2 {
                let amount = amounts[i]
                if amount < 0, pathHP[i] <= 0 { continue }
                let next = amount < 0 ? min(hp.max, pathHP[i] - amount) : pathHP[i] - amount
                pathDamage[i] += pathHP[i] - next
                pathHP[i] = next
            }
        }
        var remain: Distribution = [hp.now: 1]
        func step(_ transition: (Int) -> Distribution) {
            var next: Distribution = [:]
            for (h, p) in remain {
                for (v, q) in transition(h) {
                    next[v, default: 0] += p * q
                }
            }
            remain = next
        }
        for entry in ok {
            if let constant = entry.constant {
                let delta = constantSign(entry.kind) * constant.total
                hit([delta, delta])
                step { h in
                    let next = h <= 0 ? 0 : max(0, min(hp.max, h - delta))
                    return [next: 1]
                }
                continue
            }
            guard let result = entry.result else { continue }
            let range = useRange(result)
            hit([range.min, range.max])
            let perUse = useDistribution(result, hp.max)
            step { h in
                var out: Distribution = [:]
                for (d, q) in perUse {
                    out[max(0, h - d), default: 0] += q
                }
                return out
            }
        }
        let low = pathDamage[0]
        let high = pathDamage[1]
        let suffix = ok.contains { $0.result?.info?.failed == true } ? "（失敗）" : ""
        if multi {
            return Summary(text: "ひんし率\(Format.fixed1((remain[0] ?? 0) * 100))%\(suffix)", rate: nil, min: low, max: high)
        }
        let only = ok[0]
        let dist: Distribution
        if let constant = only.constant {
            dist = [max(0, constantSign(only.kind) * constant.total): 1]
        } else if let result = only.result {
            dist = useDistribution(result, hp.now)
        } else {
            dist = [0: 1]
        }
        guard let ko = knockOut(dist, hp.now), ko.hits != Int.max else {
            return Summary(text: "10発以上\(suffix)", rate: nil, min: low, max: high)
        }
        if ko.rate >= 1 - 1e-9 { return Summary(text: "確定\(ko.hits)発\(suffix)", rate: nil, min: low, max: high) }
        return Summary(text: "乱数\(ko.hits)発\(suffix)", rate: "\(Format.fixed2(ko.rate * 100))%", min: low, max: high)
    }

    static func hpEffects(_ entry: CalcEntry, def: Fighter) -> [HPEffect] {
        guard let atk = entry.atk, let result = entry.result, result.isOK, let info = result.info else { return [] }
        let atkHP = hpOf(atk)
        let maxHP = atkHP.max
        let defNow = hpOf(def).now
        let magic = atk.ability == "マジックガード"
        var contacts: [(String, Int)] = []
        if info.isContact, !magic {
            if def.item == "ゴツゴツメット" { contacts.append((def.item, 6)) }
            if ["さめはだ", "てつのトゲ"].contains(def.ability) { contacts.append((def.ability, 8)) }
        }
        let drain = drainRatio[atk.move]
        let recoil = !magic && atk.ability != "いしあたま" ? recoilRatio[atk.move] : nil
        let sheerForce = atk.ability == "ちからずく" && secondaryMoves.contains(atk.move)
        var order: [String] = []
        var rows: [String: [Int]] = [:]
        for pick in 0..<2 {
            var hp = atkHP.now
            var defHP = defNow
            var dealt = 0
            func apply(_ name: String, _ amount: Int) {
                if amount == 0 { return }
                let before = hp
                if before > 0 { hp = max(0, min(maxHP, before + amount)) }
                if rows[name] == nil {
                    rows[name] = [0, 0]
                    order.append(name)
                }
                rows[name]?[pick] = hp - before
            }
            for (index, damages) in result.hits.enumerated() {
                if defHP <= 0 { continue }
                let chosen = pick == 0 ? (damages.min() ?? 0) : (damages.max() ?? 0)
                let amount = min(chosen, defHP)
                defHP -= amount
                dealt += amount
                for (name, ratio) in contacts {
                    apply(result.hits.count > 1 ? "\(name)（\(index + 1)回目）" : name, -max(1, maxHP / ratio))
                }
            }
            if let drain {
                let root = atk.item == "おおきなねっこ"
                var amount = max(1, Int(jsRound(Double(dealt) * drain)))
                if root { amount = applyMod(amount, 5324) }
                apply(root ? "\(atk.move)（おおきなねっこ）" : atk.move, amount)
            }
            if atk.item == "かいがらのすず" { apply(atk.item, dealt / 8) }
            if let recoil { apply(atk.move, -max(1, Int(jsRound(Double(dealt) * recoil)))) }
            if atk.move == "てっていこうせん", !magic { apply(atk.move, -Int(jsRound(Double(maxHP) / 2))) }
            if selfKOMoves.contains(atk.move) { apply(atk.move, -atkHP.now) }
            if atk.item == "いのちのたま", !magic, !sheerForce { apply(atk.item, -max(1, maxHP / 10)) }
        }
        return order.map { HPEffect(name: $0, p: rows[$0] ?? [0, 0], max: maxHP) }
    }

    static func counterRows(_ entry: CalcEntry, def: Fighter) -> [CounterRow]? {
        guard let atk = entry.atk, let result = entry.result, result.isOK, let category = result.info?.category,
              ["物理", "特殊"].contains(category), let last = result.hits.last else { return nil }
        let defMax = hpOf(def).max
        let atkMax = max(1, hpOf(atk).max)
        let rolls = (0..<16).map { i in (total: result.hits.reduce(0) { $0 + $1[i] }, last: last[i]) }
        let alive = rolls.filter { $0.total < defMax }
        let physical = category == "物理"
        let rows: [(String, Double, Bool)] = [
            (physical ? "カウンター" : "ミラーコート", 2, atk.types.contains(physical ? "ゴースト" : "あく")),
            ("メタルバースト・ほうふく", 1.5, false),
        ]
        return rows.map { name, mult, immune in
            if alive.isEmpty {
                return CounterRow(name: name, mult: mult, text: "ひんしのため反射不可", percent: "", ratios: [1, 1])
            }
            if immune {
                return CounterRow(name: name, mult: mult, text: "効果なし", percent: "", ratios: [1, 1])
            }
            let amounts = alive.map { min(atkMax, max(1, Int((Double($0.last) * mult).rounded(.down)))) }
            let lo = amounts.min() ?? 0
            let hi = amounts.max() ?? 0
            let text = Format.pair(lo, hi) + (alive.count < rolls.count ? "（一部ひんし）" : "")
            return CounterRow(
                name: name, mult: mult, text: text,
                percent: Format.percentPair(lo, hi, atkMax),
                ratios: [Double(atkMax - hi) / Double(atkMax), Double(atkMax - lo) / Double(atkMax)]
            )
        }
    }

    static func withStat(_ p: Fighter, _ key: StatKey, _ points: Int, nature: Int? = nil) -> Fighter {
        var copy = p
        let natureValue = nature ?? p.evs[key]?.nature ?? 10
        let real = key == .h ? hpStat(p.base.h, points) : realStat(p.base[key], points, natureValue)
        var value = p.evs[key] ?? StatValue(real: real, points: points, rank: 0, nature: natureValue)
        value.points = points
        value.nature = natureValue
        value.real = real
        copy.evs[key] = value
        return copy
    }

    static func damageSpan(_ result: CalcResult) -> (lo: Int, hi: Int)? {
        guard result.isOK else { return nil }
        return result.hits.reduce((lo: 0, hi: 0)) { ($0.lo + ($1.min() ?? 0), $0.hi + ($1.max() ?? 0)) }
    }

    static func minPoints(_ test: (Int) -> Bool) -> Int? {
        if !test(32) { return nil }
        var lo = 0
        var hi = 32
        while lo < hi {
            let mid = (lo + hi) >> 1
            if test(mid) { hi = mid } else { lo = mid + 1 }
        }
        return lo
    }

    static func adjustTable(_ entry: CalcEntry) -> AdjustTable? {
        guard let atk = entry.atk, let def = entry.def, let field = entry.field, let result = entry.result, result.isOK,
              let info = result.info, ["物理", "特殊"].contains(info.category),
              let offenseKey = info.offenseKey, let defenseKey = info.defenseKey,
              atk.evs[offenseKey] != nil, def.evs[defenseKey] != nil else { return nil }
        let hp = hpOf(def)
        let ratio = hp.max > 0 ? Double(hp.now) / Double(hp.max) : 1
        func survives(_ target: Fighter) -> Bool {
            guard let span = damageSpan(calcDamage(atk, target, field)) else { return false }
            var full = target
            full.hpNow = 0
            let maxHP = hpOf(full).max
            let now = ratio >= 1 ? maxHP : max(1, Int(jsRound(Double(maxHP) * ratio)))
            return span.hi < now
        }
        let h = minPoints { points in
            var target = withStat(def, .h, points)
            target.hpNow = 0
            return survives(target)
        }
        let rows = [10, 11].map { nature -> AdjustRowData in
            let label = nature == 11 ? "×1.1" : "×1.0"
            var koCell: AdjustCell?
            if offenseKey != .vsa {
                let ko = minPoints { points in
                    guard let span = damageSpan(calcDamage(withStat(atk, offenseKey, points, nature: nature), def, field)) else { return false }
                    return span.lo >= hp.now
                }
                koCell = AdjustCell(label: label, points: ko, real: ko.map { withStat(atk, offenseKey, $0, nature: nature).evs[offenseKey]?.real ?? 0 } ?? 0)
            }
            let wall = minPoints { points in survives(withStat(def, defenseKey, points, nature: nature)) }
            let hCell = nature == 10 ? AdjustCell(label: "", points: h, real: h.map { hpStat(def.base.h, $0) } ?? 0) : nil
            return AdjustRowData(
                ko: koCell,
                h: hCell,
                wall: AdjustCell(label: label, points: wall, real: wall.map { withStat(def, defenseKey, $0, nature: nature).evs[defenseKey]?.real ?? 0 } ?? 0)
            )
        }
        return AdjustTable(offenseKey: offenseKey, defenseKey: defenseKey, rows: rows)
    }
}

enum Format {
    static func fixed1(_ value: Double) -> String {
        var rounded = Calc.jsRound(value * 10) / 10
        if rounded == 0 { rounded = 0 }
        return String(format: "%.1f", rounded)
    }

    static func fixed2(_ value: Double) -> String {
        var rounded = Calc.jsRound(value * 100) / 100
        if rounded == 0 { rounded = 0 }
        return String(format: "%.2f", rounded)
    }

    static func pair(_ a: Int, _ b: Int, unit: String = "") -> String {
        a == b ? "\(a)\(unit)" : "\(a)～\(b)\(unit)"
    }

    static func pair(_ a: String, _ b: String, unit: String = "") -> String {
        a == b ? "\(a)\(unit)" : "\(a)～\(b)\(unit)"
    }

    static func percentPair(_ a: Int, _ b: Int, _ base: Int) -> String {
        let total = Double(max(1, base))
        return pair(fixed1(Double(a) / total * 100), fixed1(Double(b) / total * 100), unit: "%")
    }

    static func mul(_ value: Double) -> String {
        let rounded = Calc.jsRound(value * 100) / 100
        if rounded == rounded.rounded() { return "×\(Int(rounded))" }
        return "×\(rounded)"
    }

    static func absPair(_ lo: Int, _ hi: Int) -> String {
        let a = abs(lo)
        let b = abs(hi)
        return lo < 0 && hi > 0 ? "\(lo)～+\(hi)" : pair(min(a, b), max(a, b))
    }
}
