import Foundation

// =============================================================
//  Tech.swift
//  L'arbre technologique : 20 technologies civiles et
//  militaires, les points de recherche et leurs effets.
// =============================================================

enum TechCategory: String, CaseIterable {
    case economy = "Économie"
    case military = "Armée"
    case society = "Société"
}

enum TechID: String, Codable, CaseIterable {
    // Économie
    case automation, appliedAI, advancedChips, shaleExtraction, smartGrid, precisionAgriculture, smallReactors, quantumComputing
    // Armée
    case professionalArmy, combatMedicine, autonomousDrones, electronicWarfare, missileDefense, hypersonic,
         nextGenArmor, stealthAircraft, militarySatellites, cyberWarfare
    // Société
    case digitalState, informationControl

    var name: String {
        switch self {
        case .automation: return "Automatisation industrielle"
        case .appliedAI: return "Intelligence artificielle"
        case .advancedChips: return "Puces de pointe"
        case .shaleExtraction: return "Nouveaux gisements"
        case .smartGrid: return "Réseaux électriques intelligents"
        case .precisionAgriculture: return "Agriculture de précision"
        case .smallReactors: return "Petits réacteurs nucléaires"
        case .quantumComputing: return "Informatique quantique"
        case .professionalArmy: return "Armée professionnelle"
        case .combatMedicine: return "Médecine de guerre"
        case .autonomousDrones: return "Drones autonomes"
        case .electronicWarfare: return "Guerre électronique"
        case .missileDefense: return "Défense antimissile"
        case .hypersonic: return "Missiles hypersoniques"
        case .nextGenArmor: return "Blindés nouvelle génération"
        case .stealthAircraft: return "Avions furtifs"
        case .militarySatellites: return "Satellites militaires"
        case .cyberWarfare: return "Cyberguerre"
        case .digitalState: return "État numérique"
        case .informationControl: return "Maîtrise de l'information"
        }
    }

    var effect: String {
        switch self {
        case .automation: return "+10 % de construction et de production militaire, +0,2 pt de croissance."
        case .appliedAI: return "+0,3 pt de croissance, +10 % de recherche."
        case .advancedChips: return "+30 % de production de semi-conducteurs, +5 % de production militaire."
        case .shaleExtraction: return "+15 % de production de pétrole et de gaz."
        case .smartGrid: return "−15 % de besoins en pétrole, −10 % en gaz."
        case .precisionAgriculture: return "+15 % de production agricole."
        case .smallReactors: return "−15 % de besoins en gaz, +0,2 pt de croissance."
        case .quantumComputing: return "+20 % de recherche, +0,2 pt de croissance."
        case .professionalArmy: return "+8 % d'efficacité au combat."
        case .combatMedicine: return "−20 % de pertes humaines."
        case .autonomousDrones: return "Drones 60 % plus efficaces."
        case .electronicWarfare: return "Les drones ennemis perdent 30 % d'efficacité."
        case .missileDefense: return "+20 % d'interception des missiles."
        case .hypersonic: return "Vos missiles échappent mieux aux défenses (−15 % d'interception)."
        case .nextGenArmor: return "+12 % d'attaque pour les divisions blindées et mécanisées."
        case .stealthAircraft: return "+25 % de puissance aérienne."
        case .militarySatellites: return "+15 % de projection lointaine, +5 % au combat."
        case .cyberWarfare: return "Débloque les cyberattaques contre vos rivaux."
        case .digitalState: return "+0,03 de stabilité, +0,1 pt de croissance."
        case .informationControl: return "Les campagnes de communication sont deux fois plus efficaces."
        }
    }

    var category: TechCategory {
        switch self {
        case .automation, .appliedAI, .advancedChips, .shaleExtraction, .smartGrid, .precisionAgriculture,
             .smallReactors, .quantumComputing:
            return .economy
        case .digitalState, .informationControl:
            return .society
        default:
            return .military
        }
    }

    /// Coût en points de recherche.
    var cost: Double {
        switch self {
        case .automation, .professionalArmy, .combatMedicine, .shaleExtraction, .precisionAgriculture, .digitalState:
            return 400
        case .appliedAI, .smartGrid, .autonomousDrones, .electronicWarfare, .missileDefense, .militarySatellites,
             .cyberWarfare, .informationControl, .nextGenArmor:
            return 800
        case .advancedChips, .smallReactors, .hypersonic, .stealthAircraft:
            return 1500
        case .quantumComputing:
            return 2500
        }
    }

