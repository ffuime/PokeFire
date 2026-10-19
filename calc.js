const CALC_TYPE_CHART = {
    "ノーマル": { "いわ": 0.5, "ゴースト": 0, "はがね": 0.5 },
    "ほのお": { "ほのお": 0.5, "みず": 0.5, "くさ": 2, "こおり": 2, "むし": 2, "いわ": 0.5, "ドラゴン": 0.5, "はがね": 2 },
    "みず": { "ほのお": 2, "みず": 0.5, "くさ": 0.5, "じめん": 2, "いわ": 2, "ドラゴン": 0.5 },
    "くさ": { "ほのお": 0.5, "みず": 2, "くさ": 0.5, "どく": 0.5, "じめん": 2, "ひこう": 0.5, "むし": 0.5, "いわ": 2, "ドラゴン": 0.5, "はがね": 0.5 },
    "でんき": { "みず": 2, "くさ": 0.5, "でんき": 0.5, "じめん": 0, "ひこう": 2, "ドラゴン": 0.5 },
    "こおり": { "ほのお": 0.5, "みず": 0.5, "くさ": 2, "こおり": 0.5, "じめん": 2, "ひこう": 2, "ドラゴン": 2, "はがね": 0.5 },
    "かくとう": { "ノーマル": 2, "こおり": 2, "どく": 0.5, "ひこう": 0.5, "エスパー": 0.5, "むし": 0.5, "いわ": 2, "ゴースト": 0, "あく": 2, "はがね": 2, "フェアリー": 0.5 },
    "どく": { "くさ": 2, "どく": 0.5, "じめん": 0.5, "いわ": 0.5, "ゴースト": 0.5, "はがね": 0, "フェアリー": 2 },
    "じめん": { "ほのお": 2, "くさ": 0.5, "でんき": 2, "どく": 2, "ひこう": 0, "むし": 0.5, "いわ": 2, "はがね": 2 },
    "ひこう": { "くさ": 2, "でんき": 0.5, "かくとう": 2, "むし": 2, "いわ": 0.5, "はがね": 0.5 },
    "エスパー": { "かくとう": 2, "どく": 2, "エスパー": 0.5, "あく": 0, "はがね": 0.5 },
    "むし": { "ほのお": 0.5, "くさ": 2, "かくとう": 0.5, "どく": 0.5, "ひこう": 0.5, "エスパー": 2, "ゴースト": 0.5, "あく": 2, "はがね": 0.5, "フェアリー": 0.5 },
    "いわ": { "ほのお": 2, "こおり": 2, "かくとう": 0.5, "じめん": 0.5, "ひこう": 2, "むし": 2, "はがね": 0.5 },
    "ゴースト": { "ノーマル": 0, "エスパー": 2, "ゴースト": 2, "あく": 0.5 },
    "ドラゴン": { "ドラゴン": 2, "はがね": 0.5, "フェアリー": 0 },
    "あく": { "かくとう": 0.5, "エスパー": 2, "ゴースト": 2, "あく": 0.5, "フェアリー": 0.5 },
    "はがね": { "ほのお": 0.5, "みず": 0.5, "でんき": 0.5, "こおり": 2, "いわ": 2, "はがね": 0.5, "フェアリー": 2 },
    "フェアリー": { "ほのお": 0.5, "かくとう": 2, "どく": 0.5, "ドラゴン": 2, "あく": 2, "はがね": 0.5 },
};

const CALC_SECONDARY_MOVES = new Set([
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
]);

const CALC_RECOIL_MOVES = new Set([
    "ウェーブタックル", "ウッドハンマー", "かかとおとし", "サンダーダイブ", "すてみタックル", "とびひざげり", "はめつのひかり", "フレアドライブ", "ブレイブバード", "ボルテッカー",
    "もろはのずつき", "ワイルドボルト",
]);

const CALC_RECOIL_RATIO = {
    "ウェーブタックル": 1 / 3, "ウッドハンマー": 1 / 3, "すてみタックル": 1 / 3, "フレアドライブ": 1 / 3, "ブレイブバード": 1 / 3, "ボルテッカー": 1 / 3,
    "もろはのずつき": 1 / 2, "はめつのひかり": 1 / 2, "ワイルドボルト": 1 / 4,
};
const CALC_DRAIN_RATIO = {
    "ウッドホーン": 1 / 2, "ギガドレイン": 1 / 2, "きゅうけつ": 1 / 2, "シャカシャカほう": 1 / 2, "ドレインパンチ": 1 / 2, "パラボラチャージ": 1 / 2,
    "むねんのつるぎ": 1 / 2, "ドレインキッス": 3 / 4,
};
const CALC_SELF_KO_MOVES = new Set(["じばく", "だいばくはつ", "ミストバースト", "いのちがけ"]);

const CALC_FIXED_MULTI_HIT = {
    "ダブルアタック": [35, 35],
    "ダブルウイング": [40, 40],
    "ツインビーム": [40, 40],
    "ドラゴンアロー": [50, 50],
    "トリプルアクセル": [20, 40, 60],
    "ネズミざん": Array(10).fill(20),
};
const CALC_VARIABLE_MULTI_HIT = new Set(["スイープビンタ", "スケイルショット", "タネマシンガン", "つららばり", "ボーンラッシュ", "ミサイルばり", "みずしゅりけん", "ロックブラスト"]);

const CALC_OHKO_MOVES = new Set(["じわれ", "ぜったいれいど", "つのドリル", "ハサミギロチン"]);
const CALC_UNSUPPORTED_MOVES = new Set(["カウンター", "ほうふく", "ミラーコート", "メタルバースト", "はきだす", "なげつける", "ふくろだたき"]);
const CALC_ALWAYS_CRIT_MOVES = new Set(["こおりのいぶき", "トリックフラワー", "やまあらし"]);
const CALC_SCREEN_BREAK_MOVES = new Set(["かわらわり", "サイコファング", "レイジングブル"]);

const CALC_POWER_UP_MOVES = {
    "しっぺがえし": { kind: "base" }, "じだんだ": { kind: "base" }, "やけっぱち": { kind: "base" }, "ダメおし": { kind: "base" },
    "ゆきなだれ": { kind: "base" }, "たたりめ": { kind: "base" }, "ひゃっきやこう": { kind: "base" }, "どくばりセンボン": { kind: "base" },
    "きまぐレーザー": { kind: "base" }, "りんしょう": { kind: "base" },
    "からげんき": { kind: "power", mod: 8192 }, "うっぷんばらし": { kind: "power", mod: 8192 }, "ベノムショック": { kind: "power", mod: 8192 },
    "Gのちから": { kind: "power", mod: 6144 },
    "じしん": { kind: "damage", label: "地中状態" }, "なみのり": { kind: "damage", label: "水中状態" }, "うずしお": { kind: "damage", label: "水中状態" },
    "サンダーダイブ": { kind: "damage" }, "ドラゴンダイブ": { kind: "damage" }, "のしかかり": { kind: "damage" },
    "ヒートスタンプ": { kind: "damage" }, "ヘビーボンバー": { kind: "damage" }, "フライングプレス": { kind: "damage" },
};

const CALC_HALF_BERRIES = {
    "オッカのみ": "ほのお", "イトケのみ": "みず", "ソクノのみ": "でんき", "リンドのみ": "くさ", "ヤチェのみ": "こおり", "ヨプのみ": "かくとう",
    "ビアーのみ": "どく", "シュカのみ": "じめん", "バコウのみ": "ひこう", "ウタンのみ": "エスパー", "タンガのみ": "むし", "ヨロギのみ": "いわ",
    "カシブのみ": "ゴースト", "ハバンのみ": "ドラゴン", "ナモのみ": "あく", "リリバのみ": "はがね", "ロゼルのみ": "フェアリー", "ホズのみ": "ノーマル",
};
const RAGING_BULL_TYPES = { "パルデアケンタロス(かくとう)": "かくとう", "パルデアケンタロス(ほのお)": "ほのお", "パルデアケンタロス(みず)": "みず" };

const SKIN_ABILITIES = { "スカイスキン": "ひこう", "フェアリースキン": "フェアリー", "フリーズスキン": "こおり", "ドラゴンスキン": "ドラゴン" };
const TYPE_BOOST_ITEMS = {
    "シルクのスカーフ": "ノーマル", "もくたん": "ほのお", "しんぴのしずく": "みず", "きせきのタネ": "くさ", "じしゃく": "でんき",
    "とけないこおり": "こおり", "くろおび": "かくとう", "どくバリ": "どく", "やわらかいすな": "じめん", "するどいくちばし": "ひこう",
    "まがったスプーン": "エスパー", "ぎんのこな": "むし", "かたいいし": "いわ", "のろいのおふだ": "ゴースト", "りゅうのキバ": "ドラゴン",
    "くろいメガネ": "あく", "メタルコート": "はがね", "ようせいのハネ": "フェアリー",
};
const PINCH_ABILITIES = { "もうか": "ほのお", "しんりょく": "くさ", "げきりゅう": "みず", "むしのしらせ": "むし" };
const IMMUNE_ABILITIES = {
    "ちくでん": "でんき", "でんきエンジン": "でんき", "ひらいしん": "でんき",
    "ちょすい": "みず", "かんそうはだ": "みず",
    "もらいび": "ほのお", "そうしょく": "くさ", "どしょく": "じめん",
};
const TERRAIN_TYPES = { "エレキ": "でんき", "グラス": "くさ", "サイコ": "エスパー", "ミスト": "フェアリー" };
const WEATHER_BALL_TYPES = { "はれ": "ほのお", "あめ": "みず", "すなあらし": "いわ", "ゆき": "こおり" };
const WEATHER_NAMES = { "はれ": "にほんばれ", "あめ": "あめ", "すなあらし": "すなあらし", "ゆき": "ゆき" };
const STAT_NAMES = { a: "こうげき", b: "ぼうぎょ", c: "とくこう", d: "とくぼう", s: "すばやさ", vsa: "相手のこうげき" };
const STAT_LETTERS = { h: "H", a: "A", b: "B", c: "C", d: "D", s: "S", vsa: "A" };

