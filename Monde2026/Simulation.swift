import Foundation

// =============================================================
//  Simulation.swift
//  L'horloge du jeu, l'état global, l'IA économique et militaire
//  des pays non joués, les actions du joueur et la sauvegarde.
//  (La diplomatie est dans Diplomacy.swift.)
// =============================================================

struct War: Codable, Identifiable {
    let id: Int
    var name: String
    var attackers: [CountryID]
    var defenders: [CountryID]
    let startDay: Int
    var isActive: Bool
    var lastNet: Double       // territoire net tenu par les attaquants le mois dernier
    var momentum: Double      // évolution sur le dernier mois (positif = attaquants avancent)
}

struct GameState: Codable {
    var day: Int
    var countries: [CountryID: Country]
    var wars: [War]
    /// occupation[victime][occupant] : zones tenues pendant une guerre.
    var occupation: [CountryID: [CountryID: Double]]
    /// annexation[victime][occupant] : zones gardées après une paix (ou contrôlées de longue date).
    var annexation: [CountryID: [CountryID: Double]]
    var prices: [Resource: Double]
    var playerID: CountryID?
    var rng: SeededRandom
    var nextWarID: Int
    var events: [GameEvent]
    var nextEventID: Int
    var initialWorldGDP: Double

    // Diplomatie
    var relations: [String: Double]
    var relationMemory: [String: Double]
    var treaties: [Treaty]
    var nextTreatyID: Int
    var blocs: [Bloc]
    var claims: [Claim]
    var warPlans: [WarPlan]
    var proposals: [Proposal]
    var nextProposalID: Int
    var worldTension: Double

    // Partie
    var difficulty: Difficulty
    var record: PlayerRecord?
    var pendingEvents: [PendingEvent]
    var nextPendingEventID: Int
    var achievements: Set<String>
    var firedNews: Set<String>

    // Guerre région par région
    var armies: [Army]
    var nextArmyID: Int
    var control: [Int: CountryID]          // région -> pays qui la tient (si ce n'est pas son pays d'origine)
    var annexedProvinces: Set<Int>
    var provinceOrg: [Int: Double]         // organisation des garnisons après un combat
    var autoArmies: Bool                   // le joueur laisse l'IA commander ses armées
    var battles: [Int: Battle] = [:]       // batailles en cours, par région disputée
    var forts: [Int: Int] = [:]            // région -> niveau du fort (1…5)
    var bases: Set<Int> = []               // régions avec une base militaire
    var constructions: [ConstructionJob] = []
    var nextConstructionID = 1
    var pauseRequested = false             // l'interface doit mettre en pause (guerre qui nous concerne)
    var complexes: [Int: [BuildingKind: Int]] = [:]    // région -> complexes industriels
    var industryCache: [CountryID: IndustryBonus] = [:]
    var depots: [Int: [DivisionType: Int]] = [:]        // divisions du joueur en réserve, par base
    var proxyConquests: [Int: CountryID] = [:]          // régions prises par nos troupes pour un autre pays
    var jointPlans: [JointPlan] = []                    // attaques conjointes prévues
    var leases: [FactoryLease] = []                     // usines prêtées
    var covertAid: [CovertAid] = []                     // aides secrètes en cours
    var bombardments: [Int: Bombardment] = [:]          // régions sous les bombes
    var nextPlanID = 1
    var fronts: [FrontOrder] = []                       // groupes d'armées affectés à une ligne de front
    var nextFrontID = 1
    var summits: [String: Int] = [:]                    // dernier sommet entre deux pays (jour)
    var reports: [BattleReport] = []                    // rapports après bataille (les plus récents)
    var nextReportID = 1
}