    var requires: [TechID] {
        switch self {
        case .appliedAI: return [.automation]
        case .advancedChips: return [.automation]
        case .quantumComputing: return [.appliedAI, .advancedChips]
        case .smallReactors: return [.smartGrid]
        case .autonomousDrones: return [.appliedAI]
        case .electronicWarfare: return [.professionalArmy]
        case .missileDefense: return [.militarySatellites]
        case .hypersonic: return [.militarySatellites]
        case .nextGenArmor: return [.professionalArmy]
        case .stealthAircraft: return [.advancedChips]
        case .cyberWarfare: return [.appliedAI]
        case .informationControl: return [.digitalState]
        default: return []
        }
    }
}

/// Technologies déjà maîtrisées en 2026.
enum TechData {
    static let extra: [CountryID: [TechID]] = [
        "USA": [.appliedAI, .stealthAircraft, .missileDefense, .advancedChips, .cyberWarfare, .autonomousDrones,
                .nextGenArmor, .shaleExtraction, .militarySatellites, .digitalState],
        "CHN": [.appliedAI, .hypersonic, .stealthAircraft, .cyberWarfare, .militarySatellites, .digitalState,
                .informationControl],
        "RUS": [.hypersonic, .electronicWarfare, .cyberWarfare, .militarySatellites, .informationControl],
        "ISR": [.missileDefense, .cyberWarfare, .autonomousDrones, .appliedAI, .militarySatellites],
        "UKR": [.autonomousDrones, .electronicWarfare, .appliedAI],
        "TUR": [.autonomousDrones],
        "IRN": [.cyberWarfare, .informationControl],
        "PRK": [.cyberWarfare, .informationControl],
        "KOR": [.advancedChips, .nextGenArmor, .digitalState],
        "TWN": [.advancedChips, .missileDefense],
        "JPN": [.stealthAircraft, .missileDefense],
        "GBR": [.stealthAircraft, .cyberWarfare],
        "FRA": [.cyberWarfare, .missileDefense],
        "DEU": [.nextGenArmor],
        "IND": [.militarySatellites],
        "AUS": [.stealthAircraft], "NLD": [.stealthAircraft, .advancedChips], "NOR": [.stealthAircraft],
        "DNK": [.stealthAircraft, .digitalState], "ITA": [.stealthAircraft], "POL": [.nextGenArmor],
        "EST": [.digitalState, .cyberWarfare], "SGP": [.digitalState], "ARE": [.digitalState], "AZE": [.autonomousDrones]
    ]
}

extension Country {
    func has(_ tech: TechID) -> Bool { techs.contains(tech) }

    func canResearch(_ tech: TechID) -> Bool {
        !techs.contains(tech) && tech.requires.allSatisfy { techs.contains($0) }
    }

    /// Bonus de croissance des technologies (calibré au départ, donc seuls les progrès comptent).
    var techGrowthBonus: Double {
        var g = 0.0
        if has(.automation) { g += 0.002 }
        if has(.appliedAI) { g += 0.003 }
        if has(.advancedChips) { g += 0.002 }
        if has(.smallReactors) { g += 0.002 }
        if has(.quantumComputing) { g += 0.002 }
        if has(.digitalState) { g += 0.001 }
        return g
    }

    var techProductionFactor: Double {
        (has(.automation) ? 1.1 : 1) * (has(.advancedChips) ? 1.05 : 1)
    }

    var techCombatFactor: Double {
        (has(.professionalArmy) ? 1.08 : 1) * (has(.militarySatellites) ? 1.05 : 1)
    }

    func demandFactor(_ r: Resource) -> Double {
        switch r {
        case .oil: return has(.smartGrid) ? 0.85 : 1
        case .gas: return (has(.smartGrid) ? 0.9 : 1) * (has(.smallReactors) ? 0.85 : 1)
        default: return 1
        }
    }
}

extension Simulation {

    mutating func setupTechnologies() {
        for id in countryIDs {
            guard var c = state.countries[id] else { continue }
            if c.tech >= 0.6 { c.techs.insert(.automation) }
            if c.tech >= 0.8 { c.techs.formUnion([.professionalArmy, .combatMedicine]) }
            if c.tech >= 0.9 { c.techs.formUnion([.militarySatellites, .electronicWarfare]) }
            for t in TechData.extra[id] ?? [] { c.techs.insert(t) }
            state.countries[id] = c
        }
    }