const CALC_LEVEL = 50;

const chainMods = (mods) => mods.reduce((acc, mod) => Math.floor((acc * mod + 2048) / 4096), 4096);
const applyMod = (value, mod) => Math.floor((value * mod + 2047) / 4096);
const rankRatio = (rank) => (rank >= 0 ? (2 + rank) / 2 : 2 / (2 - rank));
const applyRank = (value, rank) => (rank >= 0 ? Math.floor((value * (2 + rank)) / 2) : Math.floor((value * 2) / (2 - rank)));

const calcText = (el) => el?.textContent.trim() ?? "";
const calcInt = (el) => parseInt(calcText(el), 10) || 0;

const readEvs = (side, key) => {
    const section = side?.querySelector(`.main_evs.main_evs_${key}`);
    if (!section) return null;
    const select = section.querySelector(".main_evs_ranks select");
    const selected = section.querySelector(".main_evs_nature > .selected");
    return {
        section,
        real: calcInt(section.querySelector(".main_evs_header_value")),
        points: calcInt(section.querySelector(".main_evs_range_num")),
        rank: select ? 6 - select.selectedIndex : 0,
        nature: selected?.classList.contains("main_evs_nature_09") ? 9 : selected?.classList.contains("main_evs_nature_11") ? 11 : 10,
    };
};

const countValue = (side, selector) => {
    const label = side.querySelector(selector);
    return label && !label.hidden ? Number(label.querySelector("select").value) : null;
};

function multiHitRange(move, ability) {
    if (move === "ネズミざん") return { min: 1, max: 10, def: 10 };
    const fixed = CALC_FIXED_MULTI_HIT[move];
    if (fixed && move !== "トリプルアクセル") return { min: fixed.length, max: fixed.length, def: fixed.length };
    if (!CALC_VARIABLE_MULTI_HIT.has(move)) return null;
    return ability === "スキルリンク" ? { min: 5, max: 5, def: 5 } : { min: 2, max: 5, def: 2 };
}

const hitPlan = (atk) => {
    if (atk.move === "トリプルアクセル") {
        const rows = atk.axel?.length ? atk.axel : AXEL_POWERS.map(() => ({ hit: true, crit: false }));
        return rows.map((row, i) => ({ power: AXEL_POWERS[i], crit: row.crit, hit: row.hit })).filter((row) => row.hit);
    }
    const range = multiHitRange(atk.move, atk.ability);
    if (!range) return null;
    const count = Math.min(range.max, Math.max(range.min, atk.hits ?? range.def));
    const crits = Math.min(count, Math.max(0, atk.crits ?? 0));
    const power = CALC_FIXED_MULTI_HIT[atk.move]?.[0];
    return Array.from({ length: count }, (_, i) => ({ power, crit: i < crits }));
};

const firepowerOf = (ctx, basePower) => {
    const { own } = ctx;
    const mods = [...own.bpMods];
    if (ctx.atk.ability === "テクニシャン" && basePower <= 60) mods.splice(own.technicianIndex, 0, 6144);
    const power = Math.max(1, applyMod(basePower, chainMods(mods)));
    return (own.attack * power * ctx.weatherMod * ctx.stab * own.finalMod) / 4096 ** 3 * (ctx.isCrit ? 1.5 : 1) * (ctx.burn ? 0.5 : 1);
};

const clampRank = (rank) => Math.max(-6, Math.min(6, rank));

const withDefRanks = (def, ranks, bonus = 0) => ({
    ...def,
    evs: Object.fromEntries(Object.entries(def.evs).map(([key, e]) => {
        if (!e || (ranks?.[key] === undefined && !(key === "b" && bonus))) return [key, e];
        return [key, { ...e, rank: clampRank((ranks?.[key] ?? e.rank) + (key === "b" ? bonus : 0)) }];
    })),
});

const calcDamage = (atk, def, field, data) => {
    const plan = hitPlan(atk);
    if (!plan) return calcCore(atk, def, field, data);
    const stamina = def.ability === "じきゅうりょく" && !!def.evs.b;
    const scales = def.ability === "マルチスケイル" && def.abilityOn;
    const cores = new Map();
    const coreAt = (crit, i = 0) => {
        const step = Math.max(0, stamina ? Math.min(i, 6 - def.evs.b.rank) : 0);
        const scaleOff = scales && i > 0;
        const key = `${crit}:${step}:${scaleOff}`;
        if (!cores.has(key)) {
            let target = step > 0 ? withDefRanks(def, null, step) : def;
            if (scaleOff) target = { ...target, abilityOn: false };
            cores.set(key, calcCore({ ...atk, crit, single: true }, target, field, data));
        }
        return cores.get(key);
    };
    const base = coreAt(false);
    if (base.status !== "ok") return base;
    if (!plan.length) return { status: "immune", message: "ヒットなし" };
    const crits = plan.filter((p) => p.crit).length;
    const notes = [...base.info.notes];
    if (crits) notes.push({ label: `急所${crits}回`, mul: 1.5, good: true });
    return {
        status: "ok",
        hits: plan.map((p, i) => hitDamages(coreAt(p.crit, i).ctx, p.power ?? base.info.basePower)),
        info: { ...base.info, notes, plan, firepower: Math.round(plan.reduce((sum, p) => sum + firepowerOf(coreAt(p.crit).ctx, p.power ?? base.info.basePower), 0)) },
    };
};

const readSide = (role) => {
    const side = $(`main.${role}`);
    if (!side) return null;
    const search = searchOf(side);
    const base = {};
    ["h", "a", "b", "c", "d", "s"].forEach((key) => { base[key] = calcInt(side.querySelector(`.main_basestats_item.${key} p`)); });
    const item = calcText(side.querySelector("button.main_item_choose p"));
    return {
        side,
        role,
        name: search?.getPokemon().name ?? side.querySelector(".main_search_info input")?.value ?? "",
        base,
        types: [...side.querySelectorAll(".main_search_info_types_item")].map((el) => el.dataset.type),
        ability: calcText(side.querySelector("button.main_ability_choose p")),
        abilityOn: !!side.querySelector("button.main_ability_on")?.classList.contains("active"),
        item: item === "なし" ? "" : item,
        conditions: [...side.querySelectorAll("button.main_condition_item.active:not(:disabled)")].map(calcText),
        crit: !!side.querySelector("button.main_move_weak:not([hidden])")?.classList.contains("active"),
        hits: countValue(side, ".main_move_hits"),
        crits: countValue(side, ".main_move_crits"),
        axel: $$(".main_move_axel_row", side).map((row) => ({ hit: !!$(".hit.active", row), crit: !!$(".crit.active", row) })),
        metronome: countValue(side, ".main_item_metronome"),
        powerUp: !!side.querySelector("button.main_move_powerup:not([hidden])")?.classList.contains("active"),
        move: calcText(side.querySelector("button.main_move_choose p")),
        evs: Object.fromEntries(["h", "a", "vsa", "b", "c", "d", "s"].map((key) => [key, readEvs(side, key)])),
        hpNow: Number(side.querySelector(".main_hpleft")?.dataset.now) || 0,
        speedConditions: [...(speedConditions[role] ?? [])],
        speedAbility: speedAbilityOverride[role]?.name === calcText(side.querySelector("button.main_ability_choose p")) ? speedAbilityOverride[role].on : null,
    };
};

const hpOf = (p) => {
    const max = p.evs.h?.real ?? 0;
    return { max, now: p.hpNow > 0 ? Math.min(p.hpNow, max) : max };
};

const isGrounded = (p) => {
    if (p.item === "くろいてっきゅう" || p.conditions.includes("地面にいる")) return true;
    if (p.types.includes("ひこう")) return false;
    if (["ふゆう", "うなぎのぼり"].includes(p.ability)) return false;
    return p.item !== "ふうせん";
};

const typeEffectiveness = (moveType, defTypes, groundedFlying = false) => defTypes.reduce((mul, defType) => {
    if (moveType === "じめん" && defType === "ひこう" && groundedFlying) return mul;
    return mul * (CALC_TYPE_CHART[moveType]?.[defType] ?? 1);
}, 1);

const realStat = (base, points, nature = 10) => Math.floor(((base + 20 + points) * nature) / 10);

const SPEED_ABILITIES = {
    "すいすい": { mod: 8192, weather: "あめ" },
    "ようりょくそ": { mod: 8192, weather: "はれ" },
    "すなかき": { mod: 8192, weather: "すなあらし" },
    "ゆきかき": { mod: 8192, weather: "ゆき" },
    "サーフテール": { mod: 8192, terrain: "エレキ" },
    "かるわざ": { mod: 8192, toggle: true },
    "はやあし": { mod: 6144, toggle: true },
};

const speedAbilityActive = (p, weather, terrain) => {
    const rule = SPEED_ABILITIES[p.ability];
    if (!rule) return false;
    if (rule.toggle) return p.abilityOn || (p.ability === "はやあし" && (p.speedConditions ?? []).includes("まひ"));
    if (typeof p.speedAbility === "boolean") return p.speedAbility;
    return rule.weather ? rule.weather === weather : rule.terrain === terrain;
};

const speedStat = (p, weather, terrain, { scarf = false, real = p.evs.s?.real ?? 0 } = {}) => {
    const conditions = p.speedConditions ?? [];
    const mods = [];
    if (p.item === "くろいてっきゅう" || conditions.includes("くろいてっきゅう")) mods.push(2048);
    if (scarf) mods.push(6144);
    if (speedAbilityActive(p, weather, terrain)) mods.push(SPEED_ABILITIES[p.ability].mod);
    if (conditions.includes("おいかぜ")) mods.push(8192);
    let speed = applyMod(applyRank(real, p.evs.s?.rank ?? 0), chainMods(mods));
    if (conditions.includes("まひ") && p.ability !== "はやあし") speed = Math.floor(speed / 2);
    return Math.max(1, speed);
};

