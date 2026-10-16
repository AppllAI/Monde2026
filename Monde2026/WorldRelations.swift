import Foundation

// =============================================================
//  WorldRelations.swift
//  La géopolitique au 1er janvier 2026 : blocs, alliances,
//  sanctions, revendications, territoires contestés, rivalités.
//  (Situation d'après l'actualité connue jusqu'à mi-2026.)
// =============================================================

enum WorldRelations {

    // MARK: - Personnalité de l'IA (0 = pacifique, 1 = très agressive)

    static let aggressiveness: [CountryID: Double] = [
        "RUS": 0.7, "ISR": 0.5, "AZE": 0.45, "PRK": 0.5, "CHN": 0.35, "IRN": 0.4, "VEN": 0.3,
        "TUR": 0.35, "USA": 0.3, "ETH": 0.35, "PAK": 0.3, "IND": 0.25, "RWA": 0.4, "SAU": 0.3,
        "ARE": 0.3, "SRB": 0.25, "ERI": 0.4, "SDN": 0.4
    ]

    // MARK: - Blocs

    static let nato: [CountryID] = [
        "USA", "CAN", "GBR", "FRA", "DEU", "ITA", "ESP", "NLD", "BEL", "LUX", "PRT", "NOR", "DNK", "ISL",
        "GRC", "TUR", "POL", "CZE", "SVK", "HUN", "ROU", "BGR", "HRV", "SVN", "ALB", "MNE", "MKD",
        "LTU", "LVA", "EST", "FIN", "SWE"
    ]

    static let europeanUnion: [CountryID] = [
        "AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN",
        "IRL", "ITA", "LVA", "LTU", "LUX", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE"
    ]

    static let blocs: [Bloc] = [
        Bloc(id: "OTAN", name: "OTAN", members: nato, isMilitary: true, isEconomic: false, leader: "USA"),
        Bloc(id: "UE", name: "Union européenne", members: europeanUnion, isMilitary: false, isEconomic: true),
        Bloc(id: "OTSC", name: "OTSC", members: ["RUS", "BLR", "KAZ", "KGZ", "TJK"], isMilitary: true, isEconomic: false, leader: "RUS"),
        Bloc(id: "CCG", name: "Conseil de coopération du Golfe", members: ["SAU", "ARE", "QAT", "KWT", "OMN", "BHR"],
             isMilitary: true, isEconomic: true, leader: "SAU"),
        Bloc(id: "AES", name: "Alliance des États du Sahel", members: ["MLI", "BFA", "NER"], isMilitary: true, isEconomic: false, leader: "MLI"),
        Bloc(id: "BRICS", name: "BRICS", members: ["BRA", "RUS", "IND", "CHN", "ZAF", "EGY", "ETH", "IRN", "ARE", "IDN"],
             isMilitary: false, isEconomic: true),
        Bloc(id: "ASEAN", name: "ASEAN", members: ["IDN", "THA", "MYS", "SGP", "PHL", "VNM", "MMR", "KHM", "LAO"],
             isMilitary: false, isEconomic: true),
        Bloc(id: "MERCOSUR", name: "Mercosur", members: ["BRA", "ARG", "URY", "PRY", "BOL"], isMilitary: false, isEconomic: true),
        Bloc(id: "UEEA", name: "Union économique eurasiatique", members: ["RUS", "BLR", "KAZ", "KGZ", "ARM"],
             isMilitary: false, isEconomic: true),
        Bloc(id: "ACEUM", name: "ACEUM (USA-Mexique-Canada)", members: ["USA", "CAN", "MEX"], isMilitary: false, isEconomic: true),
        Bloc(id: "OCS", name: "Organisation de coopération de Shanghai",
             members: ["CHN", "RUS", "IND", "PAK", "IRN", "KAZ", "KGZ", "TJK", "UZB", "BLR"], isMilitary: false, isEconomic: false)
    ]

    /// Blocs militaires rivaux (relations de base dégradées entre leurs membres).
    static let opposedBlocs: [(String, String)] = [("OTAN", "OTSC")]

    // MARK: - Traités bilatéraux

    static let alliances: [(CountryID, CountryID)] = [
        ("USA", "JPN"), ("USA", "KOR"), ("USA", "PHL"), ("USA", "AUS"), ("AUS", "NZL"), ("CHN", "PRK"),
        ("RUS", "PRK"), ("SAU", "PAK"), ("TUR", "AZE")
    ]

    /// (garant, garanti) : soutien militaire probable en cas d'agression.
    static let guarantees: [(CountryID, CountryID)] = [
        ("USA", "TWN"), ("USA", "ISR"), ("USA", "XKX"), ("USA", "GUY"), ("FRA", "ARM"), ("RUS", "BLR")
    ]

    static let nonAggressionPacts: [(CountryID, CountryID)] = [("CHN", "RUS")]

