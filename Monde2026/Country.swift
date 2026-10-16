import Foundation

// =============================================================
//  Country.swift
//  L'état complet d'un pays : économie, budget, industrie,
//  ressources et armée.
// =============================================================

/// Budget de l'État, en fractions du PIB.
struct Budget: Codable, Equatable {
    var taxRate: Double          // recettes publiques
    var military: Double
    var infrastructure: Double   // finance la construction
    var research: Double
    var social: Double           // santé, retraites, éducation…

    var totalSpending: Double { military + infrastructure + research + social }
}

struct ProductionLine: Codable, Identifiable {
    var id: Int
    var equipment: EquipmentType
    var factories: Double        // usines (ou chantiers navals) affectées
    var efficiency: Double       // 0…1, monte avec le temps
    var progress: Double         // pp accumulés pour l'unité en cours
}

struct ConstructionProject: Codable, Identifiable {
    var id: Int
    var kind: ConstructionKind
    var progress: Double         // points de construction accumulés
}

struct TrainingBatch: Codable {
    var type: DivisionType
    var count: Int
    var daysLeft: Int
}

/// Photo mensuelle pour les graphiques.
struct Snapshot: Codable, Identifiable {
    var day: Int
    var gdp: Double
    var growth: Double
    var debtRatio: Double
    var inflation: Double
    var unemployment: Double
    var divisions: Int
    var id: Int { day }
}

struct Country: Codable, Identifiable {

    // MARK: Identité
    let id: CountryID
    let name: String
    let region: Region
    let area: Double                     // milliers de km²
    var neighbors: [CountryID]           // frontières terrestres

    // MARK: Population
    var population: Double               // millions
    var populationGrowth: Double         // par an

    // MARK: Macro-économie
    var gdp: Double                      // Md$ / an, territoire national
    var growth: Double                   // dernière croissance annualisée
    var trendGrowth: Double              // croissance de référence (début de partie)
    var growthCalibration: Double        // croissance « structurelle »
    var inflation: Double
    var inflationAnchor: Double
    var unemployment: Double
    var naturalUnemployment: Double
    var debt: Double                     // Md$
    var interestRate: Double             // taux moyen payé sur la dette
    let borrowingBonus: Double           // monnaie de réserve, épargne domestique…
    var foreignAid: Double               // Md$ / an reçus
    var defaultMonthsLeft: Int           // > 0 après un défaut de paiement
    var tech: Double                     // niveau technologique (1,0 ≈ États-Unis 2026)
    var infrastructure: Double           // 0…1

    // MARK: Politique économique
    var budget: Budget
    let baseTaxRate: Double
    let baseMilitaryBudget: Double
    var economyMode: EconomyMode
    var conscription: ConscriptionLaw
    var lastBudgetBalance: Double        // Md$ / mois (négatif = déficit)

    // MARK: Industrie
    var civilianFactories: Double
    var militaryFactories: Double
    var dockyards: Double
    let industryShare: Double
    let costMultiplier: Double           // coût local (parité de pouvoir d'achat)
    var constructionQueue: [ConstructionProject]
    var constructionFunds: Double        // Md$ disponibles pour construire
    var nextProjectID: Int

    // MARK: Ressources (Md$ / mois au prix de base)
    let resourceShare: [Resource: Double]          // part de la production mondiale (%)
    var resourceProduction: [Resource: Double]
    var resourceDemand: [Resource: Double]
    var resourceImports: [Resource: Double]
    var resourceExports: [Resource: Double]
    var resourceCoverage: [Resource: Double]       // 0…1 de la demande satisfaite
    var tradeBalance: Double                       // Md$ / mois

    // MARK: Armée
    var activePersonnel: Double          // milliers
    let initialActivePersonnel: Double
    var reservePersonnel: Double         // milliers
    var supportPersonnel: Double         // marine, air, logistique
    var casualties: Double               // milliers (tués + blessés)
    var divisions: [DivisionType: Int]
    var training: [TrainingBatch]
    var equipment: [EquipmentType: Double]
    var forceTargets: [EquipmentType: Double]      // niveaux que l'IA cherche à maintenir
    var productionLines: [ProductionLine]
    var nextLineID: Int
    var autoProduction: Bool
    var procurementFunds: Double         // Md$ pour acheter du matériel
    var readiness: Double                // 0…1 entraînement / entretien
    var experience: Double               // 0…1
    var nuclearWarheads: Int
    let navalIndustry: Double
    var capitulated: Bool

    // MARK: Diplomatie et IA
    let aggressiveness: Double           // 0…1
    var warExhaustion: Double            // 0…1 : lassitude de guerre
    var casualtiesAtLastMonth: Double
    var influence: Double                // points diplomatiques (0…100)
    var history: [Snapshot]