const effectiveSpeed = (p, weather, terrain) => (p.evs.s ? speedStat(p, weather, terrain) : 0);

const hitDamages = (ctx, basePower, parentalSecond = false) => {
    const bpMods = [...ctx.bpMods];
    if (ctx.atk.ability === "テクニシャン" && basePower <= 60) bpMods.splice(ctx.technicianIndex, 0, 6144);
    const power = Math.max(1, applyMod(basePower, chainMods(bpMods)));
    const levelFactor = Math.floor((CALC_LEVEL * 2) / 5) + 2;
    let base = Math.floor(Math.floor((levelFactor * power * ctx.attack) / ctx.defense) / 50) + 2;
    if (parentalSecond) base = applyMod(base, 1024);
    if (ctx.weatherMod !== 4096) base = applyMod(base, ctx.weatherMod);
    if (ctx.isCrit) base = applyMod(base, 6144);
    return Array.from({ length: 16 }, (_, i) => {
        let damage = Math.floor((base * (85 + i)) / 100);
        if (ctx.stab !== 4096) damage = applyMod(damage, ctx.stab);
        damage = Math.floor(damage * ctx.eff);
        if (ctx.burn) damage = applyMod(damage, 2048);
        if (ctx.finalMod !== 4096) damage = applyMod(damage, ctx.finalMod);
        return Math.max(1, damage);
    });
};

