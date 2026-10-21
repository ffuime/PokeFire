import Foundation
import Observation

struct SharedBuild {
    var evs: [StatKey: EVState] = [:]
    var ability: String?
    var item: String?
    var atk: Fighter?
}

struct SpeedOverride: Equatable {
    var name: String
    var on: Bool
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

struct CalcOutput {
    var entries: [CalcEntry] = []
    var def: Fighter?
    var hp = HPInfo(max: 0, now: 0)
    var multi = false
    var summary = Summary(text: "", rate: nil, min: 0, max: 0)
    var liveAttacker: Fighter?
    var liveResult: CalcResult?
    var defRankBonus = 0
    var multiscaleLocked = false
    var field = Field()
    var revision = 0

    var attacks: [CalcEntry] { entries.filter { $0.kind == .attack } }

    var percentText: String {
        guard hp.max > 0 else { return "0.0%" }
        let low = "\(Format.fixed1(Double(summary.min) / Double(hp.max) * 100))%"
        let high = "\(Format.fixed1(Double(summary.max) / Double(hp.max) * 100))%"
        return summary.min == summary.max ? low : "\(low)～\(high)"
    }

    var damageText: String { Format.pair(summary.min, summary.max) }

    var sureRatio: Double {
        hp.max > 0 ? min(1, max(0, Double(hp.now - summary.max) / Double(hp.max))) : 0
    }

    var maybeRatio: Double {
        hp.max > 0 ? min(1, max(0, Double(hp.now - summary.min) / Double(hp.max))) : 0
    }
}

@Observable
@MainActor
final class AppModel {
    let data = GameData.shared

    var attacker = SideState.initial(.attacker)
    var defender = SideState.initial(.defender)
    var weather = "none"
    var field = "none"
    var tabs: [OrderTab] = []
    var active = 0
    var speedConditions: [Role: Set<String>] = [.attacker: [], .defender: []]
    var speedOverride: [Role: SpeedOverride] = [:]
    var output = CalcOutput()
    var usage: UsageData?
    var learnsets: [String: [String]]?
    var toast: ToastMessage?
    var history: [HistoryEntry] = Storage.history
    var isLoadingShare = false

    @ObservationIgnored private var shared: [String: SharedBuild] = [:]
    @ObservationIgnored private var swapSlots: [SideSnapshot] = [SideSnapshot(), SideSnapshot()]
    @ObservationIgnored private var slotOfRole: [Role: Int] = [.attacker: 0, .defender: 1]
    @ObservationIgnored private var roleDefaults: [Role: SideSnapshot] = [:]
    @ObservationIgnored private var tabSequence = 0
    @ObservationIgnored private var calcScheduled = false
    @ObservationIgnored private var historyArmed = false
    @ObservationIgnored private var historyMuted = false
    @ObservationIgnored private var historyTask: Task<Void, Never>?
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var pokemonOrderCache: (key: Double, list: [String])?

    init() {
        roleDefaults[.attacker] = snapshot(SideState.initial(.attacker))
        roleDefaults[.defender] = snapshot(SideState.initial(.defender))
        selectPokemonCore(.attacker, "ガブリアス")
        selectAbilityIfCandidate(.attacker, "さめはだ")
        selectPokemonCore(.defender, "メガリザードンX")
        selectAbilityIfCandidate(.defender, "かたいツメ")
        selectMoveCore("げきりん")
        tabs = [newTab(.attack)]
        if let session = Storage.session, let json = try? JSON.parse(session) {
            historyMuted = true
            _ = applyShareData(json)
            historyMuted = false
        }
        recalc()
        Task { [weak self] in
            let loaded = await UsageLoader.load()
            self?.usage = loaded
        }
        Task { [weak self] in
            let loaded = await LearnsetLoader.load()
            self?.learnsets = loaded
        }
        NotificationCenter.default.addObserver(forName: .pokefireToast, object: nil, queue: .main) { [weak self] note in
            guard let text = note.object as? String else { return }
            MainActor.assumeIsolated { self?.showToast(text) }
        }
    }

    func learnset(_ name: String) -> [String]? {
        guard let learnsets, let en = data.usageNames.pokemons[name] ?? data.usageNames.pokemons[data.usageName(of: name)] else { return nil }
        return learnsets[en]
    }

    func applyBox(_ entry: BoxPokemon, to role: Role) {
        if side(role).name != entry.name {
            selectPokemon(role, entry.name)
        }
        update(role) { side in
            side.shiny = entry.isShiny
            for key in Rules.statKeys(role) where StatKey.baseKeys.contains(key) {
                var value = side.evs[key] ?? EVState(points: 0)
                value.points = entry.point(key)
                if key.hasNature { value.nature = entry.nature(key) }
                side.evs[key] = value
            }
        }
        if !entry.ability.isEmpty { selectAbility(role, entry.ability) }
        if !entry.item.isEmpty { selectItem(role, entry.item) }
        if role == .attacker, let move = entry.moves.first(where: { !$0.isEmpty }), data.moves[move] != nil {
            selectMove(move)
        }
    }

    func applyStats(_ source: StatsSide, to role: Role) {
        if side(role).name != source.name {
            selectPokemon(role, source.name)
        }
        update(role) { side in
            for key in Rules.statKeys(role) where StatKey.baseKeys.contains(key) {
                var value = side.evs[key] ?? EVState(points: 0)
                value.points = source.point(key)
                if key.hasNature { value.nature = source.nature(key) }
                side.evs[key] = value
            }
        }
    }

    func usageAbilities(_ name: String) -> [UsagePair] {
        if data.usageName(of: name) != name, let first = data.pokemons[name]?.abilities.first {
            return [UsagePair(name: first, pct: 100)]
        }
        return usage?.pokemons[name]?.abilities ?? []
    }

    // MARK: - Side access

    func side(_ role: Role) -> SideState {
        role == .attacker ? attacker : defender
    }

    private func setSide(_ role: Role, _ side: SideState) {
        if role == .attacker {
            if attacker != side { attacker = side }
        } else if defender != side {
            defender = side
        }
    }

