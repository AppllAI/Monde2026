import Foundation

// =============================================================
//  WorldData.swift
//  Le monde au 1er janvier 2026 : 69 grands pays ici, 85 autres
//  dans WorldDataExtra.swift (154 au total).
//  Chiffres arrondis d'après les données publiques 2024-2025
//  (FMI, Banque mondiale, SIPRI, IISS). À affiner librement.
// =============================================================

/// Données brutes d'un pays. Les pourcentages sont déjà convertis en fractions.
struct CountrySeed {
    var id: CountryID
    var name: String
    var region: Region
    var population: Double          // millions
    var area: Double                // milliers de km²
    var gdp: Double                 // Md$
    var growth: Double
    var debtRatio: Double
    var revenue: Double
    var military: Double
    var industry: Double
    var tech: Double
    var costMultiplier: Double
    var active: Double              // milliers
    var reserve: Double
    var tanks: Double
    var afv: Double
    var artillery: Double
    var aircraft: Double
    var warships: Double
    var carriers: Double
    var submarines: Double
    var nukes: Int
    var resources: [Resource: Double]   // part de la production mondiale (%)

    // Valeurs complétées par les tables d'ajustement ci-dessous
    var research: Double
    var infrastructureSpending: Double
    var inflation: Double
    var unemployment: Double
    var borrowingBonus: Double
    var landShare: Double
    var experience: Double
    var drones: Double
    var missiles: Double
    var navalIndustry: Double
    var conscription: ConscriptionLaw
    var foreignAid: Double
    var aggressiveness: Double      // 0…1 : propension de l'IA à utiliser la force
}

enum WorldData {

    // MARK: - Ajustements par pays

    static let research: [CountryID: Double] = [
        "USA": 0.034, "ISR": 0.06, "KOR": 0.049, "TWN": 0.038, "JPN": 0.034, "SWE": 0.034,
        "CHE": 0.033, "DEU": 0.031, "AUT": 0.032, "FIN": 0.03, "DNK": 0.029, "BEL": 0.034,
        "CHN": 0.026, "NLD": 0.023, "FRA": 0.022, "GBR": 0.027, "CZE": 0.019, "SGP": 0.022,
        "NOR": 0.019, "AUS": 0.017, "CAN": 0.017, "ITA": 0.013, "ESP": 0.014, "POL": 0.016,
        "PRT": 0.017, "HUN": 0.014, "GRC": 0.015, "TUR": 0.013, "RUS": 0.01, "IND": 0.007, "BRA": 0.012
    ]

    static let infrastructureSpending: [CountryID: Double] = [
        "CHN": 0.06, "IND": 0.035, "IDN": 0.035, "VNM": 0.05, "SAU": 0.04, "ARE": 0.04,
        "QAT": 0.05, "ETH": 0.04
    ]

    static let inflation: [CountryID: Double] = [
        "ARG": 0.30, "TUR": 0.33, "IRN": 0.40, "VEN": 1.5, "EGY": 0.15, "NGA": 0.22, "RUS": 0.08,
        "ETH": 0.15, "UKR": 0.12, "PAK": 0.05, "SYR": 0.30, "AGO": 0.20, "MMR": 0.25, "BGD": 0.09,
        "KAZ": 0.11, "CHN": 0.0, "JPN": 0.03, "BRA": 0.05, "COL": 0.05, "MEX": 0.04, "SAU": 0.02,
        "CHE": 0.005, "PRK": 0.10, "COD": 0.10, "KEN": 0.04, "ZAF": 0.035, "DZA": 0.04, "MAR": 0.02,
        "TKM": 0.10, "BLR": 0.06, "ROU": 0.07, "HUN": 0.045, "POL": 0.035, "THA": 0.0, "VNM": 0.035
    ]

    static let unemployment: [CountryID: Double] = [
        "ZAF": 0.32, "ESP": 0.105, "GRC": 0.09, "TUR": 0.085, "IRN": 0.08, "EGY": 0.065, "NGA": 0.05,
        "ARG": 0.07, "BRA": 0.06, "USA": 0.042, "JPN": 0.025, "DEU": 0.035, "KOR": 0.028, "CHN": 0.05,
        "IND": 0.08, "RUS": 0.023, "POL": 0.03, "CHE": 0.03, "MEX": 0.027, "SAU": 0.035, "IRQ": 0.15,
        "SYR": 0.25, "COD": 0.20, "ETH": 0.04, "AGO": 0.30, "KEN": 0.06, "MAR": 0.13, "DZA": 0.11,
        "LBY": 0.19, "UKR": 0.13, "PAK": 0.07, "FRA": 0.075, "ITA": 0.065, "GBR": 0.047, "CAN": 0.068,
        "SWE": 0.088, "FIN": 0.09, "COL": 0.09, "PER": 0.06, "CHL": 0.085, "VEN": 0.07, "ISR": 0.03,
        "THA": 0.01, "VNM": 0.02, "SGP": 0.02
    ]

    /// Facilité d'emprunt : monnaie de réserve, épargne domestique, BCE…
    /// Calé pour retrouver les taux moyens réels payés sur la dette (Japon ≈ 1 %, États-Unis ≈ 3,3 %…).
    static let borrowingBonus: [CountryID: Double] = [
        "USA": 0.028, "JPN": 0.085, "DEU": 0.024, "FRA": 0.036, "ITA": 0.033, "ESP": 0.03, "GBR": 0.015,
        "CAN": 0.027, "CHN": 0.009, "CHE": 0.02, "GRC": 0.05, "NLD": 0.023, "BEL": 0.033, "AUT": 0.027,
        "PRT": 0.028, "FIN": 0.027, "SGP": 0.023, "KWT": 0.01, "KOR": 0.018, "AUS": 0.015, "SWE": 0.02,
        "NOR": 0.02, "DNK": 0.02, "ISR": 0.01, "TWN": 0.02, "CZE": 0.01, "POL": 0.005,
        // Dette restructurée ou prêts concessionnels (FMI, alliés)
        "ARG": 0.06, "UKR": 0.06, "SYR": 0.05
    ]