const calcCore = (atk, def, field, data) => {
    const move = data.moves[atk.move];
    if (!move) return { status: "nomove", message: "わざを選んでください" };
    if (move.category === "変化") return { status: "status", message: "変化技です" };
    if (CALC_UNSUPPORTED_MOVES.has(atk.move)) return { status: "unsupported", message: "この技は計算できません" };

    const moldBreaker = atk.ability === "かたやぶり";
    const defAbility = moldBreaker ? "" : def.ability;
    const weather = [atk.ability, def.ability].includes("ノーてんき") ? "" : field.weather;
    const moveWeather = atk.ability === "メガソーラー" ? "はれ" : weather;
    const terrain = field.terrain;
    const terrainName = `${terrain}フィールド`;
    const atkGrounded = isGrounded(atk);
    const defGrounded = isGrounded({ ...def, ability: defAbility });
    const atkItem = atk.ability === "ぶきよう" ? "" : atk.item;
    const defItem = def.ability === "ぶきよう" ? "" : def.item;
    const remarks = (move.remarks ?? "").split(/[、,]/).map((s) => s.trim());
    const has = (flag) => remarks.includes(flag);
    const isContact = has("接触");

    let moveType = move.type;
    if (atk.move === "レイジングブル" && RAGING_BULL_TYPES[atk.name]) moveType = RAGING_BULL_TYPES[atk.name];
    let skinBoost = false;
    let basePower = typeof move.power === "number" ? move.power : 0;
    if (SKIN_ABILITIES[atk.ability] && moveType === "ノーマル") {
        moveType = SKIN_ABILITIES[atk.ability];
        skinBoost = true;
    }
    if (atk.ability === "うるおいボイス" && has("音")) moveType = "みず";
    if (atk.move === "ウェザーボール" && WEATHER_BALL_TYPES[moveWeather]) {
        moveType = WEATHER_BALL_TYPES[moveWeather];
        basePower *= 2;
    }
    if (atk.move === "だいちのはどう" && TERRAIN_TYPES[terrain] && atkGrounded) {
        moveType = TERRAIN_TYPES[terrain];
        basePower *= 2;
    }

    let eff = typeEffectiveness(moveType, def.types, defGrounded);
    if (atk.move === "フライングプレス") eff *= typeEffectiveness("ひこう", def.types);
    if (atk.move === "フリーズドライ" && def.types.includes("みず")) eff *= 4;
    if (moveType === "じめん" && !defGrounded) eff = 0;
    if (IMMUNE_ABILITIES[defAbility] === moveType) eff = 0;
    if (defAbility === "ぼうおん" && has("音")) eff = 0;
    if (defAbility === "ぼうだん" && has("弾")) eff = 0;
    if (eff === 0) return { status: "immune", message: "効果なし" };

    const priority = Number(remarks.find((r) => r.startsWith("優先度"))?.replace("優先度", "") ?? 0);
    if (terrain === "サイコ" && defGrounded && priority > 0) return { status: "immune", message: "フィールドにより無効" };
    if (atk.move === "アイアンローラー" && !terrain) return { status: "immune", message: "フィールドがないと失敗する" };
    if (atk.move === "ポルターガイスト" && !defItem) return { status: "immune", message: "相手が道具を持っていないと失敗する" };

    const { max: defHp, now: defNow } = hpOf(def);
    const { max: atkHp, now: atkNow } = hpOf(atk);
    const info = { moveType, category: move.category, isContact, notes: [] };

    const fixed = (damage, message) => ({
        status: "ok", fixed: true, message, hits: [Array(16).fill(Math.max(1, damage))], info: { ...info, displayPower: move.power },
    });
    if (CALC_OHKO_MOVES.has(atk.move)) {
        if (atk.move === "ぜったいれいど" && def.types.includes("こおり")) return { status: "immune", message: "効果なし" };
        return fixed(defHp, "一撃必殺");
    }
    if (["ちきゅうなげ", "ナイトヘッド"].includes(atk.move)) return fixed(CALC_LEVEL, "固定ダメージ");
    if (atk.move === "いかりのまえば") return fixed(Math.floor(defNow / 2), "相手のHPの半分");
    if (atk.move === "いのちがけ") return fixed(atkNow, "自分のHP分");
    if (atk.move === "がむしゃら") {
        if (defNow <= atkNow) return { status: "immune", message: "失敗する（相手のHPが自分以下）" };
        return fixed(defNow - atkNow, "相手と自分のHPの差");
    }

    const atkSpeed = effectiveSpeed(atk, weather, terrain);
    const defSpeed = effectiveSpeed(def, weather, terrain);
    const weightOf = (p) => {
        const w = data.pokemons[p.name]?.weight ?? 0;
        const ability = p === def ? defAbility : p.ability;
        return ability === "ヘヴィメタル" ? w * 2 : ability === "ライトメタル" ? Math.floor(w * 5) / 10 : w;
    };
    switch (atk.move) {
        case "エレキボール": {
            const ratio = defSpeed > 0 ? atkSpeed / defSpeed : 0;
            basePower = ratio >= 4 ? 150 : ratio >= 3 ? 120 : ratio >= 2 ? 80 : ratio >= 1 ? 60 : 40;
            break;
        }
        case "ジャイロボール":
            basePower = Math.min(150, Math.floor((25 * defSpeed) / Math.max(1, atkSpeed)) + 1);
            break;
        case "くさむすび":
        case "けたぐり": {
            const w = weightOf(def);
            basePower = w >= 200 ? 120 : w >= 100 ? 100 : w >= 50 ? 80 : w >= 25 ? 60 : w >= 10 ? 40 : 20;
            break;
        }
        case "ヒートスタンプ":
        case "ヘビーボンバー": {
            const ratio = weightOf(def) / Math.max(0.1, weightOf(atk));
            basePower = ratio <= 1 / 5 ? 120 : ratio <= 1 / 4 ? 100 : ratio <= 1 / 3 ? 80 : ratio <= 1 / 2 ? 60 : 40;
            break;
        }
        case "ふんか":
        case "しおふき":
        case "ドラゴンエナジー":
            basePower = Math.max(1, Math.floor((150 * atkNow) / Math.max(1, atkHp)));
            break;
        case "きしかいせい":
        case "じたばた": {
            const p = Math.floor((48 * atkNow) / Math.max(1, atkHp));
            basePower = p <= 1 ? 200 : p <= 4 ? 150 : p <= 9 ? 100 : p <= 16 ? 80 : p <= 32 ? 40 : 20;
            break;
        }
        case "ハードプレス":
            basePower = Math.max(1, Math.floor((100 * defNow) / Math.max(1, defHp)));
            break;
        case "アシストパワー":
        case "つけあがる":
            basePower = 20 + 20 * ["a", "b", "c", "d", "s"].reduce((sum, key) => sum + Math.max(0, atk.evs[key]?.rank ?? 0), 0);
            break;
        case "ライジングボルト":
            if (terrain === "エレキ" && defGrounded) basePower *= 2;
            break;
        case "アクロバット":
            if (!atkItem) basePower *= 2;
            break;
        default:
            break;
    }
    const powerUp = atk.powerUp ? CALC_POWER_UP_MOVES[atk.move] : null;
    if (powerUp?.kind === "base") basePower *= 2;
    if (!basePower) return { status: "unsupported", message: "この技は計算できません" };

    const solarWeak = ["ソーラービーム", "ソーラーブレード"].includes(atk.move) && ["あめ", "すなあらし", "ゆき"].includes(moveWeather);
    const knockOff = atk.move === "はたきおとす" && defItem;
    const expanding = atk.move === "ワイドフォース" && terrain === "サイコ" && atkGrounded;
    const displayMods = [];
    if (knockOff) displayMods.push(6144);
    if (expanding) displayMods.push(6144);
    if (solarWeak) displayMods.push(2048);
    if (powerUp?.kind === "power") displayMods.push(powerUp.mod);
    if (powerUp?.kind === "damage") displayMods.push(8192);
    info.basePower = basePower;
    info.displayPower = Math.max(1, applyMod(basePower, chainMods(displayMods)));

    const isPhysical = move.category === "物理";
    const isCrit = atk.crit || CALC_ALWAYS_CRIT_MOVES.has(atk.move);
    const notes = info.notes;
    const note = (label, mul, good = mul > 1) => { if (mul !== 1) notes.push({ label, mul, good }); };
    const pushMod = (list, good, own) => (mod, label, opp = false) => {
        list.push(mod);
        if (own && !opp) own.push(mod);
        note(label, mod / 4096, good ? mod > 4096 : mod < 4096);
    };

    const bpMods = [];
    const bpOwn = [];
    const bp = pushMod(bpMods, true, bpOwn);
    if (skinBoost) bp(4915, atk.ability);
    if (atk.ability === "てつのこぶし" && has("パンチ")) bp(4915, atk.ability);
    if (atk.ability === "すてみ" && CALC_RECOIL_MOVES.has(atk.move)) bp(4915, atk.ability);
    if (atk.ability === "とうそうしん" && atk.abilityOn) bp(5120, atk.ability);
    if (atk.ability === "かたいツメ" && isContact) bp(5325, atk.ability);
    if (atk.ability === "アナライズ" && atk.abilityOn) bp(5325, atk.ability);
    if (atk.ability === "すなのちから" && weather === "すなあらし" && ["いわ", "じめん", "はがね"].includes(moveType)) bp(5325, atk.ability);
    if (atk.ability === "ちからずく" && CALC_SECONDARY_MOVES.has(atk.move)) bp(5325, atk.ability);
    if (atk.ability === "パンクロック" && has("音")) bp(5325, atk.ability);
    if (moveType === "フェアリー" && [atk.ability, def.ability].includes("フェアリーオーラ")) bp(5448, "フェアリーオーラ", atk.ability !== "フェアリーオーラ");
    const technicianIndex = bpMods.length;
    const technicianOwnIndex = bpOwn.length;
    const powers = CALC_FIXED_MULTI_HIT[atk.move] ?? [basePower];
    if (atk.ability === "テクニシャン" && powers.some((p) => p <= 60)) note("テクニシャン", 1.5);
    if (atk.ability === "がんじょうあご" && has("噛み")) bp(6144, atk.ability);
    if (atk.ability === "メガランチャー" && has("波動")) bp(6144, atk.ability);
    if (atk.ability === "きれあじ" && has("切り")) bp(6144, atk.ability);
    if (atk.ability === "はがねのせいしん" && moveType === "はがね") bp(6144, atk.ability);
    if (atk.ability === "ほのおのたてがみ" && moveType === "ほのお") bp(6144, atk.ability);
    if (defAbility === "かんそうはだ" && moveType === "ほのお") bp(5120, defAbility, true);
    if (atkItem === "ちからのハチマキ" && isPhysical) bp(4505, atkItem);
    if (atkItem === "ものしりメガネ" && !isPhysical) bp(4505, atkItem);
    if (TYPE_BOOST_ITEMS[atkItem] === moveType) bp(4915, atkItem);
    if (atkItem === "ノーマルジュエル" && moveType === "ノーマル") bp(5325, atkItem);
    if (solarWeak) bp(2048, WEATHER_NAMES[moveWeather]);
    if (knockOff) bp(6144, "はたきおとす", true);
    if (expanding) bp(6144, terrainName);
    if (powerUp?.kind === "power") bp(powerUp.mod, "威力アップ");
    if (moveType === "でんき" && atk.conditions.includes("じゅうでん")) bp(8192, "じゅうでん");
    else if (moveType === "でんき" && atk.ability === "でんきにかえる" && atk.abilityOn) bp(8192, atk.ability);
    if (atkGrounded && TERRAIN_TYPES[terrain] === moveType && terrain !== "ミスト") bp(5325, terrainName);
    if (defGrounded && terrain === "グラス" && ["じしん", "じならし"].includes(atk.move)) bp(2048, terrainName);
    if (defGrounded && terrain === "ミスト" && moveType === "ドラゴン") bp(2048, terrainName);

    const offenseKey = atk.move === "ボディプレス" ? "b" : atk.move === "イカサマ" ? "vsa" : isPhysical ? "a" : "c";
    const offense = atk.evs[offenseKey];
    if (!offense) return { status: "unsupported", message: "能力値が見つかりません" };
    let atkRank = offense.rank;
    if (["エレクトロビーム", "メテオビーム"].includes(atk.move)) atkRank = Math.min(6, atkRank + 1);
    const ownRank = isCrit && atkRank < 0 ? 0 : atkRank;
    if (defAbility === "てんねん") atkRank = 0;
    if (isCrit && atkRank < 0) atkRank = 0;
    note(`${STAT_NAMES[offenseKey]}ランク`, rankRatio(atkRank));
    const atkMods = [];
    const atkOwn = [];
    const am = pushMod(atkMods, true, atkOwn);
    const gutsActive = atk.ability === "こんじょう" && atk.abilityOn;
    if (isPhysical && ["ちからもち", "ヨガパワー"].includes(atk.ability)) am(8192, atk.ability);
    if (isPhysical && atk.ability === "はりきり") am(6144, atk.ability);
    if (isPhysical && gutsActive) am(6144, atk.ability);
    if (PINCH_ABILITIES[atk.ability] === moveType && atk.abilityOn) am(6144, atk.ability);
    if (!isPhysical && atk.ability === "サンパワー" && moveWeather === "はれ") am(6144, atk.ability);
    if (!isPhysical && ["プラス", "マイナス"].includes(atk.ability) && atk.abilityOn) am(6144, atk.ability);
    if (atk.ability === "もらいび" && atk.abilityOn && moveType === "ほのお") am(6144, atk.ability);
    if (atk.ability === "すいほう" && moveType === "みず") am(8192, atk.ability);
    if (atk.ability === "はりこみ" && atk.abilityOn) am(8192, atk.ability);
    if (atkItem === "でんきだま" && atk.name === "ピカチュウ") am(8192, atkItem);
    if (defAbility === "あついしぼう" && ["ほのお", "こおり"].includes(moveType)) am(2048, defAbility, true);
    if (["たいねつ", "すいほう"].includes(defAbility) && moveType === "ほのお") am(2048, defAbility, true);
    if (defAbility === "きよめのしお" && moveType === "ゴースト") am(2048, defAbility, true);
    const attack = Math.max(1, applyMod(applyRank(offense.real, atkRank), chainMods(atkMods)));

    const useDefense = isPhysical || atk.move === "サイコショック";
    const defenseKey = useDefense ? "b" : "d";
    const defense0 = def.evs[defenseKey];
    if (!defense0) return { status: "unsupported", message: "能力値が見つかりません" };
    let defRank = defense0.rank;
    if (atk.ability === "てんねん" || ["DDラリアット", "せいなるつるぎ"].includes(atk.move)) defRank = 0;
    if (isCrit && defRank > 0) defRank = 0;
    note(`${STAT_NAMES[defenseKey]}ランク`, rankRatio(defRank), defRank < 0);
    const defMods = [];
    const dm = pushMod(defMods, false);
    if (useDefense && defAbility === "ファーコート") dm(8192, defAbility);
    if (useDefense && defAbility === "ふしぎなうろこ" && def.abilityOn) dm(6144, defAbility);
    if (useDefense && defAbility === "くさのけがわ" && terrain === "グラス") dm(6144, defAbility);
    if (!useDefense && weather === "すなあらし" && def.types.includes("いわ")) dm(6144, "すなあらし");
    if (useDefense && weather === "ゆき" && def.types.includes("こおり")) dm(6144, "ゆき");
    const defense = Math.max(1, applyMod(applyRank(defense0.real, defRank), chainMods(defMods)));

    let weatherMod = 4096;
    if (moveWeather === "はれ") weatherMod = moveType === "ほのお" ? 6144 : moveType === "みず" ? 2048 : 4096;
    if (moveWeather === "あめ") weatherMod = moveType === "みず" ? 6144 : moveType === "ほのお" ? 2048 : 4096;
    note(WEATHER_NAMES[moveWeather], weatherMod / 4096);
    if (isCrit) note("急所", 1.5);

    const stabActive = atk.types.includes(moveType);
    const stab = stabActive ? (atk.ability === "てきおうりょく" ? 8192 : 6144) : 4096;
    note("タイプ一致", stab / 4096);
    note("タイプ相性", eff);

    const burn = isPhysical && atk.conditions.includes("やけど") && !gutsActive && atk.move !== "からげんき";
    if (burn) note("やけど", 0.5);

    const superEffective = eff > 1;
    const finalMods = [];
    const finalOwn = [];
    const fm = pushMod(finalMods, true, finalOwn);
    const screenName = isPhysical ? "リフレクター" : "ひかりのかべ";
    if (def.conditions.includes(screenName) && !isCrit && atk.ability !== "すりぬけ" && !CALC_SCREEN_BREAK_MOVES.has(atk.move)) fm(2048, screenName, true);
    if (isCrit && atk.ability === "スナイパー") fm(6144, atk.ability);
    if (defAbility === "もふもふ" && moveType === "ほのお") fm(8192, defAbility, true);
    if (defAbility === "マルチスケイル" && def.abilityOn) fm(2048, defAbility, true);
    if (["もふもふ", "はどうのぼうご"].includes(defAbility) && isContact) fm(2048, defAbility, true);
    if (defAbility === "パンクロック" && has("音")) fm(2048, defAbility, true);
    if (["ハードロック", "フィルター"].includes(defAbility) && superEffective) fm(3072, defAbility, true);
    if (atkItem === "たつじんのおび" && superEffective) fm(4915, atkItem, true);
    if (atkItem === "いのちのたま") fm(5324, atkItem);
    if (atkItem === "メトロノーム" && atk.metronome > 1) fm([4915, 5734, 6553, 7372, 8192][Math.min(atk.metronome, 6) - 2], `${atkItem}（${atk.metronome >= 6 ? "6回目以上" : `${atk.metronome}回目`}）`);
    const berryType = CALC_HALF_BERRIES[defItem];
    if (berryType && berryType === moveType && (superEffective || berryType === "ノーマル")) fm(defAbility === "じゅくせい" ? 1024 : 2048, defItem, true);
    if (powerUp?.kind === "damage") fm(8192, powerUp.label ?? "威力アップ");
    if (def.conditions.includes("無防備状態")) fm(8192, "無防備状態", true);

    const ctx = {
        atk, eff, isCrit, weatherMod, bpMods, technicianIndex, attack, defense, stab, burn, finalMod: chainMods(finalMods),
        own: {
            attack: Math.max(1, applyMod(applyRank(offense.real, ownRank), chainMods(atkOwn))),
            bpMods: bpOwn,
            technicianIndex: technicianOwnIndex,
            finalMod: chainMods(finalOwn),
        },
    };

    if (atk.single) return { status: "ok", ctx, info: { ...info, offenseKey, defenseKey } };
    const parental = atk.ability === "おやこあい";
    const hits = parental ? [hitDamages(ctx, basePower), hitDamages(ctx, basePower, true)] : [hitDamages(ctx, basePower)];
    return { status: "ok", hits, info: { ...info, offenseKey, defenseKey, firepower: Math.round(firepowerOf(ctx, basePower) * (parental ? 1.25 : 1)) } };
};