    static let tradePacts: [(CountryID, CountryID)] = [
        ("USA", "KOR"), ("USA", "AUS"), ("USA", "ISR"), ("CHN", "PAK"), ("IND", "ARE"), ("JPN", "AUS"),
        ("CHN", "AUS"), ("CHN", "KOR"), ("CHN", "NZL"), ("GBR", "AUS"), ("GBR", "JPN"), ("CHN", "RUS"),
        ("RUS", "IND"), ("TUR", "AZE")
    ]

    /// Pays qui appliquent les sanctions « occidentales » (en plus des membres de l'UE).
    static let westernSanctioners: [CountryID] = ["USA", "GBR", "CAN", "JPN", "AUS", "CHE", "NOR", "NZL", "ISL"]

    static let westernSanctionTargets: [CountryID] = ["RUS", "BLR", "IRN", "PRK"]

    static let otherSanctions: [(CountryID, CountryID)] = [
        ("USA", "VEN"), ("USA", "CUB"), ("USA", "MMR"), ("GBR", "MMR"), ("USA", "NIC")
    ]

    // MARK: - Revendications territoriales

    static let claims: [Claim] = [
        Claim(claimant: "RUS", target: "UKR", name: "Oblasts ukrainiens", major: true),
        Claim(claimant: "CHN", target: "TWN", name: "Réunification avec Taïwan", major: true),
        Claim(claimant: "VEN", target: "GUY", name: "Essequibo", major: true),
        Claim(claimant: "PAK", target: "IND", name: "Cachemire", major: true),
        Claim(claimant: "IND", target: "PAK", name: "Cachemire", major: true),
        Claim(claimant: "PRK", target: "KOR", name: "Réunification", major: true),
        Claim(claimant: "KOR", target: "PRK", name: "Réunification", major: true),
        Claim(claimant: "SRB", target: "XKX", name: "Kosovo", major: true),
        Claim(claimant: "SYR", target: "ISR", name: "Plateau du Golan", major: true),
        Claim(claimant: "ETH", target: "ERI", name: "Accès à la mer Rouge", major: true),
        Claim(claimant: "ARG", target: "GBR", name: "Îles Malouines", major: false),
        Claim(claimant: "CHN", target: "IND", name: "Arunachal Pradesh", major: false),
        Claim(claimant: "IND", target: "CHN", name: "Aksaï Chin", major: false),
        Claim(claimant: "CHN", target: "JPN", name: "Îles Senkaku / Diaoyu", major: false),
        Claim(claimant: "CHN", target: "PHL", name: "Mer de Chine méridionale", major: false),
        Claim(claimant: "CHN", target: "VNM", name: "Paracels et Spratleys", major: false),
        Claim(claimant: "THA", target: "KHM", name: "Temples frontaliers", major: false),
        Claim(claimant: "KHM", target: "THA", name: "Temples frontaliers", major: false),
        Claim(claimant: "AZE", target: "ARM", name: "Corridor de Zanguezour", major: false),
        Claim(claimant: "TUR", target: "GRC", name: "Îles de la mer Égée", major: false),
        Claim(claimant: "GEO", target: "RUS", name: "Abkhazie et Ossétie du Sud", major: false),
        Claim(claimant: "MDA", target: "RUS", name: "Transnistrie", major: false),
        Claim(claimant: "CYP", target: "TUR", name: "Nord de Chypre", major: false)
    ]

    // MARK: - Territoires contrôlés par un autre pays au départ
    // (victime, occupant, part du territoire, guerre en cours ?)

    static let initialControl: [(CountryID, CountryID, Double, Bool)] = [
        ("UKR", "RUS", 0.19, true),     // Crimée, Donbass, sud de l'Ukraine
        ("GEO", "RUS", 0.20, false),    // Abkhazie, Ossétie du Sud
        ("MDA", "RUS", 0.12, false),    // Transnistrie (sous protection russe)
        ("CYP", "TUR", 0.36, false),    // Nord de Chypre
        ("SYR", "ISR", 0.01, false)     // Golan
    ]

    // MARK: - Relations (−100 hostile … +100 très proches)