    /// Part des militaires d'active dans l'armée de terre.
    static let landShare: [CountryID: Double] = [
        "IND": 0.85, "PAK": 0.85, "VNM": 0.85, "KOR": 0.73, "CHN": 0.48, "USA": 0.45, "RUS": 0.65,
        "UKR": 0.8, "PRK": 0.8, "ISR": 0.65, "IRN": 0.6, "TUR": 0.7, "EGY": 0.7, "SAU": 0.6
    ]

    static let experience: [CountryID: Double] = [
        "UKR": 0.7, "RUS": 0.6, "ISR": 0.6, "USA": 0.3, "TUR": 0.3, "IRN": 0.3, "SAU": 0.2,
        "PAK": 0.3, "IND": 0.25, "SYR": 0.4
    ]

    static let drones: [CountryID: Double] = [
        "UKR": 30000, "RUS": 25000, "CHN": 15000, "USA": 12000, "ISR": 4000, "IRN": 6000, "TUR": 4000
    ]

    static let missiles: [CountryID: Double] = [
        "USA": 6000, "RUS": 3500, "CHN": 5000, "IRN": 3000, "PRK": 1000, "ISR": 1500, "IND": 1500,
        "PAK": 1000, "KOR": 1500, "TWN": 800, "TUR": 600, "SAU": 400, "FRA": 500, "GBR": 300,
        "JPN": 300, "UKR": 400, "DEU": 200
    ]

    static let navalIndustry: [CountryID: Double] = ["CHN": 3.0, "KOR": 2.5, "JPN": 1.6]

    static let conscription: [CountryID: ConscriptionLaw] = [
        "RUS": .extensive, "UKR": .total, "ISR": .extensive, "KOR": .extensive, "PRK": .total,
        "TWN": .limited, "FIN": .extensive, "CHE": .limited, "AUT": .limited, "GRC": .limited,
        "TUR": .limited, "IRN": .limited, "EGY": .limited, "VNM": .limited, "SGP": .limited,
        "NOR": .limited, "SWE": .limited, "DNK": .limited
    ]

    /// Aide étrangère reçue (Md$ / an).
    static let foreignAid: [CountryID: Double] = ["UKR": 45, "ISR": 3.8, "EGY": 1.3]

    // MARK: - Frontières terrestres (entre pays du jeu)

    static let borders: [(CountryID, CountryID)] = [
        // Amériques
        ("USA", "CAN"), ("USA", "MEX"), ("COL", "VEN"), ("COL", "PER"), ("COL", "BRA"), ("VEN", "BRA"),
        ("BRA", "ARG"), ("BRA", "PER"), ("ARG", "CHL"), ("CHL", "PER"),
        // Europe
        ("FRA", "BEL"), ("FRA", "DEU"), ("FRA", "CHE"), ("FRA", "ITA"), ("FRA", "ESP"), ("ESP", "PRT"),
        ("BEL", "NLD"), ("BEL", "DEU"), ("NLD", "DEU"), ("DEU", "DNK"), ("DEU", "POL"), ("DEU", "CZE"),
        ("DEU", "AUT"), ("DEU", "CHE"), ("CHE", "AUT"), ("CHE", "ITA"), ("ITA", "AUT"), ("AUT", "CZE"),
        ("AUT", "HUN"), ("CZE", "POL"), ("POL", "UKR"), ("POL", "BLR"), ("POL", "RUS"), ("HUN", "ROU"),
        ("HUN", "UKR"), ("ROU", "UKR"), ("BLR", "UKR"), ("BLR", "RUS"), ("UKR", "RUS"), ("NOR", "SWE"),
        ("NOR", "FIN"), ("NOR", "RUS"), ("SWE", "FIN"), ("FIN", "RUS"), ("GRC", "TUR"),
        // Russie, Asie centrale
        ("RUS", "KAZ"), ("RUS", "CHN"), ("RUS", "PRK"), ("KAZ", "TKM"), ("KAZ", "CHN"),
        // Moyen-Orient, Afrique du Nord
        ("TUR", "SYR"), ("TUR", "IRQ"), ("TUR", "IRN"), ("SYR", "IRQ"), ("SYR", "ISR"), ("IRQ", "IRN"),
        ("IRQ", "SAU"), ("IRQ", "KWT"), ("KWT", "SAU"), ("SAU", "QAT"), ("SAU", "ARE"), ("ISR", "EGY"),
        ("IRN", "PAK"), ("IRN", "TKM"), ("EGY", "LBY"), ("LBY", "DZA"), ("DZA", "MAR"),
        // Afrique subsaharienne
        ("ETH", "KEN"), ("COD", "AGO"),
        // Asie
        ("PAK", "IND"), ("PAK", "CHN"), ("IND", "CHN"), ("IND", "BGD"), ("IND", "MMR"), ("BGD", "MMR"),
        ("CHN", "MMR"), ("CHN", "VNM"), ("CHN", "PRK"), ("PRK", "KOR"), ("THA", "MMR"), ("THA", "MYS"),
        ("MYS", "IDN"), ("MYS", "SGP")
    ]

    // MARK: - Construction du monde