const convolve = (a, b, cap) => {
    const next = new Map();
    a.forEach((p, x) => {
        b.forEach((q, y) => {
            const key = Math.min(cap, x + y);
            next.set(key, (next.get(key) ?? 0) + p * q);
        });
    });
    return next;
};
const uniform = (damages) => {
    const dist = new Map();
    damages.forEach((d) => dist.set(d, (dist.get(d) ?? 0) + 1 / damages.length));
    return dist;
};

const useDistribution = (result, hp) => result.hits.reduce((dist, damages) => convolve(dist, uniform(damages), hp), new Map([[0, 1]]));

const knockOutFrom = (perUse, hp) => {
    if (hp <= 0) return null;
    let dist = new Map([[0, 1]]);
    for (let n = 1; n <= 10; n++) {
        dist = convolve(dist, perUse, hp);
        const rate = dist.get(hp) ?? 0;
        if (rate > 1e-9) return { hits: n, rate: Math.min(1, rate) };
    }
    return { hits: Infinity, rate: 0 };
};

const useRange = (result) => ({
    min: result.hits.reduce((sum, d) => sum + Math.min(...d), 0),
    max: result.hits.reduce((sum, d) => sum + Math.max(...d), 0),
});

const hpColor = (ratio) => (ratio >= 0.5 ? "#00c950" : ratio >= 0.25 ? "#ff8904" : "#fb2c36");
const fixed1 = (value) => (Math.round(value * 10) / 10).toFixed(1);
const fixed2 = (value) => (Math.round(value * 100) / 100).toFixed(2);
const pairText = (a, b, unit = "") => (a === b ? `${a}${unit}` : `${a}～${b}${unit}`);
const percentPair = (a, b, base) => pairText(fixed1((a / base) * 100), fixed1((b / base) * 100), "%");
const mulText = (mul) => `×${Math.round(mul * 100) / 100}`;

const setText = (el, text) => {
    if (el && el.textContent !== text) el.textContent = text;
};

const fillResult = (root, prefix, hp, min, max, judgeText, rateText) => {
    if (!root) return;
    const q = (name) => root.querySelector(`.${prefix}_${name}`);
    setText(q("damage_num_max"), String(hp.max));
    const pct = (v) => `${fixed1(hp.max > 0 ? (v / hp.max) * 100 : 0)}%`;
    setText(q("damage_percent"), min === max ? pct(min) : `${pct(min)}～${pct(max)}`);
    setText(q("damage_num_take"), pairText(min, max));
    const clamp = (v) => Math.min(1, Math.max(0, v));
    const sure = hp.max > 0 ? clamp((hp.now - max) / hp.max) : 0;
    const maybe = hp.max > 0 ? clamp((hp.now - min) / hp.max) : 0;
    [[q("hpbar_kaku"), sure], [q("hpbar_ran"), maybe]].forEach(([bar, ratio]) => {
        if (!bar) return;
        bar.style.width = `${ratio * 100}%`;
        bar.style.backgroundColor = hpColor(sure);
    });
    setText(q("judgement"), judgeText);
    const percent = q("judge_percent");
    if (percent) {
        percent.hidden = rateText === null;
        if (rateText !== null) setText(percent, rateText);
    }
};

const constantSign = (e) => (e.kind === "damage" ? 1 : -1);

const summarize = (list, hp, multi) => {
    const ok = list.filter((e) => e.constant || e.result?.status === "ok");
    if (!ok.length) return { text: list.find((e) => e.result)?.result.message ?? "計算できません", rate: null, min: 0, max: 0 };
    const paths = [0, 1].map(() => ({ hp: hp.now, damage: 0 }));
    const hit = (amounts) => paths.forEach((path, i) => {
        const amount = amounts[i];
        if (amount < 0 && path.hp <= 0) return;
        const next = amount < 0 ? Math.min(hp.max, path.hp - amount) : path.hp - amount;
        path.damage += path.hp - next;
        path.hp = next;
    });
    let remain = new Map([[hp.now, 1]]);
    const step = (transition) => {
        const next = new Map();
        remain.forEach((p, h) => transition(h).forEach((q, v) => next.set(v, (next.get(v) ?? 0) + p * q)));
        remain = next;
    };
    ok.forEach((e) => {
        if (e.constant) {
            const delta = constantSign(e) * e.constant.total;
            hit([delta, delta]);
            step((h) => new Map([[h <= 0 ? 0 : Math.max(0, Math.min(hp.max, h - delta)), 1]]));
            return;
        }
        const range = useRange(e.result);
        hit([range.min, range.max]);
        const perUse = useDistribution(e.result, hp.max);
        step((h) => {
            const out = new Map();
            perUse.forEach((q, d) => {
                const v = Math.max(0, h - d);
                out.set(v, (out.get(v) ?? 0) + q);
            });
            return out;
        });
    });
    const base = { min: paths[0].damage, max: paths[1].damage, rate: null };
    if (multi) return { ...base, text: `ひんし率${fixed1((remain.get(0) ?? 0) * 100)}%` };
    const only = ok[0];
    const dist = only.constant ? new Map([[Math.max(0, constantSign(only) * only.constant.total), 1]]) : useDistribution(only.result, hp.now);
    const ko = knockOutFrom(dist, hp.now);
    if (!ko || ko.hits === Infinity) return { ...base, text: "10発以上" };
    if (ko.rate >= 1 - 1e-9) return { ...base, text: `確定${ko.hits}発` };
    return { ...base, text: `乱数${ko.hits}発`, rate: `${fixed2(ko.rate * 100)}%` };
};

const calcData = { moves: {}, pokemons: {} };
const calcReady = Promise.all([
    loadJson("moves.json").then((json) => { calcData.moves = json; }),
    loadJson("pokemons.json").then((json) => { calcData.pokemons = json; }),
]).catch((err) => console.error(err));

const updateFoulPlayStat = (atk, def, writeHeader = true) => {
    const vsa = atk.evs.vsa;
    if (!vsa || !def) return;
    vsa.real = realStat(def.base.a, vsa.points, vsa.nature);
    if (writeHeader) setText(vsa.section?.querySelector(".main_evs_header_value"), String(vsa.real));
};

const ENVIRONMENT_WEATHER = { none: "", sun: "はれ", rain: "あめ", sand: "すなあらし", snow: "ゆき" };
const ENVIRONMENT_FIELD = { none: "", electric: "エレキ", grass: "グラス", psycho: "サイコ", mist: "ミスト" };
const selectedEnvironment = (kind, values) => {
    const button = $(`.modal_environment_${kind}_select button.selected`);
    const key = [...(button?.classList ?? [])].map((c) => c.split("_").pop()).find((k) => k in values);
    return values[key] ?? "";
};
const readField = () => ({ weather: selectedEnvironment("weather", ENVIRONMENT_WEATHER), terrain: selectedEnvironment("field", ENVIRONMENT_FIELD) });

const shareWith = (stored, source) => ({
    ...stored,
    ability: source.ability,
    abilityOn: stored.ability === source.ability ? stored.abilityOn : source.abilityOn,
    item: source.item,
    evs: Object.fromEntries(Object.entries(stored.evs).map(([key, e]) => [key, e && source.evs[key] ? { ...source.evs[key], rank: e.rank } : e && { ...e }])),
});

function captureCalcInput() {
    const atk = readSide("attacker");
    return atk ? { atk, field: readField() } : null;
}

const calcState = { entries: [], attacks: [], def: null, hp: { max: 0, now: 0 }, multi: false, summary: null };

