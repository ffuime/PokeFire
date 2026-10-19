const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const nativeBridge = window.webkit?.messageHandlers?.pokefire;
const isNative = !!nativeBridge;
const postNative = (message) => nativeBridge?.postMessage(message);
let lastSelectionHaptic = 0;
const haptic = (style = "light") => {
    if (!nativeBridge) return;
    if (style === "selection") {
        const now = performance.now();
        if (now - lastSelectionHaptic < 35) return;
        lastSelectionHaptic = now;
    }
    postNative({ type: "haptic", style });
};
if (isNative) document.documentElement.classList.add("is-native");

const jsonCache = {};
const loadJson = (file) => (jsonCache[file] ??= fetch(file).then((res) => (res.ok ? res.json() : Promise.reject(new Error(file)))));
const spriteOf = (pokemon) => (pokemon ? `https://pokesol.app/api/images/assets/pokemons/${pokemon.num}${pokemon.form ? `_0${pokemon.form}` : ""}.png` : "");

const RANK_OPTIONS = [["*4", "+6"], ["*7/2", "+5"], ["*3", "+4"], ["*5/2", "+3"], ["*2", "+2"], ["*3/2", "+1"], ["*1", "±0"], ["*2/3", "-1"], ["*1/2", "-2"], ["*2/5", "-3"], ["*1/3", "-4"], ["*2/7", "-5"], ["*1/4", "-6"]];
const iconHtml = (id) => `<svg viewBox="0 0 24 24"><use href="#${id}"/></svg>`;
const evsHtml = (ttl, value, points, others) => `
            <div class="main_evs_header">
                <p class="ttl">${ttl}</p>
                <p class="main_evs_header_value">${value}</p>
            </div>
            <div class="main_evs_range_container">
                <div class="main_evs_range">
                    ${"<span></span>".repeat(32)}
                </div>
                <div class="main_evs_range_num">${points}</div>
            </div>${others ? `
            <div class="main_evs_others">
                <div class="main_evs_nature">
                    <div class="main_evs_nature_09" ontouchstart="">×0.9</div>
                    <div class="main_evs_nature_10 selected" ontouchstart="">×1.0</div>
                    <div class="main_evs_nature_11" ontouchstart="">×1.1</div>
                </div>
                <div class="main_evs_ranks">
                    <select class="main_evs_ranks_select">
                        ${RANK_OPTIONS.map(([value, label]) => `<option value="${value}"${value === "*1" ? " selected" : ""}>${label}</option>`).join("")}
                    </select>
                    <div class="main_evs_ranks_btns">
                        <button class="main_evs_ranks_btn up">${iconHtml("i-up")}</button>
                        <button class="main_evs_ranks_btn down">${iconHtml("i-down")}</button>
                    </div>
                </div>
            </div>` : ""}
`;
$$("[data-evs]").forEach((el) => {
    const [ttl, value, points, others] = el.dataset.evs.split("|");
    el.insertAdjacentHTML("afterbegin", evsHtml(ttl, value, points, others));
    el.removeAttribute("data-evs");
});

document.addEventListener("gesturestart", (e) => e.preventDefault());
document.addEventListener("touchmove", (e) => {
    if (e.touches.length > 1) e.preventDefault();
}, { passive: false });

$$("button.main_move_weak, button.main_move_powerup, button.main_ability_on, button.main_condition_item").forEach((button) => {
    button.addEventListener("click", () => {
        if (button.dataset.action) return;
        button.classList.toggle("active");
        haptic("light");
    });
});

const ABILITY_ACTIVATION = {
    attacker: {
        always: new Set([
            "ちからもち", "ヨガパワー", "はりきり", "テクニシャン", "てつのこぶし", "すてみ", "かたいツメ", "がんじょうあご", "メガランチャー", "きれあじ",
            "パンクロック", "スカイスキン", "フェアリースキン", "フリーズスキン", "ドラゴンスキン", "うるおいボイス", "てきおうりょく", "スナイパー", "ちからずく",
            "はがねのせいしん", "フェアリーオーラ", "ほのおのたてがみ", "すいほう", "かたやぶり", "てんねん", "ノーてんき", "すりぬけ", "スキルリンク", "おやこあい",
            "ヘヴィメタル", "ライトメタル", "メガソーラー", "すなのちから", "サンパワー", "ぶきよう", "すいすい", "ようりょくそ", "すなかき", "ゆきかき", "サーフテール",
            "ふゆう", "うなぎのぼり",
        ]),
        toggle: new Set([
            "もうか", "しんりょく", "げきりゅう", "むしのしらせ", "こんじょう", "アナライズ", "とうそうしん", "プラス", "マイナス", "もらいび", "はりこみ",
            "かるわざ", "はやあし", "でんきにかえる",
        ]),
        defaultOn: new Set(),
        changeType: new Set(["へんげんじざい", "リベロ"]),
    },
    defender: {
        always: new Set([
            "あついしぼう", "たいねつ", "かんそうはだ", "きよめのしお", "すいほう", "ファーコート", "もふもふ", "はどうのぼうご", "ハードロック", "フィルター",
            "ふゆう", "うなぎのぼり", "ちくでん", "でんきエンジン", "ひらいしん", "ちょすい", "そうしょく", "どしょく", "もらいび", "ぼうおん", "ぼうだん",
            "てんねん", "ノーてんき", "パンクロック", "くさのけがわ", "フェアリーオーラ", "ヘヴィメタル", "ライトメタル", "ぶきよう", "じゅくせい",
            "すいすい", "ようりょくそ", "すなかき", "ゆきかき", "サーフテール",
        ]),
        toggle: new Set(["ふしぎなうろこ", "かるわざ", "はやあし", "マルチスケイル"]),
        defaultOn: new Set(["マルチスケイル"]),
        changeType: new Set(),
    },
};

const RANK_ABILITIES = {
    "まけんき": [["self", "a", 2]],
    "かちき": [["self", "c", 2]],
    "じしんかじょう": [["self", "a", 1]],
    "せいぎのこころ": [["self", "a", 1]],
    "ねつこうかん": [["self", "a", 1]],
    "そうしょく": [["self", "a", 1]],
    "いかりのつぼ": [["self", "a", 12]],
    "ぎゃくじょう": [["self", "c", 1]],
    "ひらいしん": [["self", "c", 1]],
    "かそく": [["self", "s", 1]],
    "ふくつのこころ": [["self", "s", 1]],
    "びびり": [["self", "s", 1]],
    "でんきエンジン": [["self", "s", 1]],
    "じきゅうりょく": [["self", "b", 1]],
    "くだけるよろい": [["self", "b", -1], ["self", "s", 2]],
    "いかく": [["opp", "a", -1]],
};
const INTIMIDATE_REACTIONS = {
    "きもったま": [],
    "マイペース": [],
    "どんかん": [],
    "せいしんりょく": [],
    "クリアボディ": [],
    "しろいけむり": [],
    "ミラーアーマー": [],
    "あまのじゃく": [["a", 1]],
    "まけんき": [["a", -1], ["a", 2]],
    "かちき": [["a", -1], ["c", 2]],
    "びびり": [["a", -1], ["s", 1]],
};
const RANK_STAT_NAMES = { a: "こうげき", b: "ぼうぎょ", c: "とくこう", d: "とくぼう", s: "すばやさ" };

const abilityOf = (side) => side?.querySelector("button.main_ability_choose p")?.textContent.trim() ?? "";
const otherSide = (side) => $(side.classList.contains("attacker") ? "main.defender" : "main.attacker");
const rankSelectOf = (side, key) => side?.querySelector(`.main_evs_${key} .main_evs_ranks select`);

const rankChangesOf = (side, ability) => (RANK_ABILITIES[ability] ?? []).flatMap(([who, key, delta]) => {
    const target = who === "self" ? side : otherSide(side);
    const reaction = who === "opp" && ability === "いかく" ? INTIMIDATE_REACTIONS[abilityOf(target)] : null;
    return (reaction ?? [[key, delta]]).map(([k, d]) => [target, k, d]);
}).filter(([target, key]) => rankSelectOf(target, key));

const hasRankAbility = (side, ability) => (RANK_ABILITIES[ability] ?? []).some(([who, key]) => rankSelectOf(who === "self" ? side : otherSide(side), key));

const applyRankAbility = (side) => {
    const ability = abilityOf(side);
    const changes = rankChangesOf(side, ability);
    const totals = new Map();
    changes.forEach(([target, key, delta]) => {
        const select = rankSelectOf(target, key);
        const index = Math.max(0, Math.min(select.options.length - 1, select.selectedIndex - delta));
        const moved = select.selectedIndex - index;
        const id = `${target === side ? "自分" : "相手"}の${RANK_STAT_NAMES[key]}`;
        totals.set(id, (totals.get(id) ?? 0) + moved);
        if (index === select.selectedIndex) return;
        select.selectedIndex = index;
        select.dispatchEvent(new Event("change", { bubbles: true }));
    });
    const text = [...totals].filter(([, v]) => v).map(([id, v]) => `${id}${v > 0 ? "+" : ""}${v}`).join("・");
    haptic(text ? "medium" : "warning");
    showToast(`${ability}：${text || "変化なし"}`);
};

function syncAbilityButton(side, { reset = false } = {}) {
    const button = side?.querySelector("button.main_ability_on");
    if (!button) return;
    if (button.dataset.wasOn !== undefined) {
        button.classList.toggle("active", button.dataset.wasOn === "1");
        delete button.dataset.wasOn;
    }
    const rules = ABILITY_ACTIVATION[side.classList.contains("defender") ? "defender" : "attacker"];
    const ability = side.querySelector("button.main_ability_choose p")?.textContent.trim() ?? "";
    const changeType = rules.changeType.has(ability);
    const rankAction = !changeType && !rules.always.has(ability) && !rules.toggle.has(ability) && hasRankAbility(side, ability);
    let locked = false;
    if (changeType || rankAction) {
        button.hidden = false;
        button.disabled = false;
        button.classList.remove("active");
    } else if (rules.always.has(ability)) {
        button.hidden = false;
        button.disabled = true;
        button.classList.add("active");
        locked = true;
    } else if (rules.toggle.has(ability)) {
        button.hidden = false;
        button.disabled = false;
        if (reset) button.classList.toggle("active", rules.defaultOn.has(ability));
    } else {
        button.hidden = true;
        button.disabled = true;
        button.classList.remove("active");
    }
    if (changeType) button.dataset.action = "changeType";
    else if (rankAction) button.dataset.action = "rank";
    else delete button.dataset.action;
    setButtonLabel(button, changeType ? "タイプ変更" : "発動", locked);
    syncBurnLock(side);
    if (side.classList.contains("attacker")) syncMultiHit(false);
}

function setButtonLabel(button, label, locked) {
    const html = (locked ? LOCK_ICON : "") + label;
    if (button.innerHTML !== html) button.innerHTML = html;
    button.classList.toggle("is-locked", locked);
}

const LOCK_ICON = '<svg class="lock_icon" viewBox="0 0 24 24"><circle cx="12" cy="16" r="1"/><rect x="3" y="10" width="18" height="12" rx="2"/><path d="M7 10V7a5 5 0 0 1 10 0v3"/></svg>';
function syncBurnLock(side) {
    if (!side?.classList.contains("attacker")) return;
    const burn = [...side.querySelectorAll("button.main_condition_item")].find((b) => b.textContent.trim() === "やけど");
    if (!burn) return;
    const move = side.querySelector("button.main_move_choose p")?.textContent.trim();
    const ability = side.querySelector("button.main_ability_choose p")?.textContent.trim();
    const locked = move === "からげんき" || ability === "こんじょう";
    burn.disabled = locked;
    setButtonLabel(burn, "やけど", locked);
    const weak = $("button.main_move_weak", side);
    if (!weak) return;
    const critLocked = window.calcLoaded && CALC_ALWAYS_CRIT_MOVES.has(move);
    if (weak.disabled && !critLocked) weak.classList.remove("active");
    if (critLocked) weak.classList.add("active");
    weak.disabled = critLocked;
    setButtonLabel(weak, "急所", critLocked);
}

$$("button.main_ability_on").forEach((button) => {
    button.addEventListener("click", () => {
        const side = button.closest("main");
        if (button.dataset.action === "rank") {
            applyRankAbility(side);
            return;
        }
        if (button.dataset.action !== "changeType") return;
        const moveName = side?.querySelector("button.main_move_choose p")?.textContent.trim();
        const moveType = movesData[moveName]?.type;
        if (!moveType) return;
        searchOf(side)?.setTypes([moveType]);
    });
});

const ADJUSTMENTS_KEY = "pokefire-adjustments";
const loadAdjustments = () => {
    try {
        return JSON.parse(localStorage.getItem(ADJUSTMENTS_KEY)) ?? {};
    } catch {
        return {};
    }
};
const evsKeyOf = (section) => [...section.classList].find((c) => c.startsWith("main_evs_"))?.replace("main_evs_", "");
const pointsOf = (section) => parseInt(section.querySelector(".main_evs_range_num")?.textContent, 10) || 0;
const natureOf = (section) => {
    const selected = section.querySelector(".main_evs_nature > .selected");
    return selected?.classList.contains("main_evs_nature_09") ? "09" : selected?.classList.contains("main_evs_nature_11") ? "11" : "10";
};
const zeroRankIndex = (select) => [...select.options].findIndex((option) => option.value === "*1");
const defaultPoints = (_role, key) => ({ h: 2, a: 32, c: 32 })[key] ?? 0;

function setNature(section, nature) {
    section.querySelectorAll(".main_evs_nature > div").forEach((div) => {
        div.classList.toggle("selected", div.classList.contains(`main_evs_nature_${nature}`));
    });
}

function applyAdjustments(side, name) {
    const stored = loadAdjustments()[name] ?? {};
    const role = side.classList.contains("defender") ? "defender" : "attacker";
    if (role === "defender") document.dispatchEvent(new Event("defender-reset"));
    side.querySelectorAll(".main_evs").forEach((section) => {
        const key = evsKeyOf(section);
        if (!key || key === "vsa") return;
        const value = stored[key] ?? { points: defaultPoints(role, key), nature: "10" };
        section.querySelector(".main_evs_range")?.setEvsValue?.(value.points);
        setNature(section, value.nature);
    });
    side.querySelectorAll(".main_evs_ranks select").forEach((select) => {
        const zero = zeroRankIndex(select);
        if (zero < 0 || select.selectedIndex === zero) return;
        select.selectedIndex = zero;
        select.dispatchEvent(new Event("change", { bubbles: true }));
    });
    updateRealStatsIn(side);
}

function saveAdjustments(side) {
    const name = searchOf(side)?.getPokemon().name;
    if (!name || !pokemons[name]) return;
    const all = loadAdjustments();
    const entry = all[name] ?? {};
    side.querySelectorAll(".main_evs").forEach((section) => {
        const key = evsKeyOf(section);
        if (!key || key === "vsa") return;
        entry[key] = { points: pointsOf(section), nature: natureOf(section) };
    });
    all[name] = entry;
    try {
        localStorage.setItem(ADJUSTMENTS_KEY, JSON.stringify(all));
    } catch {}
}

$$("main.attacker, main.defender").forEach((side) => syncAbilityButton(side, { reset: true }));

let modalOpenerSide = document;
function updateRealStats() {
    $$("main").forEach((side) => updateRealStatsIn(side));
}
function updateRealStatsIn(side) {
    ["h", "a", "b", "c", "d", "s"].forEach((key) => {
        const base = parseInt(side.querySelector(`.main_basestats_item.${key} p`)?.textContent, 10);
        const section = side.querySelector(`.main_evs.main_evs_${key}`);
        const header = section?.querySelector(".main_evs_header_value");
        if (!header || Number.isNaN(base)) return;

        const points = pointsOf(section);
        header.textContent = key === "h" ? base + 75 + points : Math.floor(((base + 20 + points) * Number(natureOf(section))) / 10);
    });
    syncHpLeft(side);
}

function syncHpLeft(side, now) {
    const box = side?.querySelector(".main_hpleft");
    const max = parseInt(side?.querySelector(".main_evs_h .main_evs_header_value")?.textContent, 10);
    if (!box || !(max > 0)) return;
    const oldMax = Number(box.dataset.max) || max;
    const oldNow = Number(box.dataset.now) || oldMax;
    if (now === undefined) now = oldNow >= oldMax ? max : Math.round((oldNow / oldMax) * max);
    now = Math.max(1, Math.min(max, Math.round(now)));
    box.dataset.max = max;
    box.dataset.now = now;
    const ratio = now / max;
    const set = (selector, text) => {
        const el = box.querySelector(selector);
        if (el && el.textContent !== text) el.textContent = text;
    };
    set(".percent", `${Math.max(1, Math.floor(ratio * 100))}%`);
    set(".now", String(now));
    set(".max", `/${max}`);
    const bar = box.querySelector(".main_hpleft_range span.active");
    if (bar) bar.style.width = `${ratio * 100}%`;
}

const bindDrag = (range, onRatio) => {
    let dragging = false;
    const update = (e) => {
        const rect = range.getBoundingClientRect();
        onRatio(Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width)));
    };
    range.addEventListener("pointerdown", (e) => {
        dragging = true;
        try {
            range.setPointerCapture(e.pointerId);
        } catch {}
        update(e);
    });
    range.addEventListener("pointermove", (e) => {
        if (dragging) update(e);
    });
    ["pointerup", "pointercancel"].forEach((type) => range.addEventListener(type, () => { dragging = false; }));
};

$$(".main_hpleft_range").forEach((range) => {
    const side = range.closest("main");
    bindDrag(range, (ratio) => {
        const max = parseInt(side.querySelector(".main_evs_h .main_evs_header_value")?.textContent, 10) || 1;
        const box = side.querySelector(".main_hpleft");
        const before = box?.dataset.now;
        syncHpLeft(side, Math.ceil(ratio * max));
        if (box?.dataset.now !== before) haptic("selection");
    });
});

$$(".main_evs_nature").forEach((nature) => {
    const items = nature.querySelectorAll(":scope > div");
    items.forEach((item) => {
        item.addEventListener("click", () => {
            if (!item.classList.contains("selected")) haptic("light");
            items.forEach((other) => other.classList.remove("selected"));
            item.classList.add("selected");
            updateRealStats();
            saveAdjustments(nature.closest("main"));
        });
    });
});

const EVS_MAX = 32;

$$(".main_evs_range").forEach((range) => {
    const spans = range.querySelectorAll("span");
    const num = range.closest(".main_evs_range_container")?.querySelector(".main_evs_range_num");
    const setValue = (value) => {
        value = Math.max(0, Math.min(EVS_MAX, value));
        spans.forEach((span, i) => span.classList.toggle("active", i < value));
        if (num) num.textContent = value;
        updateRealStats();
    };
    range.setEvsValue = setValue;
    bindDrag(range, (ratio) => {
        const next = Math.max(0, Math.min(EVS_MAX, Math.round(ratio * EVS_MAX)));
        if (String(next) !== num?.textContent) haptic("selection");
        setValue(next);
        saveAdjustments(range.closest("main"));
    });
    setValue(parseInt(num?.textContent, 10) || 0);
});

$$(".main_evs_ranks_select").forEach((select) => {
    const ranks = select.closest(".main_evs_ranks");
    if (!ranks) return;
    const syncRank = () => {
        const zero = zeroRankIndex(select);
        const rank = select.selectedIndex < zero ? "up" : select.selectedIndex > zero ? "down" : "";
        if (rank) ranks.dataset.rank = rank;
        else delete ranks.dataset.rank;
    };
    select.addEventListener("change", syncRank);
    syncRank();
});

$$(".main_evs_ranks_btn").forEach((button) => {
    button.addEventListener("click", () => {
        const select = button.closest(".main_evs_ranks")?.querySelector("select");
        if (!select) return;

        const step = button.classList.contains("up") ? -1 : 1;
        const index = Math.max(0, Math.min(select.options.length - 1, select.selectedIndex + step));
        if (index === select.selectedIndex) return;
        haptic("light");

        select.selectedIndex = index;
        select.dispatchEvent(new Event("change", { bubbles: true }));
    });
});

