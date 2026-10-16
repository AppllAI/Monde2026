import Foundation

// =============================================================
//  Politics.swift
//  Politique intérieure : régimes, idéologies, libertés,
//  soutien populaire, stabilité, élections, coups d'État et
//  guerres civiles (avec les conflits internes de 2026).
// =============================================================

// MARK: - Types

enum GovernmentType: String, Codable, CaseIterable {
    case democracy, hybrid, authoritarian, monarchy, theocracy, junta, oneParty

    var name: String {
        switch self {
        case .democracy: return "Démocratie"
        case .hybrid: return "Régime hybride"
        case .authoritarian: return "Régime autoritaire"
        case .monarchy: return "Monarchie"
        case .theocracy: return "Théocratie"
        case .junta: return "Junte militaire"
        case .oneParty: return "Parti unique"
        }
    }

    var baseStability: Double {
        switch self {
        case .democracy: return 0.70
        case .hybrid: return 0.55
        case .authoritarian: return 0.60
        case .monarchy: return 0.65
        case .theocracy: return 0.55
        case .junta: return 0.45
        case .oneParty: return 0.65
        }
    }

    var holdsElections: Bool { self == .democracy || self == .hybrid }

    /// Soutien nécessaire pour gagner une élection (les régimes hybrides « aident » le résultat).
    var electionThreshold: Double { self == .democracy ? 0.5 : 0.35 }

    var isDemocratic: Bool { self == .democracy }

    var coupProne: Bool {
        switch self {
        case .hybrid, .authoritarian, .junta, .monarchy: return true
        default: return false
        }
    }
}

enum Ideology: String, Codable, CaseIterable {
    case left, center, right, nationalist, islamist, communist

    var name: String {
        switch self {
        case .left: return "Gauche"
        case .center: return "Centre"
        case .right: return "Droite"
        case .nationalist: return "Nationalistes"
        case .islamist: return "Islamistes"
        case .communist: return "Communistes"
        }
    }

    /// « la gauche remporte », « les nationalistes remportent »…
    var winnerPhrase: String {
        switch self {
        case .left: return "la gauche remporte"
        case .center: return "le centre remporte"
        case .right: return "la droite remporte"
        case .nationalist: return "les nationalistes remportent"
        case .islamist: return "les islamistes remportent"
        case .communist: return "les communistes remportent"
        }
    }

    /// Influence sur l'agressivité de l'IA.
    var aggressionFactor: Double {
        switch self {
        case .nationalist: return 1.3
        case .islamist: return 1.2
        case .left: return 0.85
        default: return 1.0
        }
    }
}

enum FreedomLevel: String, Codable, CaseIterable {
    case open, restricted, repressed

    var name: String {
        switch self {
        case .open: return "Libertés garanties"
        case .restricted: return "Libertés restreintes"
        case .repressed: return "Répression"
        }
    }
}

/// Effet temporaire sur un pays (événement, décision, crise).
struct Modifier: Codable, Identifiable {
    var id: Int
    var name: String
    var growth: Double       // points de croissance annuelle
    var stability: Double    // ajouté à la cible de stabilité
    var support: Double      // ajouté à la cible de soutien
    var monthsLeft: Int
}

// MARK: - Données de départ (janvier 2026)

enum PoliticalData {

    static let democracies: Set<CountryID> = [
        "USA", "CAN", "MEX", "BRA", "ARG", "COL", "CHL", "PER", "GBR", "FRA", "DEU", "ITA", "ESP", "NLD", "BEL",
        "CHE", "AUT", "PRT", "GRC", "SWE", "NOR", "FIN", "DNK", "IRL", "ISL", "LUX", "CYP", "POL", "ROU", "CZE",
        "SVK", "HRV", "SVN", "BGR", "LTU", "LVA", "EST", "MDA", "MNE", "MKD", "ALB", "XKX", "BIH", "ISR", "JPN",
        "KOR", "TWN", "IND", "IDN", "PHL", "MYS", "MNG", "NPL", "LKA", "ZAF", "NAM", "BWA", "GHA", "SEN", "KEN",
        "ZMB", "MWI", "CRI", "PAN", "DOM", "URY", "PRY", "ECU", "BOL", "GTM", "HND", "JAM", "GUY", "SUR", "AUS",
        "NZL", "FJI", "UKR", "ARM", "NGA", "PNG"
    ]