const runCalc = () => {
    const atk = readSide("attacker");
    let def = readSide("defender");
    if (!atk || !def) return;
    const field = readField();
    const hp = hpOf(def);
    const stamina = def.ability === "じきゅうりょく";
    const multiscale = def.ability === "マルチスケイル";
    const multiscaleOn = multiscale && multiscaleUserOn();
    const offsets = readDefRanks();
    let taken = 0;
    let damaged = false;
    let liveResult = null;

    const tabs = orderTabs.length ? orderTabs : [{ kind: "attack", id: 0 }];
    const entries = tabs.map((tab, i) => {
        if (tab.kind !== "attack") {
            const constant = constantBreakdown(tab, hp.max);
            if (tab.kind === "damage" && constant.total > 0) damaged = true;
            return { tab, kind: tab.kind, constant };
        }
        const bonus = stamina ? taken : 0;
        const abilityOn = multiscale ? multiscaleOn && !damaged : null;
        let entry;
        if (i === orderActive || !tab.calcInput) {
            const changed = syncDefRankBonus(bonus);
            if (lockMultiscale(multiscale && damaged, multiscale) || changed) def = readSide("defender");
            if (abilityOn !== null) def.abilityOn = abilityOn;
            updateFoulPlayStat(atk, def);
            liveResult = calcDamage(atk, def, field, calcData);
            entry = { tab, kind: "attack", atk, def, field, result: liveResult };
        } else {
            const tabDef = withDefRanks(def, tab.defRanks ?? offsets, bonus);
            if (abilityOn !== null) tabDef.abilityOn = abilityOn;
            const stored = tab.calcInput.atk;
            const source = stored.name === atk.name ? atk : sharedPokemon[stored.name]?.atk;
            const merged = source && source !== stored ? shareWith(stored, source) : { ...stored };
            updateFoulPlayStat(merged, tabDef, false);
            entry = { tab, kind: "attack", atk: merged, def: tabDef, field: tab.calcInput.field, result: calcDamage(merged, tabDef, tab.calcInput.field, calcData) };
        }
        if (entry.result.status === "ok") {
            taken += entry.result.hits.length;
            damaged = true;
        }
        return entry;
    });
    if (!liveResult) {
        updateFoulPlayStat(atk, def);
        liveResult = calcDamage(atk, def, field, calcData);
    }
    renderMovePower(atk, liveResult);
    const attacks = entries.filter((e) => e.kind === "attack");
    const multi = entries.length > 1;
    const summary = summarize(entries, hp, multi);
    Object.assign(calcState, { entries, attacks, def, hp, multi, summary });
    fillResult($(".card_result"), "card_result", hp, summary.min, summary.max, summary.text, summary.rate);
    pushNativeState();
    recordHistory();
    if ($("section.speed.is-open")) renderSpeed();
    refreshConstantPanel();
    if ($("section.detail.is-open")) renderDetail();
};

const renderMovePower = (atk, result) => {
    const el = atk.side.querySelector(".main_move_header_info_power");
    const move = calcData.moves[atk.move];
    if (!el || !move) return;
    const shown = result.info?.displayPower ?? move.power;
    setText(el, String(shown));
    el.classList.toggle("is-boosted", atk.powerUp || (typeof move.power === "number" && typeof shown === "number" && shown > move.power));
};

const hpEffects = (entry, def) => {
    const { atk, result } = entry;
    if (result?.status !== "ok") return [];
    const { max, now } = hpOf(atk);
    const defNow = hpOf(def).now;
    const magic = atk.ability === "マジックガード";
    const contacts = result.info.isContact && !magic
        ? [[def.item === "ゴツゴツメット", def.item, 6], [["さめはだ", "てつのトゲ"].includes(def.ability), def.ability, 8]].filter(([on]) => on)
        : [];
    const drain = CALC_DRAIN_RATIO[atk.move];
    const recoil = !magic && atk.ability !== "いしあたま" && CALC_RECOIL_RATIO[atk.move];
    const sheerForce = atk.ability === "ちからずく" && CALC_SECONDARY_MOVES.has(atk.move);
    const rows = new Map();
    const paths = [Math.min, Math.max].map((pick) => {
        const path = { hp: now, defHp: defNow, dealt: 0 };
        const apply = (name, amount) => {
            if (!amount) return;
            const before = path.hp;
            if (before > 0) path.hp = Math.max(0, Math.min(max, before + amount));
            const row = rows.get(name) ?? { name, p: [0, 0], max };
            row.p[pick === Math.min ? 0 : 1] = path.hp - before;
            rows.set(name, row);
        };
        result.hits.forEach((damages, i) => {
            if (path.defHp <= 0) return;
            const dealt = Math.min(pick(...damages), path.defHp);
            path.defHp -= dealt;
            path.dealt += dealt;
            contacts.forEach(([, name, ratio]) => apply(result.hits.length > 1 ? `${name}（${i + 1}回目）` : name, -Math.max(1, Math.floor(max / ratio))));
        });
        if (drain) apply(atk.item === "おおきなねっこ" ? `${atk.move}（おおきなねっこ）` : atk.move, (atk.item === "おおきなねっこ" ? (v) => applyMod(v, 5324) : (v) => v)(Math.max(1, Math.round(path.dealt * drain))));
        if (atk.item === "かいがらのすず") apply(atk.item, Math.floor(path.dealt / 8));
        if (recoil) apply(atk.move, -Math.max(1, Math.round(path.dealt * recoil)));
        if (atk.move === "てっていこうせん" && !magic) apply(atk.move, -Math.round(max / 2));
        if (CALC_SELF_KO_MOVES.has(atk.move)) apply(atk.move, -now);
        if (atk.item === "いのちのたま" && !magic && !sheerForce) apply(atk.item, -Math.max(1, Math.floor(max / 10)));
        return path;
    });
    return [...rows.values()].map((row) => ({ ...row, lo: Math.min(...row.p), hi: Math.max(...row.p), final: paths.map((path) => path.hp) }));
};

const signClass = (lo, hi) => (lo + hi >= 0 ? "plus" : "minus");
const absPair = (lo, hi) => {
    const a = Math.abs(lo);
    const b = Math.abs(hi);
    return lo < 0 && hi > 0 ? `${lo}～+${hi}` : pairText(Math.min(a, b), Math.max(a, b));
};

let detailSelected = null;

const statText = (p, keys, withRank = true) => keys.filter((key) => p.evs[key]).map((key) => {
    const e = p.evs[key];
    const nature = e.nature === 11 ? "↑" : e.nature === 9 ? "↓" : "";
    const rank = withRank && key !== "h" && e.rank ? ` ${e.rank > 0 ? "+" : ""}${e.rank}` : "";
    return `${STAT_LETTERS[key]}${e.points}${nature}${rank}`;
}).join(" ");

const typesHtml = (types) => types.map((type) => `<div class="detail_overview_match_sprite_types_item">${TYPE_BY_JA[type]?.svg ?? ""}</div>`).join("");

const flowItemHtml = (entry, index) => {
    if (entry.kind !== "attack") {
        const { parts, total } = entry.constant;
        const sign = entry.kind === "damage" ? "" : "+";
        return `<div class="detail_overview_flow_item is-constant ${entry.kind}${entry.tab.id === detailSelected ? " selected" : ""}" data-id="${entry.tab.id}">
            <div class="detail_overview_flow_closing">
                <p class="detail_overview_flow_num">${index + 1}</p>
                <div class="detail_overview_flow_info">
                    <p class="detail_overview_flow_info_match">${CONSTANT_KINDS[entry.kind].title}</p>
                    <p class="detail_overview_flow_info_other">${parts.map((p) => p.label).join("・") || "なし"}</p>
                </div>
                <div class="detail_overview_flow_damage">
                    <p class="detail_overview_flow_damage_percent">${sign}${fixed1((total / Math.max(1, calcState.hp.max)) * 100)}%</p>
                    <p class="detail_overview_flow_damage_num">${sign}${total}</p>
                </div>
            </div>
        </div>`;
    }
    const { atk, result } = entry;
    const ok = result?.status === "ok";
    const range = ok ? useRange(result) : null;
    const plan = result?.info?.plan;
    const crits = plan?.filter((p) => p.crit).length ?? 0;
    const flags = [atk.move, plan && `${plan.length}回`, (atk.crit || crits) && `急所${crits ? `${crits}回` : ""}`, atk.powerUp && "威力アップ"].filter(Boolean).join("・");
    const groups = new Map();
    if (ok && !result.fixed) {
        result.hits.forEach((row, i) => {
            const p = plan?.[i];
            const key = p ? `${atk.move === "トリプルアクセル" ? `威力${p.power} ` : ""}${p.crit ? "急所" : "通常"}` : result.hits.length > 1 ? `${i + 1}発目` : "ダメージ";
            const group = groups.get(key) ?? { row, count: 0 };
            group.count += 1;
            groups.set(key, group);
        });
    }
    const table = groups.size ? `<table>
        <tr><th>乱数</th>${[...groups.values()][0].row.map((_, i) => `<th>${85 + i}</th>`).join("")}</tr>
        ${[...groups].map(([label, { row, count }]) => `<tr><th>${label}${count > 1 ? `×${count}` : ""}</th>${row.map((d) => `<td>${d}</td>`).join("")}</tr>`).join("")}
    </table>` : "";
    const chips = ok ? result.info.notes.map((n) => `<p class="${n.good ? "plus" : "minus"}">${n.label} <span>${mulText(n.mul)}</span></p>`).join("") : "";
    return `<div class="detail_overview_flow_item${entry.tab.id === detailSelected ? " selected" : ""}" data-id="${entry.tab.id}">
        <div class="detail_overview_flow_closing">
            <p class="detail_overview_flow_num">${index + 1}</p>
            <div class="detail_overview_flow_info">
                <p class="detail_overview_flow_info_match">${atk.name}→${calcState.def.name}</p>
                <p class="detail_overview_flow_info_other">${flags}</p>
            </div>
            <div class="detail_overview_flow_damage">
                <p class="detail_overview_flow_damage_percent">${ok ? percentPair(range.min, range.max, calcState.hp.max) : result?.message ?? "-"}</p>
                ${ok ? `<p class="detail_overview_flow_damage_num">${pairText(range.min, range.max)}</p>` : ""}
            </div>
            ${ok ? `<button class="detail_overview_flow_open"><svg viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg></button>` : ""}
        </div>
        ${ok ? `<div class="detail_overview_flow_opening">
            <div class="detail_overview_flow_range">${table}</div>
            <div class="detail_overview_flow_scaling">${chips}</div>
        </div>` : ""}
    </div>`;
};