$$(".main_ability_header_ex").forEach((ex) => {
    const label = ex.closest(".main_ability")?.querySelector("button.main_ability_choose p");

    ex.addEventListener("click", (e) => {
        const item = e.target.closest("span");
        if (!item || !ex.contains(item)) return;

        const willSelect = !item.classList.contains("selected");
        ex.querySelectorAll("span").forEach((other) => other.classList.remove("selected"));
        if (willSelect) item.classList.add("selected");
        if (label) label.textContent = willSelect ? item.textContent.trim() : "なし";
        syncAbilityButton(ex.closest("main"), { reset: true });
    });
});

const TYPES_INFO = [
    ["normal", "ノーマル", "#949495", '<path d="M63.81 26.43c3.12-4.29 2.43-10.33-1.69-13.79-4-3.36-9.82-3.11-13.54.39-3.18-1.21-6.63-1.88-10.23-1.88s-7.05.67-10.23 1.88c-3.71-3.5-9.53-3.74-13.54-.39-4.13 3.46-4.81 9.49-1.69 13.79-2.17 4.05-3.4 8.67-3.4 13.58 0 15.91 12.95 28.86 28.86 28.86s28.86-12.95 28.86-28.86c0-4.91-1.23-9.53-3.4-13.58zM38.35 60.87c-11.5 0-20.86-9.36-20.86-20.86s9.36-20.86 20.86-20.86 20.86 9.36 20.86 20.86-9.36 20.86-20.86 20.86z"/>'],
    ["fire", "ほのお", "#e56c3e", '<path d="M55.78 38.1c-5.32-5.15-3.66-9.14-1.21-11.26 0 0-6.53-.79-8.85 4.53-2.33 5.32 2.16 8.06 2.16 8.06s-6.48-2.58-4.66-8.9c1.61-5.56 4.57-8.48 3.24-14.38-1.5-6.67-10.97-9.49-15.55-7.74 3.2 1.08 5.51 4.09 5.51 7.66 0 4.16-3.29 6.92-7.71 11.39-5.11 5.15-10.32 10.97-10.32 20.31 0 10.78 6.65 17.45 14.62 19.87-4.04-1.93-12.45-7.99-11.4-19.65 1.1-12.3 12.89-20.7 12.89-20.7s-2.54 4.26-1.43 11.16c.62 3.88 3.4 8.65 6.05 10.72 3.72 2.91 8.64 5.93 7.93 11.45-.67 5.18-7.55 7.5-11.02 7.71 1.58.26 3.19.37 4.78.32 11.81 0 20.58-8.78 20.58-18.12 0-7.39-3.54-10.43-5.62-12.43z"/>'],
    ["water", "みず", "#5185c5", '<path d="M54 41.57s-3.96-6.86-5.85-9.78c-1.97-3.07-3.82-6.73-5.26-12.61-1.44-5.87-2.22-11.53-4.54-11.53s-3.1 5.65-4.54 11.53c-1.44 5.87-3.29 9.53-5.26 12.61-1.88 2.93-5.85 9.78-5.85 9.78a18.018 18.018 0 00-2.58 9.32c0 10.03 8.2 18.17 18.23 18.17s18.23-8.13 18.23-18.17c0-3.41-.95-6.59-2.58-9.32zM38.35 64.96c-8.18 0-14.61-6.1-14.61-10.5 0-2.91 6.43 2.52 14.61 2.52s14.61-5.43 14.61-2.52c0 4.41-6.43 10.5-14.61 10.5z"/>'],
    ["grass", "くさ", "#66a945", '<path d="M11.47 66.62H29.1s4.82-44.39 2.33-44.39-19.96 44.39-19.96 44.39zm29.6 0h17.62S67 22.23 64.51 22.23 41.07 66.62 41.07 66.62zm-5.99 0l12.8-25.44s4.66-30.26 2.49-30.26-13.14 26.94-13.14 26.94l-2.16 28.76z"/>'],
    ["electric", "でんき", "#f6d851", '<path d="M37.97 6.94c2.5 1.14 12.84 6.04 19.84 12.22.31.27.34.75.07 1.06-1.55 1.8-6.66 7.75-12.82 14.99-.27.32-.24.8.07 1.08 1.8 1.59 7.48 6.69 10.91 10.43.28.3.26.77-.04 1.06-2.98 2.87-17.73 17.06-23.45 21.97-.3.26-.76-.02-.67-.41.74-3.02 2.8-11.05 4.99-16.89.12-.31.02-.66-.25-.86-2.15-1.64-11.56-8.86-17.74-14.4a.746.746 0 01-.16-.91c1.36-2.62 7.8-14.72 18.32-29.07.21-.29.6-.4.92-.25z"/>'],
    ["ice", "こおり", "#6dc8eb", '<path transform="rotate(-45 38.354 11.743)" d="M33.44 6.82h9.83v9.83h-9.83z"/><path d="M11.49 48.24h9.83v9.83h-9.83z"/><path transform="rotate(-45 38.353 64.974)" d="M33.44 60.05h9.83v9.83h-9.83z"/><path d="M55.38 18.75v9.77l-17.03-9.83-17.03 9.83v-9.77h-9.83v9.83h9.83v19.6l17.03 9.83 17.03-9.83v-19.6h9.83v-9.83h-9.83zM31.14 34.32v9.62h-5.11v-12.6h.05l10.86-6.27 2.55 4.42-8.36 4.83zm24.24 13.92h9.83v9.83h-9.83z"/>'],
    ["fighting", "かくとう", "#e09c40", '<path d="M40.72 34.03h21.8v9.88h-21.8v-9.88zm13.33-22v17.66h8.47V12.03h-8.47zm-4.86 0h-8.47v17.66h8.47V12.03zm-13.2 0h-8.47v23.22h8.47V12.03zm-13.33 0h-8.47v23.22h8.47V12.03zm14.03 31.43h-22.5v12.97l14.41 9.42 33.92-10.46v-7.38H36.69v-4.54z"/>'],
    ["poison", "どく", "#735198", '<path d="M47.7 56.75c-.55-4.68-4.52-8.31-9.35-8.31s-8.8 3.63-9.35 8.31c-11.51.84-19.8 3.18-19.8 5.93 0 3.46 13.05 6.26 29.15 6.26s29.15-2.8 29.15-6.26c0-2.76-8.29-5.09-19.8-5.93z"/><circle cx="28.31" cy="23.22" r="11.2"/><circle cx="51.28" cy="37.57" r="6.64"/>'],
    ["ground", "じめん", "#9c7743", '<path d="M52.29 16.07h8.31v8.31h-8.31zm-24.44 6.49h6.48v6.48h-6.48zM13.55 8.92h10.81v10.81H13.55zm53.89 39.29V46.1L38.35 34.49 9.26 46.1v2.11l29.09 11.6 29.09-11.6z"/><path d="M67.52 53.52L38.35 65.3 9.19 53.52l-1.47 3.64 30.63 12.38 30.64-12.38-1.47-3.64z"/>'],
    ["flying", "ひこう", "#81b9ef", '<path d="M23.78 27.7c-1.94 4.43-7.5 23.12-8.81 33.15-.67 5.09-1.31 6.86 0 7.25 1.66.5 8.65-10.31 11.14-14.47 0 0 15.92 2.39 24.09-7.79.19-.24-.02-.59-.32-.53-3.22.55-14.81 2.34-19.94.35 0 0 20.89.81 30.38-14.67.13-.2-.08-.46-.3-.38-3.29 1.19-17.5 5.86-26.01 3.66 0 0 13.83-.81 24.28-10.31S69.6 9.66 68.85 8.91c-1.42-1.42-8.65 2.16-14.47 3.99s-13.14 3.99-17.96 4.99-8.81 1.08-12.64 9.81z"/>'],
    ["psychic", "エスパー", "#dd6b7b", '<path d="M38.35 16.28c.29 0 .59.16.72.48 2.62 6.29 8.79 10.32 15.47 10.32.71 0 1.43-.05 2.15-.14h.11c.63 0 1.01.73.61 1.26-4.58 5.98-4.58 14.34-.02 20.33.4.52.01 1.25-.61 1.25h-.11c-.72-.09-1.43-.14-2.14-.14-6.68 0-12.85 4.02-15.47 10.32-.13.32-.43.48-.72.48s-.59-.16-.72-.48C35 53.67 28.83 49.64 22.15 49.64c-.71 0-1.43.05-2.15.14h-.11c-.63 0-1.01-.73-.61-1.26 4.58-5.98 4.58-14.34.02-20.33-.4-.52-.01-1.25.61-1.25h.11c.72.09 1.43.14 2.14.14 6.68 0 12.85-4.02 15.47-10.32.13-.32.43-.48.72-.48m0-8.7c-3.84 0-7.28 2.29-8.75 5.84-1.23 2.96-4.22 4.96-7.44 4.96-.34 0-.68-.02-1.02-.07-.4-.05-.81-.08-1.22-.08-3.62 0-6.88 2.02-8.49 5.27a9.42 9.42 0 00.95 9.95c2.19 2.88 2.19 6.9 0 9.77a9.417 9.417 0 00-.97 9.96 9.407 9.407 0 008.49 5.28c.41 0 .82-.03 1.23-.08.34-.04.69-.07 1.03-.07 3.22 0 6.21 1.99 7.44 4.96 1.48 3.55 4.91 5.84 8.75 5.84s7.28-2.29 8.75-5.84c1.23-2.96 4.22-4.96 7.44-4.96.34 0 .68.02 1.02.07.4.05.81.08 1.22.08 3.62 0 6.88-2.02 8.49-5.27a9.42 9.42 0 00-.95-9.95c-2.19-2.88-2.19-6.9 0-9.77 2.21-2.89 2.58-6.7.97-9.96a9.407 9.407 0 00-8.49-5.28c-.41 0-.82.03-1.23.08-.34.04-.69.07-1.03.07-3.22 0-6.21-1.99-7.44-4.96a9.443 9.443 0 00-8.75-5.84z"/>'],
    ["bug", "むし", "#9fa244", '<path d="M38.35 28.23c8.1 0 15.19-3.44 19.07-8.57-3.88-6.28-10.97-10.49-19.07-10.49s-15.19 4.21-19.07 10.49c3.88 5.13 10.97 8.57 19.07 8.57zm22.84-4.26c-4.56 5.02-11.7 8.47-19.88 9.14l10.93 34.42c8.67-5.52 14.42-15.13 14.42-26.08 0-6.49-2.02-12.5-5.47-17.48zm-45.67 0c4.56 5.02 11.7 8.47 19.88 9.14L24.47 67.53C15.8 62.01 10.05 52.4 10.05 41.45c0-6.49 2.02-12.5 5.47-17.48zm22.83 30.75c1.66 0 3.31-.37 4.83-1.09l-1.3-4.74a6.554 6.554 0 01-7.07 0l-1.3 4.74c1.53.72 3.18 1.09 4.83 1.09zm0 9.14c2.53 0 4.98-.48 7.27-1.36l-1.33-4.85c-1.85.79-3.86 1.21-5.94 1.21s-4.08-.42-5.94-1.21l-1.33 4.85c2.29.88 4.74 1.36 7.27 1.36z"/>'],
    ["rock", "いわ", "#bfb889", '<path d="M58.71 18l2.67 11.72-14.39-14.39L58.71 18l-8.43-8.43H26.43L9.57 26.43v23.85l8.23 8.23-4.49-19.72L37.52 63 17.8 58.51l8.63 8.63h23.85l8.43-8.43-19.72 4.49L63.2 38.99l-4.49 19.72 8.43-8.43V26.43L58.71 18z"/>'],
    ["ghost", "ゴースト", "#684870", '<path d="M64.73 37.52c-2.45-.58-4.47.48-5.75 1.48.49-2.06.77-4.09.77-6.02 0-11.82-9.58-21.4-21.4-21.4s-21.4 9.58-21.4 21.4c0 1.93.28 3.96.77 6.02-1.28-.99-3.31-2.06-5.75-1.48-3.51.83-6.4 5.88-6.57 10.24-.03.9 1.07 1.36 1.67.69.97-1.09 2.24-2.21 3.12-1.84 2.88 1.22 3.1 6.32 5.87 6.32 2.43 0 4.52-2.43 5.54-3.86 4.66 8.79 11.84 16.06 16.74 16.06s12.07-7.26 16.74-16.06c1.02 1.43 3.11 3.86 5.54 3.86 2.77 0 2.99-5.1 5.87-6.32.88-.37 2.15.74 3.12 1.84.6.67 1.71.21 1.67-.69-.17-4.36-3.06-9.41-6.57-10.24zm-31.59-2.74c-1.78.83-4.48-1.18-6.03-4.5-1.55-3.32-1.35-6.68.43-7.51 1.78-.83 4.48 1.18 6.03 4.5 1.55 3.32 1.36 6.68-.43 7.51zm16.45-4.5c-1.55 3.32-4.25 5.33-6.03 4.5-1.78-.83-1.98-4.2-.43-7.51 1.55-3.32 4.25-5.33 6.03-4.5 1.78.83 1.98 4.2.43 7.51z"/>'],
    ["dragon", "ドラゴン", "#535ca8", '<path d="M12.39 23.98c-8.41 11.05-7.23 26.81 3.02 36.47 1.09-3.6 3.14-6.95 6.1-9.6a20.91 20.91 0 01-4.04-10.48c-5.13-3.92-7-10.56-5.08-16.4zm51.92 0c1.92 5.84.05 12.48-5.08 16.4-.38 3.88-1.82 7.47-4.04 10.48 2.96 2.65 5.01 5.99 6.1 9.6 10.25-9.65 11.43-25.42 3.02-36.47zm-12.95 1.33c-1.12-7.41-3.63-15.73-4.89-19.64-.22-.68-1.26-.66-1.44.03-1.17 4.28-2.6 11.09-3.24 14.2-1.07-.2-2.29-.32-3.42-.32s-2.35.11-3.42.32c-.64-3.11-2.07-9.91-3.24-14.2-.19-.69-1.22-.72-1.44-.03-1.26 3.91-3.78 12.22-4.89 19.64-2.67 2.99-4.3 6.93-4.3 11.33 0 6.35 3.37 13.85 8.39 18.21l1.38 12.27c0 1.8 3.37 4.41 7.53 4.41s7.53-2.62 7.53-4.41l1.38-12.27c5.02-4.36 8.39-11.86 8.39-18.21 0-4.4-1.63-8.34-4.3-11.33zM29.81 48.82c-2.98-.92-5.06-3.61-5.15-6.73-.12-3.67.07-7.59.07-7.59l9.2 15.41c-1.61-.37-2.97-.74-4.12-1.09zm17.1 0c-1.14.35-2.51.73-4.12 1.09l9.2-15.41s.19 3.92.07 7.59a7.285 7.285 0 01-5.15 6.73z"/>'],
    ["dark", "あく", "#4c4948", '<path d="M60.1 20.73s-3.25 4.41-10.78 6.74c.84 2.28 1.32 4.93 1.32 7.9 0 10.15-5.5 18.39-12.28 18.39s-12.28-7.27-12.28-18.39c0-2.95.58-5.58 1.52-7.84-7.67-2.32-10.98-6.8-10.98-6.8s-7.54 8.04-6.83 17.19c.42 5.33 3.3 11.6 10.35 17.38 0 0 7.54 6.66 18.22 6.66s18.22-6.66 18.22-6.66c7.05-5.78 9.93-12.04 10.35-17.38.72-9.15-6.83-17.19-6.83-17.19z"/><path d="M35.54 28.85c-.96 2-1.58 4.89-1.58 7.72 0 5.08 1.97 9.19 4.39 9.19s4.39-4.12 4.39-9.19c0-2.84-.61-5.73-1.58-7.72-.9.04-1.84.05-2.81.02-.97.03-1.91.02-2.81-.02z"/>'],
    ["steel", "はがね", "#69a9c7", '<path d="M41 27.35l9.18 32.02 17.37-12.62-8.03-24.71L41 27.35zM52.3 37.6c-2.52 0-4.56-2.04-4.56-4.56s2.04-4.56 4.56-4.56 4.56 2.04 4.56 4.56-2.04 4.56-4.56 4.56z"/><path d="M37.9 38.21l-4.29-14.95 24.07-6.9-1.28-3.93H20.3L9.15 46.75l28.75-8.54zM26.03 15.23c1.87 0 3.38 1.51 3.38 3.38s-1.51 3.38-3.38 3.38-3.38-1.51-3.38-3.38 1.51-3.38 3.38-3.38zm13.01 26.95l-25.69 7.63 25 18.17 6.69-4.87-6-20.93z"/>'],
    ["fairy", "フェアリー", "#dab4d4", '<path d="M66.36 12.08c-2.18-2.18-15.61-3.16-24.65 5.88-1.55 1.55-2.63 3.4-3.25 5.35-.62-1.96-1.7-3.8-3.25-5.35-9.04-9.04-22.47-8.06-24.65-5.88S7.4 27.69 16.44 36.73c1.91 1.91 4.26 3.11 6.73 3.61-5 4.33-5.57 11.18-4.61 12.52 1.02 1.42 8.4 3.21 14.31-.94-.27.79-.53 1.6-.79 2.44-2.47 8.08-3.39 14.96-2.07 15.36 1.33.41 4.41-5.81 6.88-13.89.62-2.03 1.15-3.99 1.56-5.79.41 1.8.94 3.76 1.56 5.79 2.47 8.08 5.55 14.3 6.88 13.89 1.33-.41.4-7.29-2.07-15.36-.26-.84-.52-1.65-.79-2.44 5.91 4.15 13.3 2.36 14.31.94.96-1.34.39-8.18-4.61-12.52 2.47-.5 4.82-1.7 6.73-3.61 9.04-9.04 8.06-22.47 5.88-24.65zm-27.9 28.05c-4.31 0-8.04-2.45-9.9-6.03 5.01-.02 9.15-3.74 9.81-8.57.02-.12.17-.12.18 0 .66 4.83 4.8 8.56 9.81 8.57-1.86 3.58-5.59 6.03-9.9 6.03z"/>'],
].map(([id, ja, color, shapes]) => ({ id, ja, color, svg: `<svg viewBox="0 0 76.71 76.71"><rect width="76.71" height="76.71" rx="6.57" fill="${color}"/><g fill="#fff">${shapes}</g></svg>` }));

const TYPE_BY_JA = Object.fromEntries(TYPES_INFO.map((type) => [type.ja, type]));