/// Mémoire de calcul (ennemis, alliés, régions tenues, troupes par région), valable tant que ce dont elle
/// dépend ne change pas. Ce sont les questions les plus posées par le moteur. Protégée par un verrou :
/// la carte peut être calculée en arrière-plan pendant que l'interface interroge le même état.
final class RelationCache: @unchecked Sendable {
    private let lock = NSLock()
    private var key: [Int] = []
    private var enemies: [CountryID: Set<CountryID>] = [:]
    private var allies: [CountryID: Set<CountryID>] = [:]
    private var controlKey = -1
    private var controlled: [CountryID: [Int]] = [:]
    private var troopsKey = -1
    private var troops: [Int: Int] = [:]
    /// Mesure fine (autotest de performance seulement).
    var profiling = false
    var timings: [String: Double] = [:]

    func reset() {
        lock.lock()
        key = []
        enemies = [:]
        allies = [:]
        lock.unlock()
    }

    private func camp(_ id: CountryID, key k: [Int], enemies wantEnemies: Bool, compute: () -> Set<CountryID>) -> Set<CountryID> {
        lock.lock()
        if k != key { key = k; enemies = [:]; allies = [:] }
        if let c = wantEnemies ? enemies[id] : allies[id] { lock.unlock(); return c }
        lock.unlock()
        let r = compute()
        lock.lock()
        if k == key { if wantEnemies { enemies[id] = r } else { allies[id] = r } }
        lock.unlock()
        return r
    }

    func enemies(_ id: CountryID, key k: [Int], compute: () -> Set<CountryID>) -> Set<CountryID> {
        camp(id, key: k, enemies: true, compute: compute)
    }

    func allies(_ id: CountryID, key k: [Int], compute: () -> Set<CountryID>) -> Set<CountryID> {
        camp(id, key: k, enemies: false, compute: compute)
    }

    func controlled(key k: Int, compute: () -> [CountryID: [Int]]) -> [CountryID: [Int]] {
        lock.lock()
        if k == controlKey { let c = controlled; lock.unlock(); return c }
        lock.unlock()
        let r = compute()
        lock.lock()
        controlKey = k
        controlled = r
        lock.unlock()
        return r
    }

    func troops(key k: Int, compute: () -> [Int: Int]) -> [Int: Int] {
        lock.lock()
        if k == troopsKey { let c = troops; lock.unlock(); return c }
        lock.unlock()
        let r = compute()
        lock.lock()
        troopsKey = k
        troops = r
        lock.unlock()
        return r
    }
}

struct Simulation {
    var state: GameState
    /// Chaque calcul de jours a sa propre mémoire (jamais partagée entre deux fils d'exécution).
    var relCache = RelationCache()

    /// Mesure le temps d'une étape quand l'autotest le demande (sinon, simple appel).
    mutating func timed(_ name: String, _ body: (inout Simulation) -> Void) {
        guard relCache.profiling else { body(&self); return }
        let t0 = Date()
        body(&self)
        relCache.timings[name, default: 0] += Date().timeIntervalSince(t0)
    }

    /// Empreinte de ce qui décide des camps.
    func relationKey() -> [Int] {
        var active = 0, sides = 0
        for w in state.wars where w.isActive {
            active += 1
            sides += w.attackers.count * 31 + w.defenders.count
        }
        var members = 0
        for b in state.blocs { members += b.members.count }
        return [state.day, state.wars.count, active, sides, state.treaties.count, state.nextTreatyID, state.blocs.count, members]
    }

    /// Régions tenues par chaque pays (recalculé seulement quand une région change de mains).
    func controlledMap() -> [CountryID: [Int]] {
        var h = Hasher()
        h.combine(state.control.count)
        for (k, v) in state.control { h.combine(k &* 31 &+ v.hashValue) }
        return relCache.controlled(key: h.finalize()) {
            var out: [CountryID: [Int]] = [:]
            for p in ProvinceMap.all { out[state.control[p.id] ?? p.country, default: []].append(p.id) }
            return out
        }
    }