    static let hybrids: Set<CountryID> = [
        "TUR", "HUN", "SRB", "GEO", "PAK", "BGD", "THA", "SGP", "LBN", "IRQ", "SLV", "CIV", "BEN", "MDG", "TZA",
        "MOZ", "MRT", "SOM", "HTI", "GAB"
    ]

    static let monarchies: Set<CountryID> = ["SAU", "ARE", "QAT", "KWT", "OMN", "BHR", "JOR", "MAR"]
    static let theocracies: Set<CountryID> = ["IRN", "AFG"]
    static let juntas: Set<CountryID> = ["MMR", "MLI", "BFA", "NER", "SDN", "TCD", "GIN"]
    static let oneParty: Set<CountryID> = ["CHN", "VNM", "LAO", "CUB", "PRK"]
    // Tous les autres : régime autoritaire.

    static func government(_ id: CountryID) -> GovernmentType {
        if democracies.contains(id) { return .democracy }
        if hybrids.contains(id) { return .hybrid }
        if monarchies.contains(id) { return .monarchy }
        if theocracies.contains(id) { return .theocracy }
        if juntas.contains(id) { return .junta }
        if oneParty.contains(id) { return .oneParty }
        return .authoritarian
    }

    static let ideology: [CountryID: Ideology] = [
        "USA": .nationalist, "ARG": .right, "ITA": .right, "HUN": .nationalist, "ISR": .nationalist,
        "IND": .nationalist, "SLV": .right, "ECU": .right, "PRY": .right, "CRI": .right, "JPN": .right,
        "CZE": .nationalist, "SVK": .nationalist, "SWE": .right, "FIN": .right, "GRC": .right, "NLD": .right,
        "AUT": .right, "CHL": .right, "BOL": .right, "HRV": .right,
        "ESP": .left, "BRA": .left, "MEX": .left, "COL": .left, "GBR": .left, "AUS": .left, "NOR": .left,
        "DNK": .left, "LKA": .left, "URY": .left, "GTM": .left, "KOR": .left, "ZAF": .left, "HND": .left,
        "TUR": .nationalist, "RUS": .nationalist, "AZE": .nationalist, "BLR": .nationalist, "SRB": .nationalist,
        "IRN": .islamist, "AFG": .islamist, "PAK": .right, "VEN": .left, "NIC": .left
    ]

    /// Date (jour de jeu) de la prochaine élection nationale ; les autres sont réparties sur 4 ans.
    static let nextElection: [CountryID: Int] = [
        "BRA": 276, "USA": 1041, "FRA": 470, "KOR": 1615, "JPN": 950, "DEU": 1360, "GBR": 1310, "CAN": 1380,
        "AUS": 850, "IND": 1225, "ISR": 300, "HUN": 95, "COL": 150, "PER": 101, "SWE": 256, "ITA": 610,
        "ESP": 540, "POL": 650, "PHL": 850, "TWN": 740, "MEX": 1615, "ARG": 660, "UKR": 900, "TUR": 880
    ]

    static func termDays(_ id: CountryID) -> Int {
        switch id {
        case "FRA", "TUR": return 1826
        case "MEX": return 2191
        default: return 1461
        }
    }

    /// Stabilité de départ des pays fragiles.
    static let stability: [CountryID: Double] = [
        "SDN": 0.10, "MMR": 0.12, "YEM": 0.15, "SOM": 0.20, "HTI": 0.10, "LBY": 0.20, "SYR": 0.30, "COD": 0.30,
        "MLI": 0.25, "BFA": 0.20, "NER": 0.30, "AFG": 0.40, "UKR": 0.55, "RUS": 0.58, "VEN": 0.30, "LBN": 0.30,
        "PAK": 0.40, "ETH": 0.35, "IRN": 0.40, "CUB": 0.30, "ARG": 0.50, "BGD": 0.40, "SSD": 0.15, "CAF": 0.20,
        "LKA": 0.50, "NIC": 0.45, "ERI": 0.40, "TCD": 0.30, "IRQ": 0.40, "NGA": 0.45, "COL": 0.55, "PER": 0.45,
        "FRA": 0.60, "USA": 0.62, "KOR": 0.62, "ISR": 0.55, "MOZ": 0.40, "CMR": 0.45, "GIN": 0.40
    ]