    static func makeCountries() -> [CountryID: Country] {
        var result: [CountryID: Country] = [:]
        for seed in seeds() + WorldDataExtra.seeds() {
            result[seed.id] = Country(seed: seed)
        }
        for (a, b) in borders + WorldDataExtra.borders {
            guard result[a] != nil, result[b] != nil else { continue }
            if !result[a]!.neighbors.contains(b) { result[a]!.neighbors.append(b) }
            if !result[b]!.neighbors.contains(a) { result[b]!.neighbors.append(a) }
        }
        return result
    }

    /// Fabrique un pays. Les valeurs en % sont converties en fractions.
    static func c(_ id: CountryID, _ name: String, _ region: Region,
                          pop: Double, area: Double, gdp: Double, growth: Double, debt: Double,
                          revenue: Double, mil: Double, industry: Double, tech: Double, cost: Double,
                          army: (Double, Double, Double, Double, Double),
                          air: Double, navy: (Double, Double, Double), nukes: Int = 0,
                          res: [Resource: Double] = [:]) -> CountrySeed {
        CountrySeed(
            id: id, name: name, region: region, population: pop, area: area, gdp: gdp,
            growth: growth / 100, debtRatio: debt / 100, revenue: revenue / 100, military: mil / 100,
            industry: industry / 100, tech: tech, costMultiplier: cost,
            active: army.0, reserve: army.1, tanks: army.2, afv: army.3, artillery: army.4,
            aircraft: air, warships: navy.0, carriers: navy.1, submarines: navy.2, nukes: nukes,
            resources: res,
            research: research[id] ?? (0.004 + 0.008 * tech),
            infrastructureSpending: infrastructureSpending[id] ?? 0.03,
            inflation: inflation[id] ?? WorldDataExtra.inflation[id] ?? 0.03,
            unemployment: unemployment[id] ?? WorldDataExtra.unemployment[id] ?? 0.06,
            borrowingBonus: borrowingBonus[id] ?? WorldDataExtra.borrowingBonus[id] ?? 0,
            landShare: landShare[id] ?? WorldDataExtra.landShare[id] ?? 0.55,
            experience: experience[id] ?? WorldDataExtra.experience[id] ?? 0.1,
            drones: drones[id] ?? WorldDataExtra.drones[id] ?? (air * 3 + army.0 * 0.3),
            missiles: missiles[id] ?? WorldDataExtra.missiles[id] ?? (air * 0.5),
            navalIndustry: navalIndustry[id] ?? 1,
            conscription: conscription[id] ?? WorldDataExtra.conscription[id] ?? .volunteer,
            foreignAid: foreignAid[id] ?? WorldDataExtra.foreignAid[id] ?? 0,
            aggressiveness: WorldRelations.aggressiveness[id] ?? 0.15
        )
    }

    // MARK: - Les pays
    // army: (actifs k, réservistes k, chars, blindés, artillerie) — navy: (navires de surface, porte-avions, sous-marins)
    // pop en millions, area en milliers de km², gdp en Md$, growth/debt/revenue/mil/industry en %.