const CATEGORY_SVG = {
    "物理": '<svg viewBox="0 0 95 95"><g transform="matrix(1,0,0,1,-256.462,-752.96)"><g transform="matrix(0.231713,0,0,0.220372,178.786,681.419)"><path d="M540,324.637L587.538,381.96C589.306,384.091 592.055,385.01 594.669,384.342L666.75,365.927L671.484,439.758C671.674,442.717 673.488,445.287 676.125,446.335L744.774,473.611L705.41,535.803C703.802,538.345 703.802,541.655 705.41,544.197L744.774,606.389L676.125,633.665C673.488,634.713 671.674,637.283 671.484,640.242L666.75,714.072L594.669,695.658C592.055,694.99 589.306,695.909 587.538,698.04L540,755.363L492.462,698.04C490.694,695.909 487.945,694.99 485.331,695.658L413.25,714.073L408.516,640.242C408.326,637.283 406.512,634.713 403.875,633.665L335.226,606.389L374.59,544.197C376.198,541.655 376.198,538.345 374.59,535.803L335.226,473.611L403.875,446.335C406.512,445.287 408.326,442.717 408.516,439.758L413.25,365.928L485.331,384.342C487.945,385.01 490.694,384.091 492.462,381.96L540,324.637ZM545.43,383.762C544.062,382.112 542.082,381.166 540,381.166C537.918,381.166 535.938,382.112 534.57,383.762L502.135,422.873L452.793,410.268C450.728,409.74 448.547,410.198 446.833,411.519C445.119,412.84 444.047,414.89 443.904,417.119L440.675,467.467L393.597,486.172C391.544,486.988 389.957,488.743 389.285,490.939C388.614,493.136 388.93,495.534 390.146,497.455L417.074,540L390.146,582.545C388.93,584.466 388.614,586.864 389.285,589.061C389.957,591.257 391.544,593.012 393.597,593.828L440.675,612.533L443.904,662.881C444.047,665.11 445.119,667.16 446.833,668.481C448.547,669.802 450.728,670.26 452.793,669.732L502.135,657.127L534.57,696.238C535.938,697.888 537.918,698.834 540,698.834C542.082,698.834 544.062,697.888 545.43,696.238L577.865,657.127L627.207,669.732C629.272,670.26 631.453,669.802 633.167,668.481C634.881,667.16 635.953,665.11 636.096,662.881L639.325,612.533L686.403,593.828C688.456,593.012 690.043,591.257 690.715,589.061C691.386,586.864 691.07,584.466 689.854,582.545L662.926,540L689.854,497.455C691.07,495.534 691.386,493.136 690.715,490.939C690.043,488.743 688.456,486.988 686.403,486.172L639.325,467.467L636.096,417.119C635.953,414.89 634.881,412.84 633.167,411.519C631.453,410.198 629.272,409.74 627.207,410.268L577.865,422.873L545.43,383.762Z"></path></g></g></svg>',
    "特殊": '<svg viewBox="0 0 97 97"><g transform="matrix(1,0,0,1,-374.328,-752.089)"><g transform="matrix(0.107373,0,0,0.107373,364.677,742.438)"><path d="M540,89.88C788.428,89.88 990.12,291.572 990.12,540C990.12,788.428 788.428,990.12 540,990.12C291.572,990.12 89.88,788.428 89.88,540C89.88,291.572 291.572,89.88 540,89.88ZM540,175.203C338.663,175.203 175.203,338.663 175.203,540C175.203,741.337 338.663,904.797 540,904.797C741.337,904.797 904.797,741.337 904.797,540C904.797,338.663 741.337,175.203 540,175.203ZM540,289.832C678.071,289.832 790.168,401.929 790.168,540C790.168,678.071 678.071,790.168 540,790.168C401.929,790.168 289.832,678.071 289.832,540C289.832,401.929 401.929,289.832 540,289.832ZM540,391.596C458.093,391.596 391.596,458.093 391.596,540C391.596,621.907 458.093,688.404 540,688.404C621.907,688.404 688.404,621.907 688.404,540C688.404,458.093 621.907,391.596 540,391.596Z"></path></g></g></svg>',
};

$$(".main_search_info_types_item[data-type]").forEach((el) => el.insertAdjacentHTML("afterbegin", TYPE_BY_JA[el.dataset.type]?.svg ?? ""));
$$("[data-type-svg]").forEach((el) => { el.innerHTML = TYPE_BY_JA[el.dataset.typeSvg]?.svg ?? ""; });
$$("[data-category-svg]").forEach((el) => { el.innerHTML = CATEGORY_SVG[el.dataset.categorySvg] ?? ""; });

const swapSprite = (img, src) => {
    if (img.getAttribute("src") === src) return;
    const token = (img.dataset.swapToken = String(Number(img.dataset.swapToken ?? 0) + 1));
    const shrink = img.animate([{ scale: 1 }, { scale: 0 }], { duration: 140, easing: "ease-in", fill: "forwards" });
    shrink.finished.catch(() => {}).then(() => {
        if (img.dataset.swapToken !== token) return;
        img.src = src;
        shrink.cancel();
        img.animate([{ scale: 0 }, { scale: 1.12, offset: 0.7 }, { scale: 1 }], { duration: 300, easing: "cubic-bezier(.34, 1.56, .64, 1)" });
    });
};

const spinChangeIcon = (side) => {
    side.querySelector(".main_search_change svg")?.animate(
        [{ rotate: "0deg" }, { rotate: "-100deg", offset: 0.45 }, { rotate: "0deg" }],
        { duration: 520, easing: "ease-in-out" },
    );
};

let pokemons = {};

let searchAliases = { pokemons: {}, moves: {}, abilities: {}, items: {} };
const USAGE_SOURCE = "https://championsbattledata.com";
const USAGE_KEY = "pokefire-usage-v3";
const MEGA_STONE = "メガストーン";
const USAGE_TTL = 6 * 60 * 60 * 1000;
let usageData = null;

const usageReady = (async () => {
    let cached = null;
    try {
        cached = JSON.parse(localStorage.getItem(USAGE_KEY));
        if (cached && Date.now() - cached.fetchedAt < USAGE_TTL) return (usageData = cached);
    } catch {}
    try {
        const getJson = (url) => fetch(url).then((res) => (res.ok ? res.json() : Promise.reject(new Error(url))));
        const [names, index] = await Promise.all([getJson("usage_names.json"), getJson(`${USAGE_SOURCE}/data/meta/index.json`)]);
        const season = index.seasons.find((s) => s.formats.includes("Singles") && s.dates.length);
        const date = season.dates[0];
        const day = await getJson(`${USAGE_SOURCE}/data/meta/${season.season}/${date}/Singles.json`);
        const toJa = (rows, table) => (rows ?? []).map(([name, pct]) => [table[name] ?? null, pct]);
        const toItems = (rows, table) => {
            const merged = new Map();
            (rows ?? []).forEach(([name, pct], i) => {
                const ja = table[name] ?? (/ite( [XYZ])?$/.test(name) ? MEGA_STONE : `?${i}`);
                merged.set(ja, (merged.get(ja) ?? 0) + pct);
            });
            return [...merged].sort((a, b) => b[1] - a[1]).map(([name, pct]) => [name.startsWith("?") ? null : name, Math.round(pct * 10) / 10]);
        };
        const result = { fetchedAt: Date.now(), season: season.season, date, pokemons: {} };
        Object.entries(names.pokemons).forEach(([ja, en]) => {
            const entry = day.pokemon[en];
            if (!entry) return;
            result.pokemons[ja] = {
                rank: entry.position,
                moves: toJa(entry.move, names.moves),
                abilities: toJa(entry.ability, names.abilities),
                items: toItems(entry.held_item, names.items),
            };
        });
        try {
            localStorage.setItem(USAGE_KEY, JSON.stringify(result));
        } catch {}
        return (usageData = result);
    } catch (err) {
        if (cached?.pokemons) return (usageData = cached);
        console.error("使用率データを読み込めませんでした", err);
        return null;
    }
})();

const usageCredit = () => {
    const credit = document.createElement("a");
    credit.className = "usage_credit";
    credit.href = USAGE_SOURCE;
    credit.target = "_blank";
    credit.rel = "noopener";
    credit.textContent = "Battle data provided by Pokémon Champions Battle Data";
    return credit;
};

const usageNameOf = (name) => (name?.startsWith("メガ") && pokemons[name] && megaParent(name, pokemons[name])) || name;
const topAttackMove = (name) => usageData?.pokemons[usageNameOf(name)]?.moves.find(([key]) => key && movesData[key] && movesData[key].category !== "変化")?.[0];

const applyUsageDefaults = (side, name) => {
    const move = side.classList.contains("attacker") && topAttackMove(name);
    if (move) selectMove(move, movesData[move]);
    const entry = usageData?.pokemons[name];
    if (!entry || usageNameOf(name) !== name) return;
    const ability = entry.abilities[0]?.[0];
    if (ability) selectAbility(ability, null, side);
    const item = entry.items[0]?.[0];
    selectItem(item && item !== MEGA_STONE ? item : "なし", null, side);
};

const aliasesReady = loadJson("aliases.json")
    .then((data) => {
        searchAliases = { ...searchAliases, ...data };
    })
    .catch((err) => console.error("aliases.json の読み込みに失敗しました", err));

const searchTextOf = (kind, name, ...extra) => [normalize(name), ...(searchAliases[kind]?.[name] ?? []), ...extra.map(normalize)]
    .filter(Boolean)
    .join("|");

const pokemonsReady = Promise.all([
    loadJson("pokemons.json"),
    aliasesReady,
]).then(([data]) => {
    pokemons = data;
    return data;
});
pokemonsReady.catch((err) => console.error("pokemons.json の読み込みに失敗しました", err));

const toArray = (value) => (Array.isArray(value) ? value : value ? [value] : []);

const normalize = (text) => text
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[ァ-ヶ]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0x60))
    .replace(/\s+/g, "");

const ROMAJI_TABLE = (() => {
    const table = { "-": "ー" };
    const vowels = ["a", "i", "u", "e", "o"];
    const smallY = { a: "ゃ", i: "ぃ", u: "ゅ", e: "ぇ", o: "ょ" };
    const smallV = { a: "ぁ", i: "ぃ", u: "ぅ", e: "ぇ", o: "ぉ" };
    const rows = {
        "": "あいうえお", k: "かきくけこ", s: "さしすせそ", t: "たちつてと", n: "なにぬねの",
        h: "はひふへほ", m: "まみむめも", r: "らりるれろ", g: "がぎぐげご", z: "ざじずぜぞ",
        d: "だぢづでど", b: "ばびぶべぼ", p: "ぱぴぷぺぽ", c: "かしくせこ", x: "ぁぃぅぇぉ", l: "ぁぃぅぇぉ",
    };
    Object.entries(rows).forEach(([c, kana]) => vowels.forEach((v, i) => { table[c + v] = kana[i]; }));
    Object.assign(table, {
        ya: "や", yi: "い", yu: "ゆ", ye: "いぇ", yo: "よ",
        wa: "わ", wi: "うぃ", wu: "う", we: "うぇ", wo: "を",
        xya: "ゃ", lya: "ゃ", xyu: "ゅ", lyu: "ゅ", xyo: "ょ", lyo: "ょ",
        xtu: "っ", ltu: "っ", xtsu: "っ", ltsu: "っ", xwa: "ゎ", lwa: "ゎ", xn: "ん",
    });
    const iRow = { k: "き", s: "し", t: "ち", c: "ち", n: "に", h: "ひ", m: "み", r: "り", g: "ぎ", z: "じ", j: "じ", d: "ぢ", b: "び", p: "ぴ", f: "ふ", v: "ゔ" };
    Object.entries(iRow).forEach(([c, kana]) => vowels.forEach((v) => { table[c + "y" + v] = kana + smallY[v]; }));
    [["sh", "し"], ["ch", "ち"], ["j", "じ"]].forEach(([c, kana]) => vowels.forEach((v) => {
        table[c + v] = v === "i" ? kana : kana + smallY[v];
    }));
    [["f", "ふ"], ["v", "ゔ"], ["ts", "つ"], ["th", "て"], ["dh", "で"], ["tw", "と"], ["dw", "ど"]].forEach(([c, kana]) => vowels.forEach((v) => {
        table[c + v] = v === "u" && ["f", "v", "ts"].includes(c) ? kana : kana + smallV[v];
    }));
    Object.assign(table, { thu: "てゅ", dhu: "でゅ" });
    return table;
})();

const romajiToKana = (text) => {
    let result = "";
    let i = 0;
    while (i < text.length) {
        const c = text[i];
        const next = text[i + 1];
        if (c === "n" && next !== undefined && !/[aiueoy]/.test(next)) {
            result += "ん";
            i += next === "'" || (next === "n" && !/[aiueoy]/.test(text[i + 2] ?? "")) ? 2 : 1;
            continue;
        }
        if (/[bcdfghjkmpqrstvwxz]/.test(c) && (next === c || (c === "t" && next === "c"))) {
            result += "っ";
            i += 1;
            continue;
        }
        let matched = false;
        for (let len = 4; len >= 1; len--) {
            const kana = ROMAJI_TABLE[text.slice(i, i + len)];
            if (kana) {
                result += kana;
                i += len;
                matched = true;
                break;
            }
        }
        if (!matched) {
            result += c;
            i += 1;
        }
    }
    return result;
};

const searchKeys = (query) => {
    const raw = normalize(query);
    if (raw === "") return null;
    const first = new Set([raw]);
    const fallback = new Set();
    if (/[a-z]/.test(raw)) {
        const kana = romajiToKana(raw);
        first.add(kana);
        if (kana.endsWith("n")) first.add(kana.slice(0, -1) + "ん");
        const stripped = kana.replace(/[a-z]{1,3}$/, "");
        if (stripped && stripped !== kana) fallback.add(stripped);
    }
    return { first: [...first], fallback: [...fallback] };
};

const CATEGORY_READINGS = { "物理": "ぶつり", "特殊": "とくしゅ", "変化": "へんか" };

const searchTiers = (...tiers) => tiers.map((tier) => (Array.isArray(tier) ? tier.map(normalize).filter(Boolean).join("|") : tier)).join("\n");

const tierOf = (text, keys) => text.split("\n").findIndex((tier) => {
    if (tier.startsWith("=")) {
        const parts = tier.slice(1).split("|");
        return keys.some((key) => parts.includes(key));
    }
    return keys.some((key) => tier.includes(key));
});

const filterBySearch = (items, getText, query) => {
    const keys = searchKeys(query);
    const texts = items.map(getText);
    let tiers = texts.map((text) => (keys ? tierOf(text, keys.first) : 0));
    if (keys && tiers.every((tier) => tier < 0)) {
        const loose = [...keys.first, ...keys.fallback].map((key) => key.replace(/ー/g, "")).filter(Boolean);
        tiers = texts.map((text) => tierOf(text.replace(/ー/g, ""), loose));
    }
    items.forEach((item, i) => { item.hidden = tiers[i] < 0; });
    return tiers;
};

const sortByTier = (items, tiers, groupOf = (item) => item) => {
    const groups = new Map();
    items.forEach((item, i) => {
        const key = groupOf(item);
        const group = groups.get(key) ?? { items: [], tier: Infinity, order: groups.size };
        group.items.push(item);
        if (tiers[i] >= 0) group.tier = Math.min(group.tier, tiers[i]);
        groups.set(key, group);
    });
    return [...groups.values()].sort((a, b) => a.tier - b.tier || a.order - b.order).flatMap((group) => group.items);
};

const baseName = (name) => name.replace(/\(.*\)$/, "").replace(/[XYZ]$/, "");
const megaParent = (name, pokemon) => {
    if (!name.startsWith("メガ")) return undefined;
    const rest = name.slice(2);
    const candidates = Object.keys(pokemons).filter((other) =>
        other !== name && pokemons[other].num === pokemon.num && baseName(other) === baseName(rest));
    return candidates.find((other) => other === rest) ?? candidates[0];
};

const sortWithMegaTree = () => {
    const entries = Object.entries(pokemons);
    const megasByParent = {};
    entries.forEach(([name, pokemon]) => {
        const parent = megaParent(name, pokemon);
        if (parent) (megasByParent[parent] ??= []).push([name, pokemon]);
    });
    const rank = (name) => usageData?.pokemons[name]?.rank ?? Infinity;
    return entries
        .filter(([name, pokemon]) => !megaParent(name, pokemon))
        .map((entry, i) => [entry, i])
        .sort(([a, i], [b, j]) => rank(a[0]) - rank(b[0]) || i - j)
        .flatMap(([entry]) => [entry, ...(megasByParent[entry[0]] ?? [])]);
};

const otherFormsOf = (name) => {
    const current = pokemons[name];
    if (!current) return [];
    return Object.entries(pokemons).filter(([other, p]) => p.num === current.num && other !== name);
};

const pokemonSearchSides = [];
const searchOf = (side) => pokemonSearchSides.find((s) => s.side === side);

const chooseOverlays = $$(".main_choose_overlay");
const orderChoose = $(".order_choose_container");
const syncChooseOverlay = () => {
    const isOpen = pokemonSearchSides.some((s) => s.isChooseOpen()) || !!orderChoose?.classList.contains("active");
    document.body.classList.toggle("is-choose-open", isOpen);
};
const closeOrderChoose = () => {
    if (!orderChoose?.classList.contains("active")) return;
    orderChoose.classList.remove("active");
    syncChooseOverlay();
};

const closeOtherSidesChoose = (current = null) => {
    closeOrderChoose();
    pokemonSearchSides.forEach((s) => {
        if (s === current) return;
        s.closePokemonChoose();
        s.closeTypeChoose();
    });
};

chooseOverlays.forEach((overlay) => {
    overlay.addEventListener("click", (e) => {
        e.preventDefault();
        closeOtherSidesChoose();
    });
    overlay.addEventListener("mousedown", (e) => e.preventDefault());
});

const POKEMON_HISTORY_KEY = "pokefire-pokemon-history";
const loadPokemonHistory = () => {
    try {
        return JSON.parse(localStorage.getItem(POKEMON_HISTORY_KEY)) ?? [];
    } catch {
        return [];
    }
};
const rememberPokemon = (name) => {
    const list = [name, ...loadPokemonHistory().filter((other) => other !== name)].slice(0, 30);
    try {
        localStorage.setItem(POKEMON_HISTORY_KEY, JSON.stringify(list));
    } catch {}
};