    /// Soutien au gouvernement en janvier 2026 (popularité).
    static let support: [CountryID: Double] = [
        "USA": 0.42, "FRA": 0.25, "GBR": 0.30, "DEU": 0.35, "JPN": 0.40, "KOR": 0.55, "IND": 0.65, "BRA": 0.45,
        "MEX": 0.70, "ARG": 0.45, "CAN": 0.50, "ITA": 0.45, "ESP": 0.40, "POL": 0.40, "UKR": 0.60, "ISR": 0.40,
        "TUR": 0.45, "PER": 0.15, "COL": 0.35, "AUS": 0.50
    ]

    /// Guerres civiles et insurrections en cours : part du territoire hors du contrôle du gouvernement.
    static let civilWars: [CountryID: Double] = [
        "SDN": 0.40, "MMR": 0.45, "YEM": 0.35, "SOM": 0.20, "HTI": 0.30, "LBY": 0.45, "SYR": 0.20, "COD": 0.12,
        "MLI": 0.35, "BFA": 0.40, "NER": 0.15, "ETH": 0.08, "CAF": 0.30, "SSD": 0.10, "CMR": 0.05, "MOZ": 0.03,
        "NGA": 0.05, "TCD": 0.05, "COL": 0.05
    ]
}

// MARK: - Simulation politique

extension Simulation {

    /// Mise en place des régimes, de la stabilité et des conflits internes.
    mutating func setupPolitics() {
        for id in countryIDs {
            guard var c = state.countries[id] else { continue }
            c.government = PoliticalData.government(id)
            c.ideology = PoliticalData.ideology[id] ?? defaultIdeology(c.government)
            c.freedom = c.government == .democracy ? .open : (c.government == .hybrid ? .restricted : .repressed)
            c.stability = PoliticalData.stability[id] ?? c.government.baseStability
            c.support = PoliticalData.support[id] ?? (c.government.isDemocratic ? 0.5 : 0.6)
            if c.government.holdsElections {
                var hash = 0
                for s in id.unicodeScalars { hash = (hash * 31 + Int(s.value)) % 1461 }
                c.nextElectionDay = PoliticalData.nextElection[id] ?? (60 + hash)
            } else {
                c.nextElectionDay = Int.max / 2
            }
            if let cw = PoliticalData.civilWars[id] {
                // Les données décrivent la partie contrôlée par le gouvernement.
                c.gdp /= 1 - cw * 0.9
                c.civilianFactories /= 1 - cw
                c.militaryFactories /= 1 - cw
                for r in Resource.allCases {
                    c.resourceProduction[r] = (c.resourceProduction[r] ?? 0) / (1 - cw)
                }
                c.civilWar = cw
                c.rebelStrength = max(1, c.landStrengthIndex * 0.6)
            }
            state.countries[id] = c
        }
    }

    private func defaultIdeology(_ g: GovernmentType) -> Ideology {
        switch g {
        case .oneParty: return .communist
        case .theocracy: return .islamist
        case .junta, .authoritarian: return .nationalist
        case .monarchy: return .right
        default: return .center
        }
    }

    // MARK: Calculs

    func stabilityFactor(_ c: Country) -> Double {
        (0.5 + 0.5 * c.stability / 0.65).clamped(0.6, 1.15)
    }

    /// Termes de la cible de stabilité, hors base du régime.
    func stabilityTerms(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var t = (c.support - 0.5) * 0.4
        t += c.growth >= 0 ? 0.02 : -0.05
        t -= c.warExhaustion * 0.2
        t -= c.civilWar * 0.5
        t -= occupiedFraction(id) * 0.3
        if c.defaultMonthsLeft > 0 { t -= 0.1 }
        switch (c.government.isDemocratic, c.freedom) {
        case (true, .restricted): t -= 0.05
        case (true, .repressed): t -= 0.12
        case (false, .open): t -= 0.05
        case (false, .repressed): t += 0.05
        default: break
        }
        if c.techs.contains(.digitalState) { t += 0.03 }
        for m in c.modifiers { t += m.stability }
        return t
    }