    static func seeds() -> [CountrySeed] {
        var list: [CountrySeed] = []

        // Amériques
        list.append(c("USA", "États-Unis", .northAmerica, pop: 342, area: 9834, gdp: 30300, growth: 2.0, debt: 122,
                      revenue: 30, mil: 3.4, industry: 10, tech: 1.0, cost: 1.0,
                      army: (1330, 800, 4600, 39000, 2600), air: 1800, navy: (105, 11, 68), nukes: 5177,
                      res: [.oil: 13, .gas: 25, .steel: 4.4, .aluminium: 1, .criticalMinerals: 6, .semiconductors: 7, .food: 8]))
        list.append(c("CAN", "Canada", .northAmerica, pop: 41, area: 9985, gdp: 2250, growth: 1.2, debt: 107,
                      revenue: 40, mil: 1.3, industry: 9, tech: 0.85, cost: 0.95,
                      army: (67, 35, 80, 1500, 160), air: 66, navy: (12, 0, 4),
                      res: [.oil: 6, .gas: 4.5, .steel: 0.6, .aluminium: 4.2, .criticalMinerals: 1.5, .food: 1.2]))
        list.append(c("MEX", "Mexique", .latinAmerica, pop: 131, area: 1964, gdp: 1850, growth: 0.5, debt: 52,
                      revenue: 23, mil: 0.7, industry: 19, tech: 0.5, cost: 0.55,
                      army: (230, 80, 0, 1500, 300), air: 30, navy: (10, 0, 0),
                      res: [.oil: 2, .gas: 0.8, .steel: 0.8, .food: 1.5]))
        list.append(c("BRA", "Brésil", .latinAmerica, pop: 213, area: 8516, gdp: 2200, growth: 2.0, debt: 88,
                      revenue: 34, mil: 1.1, industry: 11, tech: 0.5, cost: 0.55,
                      army: (370, 1340, 290, 1600, 600), air: 90, navy: (7, 0, 6),
                      res: [.oil: 3.5, .gas: 0.6, .steel: 1.8, .aluminium: 1.6, .criticalMinerals: 2, .food: 5]))
        list.append(c("ARG", "Argentine", .latinAmerica, pop: 46, area: 2780, gdp: 640, growth: 4.0, debt: 85,
                      revenue: 34, mil: 0.5, industry: 15, tech: 0.45, cost: 0.5,
                      army: (72, 0, 200, 700, 150), air: 20, navy: (10, 0, 1),
                      res: [.oil: 0.8, .gas: 1.0, .steel: 0.3, .aluminium: 0.6, .criticalMinerals: 1, .food: 1.6]))
        list.append(c("COL", "Colombie", .latinAmerica, pop: 53, area: 1142, gdp: 420, growth: 2.5, debt: 60,
                      revenue: 28, mil: 3.0, industry: 11, tech: 0.4, cost: 0.45,
                      army: (295, 35, 0, 400, 150), air: 20, navy: (5, 0, 4),
                      res: [.oil: 0.8, .gas: 0.3, .food: 0.6]))
        // Dette « effective » : l'essentiel de la dette extérieure vénézuélienne n'est plus servi.
        list.append(c("VEN", "Venezuela", .latinAmerica, pop: 28, area: 916, gdp: 100, growth: 1.0, debt: 60,
                      revenue: 15, mil: 1.5, industry: 15, tech: 0.3, cost: 0.2,
                      army: (123, 8, 170, 500, 150), air: 40, navy: (6, 0, 1),
                      res: [.oil: 1.0, .gas: 0.6, .food: 0.2]))
        list.append(c("CHL", "Chili", .latinAmerica, pop: 20, area: 756, gdp: 340, growth: 2.3, debt: 42,
                      revenue: 25, mil: 1.6, industry: 10, tech: 0.55, cost: 0.6,
                      army: (70, 40, 200, 800, 300), air: 40, navy: (8, 0, 4),
                      res: [.criticalMinerals: 5, .food: 0.4]))
        list.append(c("PER", "Pérou", .latinAmerica, pop: 34, area: 1285, gdp: 290, growth: 3.0, debt: 33,
                      revenue: 20, mil: 1.0, industry: 13, tech: 0.4, cost: 0.45,
                      army: (80, 190, 160, 400, 200), air: 20, navy: (8, 0, 6),
                      res: [.gas: 0.3, .criticalMinerals: 2, .food: 0.4]))

        // Europe de l'Ouest
        list.append(c("GBR", "Royaume-Uni", .westernEurope, pop: 69, area: 244, gdp: 3700, growth: 1.1, debt: 101,
                      revenue: 40, mil: 2.3, industry: 9, tech: 0.95, cost: 0.95,
                      army: (140, 75, 227, 4000, 150), air: 180, navy: (18, 2, 10), nukes: 225,
                      res: [.oil: 0.7, .gas: 0.9, .steel: 0.3, .semiconductors: 0.3, .food: 0.6]))
        list.append(c("FRA", "France", .westernEurope, pop: 68.5, area: 552, gdp: 3200, growth: 0.8, debt: 115,
                      revenue: 52, mil: 2.1, industry: 10, tech: 0.9, cost: 0.95,
                      army: (200, 40, 215, 6000, 120), air: 200, navy: (20, 1, 10), nukes: 290,
                      res: [.steel: 0.6, .aluminium: 0.6, .semiconductors: 0.5, .food: 1.5]))
        list.append(c("DEU", "Allemagne", .westernEurope, pop: 84, area: 357, gdp: 4900, growth: 0.3, debt: 63,
                      revenue: 46, mil: 2.0, industry: 18, tech: 0.95, cost: 1.0,
                      army: (182, 30, 310, 4500, 200), air: 220, navy: (12, 0, 6),
                      res: [.gas: 0.1, .steel: 1.9, .aluminium: 0.4, .semiconductors: 1.0, .food: 1.0]))
        list.append(c("ITA", "Italie", .westernEurope, pop: 59, area: 301, gdp: 2400, growth: 0.6, debt: 137,
                      revenue: 47, mil: 1.5, industry: 15, tech: 0.85, cost: 0.85,
                      army: (165, 18, 200, 3000, 200), air: 180, navy: (18, 2, 8),
                      res: [.gas: 0.1, .steel: 1.1, .food: 0.9]))
        list.append(c("ESP", "Espagne", .westernEurope, pop: 49, area: 506, gdp: 1880, growth: 2.5, debt: 102,
                      revenue: 42, mil: 1.3, industry: 11, tech: 0.8, cost: 0.8,
                      army: (120, 15, 327, 2500, 300), air: 130, navy: (11, 1, 2),
                      res: [.steel: 0.6, .aluminium: 0.2, .food: 1.0]))
        list.append(c("NLD", "Pays-Bas", .westernEurope, pop: 18, area: 42, gdp: 1270, growth: 1.4, debt: 44,
                      revenue: 43, mil: 2.0, industry: 11, tech: 0.9, cost: 0.9,
                      army: (41, 5, 18, 800, 60), air: 40, navy: (6, 0, 3),
                      res: [.gas: 0.4, .steel: 0.35, .semiconductors: 0.6, .food: 0.6]))
        list.append(c("BEL", "Belgique", .westernEurope, pop: 12, area: 31, gdp: 690, growth: 1.0, debt: 105,
                      revenue: 50, mil: 1.3, industry: 11, tech: 0.85, cost: 0.9,
                      army: (25, 5, 0, 500, 20), air: 40, navy: (2, 0, 0),
                      res: [.steel: 0.35, .food: 0.2]))
        list.append(c("CHE", "Suisse", .westernEurope, pop: 9, area: 41, gdp: 950, growth: 1.2, debt: 38,
                      revenue: 33, mil: 0.7, industry: 18, tech: 1.0, cost: 1.0,
                      army: (20, 120, 134, 900, 130), air: 30, navy: (0, 0, 0),
                      res: [.food: 0.1]))
        list.append(c("AUT", "Autriche", .westernEurope, pop: 9.2, area: 84, gdp: 530, growth: 0.3, debt: 80,
                      revenue: 50, mil: 0.9, industry: 17, tech: 0.9, cost: 0.9,
                      army: (16, 120, 50, 400, 30), air: 15, navy: (0, 0, 0),
                      res: [.steel: 0.4, .food: 0.2]))
        list.append(c("PRT", "Portugal", .westernEurope, pop: 10.4, area: 92, gdp: 310, growth: 1.9, debt: 95,
                      revenue: 44, mil: 1.5, industry: 12, tech: 0.7, cost: 0.75,
                      army: (27, 210, 40, 400, 50), air: 25, navy: (5, 0, 2),
                      res: [.food: 0.2]))
        list.append(c("GRC", "Grèce", .westernEurope, pop: 10.4, area: 132, gdp: 260, growth: 2.2, debt: 150,
                      revenue: 48, mil: 3.1, industry: 9, tech: 0.7, cost: 0.5,
                      army: (130, 220, 1300, 3000, 650), air: 200, navy: (13, 0, 11),
                      res: [.aluminium: 0.3, .food: 0.3]))
        list.append(c("SWE", "Suède", .westernEurope, pop: 10.6, area: 450, gdp: 620, growth: 1.5, debt: 32,
                      revenue: 48, mil: 2.2, industry: 13, tech: 0.95, cost: 0.95,
                      army: (25, 32, 120, 1200, 50), air: 90, navy: (7, 0, 4),
                      res: [.steel: 0.25, .aluminium: 0.2, .food: 0.2]))
        list.append(c("NOR", "Norvège", .westernEurope, pop: 5.6, area: 385, gdp: 500, growth: 1.5, debt: 44,
                      revenue: 55, mil: 2.2, industry: 7, tech: 1.0, cost: 0.95,
                      army: (25, 40, 36, 700, 40), air: 50, navy: (4, 0, 6),
                      res: [.oil: 2.0, .gas: 3.0, .aluminium: 1.9, .food: 0.05]))
        list.append(c("FIN", "Finlande", .westernEurope, pop: 5.6, area: 338, gdp: 310, growth: 0.5, debt: 82,
                      revenue: 52, mil: 2.4, industry: 14, tech: 0.9, cost: 0.95,
                      army: (24, 238, 200, 1500, 1500), air: 60, navy: (6, 0, 0),
                      res: [.steel: 0.2, .food: 0.1]))
        list.append(c("DNK", "Danemark", .westernEurope, pop: 6.0, area: 43, gdp: 430, growth: 2.5, debt: 30,
                      revenue: 46, mil: 3.0, industry: 13, tech: 0.95, cost: 0.95,
                      army: (15, 40, 44, 700, 30), air: 30, navy: (6, 0, 0),
                      res: [.oil: 0.1, .food: 0.4]))

        // Europe de l'Est
        list.append(c("POL", "Pologne", .easternEurope, pop: 37, area: 313, gdp: 980, growth: 3.2, debt: 55,
                      revenue: 41, mil: 4.5, industry: 17, tech: 0.6, cost: 0.6,
                      army: (200, 50, 800, 3500, 900), air: 90, navy: (2, 0, 1),
                      res: [.gas: 0.1, .steel: 0.4, .food: 0.8]))
        list.append(c("ROU", "Roumanie", .easternEurope, pop: 19, area: 238, gdp: 380, growth: 1.0, debt: 55,
                      revenue: 33, mil: 2.3, industry: 18, tech: 0.5, cost: 0.5,
                      army: (70, 50, 380, 1100, 600), air: 30, navy: (4, 0, 0),
                      res: [.gas: 0.2, .steel: 0.2, .food: 0.5]))
        list.append(c("CZE", "Tchéquie", .easternEurope, pop: 10.9, area: 79, gdp: 350, growth: 1.8, debt: 43,
                      revenue: 41, mil: 2.0, industry: 25, tech: 0.65, cost: 0.65,
                      army: (27, 3, 30, 600, 90), air: 15, navy: (0, 0, 0),
                      res: [.steel: 0.25, .food: 0.2]))
        list.append(c("HUN", "Hongrie", .easternEurope, pop: 9.6, area: 93, gdp: 220, growth: 0.8, debt: 74,
                      revenue: 44, mil: 2.1, industry: 18, tech: 0.5, cost: 0.5,
                      army: (41, 20, 50, 400, 30), air: 14, navy: (0, 0, 0),
                      res: [.food: 0.3]))
        list.append(c("UKR", "Ukraine", .easternEurope, pop: 37, area: 604, gdp: 200, growth: 2.0, debt: 95,
                      revenue: 25, mil: 26, industry: 10, tech: 0.6, cost: 0.3,
                      army: (900, 1200, 1000, 3500, 2500), air: 70, navy: (1, 0, 0),
                      res: [.gas: 0.4, .steel: 0.4, .food: 1.0]))
        list.append(c("BLR", "Biélorussie", .easternEurope, pop: 9.1, area: 208, gdp: 75, growth: 2.0, debt: 40,
                      revenue: 30, mil: 1.5, industry: 22, tech: 0.3, cost: 0.3,
                      army: (48, 290, 500, 1500, 1000), air: 50, navy: (0, 0, 0),
                      res: [.steel: 0.15, .food: 0.3]))
        list.append(c("RUS", "Russie", .easternEurope, pop: 144, area: 17098, gdp: 2100, growth: 1.0, debt: 20,
                      revenue: 35, mil: 6.3, industry: 14, tech: 0.75, cost: 0.35,
                      army: (1100, 2000, 3000, 10000, 6000), air: 1100, navy: (80, 0, 60), nukes: 5580,
                      res: [.oil: 11, .gas: 15, .steel: 3.8, .aluminium: 5.3, .criticalMinerals: 3, .semiconductors: 0.2, .food: 3]))

        // Moyen-Orient
        list.append(c("TUR", "Turquie", .middleEast, pop: 87, area: 784, gdp: 1400, growth: 3.0, debt: 25,
                      revenue: 30, mil: 2.1, industry: 20, tech: 0.6, cost: 0.4,
                      army: (355, 380, 2200, 9000, 2500), air: 270, navy: (30, 0, 12),
                      res: [.steel: 2.0, .aluminium: 0.1, .food: 1.5]))
        list.append(c("ISR", "Israël", .middleEast, pop: 10, area: 22, gdp: 560, growth: 3.0, debt: 68,
                      revenue: 33, mil: 7.0, industry: 12, tech: 1.0, cost: 0.6,
                      army: (170, 465, 1300, 6000, 800), air: 340, navy: (7, 0, 5), nukes: 90,
                      res: [.gas: 0.6, .semiconductors: 1.0, .food: 0.1]))
        list.append(c("IRN", "Iran", .middleEast, pop: 91, area: 1648, gdp: 400, growth: 0.5, debt: 35,
                      revenue: 12, mil: 3.0, industry: 20, tech: 0.55, cost: 0.25,
                      army: (610, 350, 1700, 3000, 3000), air: 180, navy: (10, 0, 19),
                      res: [.oil: 4.0, .gas: 6.5, .steel: 1.6, .aluminium: 0.6, .food: 1.0]))
        list.append(c("IRQ", "Irak", .middleEast, pop: 46, area: 438, gdp: 260, growth: 1.0, debt: 45,
                      revenue: 30, mil: 2.5, industry: 3, tech: 0.35, cost: 0.3,
                      army: (193, 0, 400, 2000, 300), air: 40, navy: (0, 0, 0),
                      res: [.oil: 4.5, .gas: 0.3, .food: 0.3]))
        list.append(c("SAU", "Arabie saoudite", .middleEast, pop: 35, area: 2150, gdp: 1100, growth: 3.5, debt: 30,
                      revenue: 28, mil: 6.5, industry: 15, tech: 0.65, cost: 0.45,
                      army: (257, 0, 1060, 10000, 1000), air: 280, navy: (11, 0, 0),
                      res: [.oil: 11, .gas: 3.0, .steel: 0.5, .aluminium: 1.4, .food: 0.15]))
        list.append(c("ARE", "Émirats arabes unis", .middleEast, pop: 11, area: 84, gdp: 550, growth: 4.5, debt: 30,
                      revenue: 28, mil: 5.0, industry: 9, tech: 0.75, cost: 0.55,
                      army: (65, 130, 350, 3000, 250), air: 120, navy: (10, 0, 0),
                      res: [.oil: 4.0, .gas: 1.4, .aluminium: 3.7, .food: 0.05]))
        list.append(c("QAT", "Qatar", .middleEast, pop: 3.1, area: 12, gdp: 220, growth: 2.5, debt: 40,
                      revenue: 35, mil: 4.0, industry: 8, tech: 0.85, cost: 0.5,
                      army: (17, 0, 100, 500, 50), air: 90, navy: (7, 0, 0),
                      res: [.oil: 1.8, .gas: 4.5, .aluminium: 0.9, .food: 0.01]))
        list.append(c("KWT", "Koweït", .middleEast, pop: 4.9, area: 18, gdp: 160, growth: 2.0, debt: 7,
                      revenue: 50, mil: 5.0, industry: 6, tech: 0.75, cost: 0.45,
                      army: (18, 24, 300, 1000, 100), air: 50, navy: (0, 0, 0),
                      res: [.oil: 3.0, .gas: 0.4, .food: 0.02]))
        list.append(c("SYR", "Syrie", .middleEast, pop: 23, area: 185, gdp: 25, growth: 1.0, debt: 100,
                      revenue: 10, mil: 3.0, industry: 10, tech: 0.25, cost: 0.2,
                      army: (100, 0, 200, 500, 300), air: 10, navy: (0, 0, 0),
                      res: [.oil: 0.05, .food: 0.15]))

        // Afrique du Nord
        list.append(c("EGY", "Égypte", .northAfrica, pop: 116, area: 1002, gdp: 350, growth: 4.0, debt: 90,
                      revenue: 20, mil: 2.0, industry: 15, tech: 0.3, cost: 0.2,
                      army: (440, 480, 2800, 8000, 2000), air: 330, navy: (22, 0, 8),
                      res: [.oil: 0.6, .gas: 1.5, .steel: 0.6, .aluminium: 0.4, .food: 0.9]))
        list.append(c("DZA", "Algérie", .northAfrica, pop: 47, area: 2382, gdp: 270, growth: 3.5, debt: 50,
                      revenue: 30, mil: 7.5, industry: 35, tech: 0.4, cost: 0.35,
                      army: (140, 150, 1500, 4000, 1000), air: 120, navy: (9, 0, 6),
                      res: [.oil: 1.3, .gas: 2.5, .steel: 0.2, .food: 0.4]))
        list.append(c("LBY", "Libye", .northAfrica, pop: 7.4, area: 1760, gdp: 45, growth: 5.0, debt: 5,
                      revenue: 50, mil: 3.0, industry: 50, tech: 0.2, cost: 0.3,
                      army: (40, 0, 200, 500, 200), air: 15, navy: (0, 0, 0),
                      res: [.oil: 1.3, .gas: 0.3, .food: 0.05]))
        list.append(c("MAR", "Maroc", .northAfrica, pop: 37.5, area: 447, gdp: 160, growth: 3.5, debt: 70,
                      revenue: 27, mil: 3.5, industry: 15, tech: 0.4, cost: 0.4,
                      army: (200, 150, 900, 2500, 500), air: 80, navy: (6, 0, 0),
                      res: [.food: 0.4]))

        // Afrique subsaharienne
        list.append(c("NGA", "Nigeria", .subSaharanAfrica, pop: 230, area: 924, gdp: 250, growth: 3.5, debt: 50,
                      revenue: 10, mil: 1.0, industry: 15, tech: 0.25, cost: 0.2,
                      army: (230, 0, 100, 800, 200), air: 20, navy: (6, 0, 0),
                      res: [.oil: 1.6, .gas: 1.1, .food: 3.0]))
        list.append(c("ETH", "Éthiopie", .subSaharanAfrica, pop: 130, area: 1104, gdp: 140, growth: 6.5, debt: 40,
                      revenue: 8, mil: 0.8, industry: 7, tech: 0.2, cost: 0.2,
                      army: (160, 0, 400, 300, 600), air: 20, navy: (0, 0, 0),
                      res: [.food: 1.0]))
        list.append(c("ZAF", "Afrique du Sud", .subSaharanAfrica, pop: 64, area: 1221, gdp: 410, growth: 1.0, debt: 76,
                      revenue: 28, mil: 0.7, industry: 13, tech: 0.55, cost: 0.45,
                      army: (70, 15, 100, 1500, 150), air: 25, navy: (4, 0, 3),
                      res: [.steel: 0.25, .aluminium: 0.8, .criticalMinerals: 3, .food: 0.6]))
        list.append(c("AGO", "Angola", .subSaharanAfrica, pop: 38, area: 1247, gdp: 110, growth: 2.5, debt: 65,
                      revenue: 20, mil: 1.3, industry: 50, tech: 0.25, cost: 0.3,
                      army: (107, 0, 300, 1000, 500), air: 40, navy: (0, 0, 0),
                      res: [.oil: 1.2, .gas: 0.2, .food: 0.3]))
        list.append(c("KEN", "Kenya", .subSaharanAfrica, pop: 57, area: 580, gdp: 130, growth: 5.0, debt: 70,
                      revenue: 17, mil: 1.0, industry: 8, tech: 0.25, cost: 0.3,
                      army: (24, 0, 80, 400, 80), air: 20, navy: (0, 0, 0),
                      res: [.food: 0.4]))
        list.append(c("COD", "RD Congo", .subSaharanAfrica, pop: 110, area: 2345, gdp: 75, growth: 6.0, debt: 20,
                      revenue: 13, mil: 1.5, industry: 20, tech: 0.15, cost: 0.2,
                      army: (135, 0, 100, 200, 300), air: 5, navy: (0, 0, 0),
                      res: [.criticalMinerals: 6, .food: 0.5]))

        // Asie du Sud et centrale
        list.append(c("IND", "Inde", .southAsia, pop: 1460, area: 3287, gdp: 4200, growth: 6.5, debt: 81,
                      revenue: 19, mil: 2.3, industry: 13, tech: 0.55, cost: 0.25,
                      army: (1460, 1150, 4200, 9000, 9000), air: 600, navy: (45, 2, 18), nukes: 180,
                      res: [.oil: 0.8, .gas: 0.8, .steel: 7.5, .aluminium: 5.7, .criticalMinerals: 0.5, .semiconductors: 0.3, .food: 11]))
        list.append(c("PAK", "Pakistan", .southAsia, pop: 250, area: 882, gdp: 410, growth: 3.0, debt: 70,
                      revenue: 12, mil: 2.8, industry: 13, tech: 0.35, cost: 0.25,
                      army: (650, 550, 2600, 4000, 4500), air: 400, navy: (12, 0, 8), nukes: 170,
                      res: [.gas: 0.8, .steel: 0.3, .food: 2.0]))
        list.append(c("BGD", "Bangladesh", .southAsia, pop: 175, area: 148, gdp: 470, growth: 4.5, debt: 40,
                      revenue: 9, mil: 1.0, industry: 21, tech: 0.3, cost: 0.3,
                      army: (160, 0, 300, 600, 500), air: 45, navy: (8, 0, 2),
                      res: [.gas: 0.6, .food: 1.5]))
        list.append(c("KAZ", "Kazakhstan", .centralAsia, pop: 20.6, area: 2725, gdp: 300, growth: 5.0, debt: 25,
                      revenue: 20, mil: 0.9, industry: 13, tech: 0.4, cost: 0.4,
                      army: (40, 0, 350, 1500, 600), air: 60, navy: (0, 0, 0),
                      res: [.oil: 2.0, .gas: 0.7, .steel: 0.3, .aluminium: 0.4, .criticalMinerals: 1, .food: 0.4]))
        list.append(c("TKM", "Turkménistan", .centralAsia, pop: 6.5, area: 488, gdp: 80, growth: 6.0, debt: 5,
                      revenue: 15, mil: 2.0, industry: 30, tech: 0.25, cost: 0.25,
                      army: (36, 0, 300, 1500, 500), air: 30, navy: (0, 0, 0),
                      res: [.oil: 0.3, .gas: 2.0]))

        // Asie de l'Est
        list.append(c("CHN", "Chine", .eastAsia, pop: 1408, area: 9597, gdp: 19400, growth: 4.5, debt: 90,
                      revenue: 26, mil: 1.7, industry: 27, tech: 0.85, cost: 0.5,
                      army: (2035, 510, 5000, 9000, 7000), air: 1700, navy: (160, 3, 60), nukes: 600,
                      res: [.oil: 4.2, .gas: 6.0, .steel: 54, .aluminium: 59, .criticalMinerals: 55, .semiconductors: 15, .food: 20]))
        list.append(c("JPN", "Japon", .eastAsia, pop: 123, area: 378, gdp: 4200, growth: 0.8, debt: 235,
                      revenue: 37, mil: 1.6, industry: 19, tech: 0.95, cost: 0.8,
                      army: (247, 56, 500, 1500, 500), air: 330, navy: (52, 2, 24),
                      res: [.steel: 4.6, .semiconductors: 8, .food: 0.8]))
        list.append(c("KOR", "Corée du Sud", .eastAsia, pop: 51.7, area: 100, gdp: 1850, growth: 1.5, debt: 49,
                      revenue: 23, mil: 2.6, industry: 25, tech: 0.95, cost: 0.6,
                      army: (500, 3100, 2200, 3500, 5500), air: 400, navy: (28, 0, 21),
                      res: [.steel: 3.4, .semiconductors: 18, .food: 0.4]))
        list.append(c("PRK", "Corée du Nord", .eastAsia, pop: 26, area: 121, gdp: 30, growth: 2.0, debt: 0,
                      revenue: 25, mil: 25, industry: 30, tech: 0.35, cost: 0.1,
                      army: (1280, 600, 4000, 2500, 14000), air: 450, navy: (15, 0, 70), nukes: 50,
                      res: [.steel: 0.05, .criticalMinerals: 0.2, .food: 0.2]))
        list.append(c("TWN", "Taïwan", .eastAsia, pop: 23.3, area: 36, gdp: 800, growth: 4.0, debt: 27,
                      revenue: 13, mil: 3.3, industry: 35, tech: 0.95, cost: 0.85,
                      army: (170, 1650, 1000, 1500, 1600), air: 400, navy: (26, 0, 4),
                      res: [.steel: 1.0, .semiconductors: 45, .food: 0.2]))

        // Asie du Sud-Est
        list.append(c("VNM", "Viêt Nam", .southeastAsia, pop: 101, area: 331, gdp: 480, growth: 6.5, debt: 37,
                      revenue: 18, mil: 2.2, industry: 24, tech: 0.5, cost: 0.3,
                      army: (450, 5000, 2000, 2500, 3000), air: 70, navy: (20, 0, 6),
                      res: [.oil: 0.2, .gas: 0.2, .steel: 1.2, .criticalMinerals: 0.5, .semiconductors: 0.5, .food: 1.2]))
        list.append(c("THA", "Thaïlande", .southeastAsia, pop: 71, area: 513, gdp: 550, growth: 2.0, debt: 63,
                      revenue: 20, mil: 1.4, industry: 25, tech: 0.5, cost: 0.35,
                      army: (360, 200, 600, 2000, 900), air: 100, navy: (18, 0, 0),
                      res: [.gas: 0.6, .steel: 0.2, .criticalMinerals: 0.5, .semiconductors: 0.5, .food: 1.2]))
        list.append(c("MYS", "Malaisie", .southeastAsia, pop: 35.5, area: 330, gdp: 470, growth: 4.5, debt: 64,
                      revenue: 16, mil: 1.0, industry: 23, tech: 0.5, cost: 0.5,
                      army: (113, 50, 48, 1200, 200), air: 40, navy: (6, 0, 2),
                      res: [.oil: 0.6, .gas: 2.0, .aluminium: 1.2, .semiconductors: 2, .food: 0.5]))
        list.append(c("SGP", "Singapour", .southeastAsia, pop: 6.0, area: 0.7, gdp: 560, growth: 2.5, debt: 30,
                      revenue: 18, mil: 2.8, industry: 20, tech: 1.0, cost: 0.95,
                      army: (51, 250, 120, 2000, 200), air: 100, navy: (8, 0, 4),
                      res: [.semiconductors: 3]))
        list.append(c("IDN", "Indonésie", .southeastAsia, pop: 284, area: 1905, gdp: 1450, growth: 5.0, debt: 40,
                      revenue: 12, mil: 0.8, industry: 19, tech: 0.35, cost: 0.4,
                      army: (400, 400, 450, 1500, 800), air: 100, navy: (30, 0, 4),
                      res: [.oil: 0.6, .gas: 1.5, .steel: 1.0, .aluminium: 0.5, .criticalMinerals: 4, .food: 3.5]))
        list.append(c("PHL", "Philippines", .southeastAsia, pop: 115, area: 300, gdp: 490, growth: 5.5, debt: 60,
                      revenue: 16, mil: 1.3, industry: 17, tech: 0.35, cost: 0.4,
                      army: (150, 130, 10, 600, 300), air: 30, navy: (5, 0, 0),
                      res: [.criticalMinerals: 0.5, .semiconductors: 0.3, .food: 1.0]))
        list.append(c("MMR", "Birmanie", .southeastAsia, pop: 54, area: 677, gdp: 65, growth: 1.0, debt: 60,
                      revenue: 10, mil: 3.5, industry: 22, tech: 0.15, cost: 0.2,
                      army: (150, 0, 300, 800, 500), air: 100, navy: (6, 0, 2),
                      res: [.gas: 0.4, .criticalMinerals: 3, .food: 0.5]))

        // Océanie
        list.append(c("AUS", "Australie", .oceania, pop: 27.5, area: 7692, gdp: 1800, growth: 1.8, debt: 48,
                      revenue: 36, mil: 2.1, industry: 6, tech: 0.9, cost: 0.95,
                      army: (58, 30, 59, 1500, 50), air: 120, navy: (11, 0, 6),
                      res: [.oil: 0.4, .gas: 3.7, .steel: 0.3, .aluminium: 2.1, .criticalMinerals: 8, .food: 1.0]))
        list.append(c("NZL", "Nouvelle-Zélande", .oceania, pop: 5.3, area: 268, gdp: 260, growth: 1.0, debt: 45,
                      revenue: 35, mil: 1.2, industry: 10, tech: 0.85, cost: 0.9,
                      army: (9, 3, 0, 150, 30), air: 0, navy: (2, 0, 0),
                      res: [.food: 0.3]))

        return list
    }
}
