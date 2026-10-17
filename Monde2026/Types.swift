import Foundation

// =============================================================
//  Types.swift
//  Types de base du jeu : régions, ressources, équipements,
//  divisions, lois et projets de construction.
// =============================================================

typealias CountryID = String   // Code ISO à 3 lettres, ex. "FRA"

// MARK: - Utilitaires

extension Comparable {
    func clamped(_ low: Self, _ high: Self) -> Self {
        min(max(self, low), high)
    }
}

/// Générateur aléatoire déterministe (SplitMix64) : même graine = même partie.
struct SeededRandom: RandomNumberGenerator, Codable {
    private(set) var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Régions

enum Region: String, Codable, CaseIterable {
    case northAmerica, latinAmerica, westernEurope, easternEurope, middleEast
    case northAfrica, subSaharanAfrica, southAsia, centralAsia, eastAsia, southeastAsia, oceania

    var name: String {
        switch self {
        case .northAmerica: return "Amérique du Nord"
        case .latinAmerica: return "Amérique latine"
        case .westernEurope: return "Europe de l'Ouest"
        case .easternEurope: return "Europe de l'Est"
        case .middleEast: return "Moyen-Orient"
        case .northAfrica: return "Afrique du Nord"
        case .subSaharanAfrica: return "Afrique subsaharienne"
        case .southAsia: return "Asie du Sud"
        case .centralAsia: return "Asie centrale"
        case .eastAsia: return "Asie de l'Est"
        case .southeastAsia: return "Asie du Sud-Est"
        case .oceania: return "Océanie"
        }
    }

    /// Croissance démographique annuelle typique.
    var populationGrowth: Double {
        switch self {
        case .northAmerica: return 0.006
        case .latinAmerica: return 0.007
        case .westernEurope: return 0.001
        case .easternEurope: return -0.004
        case .middleEast: return 0.015
        case .northAfrica: return 0.015
        case .subSaharanAfrica: return 0.025
        case .southAsia: return 0.011
        case .centralAsia: return 0.012
        case .eastAsia: return -0.002
        case .southeastAsia: return 0.008
        case .oceania: return 0.011
        }
    }
}

// MARK: - Ressources

/// Unité de jeu : 1 unité de ressource = 1 Md$ au prix de base (prix = 1,0).
enum Resource: String, Codable, CaseIterable {
    case oil, gas, steel, aluminium, criticalMinerals, semiconductors, food

    var name: String {
        switch self {
        case .oil: return "Pétrole"
        case .gas: return "Gaz"
        case .steel: return "Acier"
        case .aluminium: return "Aluminium"
        case .criticalMinerals: return "Métaux critiques"
        case .semiconductors: return "Semi-conducteurs"
        case .food: return "Agriculture"
        }
    }

    /// Valeur mondiale consommée par mois au prix de base (Md$).
    var worldMonthlyValue: Double {
        switch self {
        case .oil: return 200
        case .gas: return 70
        case .steel: return 80
        case .aluminium: return 18
        case .criticalMinerals: return 15
        case .semiconductors: return 50
        case .food: return 500
        }
    }

    /// Ce qui fait la demande d'un pays : sa part du PIB, de la population et de l'industrie mondiales.
    var demandWeights: (gdp: Double, population: Double, industry: Double) {
        switch self {
        case .oil: return (0.6, 0.3, 0.1)
        case .gas: return (0.5, 0.1, 0.4)
        case .steel: return (0.2, 0.0, 0.8)
        case .aluminium: return (0.2, 0.0, 0.8)
        case .criticalMinerals: return (0.2, 0.0, 0.8)
        case .semiconductors: return (0.6, 0.0, 0.4)
        case .food: return (0.1, 0.9, 0.0)
        }
    }

    /// Perte de croissance annuelle en cas de pénurie totale.
    var shortageGrowthImpact: Double {
        switch self {
        case .oil: return 0.06
        case .gas: return 0.03
        case .steel: return 0.02
        case .aluminium: return 0.01
        case .criticalMinerals: return 0.015
        case .semiconductors: return 0.03
        case .food: return 0.05
        }
    }

    /// Poids dans la production militaire (la somme fait 1).
    var militaryImportance: Double {
        switch self {
        case .oil: return 0.25
        case .gas: return 0.0
        case .steel: return 0.3
        case .aluminium: return 0.1
        case .criticalMinerals: return 0.1
        case .semiconductors: return 0.25
        case .food: return 0.0
        }
    }

