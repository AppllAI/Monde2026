import Foundation

// =============================================================
//  WorldDataExtra.swift
//  99 pays supplémentaires (Caucase, Balkans, Baltes, Afrique,
//  Amérique centrale, Asie centrale…). Même format que WorldData.
//  Chiffres arrondis 2024-2025, à affiner librement.
// =============================================================

enum WorldDataExtra {

    // MARK: - Ajustements (aucune clé en double avec WorldData !)

    static let inflation: [CountryID: Double] = [
        "SDN": 0.8, "LBN": 0.15, "YEM": 0.2, "AFG": 0.0, "CUB": 0.3, "LAO": 0.2, "BOL": 0.2, "GHA": 0.2,
        "MWI": 0.3, "BDI": 0.3, "ZWE": 0.5, "ZMB": 0.15, "SSD": 0.5, "HTI": 0.25, "TUN": 0.07, "ERI": 0.1,
        "AZE": 0.05, "UZB": 0.1, "KGZ": 0.07, "MNG": 0.07, "NPL": 0.05, "LKA": 0.02, "MOZ": 0.04,
        "ECU": 0.02, "SRB": 0.04, "GEO": 0.03
    ]

    static let unemployment: [CountryID: Double] = [
        "ARM": 0.13, "GEO": 0.14, "BIH": 0.13, "MKD": 0.13, "XKX": 0.11, "SRB": 0.09, "JOR": 0.21,
        "LBN": 0.12, "YEM": 0.18, "AFG": 0.14, "TUN": 0.16, "SDN": 0.25, "NAM": 0.20, "BWA": 0.25,
        "ZWE": 0.10, "SOM": 0.20, "HTI": 0.15, "CUB": 0.02
    ]

    static let borrowingBonus: [CountryID: Double] = [
        "SDN": 0.05, "ZMB": 0.03, "LKA": 0.03, "GHA": 0.02, "ERI": 0.05, "CUB": 0.05, "LBN": 0.05,
        "LAO": 0.02, "IRL": 0.02, "LUX": 0.02, "EST": 0.01, "SVK": 0.015, "SVN": 0.015, "HRV": 0.015,
        "LTU": 0.015, "LVA": 0.015, "CYP": 0.015
    ]

    static let landShare: [CountryID: Double] = [
        "ARM": 0.8, "AZE": 0.8, "ERI": 0.9, "JOR": 0.8, "CUB": 0.75, "SDN": 0.85, "LKA": 0.8
    ]

    static let experience: [CountryID: Double] = [
        "AZE": 0.5, "ARM": 0.4, "SDN": 0.5, "SSD": 0.3, "ERI": 0.3, "RWA": 0.4, "MLI": 0.3, "BFA": 0.3,
        "YEM": 0.4, "AFG": 0.4, "SOM": 0.3
    ]

    static let drones: [CountryID: Double] = ["AZE": 1500, "ARM": 300, "YEM": 2000]

    static let missiles: [CountryID: Double] = ["AZE": 200, "ARM": 100, "YEM": 400]

    static let conscription: [CountryID: ConscriptionLaw] = [
        "ARM": .extensive, "AZE": .extensive, "GEO": .limited, "LTU": .limited, "LVA": .limited,
        "EST": .limited, "CYP": .limited, "ERI": .total, "CUB": .limited, "MNG": .limited, "UZB": .limited,
        "SRB": .limited, "MDA": .limited, "KGZ": .limited, "TJK": .limited
    ]

    static let foreignAid: [CountryID: Double] = ["JOR": 1.5, "SOM": 1.0, "AFG": 1.5, "MDA": 0.5]

    // MARK: - Frontières terrestres