function setupPokemonSearch(side) {
    const pokemonSearch = side.querySelector(".main_search_info input");
    const pokemonChoose = side.querySelector(".main_pokemon_choose");
    const pokemonChooseList = pokemonChoose?.querySelector(".main_pokemon_choose_list");
    const typesBox = side.querySelector(".main_search_info_types");
    const typeChoose = side.querySelector(".main_type_choose");
    const typeChooseList = typeChoose?.querySelector(".main_type_choose_list");
    let currentPokemonName = pokemonSearch?.value ?? "";
    let currentTypes = [...(typesBox?.querySelectorAll(".main_search_info_types_item") ?? [])].map((item) => item.dataset.type);

    const updateMegaTree = () => {
        const items = [...pokemonChooseList.querySelectorAll(".main_pokemon_choose_item:not([hidden])")];
        const visibleNames = new Set(items.map((item) => item.dataset.name));
        items.forEach((item) => {
            item.classList.toggle("is-mega", !!item.dataset.parent && visibleNames.has(item.dataset.parent));
        });
        items.forEach((item, i) => {
            const next = items[i + 1];
            item.classList.toggle("is-last", item.classList.contains("is-mega") && !next?.classList.contains("is-mega"));
        });
    };

    let pokemonBaseOrder = [];
    let chooseMode = "usage";
    let lastQuery = "";
    const renderPokemonList = () => {
        pokemonChooseList.innerHTML = sortWithMegaTree().map(([name, pokemon]) => `
            <div class="main_pokemon_choose_item" data-name="${name}" data-search="${searchTiers(searchTextOf("pokemons", name), toArray(pokemon.types), toArray(pokemon.abilities))}" data-parent="${megaParent(name, pokemon) ?? ""}">
                <div class="main_pokemon_choose_item_icon">
                    <img src="${spriteOf(pokemon)}" alt="" loading="lazy">
                </div>
                <p class="main_pokemon_choose_item_name">${name}</p>
                <div class="main_pokemon_choose_item_name_types">
                    ${toArray(pokemon.types).map((type) => `<div class="main_pokemon_choose_item_name_types_item">${TYPE_BY_JA[type]?.svg ?? ""}</div>`).join("")}
                </div>
            </div>`).join("");
        pokemonBaseOrder = [...pokemonChooseList.querySelectorAll(".main_pokemon_choose_item")];
        updateMegaTree();
    };

    const filterPokemonList = (query, { resetScroll = false } = {}) => {
        lastQuery = query;
        const base = pokemonBaseOrder.length ? pokemonBaseOrder : [...pokemonChooseList.querySelectorAll(".main_pokemon_choose_item")];
        let items = base;
        if (chooseMode === "history") {
            const history = loadPokemonHistory();
            const byName = new Map(base.map((item) => [item.dataset.name, item]));
            items = history.map((name) => byName.get(name)).filter(Boolean);
            const picked = new Set(items);
            base.forEach((item) => { if (!picked.has(item)) item.hidden = true; });
        }
        const tiers = filterBySearch(items, (item) => item.dataset.search, query);
        const ordered = sortByTier(items, tiers, chooseMode === "history" ? (item) => item.dataset.name : (item) => item.dataset.parent || item.dataset.name);
        pokemonChooseList.append(...ordered);
        if (chooseMode === "history") pokemonChooseList.append(...base.filter((item) => item.hidden));
        const empty = !ordered.some((item) => !item.hidden);
        if (empty) pokemonChooseList.dataset.empty = chooseMode === "history" && !items.length ? "履歴はまだありません" : "見つかりません";
        else delete pokemonChooseList.dataset.empty;
        updateMegaTree();
        if (resetScroll) pokemonChoose.scrollTop = 0;
    };

    const renderTypes = () => {
        if (typesBox) {
            typesBox.querySelectorAll(".main_search_info_types_item").forEach((item) => item.remove());
            const typesHtml = currentTypes.map((type) => `
                <div class="main_search_info_types_item" data-type="${type}">
                    ${TYPE_BY_JA[type]?.svg ?? ""}
                    <p>${type}</p>
                </div>`).join("");
            typesBox.insertAdjacentHTML("afterbegin", typesHtml);
        }
        typeChooseList?.querySelectorAll(".main_type_choose_item").forEach((item) => {
            item.classList.toggle("selected", currentTypes.includes(item.dataset.type));
        });
    };

    const toggleType = (type) => {
        currentTypes = currentTypes.includes(type)
            ? currentTypes.filter((t) => t !== type)
            : [...currentTypes, type];
        renderTypes();
    };

    const selectPokemon = (name) => {
        const pokemon = pokemons[name];
        if (!pokemon) return;
        currentPokemonName = name;
        pokemonSearch.value = name;

        const sprite = side.querySelector(".main_search_sprite_img");
        if (sprite) swapSprite(sprite, spriteOf(pokemon));
        const change = side.querySelector(".main_search_change");
        if (change) change.hidden = otherFormsOf(name).length === 0;

        currentTypes = toArray(pokemon.types);
        renderTypes();

        Object.entries(pokemon.basestats).forEach(([key, value]) => {
            const stat = side.querySelector(`.main_basestats_item.${key} p`);
            if (stat) stat.textContent = value;
        });
        applyAdjustments(side, name);

        const abilities = toArray(pokemon.abilities);
        side.querySelectorAll(".main_ability_header_ex").forEach((ex) => {
            ex.innerHTML = abilities.map((ability, i) => `<span${i === 0 ? ' class="selected"' : ""}>${ability}</span>`).join("");
            const label = ex.closest(".main_ability")?.querySelector("button.main_ability_choose p");
            if (label) label.textContent = abilities[0] ?? "なし";
            syncAbilityButton(side, { reset: true });
        });

        const itemLabel = side.querySelector("button.main_item_choose p");
        if (itemLabel) {
            if (megaParent(name, pokemon)) itemLabel.textContent = "メガストーン";
            else if (itemLabel.textContent.trim() === "メガストーン") itemLabel.textContent = "なし";
        }
    };

    const selectAbilityIn = (ability) => {
        const spans = [...side.querySelectorAll(".main_ability_header_ex span")];
        if (!spans.some((span) => span.textContent.trim() === ability)) return;
        spans.forEach((span) => span.classList.toggle("selected", span.textContent.trim() === ability));
        const label = side.querySelector("button.main_ability_choose p");
        if (label) label.textContent = ability;
        syncAbilityButton(side, { reset: true });
    };

    const self = {
        side,
        isChooseOpen: () => !!(pokemonChoose?.classList.contains("active") || typeChoose?.classList.contains("active")),
        closePokemonChoose: () => {},
        closeTypeChoose: () => {},
        getPokemon: () => ({ name: currentPokemonName, types: [...currentTypes] }),
        setTypes: (types) => {
            currentTypes = [...types];
            renderTypes();
        },
        setPokemon: ({ name, types }) => {
            selectPokemon(name);
            if (types) {
                currentTypes = [...types];
                renderTypes();
            }
        },
    };

    const openTypeChoose = () => {
        closeOtherSidesChoose(self);
        closePokemonChoose();
        typeChoose?.classList.add("active");
        syncChooseOverlay();
    };
    const closeTypeChoose = () => {
        typeChoose?.classList.remove("active");
        syncChooseOverlay();
    };

    const openPokemonChoose = () => {
        closeOtherSidesChoose(self);
        pokemonChoose.classList.add("active");
        syncChooseOverlay();
    };
    const closePokemonChoose = () => {
        if (!pokemonChoose) return;
        pokemonChoose.classList.remove("active");
        if (pokemonSearch.value !== currentPokemonName) pokemonSearch.value = currentPokemonName;
        pokemonSearch.blur();
        syncChooseOverlay();
    };

    self.closePokemonChoose = closePokemonChoose;
    self.closeTypeChoose = closeTypeChoose;
    pokemonSearchSides.push(self);

    let selectAllOnMouseUp = false;
    const selectAllSearchText = () => {
        pokemonSearch.setSelectionRange(0, pokemonSearch.value.length);
        requestAnimationFrame(() => {
            if (document.activeElement === pokemonSearch) pokemonSearch.setSelectionRange(0, pokemonSearch.value.length);
        });
    };

    if (pokemonSearch && pokemonChoose && pokemonChooseList) {
        pokemonSearch.addEventListener("focus", () => {
            closeTypeChoose();
            filterPokemonList("");
            selectAllOnMouseUp = true;
            selectAllSearchText();
            openPokemonChoose();
        });
        pokemonSearch.addEventListener("mouseup", (e) => {
            if (!selectAllOnMouseUp) return;
            selectAllOnMouseUp = false;
            e.preventDefault();
            selectAllSearchText();
        });
        pokemonSearch.addEventListener("keydown", () => { selectAllOnMouseUp = false; });
        pokemonSearch.addEventListener("blur", () => { selectAllOnMouseUp = false; });
        pokemonSearch.addEventListener("input", () => {
            openPokemonChoose();
            filterPokemonList(pokemonSearch.value, { resetScroll: true });
        });
        pokemonSearch.addEventListener("keydown", (e) => {
            if (e.key !== "Enter" || e.isComposing) return;
            const first = pokemonChooseList.querySelector(".main_pokemon_choose_item:not([hidden])");
            if (first) {
                selectPokemon(first.dataset.name);
                applyUsageDefaults(side, first.dataset.name);
                rememberPokemon(first.dataset.name);
            }
            closePokemonChoose();
        });

        const chooseTabs = document.createElement("div");
        chooseTabs.className = "main_pokemon_choose_tabs";
        chooseTabs.innerHTML = '<button type="button" data-mode="usage" class="active">使用率</button><button type="button" data-mode="history">履歴</button>';
        pokemonChoose.prepend(chooseTabs);
        pokemonChoose.classList.add("has-tabs");
        chooseTabs.addEventListener("click", (e) => {
            const button = e.target.closest("button");
            if (!button || button.dataset.mode === chooseMode) return;
            chooseMode = button.dataset.mode;
            chooseTabs.querySelectorAll("button").forEach((b) => b.classList.toggle("active", b === button));
            haptic("selection");
            filterPokemonList(lastQuery, { resetScroll: true });
        });

        pokemonChoose.addEventListener("mousedown", (e) => e.preventDefault());
        pokemonChoose.addEventListener("click", (e) => {
            if (e.target.closest(".main_choose_close")) {
                closePokemonChoose();
                return;
            }
            const item = e.target.closest(".main_pokemon_choose_item");
            if (!item) return;
            selectPokemon(item.dataset.name);
            applyUsageDefaults(side, item.dataset.name);
            rememberPokemon(item.dataset.name);
            haptic("light");
            closePokemonChoose();
        });

        pokemonsReady
            .then(() => {
                renderPokemonList();
                const initial = Object.keys(pokemons).find((name) => normalize(name) === normalize(pokemonSearch.value));
                const initialAbility = side.querySelector("button.main_ability_choose p")?.textContent.trim();
                if (initial) {
                    selectPokemon(initial);
                    if (initialAbility) selectAbilityIn(initialAbility);
                }
            })
            .catch(() => {});
        Promise.all([pokemonsReady, usageReady]).then(([, usage]) => {
            if (!usage) return;
            renderPokemonList();
            filterPokemonList(pokemonChoose.classList.contains("active") ? pokemonSearch.value : "");
        }).catch(() => {});
        pokemonChoose.insertBefore(usageCredit(), $(".main_choose_close", pokemonChoose));
    }

    if (typesBox && typeChoose && typeChooseList) {
        typeChooseList.innerHTML = TYPES_INFO.map((type) => `
            <div class="main_type_choose_item" data-type="${type.ja}" title="${type.ja}">${type.svg}</div>`).join("");
        renderTypes();

        typesBox.addEventListener("click", (e) => {
            e.preventDefault();
            const item = e.target.closest(".main_search_info_types_item");
            if (item && typeChoose.classList.contains("active")) toggleType(item.dataset.type);
            openTypeChoose();
        });
        typeChoose.addEventListener("click", (e) => {
            if (e.target.closest(".main_choose_close")) {
                closeTypeChoose();
                return;
            }
            if (e.target.closest(".main_type_choose_reset")) {
                const pokemon = pokemons[currentPokemonName];
                if (pokemon) {
                    currentTypes = toArray(pokemon.types);
                    renderTypes();
                }
                return;
            }
            const item = e.target.closest(".main_type_choose_item");
            if (item) toggleType(item.dataset.type);
        });
    }

    const searchSprite = side.querySelector(".main_search_sprite");
    const otherForms = side.querySelector(".main_search_otherforms");

    const searchLabel = side.querySelector("label.main_search");
    const closeOtherForms = () => {
        otherForms?.classList.remove("active");
        searchLabel?.classList.remove("is-forms-open");
    };

    const openOtherForms = () => {
        if (!otherForms) return;
        const forms = otherFormsOf(currentPokemonName);
        if (forms.length === 0) return;

        closeOtherSidesChoose(self);
        closePokemonChoose();
        closeTypeChoose();

        otherForms.querySelectorAll(".main_search_otherform_item").forEach((item) => item.remove());
        otherForms.insertAdjacentHTML("beforeend", forms.map(([name, p], i) => `
            <div class="main_search_otherform_item" data-name="${name}" title="${name}" style="--i: ${i}">
                <img src="${spriteOf(p)}" alt="${name}" class="main_search_otherform_img">
            </div>`).join(""));
        searchLabel?.classList.add("is-forms-open");
        otherForms.scrollLeft = 0;
        requestAnimationFrame(() => requestAnimationFrame(() => otherForms.classList.add("active")));
    };

    if (searchSprite && otherForms) {
        searchSprite.addEventListener("click", (e) => {
            e.preventDefault();
            spinChangeIcon(side);
            if (otherForms.classList.contains("active")) closeOtherForms();
            else openOtherForms();
        });
        otherForms.addEventListener("click", (e) => {
            e.preventDefault();
            if (e.target.closest(".main_search_otherforms_close")) {
                closeOtherForms();
                return;
            }
            const item = e.target.closest(".main_search_otherform_item");
            if (!item) return;
            selectPokemon(item.dataset.name);
            applyUsageDefaults(side, item.dataset.name);
            closeOtherForms();
        });
        pokemonSearch?.addEventListener("focus", closeOtherForms);
    }
}

$$("main.attacker, main.defender").forEach((side) => setupPokemonSearch(side));

const MOVE_STAT_EXCEPTIONS = {
    "ボディプレス": { basestat: ["b"], evs: ["b"] },
    "イカサマ": { basestat: [], evs: ["vsa"] },
    "いのちがけ": { basestat: ["h"], evs: ["h"] },
    "がむしゃら": { basestat: ["h"], evs: ["h"] },
};
const MOVE_STAT_EXTRA_EVS = {
    "エレキボール": ["s"],
    "ジャイロボール": ["s"],
    "ふんか": ["h"],
    "しおふき": ["h"],
    "きしかいせい": ["h"],
    "じたばた": ["h"],
};

const DEFENDER_STAT_EXCEPTIONS = {
    "いのちがけ": { basestat: ["h"], evs: ["h"] },
    "がむしゃら": { basestat: ["h"], evs: ["h"] },
    "いかりのまえば": { basestat: ["h"], evs: ["h"] },
    "ちきゅうなげ": { basestat: ["h"], evs: ["h"] },
    "ナイトヘッド": { basestat: ["h"], evs: ["h"] },
};
const DEFENDER_STAT_EXTRA_EVS = {
    "エレキボール": ["s"],
    "ジャイロボール": ["s"],
};

const EVS_KEYS = ["h", "a", "vsa", "c", "b", "d", "s"];

const applyStatRule = (side, rule, extraEvs) => {
    if (!side) return;
    const evs = [...rule.evs, ...extraEvs];
    side.querySelectorAll(".main_basestats_item").forEach((item) => {
        item.classList.toggle("active", rule.basestat.some((key) => item.classList.contains(key)));
    });
    EVS_KEYS.forEach((key) => {
        side.querySelectorAll(`.main_evs.main_evs_${key}`).forEach((section) => {
            section.classList.toggle("active", evs.includes(key));
        });
    });
};

const HP_REFERENCE_MOVES = new Set(["ふんか", "しおふき", "ドラゴンエナジー", "じたばた", "きしかいせい", "いのちがけ", "がむしゃら"]);

const AXEL_POWERS = [20, 40, 60];
var countUi = null;

const createCount = (className, title) => {
    const label = document.createElement("label");
    label.className = `main_count ${className}`;
    label.hidden = true;
    label.innerHTML = `<span class="ttl">${title}</span><span class="value"></span><span class="unit">回</span><select></select>`;
    const select = $("select", label);
    let range = [0, 0];
    let drag = null;
    let pointerType = "";
    let dragged = false;
    label.get = () => Number(select.value);
    label.set = (value) => {
        const next = Math.min(range[1], Math.max(range[0], value));
        select.value = next;
        $(".value", label).textContent = next;
        $(".unit", label).textContent = label.openEnded && next === range[1] ? "回以上" : "回";
        label.onChange?.(next);
    };
    label.setRange = (min, max, value) => {
        range = [min, max];
        select.innerHTML = Array.from({ length: max - min + 1 }, (_, i) => `<option value="${min + i}">${min + i}${label.openEnded && min + i === max ? "+" : ""}</option>`).join("");
        label.set(value);
    };
    const setFromX = (x) => {
        const rect = label.getBoundingClientRect();
        const count = range[1] - range[0] + 1;
        const next = range[0] + Math.min(count - 1, Math.max(0, Math.floor(((x - rect.left) / rect.width) * count)));
        if (next !== label.get()) haptic("selection");
        label.set(next);
    };
    select.addEventListener("change", () => label.set(Number(select.value)));
    label.addEventListener("mousedown", (e) => {
        if (pointerType === "mouse") e.preventDefault();
    });
    label.addEventListener("pointerdown", (e) => {
        pointerType = e.pointerType;
        dragged = false;
        drag = { x: e.clientX, id: e.pointerId, moved: false };
    });
    label.addEventListener("pointermove", (e) => {
        if (!drag || e.pointerId !== drag.id || (!drag.moved && Math.abs(e.clientX - drag.x) < 6)) return;
        if (!drag.moved) {
            try {
                label.setPointerCapture(e.pointerId);
            } catch {}
        }
        drag.moved = dragged = true;
        setFromX(e.clientX);
    });
    ["touchend", "click"].forEach((type) => label.addEventListener(type, (e) => {
        if (dragged) e.preventDefault();
    }, { passive: false }));
    label.addEventListener("pointerup", (e) => {
        if (drag?.moved) setFromX(e.clientX);
        if (drag && !drag.moved && pointerType === "mouse") {
            try {
                select.showPicker();
            } catch {
                select.focus();
            }
        }
        drag = null;
    });
    label.addEventListener("pointercancel", () => { drag = null; });
    return label;
};

const attackerSide = $("main.attacker");
if (attackerSide) {
    const hits = createCount("main_move_hits", "ヒット回数");
    const crits = createCount("main_move_crits", "急所回数");
    hits.onChange = (value) => crits.setRange(0, value, crits.get());
    $(".main_move_btn", attackerSide)?.append(hits, crits);
    const axel = document.createElement("div");
    axel.className = "main_move_axel";
    axel.hidden = true;
    axel.innerHTML = AXEL_POWERS.map((power, i) => `<div class="main_move_axel_row">
        <p>${i + 1}回目</p>
        <button class="hit active">威力${power} ヒット</button>
        <button class="crit">急所</button>
    </div>`).join("");
    $(".main_move_btn", attackerSide)?.after(axel);
    axel.addEventListener("click", (e) => {
        const button = e.target.closest("button");
        if (!button) return;
        if (button.classList.contains("hit") || $(".hit", button.parentElement).classList.contains("active")) button.classList.toggle("active");
    });
    const metronome = createCount("main_item_metronome", "連続攻撃回数");
    metronome.openEnded = true;
    metronome.setRange(1, 6, 1);
    $("button.main_item_choose", attackerSide)?.after(metronome);
    const itemLabel = $("button.main_item_choose p", attackerSide);
    const syncMetronome = () => { metronome.hidden = itemLabel?.textContent.trim() !== "メトロノーム"; };
    if (itemLabel) new MutationObserver(syncMetronome).observe(itemLabel, { childList: true, characterData: true, subtree: true });
    syncMetronome();
    countUi = { hits, crits, axel, metronome };
}

function syncMultiHit(reset) {
    if (!countUi) return;
    const { hits, crits, axel } = countUi;
    const move = $("button.main_move_choose p", attackerSide)?.textContent.trim() ?? "";
    const ability = $("button.main_ability_choose p", attackerSide)?.textContent.trim() ?? "";
    const range = window.calcLoaded ? multiHitRange(move, ability) : null;
    const isAxel = move === "トリプルアクセル";
    const weak = $("button.main_move_weak", attackerSide);
    hits.hidden = crits.hidden = !range;
    axel.hidden = !isAxel;
    if (weak) {
        weak.hidden = !!range || isAxel;
        if (weak.hidden) weak.classList.remove("active");
    }
    if (range) {
        hits.setRange(range.min, range.max, reset ? range.def : hits.get() || range.def);
        if (reset) crits.set(0);
    }
    if (isAxel && reset) {
        $$(".main_move_axel_row", axel).forEach((row) => {
            $(".hit", row).classList.add("active");
            $(".crit", row).classList.remove("active");
        });
    }
}

const applyMoveStats = (name, move) => {
    const isSpecial = move.category === "特殊";

    const attackKey = isSpecial ? "c" : "a";
    applyStatRule(
        $("main.attacker"),
        MOVE_STAT_EXCEPTIONS[name] ?? { basestat: [attackKey], evs: [attackKey] },
        MOVE_STAT_EXTRA_EVS[name] ?? [],
    );

    const defenseKey = isSpecial ? "d" : "b";
    applyStatRule(
        $("main.defender"),
        DEFENDER_STAT_EXCEPTIONS[name] ?? { basestat: ["h", defenseKey], evs: ["h", defenseKey] },
        DEFENDER_STAT_EXTRA_EVS[name] ?? [],
    );
};