    /// Sensibilité du prix au déséquilibre offre / demande.
    var priceElasticity: Double {
        switch self {
        case .oil: return 2.5
        case .gas: return 2.0
        case .steel: return 1.2
        case .aluminium: return 1.2
        case .criticalMinerals: return 2.5
        case .semiconductors: return 2.0
        case .food: return 2.0
        }
    }
}

// MARK: - Équipements

/// Coûts en points de production (pp). 1 pp ≈ 1 M$ au coût américain.
enum EquipmentType: String, Codable, CaseIterable {
    case infantryKit, tank, armoredVehicle, artillery, fighter, drone, missile, warship, submarine, carrier

    var name: String {
        switch self {
        case .infantryKit: return "Équipement d'infanterie (lot de 1 000 h)"
        case .tank: return "Char de combat"
        case .armoredVehicle: return "Véhicule blindé"
        case .artillery: return "Artillerie"
        case .fighter: return "Avion de combat"
        case .drone: return "Drones (lot)"
        case .missile: return "Missile de croisière / balistique"
        case .warship: return "Navire de surface"
        case .submarine: return "Sous-marin"
        case .carrier: return "Porte-avions"
        }
    }

    var cost: Double {
        switch self {
        case .infantryKit: return 25
        case .tank: return 9
        case .armoredVehicle: return 3
        case .artillery: return 4
        case .fighter: return 90
        case .drone: return 1
        case .missile: return 3
        case .warship: return 900
        case .submarine: return 1500
        case .carrier: return 11000
        }
    }

    /// Construit dans les chantiers navals plutôt que dans les usines militaires.
    var isNaval: Bool {
        switch self {
        case .warship, .submarine, .carrier: return true
        default: return false
        }
    }

    /// Utilisé par les divisions terrestres.
    var isLandEquipment: Bool {
        switch self {
        case .infantryKit, .tank, .armoredVehicle, .artillery: return true
        default: return false
        }
    }
}

// MARK: - Divisions

struct DivisionStats {
    let manpower: Double                       // milliers d'hommes
    let equipment: [EquipmentType: Double]     // besoins
    let softAttack: Double                     // contre infanterie
    let hardAttack: Double                     // contre blindés
    let defense: Double
    let breakthrough: Double
    let hardness: Double                       // 0 = infanterie, 1 = tout blindé
}

enum DivisionType: String, Codable, CaseIterable {
    case infantry, mechanized, armored, airborne, marines

    var name: String {
        switch self {
        case .infantry: return "Infanterie"
        case .mechanized: return "Mécanisée"
        case .armored: return "Blindée"
        case .airborne: return "Aéroportée"
        case .marines: return "Infanterie de marine"
        }
    }

    var stats: DivisionStats {
        switch self {
        case .infantry:
            return DivisionStats(manpower: 12,
                                 equipment: [.infantryKit: 12, .armoredVehicle: 40, .artillery: 36],
                                 softAttack: 30, hardAttack: 4, defense: 40, breakthrough: 8, hardness: 0.1)
        case .mechanized:
            return DivisionStats(manpower: 12,
                                 equipment: [.infantryKit: 12, .armoredVehicle: 300, .artillery: 54, .tank: 40],
                                 softAttack: 40, hardAttack: 15, defense: 45, breakthrough: 20, hardness: 0.6)
        case .armored:
            return DivisionStats(manpower: 10,
                                 equipment: [.infantryKit: 10, .armoredVehicle: 150, .artillery: 36, .tank: 250],
                                 softAttack: 45, hardAttack: 50, defense: 30, breakthrough: 50, hardness: 0.8)
        case .airborne:
            return DivisionStats(manpower: 8,
                                 equipment: [.infantryKit: 8, .armoredVehicle: 20, .artillery: 12],
                                 softAttack: 22, hardAttack: 3, defense: 28, breakthrough: 6, hardness: 0.05)
        case .marines:
            return DivisionStats(manpower: 8,
                                 equipment: [.infantryKit: 8, .armoredVehicle: 100, .artillery: 18, .tank: 10],
                                 softAttack: 28, hardAttack: 6, defense: 30, breakthrough: 10, hardness: 0.3)
        }
    }

    var trainingDays: Int {
        switch self {
        case .infantry: return 60
        case .mechanized: return 90
        case .armored, .airborne, .marines: return 120
        }
    }
}

// MARK: - Lois

enum ConscriptionLaw: String, Codable, CaseIterable {
    case volunteer, limited, extensive, total