    func supportTarget(_ c: Country) -> Double {
        var t = 0.5
        t += (c.growth - c.trendGrowth) * 3
        t -= max(0, c.inflation - 0.03) * 2
        t -= max(0, c.unemployment - c.naturalUnemployment) * 2
        t -= c.warExhaustion * 0.3
        t += (c.budget.social - c.baseSocialSpending) * 2
        t -= (c.budget.taxRate - c.baseTaxRate) * 2
        if c.freedom == .repressed { t -= 0.1 }
        for m in c.modifiers { t += m.support }
        return t.clamped(0.05, 0.95)
    }

    /// La stabilité de départ est un équilibre : on ajuste la base de chaque pays.
    mutating func calibratePolitics() {
        for id in countryIDs {
            let terms = stabilityTerms(id)
            guard var c = state.countries[id] else { continue }
            c.stabilityBase = c.stability - terms
            state.countries[id] = c
        }
    }

    // MARK: Mois politique

    mutating func monthlyPolitics(_ id: CountryID) {
        let terms = stabilityTerms(id)
        let isPlayer = id == state.playerID
        guard var c = state.countries[id] else { return }

        // Soutien et stabilité
        c.support += (supportTarget(c) - c.support) * 0.06
        let stabilityTarget = (c.stabilityBase + terms).clamped(0.02, 0.98)
        c.stability += (stabilityTarget - c.stability) * 0.1

        // Effets temporaires
        var kept: [Modifier] = []
        for var m in c.modifiers {
            m.monthsLeft -= 1
            if m.monthsLeft > 0 { kept.append(m) }
        }
        c.modifiers = kept

        // Élections
        if c.government.holdsElections && state.day >= c.nextElectionDay {
            let swing = Double.random(in: -0.05...0.05, using: &state.rng)
            let wins = c.support + swing >= c.government.electionThreshold
            c.nextElectionDay = state.day + PoliticalData.termDays(id)
            if wins {
                c.addModifier("Mandat renouvelé", growth: 0, stability: 0.04, support: 0.03, months: 12)
                addEvent("🗳️ \(c.name) : le gouvernement (\(c.ideology.name)) remporte les élections.", important: isPlayer)
            } else {
                let previous = c.ideology
                c.ideology = alternance(previous)
                c.support = 0.58
                c.addModifier("Nouveau gouvernement", growth: 0, stability: -0.03, support: 0.05, months: 6)
                if !isPlayer { applyNewGovernmentPolicies(&c) }
                addEvent("🗳️ \(c.name) : alternance, \(c.ideology.winnerPhrase) les élections (\(previous.name.lowercased()) battus).",
                         important: isPlayer || c.gdp > 1500)
            }
        }

        // Guerre civile
        if c.civilWar > 0 {
            let government = max(1, c.landStrengthIndex * 0.6)
            c.rebelStrength *= 1 + (0.4 - c.stability) * 0.05
            let ratio = government / max(c.rebelStrength, 1)
            let noise = Double.random(in: -0.004...0.004, using: &state.rng)
            c.civilWar = (c.civilWar - 0.015 * tanh((ratio - 1) * 2) + noise).clamped(0, 0.95)
            c.applyLandLosses(fraction: 0.01, share: 0.5)
            c.rebelStrength *= 0.99
            if c.civilWar <= 0.01 {
                c.civilWar = 0
                c.rebelStrength = 0
                c.addModifier("Fin de la guerre civile", growth: 0.01, stability: 0.1, support: 0.05, months: 12)
                addEvent("🕊️ \(c.name) : le gouvernement reprend le contrôle du pays.", important: isPlayer)
            } else if c.civilWar >= 0.65 {
                regimeFalls(&c)
                addEvent("🔥 \(c.name) : les rebelles prennent le pouvoir.", important: true)
                if isPlayer {
                    state.countries[id] = c
                    endGame(victory: false, reason: "Votre régime a été renversé par les rebelles.")
                    return
                }
            }
        }

        // Coups d'État et insurrections
        let roll = Double.random(in: 0...1, using: &state.rng)
        if c.government.coupProne && c.stability < 0.22 && c.civilWar < 0.01 && roll < 0.03 {
            if isPlayer {
                state.countries[id] = c
                queueEvent("coup", for: id, target: nil)
                guard let updated = state.countries[id] else { return }
                c = updated
            } else {
                c.government = .junta
                c.ideology = .nationalist
                c.stability = 0.45
                c.support = 0.5
                c.freedom = .repressed
                addEvent("🪖 Coup d'État : l'armée prend le pouvoir (\(c.name)).", important: c.gdp > 300)
            }
        } else if c.stability < 0.12 && c.civilWar == 0 && roll > 0.97 {
            c.civilWar = 0.08
            c.rebelStrength = max(1, c.landStrengthIndex * 0.45)
            addEvent("🔥 Insurrection armée : \(c.name).", important: isPlayer || c.gdp > 500)
        }

        state.countries[id] = c
    }