const selectMove = (name, move) => {
    applyMoveStats(name, move);
    $$(".main_move").forEach((section) => {
        const label = section.querySelector("button.main_move_choose p");
        if (label) label.textContent = name;
        const type = section.querySelector(".main_move_header_info_type");
        if (type && TYPE_BY_JA[move.type]) type.innerHTML = TYPE_BY_JA[move.type].svg;
        const category = section.querySelector(".main_move_header_info_category");
        if (category) {
            category.dataset.category = move.category;
            category.title = move.category;
            if (CATEGORY_SVG[move.category]) category.innerHTML = CATEGORY_SVG[move.category];
        }
        const power = section.querySelector(".main_move_header_info_power");
        if (power) power.textContent = move.power;
        const powerUp = section.querySelector("button.main_move_powerup");
        if (powerUp) {
            powerUp.hidden = !CALC_POWER_UP_MOVES[name];
            powerUp.classList.remove("active");
        }
        syncBurnLock(section.closest("main"));
    });
    const attackerHp = $("main.attacker .main_hpleft");
    if (attackerHp) attackerHp.hidden = !HP_REFERENCE_MOVES.has(name);
    syncMultiHit(true);
};

const selectAbility = (name, _entry, side) => {
    side.querySelectorAll(".main_ability").forEach((section) => {
        const label = section.querySelector("button.main_ability_choose p");
        if (label) label.textContent = name;
        syncAbilityButton(section.closest("main"), { reset: true });
        section.querySelectorAll(".main_ability_header_ex span").forEach((span) => {
            span.classList.toggle("selected", span.textContent.trim() === name);
        });
    });
};

const selectItem = (name, _entry, side) => {
    side.querySelectorAll("button.main_item_choose p").forEach((label) => {
        label.textContent = name;
    });
};

const moveSideHtml = (move) => `
    <div class="modal_search_item_side">
        <div class="modal_search_item_side_type">${TYPE_BY_JA[move.type]?.svg ?? ""}</div>
        <div class="modal_search_item_side_category" data-category="${move.category}" title="${move.category}">${CATEGORY_SVG[move.category] ?? ""}</div>
        <span class="modal_search_item_side_power">${move.power}</span>
    </div>`;

let movesData = {};
const applyInitialMove = (moves) => {
    movesData = moves;
    resolveMoves?.();
    const name = $("button.main_move_choose p")?.textContent.trim();
    if (moves[name]) selectMove(name, moves[name]);
};

const searchModals = [
    { name: "move", kind: "moves", onSelect: selectMove, side: moveSideHtml, onLoad: applyInitialMove },
    { name: "ability", kind: "abilities", onSelect: selectAbility },
    { name: "item", kind: "items", onSelect: selectItem },
];

searchModals.forEach(({ name: modalName, kind, onSelect, side, onLoad }) => {
    const modalEl = $(`section.modal_search${modalName}`);
    const input = modalEl?.querySelector("input");
    if (!modalEl || !input) return;
    const file = `${kind}.json`;
    const close = () => {
        if (modalEl.contains(document.activeElement)) document.activeElement.blur();
        modalEl.classList.remove("is-open");
    };
    $$(`.main_${modalName}_choose`).forEach((openButton) => {
        openButton.addEventListener("click", () => {
            modalOpenerSide = openButton.closest("main") ?? document;
            modalEl.classList.add("is-open");
            orderByUsage();
            input.focus({ preventScroll: true });
            input.select();
        });
    });
    modalEl.querySelectorAll(`.modal_search${modalName}_search_close`).forEach((closeButton) => {
        closeButton.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();
            close();
        });
    });

    const list = document.createElement("div");
    list.className = "modal_search_list";
    modalEl.append(list, usageCredit());
    let data = {};
    let original = [];
    let usageOrder = [];
    let orderKey = "";
    const orderByUsage = () => {
        const name = modalOpenerSide === document ? "" : searchOf(modalOpenerSide)?.getPokemon().name;
        const megaAbility = kind === "abilities" && usageNameOf(name) !== name && toArray(pokemons[name]?.abilities)[0];
        const usage = new Map(megaAbility ? [[megaAbility, 100]] : (usageData?.pokemons[name]?.[kind] ?? []).filter(([key]) => key));
        const keys = [...usage.keys()];
        const index = (item) => (usage.has(item.dataset.name) ? keys.indexOf(item.dataset.name) : keys.length + original.indexOf(item));
        usageOrder = [...original].sort((a, b) => index(a) - index(b));
        filter();
        original.forEach((item) => {
            const label = $(".modal_search_item_usage", item);
            label.textContent = usage.has(item.dataset.name) ? `${usage.get(item.dataset.name)}%` : "";
        });
        if (orderKey !== `${name}:${keys}`) modalEl.scrollTop = 0;
        orderKey = `${name}:${keys}`;
    };

    const filter = () => {
        const items = usageOrder.length === original.length ? usageOrder : original;
        const tiers = filterBySearch(items, (item) => item.dataset.search, input.value);
        list.append(...sortByTier(items, tiers));
    };

    input.addEventListener("input", () => {
        filter();
        modalEl.scrollTop = 0;
    });
    input.addEventListener("keydown", (e) => {
        if (e.key !== "Enter" || e.isComposing) return;
        e.preventDefault();
        list.querySelector(".modal_search_item:not([hidden])")?.click();
    });

    list.addEventListener("click", (e) => {
        const item = e.target.closest(".modal_search_item");
        if (!item) return;
        onSelect(item.dataset.name, data[item.dataset.name], modalOpenerSide);
        close();
    });

    Promise.all([loadJson(file), aliasesReady])
        .then(([json]) => {
            data = json;
            onLoad?.(data);
            list.innerHTML = Object.entries(data).map(([name, entry]) => `
                <div class="modal_search_item" data-name="${name}" data-search="${kind === "moves"
                    ? searchTiers(searchTextOf(kind, name), [entry.type], [entry.category, CATEGORY_READINGS[entry.category]], `=${entry.power}`, [entry.effect ?? ""])
                    : searchTiers(searchTextOf(kind, name), [entry.effect ?? ""])}">
                    <div class="modal_search_item_text">
                        <p class="modal_search_item_name">${name}<span class="modal_search_item_usage"></span></p>
                        <p class="modal_search_item_effect">${entry.effect ?? ""}</p>
                    </div>
                    ${side ? side(entry) : ""}
                </div>`).join("");
            original = $$(".modal_search_item", list);
            filter();
        })
        .catch((err) => console.error(`${file} の読み込みに失敗しました`, err));
});

document.addEventListener("click", (e) => {
    if (e.target !== document.body && e.target !== document.documentElement) return;
    const attacker = $("main.attacker");
    const defender = $("main.defender");
    if (!attacker || !defender) return;
    const gapLeft = attacker.getBoundingClientRect().right;
    const gapRight = defender.getBoundingClientRect().left;
    if (e.clientX < gapLeft || e.clientX > gapRight) return;
    const toDefender = (gapLeft + gapRight) / 2 > window.innerWidth / 2;
    document.body.scrollTo({ left: toDefender ? document.body.scrollWidth : 0, behavior: "smooth" });
});

const modalSections = $$("section.modal_searchmove, section.modal_searchability, section.modal_searchitem, section.modal_environment_container, section.detail, section.speed, aside.history");
const syncScrollLock = () => {
    const locked = [...modalSections].some((section) => section.classList.contains("is-open"));
    document.documentElement.classList.toggle("is-scroll-locked", locked);
    pushNativeState();
};
const scrollLockObserver = new MutationObserver(syncScrollLock);
modalSections.forEach((section) => scrollLockObserver.observe(section, { attributes: true, attributeFilter: ["class"] }));
syncScrollLock();

document.addEventListener("touchmove", (e) => {
    if (!document.documentElement.classList.contains("is-scroll-locked")) return;
    const scrollable = e.target.closest("section.modal_searchmove, section.modal_searchability, section.modal_searchitem, section.detail, section.speed, aside.history");
    if (scrollable?.classList.contains("is-open")) return;
    e.preventDefault();
}, { passive: false });

function bindSheetDrag(sheet, close, ignore = "") {
    let drag = null;
    sheet.addEventListener("touchstart", (e) => {
        const touch = e.touches[0];
        drag = e.touches.length === 1 && !(ignore && e.target.closest(ignore))
            ? { startX: touch.clientX, startY: touch.clientY, lastY: touch.clientY, baseY: null, dy: 0 }
            : null;
    }, { passive: true });
    sheet.addEventListener("touchmove", (e) => {
        if (!drag) return;
        const { clientX: x, clientY: y } = e.touches[0];
        if (drag.baseY === null) {
            if (Math.abs(x - drag.startX) < 4 && Math.abs(y - drag.startY) < 4) return;
            if (Math.abs(x - drag.startX) > Math.abs(y - drag.startY)) {
                drag = null;
                return;
            }
            if (sheet.scrollTop <= 0 && y > drag.lastY) {
                drag.baseY = drag.lastY;
                sheet.style.transition = "none";
            }
            drag.lastY = y;
            if (drag.baseY === null) return;
        }
        drag.dy = Math.max(0, y - drag.baseY);
        if (e.cancelable) e.preventDefault();
        sheet.style.translate = `0 ${drag.dy}px`;
    }, { passive: false });
    const endDrag = () => {
        if (drag && drag.baseY !== null) {
            sheet.style.transition = "";
            sheet.style.translate = "";
            if (drag.dy > Math.min(160, sheet.clientHeight * 0.25)) close();
        }
        drag = null;
    };
    sheet.addEventListener("touchend", endDrag);
    sheet.addEventListener("touchcancel", endDrag);
}

const detail = $("section.detail");
const resultCard = $(".card_result");

if (detail && resultCard) {
    const closeDetail = () => detail.classList.remove("is-open");
    const openDetailSheet = () => {
        closeOtherSidesChoose();
        openDetail();
        detail.scrollTop = 0;
        detail.classList.add("is-open");
    };
    resultCard.addEventListener("click", openDetailSheet);
    detail.querySelector("header")?.addEventListener("click", closeDetail);

    bindSheetDrag(detail, closeDetail, ".detail_overview_flow_range");
}

const environment = $("section.modal_environment_container");
const environmentPanel = environment?.querySelector(".modal_environment");

if (environment && environmentPanel) {
    environmentPanel.addEventListener("click", (e) => {
        if (e.target !== environmentPanel) return;
        if (e.clientY < environmentPanel.getBoundingClientRect().bottom) return;
        environment.classList.toggle("is-open");
    });
    environment.addEventListener("click", (e) => {
        if (e.target === environment) environment.classList.remove("is-open");
    });

    const ENVIRONMENT_LABELS = {
        weather: { none: "天候", sun: "にほんばれ", rain: "あめ", sand: "すなあらし", snow: "ゆき" },
        field: { none: "フィールド", electric: "エレキフィールド", grass: "グラスフィールド", psycho: "サイコフィールド", mist: "ミストフィールド" },
    };

    environment.querySelectorAll(".modal_environment_weather_select, .modal_environment_field_select").forEach((select) => {
        const buttons = [...select.querySelectorAll("button")];
        const kind = select.classList.contains("modal_environment_weather_select") ? "weather" : "field";
        const update = () => {
            const index = Math.max(0, buttons.findIndex((b) => b.classList.contains("selected")));
            select.style.setProperty("--selected", index);
            const key = [...(buttons[index]?.classList ?? [])].map((c) => c.split("_").pop()).find((k) => k in ENVIRONMENT_LABELS[kind]);
            environmentPanel.dataset[kind] = ENVIRONMENT_LABELS[kind][key ?? "none"];
            const flash = $(`.${kind}_flash`);
            if (flash) flash.className = key && key !== "none" ? `${kind}_flash ${key}` : `${kind}_flash`;
        };
        const none = buttons.find((b) => [...b.classList].some((c) => c.endsWith("_none"))) ?? buttons[0];
        buttons.forEach((button) => {
            button.addEventListener("click", () => {
                const target = button.classList.contains("selected") ? none : button;
                buttons.forEach((b) => b.classList.toggle("selected", b === target));
                update();
                speedAbilityOverride.attacker = speedAbilityOverride.defender = null;
            });
        });
        update();
    });

    const PULL_RATIO = 0.35;
    let pull = null;

    const setPullProgress = (progress) => {
        const height = environmentPanel.offsetHeight;
        const p = Math.min(1, Math.max(0, progress));
        environmentPanel.style.translate = `0 ${(p - 1) * height}px`;
        environment.style.backgroundColor = `rgba(0, 0, 0, ${0.4 * p})`;
        return p;
    };
    const endPull = (open) => {
        environmentPanel.style.transition = "";
        environmentPanel.style.translate = "";
        environment.style.transition = "";
        environment.style.backgroundColor = "";
        environment.classList.toggle("is-open", open);
        pull = null;
    };
    const pullMode = (target) => {
        if (isNative) return null;
        if (environment.classList.contains("is-open")) return "close";
        if (window.scrollY > 0) return null;
        if (document.body.classList.contains("is-choose-open")) return null;
        if ($("section.is-open")) return null;
        return target.closest(".main_evs_range, .main_hpleft_range, select, input, .modal_environment") ? null : "open";
    };

    document.addEventListener("touchstart", (e) => {
        const mode = e.touches.length === 1 ? pullMode(e.target) : null;
        if (!mode) return;
        const touch = e.touches[0];
        pull = { mode, startX: touch.clientX, startY: touch.clientY, active: false, progress: mode === "open" ? 0 : 1 };
    }, { passive: true });

    document.addEventListener("touchmove", (e) => {
        if (!pull) return;
        const touch = e.touches[0];
        const dx = touch.clientX - pull.startX;
        const dy = touch.clientY - pull.startY;
        if (!pull.active) {
            if (Math.abs(dx) < 8 && Math.abs(dy) < 8) return;
            const rightDirection = pull.mode === "open" ? dy > 0 && window.scrollY <= 0 : dy < 0;
            if (!rightDirection || Math.abs(dx) > Math.abs(dy)) {
                pull = null;
                return;
            }
            pull.active = true;
            environmentPanel.style.transition = "none";
            environment.style.transition = "none";
        }
        e.preventDefault();
        const height = environmentPanel.offsetHeight;
        pull.progress = setPullProgress((pull.mode === "open" ? 0 : 1) + dy / height);
    }, { passive: false });

    const finishPull = () => {
        if (!pull) return;
        if (!pull.active) {
            pull = null;
            return;
        }
        endPull(pull.mode === "open" ? pull.progress >= PULL_RATIO : pull.progress > 1 - PULL_RATIO);
    };
    document.addEventListener("touchend", finishPull);
    document.addEventListener("touchcancel", () => {
        if (pull?.active) endPull(pull.mode === "close");
        pull = null;
    });
}

const changeThem = $("button.changethem");
const supportsScrollTimeline = CSS.supports("animation-timeline: --a");

const positionChangeThem = () => {
    const attacker = $("main.attacker");
    const defender = $("main.defender");
    if (!changeThem || !attacker || !defender) return;
    const scrollLeft = document.body.scrollLeft;
    const center = (attacker.getBoundingClientRect().right + defender.getBoundingClientRect().left) / 2 + scrollLeft;
    const baseLeft = center - changeThem.offsetWidth / 2;
    if (supportsScrollTimeline) {
        changeThem.style.setProperty("--changethem-left", `${baseLeft}px`);
        document.body.style.setProperty("--pages-scroll-max", `${document.body.scrollWidth - document.body.clientWidth}px`);
    } else {
        changeThem.style.setProperty("--changethem-left", `${baseLeft - scrollLeft}px`);
    }
};

if (changeThem) {
    positionChangeThem();
    window.addEventListener("resize", positionChangeThem);
    window.addEventListener("load", positionChangeThem);
    if (!supportsScrollTimeline) document.body.addEventListener("scroll", positionChangeThem, { passive: true });

    let changeThemTurns = 0;
    changeThem.addEventListener("click", () => {
        changeThemTurns += 1;
        changeThem.style.setProperty("--changethem-turn", `${changeThemTurns * 360}deg`);

        changeThem.animate([
            { scale: "1 1", easing: "ease-out" },
            { scale: "1.16 .82", offset: .25, easing: "ease-in-out" },
            { scale: ".92 1.1", offset: .5, easing: "ease-in-out" },
            { scale: "1.04 .96", offset: .72, easing: "ease-in-out" },
            { scale: "1 1" },
        ], { duration: 550 });
    });
}

const sideRole = (side) => (side.classList.contains("attacker") ? "attacker" : "defender");

const snapshotSide = (side) => {
    const role = sideRole(side);
    const search = searchOf(side);
    const state = {};
    if (search) state.pokemon = search.getPokemon();

    side.querySelectorAll(".main_evs").forEach((section) => {
        const key = evsKeyOf(section);
        if (!key) return;
        state[`evs:${key}`] = {
            points: pointsOf(section),
            nature: [...(section.querySelector(".main_evs_nature > .selected")?.classList ?? [])].find((c) => c.startsWith("main_evs_nature_")),
            rank: section.querySelector(".main_evs_ranks select")?.selectedIndex,
        };
    });

    const abilityButton = side.querySelector("button.main_ability_on");
    const wasOn = abilityButton?.dataset.wasOn;
    state.ability = {
        name: side.querySelector("button.main_ability_choose p")?.textContent.trim(),
        on: wasOn !== undefined ? wasOn === "1" : !!abilityButton?.classList.contains("active"),
        toggleable: !!abilityButton && !abilityButton.hidden && (!abilityButton.disabled || wasOn !== undefined),
    };
    state.item = side.querySelector("button.main_item_choose p")?.textContent.trim();
    const hp = side.querySelector(".main_hpleft");
    if (hp?.dataset.max) state.hp = { now: Number(hp.dataset.now), max: Number(hp.dataset.max) };

    state[`${role}:conditions`] = [...side.querySelectorAll("button.main_condition_item.active")].map((b) => b.textContent.trim());
    if (role === "attacker") {
        state["attacker:weak"] = !!side.querySelector("button.main_move_weak")?.classList.contains("active");
        state["attacker:powerup"] = !!side.querySelector("button.main_move_powerup")?.classList.contains("active");
        state["attacker:move"] = side.querySelector("button.main_move_choose p")?.textContent.trim();
        if (countUi) {
            state["attacker:counts"] = {
                hits: countUi.hits.hidden ? null : countUi.hits.get(),
                crits: countUi.crits.hidden ? null : countUi.crits.get(),
                axel: $$(".main_move_axel_row", countUi.axel).map((row) => [$(".hit", row).classList.contains("active"), $(".crit", row).classList.contains("active")]),
                metronome: countUi.metronome.get(),
            };
        }
    }
    return state;
};