    var name: String {
        switch self {
        case .volunteer: return "Armée de métier"
        case .limited: return "Service limité"
        case .extensive: return "Conscription étendue"
        case .total: return "Mobilisation générale"
        }
    }

    /// Part de la population mobilisable.
    var recruitableFraction: Double {
        switch self {
        case .volunteer: return 0.015
        case .limited: return 0.03
        case .extensive: return 0.06
        case .total: return 0.10
        }
    }

    /// Perte de croissance annuelle (main-d'œuvre retirée de l'économie).
    var growthPenalty: Double {
        switch self {
        case .volunteer: return 0
        case .limited: return 0.003
        case .extensive: return 0.01
        case .total: return 0.025
        }
    }

    var next: ConscriptionLaw? {
        switch self {
        case .volunteer: return .limited
        case .limited: return .extensive
        case .extensive: return .total
        case .total: return nil
        }
    }
}

enum EconomyMode: String, Codable, CaseIterable {
    case civilian, partialMobilization, warEconomy

    var name: String {
        switch self {
        case .civilian: return "Économie civile"
        case .partialMobilization: return "Mobilisation partielle"
        case .warEconomy: return "Économie de guerre"
        }
    }

    /// Part des usines civiles absorbée par les biens de consommation.
    var consumerGoodsShare: Double {
        switch self {
        case .civilian: return 0.35
        case .partialMobilization: return 0.25
        case .warEconomy: return 0.15
        }
    }

    var militaryOutputBonus: Double {
        switch self {
        case .civilian: return 1.0
        case .partialMobilization: return 1.1
        case .warEconomy: return 1.25
        }
    }

    var growthPenalty: Double {
        switch self {
        case .civilian: return 0
        case .partialMobilization: return 0.005
        case .warEconomy: return 0.02
        }
    }

    var inflationPressure: Double {
        switch self {
        case .civilian: return 0
        case .partialMobilization: return 0.005
        case .warEconomy: return 0.02
        }
    }
}

// MARK: - Construction

enum ConstructionKind: String, Codable, CaseIterable {
    case civilianFactory, militaryFactory, dockyard, infrastructure

    var name: String {
        switch self {
        case .civilianFactory: return "Usine civile"
        case .militaryFactory: return "Usine militaire"
        case .dockyard: return "Chantier naval"
        case .infrastructure: return "Infrastructures"
        }
    }

    /// Points de construction nécessaires.
    var constructionCost: Double {
        switch self {
        case .civilianFactory: return 300
        case .militaryFactory: return 250
        case .dockyard: return 350
        case .infrastructure: return 400
        }
    }

    /// Coût financier (Md$), payé par le budget infrastructures.
    func moneyCost(area: Double) -> Double {
        switch self {
        case .civilianFactory: return 15
        case .militaryFactory: return 12
        case .dockyard: return 15
        case .infrastructure: return max(2, 8 * (area / 300).squareRoot())
        }
    }

    /// PIB annuel ajouté par le projet (Md$), réparti au fil du chantier.
    var gdpValue: Double {
        switch self {
        case .civilianFactory: return 10
        case .militaryFactory: return 5
        case .dockyard: return 4
        case .infrastructure: return 0
        }
    }
}

// MARK: - Posture militaire

enum WarPosture: String, Codable, CaseIterable {
    case balanced, offensive, defensive

    var name: String {
        switch self {
        case .balanced: return "Équilibrée"
        case .offensive: return "Offensive"
        case .defensive: return "Défensive"
        }
    }

    var summary: String {
        switch self {
        case .balanced: return "Ni trop prudente, ni trop risquée."
        case .offensive: return "Attaque +25 %, mais 30 % de pertes en plus."
        case .defensive: return "Défense +25 % et 30 % de pertes en moins, mais l'armée n'avance presque plus."
        }
    }

    var attack: Double {
        switch self {
        case .balanced: return 1
        case .offensive: return 1.25
        case .defensive: return 0.6
        }
    }

    var defense: Double {
        switch self {
        case .balanced: return 1
        case .offensive: return 0.9
        case .defensive: return 1.25
        }
    }

    var losses: Double {
        switch self {
        case .balanced: return 1
        case .offensive: return 1.3
        case .defensive: return 0.7
        }
    }
}

// MARK: - Fichiers de données (application Xcode ou paquet Swift Playgrounds)

enum GameResources {
    static func url(_ name: String, _ ext: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: name, withExtension: ext)
        #else
        return nil
        #endif
    }
}