    private func normalized(_ input: SideState) -> SideState {
        var side = input
        for key in Rules.statKeys(side.role) where side.evs[key] == nil {
            side.evs[key] = EVState(points: Rules.defaultPoints(key))
        }
        let max = side.maxHP
        guard max > 0 else { return side }
        let oldMax = side.hpMax > 0 ? side.hpMax : max
        let oldNow = side.hpNow > 0 ? side.hpNow : oldMax
        var now = oldNow >= oldMax ? max : Int(Calc.jsRound(Double(oldNow) / Double(oldMax) * Double(max)))
        now = Swift.max(1, Swift.min(max, now))
        side.hpNow = now
        side.hpMax = max
        return side
    }

    private func update(_ role: Role, edit: Bool = true, _ body: (inout SideState) -> Void) {
        var side = self.side(role)
        body(&side)
        setSide(role, normalized(side))
        if edit { historyArmed = true }
        scheduleCalc()
    }

    var activeTab: OrderTab? {
        tabs.indices.contains(active) ? tabs[active] : nil
    }

    var isConstantActive: Bool {
        activeTab.map { $0.kind != .attack } ?? false
    }

    func visibleStats(_ role: Role) -> [StatKey] {
        let rule = Rules.statRule(role, move: attacker.move)
        return Rules.statKeys(role).filter { rule.evs.contains($0) }
    }

    func highlightedBaseStats(_ role: Role) -> [StatKey] {
        Rules.statRule(role, move: attacker.move).basestat
    }

    func showsHP(_ role: Role) -> Bool {
        role == .defender || Rules.hpReferenceMoves.contains(attacker.move)
    }

    func abilityControl(_ role: Role) -> AbilityControl {
        Rules.abilityControl(role, side(role).ability)
    }

    func abilityActive(_ role: Role) -> Bool {
        let side = self.side(role)
        switch abilityControl(role) {
        case .locked: return true
        case .toggle:
            if role == .defender, side.ability == "マルチスケイル", output.multiscaleLocked { return false }
            return side.abilityOn
        case .environment:
            if let key = Rules.weatherAbilities[side.ability] { return weather == key }
            if let key = Rules.fieldAbilities[side.ability] { return field == key }
            return false
        case .disguise:
            return disguiseTabIndex != nil
        default: return false
        }
    }

    func abilityDisabled(_ role: Role) -> Bool {
        switch abilityControl(role) {
        case .locked, .hidden: return true
        case .toggle: return role == .defender && side(role).ability == "マルチスケイル" && output.multiscaleLocked
        case .disguise: return isConstantActive
        default: return false
        }
    }

    var burnLocked: Bool {
        attacker.move == "からげんき" || attacker.ability == "こんじょう"
    }

    var critLocked: Bool {
        Calc.alwaysCritMoves.contains(attacker.move)
    }

    var multiHitRange: (min: Int, max: Int, def: Int)? {
        Calc.multiHitRange(attacker.move, attacker.ability)
    }

    var isAxel: Bool { attacker.move == "トリプルアクセル" }

    var showsPowerUp: Bool { Calc.powerUpMoves[attacker.move] != nil }

    var showsMetronome: Bool { attacker.item == "メトロノーム" }

    func displayedRank(_ role: Role, _ key: StatKey) -> Int {
        let rank = side(role).ev(key).rank
        if role == .defender, key == .b { return Calc.clampRank(rank + output.defRankBonus) }
        return rank
    }

    var movePowerText: String {
        guard let move = data.moves[attacker.move] else { return "-" }
        if let shown = output.liveResult?.info?.displayPower { return String(shown) }
        return move.powerText
    }

    var movePowerBoosted: Bool {
        guard let move = data.moves[attacker.move] else { return false }
        if showsPowerUp, attacker.powerUp { return true }
        if let shown = output.liveResult?.info?.displayPower, let power = move.power { return shown > power }
        return false
    }

    // MARK: - Fighters

    func fighter(_ side: SideState, opponentBaseA: Int) -> Fighter {
        var f = Fighter()
        f.role = side.role
        f.name = side.name
        f.base = side.base
        f.types = side.types
        f.ability = side.ability
        let control = Rules.abilityControl(side.role, side.ability)
        f.abilityOn = control == .locked || (control == .toggle && side.abilityOn)
        f.item = side.item == "なし" ? "" : side.item
        let locked = side.role == .attacker && (side.move == "からげんき" || side.ability == "こんじょう")
        let allowed = Rules.conditions(side.role)
        f.conditions = side.conditions.filter { allowed.contains($0) && !(locked && $0 == "やけど") }
        if side.role == .attacker {
            let range = Calc.multiHitRange(side.move, side.ability)
            let axel = side.move == "トリプルアクセル"
            f.crit = range == nil && !axel && (side.crit || Calc.alwaysCritMoves.contains(side.move))
            f.hits = range != nil ? side.hits : nil
            f.crits = range != nil ? side.crits : nil
            f.axel = side.axel
            f.metronome = side.item == "メトロノーム" ? side.metronome : nil
            f.rankBoost = side.rankBoost
            f.fainted = side.fainted
            f.flingPower = side.flingPower
            f.powerUp = Calc.powerUpMoves[side.move] != nil && side.powerUp
            f.move = side.move
        }
        for key in Rules.statKeys(side.role) {
            let value = side.ev(key)
            f.evs[key] = StatValue(
                real: side.real(key, opponentBaseA: opponentBaseA),
                points: value.points,
                rank: key.hasRank ? value.rank : 0,
                nature: key.hasNature ? value.nature : 10
            )
        }
        f.hpNow = side.hpNow
        f.speedConditions = Array(speedConditions[side.role] ?? [])
        if let override = speedOverride[side.role], override.name == side.ability {
            f.speedAbility = override.on
        }
        return f
    }

    func liveFighter(_ role: Role) -> Fighter {
        role == .attacker
            ? fighter(attacker, opponentBaseA: defender.base.a)
            : fighter(defender, opponentBaseA: attacker.base.a)
    }

    private func shareWith(_ stored: Fighter, _ source: Fighter) -> Fighter {
        var merged = stored
        merged.ability = source.ability
        merged.abilityOn = stored.ability == source.ability ? stored.abilityOn : source.abilityOn
        merged.item = source.item
        for (key, value) in stored.evs {
            if var from = source.evs[key] {
                from.rank = value.rank
                merged.evs[key] = from
            }
        }
        return merged
    }