const restoreSideStages = (side, slot, defaults) => {
    const role = sideRole(side);
    const get = (key) => slot[key] ?? defaults[key];
    const search = searchOf(side);
    const pokemonStage = () => {
        if (search && slot.pokemon?.name) search.setPokemon(slot.pokemon);
    };
    const moveStage = () => {
        side.querySelector("button.main_move_weak")?.classList.toggle("active", !!get("attacker:weak"));
        const move = get("attacker:move");
        if (move && movesData[move]) selectMove(move, movesData[move]);
        const powerUp = side.querySelector("button.main_move_powerup");
        if (powerUp && !powerUp.hidden) powerUp.classList.toggle("active", !!get("attacker:powerup"));
    };
    const evsStage = () => side.querySelectorAll(".main_evs").forEach((section) => {
        const key = evsKeyOf(section);
        const value = key && get(`evs:${key}`);
        if (!value) return;
        section.querySelector(".main_evs_range")?.setEvsValue?.(value.points);
        if (value.nature) {
            section.querySelectorAll(".main_evs_nature > div").forEach((div) => {
                div.classList.toggle("selected", div.classList.contains(value.nature));
            });
        }
        const select = section.querySelector(".main_evs_ranks select");
        if (select && value.rank !== undefined && select.selectedIndex !== value.rank) {
            select.selectedIndex = value.rank;
            select.dispatchEvent(new Event("change", { bubbles: true }));
        }
    });
    const abilityStage = () => {
        const ability = get("ability");
        if (ability?.name) {
            const label = side.querySelector("button.main_ability_choose p");
            if (label) label.textContent = ability.name;
            side.querySelectorAll(".main_ability_header_ex span").forEach((span) => {
                span.classList.toggle("selected", span.textContent.trim() === ability.name);
            });
            side.querySelector("button.main_ability_on")?.classList.toggle("active", !!ability.on);
            syncAbilityButton(side, { reset: !ability.toggleable });
        }
    };
    const itemStage = () => {
        const item = get("item");
        const itemLabel = side.querySelector("button.main_item_choose p");
        if (item && itemLabel) itemLabel.textContent = item;
    };
    const conditionStage = () => {
        const conditions = get(`${role}:conditions`) ?? [];
        side.querySelectorAll("button.main_condition_item").forEach((button) => {
            button.classList.toggle("active", conditions.includes(button.textContent.trim()));
        });
        if (role === "attacker") {
            syncBurnLock(side);
            const counts = slot["attacker:counts"];
            if (counts && countUi) {
                if (counts.hits !== null && !countUi.hits.hidden) countUi.hits.set(counts.hits);
                if (counts.crits !== null && !countUi.crits.hidden) countUi.crits.set(counts.crits);
                $$(".main_move_axel_row", countUi.axel).forEach((row, i) => {
                    $(".hit", row).classList.toggle("active", counts.axel[i]?.[0] ?? true);
                    $(".crit", row).classList.toggle("active", counts.axel[i]?.[1] ?? false);
                });
                countUi.metronome.set(counts.metronome);
            }
        }
        const hp = get("hp");
        const hpBox = side.querySelector(".main_hpleft");
        if (hp && hpBox) {
            hpBox.dataset.now = hp.now;
            hpBox.dataset.max = hp.max;
        }
        updateRealStatsIn(side);
    };
    return [
        ["ポケモン", pokemonStage],
        ...(role === "attacker" ? [["わざ", moveStage]] : []),
        ["のうりょくポイント", evsStage],
        ["とくせい", abilityStage],
        ["もちもの", itemStage],
        ["じょうたい", conditionStage],
    ];
};

const restoreSide = (side, slot, defaults) => restoreSideStages(side, slot, defaults).forEach(([, run]) => run());

const sharedPokemon = {};

const rememberShared = (snapshot, atk = null) => {
    const name = snapshot?.pokemon?.name;
    if (!name) return;
    const entry = (sharedPokemon[name] ??= { evs: {} });
    Object.entries(snapshot).forEach(([key, value]) => {
        if (key.startsWith("evs:") && key !== "evs:vsa") entry.evs[key] = { points: value.points, nature: value.nature };
    });
    if (snapshot.ability?.name) entry.ability = snapshot.ability.name;
    if (snapshot.item) entry.item = snapshot.item;
    if (atk) entry.atk = atk;
};

const withShared = (snapshot) => {
    const shared = sharedPokemon[snapshot?.pokemon?.name];
    if (!shared) return snapshot;
    const merged = { ...snapshot };
    Object.entries(shared.evs).forEach(([key, value]) => {
        if (merged[key]) merged[key] = { ...merged[key], ...value };
    });
    if (shared.ability && merged.ability?.name !== shared.ability) merged.ability = { name: shared.ability, on: false, toggleable: false };
    if (shared.item) merged.item = shared.item;
    return merged;
};

const roleDefaults = {};
const swapSlots = [{}, {}];
const slotOfRole = { attacker: 0, defender: 1 };

$$("main.attacker, main.defender").forEach((side) => {
    roleDefaults[sideRole(side)] = snapshotSide(side);
});

const swapAttackerDefender = () => {
    const attacker = $("main.attacker");
    const defender = $("main.defender");
    if (!attacker || !defender) return;
    closeOtherSidesChoose();

    Object.assign(swapSlots[slotOfRole.attacker], snapshotSide(attacker));
    Object.assign(swapSlots[slotOfRole.defender], snapshotSide(defender));
    rememberShared(swapSlots[slotOfRole.attacker]);
    rememberShared(swapSlots[slotOfRole.defender]);
    [slotOfRole.attacker, slotOfRole.defender] = [slotOfRole.defender, slotOfRole.attacker];
    restoreSide(attacker, withShared(swapSlots[slotOfRole.attacker]), roleDefaults.attacker);
    restoreSide(defender, withShared(swapSlots[slotOfRole.defender]), roleDefaults.defender);

    const top = topAttackMove(searchOf(attacker)?.getPokemon().name);
    if (top) selectMove(top, movesData[top]);
    const move = attacker.querySelector("button.main_move_choose p")?.textContent.trim();
    if (movesData[move]) applyMoveStats(move, movesData[move]);
};

changeThem?.addEventListener("click", swapAttackerDefender);

const orderMain = $(".order_main");
const orderAdd = orderMain?.querySelector(".order_main_item_add");
const orderTemplates = {};
const orderTabs = [];
let orderActive = 0;

orderMain?.querySelectorAll(".order_main_item").forEach((item) => {
    const kind = ["attack", "damage", "heel"].find((k) => item.classList.contains(k));
    if (kind && !orderTemplates[kind]) {
        const template = item.cloneNode(true);
        template.classList.remove("active");
        orderTemplates[kind] = template;
    }
    item.remove();
});

const readEnvironment = () => ["weather", "field"].map((kind) => {
    const button = $(`.modal_environment_${kind}_select button.selected`);
    return [...(button?.classList ?? [])].find((c) => c.startsWith(`modal_environment_${kind}_select_`));
});
const restoreEnvironment = (classes) => {
    classes?.forEach((cls) => {
        const button = cls && $(`button.${cls}`);
        if (button && !button.classList.contains("selected")) button.click();
    });
};

let defRankBonus = 0;
const defRankSelects = () => $$("main.defender .main_evs").map((section) => [evsKeyOf(section), $(".main_evs_ranks select", section)]).filter(([key, select]) => key && select);
const readDefRanks = () => Object.fromEntries(defRankSelects().map(([key, select]) => [key, 6 - select.selectedIndex - (key === "b" ? defRankBonus : 0)]));
const writeDefRanks = (ranks, bonus = defRankBonus) => {
    const base = { ...readDefRanks(), ...ranks };
    defRankBonus = bonus;
    defRankSelects().forEach(([key, select]) => {
        const index = 6 - Math.max(-6, Math.min(6, base[key] + (key === "b" ? bonus : 0)));
        if (select.selectedIndex === index) return;
        select.selectedIndex = index;
        select.dispatchEvent(new Event("change", { bubbles: true }));
    });
};
const multiscaleButton = () => $("main.defender button.main_ability_on");
const multiscaleUserOn = () => {
    const button = multiscaleButton();
    return button?.dataset.wasOn !== undefined ? button.dataset.wasOn === "1" : !!button?.classList.contains("active");
};
const lockMultiscale = (lock, applicable) => {
    const button = multiscaleButton();
    if (!button) return false;
    const locked = button.dataset.wasOn !== undefined;
    if (!applicable) {
        if (locked) delete button.dataset.wasOn;
        return false;
    }
    if (lock === locked) return false;
    if (lock) {
        button.dataset.wasOn = button.classList.contains("active") ? "1" : "0";
        button.classList.remove("active");
        button.disabled = true;
    } else {
        button.classList.toggle("active", button.dataset.wasOn === "1");
        delete button.dataset.wasOn;
        button.disabled = false;
    }
    return true;
};

const syncDefRankBonus = (bonus) => {
    if (bonus === defRankBonus) return false;
    writeDefRanks({}, bonus);
    return true;
};
document.addEventListener("defender-reset", () => {
    defRankBonus = 0;
    orderTabs.forEach((tab) => { delete tab.defRanks; });
});

const saveActiveTab = () => {
    const tab = orderTabs[orderActive];
    const attacker = $("main.attacker");
    if (!tab || tab.kind !== "attack" || !attacker) return;
    tab.defRanks = readDefRanks();
    tab.snapshot = snapshotSide(attacker);
    tab.environment = readEnvironment();
    tab.calcInput = captureCalcInput();
    rememberShared(tab.snapshot, tab.calcInput?.atk);
};

const loadTabStages = (tab) => {
    const attacker = $("main.attacker");
    if (!tab || tab.kind !== "attack" || !tab.snapshot || !attacker) return [];
    return [
        ...restoreSideStages(attacker, withShared(tab.snapshot), roleDefaults.attacker),
        ["天候・フィールド", () => {
            if (tab.defRanks) writeDefRanks(tab.defRanks);
            restoreEnvironment(tab.environment);
            const move = attacker.querySelector("button.main_move_choose p")?.textContent.trim();
            if (movesData[move]) applyMoveStats(move, movesData[move]);
        }],
    ];
};

const loadTab = (tab) => loadTabStages(tab).forEach(([, run]) => run());

let orderTabSeq = 0;
const newOrderTab = (kind) => ({ kind, id: ++orderTabSeq });

const renderOrderTabs = () => {
    if (!orderMain) return;
    const before = new Map([...orderMain.querySelectorAll(".order_main_item")].map((item) => [item.dataset.id, item.getBoundingClientRect().left]));
    orderMain.querySelectorAll(".order_main_item").forEach((item) => item.remove());
    orderTabs.forEach((tab, i) => {
        const item = orderTemplates[tab.kind]?.cloneNode(true);
        if (!item) return;
        item.dataset.index = i;
        item.dataset.id = tab.id;
        item.classList.toggle("active", i === orderActive);
        const remove = item.querySelector(".order_main_item_delete");
        if (remove) remove.hidden = orderTabs.length <= 1;
        orderMain.insertBefore(item, orderAdd);
    });
    orderMain.querySelector(".order_main_item.active")?.scrollIntoView({ block: "nearest", inline: "nearest" });

    orderMain.querySelectorAll(".order_main_item").forEach((item) => {
        const left = before.get(item.dataset.id);
        if (left === undefined) {
            if (before.size) item.animate([{ opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1 }], { duration: 220, easing: "ease-out" });
            return;
        }
        const dx = left - item.getBoundingClientRect().left;
        if (dx) item.animate([{ translate: `${dx}px 0` }, { translate: "0 0" }], { duration: 260, easing: "cubic-bezier(.2, .8, .2, 1)" });
    });

    const leftButton = $(".order_left");
    const rightButton = $(".order_right");
    if (leftButton) leftButton.disabled = orderActive <= 0;
    if (rightButton) rightButton.disabled = orderActive >= orderTabs.length - 1;

    syncConstantPanel();
    if (window.calcLoaded) scheduleCalc();
};

const activateTab = (index) => {
    if (index === orderActive || !orderTabs[index]) return;
    saveActiveTab();
    orderActive = index;
    loadTab(orderTabs[index]);
    renderOrderTabs();
};

const addTab = (kind) => {
    saveActiveTab();
    const tab = newOrderTab(kind);
    if (kind === "attack") {
        const attacker = $("main.attacker");
        tab.defRanks = readDefRanks();
        tab.snapshot = snapshotSide(attacker);
        tab.environment = readEnvironment();
        tab.calcInput = captureCalcInput();
        rememberShared(tab.snapshot, tab.calcInput?.atk);
    } else {
        tab.constant = newConstantState();
    }
    orderTabs.splice(orderActive + 1, 0, tab);
    orderActive += 1;
    renderOrderTabs();
};

const removeTab = (index) => {
    if (orderTabs.length <= 1 || !orderTabs[index]) return;
    if (index === orderActive) {
        orderTabs.splice(index, 1);
        orderActive = Math.min(index, orderTabs.length - 1);
        loadTab(orderTabs[orderActive]);
    } else {
        orderTabs.splice(index, 1);
        if (index < orderActive) orderActive -= 1;
    }
    renderOrderTabs();
};

const moveActiveTab = (step) => {
    const to = orderActive + step;
    if (to < 0 || to >= orderTabs.length) return;
    [orderTabs[orderActive], orderTabs[to]] = [orderTabs[to], orderTabs[orderActive]];
    orderActive = to;
    renderOrderTabs();
};

const CONSTANT_RATIOS = {
    damage: [
        { key: "1/32", ratio: [1, 32], mode: "floor", ex: ["ステルスロック（いわ1/4倍）"] },
        { key: "1/16", ratio: [1, 16], mode: "floor", ex: ["やけど", "すなあらし", "ステルスロック（いわ1/2倍）"] },
        { key: "1/10", ratio: [1, 10], mode: "floor", ex: ["いのちのたま"] },
        { key: "1/8", ratio: [1, 8], mode: "floor", ex: ["ステルスロック", "どく", "やどりぎのタネ", "まきつく・しめつける等", "まきびし（1回）", "しおづけ", "くっつきバリ", "さめはだ", "てつのトゲ", "かんそうはだ（はれ）", "サンパワー", "ナイトメア"] },
        { key: "1/6", ratio: [1, 6], mode: "floor", ex: ["ゴツゴツメット", "まきびし（2回）"] },
        { key: "1/4r", label: "1/4（四捨五入）", ratio: [1, 4], mode: "round", ex: ["わるあがき"] },
        { key: "1/4f", label: "1/4（切り捨て）", ratio: [1, 4], mode: "floor", ex: ["ステルスロック（いわ2倍）", "まきびし（3回）", "のろい", "あくむ", "しおづけ（みず・はがね）", "みがわり"] },
        { key: "1/2c", label: "1/2（切り上げ）", ratio: [1, 2], mode: "ceil", ex: ["てっていこうせん", "ビックリヘッド", "クロロブラスト"] },
    ],
    heel: [
        { key: "1/16f", label: "1/16（切り捨て）", ratio: [1, 16], mode: "floor", ex: ["たべのこし", "くろいヘドロ", "アクアリング", "ねをはる", "グラスフィールド", "あめうけざら", "アイスボディ"] },
        { key: "1/8f", label: "1/8（切り捨て）", ratio: [1, 8], mode: "floor", ex: ["ポイズンヒール", "かんそうはだ（あめ）"] },
        { key: "1/4f", label: "1/4（切り捨て）", ratio: [1, 4], mode: "floor", ex: ["オボンのみ", "ちくでん", "ちょすい", "どしょく", "かんそうはだ（みず技）"] },
        { key: "1/4p", label: "1/4（五捨五超入）", ratio: [1, 4], mode: "poke", ex: ["いのちのしずく", "ジャングルヒール", "あさのひざし・つきのひかり・こうごうせい（はれ以外の天気）"] },
        { key: "1/4r", label: "1/4（四捨五入）", ratio: [1, 4], mode: "round", ex: [] },
        { key: "1/3f", label: "1/3（切り捨て）", ratio: [1, 3], mode: "floor", ex: ["さいせいりょく", "フィラのみ等"] },
        { key: "1/2f", label: "1/2（切り捨て）", ratio: [1, 2], mode: "floor", ex: ["ねがいごと"] },
        { key: "1/2p", label: "1/2（五捨五超入）", ratio: [1, 2], mode: "poke", ex: ["じこさいせい", "はねやすめ", "タマゴうみ", "ミルクのみ", "なまける", "かいふくしれい", "すなあつめ", "あさのひざし・つきのひかり・こうごうせい"] },
        { key: "1/2r", label: "1/2（四捨五入）", ratio: [1, 2], mode: "round", ex: [] },
        { key: "2/3p", label: "2/3（五捨五超入）", ratio: [2, 3], mode: "poke", ex: ["あさのひざし・つきのひかり・こうごうせい（はれ）", "すなあつめ（すなあらし）"] },
    ],
};
const CONSTANT_KINDS = {
    damage: { title: "定数ダメージ", unit: "ダメージ", fixed: 50, fixedEx: "ちきゅうなげ・ナイトヘッド", sections: { ratio: "割合", toxic: "もうどく", fixed: "固定" } },
    heel: { title: "定数回復", unit: "回復", fixed: 10, fixedEx: "オレンのみ", sections: { ratio: "割合", fixed: "固定" } },
};
const TOXIC_TURNS = Array.from({ length: 15 }, (_, i) => i + 1);

const roundBy = (mode, value, [n, d]) => (mode === "poke"
    ? Math.floor((Math.floor(value * Math.floor((n * 4096) / d)) + 2047) / 4096)
    : Math[mode]((value * n) / d));
const ratioAmount = (max, def) => Math.max(1, roundBy(def.mode, max, def.ratio));
const toxicAmount = (max, turn) => Math.max(1, Math.floor((max * turn) / 16));
const newConstantState = () => ({ section: "ratio", ratios: {}, toxic: {}, fixed: 0, inputs: [] });

function constantBreakdown(tab, max) {
    const state = tab.constant ?? newConstantState();
    const kind = CONSTANT_KINDS[tab.kind];
    const parts = [];
    const add = (label, count, amount) => count > 0 && amount > 0 && parts.push({ label: `${label}×${count}`, amount: amount * count });
    CONSTANT_RATIOS[tab.kind].forEach((def) => add(def.label ?? def.key, state.ratios[def.key], ratioAmount(max, def)));
    if (tab.kind === "damage") TOXIC_TURNS.forEach((turn) => add(`もうどく${turn}T`, state.toxic[turn], toxicAmount(max, turn)));
    add(kind.fixed, state.fixed, kind.fixed);
    state.inputs.forEach(({ value, count }) => add(value, count, value));
    return { parts, total: parts.reduce((sum, p) => sum + p.amount, 0) };
}

const defenderMaxHp = () => parseInt($("main.defender .main_evs_h .main_evs_header_value")?.textContent, 10) || 1;
const constantCount = (state, kind, key) => (kind === "fixed" ? state.fixed : kind === "inputs" ? state.inputs[key].count : state[kind][key] ?? 0);
const counterHtml = (kind, key, count) => `<div class="main_constant_counter" data-kind="${kind}" data-key="${key}">
    <button class="minus"${count ? "" : " disabled"}><svg viewBox="0 0 24 24"><path d="M5 12h14"/></svg></button>
    <span>${count}</span>
    <button class="plus"><svg viewBox="0 0 24 24"><path d="M5 12h14"/><path d="M12 5v14"/></svg></button>
</div>`;
const constantRow = (state, kind, key, name, ex) => {
    const count = constantCount(state, kind, key);
    return `<div class="main_constant_item${count ? " is-on" : ""}">
        <div class="main_constant_item_text">
            <p class="main_constant_item_name">${name}</p>
            ${ex === undefined ? "" : `<p class="main_constant_item_ex">${ex || "-"}</p>`}
        </div>
        ${counterHtml(kind, key, count)}
    </div>`;
};

const constantPanel = document.createElement("div");
constantPanel.className = "main_constant";
$("main.attacker")?.appendChild(constantPanel);

function renderConstantPanel() {
    const tab = orderTabs[orderActive];
    if (!tab || tab.kind === "attack") return;
    const state = (tab.constant ??= newConstantState());
    const kind = CONSTANT_KINDS[tab.kind];
    const max = defenderMaxHp();
    const amount = (value) => `<span>${value}</span>`;
    const sections = {
        ratio: CONSTANT_RATIOS[tab.kind].map((def) => constantRow(state, "ratios", def.key, `${def.label ?? def.key}${amount(ratioAmount(max, def))}`, def.ex.join("・"))).join(""),
        toxic: TOXIC_TURNS.map((turn) => constantRow(state, "toxic", turn, `${turn}ターン目${amount(toxicAmount(max, turn))}`)).join(""),
        fixed: constantRow(state, "fixed", "", `${kind.fixed}${kind.unit}`, kind.fixedEx)
            + state.inputs.map((input, i) => `<div class="main_constant_item main_constant_input${input.count ? " is-on" : ""}">
                <input type="number" min="0" inputmode="numeric" value="${input.value || ""}" data-input="${i}">
                <p class="main_constant_unit">${kind.unit}</p>
                ${counterHtml("inputs", i, input.count)}
            </div>`).join("")
            + `<button class="main_constant_add">＋ ${kind.unit}量を追加</button>`,
    };
    constantPanel.dataset.kind = tab.kind;
    constantPanel.dataset.max = max;
    constantPanel.innerHTML = `<div class="main_constant_title"><p>${kind.title}</p><p class="main_constant_total"></p></div>
        <div class="main_constant_tabs" style="--count: ${Object.keys(kind.sections).length}; --index: ${Object.keys(kind.sections).indexOf(state.section)}">${Object.entries(kind.sections).map(([key, label]) => `<button data-section="${key}"${key === state.section ? ' class="active"' : ""}>${label}</button>`).join("")}</div>
        ${Object.keys(kind.sections).map((key) => `<div class="main_constant_section"${key === state.section ? "" : " hidden"}>${sections[key]}</div>`).join("")}`;
    renderConstantTotal();
}