const sumItemHtml = () => {
    const { min, max } = calcState.summary;
    return `<div class="detail_overview_flow_item sum${detailSelected === "sum" ? " selected" : ""}" data-id="sum">
        <div class="detail_overview_flow_closing">
            <p class="detail_overview_flow_num">∑</p>
            <div class="detail_overview_flow_info"><p class="detail_overview_flow_info_match">合計ダメージ</p></div>
            <div class="detail_overview_flow_damage">
                <p class="detail_overview_flow_damage_percent">${percentPair(min, max, calcState.hp.max)}</p>
                <p class="detail_overview_flow_damage_num">${pairText(min, max)}</p>
            </div>
        </div>
    </div>`;
};

const fitFlowItem = (item, animate = true) => {
    const opening = item.querySelector(".detail_overview_flow_opening");
    const open = item.classList.contains("selected") && !!opening;
    if (!animate) {
        item.style.height = open ? "auto" : "";
        return;
    }
    item.style.height = `${item.offsetHeight}px`;
    item.offsetHeight;
    item.style.height = open ? `${56 + opening.scrollHeight}px` : "";
    if (open) {
        item.addEventListener("transitionend", function done(e) {
            if (e.propertyName !== "height") return;
            item.removeEventListener("transitionend", done);
            if (item.classList.contains("selected")) item.style.height = "auto";
        });
    }
};

const detailQuery = (selector) => $(`section.detail ${selector}`);
const uniqueJoin = (values, separator = "・") => [...new Set(values.filter(Boolean))].join(separator);

const detailView = () => {
    const { attacks, multi, entries } = calcState;
    const entry = attacks.find((e) => e.tab.id === detailSelected);
    if (entry) return { sum: false, list: [entry] };
    const constant = entries.find((e) => e.kind !== "attack" && e.tab.id === detailSelected);
    if (constant) return { sum: false, list: [], constant };
    detailSelected = multi ? "sum" : attacks[0]?.tab.id ?? null;
    return { sum: multi, list: multi ? attacks : attacks.slice(0, 1) };
};

const renderHppm = (list) => {
    const { def } = calcState;
    const q = detailQuery;
    const effects = list.flatMap((e) => hpEffects(e, def));
    q(".detail_hppm").hidden = !effects.length;
    if (!effects.length) return;
    const totals = [0, 1].map((i) => effects.reduce((sum, e) => sum + e.p[i], 0));
    const lo = Math.min(...totals);
    const hi = Math.max(...totals);
    const max = effects[0].max;
    const sign = signClass(lo, hi);
    const small = Math.min(Math.abs(lo), Math.abs(hi));
    const large = Math.max(Math.abs(lo), Math.abs(hi));
    q(".detail_hppm_header_sum").className = `detail_hppm_header_sum ${sign}`;
    setText(q(".detail_hppm_header_num"), absPair(lo, hi));
    setText(q(".detail_hppm_header_percent"), percentPair(small, large, max));
    const [kaku, ran] = sign === "plus" ? [small / max, large / max] : [Math.max(0, max - large) / max, Math.max(0, max - small) / max];
    [[q(".detail_hppm_hpbar_kaku"), kaku], [q(".detail_hppm_hpbar_ran"), ran]].forEach(([bar, ratio]) => {
        bar.style.width = `${Math.min(1, ratio) * 100}%`;
        bar.style.backgroundColor = sign === "plus" ? "#00c950" : "#fb2c36";
    });
    q(".detail_hppm_list").innerHTML = effects.map((e) => {
        const cls = signClass(e.lo, e.hi);
        const a = Math.min(Math.abs(e.lo), Math.abs(e.hi));
        const b = Math.max(Math.abs(e.lo), Math.abs(e.hi));
        return `<div class="detail_hppm_item">
            <p class="detail_hppm_item_name">${e.name}</p>
            <div class="detail_hppm_item_damage">
                <p class="detail_hppm_item_num ${cls}">${pairText(a, b)}</p>
                <p class="detail_hppm_item_percent ${cls}">${percentPair(a, b, e.max)}</p>
            </div>
        </div>`;
    }).join("");
};

function renderView() {
    const detail = $("section.detail");
    const { def, hp, attacks, entries } = calcState;
    if (!detail || !def || !entries.length) return;
    const { sum, list, constant } = detailView();
    const q = detailQuery;
    const first = list[0];
    const [atkItem, defItem] = detail.querySelectorAll(".detail_overview_match_item");
    detail.classList.toggle("is-constant", !!constant);
    atkItem.style.visibility = constant ? "hidden" : "";
    if (constant || !attacks.length) {
        renderConstantView(constant, defItem);
        syncDividers(detail);
        return;
    }
    q(".detail_overview_log").classList.remove("is-heal");
    const names = [...new Set(list.map((e) => e.atk.name))];

    const single = names.length === 1;
    const same = (pick) => {
        const values = new Set(list.map(pick));
        return values.size === 1 ? [...values][0] : null;
    };
    const visible = (value) => !sum || (single && value !== null);
    const envText = ({ field: { weather, terrain } }) => `${WEATHER_NAMES[weather] ?? "天候なし"}・${terrain ? `${terrain}フィールド` : "フィールドなし"}`;
    const offenseKeys = [...new Set(list.map((e) => e.result?.info?.offenseKey).filter(Boolean))];
    const defenseKeys = [...new Set(list.map((e) => e.result?.info?.defenseKey ?? "b"))];
    const ranksSame = same((e) => offenseKeys.map((key) => e.atk.evs[key]?.rank ?? 0).join()) !== null;
    const defRanksSame = same((e) => defenseKeys.map((key) => (e.def ?? def).evs[key]?.rank ?? 0).join()) !== null;
    const toggleText = (el, value) => {
        el.hidden = !visible(value);
        if (value !== null) setText(el, value);
    };

    const atkSprite = atkItem.querySelector(".detail_overview_match_sprite");
    atkSprite.querySelectorAll("img").forEach((img) => img.remove());
    atkSprite.insertAdjacentHTML("afterbegin", names.map((name) => `<img src="${spriteOf(calcData.pokemons[name])}" alt="">`).join(""));
    atkSprite.classList.toggle("is-multi", !single);
    const atkTypes = same((e) => e.atk.types.join(","));
    atkSprite.querySelector(".detail_overview_match_sprite_types").innerHTML = visible(atkTypes) ? typesHtml(first.atk.types) : "";
    setText(atkItem.querySelector(".detail_overview_match_name"), names.join("・"));
    toggleText(atkItem.querySelector(".detail_overview_match_stat"), statText(first.atk, offenseKeys, ranksSame));

    defItem.querySelector(".detail_overview_match_sprite img").src = spriteOf(calcData.pokemons[def.name]);
    defItem.querySelector(".detail_overview_match_sprite_types").innerHTML = visible("") ? typesHtml(def.types) : "";
    setText(defItem.querySelector(".detail_overview_match_name"), def.name);
    const hpRest = hp.now < hp.max ? ` 残${fixed1((hp.now / hp.max) * 100)}%` : "";
    toggleText(defItem.querySelector(".detail_overview_match_stat"), statText(first.def ?? def, ["h", ...defenseKeys], defRanksSame) + hpRest);

    const info = q(".detail_overview_match_detail_info");
    setText(q(".detail_overview_match_detail_move"), sum ? "合計ダメージ" : first.atk.move);
    info.hidden = sum;
    if (!sum) {
        const move = calcData.moves[first.atk.move];
        const result = first.result;
        q(".detail_overview_match_detail_info_type").innerHTML = TYPE_BY_JA[result?.info?.moveType ?? move?.type]?.svg ?? "";
        q(".detail_overview_match_detail_info_category").innerHTML = CATEGORY_SVG[move?.category] ?? "";
        setText(q(".detail_overview_match_detail_info_power"), String(result?.info?.displayPower ?? move?.power ?? "-"));
    }

    q(".detail_overview_others").hidden = !visible("");
    const ability = same((e) => e.atk.ability || "なし");
    const item = same((e) => e.atk.item || "なし");
    toggleText(q(".detail_overview_others_attacker .detail_overview_others_ability"), ability);
    toggleText(q(".detail_overview_others_attacker .detail_overview_others_item"), item);
    q(".detail_overview_others_attacker").hidden = !visible(ability) && !visible(item);
    setText(q(".detail_overview_others_defender .detail_overview_others_ability"), def.ability || "なし");
    setText(q(".detail_overview_others_defender .detail_overview_others_item"), def.item || "なし");
    toggleText(q(".detail_overview_environment"), same(envText));

    const firepower = sum ? null : first.result?.info?.firepower;
    const indexBox = q(".detail_index");
    indexBox.hidden = firepower == null;
    if (firepower != null) setText(q(".detail_index_num"), String(firepower));
    renderAdjust(sum ? null : first);
    const summary = summarize(sum ? calcState.entries : list, hp, sum);
    fillResult(q(".detail_overview_log"), "detail_overview_log", hp, summary.min, summary.max, summary.text, summary.rate);
    renderHppm(list);
    renderCounter(sum ? null : first);
    syncDividers(detail);
}

function renderDetail() {
    const { entries, def, multi } = calcState;
    if (!def) return;
    detailView();
    const flow = detailQuery(".detail_overview_flow");
    flow.innerHTML = entries.map(flowItemHtml).join("") + (multi ? sumItemHtml() : "");
    flow.querySelectorAll(".detail_overview_flow_item.selected").forEach((item) => fitFlowItem(item, false));
    renderView();
}