    private func refreshFoulPlay(_ atk: inout Fighter, defBaseA: Int) {
        guard var vsa = atk.evs[.vsa] else { return }
        vsa.real = Calc.realStat(defBaseA, vsa.points, vsa.nature)
        atk.evs[.vsa] = vsa
    }

    var defenderBaseRanks: [StatKey: Int] {
        Dictionary(uniqueKeysWithValues: Rules.rankKeys(.defender).map { ($0, defender.ev($0).rank) })
    }

    // MARK: - Calculation

    func scheduleCalc() {
        if calcScheduled { return }
        calcScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.calcScheduled = false
            self.recalc()
        }
    }

    func recalc() {
        calcScheduled = false
        let liveField = EnvironmentInfo.field(weather: weather, field: field)
        let atk = liveFighter(.attacker)
        let def0 = liveFighter(.defender)
        let hp = Calc.hpOf(def0)
        let stamina = def0.ability == "じきゅうりょく"
        let multiscale = def0.ability == "マルチスケイル"
        let multiscaleOn = multiscale && defender.abilityOn
        let offsets = defenderBaseRanks
        var taken = 0
        var damaged = false
        var liveResult: CalcResult?
        var bonusActive = 0
        var lockActive = false
        var entries: [CalcEntry] = []
        for (index, tab) in tabs.enumerated() {
            if tab.kind != .attack {
                let constant = Constants.breakdown(tab.constant, kind: tab.kind, max: hp.max)
                if tab.kind == .damage, constant.total > 0 { damaged = true }
                entries.append(CalcEntry(tabID: tab.id, kind: tab.kind, constant: constant))
                continue
            }
            let bonus = stamina ? taken : 0
            let abilityOverride: Bool? = multiscale ? (multiscaleOn && !damaged) : nil
            var entry: CalcEntry
            if index == active || tab.snapshot == nil {
                bonusActive = bonus
                lockActive = multiscale && damaged
                var def = bonus != 0 ? Calc.withDefRanks(def0, nil, bonus: bonus) : def0
                if let abilityOverride { def.abilityOn = abilityOverride }
                let result = Calc.calcDamage(atk, def, liveField)
                liveResult = result
                entry = CalcEntry(tabID: tab.id, kind: .attack, atk: atk, def: def, field: liveField, result: result)
            } else {
                var def = Calc.withDefRanks(def0, tab.defRanks ?? offsets, bonus: bonus)
                if let abilityOverride { def.abilityOn = abilityOverride }
                let snapshot = tab.snapshot ?? attacker
                let stored = fighter(snapshot, opponentBaseA: defender.base.a)
                let source = stored.name == atk.name ? atk : shared[stored.name]?.atk
                var merged = source.map { shareWith(stored, $0) } ?? stored
                refreshFoulPlay(&merged, defBaseA: defender.base.a)
                let tabField = EnvironmentInfo.field(weather: tab.weather, field: tab.field)
                entry = CalcEntry(tabID: tab.id, kind: .attack, atk: merged, def: def, field: tabField, result: Calc.calcDamage(merged, def, tabField))
            }
            if let result = entry.result, result.isOK {
                taken += result.hits.count
                damaged = true
            }
            entries.append(entry)
        }
        if liveResult == nil {
            liveResult = Calc.calcDamage(atk, def0, liveField)
        }
        var next = CalcOutput()
        next.entries = entries
        next.def = def0
        next.hp = hp
        next.multi = entries.count > 1
        next.summary = Calc.summarize(entries, hp, multi: entries.count > 1)
        next.liveAttacker = atk
        next.liveResult = liveResult
        next.defRankBonus = isConstantActive ? 0 : bonusActive
        next.multiscaleLocked = !isConstantActive && lockActive
        next.field = liveField
        next.revision = output.revision + 1
        output = next
        scheduleHistory()
        scheduleSession()
    }

    // MARK: - Pokemon

    private func selectPokemonCore(_ role: Role, _ name: String) {
        guard let pokemon = data.pokemons[name] else { return }
        var side = self.side(role)
        side.name = name
        side.shiny = false
        side.types = pokemon.types
        if role == .defender {
            for index in tabs.indices {
                tabs[index].defRanks = nil
            }
        }
        let stored = Storage.adjustments[name] ?? [:]
        for key in Rules.statKeys(role) {
            var value = side.ev(key)
            if key != .vsa {
                let adjustment = stored[key.rawValue] ?? Adjustment(points: Rules.defaultPoints(key), nature: 10)
                value.points = adjustment.points
                value.nature = adjustment.nature
            }
            value.rank = 0
            side.evs[key] = value
        }
        side.ability = pokemon.abilities.first ?? "なし"
        side.abilityOn = Rules.defaultAbilityOn(role, side.ability)
        if data.megaParent(name) != nil {
            side.item = "メガストーン"
        } else if side.item == "メガストーン" {
            side.item = "なし"
        }
        setSide(role, normalized(side))
        if role == .attacker { syncAttacker(resetCounts: false) }
    }

    private func selectAbilityIfCandidate(_ role: Role, _ ability: String) {
        guard side(role).pokemon?.abilities.contains(ability) == true else { return }
        var side = self.side(role)
        side.ability = ability
        side.abilityOn = Rules.defaultAbilityOn(role, ability)
        setSide(role, side)
        if role == .attacker { syncAttacker(resetCounts: false) }
    }