    /// Points de recherche par mois.
    func researchPoints(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        let budget = effectiveGDP(id) / 12 * c.budget.research
        var points = max(0, budget).squareRoot() * 12 * (0.5 + c.tech)
        if c.has(.appliedAI) { points *= 1.1 }
        if c.has(.quantumComputing) { points *= 1.2 }
        return points * stabilityFactor(c) * (state.industryCache[id]?.research ?? 1)
    }

    mutating func monthlyResearch(_ id: CountryID) {
        let points = researchPoints(id)
        let atWar = isAtWar(id)
        let isPlayer = id == state.playerID
        guard var c = state.countries[id] else { return }
        if c.researching == nil && !isPlayer {
            // L'IA choisit la technologie disponible la moins chère (militaire d'abord si elle est en guerre).
            let options = TechID.allCases.filter { c.canResearch($0) }
            let preferred = options.filter { atWar ? $0.category == .military : true }
            c.researching = (preferred.isEmpty ? options : preferred).min { $0.cost < $1.cost }
        }
        guard let current = c.researching, c.canResearch(current) else {
            c.researching = nil
            state.countries[id] = c
            return
        }
        c.researchProgress += points
        if c.researchProgress >= current.cost {
            c.researchProgress -= current.cost
            c.techs.insert(current)
            c.researching = nil
            applyOneTimeEffects(current, to: &c)
            if isPlayer {
                addEvent("🔬 Recherche terminée : \(current.name).", important: true)
            } else if [.hypersonic, .quantumComputing, .stealthAircraft].contains(current) && c.gdp > 500 {
                addEvent("🔬 \(c.name) maîtrise : \(current.name).")
            }
        }
        state.countries[id] = c
    }

    private func applyOneTimeEffects(_ tech: TechID, to c: inout Country) {
        switch tech {
        case .shaleExtraction:
            c.resourceProduction[.oil] = (c.resourceProduction[.oil] ?? 0) * 1.15
            c.resourceProduction[.gas] = (c.resourceProduction[.gas] ?? 0) * 1.15
        case .precisionAgriculture:
            c.resourceProduction[.food] = (c.resourceProduction[.food] ?? 0) * 1.15
        case .advancedChips:
            c.resourceProduction[.semiconductors] = max(0.2, (c.resourceProduction[.semiconductors] ?? 0) * 1.3)
        default:
            break
        }
    }

    mutating func setResearch(_ tech: TechID?, for id: CountryID) {
        guard let c = state.countries[id] else { return }
        if let tech = tech, !c.canResearch(tech) { return }
        if c.researching != tech {
            state.countries[id]?.researching = tech
        }
    }

    /// Cyberattaque : ralentit l'économie de la cible si votre cyberguerre dépasse ses défenses.
    mutating func cyberAttack(from id: CountryID, on target: CountryID) -> ActionResult {
        guard let a = state.countries[id], let t = state.countries[target], a.has(.cyberWarfare) else {
            return ActionResult(success: false, message: "Il faut la technologie Cyberguerre.")
        }
        guard (a.influence) >= 15 else { return ActionResult(success: false, message: "Pas assez d'influence (15).") }
        state.countries[id]?.influence -= 15
        let chance = (0.5 + (a.tech - t.tech) + (t.has(.cyberWarfare) ? -0.2 : 0.1)).clamped(0.1, 0.9)
        let roll = Double.random(in: 0...1, using: &state.rng)
        let detected = Double.random(in: 0...1, using: &state.rng) < 0.5
        if detected {
            changeRelation(id, target, by: -20)
            state.worldTension = min(100, state.worldTension + 2)
        }
        guard roll < chance else {
            return ActionResult(success: false, message: detected ? "Échec, et l'attaque a été attribuée à votre pays." : "Échec discret.")
        }
        addModifier(target, "Cyberattaque", growth: -0.006, stability: -0.02, months: 6)
        addEvent("💻 Cyberattaque massive contre \(t.name).", important: false)
        return ActionResult(success: true, message: detected ? "Réussie, mais vous avez été démasqué." : "Réussie et non attribuée.")
    }
}