    static let borders: [(CountryID, CountryID)] = [
        // Caucase
        ("ARM", "GEO"), ("ARM", "AZE"), ("ARM", "IRN"), ("ARM", "TUR"), ("AZE", "GEO"), ("AZE", "RUS"),
        ("AZE", "IRN"), ("GEO", "RUS"), ("GEO", "TUR"),
        // Europe de l'Est, Balkans, Baltes
        ("MDA", "ROU"), ("MDA", "UKR"), ("SRB", "HUN"), ("SRB", "ROU"), ("SRB", "BGR"), ("SRB", "HRV"),
        ("SRB", "BIH"), ("SRB", "MNE"), ("SRB", "MKD"), ("SRB", "XKX"), ("BGR", "ROU"), ("BGR", "GRC"),
        ("BGR", "TUR"), ("BGR", "MKD"), ("SVK", "CZE"), ("SVK", "POL"), ("SVK", "UKR"), ("SVK", "HUN"),
        ("SVK", "AUT"), ("HRV", "SVN"), ("HRV", "HUN"), ("HRV", "BIH"), ("HRV", "MNE"), ("SVN", "ITA"),
        ("SVN", "AUT"), ("SVN", "HUN"), ("BIH", "MNE"), ("ALB", "MNE"), ("ALB", "XKX"), ("ALB", "MKD"),
        ("ALB", "GRC"), ("MKD", "GRC"), ("MKD", "XKX"), ("MNE", "XKX"), ("LTU", "LVA"), ("LTU", "POL"),
        ("LTU", "BLR"), ("LTU", "RUS"), ("LVA", "EST"), ("LVA", "RUS"), ("LVA", "BLR"), ("EST", "RUS"),
        ("IRL", "GBR"), ("LUX", "FRA"), ("LUX", "BEL"), ("LUX", "DEU"),
        // Moyen-Orient
        ("JOR", "ISR"), ("JOR", "SYR"), ("JOR", "IRQ"), ("JOR", "SAU"), ("LBN", "SYR"), ("LBN", "ISR"),
        ("YEM", "SAU"), ("YEM", "OMN"), ("OMN", "SAU"), ("OMN", "ARE"), ("AFG", "IRN"), ("AFG", "PAK"),
        ("AFG", "TKM"), ("AFG", "UZB"), ("AFG", "TJK"), ("AFG", "CHN"),
        // Asie centrale, Asie
        ("UZB", "KAZ"), ("UZB", "KGZ"), ("UZB", "TJK"), ("UZB", "TKM"), ("KGZ", "KAZ"), ("KGZ", "TJK"),
        ("KGZ", "CHN"), ("TJK", "CHN"), ("MNG", "RUS"), ("MNG", "CHN"), ("NPL", "IND"), ("NPL", "CHN"),
        ("KHM", "THA"), ("KHM", "LAO"), ("KHM", "VNM"), ("LAO", "THA"), ("LAO", "VNM"), ("LAO", "CHN"),
        ("LAO", "MMR"), ("PNG", "IDN"),
        // Afrique
        ("TUN", "DZA"), ("TUN", "LBY"), ("SDN", "EGY"), ("SDN", "LBY"), ("SDN", "TCD"), ("SDN", "CAF"),
        ("SDN", "SSD"), ("SDN", "ETH"), ("SDN", "ERI"), ("SSD", "ETH"), ("SSD", "KEN"), ("SSD", "UGA"),
        ("SSD", "COD"), ("SSD", "CAF"), ("TCD", "LBY"), ("TCD", "NER"), ("TCD", "NGA"), ("TCD", "CMR"),
        ("TCD", "CAF"), ("NER", "DZA"), ("NER", "LBY"), ("NER", "MLI"), ("NER", "BFA"), ("NER", "BEN"),
        ("NER", "NGA"), ("MLI", "DZA"), ("MLI", "MRT"), ("MLI", "SEN"), ("MLI", "GIN"), ("MLI", "CIV"),
        ("MLI", "BFA"), ("BFA", "CIV"), ("BFA", "GHA"), ("BFA", "TGO"), ("BFA", "BEN"), ("SEN", "MRT"),
        ("SEN", "GIN"), ("GHA", "CIV"), ("GHA", "TGO"), ("CIV", "GIN"), ("CMR", "NGA"), ("CMR", "CAF"),
        ("CMR", "COG"), ("CMR", "GAB"), ("SOM", "ETH"), ("SOM", "KEN"), ("SOM", "DJI"), ("ERI", "ETH"),
        ("ERI", "DJI"), ("DJI", "ETH"), ("UGA", "KEN"), ("UGA", "TZA"), ("UGA", "RWA"), ("UGA", "COD"),
        ("TZA", "KEN"), ("TZA", "RWA"), ("TZA", "BDI"), ("TZA", "COD"), ("TZA", "ZMB"), ("TZA", "MWI"),
        ("TZA", "MOZ"), ("RWA", "COD"), ("RWA", "BDI"), ("BDI", "COD"), ("MOZ", "ZAF"), ("MOZ", "ZWE"),
        ("MOZ", "ZMB"), ("MOZ", "MWI"), ("ZMB", "COD"), ("ZMB", "AGO"), ("ZMB", "NAM"), ("ZMB", "ZWE"),
        ("ZMB", "MWI"), ("ZMB", "BWA"), ("ZWE", "ZAF"), ("ZWE", "BWA"), ("NAM", "AGO"), ("NAM", "BWA"),
        ("NAM", "ZAF"), ("BWA", "ZAF"), ("BEN", "TGO"), ("BEN", "NGA"), ("CAF", "COD"), ("CAF", "COG"),
        ("COG", "COD"), ("COG", "GAB"), ("COG", "AGO"), ("MRT", "DZA"),
        // Amériques (la Guyane française rend la France voisine du Brésil et du Suriname)
        ("ECU", "COL"), ("ECU", "PER"), ("BOL", "PER"), ("BOL", "BRA"), ("BOL", "PRY"), ("BOL", "ARG"),
        ("BOL", "CHL"), ("PRY", "BRA"), ("PRY", "ARG"), ("URY", "BRA"), ("URY", "ARG"), ("GTM", "MEX"),
        ("GTM", "HND"), ("GTM", "SLV"), ("HND", "SLV"), ("HND", "NIC"), ("NIC", "CRI"), ("CRI", "PAN"),
        ("PAN", "COL"), ("DOM", "HTI"), ("GUY", "VEN"), ("GUY", "BRA"), ("GUY", "SUR"), ("SUR", "BRA"),
        ("SUR", "FRA"), ("BRA", "FRA"),
        // Petits États
        ("LBR", "SLE"), ("LBR", "GIN"), ("LBR", "CIV"), ("SLE", "GIN"), ("GMB", "SEN"), ("GNB", "SEN"), ("GNB", "GIN"),
        ("GNQ", "CMR"), ("GNQ", "GAB"), ("LSO", "ZAF"), ("SWZ", "ZAF"), ("SWZ", "MOZ"), ("BTN", "IND"), ("BTN", "CHN"),
        ("BRN", "MYS"), ("TLS", "IDN"), ("BLZ", "MEX"), ("BLZ", "GTM")
    ]

    // MARK: - Les pays
    // army: (actifs k, réservistes k, chars, blindés, artillerie) — navy: (navires, porte-avions, sous-marins)