    static let relations: [(CountryID, CountryID, Double)] = [
        // Guerre en Ukraine
        ("RUS", "UKR", -100), ("BLR", "UKR", -70), ("USA", "UKR", 50), ("GBR", "UKR", 80),
        ("FRA", "UKR", 75), ("DEU", "UKR", 75), ("POL", "UKR", 75), ("LTU", "UKR", 85), ("LVA", "UKR", 85),
        ("EST", "UKR", 85), ("FIN", "UKR", 75), ("SWE", "UKR", 75), ("DNK", "UKR", 80), ("NLD", "UKR", 75),
        ("NOR", "UKR", 70), ("CAN", "UKR", 75), ("CZE", "UKR", 65), ("HUN", "UKR", -30), ("SVK", "UKR", 10),
        ("JPN", "UKR", 50), ("PRK", "UKR", -60), ("IRN", "UKR", -50), ("RUS", "PRK", 75), ("RUS", "IRN", 60), ("RUS", "BLR", 90), ("CHN", "UKR", -10),
        // Russie et Occident
        ("USA", "RUS", -55), ("GBR", "RUS", -75), ("FRA", "RUS", -65), ("DEU", "RUS", -65), ("POL", "RUS", -85),
        ("LTU", "RUS", -85), ("LVA", "RUS", -85), ("EST", "RUS", -85), ("FIN", "RUS", -70), ("SWE", "RUS", -70),
        ("CAN", "RUS", -65), ("JPN", "RUS", -45), ("HUN", "RUS", 15), ("SRB", "RUS", 45), ("MDA", "RUS", -55),
        ("GEO", "RUS", -45), ("CHN", "RUS", 65), ("IND", "RUS", 50), ("TUR", "RUS", 10), ("KAZ", "RUS", 40),
        // Chine, Indo-Pacifique
        ("USA", "CHN", -45), ("CHN", "TWN", -75), ("USA", "TWN", 60), ("CHN", "JPN", -45), ("CHN", "PHL", -55),
        ("CHN", "VNM", -10), ("CHN", "IND", -30), ("CHN", "PRK", 45), ("CHN", "PAK", 80), ("CHN", "AUS", -10),
        ("CHN", "KHM", 65), ("CHN", "LAO", 55), ("CHN", "KOR", 0), ("JPN", "KOR", 25), ("KOR", "PRK", -90),
        ("JPN", "PRK", -85), ("USA", "PRK", -90), ("USA", "IND", 35), ("USA", "VNM", 25), ("JPN", "PHL", 45),
        ("IND", "PAK", -85), ("AFG", "PAK", -60), ("THA", "KHM", -50), ("BGD", "IND", -15), ("MMR", "CHN", 40),
        // Moyen-Orient
        ("USA", "IRN", -85), ("ISR", "IRN", -100), ("ISR", "LBN", -70), ("ISR", "YEM", -90), ("ISR", "SYR", -40),
        ("USA", "ISR", 75), ("TUR", "ISR", -60), ("IRN", "SAU", -15), ("SAU", "YEM", -60), ("ARE", "YEM", -40),
        ("IRN", "IRQ", 50), ("IRN", "SYR", -40), ("TUR", "SYR", 45), ("SAU", "SYR", 30), ("IRN", "ARE", -15),
        ("SAU", "QAT", 25), ("ISR", "EGY", 10), ("ISR", "JOR", 5), ("ISR", "ARE", 25), ("USA", "SAU", 50),
        ("USA", "QAT", 45), ("IRN", "YEM", 60), ("IRN", "LBN", 20), ("SAU", "PAK", 70), ("AZE", "ISR", 55),
        ("ARE", "SDN", -60), ("EGY", "ETH", -50), ("EGY", "SDN", 30),
        // Caucase
        ("ARM", "AZE", -40), ("ARM", "TUR", -30), ("AZE", "TUR", 90), ("ARM", "RUS", -15), ("AZE", "RUS", -30),
        ("ARM", "FRA", 55), ("ARM", "IRN", 35), ("ARM", "GEO", 30), ("AZE", "GEO", 35), ("AZE", "IRN", -20),
        // Europe
        ("GRC", "TUR", -20), ("CYP", "TUR", -60), ("SRB", "XKX", -75), ("SRB", "HRV", -20), ("ALB", "XKX", 80),
        ("USA", "GBR", 80), ("USA", "DEU", 50), ("USA", "FRA", 45), ("USA", "DNK", 20), ("GBR", "ARG", -25),
        ("HUN", "SVK", 20),
        // Afrique
        ("MAR", "DZA", -70), ("ETH", "ERI", -60), ("COD", "RWA", -55), ("SOM", "ETH", -20), ("SDN", "SSD", -20),
        ("MLI", "DZA", -50), ("MLI", "FRA", -60), ("BFA", "FRA", -60), ("NER", "FRA", -60), ("MLI", "RUS", 55),
        ("BFA", "RUS", 50), ("NER", "RUS", 45), ("TCD", "FRA", -20), ("SEN", "FRA", 10), ("CIV", "FRA", 45),
        ("ZAF", "ISR", -50), ("DZA", "FRA", -30),
        // Amériques
        ("USA", "VEN", -80), ("USA", "CUB", -60), ("USA", "NIC", -50), ("VEN", "GUY", -60), ("VEN", "COL", -10),
        ("USA", "MEX", 20), ("USA", "CAN", 30), ("USA", "BRA", -5), ("USA", "ARG", 45), ("USA", "SLV", 40),
        ("USA", "COL", -10), ("USA", "PAN", 15), ("RUS", "VEN", 55), ("RUS", "CUB", 55), ("RUS", "NIC", 50),
        ("CHN", "VEN", 45), ("CHN", "CUB", 45), ("IRN", "VEN", 50)
    ]
}