    // MARK: Politique intérieure
    var government: GovernmentType
    var ideology: Ideology
    var freedom: FreedomLevel
    var stability: Double                // 0…1
    var stabilityBase: Double
    var support: Double                  // 0…1 : soutien au gouvernement
    var nextElectionDay: Int
    var civilWar: Double                 // part du territoire tenue par des rebelles
    var rebelStrength: Double
    var modifiers: [Modifier]
    var nextModifierID: Int
    let baseSocialSpending: Double

    // MARK: Recherche
    var techs: Set<TechID>
    var researching: TechID?
    var researchProgress: Double
    var posture: WarPosture

    // MARK: - Création depuis les données

    init(seed s: CountrySeed) {
        id = s.id
        name = s.name
        region = s.region
        area = s.area
        neighbors = []

        population = s.population
        populationGrowth = s.region.populationGrowth

        gdp = s.gdp
        growth = s.growth
        trendGrowth = s.growth
        growthCalibration = 0
        inflation = s.inflation
        inflationAnchor = s.inflation
        unemployment = s.unemployment
        naturalUnemployment = s.unemployment
        debt = s.gdp * s.debtRatio
        interestRate = 0.03
        borrowingBonus = s.borrowingBonus
        foreignAid = s.foreignAid
        defaultMonthsLeft = 0
        tech = s.tech
        infrastructure = (0.35 + 0.6 * s.tech).clamped(0.2, 0.95)

        let social = max(0.03, s.revenue + 0.025 - s.military - s.research - s.infrastructureSpending - s.debtRatio * 0.035)
        budget = Budget(taxRate: s.revenue, military: s.military,
                        infrastructure: s.infrastructureSpending, research: s.research, social: social)
        baseTaxRate = s.revenue
        baseMilitaryBudget = s.military
        economyMode = .civilian
        conscription = s.conscription
        lastBudgetBalance = 0

        // Industrie : 1 usine civile ≈ 10 Md$ de production industrielle par an.
        industryShare = s.industry
        costMultiplier = s.costMultiplier
        civilianFactories = max(1, s.gdp * s.industry / 10)
        // Usines militaires : capacité ≈ 30 % du budget militaire consacré aux achats, 5 pp/jour/usine.
        let procurementPPPerDay = s.gdp * s.military * 0.30 * 1000 / 365 / s.costMultiplier
        militaryFactories = max(0.5, procurementPPPerDay / 5)
        // Chantiers navals : renouveler la flotte en ~12 ans.
        let fleetValue = s.warships * EquipmentType.warship.cost
            + s.submarines * EquipmentType.submarine.cost
            + s.carriers * EquipmentType.carrier.cost
        navalIndustry = s.navalIndustry
        dockyards = fleetValue / (12 * 365 * 5) * s.navalIndustry
        constructionQueue = []
        constructionFunds = 0
        nextProjectID = 1

        resourceShare = s.resources
        var zero: [Resource: Double] = [:]
        var full: [Resource: Double] = [:]
        for r in Resource.allCases {
            zero[r] = 0
            full[r] = 1
        }
        resourceProduction = zero
        resourceDemand = zero
        resourceImports = zero
        resourceExports = zero
        resourceCoverage = full
        tradeBalance = 0

        // Armée de terre : 1 division ≈ 12 000 hommes.
        activePersonnel = s.active
        initialActivePersonnel = s.active
        reservePersonnel = s.reserve
        casualties = 0
        let landMen = s.active * s.landShare
        let n = Int(landMen / 12)
        var remaining = n
        let armored = min(Int(s.tanks / 250), Int(Double(n) * 0.25))
        remaining -= armored
        let afvLeft = max(0, s.afv - Double(armored) * 150)
        let mech = min(Int(afvLeft / 300), Int(Double(remaining) * 0.4))
        remaining -= mech
        let marines = s.warships >= 10 ? min(remaining, max(1, Int(Double(n) * 0.03))) : 0
        remaining -= marines
        let airborne = n >= 20 ? min(remaining, Int(Double(n) * 0.04)) : 0
        remaining -= airborne
        let divs: [DivisionType: Int] = [.infantry: remaining, .mechanized: mech, .armored: armored,
                                         .airborne: airborne, .marines: marines]
        divisions = divs
        training = []
        var landRequired = 0.0
        for (type, count) in divs {
            landRequired += Double(count) * type.stats.manpower
        }
        supportPersonnel = max(0, s.active - landRequired)

        let stock: [EquipmentType: Double] = [
            .infantryKit: landRequired + s.reserve * 0.5,
            .tank: s.tanks,
            .armoredVehicle: s.afv,
            .artillery: s.artillery,
            .fighter: s.aircraft,
            .drone: s.drones,
            .missile: s.missiles,
            .warship: s.warships,
            .submarine: s.submarines,
            .carrier: s.carriers
        ]
        equipment = stock
        forceTargets = stock
        productionLines = []
        nextLineID = 1
        autoProduction = true
        procurementFunds = s.gdp * s.military / 12
        readiness = (0.5 + 0.4 * s.tech).clamped(0.3, 0.9)
        experience = s.experience
        nuclearWarheads = s.nukes
        capitulated = false

        aggressiveness = s.aggressiveness
        warExhaustion = 0
        casualtiesAtLastMonth = 0
        influence = 20
        history = []

        government = .democracy
        ideology = .center
        freedom = .open
        stability = 0.6
        stabilityBase = 0.6
        support = 0.5
        nextElectionDay = Int.max / 2
        civilWar = 0
        rebelStrength = 0
        modifiers = []
        nextModifierID = 0
        baseSocialSpending = social

        techs = []
        researching = nil
        researchProgress = 0
        posture = .balanced
    }