function refreshConstantPanel() {
    if (orderTabs[orderActive]?.constant && constantPanel.dataset.max !== String(defenderMaxHp())) renderConstantPanel();
    else renderConstantTotal();
}

function renderConstantTotal() {
    const tab = orderTabs[orderActive];
    const total = constantPanel.querySelector(".main_constant_total");
    if (tab?.constant && total) total.textContent = `${tab.kind === "damage" ? "-" : "+"}${constantBreakdown(tab, defenderMaxHp()).total}`;
}

constantPanel.addEventListener("click", (e) => {
    const state = orderTabs[orderActive]?.constant;
    if (!state) return;
    const section = e.target.closest(".main_constant_tabs button");
    if (section) {
        state.section = section.dataset.section;
        const buttons = $$(".main_constant_tabs button", constantPanel);
        const index = buttons.indexOf(section);
        section.parentElement.style.setProperty("--index", index);
        buttons.forEach((button) => button.classList.toggle("active", button === section));
        $$(".main_constant_section", constantPanel).forEach((el, i) => { el.hidden = i !== index; });
        return;
    }
    if (e.target.closest(".main_constant_add")) {
        state.inputs.push({ value: 0, count: 0 });
        renderConstantPanel();
        constantPanel.querySelector(".main_constant_input:last-of-type input")?.focus();
        return;
    }
    const counter = e.target.closest(".main_constant_counter");
    if (counter && e.target.closest("button")) haptic("light");
    const step = e.target.closest(".plus") ? 1 : e.target.closest(".minus") ? -1 : 0;
    if (!counter || !step) return;
    const { kind, key } = counter.dataset;
    const count = Math.max(0, constantCount(state, kind, key) + step);
    if (kind === "fixed") state.fixed = count;
    else if (kind === "inputs") state.inputs[key].count = count;
    else state[kind][key] = count;
    counter.querySelector("span").textContent = count;
    counter.querySelector(".minus").disabled = !count;
    counter.closest(".main_constant_item").classList.toggle("is-on", count > 0);
    renderConstantTotal();
    scheduleCalc();
});
constantPanel.addEventListener("input", (e) => {
    const input = e.target.closest("input[data-input]");
    const state = orderTabs[orderActive]?.constant;
    if (!input || !state) return;
    state.inputs[input.dataset.input].value = Math.max(0, parseInt(input.value, 10) || 0);
    renderConstantTotal();
    scheduleCalc();
});

const syncConstantPanel = () => {
    const constant = orderTabs[orderActive]?.kind !== "attack";
    $("main.attacker")?.classList.toggle("is-constant", constant);
    if (changeThem) changeThem.hidden = constant;
    if (constant) renderConstantPanel();
};

if (orderMain) {
    orderTabs.push(newOrderTab("attack"));
    renderOrderTabs();

    orderMain.addEventListener("click", (e) => {
        const item = e.target.closest(".order_main_item");
        if (!item) return;
        const index = Number(item.dataset.index);
        if (e.target.closest(".order_main_item_delete")) removeTab(index);
        else activateTab(index);
    });
    $(".order_left")?.addEventListener("click", () => moveActiveTab(-1));
    $(".order_right")?.addEventListener("click", () => moveActiveTab(1));

    orderAdd?.addEventListener("click", () => {
        closeOtherSidesChoose();
        orderChoose?.classList.add("active");
        syncChooseOverlay();
    });
    orderChoose?.addEventListener("click", (e) => {
        if (e.target.closest(".order_choose_close")) {
            closeOrderChoose();
            return;
        }
        const item = e.target.closest(".order_choose_item");
        if (!item) return;
        addTab(item.dataset.kind);
        closeOrderChoose();
    });
}

const toBase64Url = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const fromBase64Url = (text) => Uint8Array.from(atob(text.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
const pipeBytes = async (bytes, stream) => new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(stream)).arrayBuffer());

const encodeShare = async (data) => toBase64Url(await pipeBytes(new TextEncoder().encode(JSON.stringify(data)), new CompressionStream("deflate-raw")));
const decodeShare = async (text) => JSON.parse(new TextDecoder().decode(await pipeBytes(fromBase64Url(text), new DecompressionStream("deflate-raw"))));

const EVS_ORDER = ["h", "a", "vsa", "b", "c", "d", "s"];
const NATURE_MARK = { 9: "-", 11: "+" };
const CONSTANT_CODES = { damage: "d", heel: "h" };
const DEFAULT_COUNTS = [-1, -1, 21, 1];

const trimTail = (list) => {
    while (list.length && !list[list.length - 1]) list.pop();
    return list;
};

const packEvs = (snap, withRank) => EVS_ORDER.map((key) => {
    const e = snap[`evs:${key}`];
    if (!e) return "";
    const nature = NATURE_MARK[Number(e.nature?.slice(-2))] ?? "";
    const rank = withRank && e.rank !== undefined && e.rank !== 6 ? `r${6 - e.rank}` : "";
    return `${e.points ?? 0}${nature}${rank}`;
}).join(".").replace(/\.+$/, "");

const unpackEvs = (code, snap) => code.split(".").forEach((part, i) => {
    const match = part.match(/^(\d+)([+-]?)(?:r(-?\d+))?$/);
    if (!match) return;
    snap[`evs:${EVS_ORDER[i]}`] = {
        points: Number(match[1]),
        nature: `main_evs_nature_${match[2] === "+" ? 11 : match[2] === "-" ? "09" : 10}`,
        rank: 6 - Number(match[3] ?? 0),
    };
});

const packSide = (snap, role) => {
    const name = snap.pokemon?.name ?? "";
    const types = (snap.pokemon?.types ?? []).join("/");
    const ability = snap.ability ?? {};
    const out = [
        name,
        types === toArray(pokemons[name]?.types).join("/") ? 0 : types,
        packEvs(snap, role === "attacker"),
        ability.name ?? "",
        ability.on ? 2 : ability.toggleable ? 1 : 0,
        snap.item === "なし" ? "" : snap.item ?? "",
        snap.hp && snap.hp.now < snap.hp.max ? `${snap.hp.now}/${snap.hp.max}` : 0,
        (snap[`${role}:conditions`] ?? []).join("/"),
    ];
    if (role === "attacker") {
        const counts = snap["attacker:counts"];
        const packedCounts = counts ? [counts.hits ?? -1, counts.crits ?? -1, counts.axel.reduce((bits, [hit, crit], i) => bits | (hit ? 1 << (i * 2) : 0) | (crit ? 2 << (i * 2) : 0), 0), counts.metronome] : [];
        out.push(
            snap["attacker:move"] ?? "",
            (snap["attacker:weak"] ? 1 : 0) | (snap["attacker:powerup"] ? 2 : 0),
            packedCounts.join() === DEFAULT_COUNTS.join() || !counts ? 0 : packedCounts,
        );
    }
    return trimTail(out);
};

const unpackSide = (packed, role) => {
    const [name = "", types = 0, evs = "", abilityName = "", abilityState = 0, item = "", hp = 0, conditions = "", move = "", flags = 0, counts = 0] = packed;
    const [now, max] = hp ? hp.split("/").map(Number) : [1, 1];
    const snap = {
        pokemon: { name, types: types ? types.split("/") : toArray(pokemons[name]?.types) },
        ability: { name: abilityName, on: abilityState === 2, toggleable: abilityState > 0 },
        item: item || "なし",
        hp: { now, max },
        [`${role}:conditions`]: conditions ? conditions.split("/") : [],
    };
    unpackEvs(evs, snap);
    if (role === "attacker") {
        snap["attacker:move"] = move;
        snap["attacker:weak"] = !!(flags & 1);
        snap["attacker:powerup"] = !!(flags & 2);
        const [hits, crits, axel, metronome] = counts || DEFAULT_COUNTS;
        snap["attacker:counts"] = {
            hits: hits < 0 ? null : hits,
            crits: crits < 0 ? null : crits,
            axel: [0, 1, 2].map((i) => [!!(axel & (1 << (i * 2))), !!(axel & (2 << (i * 2)))]),
            metronome,
        };
    }
    return snap;
};

const packEnvironment = (classes) => (classes ?? []).map((cls) => cls?.replace(/^.*_select_/, "").replace(/^none$/, "") ?? "").join(".").replace(/\.+$/, "");
const unpackEnvironment = (code = "") => {
    const [weather, field] = code.split(".");
    return [`modal_environment_weather_select_${weather || "none"}`, `modal_environment_field_select_${field || "none"}`];
};

const packRanks = (ranks) => Object.entries(ranks ?? {}).filter(([, rank]) => rank).map(([key, rank]) => `${key}${rank}`).join(".");
const unpackRanks = (code = "") => {
    const ranks = Object.fromEntries(defRankSelects().map(([key]) => [key, 0]));
    code.split(".").forEach((part) => {
        const match = part.match(/^([a-z]+)(-?\d+)$/);
        if (match) ranks[match[1]] = Number(match[2]);
    });
    return ranks;
};

const packConstant = (state) => Object.fromEntries(Object.entries(state ?? {}).filter(([key, value]) => {
    if (key === "section") return value !== "ratio";
    if (Array.isArray(value)) return value.length;
    if (value && typeof value === "object") return Object.keys(value).length;
    return value;
}));

const collectShare = () => {
    saveActiveTab();
    return trimTail([
        2,
        packSide(snapshotSide($("main.defender")), "defender"),
        orderTabs.map((tab) => (tab.kind === "attack"
            ? trimTail([packSide(tab.snapshot, "attacker"), packEnvironment(tab.environment), packRanks(tab.defRanks)])
            : [CONSTANT_CODES[tab.kind], packConstant(tab.constant)])),
        orderActive,
        packEnvironment(readEnvironment()),
    ]);
};

const expandShare = (data) => {
    if (!Array.isArray(data) || data[0] !== 2) return data;
    const [, defender, tabs = [], active = 0, environment] = data;
    return {
        v: 1,
        active,
        environment: unpackEnvironment(environment),
        defender: unpackSide(defender, "defender"),
        tabs: tabs.map(([first, second, third]) => {
            if (typeof first === "string") {
                const kind = Object.keys(CONSTANT_CODES).find((key) => CONSTANT_CODES[key] === first) ?? "damage";
                return { kind, constant: { ...newConstantState(), ...second } };
            }
            return { kind: "attack", snapshot: unpackSide(first, "attacker"), environment: unpackEnvironment(second), defRanks: unpackRanks(third) };
        }),
    };
};

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(() => setTimeout(resolve, 0)));

const applyShare = async (raw, report = null) => {
    const data = expandShare(raw);
    if (data?.v !== 1 || !data.tabs?.length) return false;
    const step = async (title, label, run) => {
        if (report) {
            report(title, label);
            await nextFrame();
        }
        run();
    };
    closeOtherSidesChoose();
    for (const [label, run] of restoreSideStages($("main.defender"), data.defender, roleDefaults.defender)) {
        await step("防御側", `${label}を読み込み中…`, run);
    }
    orderTabs.length = 0;
    data.tabs.forEach((tab) => orderTabs.push({ ...newOrderTab(tab.kind), snapshot: tab.snapshot, environment: tab.environment, constant: tab.constant, defRanks: tab.defRanks }));
    for (const [i, tab] of orderTabs.entries()) {
        const title = `タブ ${i + 1}/${orderTabs.length}`;
        if (tab.kind !== "attack" || !tab.snapshot) {
            await step(title, `${CONSTANT_KINDS[tab.kind]?.title ?? "定数"}を読み込み中…`, () => {});
            continue;
        }
        orderActive = i;
        for (const [label, run] of loadTabStages(tab)) {
            await step(title, `${label}を読み込み中…`, run);
        }
        saveActiveTab();
    }
    await step("", "ダメージ計算中…", () => {
        orderActive = Math.min(Math.max(0, data.active ?? 0), orderTabs.length - 1);
        if (orderTabs[orderActive].kind === "attack") loadTab(orderTabs[orderActive]);
        else restoreEnvironment(data.environment);
        renderOrderTabs();
    });
    if (report) {
        await nextFrame();
        await nextFrame();
    }
    return true;
};

let resolveMoves;
const movesReady = new Promise((resolve) => { resolveMoves = resolve; });
const domReady = new Promise((resolve) => {
    if (document.readyState !== "loading") resolve();
    else document.addEventListener("DOMContentLoaded", resolve, { once: true });
});
const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

const showOpenInApp = (code) => {
    if (isNative || !isIOS) return;
    const link = document.createElement("a");
    link.className = "open_in_app";
    link.href = `pokefire://open?s=${code}`;
    link.textContent = "アプリで開く";
    document.body.appendChild(link);
    setTimeout(() => link.classList.add("is-hiding"), 6000);
    setTimeout(() => link.remove(), 6400);
};

let shareLoading = false;
const loadShareCode = async (code) => {
    if (!code || shareLoading) return;
    shareLoading = true;
    const loading = document.createElement("div");
    loading.className = "share_loading";
    loading.setAttribute("role", "status");
    loading.innerHTML = '<span></span><p class="share_loading_text"><b></b>読み込み中…</p>';
    document.body.appendChild(loading);
    const text = $(".share_loading_text", loading);
    const report = (title, label) => {
        text.innerHTML = `<b>${title || "&nbsp;"}</b>${label}`;
    };
    report("", "データを読み込み中…");
    try {
        const ready = domReady.then(() => Promise.all([pokemonsReady, movesReady, calcReady]));
        const [data] = await Promise.all([decodeShare(code), ready]);
        historyMuted = true;
        await applyShare(data, report);
        if (location.hash) history.replaceState(null, "", location.pathname + location.search);
        haptic("success");
        showOpenInApp(code);
    } catch (err) {
        console.error("共有URLを読み込めませんでした", err);
        showToast("共有URLを読み込めませんでした");
    } finally {
        historyMuted = false;
        shareLoading = false;
        requestAnimationFrame(() => loading.classList.add("is-hiding"));
        setTimeout(() => loading.remove(), 400);
    }
};

const shareCode = new URLSearchParams(location.hash.slice(1)).get("s");
if (shareCode) loadShareCode(shareCode);

const SHARE_BASE = "https://ffui.me/poke/fire/";
const shareUrl = async () => `${isNative ? SHARE_BASE : `${location.origin}${location.pathname}`}#s=${await encodeShare(collectShare())}`;

const showToast = (text) => {
    const toast = document.createElement("p");
    toast.className = "toast";
    toast.textContent = text;
    document.body.appendChild(toast);
    setTimeout(() => toast.classList.add("is-hiding"), 1800);
    setTimeout(() => toast.remove(), 2200);
};

$(".detail_share")?.addEventListener("click", async (e) => {
    e.stopPropagation();
    try {
        const url = await shareUrl();
        if (isNative) {
            postNative({ type: "share", url });
            return;
        }
        if (navigator.share) {
            await navigator.share({ title: document.title, url }).catch(() => {});
            return;
        }
        await navigator.clipboard.writeText(url);
        showToast("共有用のURLをコピーしました");
    } catch (err) {
        console.error(err);
        showToast("URLを作れませんでした");
    }
});

const speedConditions = { attacker: new Set(), defender: new Set() };
const speedAbilityOverride = { attacker: null, defender: null };
const speedSection = $("section.speed");
const SPEED_ROLES = ["attacker", "defender"];
const SCARF_ICON = '<span class="speed_scarf" role="img" aria-label="スカーフ"></span>';
let speedSelected = null;
let speedCursor = null;
let speedData = [];
let speedStaticHtml = "";

const speedSideOf = (role) => $(`main.${role}`);
const speedPanel = speedSection && $(".speed_pokemon_evs", speedSection);
const speedGraph = speedSection && $(".speed_graph", speedSection);

if (speedGraph) {
    speedGraph.innerHTML = `<div class="speed_graph_axis"></div>
        <div class="speed_graph_area">
            <div class="speed_graph_static"></div>
            <div class="speed_graph_cursor" hidden><span></span></div>
            <p class="speed_graph_tip attacker" hidden></p>
            <p class="speed_graph_tip defender" hidden></p>
        </div>`;
}

const comboHtml = ({ scarf, nature, points }) => `<span class="speed_combo${nature === 11 ? " up" : nature === 9 ? " down" : ""}">${scarf ? SCARF_ICON : ""}${points}${nature === 11 ? "+" : nature === 9 ? "-" : ""}</span>`;

const speedRange = () => ({ lo: Number(speedGraph.dataset.lo), hi: Number(speedGraph.dataset.hi) });

const renderSpeedCursor = (clientY) => {
    const area = $(".speed_graph_area", speedGraph);
    const line = $(".speed_graph_cursor", speedGraph);
    if (!area || !speedData.length) return;
    const { lo, hi } = speedRange();
    if (clientY !== undefined) {
        const rect = area.getBoundingClientRect();
        const ratio = Math.max(0, Math.min(1, (clientY - rect.top) / rect.height));
        line.style.top = `${ratio * 100}%`;
        const next = Math.round(hi - ratio * (hi - lo));
        if (next !== speedCursor) haptic("selection");
        speedCursor = next;
    } else if (speedCursor !== null) {
        line.style.top = `${((hi - speedCursor) / (hi - lo)) * 100}%`;
    }
    const visible = speedCursor !== null;
    line.hidden = !visible;
    if (!visible) return;
    setText($("span", line), String(speedCursor));
    speedData.forEach(({ role, combos }) => {
        const tip = $(`.speed_graph_tip.${role}`, speedGraph);
        const html = combos.get(speedCursor)?.map(comboHtml).join("") || '<span class="speed_combo none">-</span>';
        if (tip.innerHTML !== html) tip.innerHTML = html;
        tip.style.top = line.style.top;
        tip.hidden = false;
    });
};