    func selectPokemon(_ role: Role, _ name: String, remember: Bool = true) {
        guard data.pokemons[name] != nil else { return }
        selectPokemonCore(role, name)
        applyUsageDefaults(role, name)
        if remember { Storage.rememberPokemon(name) }
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func topAttackMove(_ name: String) -> String? {
        usage?.pokemons[data.usageName(of: name)]?.moves.first { pair in
            guard let move = pair.name, let entry = data.moves[move] else { return false }
            return entry.category != "変化"
        }?.name
    }

    private func applyUsageDefaults(_ role: Role, _ name: String) {
        if role == .attacker, let move = topAttackMove(name) { selectMoveCore(move) }
        guard let entry = usage?.pokemons[name], data.usageName(of: name) == name else { return }
        if let ability = entry.abilities.first?.name { selectAbilityCore(role, ability) }
        let item = entry.items.first?.name
        selectItemCore(role, item.map { $0 != UsageLoader.megaStone ? $0 : "なし" } ?? "なし")
    }

    func setTypes(_ role: Role, _ types: [String]) {
        update(role) { $0.types = types }
    }

    func toggleType(_ role: Role, _ type: String) {
        update(role) { side in
            if side.types.contains(type) {
                side.types.removeAll { $0 == type }
            } else {
                side.types.append(type)
            }
        }
        Haptics.play(.selection)
    }

    func resetTypes(_ role: Role) {
        guard let pokemon = side(role).pokemon else { return }
        update(role) { $0.types = pokemon.types }
        Haptics.play(.light)
    }

    func pokemonOrder() -> [String] {
        let key = usage?.fetchedAt ?? 0
        if let cache = pokemonOrderCache, cache.key == key { return cache.list }
        var megas: [String: [String]] = [:]
        var roots: [(String, Int)] = []
        for (index, name) in data.pokemonOrder.enumerated() {
            if let parent = data.groupParent(name) {
                megas[parent, default: []].append(name)
            } else {
                roots.append((name, index))
            }
        }
        let rank = { (name: String) in self.usage?.pokemons[name]?.rank ?? Int.max }
        let list = roots
            .sorted { lhs, rhs in
                let left = rank(lhs.0)
                let right = rank(rhs.0)
                return left != right ? left < right : lhs.1 < rhs.1
            }
            .flatMap { [$0.0] + (megas[$0.0] ?? []) }
        pokemonOrderCache = (key, list)
        return list
    }

    // MARK: - Stats

    private func saveAdjustments(_ role: Role) {
        let side = self.side(role)
        guard data.pokemons[side.name] != nil else { return }
        var all = Storage.adjustments
        var entry = all[side.name] ?? [:]
        for key in Rules.statKeys(role) where key != .vsa {
            let value = side.ev(key)
            entry[key.rawValue] = Adjustment(points: value.points, nature: value.nature)
        }
        all[side.name] = entry
        Storage.adjustments = all
    }

    func setPoints(_ role: Role, _ key: StatKey, _ points: Int) {
        let clamped = max(0, min(32, points))
        guard side(role).ev(key).points != clamped else { return }
        update(role) { $0.evs[key, default: EVState(points: 0)].points = clamped }
        saveAdjustments(role)
    }

    func setNature(_ role: Role, _ key: StatKey, _ nature: Int) {
        guard side(role).ev(key).nature != nature else { return }
        update(role) { $0.evs[key, default: EVState(points: 0)].nature = nature }
        saveAdjustments(role)
        Haptics.play(.light)
    }

    func setRank(_ role: Role, _ key: StatKey, displayed: Int) {
        let clamped = Calc.clampRank(displayed)
        let bonus = role == .defender && key == .b ? output.defRankBonus : 0
        let base = Calc.clampRank(clamped - bonus)
        guard side(role).ev(key).rank != base else { return }
        update(role) { $0.evs[key, default: EVState(points: 0)].rank = base }
    }

    func stepRank(_ role: Role, _ key: StatKey, _ delta: Int) {
        let current = displayedRank(role, key)
        let next = Calc.clampRank(current + delta)
        guard next != current else {
            Haptics.play(.rigid)
            return
        }
        setRank(role, key, displayed: next)
        Haptics.play(.light)
    }

    func setHP(_ role: Role, ratio: Double) {
        let max = side(role).maxHP
        guard max > 0 else { return }
        let now = Swift.max(1, Swift.min(max, Int((ratio * Double(max)).rounded(.up))))
        guard side(role).hpNow != now else { return }
        update(role) { side in
            side.hpNow = now
            side.hpMax = max
        }
        Haptics.play(.selection)
    }

    // MARK: - Move

    private func syncAttacker(resetCounts: Bool) {
        var side = attacker
        let range = Calc.multiHitRange(side.move, side.ability)
        let axel = side.move == "トリプルアクセル"
        if range != nil || axel { side.crit = false }
        if let range {
            if resetCounts {
                side.hits = range.def
                side.crits = 0
            } else {
                side.hits = min(range.max, max(range.min, side.hits == 0 ? range.def : side.hits))
                side.crits = min(side.hits, max(0, side.crits))
            }
        }
        if axel, resetCounts { side.axel = Array(repeating: AxelRow(), count: 3) }
        setSide(.attacker, side)
    }

    private func selectMoveCore(_ name: String) {
        guard data.moves[name] != nil else { return }
        var side = attacker
        let old = side.move
        side.move = name
        side.powerUp = false
        side.rankBoost = 0
        if Calc.alwaysCritMoves.contains(name) {
            side.crit = true
        } else if Calc.alwaysCritMoves.contains(old) {
            side.crit = false
        }
        setSide(.attacker, normalized(side))
        syncAttacker(resetCounts: true)
    }

    func selectMove(_ name: String) {
        selectMoveCore(name)
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func toggleCrit() {
        guard !critLocked, multiHitRange == nil, !isAxel else { return }
        update(.attacker) { $0.crit.toggle() }
        Haptics.play(.light)
    }

    func togglePowerUp() {
        update(.attacker) { $0.powerUp.toggle() }
        Haptics.play(.light)
    }

    func setHits(_ value: Int) {
        guard let range = multiHitRange else { return }
        let hits = min(range.max, max(range.min, value))
        guard hits != attacker.hits else { return }
        update(.attacker) { side in
            side.hits = hits
            side.crits = min(hits, side.crits)
        }
        Haptics.play(.selection)
    }

    func setCrits(_ value: Int) {
        let crits = min(attacker.hits, max(0, value))
        guard crits != attacker.crits else { return }
        update(.attacker) { $0.crits = crits }
        Haptics.play(.selection)
    }

    func toggleAxelHit(_ index: Int) {
        guard attacker.axel.indices.contains(index) else { return }
        update(.attacker) { side in
            side.axel[index].hit.toggle()
            if !side.axel[index].hit { side.axel[index].crit = false }
        }
        Haptics.play(.light)
    }

    func toggleAxelCrit(_ index: Int) {
        guard attacker.axel.indices.contains(index), attacker.axel[index].hit else { return }
        update(.attacker) { $0.axel[index].crit.toggle() }
        Haptics.play(.light)
    }

    var rankBoostAuto: Int {
        Calc.rankSum(liveFighter(.attacker))
    }

    var rankBoostTotal: Int {
        min(Calc.rankBoostLimit, rankBoostAuto + attacker.rankBoost)
    }

    var showsRankBoost: Bool { Calc.rankBoostMoves.contains(attacker.move) }
    var showsFainted: Bool { attacker.move == "おはかまいり" }
    var showsFling: Bool { attacker.move == "なげつける" }

    func setRankBoostTotal(_ total: Int) {
        let value = max(0, min(Calc.rankBoostLimit, total))
        let auto = rankBoostAuto
        if value < auto {
            let key = Calc.rankBoostKey(attacker.move)
            update(.attacker) { side in
                side.evs[key, default: EVState(points: 0)].rank = value
                side.rankBoost = 0
            }
            return
        }
        let extra = value - auto
        guard extra != attacker.rankBoost else { return }
        update(.attacker) { $0.rankBoost = extra }
    }

    func setFainted(_ value: Int) {
        let next = min(100, max(0, value))
        guard next != attacker.fainted else { return }
        update(.attacker) { $0.fainted = next }
        Haptics.play(.selection)
    }

    func setFlingPower(_ value: Int) {
        guard value != attacker.flingPower else { return }
        update(.attacker) { $0.flingPower = value }
        Haptics.play(.selection)
    }

    func setMetronome(_ value: Int) {
        let next = min(6, max(1, value))
        guard next != attacker.metronome else { return }
        update(.attacker) { $0.metronome = next }
        Haptics.play(.selection)
    }

    // MARK: - Ability & item

    private func selectAbilityCore(_ role: Role, _ name: String) {
        var side = self.side(role)
        side.ability = name
        side.abilityOn = Rules.defaultAbilityOn(role, name)
        setSide(role, side)
        if role == .attacker { syncAttacker(resetCounts: false) }
    }

    func selectAbility(_ role: Role, _ name: String) {
        selectAbilityCore(role, name)
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func tapAbilityCandidate(_ role: Role, _ name: String) {
        selectAbility(role, side(role).ability == name ? "なし" : name)
    }

    func abilityButtonTapped(_ role: Role) {
        switch abilityControl(role) {
        case .toggle:
            guard !abilityDisabled(role) else { return }
            update(role) { $0.abilityOn.toggle() }
            Haptics.play(.light)
        case .changeType:
            guard let type = data.moves[attacker.move]?.type else { return }
            update(role) { $0.types = [type] }
            Haptics.play(.medium)
        case .rank:
            applyRankAbility(role)
        case .environment:
            let ability = side(role).ability
            if let key = Rules.weatherAbilities[ability] {
                setWeather(key)
            } else if let key = Rules.fieldAbilities[ability] {
                setField(key)
            }
        case .disguise:
            toggleDisguise()
        default:
            break
        }
    }

    private var disguiseTabIndex: Int? {
        let index = active - 1
        guard tabs.indices.contains(active), tabs[active].kind == .attack, tabs.indices.contains(index) else { return nil }
        let constant = tabs[index].constant
        guard tabs[index].kind == .damage,
              constant.ratios.filter({ $0.value > 0 }) == ["1/8": 1],
              constant.toxic.values.allSatisfy({ $0 == 0 }),
              constant.fixed == 0,
              constant.inputs.allSatisfy({ $0.count == 0 }) else { return nil }
        return index
    }

    private func toggleDisguise() {
        guard tabs.indices.contains(active), tabs[active].kind == .attack else { return }
        if let index = disguiseTabIndex {
            tabs.remove(at: index)
            active -= 1
            showToast("ばけのかわ：1/8ダメージを外しました")
        } else {
            var tab = newTab(.damage)
            tab.constant.ratios["1/8"] = 1
            tabs.insert(tab, at: active)
            active += 1
            showToast("ばけのかわ：直前に1/8ダメージを追加")
        }
        historyArmed = true
        Haptics.play(.medium)
        scheduleCalc()
    }

    private func applyRankAbility(_ role: Role) {
        let ability = side(role).ability
        var changes: [(Role, StatKey, Int)] = []
        for (target, key, delta) in Rules.rankAbilities[ability] ?? [] {
            let targetRole = target == .current ? role : role.other
            let reaction = target == .opponent && ability == "いかく" ? Rules.intimidateReactions[side(targetRole).ability] : nil
            for (k, d) in reaction ?? [(key, delta)] where Rules.rankKeys(targetRole).contains(k) {
                changes.append((targetRole, k, d))
            }
        }
        var order: [String] = []
        var totals: [String: Int] = [:]
        for (targetRole, key, delta) in changes {
            let current = displayedRank(targetRole, key)
            let next = Calc.clampRank(current + delta)
            let id = "\(targetRole == role ? "自分" : "相手")の\(Rules.rankStatNames[key] ?? key.statName)"
            if totals[id] == nil { order.append(id) }
            totals[id, default: 0] += next - current
            if next != current { setRank(targetRole, key, displayed: next) }
        }
        let text = order.compactMap { id -> String? in
            guard let value = totals[id], value != 0 else { return nil }
            return "\(id)\(value > 0 ? "+" : "")\(value)"
        }.joined(separator: "・")
        Haptics.play(text.isEmpty ? .warning : .medium)
        showToast("\(ability)：\(text.isEmpty ? "変化なし" : text)")
        historyArmed = true
        scheduleCalc()
    }

    private func selectItemCore(_ role: Role, _ name: String) {
        var side = self.side(role)
        side.item = name
        setSide(role, side)
    }

    func selectItem(_ role: Role, _ name: String) {
        selectItemCore(role, name)
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func toggleCondition(_ role: Role, _ name: String) {
        if role == .attacker, name == "やけど", burnLocked { return }
        update(role) { side in
            if side.conditions.contains(name) {
                side.conditions.removeAll { $0 == name }
            } else {
                side.conditions.append(name)
            }
        }
        Haptics.play(.light)
    }

    // MARK: - Environment

    private func setEnvironmentDirect(weather newWeather: String, field newField: String) {
        if newWeather != weather || newField != field { speedOverride = [:] }
        if newWeather != weather { weather = newWeather }
        if newField != field { field = newField }
    }

    func setWeather(_ key: String) {
        let next = key == weather ? "none" : key
        setEnvironmentDirect(weather: next, field: field)
        historyArmed = true
        Haptics.play(.selection)
        scheduleCalc()
    }

    func setField(_ key: String) {
        let next = key == field ? "none" : key
        setEnvironmentDirect(weather: weather, field: next)
        historyArmed = true
        Haptics.play(.selection)
        scheduleCalc()
    }

    // MARK: - Speed

    func toggleSpeedCondition(_ role: Role, _ name: String) {
        var set = speedConditions[role] ?? []
        if set.contains(name) { set.remove(name) } else { set.insert(name) }
        speedConditions[role] = set
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func speedAbilityActive(_ role: Role) -> Bool {
        Calc.speedAbilityActive(liveFighter(role), output.field.weather, output.field.terrain)
    }

    func toggleSpeedAbility(_ role: Role) {
        let name = side(role).ability
        guard let rule = Calc.speedAbilities[name] else { return }
        if rule.toggle {
            if abilityControl(role) == .toggle, !abilityDisabled(role) {
                update(role) { $0.abilityOn.toggle() }
            }
        } else {
            speedOverride[role] = SpeedOverride(name: name, on: !speedAbilityActive(role))
            historyArmed = true
            scheduleCalc()
        }
        Haptics.play(.light)
    }

    // MARK: - Snapshots & sharing between tabs

    private func snapshot(_ side: SideState) -> SideSnapshot {
        var snap = SideSnapshot()
        snap.name = side.name
        snap.types = side.types
        for key in Rules.statKeys(side.role) {
            snap.evs[key] = side.ev(key)
        }
        let ability = ShareCodec.abilityState(side)
        snap.ability = AbilitySnapshot(name: side.ability, on: ability.on, toggleable: ability.toggleable)
        snap.item = side.item
        snap.hp = (side.hpNow, side.maxHP)
        snap.conditions[side.role] = side.conditions
        if side.role == .attacker {
            let range = Calc.multiHitRange(side.move, side.ability)
            snap.weak = side.crit
            snap.powerUp = side.powerUp
            snap.move = side.move
            snap.counts = CountsSnapshot(
                hits: range != nil ? side.hits : nil,
                crits: range != nil ? side.crits : nil,
                axel: side.axel,
                metronome: side.metronome,
                rankBoost: side.rankBoost,
                fainted: side.fainted,
                flingPower: side.flingPower
            )
        }
        return snap
    }

    private func rememberShared(_ snap: SideSnapshot, atk: Fighter? = nil) {
        guard let name = snap.name, !name.isEmpty else { return }
        var entry = shared[name] ?? SharedBuild()
        for (key, value) in snap.evs where key != .vsa {
            entry.evs[key] = EVState(points: value.points, nature: value.nature)
        }
        if let ability = snap.ability?.name, !ability.isEmpty { entry.ability = ability }
        if let item = snap.item, !item.isEmpty { entry.item = item }
        if let atk { entry.atk = atk }
        shared[name] = entry
    }

    private func withShared(_ snap: SideSnapshot) -> SideSnapshot {
        guard let name = snap.name, let build = shared[name] else { return snap }
        var merged = snap
        for (key, value) in build.evs {
            guard var current = merged.evs[key] else { continue }
            current.points = value.points
            current.nature = value.nature
            merged.evs[key] = current
        }
        if let ability = build.ability, merged.ability?.name != ability {
            merged.ability = AbilitySnapshot(name: ability, on: false, toggleable: false)
        }
        if let item = build.item { merged.item = item }
        return merged
    }

    private func withShared(_ side: SideState) -> SideState {
        guard let build = shared[side.name] else { return side }
        var merged = side
        for (key, value) in build.evs {
            guard var current = merged.evs[key] else { continue }
            current.points = value.points
            current.nature = value.nature
            merged.evs[key] = current
        }
        if let ability = build.ability, merged.ability != ability {
            merged.ability = ability
            merged.abilityOn = Rules.defaultAbilityOn(merged.role, ability)
        }
        if let item = build.item { merged.item = item }
        return merged
    }

    private func restoreSide(_ role: Role, _ slot: SideSnapshot) {
        let defaults = roleDefaults[role] ?? SideSnapshot()
        if let name = slot.name, data.pokemons[name] != nil {
            selectPokemonCore(role, name)
            if let types = slot.types {
                var side = self.side(role)
                side.types = types
                setSide(role, side)
            }
        }
        if role == .attacker {
            var side = attacker
            side.crit = slot.weak ?? defaults.weak ?? false
            setSide(.attacker, side)
            if let move = slot.move ?? defaults.move, data.moves[move] != nil { selectMoveCore(move) }
            if showsPowerUp {
                var updated = attacker
                updated.powerUp = slot.powerUp ?? defaults.powerUp ?? false
                setSide(.attacker, updated)
            }
        }
        var side = self.side(role)
        for key in Rules.statKeys(role) {
            guard let value = slot.evs[key] ?? defaults.evs[key] else { continue }
            side.evs[key] = EVState(points: max(0, min(32, value.points)), nature: value.nature, rank: key.hasRank ? Calc.clampRank(value.rank) : 0)
        }
        if let ability = slot.ability ?? defaults.ability, !ability.name.isEmpty {
            side.ability = ability.name
            side.abilityOn = ability.toggleable ? ability.on : Rules.defaultAbilityOn(role, ability.name)
        }
        if let item = slot.item ?? defaults.item, !item.isEmpty { side.item = item }
        let allowed = Rules.conditions(role)
        side.conditions = (slot.conditions[role] ?? defaults.conditions[role] ?? []).filter { allowed.contains($0) }
        if role == .attacker, let counts = slot.counts {
            let range = Calc.multiHitRange(side.move, side.ability)
            if let range {
                if let hits = counts.hits { side.hits = min(range.max, max(range.min, hits)) }
                if let crits = counts.crits { side.crits = min(side.hits, max(0, crits)) }
            }
            side.axel = (0..<3).map { counts.axel.indices.contains($0) ? counts.axel[$0] : AxelRow() }
            side.metronome = min(6, max(1, counts.metronome))
            side.rankBoost = min(Calc.rankBoostLimit, max(0, counts.rankBoost))
            side.fainted = min(100, max(0, counts.fainted))
            side.flingPower = Calc.flingPowers.contains(counts.flingPower) ? counts.flingPower : 130
        }
        if let hp = slot.hp ?? defaults.hp {
            side.hpNow = hp.now
            side.hpMax = hp.max
        }
        setSide(role, normalized(side))
        if role == .attacker { syncAttacker(resetCounts: false) }
    }

    // MARK: - Tabs

    private func newTab(_ kind: TabKind) -> OrderTab {
        tabSequence += 1
        return OrderTab(id: tabSequence, kind: kind)
    }

    private func saveActiveTab() {
        guard tabs.indices.contains(active), tabs[active].kind == .attack else { return }
        tabs[active].defRanks = defenderBaseRanks
        tabs[active].snapshot = attacker
        tabs[active].weather = weather
        tabs[active].field = field
        rememberShared(snapshot(attacker), atk: liveFighter(.attacker))
    }

    private func applyDefenderRanks(_ ranks: [StatKey: Int]) {
        var side = defender
        for (key, rank) in ranks where Rules.rankKeys(.defender).contains(key) {
            side.evs[key, default: EVState(points: 0)].rank = Calc.clampRank(rank)
        }
        setSide(.defender, side)
    }

    private func loadTab(_ tab: OrderTab) {
        guard tab.kind == .attack, let snap = tab.snapshot else { return }
        setSide(.attacker, normalized(withShared(snap)))
        if let ranks = tab.defRanks { applyDefenderRanks(ranks) }
        setEnvironmentDirect(weather: tab.weather, field: tab.field)
    }

    func activate(_ index: Int) {
        guard index != active, tabs.indices.contains(index) else { return }
        saveActiveTab()
        active = index
        loadTab(tabs[index])
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func addTab(_ kind: TabKind) {
        saveActiveTab()
        var tab = newTab(kind)
        if kind == .attack {
            tab.defRanks = defenderBaseRanks
            tab.snapshot = attacker
            tab.weather = weather
            tab.field = field
            rememberShared(snapshot(attacker), atk: liveFighter(.attacker))
        }
        tabs.insert(tab, at: min(tabs.count, active + 1))
        active = min(tabs.count - 1, active + 1)
        historyArmed = true
        Haptics.play(.medium)
        scheduleCalc()
    }

    func removeTab(_ index: Int) {
        guard tabs.count > 1, tabs.indices.contains(index) else { return }
        if index == active {
            tabs.remove(at: index)
            active = min(index, tabs.count - 1)
            loadTab(tabs[active])
        } else {
            tabs.remove(at: index)
            if index < active { active -= 1 }
        }
        historyArmed = true
        Haptics.play(.medium)
        scheduleCalc()
    }

    func moveTab(_ index: Int, by step: Int) {
        if index != active { activate(index) }
        let target = active + step
        guard tabs.indices.contains(target) else { return }
        tabs.swapAt(active, target)
        active = target
        historyArmed = true
        Haptics.play(.light)
        scheduleCalc()
    }

    func reorderTab(from: Int, to: Int) {
        guard from != to, tabs.indices.contains(from), tabs.indices.contains(to) else { return }
        let activeID = tabs.indices.contains(active) ? tabs[active].id : nil
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
        if let activeID, let index = tabs.firstIndex(where: { $0.id == activeID }) {
            active = index
        }
        historyArmed = true
        Haptics.play(.selection)
        scheduleCalc()
    }

    func updateConstant(_ body: (inout ConstantState) -> Void) {
        guard tabs.indices.contains(active), tabs[active].kind != .attack else { return }
        body(&tabs[active].constant)
        historyArmed = true
        scheduleCalc()
    }

    func stepConstant(ratio key: String, _ step: Int) {
        updateConstant { $0.ratios[key] = max(0, ($0.ratios[key] ?? 0) + step) }
        Haptics.play(.light)
    }

    func stepConstant(toxic turn: Int, _ step: Int) {
        updateConstant { $0.toxic[turn] = max(0, ($0.toxic[turn] ?? 0) + step) }
        Haptics.play(.light)
    }

    func stepConstantFixed(_ step: Int) {
        updateConstant { $0.fixed = max(0, $0.fixed + step) }
        Haptics.play(.light)
    }

    func stepConstant(input id: UUID, _ step: Int) {
        updateConstant { state in
            guard let index = state.inputs.firstIndex(where: { $0.id == id }) else { return }
            state.inputs[index].count = max(0, state.inputs[index].count + step)
        }
        Haptics.play(.light)
    }

    func setConstantInput(_ id: UUID, value: Int) {
        updateConstant { state in
            guard let index = state.inputs.firstIndex(where: { $0.id == id }) else { return }
            state.inputs[index].value = max(0, value)
        }
    }

    func addConstantInput() -> UUID {
        let input = ConstantInput()
        updateConstant { $0.inputs.append(input) }
        Haptics.play(.light)
        return input.id
    }

    func removeConstantInput(_ id: UUID) {
        updateConstant { $0.inputs.removeAll { $0.id == id } }
        Haptics.play(.medium)
    }

    func setConstantSection(_ section: String) {
        guard tabs.indices.contains(active) else { return }
        tabs[active].constant.section = section
        Haptics.play(.selection)
    }

    func constantMaxHP() -> Int { defender.maxHP }

    // MARK: - Reset

    func resetAll() {
        historyTask?.cancel()
        speedConditions = [.attacker: [], .defender: []]
        speedOverride = [:]
        weather = "none"
        field = "none"
        shared = [:]
        swapSlots = [SideSnapshot(), SideSnapshot()]
        slotOfRole = [.attacker: 0, .defender: 1]
        attacker = normalized(SideState.initial(.attacker))
        defender = normalized(SideState.initial(.defender))
        selectMoveCore("げきりん")
        tabs = [newTab(.attack)]
        active = 0
        recalc()
        Haptics.play(.success)
        showToast("リセットしました")
    }

    // MARK: - Swap

    func swapSides() {
        guard !isConstantActive else { return }
        let attackerSlot = slotOfRole[.attacker] ?? 0
        let defenderSlot = slotOfRole[.defender] ?? 1
        swapSlots[attackerSlot].assign(snapshot(attacker))
        swapSlots[defenderSlot].assign(snapshot(defender))
        rememberShared(swapSlots[attackerSlot])
        rememberShared(swapSlots[defenderSlot])
        slotOfRole[.attacker] = defenderSlot
        slotOfRole[.defender] = attackerSlot
        restoreSide(.attacker, withShared(swapSlots[defenderSlot]))
        restoreSide(.defender, withShared(swapSlots[attackerSlot]))
        if let top = topAttackMove(attacker.name) { selectMoveCore(top) }
        historyArmed = true
        Haptics.play(.medium)
        scheduleCalc()
    }

    // MARK: - Share

    func collectShare() -> JSON {
        let tabList: [JSON] = tabs.enumerated().map { index, tab in
            if tab.kind == .attack {
                let isActive = index == active
                let snap = isActive ? attacker : (tab.snapshot ?? attacker)
                let environment = isActive
                    ? ShareCodec.packEnvironment(weather: weather, field: field)
                    : ShareCodec.packEnvironment(weather: tab.weather, field: tab.field)
                let ranks = isActive ? defenderBaseRanks : tab.defRanks
                return .array(ShareCodec.trimTail([ShareCodec.packSide(snap), JSON(environment), JSON(ShareCodec.packRanks(ranks))]))
            }
            return .array([JSON(tab.kind == .heel ? "h" : "d"), ShareCodec.packConstant(tab.constant)])
        }
        return .array(ShareCodec.trimTail([
            JSON(2),
            ShareCodec.packSide(defender),
            .array(tabList),
            JSON(active),
            JSON(ShareCodec.packEnvironment(weather: weather, field: field)),
        ]))
    }

    func shareURL() -> URL? {
        ShareCodec.encode(collectShare()).flatMap { ShareCodec.url(code: $0) }
    }

    @discardableResult
    func applyShareData(_ raw: JSON) -> Bool {
        guard let share = ShareCodec.expand(raw), !share.tabs.isEmpty else { return false }
        restoreSide(.defender, share.defender)
        tabs = share.tabs.map { item in
            var tab = newTab(item.kind)
            tab.weather = item.weather
            tab.field = item.field
            tab.defRanks = item.kind == .attack ? item.defRanks : nil
            tab.constant = item.constant
            return tab
        }
        for index in tabs.indices where tabs[index].kind == .attack {
            guard let snap = share.tabs[index].snapshot else { continue }
            active = index
            restoreSide(.attacker, withShared(snap))
            if let ranks = tabs[index].defRanks { applyDefenderRanks(ranks) }
            setEnvironmentDirect(weather: tabs[index].weather, field: tabs[index].field)
            saveActiveTab()
        }
        active = min(max(0, share.active), tabs.count - 1)
        if tabs[active].kind == .attack {
            loadTab(tabs[active])
        } else {
            setEnvironmentDirect(weather: share.weather, field: share.field)
        }
        recalc()
        return true
    }

    func open(_ url: URL) {
        guard let code = ShareCodec.code(from: url), !code.isEmpty else { return }
        openShare(code: code)
    }

    func openShare(code: String) {
        isLoadingShare = true
        historyMuted = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(250))
            let ok = ShareCodec.decode(code).map { self.applyShareData($0) } ?? false
            self.isLoadingShare = false
            if ok {
                Haptics.play(.success)
            } else {
                Haptics.play(.error)
                self.showToast("共有URLを読み込めませんでした")
            }
            try? await Task.sleep(for: .milliseconds(300))
            self.historyMuted = false
        }
    }

    // MARK: - History

    private func historyEntry() -> HistoryEntry? {
        let attacks = output.attacks
        guard let def = output.def, !def.name.isEmpty, !attacks.isEmpty else { return nil }
        var attackers: [String] = []
        var moves: [String] = []
        for entry in attacks {
            if let atk = entry.atk {
                if !attackers.contains(atk.name) { attackers.append(atk.name) }
                if !moves.contains(atk.move) { moves.append(atk.move) }
            }
        }
        return HistoryEntry(
            key: "\(attackers.joined(separator: "+"))>\(def.name)",
            attackers: attackers,
            defender: def.name,
            moves: moves,
            judge: output.summary.text,
            rate: output.summary.rate ?? "",
            data: collectShare().serialized(),
            time: Date().timeIntervalSince1970 * 1000
        )
    }

    private func scheduleHistory() {
        guard historyArmed, !historyMuted, !isLoadingShare else { return }
        historyTask?.cancel()
        historyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, let self, !self.historyMuted, !self.isLoadingShare else { return }
            self.recordHistory()
        }
    }

    private func recordHistory() {
        guard var entry = historyEntry() else { return }
        let list = Storage.history
        entry.pinned = list.first { $0.key == entry.key }?.pinned ?? false
        Storage.history = [entry] + list.filter { $0.key != entry.key }
        history = Storage.history
    }

    private func scheduleSession() {
        sessionTask?.cancel()
        sessionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            Storage.session = self.collectShare().serialized()
        }
    }

    func applyHistory(_ entry: HistoryEntry) {
        guard let json = try? JSON.parse(entry.data) else { return }
        historyTask?.cancel()
        historyMuted = true
        applyShareData(json)
        Haptics.play(.medium)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.historyMuted = false
        }
    }

    func togglePin(_ entry: HistoryEntry) {
        var list = Storage.history
        guard let index = list.firstIndex(where: { $0.key == entry.key }) else { return }
        list[index].pinned.toggle()
        Storage.history = list
        history = Storage.history
        Haptics.play(.light)
    }

    func deleteHistory(_ entry: HistoryEntry) {
        Storage.history = Storage.history.filter { $0.key != entry.key }
        history = Storage.history
        Haptics.play(.medium)
    }

    func historyShareURL(_ entry: HistoryEntry) -> URL? {
        guard let json = try? JSON.parse(entry.data) else { return nil }
        return ShareCodec.encode(json).flatMap { ShareCodec.url(code: $0) }
    }

    // MARK: - Toast

    func showToast(_ text: String) {
        let message = ToastMessage(text: text)
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2000))
            guard !Task.isCancelled, let self, self.toast?.id == message.id else { return }
            self.toast = nil
        }
    }
}