    var flag: String { Geo.flag(id) }

    // MARK: - Indicateurs

    func stock(_ e: EquipmentType) -> Double {
        equipment[e] ?? 0
    }

    var debtRatio: Double { gdp > 0 ? debt / gdp : 0 }

    /// Hommes mobilisables selon la loi de conscription (milliers).
    var recruitableManpower: Double { population * 1000 * conscription.recruitableFraction }

    var availableManpower: Double { max(0, recruitableManpower - activePersonnel) }

    var divisionCount: Int { divisions.values.reduce(0, +) }

    var landPersonnelRequired: Double {
        var total = 0.0
        for (type, count) in divisions {
            total += Double(count) * type.stats.manpower
        }
        for batch in training {
            total += Double(batch.count) * batch.type.stats.manpower
        }
        return total
    }

    var landPersonnel: Double { max(0, activePersonnel - supportPersonnel) }

    func equipmentRequired(_ e: EquipmentType) -> Double {
        var total = 0.0
        for (type, count) in divisions {
            total += Double(count) * (type.stats.equipment[e] ?? 0)
        }
        return total
    }

    func equipmentFill(_ e: EquipmentType) -> Double {
        let required = equipmentRequired(e)
        return required > 0 ? min(1, stock(e) / required) : 1
    }

    var manpowerFill: Double {
        let required = landPersonnelRequired
        return required > 0 ? min(1, landPersonnel / required) : 1
    }

    /// Taux d'équipement global des divisions (pondéré par la valeur du matériel).
    var divisionFill: Double {
        var weighted = 0.0
        var total = 0.0
        for e in EquipmentType.allCases where e.isLandEquipment {
            let value = equipmentRequired(e) * e.cost
            weighted += value * equipmentFill(e)
            total += value
        }
        let equipmentPart = total > 0 ? weighted / total : 1
        return manpowerFill * equipmentPart
    }

    /// Valeur du matériel en pp (M$).
    var equipmentValue: Double {
        var total = 0.0
        for (e, count) in equipment {
            total += count * e.cost
        }
        return total
    }

    /// Coût mensuel (Md$) des soldes et de l'entretien. Les soldes suivent le carré du coût local.
    var militaryUpkeep: Double {
        let personnel = activePersonnel * 0.135 * costMultiplier * costMultiplier / 12
        let maintenance = equipmentValue / 1000 * 0.08 * costMultiplier / 12
        return personnel + maintenance
    }

    var airPower: Double { stock(.fighter) * tech * (techs.contains(.stealthAircraft) ? 1.25 : 1) }

    var navalPower: Double {
        (stock(.warship) + stock(.submarine) * 1.3 + stock(.carrier) * 12) * tech
    }

    /// Capacité à interdire la mer depuis la côte (missiles antinavires, drones).
    var seaDenial: Double {
        (stock(.missile) * 0.05 + stock(.drone) * 0.002) * tech
    }

    // MARK: - Actions internes

    mutating func startTraining(_ type: DivisionType, count: Int, days: Int? = nil) {
        guard count > 0 else { return }
        training.append(TrainingBatch(type: type, count: count, daysLeft: days ?? type.trainingDays))
    }

    mutating func complete(_ kind: ConstructionKind) {
        switch kind {
        case .civilianFactory:
            civilianFactories += 1
        case .militaryFactory:
            militaryFactories += 1
        case .dockyard:
            dockyards += 1
        case .infrastructure:
            infrastructure = min(1, infrastructure + 0.02)
        }
        // Le PIB a déjà été ajouté pendant le chantier (voir runConstruction).
    }
}