function renderSpeed() {
    if (!speedSection || !speedGraph) return;
    const field = readField();
    speedData = SPEED_ROLES.map((role) => {
        const p = readSide(role);
        const base = p.base.s;
        const at = (points, nature, scarf = false) => speedStat(p, field.weather, field.terrain, { real: realStat(base, points, nature), scarf });
        const combos = new Map();
        [false, true].forEach((scarf) => [11, 10, 9].forEach((nature) => {
            for (let points = 0; points <= 32; points++) {
                const value = at(points, nature, scarf);
                const list = combos.get(value) ?? [];
                if (!list.some((c) => c.scarf === scarf && c.nature === nature)) list.push({ scarf, nature, points });
                combos.set(value, list);
            }
        }));
        return {
            role,
            p,
            mega: !!megaParent(p.name, pokemons[p.name] ?? {}),
            fixed: { slow: at(0, 9), none: at(0, 10), semi: at(32, 10), max: at(32, 11) },
            scarf: { none: at(0, 10, true), semi: at(32, 10, true), max: at(32, 11, true) },
            now: speedStat(p, field.weather, field.terrain),
            nowScarf: speedStat(p, field.weather, field.terrain, { scarf: true }),
            combos,
        };
    });

    speedData.forEach(({ role, p, now }) => {
        const item = $(`.speed_pokemon_item.${role}`, speedSection);
        const img = $(".speed_pokemon_item_sprite", item);
        const src = spriteOf(pokemons[p.name]);
        if (src && img.getAttribute("src") !== src) img.src = src;
        setText($(".speed_pokemon_item_num", item), String(now));
        if (role === speedSelected) {
            setText($(".main_evs_header_value", speedPanel), String(now));
            syncSpeedAbilityButton(p, field);
        }
    });

    const values = speedData.flatMap((d) => [d.fixed.slow, d.scarf.max, d.now, d.nowScarf]);
    const pad = Math.max(8, (Math.max(...values) - Math.min(...values)) * 0.05);
    const lo = Math.max(0, Math.floor(Math.min(...values) - pad));
    const hi = Math.ceil(Math.max(...values) + pad);
    const y = (v) => `${((hi - v) / (hi - lo)) * 100}%`;
    speedGraph.dataset.lo = lo;
    speedGraph.dataset.hi = hi;

    const ticks = [];
    for (let v = Math.ceil(lo / 50) * 50; v <= hi; v += 50) ticks.push(`<p class="speed_graph_tick" style="top: ${y(v)}">${v}</p>`);
    const mark = (v, label, cls = "") => `<p class="speed_graph_mark ${cls}" style="top: ${y(v)}"><span>${label}</span>${v}</p>`;
    const guides = [];
    const columns = speedData.map(({ role, mega, fixed, scarf, now, nowScarf }) => {
        [...Object.values(fixed), ...Object.values(scarf)].forEach((v) => guides.push(`<span class="speed_graph_guide ${role}" style="top: ${y(v)}"></span>`));
        return `<div class="speed_graph_item ${role}${mega ? " is-mega" : ""}">
            <span class="speed_graph_bar" style="top: ${y(fixed.max)}; bottom: calc(100% - ${y(fixed.slow)})"></span>
            <span class="speed_graph_bar scarf" style="top: ${y(scarf.max)}; bottom: calc(100% - ${y(scarf.none)})"></span>
            ${mark(fixed.max, "最")}${mark(fixed.semi, "準")}${mark(fixed.none, "無")}${mark(fixed.slow, "遅")}
            ${mark(scarf.max, `${SCARF_ICON}最`, "scarf")}${mark(scarf.semi, `${SCARF_ICON}準`, "scarf")}${mark(scarf.none, `${SCARF_ICON}無`, "scarf")}
            <p class="speed_graph_now" style="top: ${y(now)}">★${now}</p>
            <p class="speed_graph_now scarf" style="top: ${y(nowScarf)}">★${SCARF_ICON}${nowScarf}</p>
        </div>`;
    });
    const html = `${guides.join("")}${columns.join("")}`;
    if (html !== speedStaticHtml) {
        speedStaticHtml = html;
        $(".speed_graph_axis", speedGraph).innerHTML = ticks.join("");
        $(".speed_graph_static", speedGraph).innerHTML = html;
    }
    renderSpeedCursor();
}

const fitSpeedGraph = () => {
    if (!speedGraph) return;
    speedGraph.style.height = `${Math.max(220, window.innerHeight - speedGraph.offsetTop - 24)}px`;
};

const speedSectionOf = (role) => $(".main_evs.main_evs_s", speedSideOf(role));

const syncSpeedAbilityButton = (p, field = readField()) => {
    const list = speedPanel && $(".main_evs_conditions", speedPanel);
    if (!list) return;
    let button = $(".main_evs_condition_item.ability", list);
    if (!SPEED_ABILITIES[p.ability]) {
        button?.remove();
        return;
    }
    if (!button) {
        button = document.createElement("button");
        button.className = "main_evs_condition_item ability";
        list.prepend(button);
    }
    setText(button, p.ability);
    button.classList.toggle("active", speedAbilityActive(p, field.weather, field.terrain));
};

const loadSpeedPanel = (role) => {
    const section = speedSectionOf(role);
    if (!speedPanel || !section) return;
    $(".main_evs_header .ttl", speedPanel).textContent = role === "attacker" ? "攻撃側のすばやさ" : "防御側のすばやさ";
    $(".main_evs_range", speedPanel).setEvsValue?.(pointsOf(section));
    setNature(speedPanel, natureOf(section));
    const select = $(".main_evs_ranks select", speedPanel);
    select.selectedIndex = $(".main_evs_ranks select", section).selectedIndex;
    select.dispatchEvent(new Event("change", { bubbles: true }));
    $$(".main_evs_condition_item", speedPanel).forEach((button) => button.classList.toggle("active", speedConditions[role].has(button.textContent.trim())));
};

let speedLoading = false;
const saveSpeedPanel = () => {
    const side = speedSelected && speedSideOf(speedSelected);
    const section = side && speedSectionOf(speedSelected);
    if (!section || speedLoading) return;
    let changed = false;
    const points = Number($(".main_evs_range_num", speedPanel).textContent) || 0;
    if (pointsOf(section) !== points) {
        $(".main_evs_range", section).setEvsValue(points);
        changed = true;
    }
    if (natureOf(section) !== natureOf(speedPanel)) {
        setNature(section, natureOf(speedPanel));
        changed = true;
    }
    const select = $(".main_evs_ranks select", section);
    const index = $(".main_evs_ranks select", speedPanel).selectedIndex;
    if (select.selectedIndex !== index) {
        select.selectedIndex = index;
        select.dispatchEvent(new Event("change", { bubbles: true }));
        changed = true;
    }
    if (!changed) return;
    updateRealStatsIn(side);
    saveAdjustments(side);
    renderSpeed();
    scheduleCalc();
};

const selectSpeedPokemon = (role) => {
    speedSelected = speedSelected === role ? null : role;
    $$(".speed_pokemon_item", speedSection).forEach((item) => item.classList.toggle("selected", item.classList.contains(speedSelected)));
    speedPanel.classList.toggle("active", !!speedSelected);
    speedPanel.classList.toggle("defender", speedSelected === "defender");
    speedGraph.classList.toggle("is-behind", !!speedSelected);
    if (speedSelected) {
        speedLoading = true;
        loadSpeedPanel(speedSelected);
        speedLoading = false;
    }
    renderSpeed();
};

const openSpeed = () => {
    closeOtherSidesChoose();
    speedSection.scrollTop = 0;
    speedSection.classList.add("is-open");
    fitSpeedGraph();
    renderSpeed();
};

if (speedSection && speedGraph && speedPanel) {
    speedSection.classList.remove("is-open");
    $$(".main_basestats_item.s").forEach((item) => item.addEventListener("click", openSpeed));
    $$(".open_speed").forEach((button) => button.addEventListener("click", (e) => {
        e.stopPropagation();
        const detailOpen = button.closest("section.detail");
        openSpeed();
        if (detailOpen) setTimeout(() => detailOpen.classList.remove("is-open"), 360);
    }));
    $("header", speedSection)?.addEventListener("click", () => speedSection.classList.remove("is-open"));
    bindSheetDrag(speedSection, () => speedSection.classList.remove("is-open"), ".speed_graph, .speed_pokemon_evs");
    window.addEventListener("resize", () => {
        if (!speedSection.classList.contains("is-open")) return;
        fitSpeedGraph();
        renderSpeed();
    });

    $$(".speed_pokemon_item", speedSection).forEach((item) => {
        item.addEventListener("click", () => selectSpeedPokemon(SPEED_ROLES.find((role) => item.classList.contains(role))));
    });

    new MutationObserver(() => {
        if (!speedLoading) saveSpeedPanel();
    }).observe(speedPanel, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["class"] });
    speedPanel.addEventListener("change", saveSpeedPanel);
    speedPanel.addEventListener("click", (e) => {
        const condition = e.target.closest(".main_evs_condition_item");
        if (!condition || !speedSelected) return;
        if (condition.classList.contains("ability")) {
            const side = speedSideOf(speedSelected);
            const name = condition.textContent.trim();
            if (SPEED_ABILITIES[name]?.toggle) {
                const abilityButton = $("button.main_ability_on", side);
                if (abilityButton && !abilityButton.disabled && !abilityButton.hidden) abilityButton.click();
            } else {
                speedAbilityOverride[speedSelected] = { name, on: !condition.classList.contains("active") };
            }
            runCalc();
            renderSpeed();
            return;
        }
        const name = condition.textContent.trim();
        const set = speedConditions[speedSelected];
        if (set.has(name)) set.delete(name);
        else set.add(name);
        condition.classList.toggle("active", set.has(name));
        renderSpeed();
        scheduleCalc();
    });

    let graphDrag = false;
    speedGraph.addEventListener("pointerdown", (e) => {
        graphDrag = true;
        try {
            speedGraph.setPointerCapture(e.pointerId);
        } catch {}
        renderSpeedCursor(e.clientY);
    });
    speedGraph.addEventListener("pointermove", (e) => {
        if (graphDrag) renderSpeedCursor(e.clientY);
    });
    ["pointerup", "pointercancel"].forEach((type) => speedGraph.addEventListener(type, () => { graphDrag = false; }));
}

if (!isNative && "serviceWorker" in navigator && location.protocol !== "file:") {
    window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
}

const NATIVE_TAB_LABELS = { attack: "攻撃", damage: "定数", heel: "回復" };
let nativeStateText = "";
function pushNativeState() {
    if (!isNative || !window.calcLoaded) return;
    const card = $(".card_result");
    const text = (selector) => $(selector, card)?.textContent.trim() ?? "";
    const bar = (selector) => {
        const el = $(selector, card);
        return { width: parseFloat(el?.style.width) / 100 || 0, color: el?.style.backgroundColor || "" };
    };
    const rate = $(".card_result_judge_percent", card);
    const state = {
        type: "state",
        result: {
            percent: text(".card_result_damage_percent"),
            damage: text(".card_result_damage_num_take"),
            hp: text(".card_result_damage_num_max"),
            judge: text(".card_result_judgement"),
            rate: rate && !rate.hidden ? rate.textContent.trim() : "",
            sure: bar(".card_result_hpbar_kaku"),
            maybe: bar(".card_result_hpbar_ran"),
        },
        tabs: orderTabs.map((tab, i) => ({ id: tab.id, kind: tab.kind, label: NATIVE_TAB_LABELS[tab.kind] ?? "", index: i + 1 })),
        active: orderActive,
        covered: document.documentElement.classList.contains("is-scroll-locked"),
        environment: Object.fromEntries(["weather", "field"].map((kind, i) => [kind, readEnvironment()[i]?.split("_").pop() ?? "none"])),
    };
    const json = JSON.stringify(state);
    if (json === nativeStateText) return;
    nativeStateText = json;
    postNative(state);
}

window.PokeFireNative = {
    activate: (index) => activateTab(index),
    add: (kind) => addTab(kind),
    remove: (index) => removeTab(index),
    move: (index, step) => {
        if (index !== orderActive) activateTab(index);
        moveActiveTab(step);
    },
    openDetail: () => $(".card_result")?.click(),
    openSpeed: () => $(".card_speed")?.click(),
    share: async () => postNative({ type: "share", url: await shareUrl() }),
    openShare: (code) => loadShareCode(code),
    setEnvironment: (kind, key) => {
        const button = $(`.modal_environment_${kind}_select_${key}`);
        if (button && !button.classList.contains("selected")) button.click();
    },
    openHistory: () => openHistory(),
    sync: () => {
        nativeStateText = "";
        pushNativeState();
    },
};

const HISTORY_KEY = "pokefire-history";
const HISTORY_LIMIT = 60;
const historyAside = $("aside.history");
const historyList = historyAside && $(".history_list", historyAside);
let historyArmed = false;
let historyMuted = false;
let historyTimer = 0;

const loadHistory = () => {
    try {
        return JSON.parse(localStorage.getItem(HISTORY_KEY)) ?? [];
    } catch {
        return [];
    }
};
const saveHistory = (list) => {
    const pinned = list.filter((entry) => entry.pinned);
    const rest = list.filter((entry) => !entry.pinned).slice(0, Math.max(0, HISTORY_LIMIT - pinned.length));
    try {
        localStorage.setItem(HISTORY_KEY, JSON.stringify([...pinned, ...rest].sort((a, b) => b.time - a.time)));
    } catch {}
};

["pointerdown", "keydown"].forEach((type) => document.addEventListener(type, (e) => {
    if (!e.target.closest?.("aside.history, .gohistory")) historyArmed = true;
}, { capture: true, passive: true }));

const historyEntry = () => {
    const { attacks, def, summary } = calcState;
    if (!def?.name || !attacks.length) return null;
    const attackers = [...new Set(attacks.map((e) => e.atk.name))];
    const moves = [...new Set(attacks.map((e) => e.atk.move))];
    return {
        key: `${attackers.join("+")}>${def.name}`,
        attackers,
        defender: def.name,
        moves,
        judge: summary?.text ?? "",
        rate: summary?.rate ?? "",
        data: collectShare(),
        time: Date.now(),
    };
};

function recordHistory() {
    if (!historyAside || !historyArmed || historyMuted || shareLoading) return;
    clearTimeout(historyTimer);
    historyTimer = setTimeout(() => {
        if (historyMuted || shareLoading) return;
        const entry = historyEntry();
        if (!entry) return;
        const list = loadHistory();
        entry.pinned = !!list.find((h) => h.key === entry.key)?.pinned;
        saveHistory([entry, ...list.filter((h) => h.key !== entry.key)]);
        if (historyAside.classList.contains("is-open")) renderHistory();
    }, 1200);
}

const escapeHtml = (text) => String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

const historyGroupOf = (time) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const day = 86400000;
    if (time >= today.getTime()) return "今日";
    if (time >= today.getTime() - day) return "昨日";
    if (time >= today.getTime() - day * 7) return "過去7日間";
    return "それ以前";
};

const historyTime = (time) => {
    const date = new Date(time);
    const pad = (n) => String(n).padStart(2, "0");
    return historyGroupOf(time) === "今日" || historyGroupOf(time) === "昨日"
        ? `${pad(date.getHours())}:${pad(date.getMinutes())}`
        : `${date.getMonth() + 1}/${date.getDate()}`;
};

const PIN_ICON = '<svg viewBox="0 0 24 24"><path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/></svg>';
const TRASH_ICON = '<svg viewBox="0 0 24 24"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>';

const historyItemHtml = (entry) => `<div class="history_item${entry.pinned ? " is-pinned" : ""}" data-key="${escapeHtml(entry.key)}">
    <div class="history_item_sprites">${[...entry.attackers.slice(0, 2), entry.defender].map((name) => `<img src="${spriteOf(pokemons[name])}" alt="" loading="lazy">`).join("")}</div>
    <div class="history_item_text">
        <p class="history_item_title">${escapeHtml(entry.attackers.join("・"))} → ${escapeHtml(entry.defender)}</p>
        <p class="history_item_sub">${escapeHtml([historyTime(entry.time), entry.moves.join("・"), entry.judge && `${entry.judge}${entry.rate ? `（${entry.rate}）` : ""}`].filter(Boolean).join(" ・ "))}</p>
    </div>
    <button class="history_item_pin" aria-label="ピン留め">${PIN_ICON}</button>
    <button class="history_item_delete" aria-label="削除">${TRASH_ICON}</button>
</div>`;

function renderHistory() {
    if (!historyList) return;
    const list = loadHistory();
    if (!list.length) {
        historyList.innerHTML = '<p class="history_empty">計算した対面が<br>ここに自動で残ります</p>';
        return;
    }
    const groups = [];
    const pinned = list.filter((entry) => entry.pinned);
    if (pinned.length) groups.push(["ピン留め", pinned]);
    list.filter((entry) => !entry.pinned).forEach((entry) => {
        const label = historyGroupOf(entry.time);
        const last = groups[groups.length - 1];
        if (!last || last[0] !== label) groups.push([label, [entry]]);
        else last[1].push(entry);
    });
    historyList.innerHTML = groups.map(([label, entries]) => `<p class="history_group">${label}</p>${entries.map(historyItemHtml).join("")}`).join("");
}

function openHistory() {
    if (!historyAside) return;
    closeOtherSidesChoose();
    renderHistory();
    historyAside.classList.add("is-open");
    haptic("light");
}
const closeHistory = () => historyAside?.classList.remove("is-open");

if (historyAside) {
    $(".gohistory")?.addEventListener("click", openHistory);
    $(".history_close", historyAside).addEventListener("click", closeHistory);
    historyAside.addEventListener("click", async (e) => {
        if (e.target === historyAside) {
            closeHistory();
            return;
        }
        const item = e.target.closest(".history_item");
        if (!item) return;
        const list = loadHistory();
        const entry = list.find((h) => h.key === item.dataset.key);
        if (!entry) return;
        if (e.target.closest(".history_item_pin")) {
            entry.pinned = !entry.pinned;
            saveHistory(list);
            renderHistory();
            haptic("light");
            return;
        }
        if (e.target.closest(".history_item_delete")) {
            saveHistory(list.filter((h) => h !== entry));
            renderHistory();
            haptic("medium");
            return;
        }
        closeHistory();
        haptic("medium");
        historyMuted = true;
        try {
            await applyShare(entry.data);
        } finally {
            setTimeout(() => { historyMuted = false; }, 300);
        }
    });

    let drawerSwipe = null;
    historyAside.addEventListener("touchstart", (e) => {
        drawerSwipe = e.touches.length === 1 ? { x: e.touches[0].clientX, y: e.touches[0].clientY } : null;
    }, { passive: true });
    historyAside.addEventListener("touchmove", (e) => {
        if (!drawerSwipe) return;
        const dx = e.touches[0].clientX - drawerSwipe.x;
        const dy = e.touches[0].clientY - drawerSwipe.y;
        if (dx < -60 && Math.abs(dy) < -dx * 0.6) {
            drawerSwipe = null;
            closeHistory();
        } else if (Math.abs(dy) > 40) {
            drawerSwipe = null;
        }
    }, { passive: true });

    let edgeSwipe = null;
    const SWIPE_IGNORE = ".main_evs_range, .main_hpleft_range, .main_count, select, input, .order_main, .main_search_otherforms, .main_pokemon_choose, .main_type_choose, section, aside";
    document.addEventListener("touchstart", (e) => {
        const blocked = e.touches.length !== 1 || document.body.scrollLeft > 4 || $("section.is-open") || e.target.closest(SWIPE_IGNORE);
        edgeSwipe = blocked ? null : { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }, { passive: true });
    document.addEventListener("touchmove", (e) => {
        if (!edgeSwipe) return;
        const dx = e.touches[0].clientX - edgeSwipe.x;
        const dy = e.touches[0].clientY - edgeSwipe.y;
        if (dx > 64 && Math.abs(dy) < dx * 0.5) {
            edgeSwipe = null;
            openHistory();
        } else if (dx < -12 || Math.abs(dy) > 32) {
            edgeSwipe = null;
        }
    }, { passive: true });
}

if (isNative) {
    const ROLL_SELECTOR = ".main_evs_header_value, .main_evs_range_num, .main_basestats_item p, .main_move_header_info_power, .main_hpleft_header_value .percent, .main_hpleft_header_value .now, .speed_pokemon_item_num, .main_count .value, .detail_overview_log_damage_percent, .detail_overview_log_damage_num_take, .detail_index_num, .detail_hppm_header_num";
    const rollTexts = new WeakMap();
    new MutationObserver((records) => {
        const targets = new Set();
        records.forEach((record) => {
            const node = record.target.nodeType === Node.TEXT_NODE ? record.target.parentElement : record.target;
            const el = node?.closest?.(ROLL_SELECTOR);
            if (el) targets.add(el);
        });
        targets.forEach((el) => {
            const text = el.textContent;
            const before = rollTexts.get(el);
            rollTexts.set(el, text);
            if (before === undefined || before === text) return;
            el.classList.remove("num-roll");
            void el.offsetWidth;
            el.classList.add("num-roll");
        });
    }).observe(document.body, { subtree: true, childList: true, characterData: true });
    document.addEventListener("animationend", (e) => {
        if (e.animationName === "num-roll") e.target.classList.remove("num-roll");
    });
    window.addEventListener("load", () => $$(ROLL_SELECTOR).forEach((el) => rollTexts.set(el, el.textContent)));
}