$(".detail_overview_flow")?.addEventListener("click", (e) => {
    const item = e.target.closest(".detail_overview_flow_item");
    if (!item) return;
    const id = item.dataset.id === "sum" ? "sum" : Number(item.dataset.id);
    const next = id !== "sum" && id === detailSelected && calcState.multi ? "sum" : id;
    if (next === detailSelected) return;
    detailSelected = next;
    haptic(next === "sum" ? "soft" : "light");
    item.parentElement.querySelectorAll(".detail_overview_flow_item").forEach((other) => {
        const selected = other.dataset.id === String(next);
        if (other.classList.contains("selected") === selected) return;
        other.classList.toggle("selected", selected);
        fitFlowItem(other);
    });
    renderView();
});

function openDetail() {
    detailSelected = null;
    renderDetail();
}

let calcScheduled = false;
const scheduleCalc = () => {
    if (calcScheduled) return;
    calcScheduled = true;
    requestAnimationFrame(() => {
        calcScheduled = false;
        runCalc();
    });
};

calcReady.then(() => {
    runCalc();
    const observer = new MutationObserver(scheduleCalc);
    $$("main").forEach((side) => {
        observer.observe(side, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["class"] });
    });
    $$(".modal_environment_weather_select, .modal_environment_field_select").forEach((select) => {
        observer.observe(select, { subtree: true, attributes: true, attributeFilter: ["class"] });
    });
    document.addEventListener("change", scheduleCalc);
});

const renderCounter = (entry) => {
    const box = detailQuery(".detail_counter");
    const result = entry?.result;
    const category = result?.info?.category;
    box.hidden = !(result?.status === "ok" && ["物理", "特殊"].includes(category));
    if (box.hidden) return;
    const { atk } = entry;
    const def = entry.def ?? calcState.def;
    const hit = result;
    const defMax = hpOf(def).max;
    const atkMax = hpOf(atk).max;
    const rolls = Array.from({ length: 16 }, (_, i) => ({
        total: hit.hits.reduce((sum, damages) => sum + damages[i], 0),
        last: hit.hits[hit.hits.length - 1][i],
    }));
    const alive = rolls.filter((roll) => roll.total < defMax);
    const physical = category === "物理";
    const rows = [
        { name: physical ? "カウンター" : "ミラーコート", mult: 2, immune: atk.types.includes(physical ? "ゴースト" : "あく") },
        { name: "メタルバースト・ほうふく", mult: 1.5, immune: false },
    ];
    const list = $(".detail_counter_list", box);
    if (list.children.length !== rows.length) {
        list.innerHTML = rows.map(() => `<div class="detail_counter_row">
            <div class="detail_hppm_item">
                <p class="detail_hppm_item_name"></p>
                <div class="detail_hppm_item_damage">
                    <p class="detail_hppm_item_num minus"></p>
                    <p class="detail_hppm_item_percent minus"></p>
                </div>
            </div>
            <div class="detail_hppm_hpbar">
                <div class="detail_hppm_hpbar_kaku" style="width: 100%"></div>
                <div class="detail_hppm_hpbar_ran" style="width: 100%"></div>
            </div>
        </div>`).join("");
    }
    rows.forEach((row, i) => {
        const el = list.children[i];
        let num;
        let percent = "";
        let ratios = [1, 1];
        if (!alive.length) {
            num = "ひんしのため反射不可";
        } else if (row.immune) {
            num = "効果なし";
        } else {
            const amounts = alive.map((roll) => Math.min(atkMax, Math.max(1, Math.floor(roll.last * row.mult))));
            const lo = Math.min(...amounts);
            const hi = Math.max(...amounts);
            num = pairText(lo, hi) + (alive.length < rolls.length ? "（一部ひんし）" : "");
            percent = percentPair(lo, hi, atkMax);
            ratios = [(atkMax - hi) / atkMax, (atkMax - lo) / atkMax];
        }
        const name = $(".detail_hppm_item_name", el);
        const nameHtml = `${row.name}<span>×${row.mult}</span>`;
        if (name.innerHTML !== nameHtml) name.innerHTML = nameHtml;
        setText($(".detail_hppm_item_num", el), num);
        const percentEl = $(".detail_hppm_item_percent", el);
        setText(percentEl, percent);
        percentEl.hidden = !percent;
        const color = hpColor(ratios[0]);
        [$(".detail_hppm_hpbar_kaku", el), $(".detail_hppm_hpbar_ran", el)].forEach((bar, j) => {
            bar.style.width = `${ratios[j] * 100}%`;
            bar.style.backgroundColor = color;
        });
    });
};

window.calcLoaded = true;

const withStat = (p, key, points, nature = p.evs[key]?.nature ?? 10) => {
    const real = key === "h" ? p.base.h + 75 + points : realStat(p.base[key], points, nature);
    return { ...p, evs: { ...p.evs, [key]: { ...p.evs[key], points, nature, real } } };
};

const damageSpan = (result) => (result?.status === "ok"
    ? result.hits.reduce(([lo, hi], damages) => [lo + Math.min(...damages), hi + Math.max(...damages)], [0, 0])
    : null);

const minPoints = (test) => {
    if (!test(32)) return null;
    let lo = 0;
    let hi = 32;
    while (lo < hi) {
        const mid = (lo + hi) >> 1;
        if (test(mid)) hi = mid;
        else lo = mid + 1;
    }
    return lo;
};

const adjustCell = (label, points, real) => `<td>${label ? `<span class="detail_adjust_nature">${label}:</span>` : ""}${points === null ? '<span class="detail_adjust_none">不可</span>' : `+${points}<small>（${real}）</small>`}</td>`;

let adjustKey = "";
const renderAdjust = (entry) => {
    const box = detailQuery(".detail_adjust");
    const result = entry?.result;
    const offenseKey = result?.info?.offenseKey;
    const defenseKey = result?.info?.defenseKey;
    box.hidden = !(result?.status === "ok" && ["物理", "特殊"].includes(result.info.category) && entry.atk.evs[offenseKey] && entry.def.evs[defenseKey]);
    if (box.hidden) return;
    const { atk, def, field } = entry;
    const key = JSON.stringify([atk.name, atk.move, atk.ability, atk.item, atk.evs, atk.hits, atk.crits, atk.crit, atk.axel, atk.metronome, atk.powerUp, atk.conditions, atk.types, def.name, def.ability, def.abilityOn, def.item, def.evs, def.hpNow, def.conditions, def.types, field]);
    if (key === adjustKey) return;
    adjustKey = key;
    const hp = hpOf(def);
    const ratio = hp.now / hp.max;
    const survives = (target) => {
        const span = damageSpan(calcDamage(atk, target, field, calcData));
        const max = hpOf({ ...target, hpNow: 0 }).max;
        const now = ratio >= 1 ? max : Math.max(1, Math.round(max * ratio));
        return !!span && span[1] < now;
    };
    const natures = [10, 11];
    const h = minPoints((points) => survives({ ...withStat(def, "h", points), hpNow: 0 }));
    const rows = natures.map((nature) => {
        const ko = offenseKey === "vsa" ? null : minPoints((points) => {
            const span = damageSpan(calcDamage(withStat(atk, offenseKey, points, nature), def, field, calcData));
            return !!span && span[0] >= hp.now;
        });
        const wall = minPoints((points) => survives(withStat(def, defenseKey, points, nature)));
        const label = nature === 11 ? "×1.1" : "×1.0";
        return `<tr>
            ${offenseKey === "vsa" ? "<td>-</td>" : adjustCell(label, ko, ko === null ? 0 : withStat(atk, offenseKey, ko, nature).evs[offenseKey].real)}
            ${nature === 10 ? adjustCell("", h, h === null ? 0 : def.base.h + 75 + h) : "<td></td>"}
            ${adjustCell(label, wall, wall === null ? 0 : withStat(def, defenseKey, wall, nature).evs[defenseKey].real)}
        </tr>`;
    });
    $(".detail_adjust_table", box).innerHTML = `<tr><th>${STAT_LETTERS[offenseKey]} 確定1発</th><th>H 確定耐え</th><th>${STAT_LETTERS[defenseKey]} 確定耐え</th></tr>${rows.join("")}`;
};

const syncDividers = (root) => {
    let seen = false;
    let pending = null;
    [...root.children].forEach((el) => {
        if (el.matches("header, .detail_credit")) return;
        if (el.classList.contains("hr")) {
            el.hidden = true;
            if (seen && !pending) pending = el;
            return;
        }
        if (el.hidden) return;
        if (pending) {
            pending.hidden = false;
            pending = null;
        }
        seen = true;
    });
};

const renderConstantView = (entry, defItem) => {
    const q = detailQuery;
    const { def, hp } = calcState;
    defItem.querySelector(".detail_overview_match_sprite img").src = spriteOf(calcData.pokemons[def.name]);
    defItem.querySelector(".detail_overview_match_sprite_types").innerHTML = typesHtml(def.types);
    setText(defItem.querySelector(".detail_overview_match_name"), def.name);
    setText(defItem.querySelector(".detail_overview_match_stat"), statText(def, ["h"]));
    const kind = entry?.kind ?? "damage";
    const { parts, total } = entry?.constant ?? { parts: [], total: 0 };
    setText(q(".detail_overview_match_detail_move"), CONSTANT_KINDS[kind].title);
    q(".detail_overview_match_detail_info").hidden = true;
    q(".detail_overview_others").hidden = true;
    q(".detail_overview_environment").hidden = true;
    const heal = kind === "heel";
    const amount = heal ? -total : total;
    const log = q(".detail_overview_log");
    fillResult(log, "detail_overview_log", hp, amount, amount, parts.map((p) => p.label).join("・") || "なし", null);
    if (heal) {
        setText(q(".detail_overview_log_damage_percent"), `+${fixed1((total / Math.max(1, hp.max)) * 100)}%`);
        setText(q(".detail_overview_log_damage_num_take"), `+${total}`);
    }
    log.classList.toggle("is-heal", heal);
    ["detail_index", "detail_adjust", "detail_hppm", "detail_counter"].forEach((name) => { q(`.${name}`).hidden = true; });
};