    // MARK: - Calendrier

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }()

    static let startDate: Date = {
        Simulation.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()
    }()

    var currentDate: Date {
        Simulation.calendar.date(byAdding: .day, value: state.day, to: Simulation.startDate) ?? Simulation.startDate
    }

    var dateString: String {
        let style = Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "fr_FR"),
                                     calendar: Simulation.calendar, timeZone: Simulation.calendar.timeZone)
        return currentDate.formatted(style)
    }

    func dateString(forDay day: Int) -> String {
        let date = Simulation.calendar.date(byAdding: .day, value: day, to: Simulation.startDate) ?? Simulation.startDate
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Locale(identifier: "fr_FR"),
                                     calendar: Simulation.calendar, timeZone: Simulation.calendar.timeZone)
        return date.formatted(style)
    }

    /// Pays triés : l'ordre est fixe, donc la partie est reproductible.
    var countryIDs: [CountryID] { state.countries.keys.sorted() }

    // MARK: - Nouvelle partie

    init(playerID: CountryID? = nil, difficulty: Difficulty = .normal, seed: UInt64 = 2026) {
        state = GameState(day: 0, countries: WorldData.makeCountries(), wars: [], occupation: [:], annexation: [:],
                          prices: [:], playerID: playerID, rng: SeededRandom(seed: seed), nextWarID: 1,
                          events: [], nextEventID: 1, initialWorldGDP: 1,
                          relations: [:], relationMemory: [:], treaties: [], nextTreatyID: 1, blocs: [],
                          claims: [], warPlans: [], proposals: [], nextProposalID: 1, worldTension: 0,
                          difficulty: difficulty, record: nil, pendingEvents: [], nextPendingEventID: 1,
                          achievements: [], firedNews: [],
                          armies: [], nextArmyID: 1, control: [:], annexedProvinces: [], provinceOrg: [:],
                          autoArmies: false)
        for r in Resource.allCases {
            state.prices[r] = 1
        }
        calibrateResources()
        setupPolitics()
        setupTechnologies()
        setupWorldRelations()
        initializeControl()
        setupBases()
        setupIndustry()
        refreshIndustryBonuses()
        deployInitialArmies()
        if let p = playerID { formStartingArmies(p) }
        state.initialWorldGDP = countryIDs.reduce(0.0) { $0 + effectiveGDP($1) }
        for id in countryIDs {
            let atWar = isAtWar(id)
            guard var c = state.countries[id] else { continue }
            c.autoAllocateProduction(atWar: atWar)
            for i in c.productionLines.indices {
                c.productionLines[i].efficiency = 0.8   // lignes déjà rodées en début de partie
            }
            state.countries[id] = c
        }
        updateMarket()
        calibrateEconomy()
        calibratePolitics()
        for id in countryIDs {
            recordSnapshot(id)
        }
        setupGoals()
        addEvent("1er janvier 2026 : le monde retient son souffle.", important: false)
    }

    // MARK: - Horloge

    mutating func advanceDay() {
        state.day += 1
        dailyMilitary()
        dailyArmies()
        if state.day % 2 == 0 { manageFronts() }
        dailyTraining()
        dailyConstruction()
        syncDepots()
        dailyOperations()
        dailyWar()
        scheduledNews()
        if Simulation.calendar.component(.day, from: currentDate) == 1 {
            monthlyTick()
        }
    }

    /// Même chose qu'`advanceDay`, en mesurant chaque étape (test de performance).
    mutating func advanceDayProfiled(_ t: inout [String: Double]) {
        func time(_ name: String, _ body: (inout Simulation) -> Void) {
            let t0 = Date()
            body(&self)
            t[name, default: 0] += Date().timeIntervalSince(t0)
        }
        state.day += 1
        time("militaire") { $0.dailyMilitary() }
        time("armées") { $0.dailyArmies() }
        if state.day % 2 == 0 { time("fronts") { $0.manageFronts() } }
        time("entraînement") { $0.dailyTraining() }
        time("chantiers") { $0.dailyConstruction() }
        time("réserves") { $0.syncDepots() }
        time("opérations") { $0.dailyOperations() }
        time("guerre") { $0.dailyWar() }
        time("nouvelles") { $0.scheduledNews() }
        if Simulation.calendar.component(.day, from: currentDate) == 1 {
            time("mois") { $0.monthlyTick(profile: &t) }
        }
    }

    mutating func advance(days: Int) {
        guard days > 0 else { return }
        relCache = RelationCache()
        for _ in 0..<days {
            advanceDay()
        }
    }

    private mutating func monthlyTick() {
        var ignored: [String: Double] = [:]
        monthlyTick(profile: &ignored)
    }

    private mutating func monthlyTick(profile t: inout [String: Double]) {
        func time(_ name: String, _ body: (inout Simulation) -> Void) {
            let t0 = Date()
            body(&self)
            t["m." + name, default: 0] += Date().timeIntervalSince(t0)
        }
        time("marché") { $0.updateMarket() }
        time("pays") { sim in
            for id in sim.countryIDs {
                sim.monthlyEconomy(id)
                sim.monthlyPolitics(id)
                sim.monthlyResearch(id)
                sim.monthlyProjects(id)
            }
        }
        time("diplomatie") { $0.monthlyDiplomacy() }
        time("ia") { sim in
            for id in sim.countryIDs {
                if id == sim.state.playerID {
                    let atWar = sim.isAtWar(id)
                    if sim.state.countries[id]?.autoProduction ?? false {
                        sim.state.countries[id]?.autoAllocateProduction(atWar: atWar)
                    }
                } else {
                    sim.runAI(id)
                }
                sim.recordSnapshot(id)
            }
        }
        time("événements") { $0.monthlyEvents() }
        time("forts") { $0.aiFortify() }
        time("industrie") { sim in
            sim.aiIndustry()
            sim.refreshIndustryBonuses()
        }
        time("intrigues") { $0.monthlyIntrigue() }
        time("nucléaire") { $0.aiNuclearDecisions() }
        time("objectifs") { sim in
            sim.monthlyGoals()
            sim.monthlyAchievements()
        }
    }

    mutating func recordSnapshot(_ id: CountryID) {
        guard let c = state.countries[id] else { return }
        let gdp = effectiveGDP(id)
        let snap = Snapshot(day: state.day, gdp: gdp, growth: c.growth, debtRatio: c.debt / max(gdp, 0.1),
                            inflation: c.inflation, unemployment: c.unemployment, divisions: c.divisionCount)
        state.countries[id]?.history.append(snap)
        if (state.countries[id]?.history.count ?? 0) > 120 {
            state.countries[id]?.history.removeFirst()
        }
    }

    mutating func addEvent(_ text: String, important: Bool = false) {
        state.events.append(GameEvent(id: state.nextEventID, day: state.day, text: text, important: important))
        state.nextEventID += 1
        if state.events.count > 300 {
            state.events.removeFirst(state.events.count - 300)
        }
    }

    // MARK: - IA économique et militaire des pays non joués

    private mutating func runAI(_ id: CountryID) {
        let atWar = isAtWar(id)
        let homeFront = isFightingAtHome(id)
        let occupied = occupiedFraction(id)
        let threatened = state.warPlans.contains { $0.target == id }
        let gdp = effectiveGDP(id)
        let b = projectedBudget(id)
        // Posture : offensive si notre camp domine, défensive s'il est dominé.
        var posture = WarPosture.balanced
        var sideRatio = 1.0
        if let war = wars(of: id).first, let sides = warSide(of: id, in: war) {
            sideRatio = sidePower(sides.mine) / max(sidePower(sides.enemy), 1)
            posture = sideRatio > 1.3 ? .offensive : (sideRatio < 0.8 ? .defensive : .balanced)
        }
        guard var c = state.countries[id] else { return }

        // Budget : contenir le déficit (plus de tolérance en guerre).
        let deficit = -b.balance * 12 / gdp
        let limit = atWar ? 0.10 : 0.045
        if deficit > limit {
            c.budget.social = max(0.03, c.budget.social - 0.002)
            c.budget.taxRate = min(c.baseTaxRate + 0.05, c.budget.taxRate + 0.002)
        } else if deficit < 0.01 && c.budget.taxRate > c.baseTaxRate {
            c.budget.taxRate = max(c.baseTaxRate, c.budget.taxRate - 0.002)
        }

        if atWar || threatened {
            if c.budget.military < 0.08 { c.budget.military += 0.002 }
            if c.economyMode == .civilian { c.economyMode = .partialMobilization }
            if homeFront && occupied > 0.05 && c.economyMode == .partialMobilization { c.economyMode = .warEconomy }
            if atWar && c.availableManpower < c.activePersonnel * 0.1, let next = c.conscription.next {
                c.conscription = next
                addEvent("\(c.name) passe à : \(next.name).")
            }
            // Nouvelles divisions si les existantes sont bien équipées et que notre camp ne domine pas déjà.
            if c.availableManpower > 24 && c.divisionFill > 0.75 && sideRatio < 1.5 {
                let count = min(20, Int(c.availableManpower * 0.15 / DivisionType.infantry.stats.manpower))
                if count > 0 {
                    c.activePersonnel += Double(count) * DivisionType.infantry.stats.manpower
                    c.startTraining(.infantry, count: count)
                }
            }
            // Menacé : rappel des réservistes.
            if threatened && !atWar && c.reservePersonnel >= 24 {
                let count = Int(min(c.reservePersonnel * 0.3, 240) / 12)
                if count > 0 {
                    c.reservePersonnel -= Double(count) * 12
                    c.activePersonnel += Double(count) * 12
                    c.startTraining(.infantry, count: count, days: 30)
                }
            }
        } else {
            if c.economyMode != .civilian { c.economyMode = .civilian }
            if c.budget.military > c.baseMilitaryBudget * 1.05 { c.budget.military -= 0.001 }
        }
        if c.autoProduction {
            c.autoAllocateProduction(atWar: atWar)
        }
        c.posture = posture
        state.countries[id] = c
    }

    // MARK: - Actions du joueur (économie et armée)

    mutating func setBudget(_ budget: Budget, for id: CountryID) {
        var b = budget
        b.taxRate = b.taxRate.clamped(0.05, 0.70)
        b.military = b.military.clamped(0, 0.40)
        b.infrastructure = b.infrastructure.clamped(0, 0.15)
        b.research = b.research.clamped(0, 0.10)
        b.social = b.social.clamped(0, 0.50)
        state.countries[id]?.budget = b
    }

    mutating func setConscription(_ law: ConscriptionLaw, for id: CountryID) {
        state.countries[id]?.conscription = law
    }

    mutating func setPosture(_ posture: WarPosture, for id: CountryID) {
        state.countries[id]?.posture = posture
    }

    mutating func setEconomyMode(_ mode: EconomyMode, for id: CountryID) {
        state.countries[id]?.economyMode = mode
    }

    mutating func queueConstruction(_ kind: ConstructionKind, count: Int = 1, for id: CountryID) {
        guard var c = state.countries[id], count > 0 else { return }
        for _ in 0..<count {
            c.constructionQueue.append(ConstructionProject(id: c.nextProjectID, kind: kind, progress: 0))
            c.nextProjectID += 1
        }
        state.countries[id] = c
    }

    mutating func removeConstruction(_ projectID: Int, for id: CountryID) {
        state.countries[id]?.constructionQueue.removeAll { $0.id == projectID }
    }

    /// Fixe le nombre d'usines sur un équipement et passe la production en manuel.
    mutating func setProduction(_ equipment: EquipmentType, factories: Double, for id: CountryID) {
        guard var c = state.countries[id] else { return }
        var allocation: [EquipmentType: Double] = [:]
        for line in c.productionLines {
            allocation[line.equipment] = line.factories
        }
        let capacity = equipment.isNaval ? c.dockyards : c.militaryFactories
        var used = 0.0
        for (e, f) in allocation where e != equipment && e.isNaval == equipment.isNaval {
            used += f
        }
        allocation[equipment] = max(0, min(factories, capacity - used))
        c.autoProduction = false
        c.setProductionAllocation(allocation)
        state.countries[id] = c
    }

    mutating func setAutoProduction(_ enabled: Bool, for id: CountryID) {
        let atWar = isAtWar(id)
        state.countries[id]?.autoProduction = enabled
        if enabled {
            state.countries[id]?.autoAllocateProduction(atWar: atWar)
        }
    }

    /// Lève et entraîne de nouvelles divisions. Retourne false si la main-d'œuvre manque.
    @discardableResult
    mutating func recruit(_ type: DivisionType, count: Int, for id: CountryID, base: Int? = nil) -> Bool {
        guard count > 0, var c = state.countries[id] else { return false }
        let men = Double(count) * type.stats.manpower
        guard men <= c.availableManpower else { return false }
        c.activePersonnel += men
        let days = Int(Double(type.trainingDays) * (state.industryCache[id]?.training ?? 1))
        c.startTraining(type, count: count, days: max(10, days))
        if let b = base { c.training[c.training.count - 1].base = b }
        state.countries[id] = c
        return true
    }

    /// Démobilise des divisions (rend les hommes à l'économie).
    mutating func disband(_ type: DivisionType, count: Int, for id: CountryID) {
        guard var c = state.countries[id], let current = c.divisions[type], current > 0 else { return }
        let n = min(count, current)
        c.divisions[type] = current - n
        c.activePersonnel = max(c.supportPersonnel, c.activePersonnel - Double(n) * type.stats.manpower)
        state.countries[id] = c
    }

    /// Rappelle des réservistes : divisions d'infanterie prêtes en 30 jours.
    @discardableResult
    mutating func mobilizeReserves(thousands: Double, for id: CountryID) -> Int {
        guard var c = state.countries[id] else { return 0 }
        let size = DivisionType.infantry.stats.manpower
        let count = Int(min(thousands, c.reservePersonnel) / size)
        guard count > 0 else { return 0 }
        let men = Double(count) * size
        c.reservePersonnel -= men
        c.activePersonnel += men
        c.startTraining(.infantry, count: count, days: 30)
        state.countries[id] = c
        addEvent("\(c.name) mobilise \(count) divisions de réservistes.", important: id == state.playerID)
        return count
    }

    // MARK: - Sauvegarde

    func saveData() throws -> Data {
        try JSONEncoder().encode(state)
    }

    init(saveData: Data) throws {
        state = try JSONDecoder().decode(GameState.self, from: saveData)
    }

    // MARK: - Indicateurs pratiques pour l'interface

    func name(_ id: CountryID) -> String {
        state.countries[id]?.name ?? id
    }

    func rankedCountries() -> [Country] {
        let gdps = Dictionary(uniqueKeysWithValues: countryIDs.map { ($0, effectiveGDP($0)) })
        return state.countries.values.sorted { (gdps[$0.id] ?? 0) > (gdps[$1.id] ?? 0) }
    }

    var activeWarsList: [War] {
        state.wars.filter { $0.isActive }
    }

    func wars(of id: CountryID) -> [War] {
        state.wars.filter { $0.isActive && ($0.attackers.contains(id) || $0.defenders.contains(id)) }
    }

    /// Part du territoire tenue par un camp dans une guerre.
    func heldShare(of victims: [CountryID], by occupiers: [CountryID]) -> [(CountryID, Double)] {
        victims.compactMap { v -> (CountryID, Double)? in
            let held = occupiers.reduce(0.0) { $0 + (state.occupation[v]?[$1] ?? 0) }
            return held > 0.0005 ? (v, held) : nil
        }
    }
}