    static func seeds() -> [CountrySeed] {
        typealias W = WorldData
        var list: [CountrySeed] = []

        // Caucase
        list.append(W.c("ARM", "Arménie", .easternEurope, pop: 3.0, area: 29.7, gdp: 25, growth: 5.5, debt: 50,
                        revenue: 25, mil: 5.5, industry: 20, tech: 0.45, cost: 0.3,
                        army: (42, 210, 110, 300, 250), air: 15, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.3, .food: 0.03]))
        list.append(W.c("AZE", "Azerbaïdjan", .easternEurope, pop: 10.2, area: 86.6, gdp: 75, growth: 2.5, debt: 22,
                        revenue: 30, mil: 5.0, industry: 45, tech: 0.4, cost: 0.3,
                        army: (64, 300, 450, 1000, 600), air: 30, navy: (2, 0, 0),
                        res: [.oil: 0.6, .gas: 0.9, .food: 0.1]))
        list.append(W.c("GEO", "Géorgie", .easternEurope, pop: 3.7, area: 69.7, gdp: 34, growth: 8.0, debt: 38,
                        revenue: 28, mil: 1.6, industry: 17, tech: 0.45, cost: 0.3,
                        army: (20, 0, 120, 200, 150), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.05]))

        // Europe de l'Est et Balkans
        list.append(W.c("MDA", "Moldavie", .easternEurope, pop: 2.4, area: 33.8, gdp: 19, growth: 1.0, debt: 38,
                        revenue: 32, mil: 0.6, industry: 15, tech: 0.4, cost: 0.3,
                        army: (6, 60, 0, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("SRB", "Serbie", .easternEurope, pop: 6.6, area: 77.5, gdp: 90, growth: 3.0, debt: 47,
                        revenue: 41, mil: 2.3, industry: 22, tech: 0.5, cost: 0.45,
                        army: (28, 50, 230, 600, 300), air: 25, navy: (0, 0, 0),
                        res: [.steel: 0.1, .food: 0.3]))
        list.append(W.c("BGR", "Bulgarie", .easternEurope, pop: 6.4, area: 111, gdp: 115, growth: 2.5, debt: 25,
                        revenue: 38, mil: 2.2, industry: 20, tech: 0.55, cost: 0.45,
                        army: (37, 3, 90, 400, 200), air: 15, navy: (4, 0, 0),
                        res: [.food: 0.3]))
        list.append(W.c("SVK", "Slovaquie", .easternEurope, pop: 5.4, area: 49, gdp: 145, growth: 1.5, debt: 59,
                        revenue: 42, mil: 2.0, industry: 30, tech: 0.65, cost: 0.6,
                        army: (16, 0, 30, 300, 40), air: 10, navy: (0, 0, 0),
                        res: [.steel: 0.25, .aluminium: 0.1]))
        list.append(W.c("HRV", "Croatie", .easternEurope, pop: 3.85, area: 56.6, gdp: 95, growth: 3.0, debt: 58,
                        revenue: 46, mil: 1.8, industry: 15, tech: 0.6, cost: 0.6,
                        army: (15, 20, 0, 300, 50), air: 12, navy: (5, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("SVN", "Slovénie", .easternEurope, pop: 2.1, area: 20.3, gdp: 75, growth: 2.0, debt: 67,
                        revenue: 44, mil: 1.3, industry: 23, tech: 0.7, cost: 0.7,
                        army: (7, 1, 14, 120, 20), air: 0, navy: (0, 0, 0),
                        res: [.aluminium: 0.05]))
        list.append(W.c("BIH", "Bosnie-Herzégovine", .easternEurope, pop: 3.2, area: 51.2, gdp: 30, growth: 2.5, debt: 28,
                        revenue: 40, mil: 0.8, industry: 18, tech: 0.4, cost: 0.35,
                        army: (10, 0, 30, 100, 100), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.03]))
        list.append(W.c("ALB", "Albanie", .easternEurope, pop: 2.4, area: 28.7, gdp: 27, growth: 3.5, debt: 56,
                        revenue: 27, mil: 2.0, industry: 12, tech: 0.45, cost: 0.35,
                        army: (7, 0, 0, 100, 20), air: 0, navy: (2, 0, 0),
                        res: [.oil: 0.02, .food: 0.05]))
        list.append(W.c("MKD", "Macédoine du Nord", .easternEurope, pop: 1.8, area: 25.7, gdp: 16, growth: 2.5, debt: 55,
                        revenue: 33, mil: 2.2, industry: 18, tech: 0.45, cost: 0.35,
                        army: (8, 5, 30, 100, 30), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.03]))
        list.append(W.c("MNE", "Monténégro", .easternEurope, pop: 0.62, area: 13.8, gdp: 8, growth: 3.0, debt: 60,
                        revenue: 42, mil: 1.9, industry: 10, tech: 0.5, cost: 0.45,
                        army: (2, 0, 0, 20, 10), air: 0, navy: (2, 0, 0)))
        list.append(W.c("XKX", "Kosovo", .easternEurope, pop: 1.6, area: 10.9, gdp: 11, growth: 4.0, debt: 18,
                        revenue: 30, mil: 1.5, industry: 15, tech: 0.4, cost: 0.35,
                        army: (5, 3, 0, 50, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("LTU", "Lituanie", .easternEurope, pop: 2.9, area: 65.3, gdp: 85, growth: 2.5, debt: 38,
                        revenue: 36, mil: 3.9, industry: 18, tech: 0.7, cost: 0.65,
                        army: (23, 104, 0, 500, 60), air: 0, navy: (4, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("LVA", "Lettonie", .easternEurope, pop: 1.85, area: 64.6, gdp: 45, growth: 1.0, debt: 46,
                        revenue: 38, mil: 3.5, industry: 13, tech: 0.65, cost: 0.6,
                        army: (8, 18, 0, 200, 50), air: 0, navy: (5, 0, 0),
                        res: [.food: 0.05]))
        list.append(W.c("EST", "Estonie", .easternEurope, pop: 1.37, area: 45.3, gdp: 43, growth: 0.5, debt: 23,
                        revenue: 40, mil: 3.4, industry: 15, tech: 0.8, cost: 0.75,
                        army: (8, 230, 0, 300, 60), air: 0, navy: (2, 0, 0)))

        // Europe de l'Ouest
        list.append(W.c("IRL", "Irlande", .westernEurope, pop: 5.4, area: 70.3, gdp: 600, growth: 3.0, debt: 40,
                        revenue: 22, mil: 0.25, industry: 35, tech: 0.9, cost: 0.95,
                        army: (8, 4, 0, 100, 20), air: 0, navy: (8, 0, 0),
                        res: [.semiconductors: 0.3, .food: 0.2]))
        list.append(W.c("ISL", "Islande", .westernEurope, pop: 0.39, area: 103, gdp: 33, growth: 1.5, debt: 60,
                        revenue: 42, mil: 0.0, industry: 10, tech: 0.9, cost: 1.0,
                        army: (0, 0, 0, 0, 0), air: 0, navy: (0, 0, 0),
                        res: [.aluminium: 1.2, .food: 0.02]))
        list.append(W.c("LUX", "Luxembourg", .westernEurope, pop: 0.67, area: 2.6, gdp: 95, growth: 1.5, debt: 26,
                        revenue: 44, mil: 0.8, industry: 6, tech: 1.0, cost: 1.0,
                        army: (1, 0, 0, 50, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("CYP", "Chypre", .westernEurope, pop: 1.35, area: 9.3, gdp: 37, growth: 3.0, debt: 65,
                        revenue: 41, mil: 1.6, industry: 8, tech: 0.7, cost: 0.7,
                        army: (12, 50, 130, 300, 100), air: 0, navy: (0, 0, 0)))

        // Moyen-Orient
        list.append(W.c("JOR", "Jordanie", .middleEast, pop: 11.5, area: 89, gdp: 55, growth: 2.5, debt: 90,
                        revenue: 26, mil: 4.5, industry: 17, tech: 0.4, cost: 0.35,
                        army: (100, 65, 600, 2000, 400), air: 50, navy: (0, 0, 0),
                        res: [.food: 0.05]))
        // Liban : dette « effective » (en défaut depuis 2020)
        list.append(W.c("LBN", "Liban", .middleEast, pop: 5.5, area: 10.4, gdp: 20, growth: 1.0, debt: 60,
                        revenue: 15, mil: 2.0, industry: 10, tech: 0.35, cost: 0.3,
                        army: (60, 0, 200, 1000, 150), air: 0, navy: (0, 0, 0)))
        list.append(W.c("YEM", "Yémen", .middleEast, pop: 40, area: 528, gdp: 20, growth: -1.0, debt: 70,
                        revenue: 8, mil: 4.0, industry: 10, tech: 0.1, cost: 0.15,
                        army: (40, 0, 100, 200, 100), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.1, .food: 0.1]))
        list.append(W.c("OMN", "Oman", .middleEast, pop: 5.3, area: 310, gdp: 110, growth: 2.5, debt: 35,
                        revenue: 32, mil: 6.0, industry: 30, tech: 0.6, cost: 0.45,
                        army: (43, 20, 120, 400, 150), air: 40, navy: (6, 0, 0),
                        res: [.oil: 1.1, .gas: 0.9, .aluminium: 0.4]))
        list.append(W.c("BHR", "Bahreïn", .middleEast, pop: 1.6, area: 0.8, gdp: 47, growth: 3.0, debt: 125,
                        revenue: 22, mil: 3.5, industry: 15, tech: 0.7, cost: 0.6,
                        army: (8, 0, 180, 400, 60), air: 30, navy: (1, 0, 0),
                        res: [.oil: 0.2, .aluminium: 2.0]))
        list.append(W.c("AFG", "Afghanistan", .middleEast, pop: 42, area: 652, gdp: 17, growth: 2.5, debt: 7,
                        revenue: 15, mil: 3.0, industry: 10, tech: 0.1, cost: 0.1,
                        army: (150, 0, 50, 300, 100), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.3, .food: 0.3]))

        // Asie centrale
        list.append(W.c("UZB", "Ouzbékistan", .centralAsia, pop: 37, area: 449, gdp: 115, growth: 6.0, debt: 33,
                        revenue: 27, mil: 2.0, industry: 25, tech: 0.35, cost: 0.3,
                        army: (48, 20, 350, 1000, 400), air: 50, navy: (0, 0, 0),
                        res: [.gas: 1.2, .criticalMinerals: 0.5, .food: 0.4]))
        list.append(W.c("KGZ", "Kirghizistan", .centralAsia, pop: 7.2, area: 200, gdp: 17, growth: 8.0, debt: 40,
                        revenue: 30, mil: 2.0, industry: 15, tech: 0.25, cost: 0.25,
                        army: (11, 0, 150, 300, 100), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.2]))
        list.append(W.c("TJK", "Tadjikistan", .centralAsia, pop: 10.5, area: 141, gdp: 14, growth: 8.0, debt: 30,
                        revenue: 28, mil: 1.5, industry: 15, tech: 0.2, cost: 0.2,
                        army: (9, 0, 40, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.aluminium: 0.4]))
        list.append(W.c("MNG", "Mongolie", .eastAsia, pop: 3.5, area: 1564, gdp: 23, growth: 5.0, debt: 45,
                        revenue: 33, mil: 0.7, industry: 30, tech: 0.3, cost: 0.3,
                        army: (10, 137, 400, 600, 400), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 1.0]))

        // Asie du Sud et du Sud-Est
        list.append(W.c("NPL", "Népal", .southAsia, pop: 30, area: 147, gdp: 43, growth: 4.0, debt: 45,
                        revenue: 18, mil: 1.0, industry: 12, tech: 0.2, cost: 0.15,
                        army: (96, 0, 0, 50, 50), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.3]))
        list.append(W.c("LKA", "Sri Lanka", .southAsia, pop: 22, area: 65.6, gdp: 100, growth: 4.0, debt: 100,
                        revenue: 13, mil: 2.0, industry: 20, tech: 0.35, cost: 0.2,
                        army: (220, 6, 60, 600, 200), air: 10, navy: (6, 0, 0),
                        res: [.food: 0.2]))
        list.append(W.c("KHM", "Cambodge", .southeastAsia, pop: 17.5, area: 181, gdp: 50, growth: 6.0, debt: 30,
                        revenue: 22, mil: 1.8, industry: 28, tech: 0.2, cost: 0.2,
                        army: (125, 0, 200, 400, 400), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.3]))
        list.append(W.c("LAO", "Laos", .southeastAsia, pop: 7.8, area: 237, gdp: 16, growth: 4.0, debt: 115,
                        revenue: 14, mil: 0.2, industry: 18, tech: 0.2, cost: 0.2,
                        army: (29, 0, 30, 80, 50), air: 0, navy: (0, 0, 0)))

        // Afrique du Nord et Sahel
        list.append(W.c("TUN", "Tunisie", .northAfrica, pop: 12.3, area: 163, gdp: 52, growth: 1.5, debt: 80,
                        revenue: 30, mil: 2.5, industry: 15, tech: 0.35, cost: 0.3,
                        army: (36, 0, 100, 500, 200), air: 15, navy: (4, 0, 0),
                        res: [.oil: 0.05, .gas: 0.05, .food: 0.2]))
        // Soudan : guerre civile depuis 2023 ; dette « effective » (arriérés)
        list.append(W.c("SDN", "Soudan", .subSaharanAfrica, pop: 50, area: 1886, gdp: 30, growth: -10, debt: 60,
                        revenue: 6, mil: 3.0, industry: 15, tech: 0.1, cost: 0.1,
                        army: (100, 0, 400, 500, 300), air: 40, navy: (0, 0, 0),
                        res: [.oil: 0.1, .food: 0.4]))
        list.append(W.c("SSD", "Soudan du Sud", .subSaharanAfrica, pop: 11.5, area: 644, gdp: 5, growth: -5, debt: 60,
                        revenue: 15, mil: 3.0, industry: 50, tech: 0.05, cost: 0.1,
                        army: (50, 0, 80, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.15]))
        list.append(W.c("TCD", "Tchad", .subSaharanAfrica, pop: 19, area: 1284, gdp: 13, growth: 3.5, debt: 40,
                        revenue: 15, mil: 2.5, industry: 30, tech: 0.1, cost: 0.15,
                        army: (35, 0, 60, 300, 50), air: 5, navy: (0, 0, 0),
                        res: [.oil: 0.07, .food: 0.2]))
        list.append(W.c("NER", "Niger", .subSaharanAfrica, pop: 27, area: 1267, gdp: 20, growth: 6.0, debt: 50,
                        revenue: 12, mil: 2.0, industry: 20, tech: 0.1, cost: 0.15,
                        army: (25, 0, 0, 200, 30), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.4, .food: 0.3]))
        list.append(W.c("MLI", "Mali", .subSaharanAfrica, pop: 24, area: 1240, gdp: 22, growth: 4.0, debt: 52,
                        revenue: 18, mil: 3.5, industry: 20, tech: 0.1, cost: 0.15,
                        army: (20, 0, 50, 200, 50), air: 10, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.3, .food: 0.3]))
        list.append(W.c("BFA", "Burkina Faso", .subSaharanAfrica, pop: 24, area: 274, gdp: 22, growth: 4.5, debt: 58,
                        revenue: 22, mil: 4.0, industry: 22, tech: 0.1, cost: 0.15,
                        army: (12, 0, 0, 200, 30), air: 5, navy: (0, 0, 0),
                        res: [.food: 0.2]))
        list.append(W.c("MRT", "Mauritanie", .northAfrica, pop: 5.1, area: 1031, gdp: 11, growth: 4.5, debt: 50,
                        revenue: 22, mil: 2.5, industry: 25, tech: 0.15, cost: 0.2,
                        army: (16, 0, 35, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.steel: 0.05, .criticalMinerals: 0.1]))

        // Afrique de l'Ouest et centrale
        list.append(W.c("SEN", "Sénégal", .subSaharanAfrica, pop: 18.5, area: 197, gdp: 33, growth: 8.0, debt: 100,
                        revenue: 20, mil: 1.5, industry: 22, tech: 0.25, cost: 0.25,
                        army: (14, 0, 0, 150, 30), air: 0, navy: (1, 0, 0),
                        res: [.oil: 0.1, .gas: 0.1, .food: 0.15]))
        list.append(W.c("GHA", "Ghana", .subSaharanAfrica, pop: 34, area: 239, gdp: 80, growth: 4.0, debt: 70,
                        revenue: 15, mil: 0.4, industry: 25, tech: 0.3, cost: 0.3,
                        army: (16, 0, 0, 150, 20), air: 5, navy: (4, 0, 0),
                        res: [.oil: 0.2, .criticalMinerals: 0.3, .food: 0.5]))
        list.append(W.c("CIV", "Côte d'Ivoire", .subSaharanAfrica, pop: 32, area: 322, gdp: 87, growth: 6.5, debt: 58,
                        revenue: 17, mil: 1.0, industry: 22, tech: 0.3, cost: 0.3,
                        army: (27, 0, 10, 200, 30), air: 0, navy: (2, 0, 0),
                        res: [.oil: 0.05, .food: 0.5]))
        list.append(W.c("GIN", "Guinée", .subSaharanAfrica, pop: 14.5, area: 246, gdp: 25, growth: 6.0, debt: 40,
                        revenue: 14, mil: 2.0, industry: 30, tech: 0.1, cost: 0.15,
                        army: (12, 0, 40, 100, 30), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.6]))
        list.append(W.c("BEN", "Bénin", .subSaharanAfrica, pop: 14.5, area: 115, gdp: 22, growth: 6.5, debt: 55,
                        revenue: 15, mil: 0.8, industry: 15, tech: 0.15, cost: 0.2,
                        army: (12, 0, 0, 50, 20), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.15]))
        list.append(W.c("TGO", "Togo", .subSaharanAfrica, pop: 9.5, area: 57, gdp: 10, growth: 5.5, debt: 67,
                        revenue: 17, mil: 2.0, industry: 15, tech: 0.15, cost: 0.2,
                        army: (14, 0, 0, 50, 20), air: 0, navy: (0, 0, 0)))
        list.append(W.c("CMR", "Cameroun", .subSaharanAfrica, pop: 29, area: 475, gdp: 55, growth: 3.5, debt: 45,
                        revenue: 15, mil: 1.0, industry: 25, tech: 0.2, cost: 0.2,
                        army: (25, 0, 0, 200, 30), air: 0, navy: (1, 0, 0),
                        res: [.oil: 0.07, .food: 0.4]))
        list.append(W.c("CAF", "Centrafrique", .subSaharanAfrica, pop: 5.5, area: 623, gdp: 3, growth: 1.5, debt: 55,
                        revenue: 10, mil: 1.5, industry: 15, tech: 0.05, cost: 0.1,
                        army: (10, 0, 0, 30, 10), air: 0, navy: (0, 0, 0)))
        list.append(W.c("COG", "Congo", .subSaharanAfrica, pop: 6.3, area: 342, gdp: 15, growth: 3.0, debt: 95,
                        revenue: 25, mil: 2.0, industry: 40, tech: 0.15, cost: 0.2,
                        army: (12, 0, 40, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.3]))
        list.append(W.c("GAB", "Gabon", .subSaharanAfrica, pop: 2.5, area: 268, gdp: 20, growth: 2.5, debt: 70,
                        revenue: 18, mil: 1.5, industry: 40, tech: 0.3, cost: 0.3,
                        army: (5, 0, 0, 100, 20), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.2, .criticalMinerals: 0.3]))

        // Corne de l'Afrique et Grands Lacs
        list.append(W.c("SOM", "Somalie", .subSaharanAfrica, pop: 19, area: 638, gdp: 12, growth: 3.5, debt: 10,
                        revenue: 5, mil: 2.5, industry: 7, tech: 0.05, cost: 0.1,
                        army: (25, 0, 0, 50, 20), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("ERI", "Érythrée", .subSaharanAfrica, pop: 3.7, area: 121, gdp: 3, growth: 3.0, debt: 60,
                        revenue: 20, mil: 10, industry: 20, tech: 0.1, cost: 0.1,
                        army: (200, 120, 150, 200, 150), air: 10, navy: (0, 0, 0)))
        list.append(W.c("DJI", "Djibouti", .subSaharanAfrica, pop: 1.2, area: 23.2, gdp: 4, growth: 6.0, debt: 40,
                        revenue: 22, mil: 3.5, industry: 10, tech: 0.2, cost: 0.3,
                        army: (10, 0, 0, 50, 20), air: 0, navy: (0, 0, 0)))
        list.append(W.c("UGA", "Ouganda", .subSaharanAfrica, pop: 50, area: 241, gdp: 60, growth: 6.0, debt: 50,
                        revenue: 14, mil: 2.0, industry: 20, tech: 0.2, cost: 0.2,
                        army: (45, 10, 240, 400, 200), air: 10, navy: (0, 0, 0),
                        res: [.food: 0.4]))
        list.append(W.c("TZA", "Tanzanie", .subSaharanAfrica, pop: 68, area: 947, gdp: 85, growth: 5.5, debt: 45,
                        revenue: 15, mil: 1.0, industry: 25, tech: 0.2, cost: 0.2,
                        army: (27, 80, 50, 200, 200), air: 10, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.3, .food: 0.6]))
        list.append(W.c("RWA", "Rwanda", .subSaharanAfrica, pop: 14, area: 26.3, gdp: 14, growth: 7.0, debt: 70,
                        revenue: 22, mil: 1.5, industry: 15, tech: 0.25, cost: 0.2,
                        army: (33, 0, 30, 150, 50), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.2]))
        list.append(W.c("BDI", "Burundi", .subSaharanAfrica, pop: 13.7, area: 27.8, gdp: 3, growth: 3.0, debt: 70,
                        revenue: 20, mil: 2.5, industry: 10, tech: 0.05, cost: 0.1,
                        army: (30, 0, 0, 50, 20), air: 0, navy: (0, 0, 0)))

        // Afrique australe et océan Indien
        list.append(W.c("MOZ", "Mozambique", .subSaharanAfrica, pop: 34, area: 801, gdp: 23, growth: 2.0, debt: 95,
                        revenue: 25, mil: 1.0, industry: 20, tech: 0.15, cost: 0.15,
                        army: (11, 0, 30, 200, 50), air: 0, navy: (0, 0, 0),
                        res: [.gas: 0.6, .aluminium: 0.3, .food: 0.2]))
        list.append(W.c("ZMB", "Zambie", .subSaharanAfrica, pop: 21.5, area: 753, gdp: 28, growth: 5.0, debt: 115,
                        revenue: 20, mil: 1.2, industry: 25, tech: 0.2, cost: 0.2,
                        army: (15, 3, 30, 100, 50), air: 5, navy: (0, 0, 0),
                        res: [.criticalMinerals: 1.0]))
        list.append(W.c("ZWE", "Zimbabwe", .subSaharanAfrica, pop: 17, area: 391, gdp: 35, growth: 4.0, debt: 60,
                        revenue: 18, mil: 1.0, industry: 20, tech: 0.2, cost: 0.2,
                        army: (30, 20, 40, 200, 100), air: 20, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.5, .food: 0.1]))
        list.append(W.c("NAM", "Namibie", .subSaharanAfrica, pop: 3.0, area: 825, gdp: 13, growth: 3.5, debt: 67,
                        revenue: 33, mil: 3.0, industry: 12, tech: 0.35, cost: 0.35,
                        army: (10, 0, 0, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.5]))
        list.append(W.c("BWA", "Botswana", .subSaharanAfrica, pop: 2.5, area: 582, gdp: 19, growth: 1.0, debt: 25,
                        revenue: 25, mil: 2.5, industry: 25, tech: 0.4, cost: 0.4,
                        army: (9, 0, 50, 100, 30), air: 10, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.3]))
        list.append(W.c("MDG", "Madagascar", .subSaharanAfrica, pop: 31, area: 587, gdp: 17, growth: 4.0, debt: 55,
                        revenue: 13, mil: 0.6, industry: 15, tech: 0.1, cost: 0.15,
                        army: (13, 20, 0, 50, 20), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.3, .food: 0.2]))
        list.append(W.c("MWI", "Malawi", .subSaharanAfrica, pop: 21.5, area: 118, gdp: 11, growth: 2.0, debt: 80,
                        revenue: 18, mil: 1.0, industry: 10, tech: 0.1, cost: 0.15,
                        army: (10, 0, 0, 50, 20), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.1]))

        // Amérique latine et Caraïbes
        list.append(W.c("CUB", "Cuba", .latinAmerica, pop: 11, area: 110, gdp: 100, growth: -1.0, debt: 60,
                        revenue: 50, mil: 3.0, industry: 12, tech: 0.3, cost: 0.2,
                        army: (50, 40, 600, 800, 700), air: 20, navy: (2, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("ECU", "Équateur", .latinAmerica, pop: 18, area: 256, gdp: 125, growth: 1.5, debt: 55,
                        revenue: 33, mil: 1.5, industry: 15, tech: 0.35, cost: 0.35,
                        army: (40, 120, 30, 300, 100), air: 10, navy: (6, 0, 2),
                        res: [.oil: 0.5, .food: 0.4]))
        list.append(W.c("BOL", "Bolivie", .latinAmerica, pop: 12.4, area: 1099, gdp: 50, growth: 1.0, debt: 95,
                        revenue: 30, mil: 1.2, industry: 15, tech: 0.25, cost: 0.25,
                        army: (34, 0, 50, 200, 100), air: 10, navy: (0, 0, 0),
                        res: [.gas: 0.3, .criticalMinerals: 0.5]))
        list.append(W.c("PRY", "Paraguay", .latinAmerica, pop: 7.0, area: 407, gdp: 45, growth: 4.0, debt: 40,
                        revenue: 22, mil: 0.8, industry: 18, tech: 0.3, cost: 0.3,
                        army: (14, 160, 10, 50, 50), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.3]))
        list.append(W.c("URY", "Uruguay", .latinAmerica, pop: 3.4, area: 176, gdp: 80, growth: 2.5, debt: 68,
                        revenue: 30, mil: 1.8, industry: 13, tech: 0.5, cost: 0.55,
                        army: (21, 0, 15, 200, 50), air: 0, navy: (3, 0, 0),
                        res: [.food: 0.3]))
        list.append(W.c("GTM", "Guatemala", .latinAmerica, pop: 18.4, area: 109, gdp: 115, growth: 3.5, debt: 27,
                        revenue: 12, mil: 0.4, industry: 18, tech: 0.25, cost: 0.3,
                        army: (18, 0, 0, 50, 20), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.2]))
        list.append(W.c("HND", "Honduras", .latinAmerica, pop: 10.8, area: 112, gdp: 37, growth: 3.5, debt: 47,
                        revenue: 24, mil: 1.5, industry: 17, tech: 0.2, cost: 0.25,
                        army: (15, 60, 0, 50, 20), air: 10, navy: (0, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("SLV", "Salvador", .latinAmerica, pop: 6.3, area: 21, gdp: 35, growth: 2.5, debt: 85,
                        revenue: 28, mil: 1.3, industry: 15, tech: 0.25, cost: 0.3,
                        army: (25, 10, 0, 50, 20), air: 0, navy: (0, 0, 0)))
        list.append(W.c("NIC", "Nicaragua", .latinAmerica, pop: 7.0, area: 130, gdp: 20, growth: 3.5, debt: 45,
                        revenue: 28, mil: 0.6, industry: 15, tech: 0.2, cost: 0.2,
                        army: (13, 0, 60, 100, 50), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("CRI", "Costa Rica", .latinAmerica, pop: 5.2, area: 51, gdp: 95, growth: 4.0, debt: 60,
                        revenue: 28, mil: 0.0, industry: 13, tech: 0.5, cost: 0.55,
                        army: (0, 0, 0, 0, 0), air: 0, navy: (0, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("PAN", "Panama", .latinAmerica, pop: 4.5, area: 75, gdp: 90, growth: 4.0, debt: 55,
                        revenue: 15, mil: 0.0, industry: 10, tech: 0.4, cost: 0.5,
                        army: (0, 0, 0, 0, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("DOM", "République dominicaine", .latinAmerica, pop: 11.4, area: 48.7, gdp: 125, growth: 4.5, debt: 60,
                        revenue: 15, mil: 0.7, industry: 20, tech: 0.35, cost: 0.3,
                        army: (56, 0, 0, 100, 30), air: 10, navy: (0, 0, 0),
                        res: [.food: 0.1]))
        list.append(W.c("HTI", "Haïti", .latinAmerica, pop: 11.8, area: 27.8, gdp: 25, growth: -3.0, debt: 25,
                        revenue: 7, mil: 0.1, industry: 10, tech: 0.05, cost: 0.1,
                        army: (1, 0, 0, 0, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("JAM", "Jamaïque", .latinAmerica, pop: 2.8, area: 11, gdp: 20, growth: 1.5, debt: 70,
                        revenue: 30, mil: 0.8, industry: 10, tech: 0.35, cost: 0.4,
                        army: (6, 1, 0, 30, 10), air: 0, navy: (0, 0, 0),
                        res: [.aluminium: 0.2]))
        list.append(W.c("GUY", "Guyana", .latinAmerica, pop: 0.83, area: 215, gdp: 25, growth: 12.0, debt: 25,
                        revenue: 25, mil: 1.0, industry: 50, tech: 0.3, cost: 0.4,
                        army: (5, 0, 0, 20, 10), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.9]))
        list.append(W.c("SUR", "Suriname", .latinAmerica, pop: 0.63, area: 164, gdp: 4, growth: 3.0, debt: 85,
                        revenue: 25, mil: 0.8, industry: 30, tech: 0.25, cost: 0.3,
                        army: (2, 0, 0, 20, 5), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.02]))

        // Océanie
        list.append(W.c("PNG", "Papouasie-Nouvelle-Guinée", .oceania, pop: 10.5, area: 463, gdp: 32, growth: 4.0, debt: 50,
                        revenue: 20, mil: 0.4, industry: 30, tech: 0.15, cost: 0.2,
                        army: (4, 0, 0, 20, 10), air: 0, navy: (0, 0, 0),
                        res: [.gas: 0.5, .criticalMinerals: 0.3]))
        list.append(W.c("FJI", "Fidji", .oceania, pop: 0.93, area: 18.3, gdp: 6, growth: 3.0, debt: 80,
                        revenue: 25, mil: 1.4, industry: 15, tech: 0.3, cost: 0.35,
                        army: (4, 6, 0, 20, 10), air: 0, navy: (0, 0, 0)))

        // Petits États ajoutés en version 0.8
        list.append(W.c("LBR", "Liberia", .subSaharanAfrica, pop: 5.6, area: 111, gdp: 4.8, growth: 4.5, debt: 55,
                        revenue: 18, mil: 0.6, industry: 15, tech: 0.15, cost: 0.15,
                        army: (8, 0, 0, 20, 10), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.1, .food: 0.05]))
        list.append(W.c("SLE", "Sierra Leone", .subSaharanAfrica, pop: 8.9, area: 72, gdp: 7.4, growth: 4.0, debt: 90,
                        revenue: 15, mil: 0.8, industry: 15, tech: 0.15, cost: 0.15,
                        army: (9, 0, 0, 30, 10), air: 0, navy: (0, 0, 0),
                        res: [.criticalMinerals: 0.1, .food: 0.05]))
        list.append(W.c("GMB", "Gambie", .subSaharanAfrica, pop: 2.8, area: 11.3, gdp: 2.6, growth: 5.0, debt: 75,
                        revenue: 18, mil: 0.7, industry: 12, tech: 0.15, cost: 0.15,
                        army: (2, 0, 0, 10, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("GNB", "Guinée-Bissau", .subSaharanAfrica, pop: 2.2, area: 36, gdp: 2.2, growth: 4.5, debt: 75,
                        revenue: 14, mil: 1.5, industry: 12, tech: 0.1, cost: 0.15,
                        army: (4.5, 0, 10, 30, 20), air: 0, navy: (0, 0, 0)))
        list.append(W.c("GNQ", "Guinée équatoriale", .subSaharanAfrica, pop: 1.9, area: 28, gdp: 12.5, growth: -2.0, debt: 40,
                        revenue: 18, mil: 1.2, industry: 50, tech: 0.25, cost: 0.3,
                        army: (2, 0, 3, 30, 10), air: 0, navy: (0, 0, 0),
                        res: [.oil: 0.15, .gas: 0.3]))
        list.append(W.c("LSO", "Lesotho", .subSaharanAfrica, pop: 2.3, area: 30, gdp: 2.3, growth: 2.0, debt: 60,
                        revenue: 45, mil: 1.7, industry: 30, tech: 0.2, cost: 0.2,
                        army: (2, 0, 0, 20, 5), air: 0, navy: (0, 0, 0)))
        list.append(W.c("SWZ", "Eswatini", .subSaharanAfrica, pop: 1.2, area: 17.4, gdp: 4.8, growth: 4.0, debt: 40,
                        revenue: 28, mil: 1.6, industry: 30, tech: 0.25, cost: 0.3,
                        army: (3, 0, 0, 10, 5), air: 0, navy: (0, 0, 0)))
        list.append(W.c("BTN", "Bhoutan", .southAsia, pop: 0.79, area: 38.4, gdp: 3.0, growth: 6.0, debt: 115,
                        revenue: 25, mil: 0.0, industry: 35, tech: 0.25, cost: 0.25,
                        army: (8, 0, 0, 0, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("BRN", "Brunei", .southeastAsia, pop: 0.46, area: 5.8, gdp: 15.5, growth: 2.0, debt: 3,
                        revenue: 25, mil: 3.0, industry: 60, tech: 0.55, cost: 0.6,
                        army: (7, 1, 0, 40, 20), air: 0, navy: (4, 0, 0),
                        res: [.oil: 0.15, .gas: 0.3]))
        list.append(W.c("TLS", "Timor oriental", .southeastAsia, pop: 1.4, area: 14.9, gdp: 2.0, growth: 3.0, debt: 15,
                        revenue: 60, mil: 1.0, industry: 15, tech: 0.1, cost: 0.2,
                        army: (2, 0, 0, 0, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("BLZ", "Belize", .latinAmerica, pop: 0.42, area: 23, gdp: 3.3, growth: 3.0, debt: 60,
                        revenue: 28, mil: 1.2, industry: 15, tech: 0.3, cost: 0.4,
                        army: (1.5, 0, 0, 0, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("TTO", "Trinité-et-Tobago", .latinAmerica, pop: 1.5, area: 5.1, gdp: 26, growth: 2.0, debt: 65,
                        revenue: 26, mil: 0.7, industry: 45, tech: 0.45, cost: 0.5,
                        army: (4, 0, 0, 10, 0), air: 0, navy: (2, 0, 0),
                        res: [.oil: 0.1, .gas: 0.9]))
        list.append(W.c("MLT", "Malte", .westernEurope, pop: 0.56, area: 0.32, gdp: 25, growth: 5.0, debt: 47,
                        revenue: 36, mil: 0.5, industry: 10, tech: 0.75, cost: 0.7,
                        army: (1.7, 0, 0, 20, 0), air: 0, navy: (0, 0, 0)))
        list.append(W.c("BHS", "Bahamas", .latinAmerica, pop: 0.41, area: 13.9, gdp: 15, growth: 2.0, debt: 80,
                        revenue: 22, mil: 0.7, industry: 10, tech: 0.45, cost: 0.6,
                        army: (1.6, 0, 0, 0, 0), air: 0, navy: (0, 0, 0)))

        return list
    }
}