    private func alternance(_ current: Ideology) -> Ideology {
        switch current {
        case .left: return .right
        case .right: return .left
        case .center: return .right
        case .nationalist: return .center
        case .islamist: return .nationalist
        case .communist: return .center
        }
    }

    /// Ce que fait un nouveau gouvernement IA en arrivant.
    private func applyNewGovernmentPolicies(_ c: inout Country) {
        switch c.ideology {
        case .left:
            c.budget.social += 0.01
            c.budget.taxRate += 0.01
        case .right:
            c.budget.taxRate = max(0.08, c.budget.taxRate - 0.01)
            c.budget.social = max(0.03, c.budget.social - 0.005)
        case .nationalist:
            c.budget.military += 0.005
        case .center, .islamist, .communist:
            break
        }
    }

    private func regimeFalls(_ c: inout Country) {
        c.government = c.government.isDemocratic ? .junta : .hybrid
        c.ideology = c.government == .junta ? .nationalist : .center
        c.freedom = c.government == .junta ? .repressed : .restricted
        c.civilWar = 0
        c.rebelStrength = 0
        c.stability = 0.35
        c.support = 0.55
        c.nextElectionDay = c.government.holdsElections ? state.day + 365 : Int.max / 2
    }

    // MARK: Effet du régime sur les relations

    func regimeAffinity(_ a: CountryID, _ b: CountryID) -> Double {
        guard let A = state.countries[a], let B = state.countries[b] else { return 0 }
        let da = A.government.isDemocratic, db = B.government.isDemocratic
        if da && db { return 10 }
        if da != db { return -5 }
        return 5
    }

    // MARK: Actions du joueur

    mutating func addModifier(_ id: CountryID, _ name: String, growth: Double = 0, stability: Double = 0,
                              support: Double = 0, months: Int) {
        state.countries[id]?.addModifier(name, growth: growth, stability: stability, support: support, months: months)
    }

    mutating func setFreedom(_ level: FreedomLevel, for id: CountryID) -> ActionResult {
        guard let c = state.countries[id], c.freedom != level else {
            return ActionResult(success: false, message: "Rien ne change.")
        }
        let tougher = level == .repressed || (level == .restricted && c.freedom == .open)
        state.countries[id]?.freedom = level
        if tougher {
            state.countries[id]?.support = max(0.05, c.support - 0.05)
            for other in countryIDs where other != id && (state.countries[other]?.government.isDemocratic ?? false) {
                changeRelation(id, other, by: -4)
            }
            return ActionResult(success: true, message: "Libertés réduites : opposition muselée, démocraties inquiètes.")
        }
        for other in countryIDs where other != id && (state.countries[other]?.government.isDemocratic ?? false) {
            changeRelation(id, other, by: 3)
        }
        return ActionResult(success: true, message: "Libertés élargies.")
    }

