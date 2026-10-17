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
}

struct Simulation {
    var state: GameState

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
        dailyTraining()
        dailyConstruction()
        syncDepots()
        dailyWar()
        scheduledNews()
        if Simulation.calendar.component(.day, from: currentDate) == 1 {
            monthlyTick()
        }
    }

    mutating func advance(days: Int) {
        guard days > 0 else { return }
        for _ in 0..<days {
            advanceDay()
        }
    }

    private mutating func monthlyTick() {
        updateMarket()
        for id in countryIDs {
            monthlyEconomy(id)
            monthlyPolitics(id)
            monthlyResearch(id)
            monthlyProjects(id)
        }
        monthlyDiplomacy()
        for id in countryIDs {
            if id == state.playerID {
                let atWar = isAtWar(id)
                if state.countries[id]?.autoProduction ?? false {
                    state.countries[id]?.autoAllocateProduction(atWar: atWar)
                }
            } else {
                runAI(id)
            }
            recordSnapshot(id)
        }
        monthlyEvents()
        aiFortify()
        aiIndustry()
        refreshIndustryBonuses()
        aiNuclearDecisions()
        monthlyGoals()
        monthlyAchievements()
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