    mutating func propagandaCampaign(for id: CountryID) -> ActionResult {
        guard let c = state.countries[id] else { return ActionResult(success: false, message: "Action impossible.") }
        if c.modifiers.contains(where: { $0.name == "Campagne de communication" }) {
            return ActionResult(success: false, message: "Une campagne est déjà en cours.")
        }
        let cost = effectiveGDP(id) * 0.001
        state.countries[id]?.debt += cost
        addModifier(id, "Campagne de communication", support: c.has(.informationControl) ? 0.12 : 0.06, months: 6)
        return ActionResult(success: true, message: "Campagne lancée (\(Int(cost.rounded())) Md$) : soutien en hausse pendant 6 mois.")
    }

    mutating func crackdown(for id: CountryID) -> ActionResult {
        guard state.countries[id] != nil else { return ActionResult(success: false, message: "Action impossible.") }
        addModifier(id, "Répression de l'opposition", stability: 0.08, support: -0.06, months: 6)
        for other in countryIDs where other != id && (state.countries[other]?.government.isDemocratic ?? false) {
            changeRelation(id, other, by: -5)
        }
        return ActionResult(success: true, message: "Opposition réprimée : plus stable à court terme, moins populaire.")
    }

    mutating func callEarlyElections(for id: CountryID) -> ActionResult {
        guard var c = state.countries[id], c.government.holdsElections else {
            return ActionResult(success: false, message: "Votre régime n'organise pas d'élections.")
        }
        c.nextElectionDay = state.day
        state.countries[id] = c
        monthlyPolitics(id)
        let won = state.countries[id]?.ideology == c.ideology
        return ActionResult(success: won, message: won ? "Élections gagnées : mandat renouvelé." : "Élections perdues : alternance.")
    }

    /// Réforme du régime d'un cran vers la démocratie (ou l'inverse).
    mutating func reformRegime(for id: CountryID, democratize: Bool) -> ActionResult {
        guard var c = state.countries[id] else { return ActionResult(success: false, message: "Action impossible.") }
        let before = c.government
        if democratize {
            switch c.government {
            case .democracy: return ActionResult(success: false, message: "Vous êtes déjà une démocratie.")
            case .hybrid: c.government = .democracy
            default: c.government = .hybrid
            }
            c.freedom = c.government == .democracy ? .open : .restricted
        } else {
            switch c.government {
            case .democracy: c.government = .hybrid
            case .hybrid: c.government = .authoritarian
            default: return ActionResult(success: false, message: "Le régime est déjà autoritaire.")
            }
            c.freedom = c.government == .hybrid ? .restricted : .repressed
        }
        if c.government.holdsElections && !before.holdsElections {
            c.nextElectionDay = state.day + 365
        } else if !c.government.holdsElections {
            c.nextElectionDay = Int.max / 2
        }
        c.addModifier("Transition politique", growth: -0.005, stability: democratize ? -0.15 : 0.03, support: democratize ? 0.05 : -0.1, months: 12)
        state.countries[id] = c
        for other in countryIDs where other != id && (state.countries[other]?.government.isDemocratic ?? false) {
            changeRelation(id, other, by: democratize ? 10 : -15)
        }
        return ActionResult(success: true, message: "Nouveau régime : \(c.government.name).")
    }

    /// Accord avec les rebelles : moins de territoire perdu, mais le gouvernement paraît faible.
    mutating func negotiateWithRebels(for id: CountryID) -> ActionResult {
        guard var c = state.countries[id], c.civilWar > 0 else {
            return ActionResult(success: false, message: "Pas de guerre civile.")
        }
        c.civilWar *= 0.6
        c.rebelStrength *= 0.6
        c.support = max(0.05, c.support - 0.05)
        state.countries[id] = c
        return ActionResult(success: true, message: "Cessez-le-feu partiel avec les rebelles.")
    }
}

extension Country {
    mutating func addModifier(_ name: String, growth: Double = 0, stability: Double = 0, support: Double = 0, months: Int) {
        nextModifierID += 1
        modifiers.append(Modifier(id: nextModifierID, name: name, growth: growth, stability: stability,
                                  support: support, monthsLeft: months))
    }

    var modifierGrowth: Double { modifiers.reduce(0) { $0 + $1.growth } }
}
