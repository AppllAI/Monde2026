import Foundation

// =============================================================
//  Battles.swift
//  La bataille, en profondeur :
//   - des généraux (nom, niveau 1 à 5, trait, expérience),
//   - des postures d'armée (défense, équilibre, assaut),
//   - la planification (une offensive préparée frappe plus fort),
//   - le ravitaillement (une armée coupée de ses bases s'effondre),
//   - des phases tactiques de 4 jours : chaque camp choisit une
//     tactique, certaines en contrent d'autres (le joueur peut
//     choisir la sienne sur la fiche de bataille),
//   - terrain, fleuves, météo, largeur de front, maîtrise du ciel.
// =============================================================

// MARK: - Généraux

enum GeneralTrait: String, Codable, CaseIterable {
    case offensive, defensive, logistician, armor, mountaineer, planner

    var name: String {
        switch self {
        case .offensive: return "Offensif"
        case .defensive: return "Défenseur tenace"
        case .logistician: return "Logisticien"
        case .armor: return "Maître des blindés"
        case .mountaineer: return "Terrain difficile"
        case .planner: return "Planificateur"
        }
    }

    var icon: String {
        switch self {
        case .offensive: return "arrow.up.forward"
        case .defensive: return "shield.fill"
        case .logistician: return "shippingbox.fill"
        case .armor: return "car.side.fill"
        case .mountaineer: return "mountain.2.fill"
        case .planner: return "map.fill"
        }
    }

    var summary: String {
        switch self {
        case .offensive: return "+10 % en attaque"
        case .defensive: return "+10 % en défense, se retranche deux fois plus vite"
        case .logistician: return "Ravitaillement plus loin, moral qui remonte vite"
        case .armor: return "Blindés et mécanisés +15 %, percées blindées"
        case .mountaineer: return "Moitié moins gêné par le terrain"
        case .planner: return "Planifie 50 % plus vite, bonus de plan plus fort"
        }
    }
}

struct General: Codable, Equatable {
    var name: String
    var skill: Int          // 1…5
    var trait: GeneralTrait
    var xp: Double

    static let staff = General(name: "État-major", skill: 1, trait: .defensive, xp: 0)

    var stars: String { String(repeating: "★", count: skill) + String(repeating: "☆", count: max(0, 5 - skill)) }
    var nextLevelXP: Double { Double(skill) * 60 }
}

enum ArmyStance: String, Codable, CaseIterable {
    case defend, balanced, assault

    var name: String {
        switch self {
        case .defend: return "Défense"
        case .balanced: return "Équilibre"
        case .assault: return "Assaut"
        }
    }

    var icon: String {
        switch self {
        case .defend: return "shield.lefthalf.filled"
        case .balanced: return "circle.lefthalf.filled"
        case .assault: return "flame.fill"
        }
    }

    var attack: Double {
        switch self {
        case .defend: return 0.75
        case .balanced: return 1
        case .assault: return 1.15
        }
    }

    var defense: Double {
        switch self {
        case .defend: return 1.15
        case .balanced: return 1
        case .assault: return 0.9
        }
    }

    var losses: Double {
        switch self {
        case .defend: return 0.85
        case .balanced: return 1
        case .assault: return 1.3
        }
    }
}

// MARK: - Tactiques

enum Tactic: String, Codable, CaseIterable, Identifiable {
    // Attaque
    case assault, barrage, armoredThrust, infiltration, droneSwarm, pincer
    // Défense
    case holdFirm, elastic, counterattack, counterBattery, jamming, ambush

    var id: String { rawValue }

    var isAttack: Bool {
        switch self {
        case .assault, .barrage, .armoredThrust, .infiltration, .droneSwarm, .pincer: return true
        default: return false
        }
    }

    var name: String {
        switch self {
        case .assault: return "Assaut frontal"
        case .barrage: return "Barrage d'artillerie"
        case .armoredThrust: return "Percée blindée"
        case .infiltration: return "Infiltration"
        case .droneSwarm: return "Essaim de drones"
        case .pincer: return "Tenaille"
        case .holdFirm: return "Défense ferme"
        case .elastic: return "Défense élastique"
        case .counterattack: return "Contre-attaque"
        case .counterBattery: return "Contre-batterie"
        case .jamming: return "Brouillage"
        case .ambush: return "Embuscade"
        }
    }

    var icon: String {
        switch self {
        case .assault: return "figure.run"
        case .barrage: return "burst.fill"
        case .armoredThrust: return "car.side.fill"
        case .infiltration: return "eye.slash.fill"
        case .droneSwarm: return "airplane"
        case .pincer: return "arrow.triangle.merge"
        case .holdFirm: return "shield.fill"
        case .elastic: return "arrow.left.and.right"
        case .counterattack: return "arrow.uturn.forward"
        case .counterBattery: return "scope"
        case .jamming: return "antenna.radiowaves.left.and.right.slash"
        case .ambush: return "tree.fill"
        }
    }

    var summary: String {
        switch self {
        case .assault: return "+10 % d'attaque, mais plus de pertes."
        case .barrage: return "+12 % d'attaque, écrase les défenses fixes."
        case .armoredThrust: return "Fort en plaine selon la part de blindés."
        case .infiltration: return "Très fort en forêt, montagne et ville."
        case .droneSwarm: return "Bonus selon vos drones ; frappe l'artillerie."
        case .pincer: return "+18 % : attaque depuis plusieurs régions."
        case .holdFirm: return "+12 % de défense, brise les assauts."
        case .elastic: return "Cède du terrain, perd moins de moral."
        case .counterattack: return "Fait perdre du moral à l'attaquant."
        case .counterBattery: return "Détruit l'artillerie ennemie."
        case .jamming: return "Annule les drones ennemis."
        case .ambush: return "+15 % en terrain difficile."
        }
    }

    /// Tactiques que celle-ci bat (l'adversaire est contré).
    var beats: [Tactic] {
        switch self {
        case .assault: return [.counterattack]
        case .barrage: return [.holdFirm, .ambush]
        case .armoredThrust: return [.counterattack]
        case .infiltration: return [.elastic]
        case .droneSwarm: return [.counterBattery, .counterattack]
        case .pincer: return [.holdFirm, .elastic]
        case .holdFirm: return [.assault]
        case .elastic: return [.armoredThrust]
        case .counterattack: return [.infiltration, .pincer]
        case .counterBattery: return [.barrage]
        case .jamming: return [.droneSwarm]
        case .ambush: return [.armoredThrust, .infiltration]
        }
    }

    /// Tactiques adverses qui battent celle-ci.
    var weakAgainst: [Tactic] { Tactic.allCases.filter { $0.beats.contains(self) } }
}

struct BattleModifier: Codable, Hashable {
    let name: String
    let value: Double        // multiplicateur (1,15 = +15 %)
}

struct Battle: Codable, Identifiable {
    var id: Int { province }
    let province: Int
    var attacker: CountryID
    var defender: CountryID
    var startDay: Int
    var phaseStart: Int
    var phase: Int
    var attackerTactic: Tactic
    var defenderTactic: Tactic
    var playerPick: Tactic?
    var attackMods: [BattleModifier]
    var defenseMods: [BattleModifier]
    var attack: Double
    var defense: Double
    var attackerOrg: Double
    var defenderOrg: Double
    var attackerDivisions: Int
    var defenderDivisions: Int
    var attackerLosses: Double     // milliers d'hommes
    var defenderLosses: Double
    var attackerGeneral: String
    var defenderGeneral: String
    var log: [String]
    var lastDay: Int
    var airStrikeUntil: Int
    var airStrikeSide: CountryID?
    var fronts: [Int] = []          // régions d'où partent les attaques (flèches sur la carte)

    /// Avancée de l'attaquant vers la prise de la région (0 → 100 %).
    var captureProgress: Double { (1 - (defenderOrg - 0.2) / 0.8).clamped(0, 1) }

    /// Part de l'avantage de l'attaquant (0…1).
    var balance: Double { attack + defense > 0 ? attack / (attack + defense) : 0.5 }
    var daysLeftInPhase: Int { max(0, 4 - (lastDay - phaseStart)) }
}

// MARK: - Noms des généraux

enum GeneralNames {
    private static let pools: [String: [String]] = [
        "fr": ["Lecointre", "Burkhard", "Schill", "Mandon", "Bellanger", "Ferrand", "Delmas", "Garnier", "Rousseau", "Lefèvre", "Marchal", "Vidal", "Tessier", "Morin", "Duval"],
        "en": ["Harrington", "Caldwell", "Brooks", "Whitaker", "Mercer", "Lawson", "Fletcher", "Grant", "Hayes", "Sullivan", "Reed", "Carter", "Morgan", "Pierce", "Walsh"],
        "ru": ["Volkov", "Sokolov", "Morozov", "Lebedev", "Kuznetsov", "Orlov", "Belov", "Zaitsev", "Smirnov", "Gromov", "Tarasov", "Kozlov", "Fedorov", "Nikitin", "Karpov"],
        "ua": ["Kovalenko", "Shevchenko", "Bondarenko", "Tkachenko", "Kravchenko", "Melnyk", "Syrskyi", "Moroz", "Lysenko", "Hnatov", "Naiev", "Polishchuk", "Savchuk", "Rudenko", "Marchenko"],
        "pl": ["Nowak", "Kowalski", "Wiśniewski", "Kamiński", "Lewandowski", "Zieliński", "Szymański", "Wójcik", "Kaczmarek", "Mazur"],
        "de": ["Breuer", "Zorn", "Hoffmann", "Krüger", "Lange", "Brandt", "Vogel", "Winter", "Keller", "Neumann", "Richter", "Hartmann"],
        "es": ["García", "Fernández", "Ramírez", "Torres", "Herrera", "Castillo", "Navarro", "Romero", "Vargas", "Mendoza", "Ortega", "Rojas", "Cabello", "Padrino"],
        "pt": ["Silva", "Santos", "Oliveira", "Pereira", "Costa", "Almeida", "Carvalho", "Ribeiro", "Moura", "Teixeira"],
        "ar": ["Al-Masri", "Haddad", "Al-Rashid", "Mansour", "Khalil", "Nasser", "Al-Hashimi", "Saleh", "Barakat", "Hamdan", "Al-Zahrani", "Farouk", "Qasim", "Darwish"],
        "fa": ["Bagheri", "Mousavi", "Salami", "Hosseini", "Rahimi", "Karimi", "Jafari", "Ahmadi", "Rezaei", "Sadeghi"],
        "tr": ["Yılmaz", "Kaya", "Demir", "Şahin", "Çelik", "Aydın", "Öztürk", "Arslan", "Doğan", "Koç"],
        "he": ["Halevi", "Zamir", "Cohen", "Levi", "Mizrahi", "Peretz", "Biton", "Friedman", "Ashkenazi", "Gantz"],
        "zh": ["Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Zhao", "Huang", "Zhou", "Wu", "Xu", "Sun", "Ma", "Hu"],
        "ja": ["Yoshida", "Tanaka", "Suzuki", "Takahashi", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato"],
        "ko": ["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim"],
        "hi": ["Sharma", "Singh", "Rawat", "Chauhan", "Pandey", "Naravane", "Dwivedi", "Mehta", "Reddy", "Nair", "Kapoor", "Joshi"],
        "ur": ["Munir", "Bajwa", "Raheel", "Qureshi", "Malik", "Hussain", "Abbasi", "Chaudhry"],
        "hy": ["Grigoryan", "Harutyunyan", "Sargsyan", "Petrosyan", "Hovhannisyan", "Avetisyan", "Mkrtchyan", "Davtyan"],
        "az": ["Aliyev", "Mammadov", "Hasanov", "Huseynov", "Valiyev", "Guliyev", "Ismayilov"],
        "ka": ["Beridze", "Kapanadze", "Gelashvili", "Lomidze", "Tsiklauri", "Maisuradze"],
        "af": ["Mensah", "Okafor", "Diallo", "Traoré", "Kamara", "Mwangi", "Ndlovu", "Abdi", "Tshabalala", "Keita", "Haftar", "Dagalo", "Burhan", "Kagame"],
        "sea": ["Nguyen", "Tran", "Pham", "Santos", "Reyes", "Prabowo", "Suharto", "Wongsuwan", "Min Aung", "Rahman", "Tan", "Lim"],
        "it": ["Rossi", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti"],
        "nl": ["de Vries", "Jansen", "Bakker", "Visser", "Smit", "Mulder", "Peeters", "Maes"],
        "nord": ["Andersson", "Johansson", "Nilsen", "Hansen", "Virtanen", "Korhonen", "Larsen", "Lindqvist"],
        "gr": ["Papadopoulos", "Georgiou", "Nikolaidis", "Konstantinou", "Dimitriou"],
        "bal": ["Petrović", "Jovanović", "Popescu", "Ionescu", "Dimitrov", "Horvat", "Novák", "Kovács", "Nagy"]
    ]

    private static let group: [CountryID: String] = [
        "FRA": "fr", "BEL": "nl", "CHE": "fr", "SEN": "af", "CIV": "af", "MLI": "af", "BFA": "af", "NER": "af", "TCD": "af",
        "USA": "en", "GBR": "en", "CAN": "en", "AUS": "en", "NZL": "en", "IRL": "en",
        "RUS": "ru", "BLR": "ru", "KAZ": "ru", "UKR": "ua", "POL": "pl", "CZE": "bal", "SVK": "bal", "HUN": "bal", "ROU": "bal",
        "BGR": "bal", "SRB": "bal", "HRV": "bal", "BIH": "bal", "MDA": "bal",
        "DEU": "de", "AUT": "de", "ITA": "it", "NLD": "nl", "SWE": "nord", "NOR": "nord", "FIN": "nord", "DNK": "nord",
        "GRC": "gr", "CYP": "gr", "ESP": "es", "MEX": "es", "ARG": "es", "COL": "es", "VEN": "es", "CHL": "es", "PER": "es",
        "CUB": "es", "BOL": "es", "ECU": "es", "PRT": "pt", "BRA": "pt", "AGO": "pt", "MOZ": "pt",
        "SAU": "ar", "EGY": "ar", "SYR": "ar", "IRQ": "ar", "JOR": "ar", "ARE": "ar", "QAT": "ar", "KWT": "ar", "YEM": "ar",
        "LBN": "ar", "LBY": "ar", "DZA": "ar", "MAR": "ar", "TUN": "ar", "OMN": "ar", "SDN": "ar", "PSE": "ar",
        "IRN": "fa", "AFG": "fa", "TUR": "tr", "ISR": "he", "CHN": "zh", "TWN": "zh", "JPN": "ja", "KOR": "ko", "PRK": "ko",
        "IND": "hi", "PAK": "ur", "BGD": "sea", "ARM": "hy", "AZE": "az", "GEO": "ka",
        "VNM": "sea", "PHL": "sea", "IDN": "sea", "THA": "sea", "MMR": "sea", "MYS": "sea", "SGP": "sea",
        "NGA": "af", "ETH": "af", "KEN": "af", "ZAF": "af", "COD": "af", "RWA": "af", "SOM": "af", "SSD": "af", "GHA": "af"
    ]

    static func pick(for id: CountryID, rng: inout SeededRandom) -> String {
        let key: String
        if let g = group[id] {
            key = g
        } else {
            let info = Geo.info(id)
            if info.lon < -30 { key = info.lat > 15 ? "en" : "es" }
            else if info.lat < 15 && info.lon < 50 { key = "af" }
            else if info.lon > 90 { key = "sea" }
            else if info.lon > 45 { key = "ru" }
            else { key = "bal" }
        }
        let pool = pools[key] ?? pools["en"] ?? ["Martin"]
        return pool[Int.random(in: 0..<pool.count, using: &rng)]
    }
}

// MARK: - Moteur de bataille

extension Simulation {

    mutating func makeGeneral(for id: CountryID, divisions: [DivisionType: Int]) -> General {
        let c = state.countries[id]
        let quality = ((c?.tech ?? 0.5) + (c?.readiness ?? 0.5)) / 2
        var skill = 1
        let roll = Double.random(in: 0...1, using: &state.rng) + quality * 0.5
        if roll > 1.35 { skill = 4 } else if roll > 1.05 { skill = 3 } else if roll > 0.65 { skill = 2 }
        let total = Double(max(1, divisions.values.reduce(0, +)))
        let armorShare = Double((divisions[.armored] ?? 0) + (divisions[.mechanized] ?? 0)) / total
        var weights: [(GeneralTrait, Double)] = [
            (.offensive, 1), (.defensive, 1), (.logistician, 0.8), (.armor, 0.4 + armorShare * 2),
            (.mountaineer, 0.6), (.planner, 0.9)
        ]
        if c?.posture == .defensive { weights[1].1 += 1 }
        if c?.posture == .offensive { weights[0].1 += 1 }
        let sum = weights.reduce(0) { $0 + $1.1 }
        var x = Double.random(in: 0..<sum, using: &state.rng)
        var trait = GeneralTrait.offensive
        for (t, w) in weights {
            if x < w { trait = t; break }
            x -= w
        }
        var name = GeneralNames.pick(for: id, rng: &state.rng)
        // Évite deux généraux du même nom dans un pays.
        let used = Set(state.armies.filter { $0.owner == id }.map { $0.general.name })
        if used.contains("Gén. " + name) {
            name += " " + ["II", "Jr", "fils", "aîné"][Int.random(in: 0..<4, using: &state.rng)]
        }
        return General(name: "Gén. " + name, skill: skill, trait: trait, xp: 0)
    }

    // MARK: Ravitaillement

    /// 1 = bien ravitaillée ; 0,6 = par la mer ; 0,15 = encerclée.
    func supplyLevel(owner: CountryID, at province: Int, logistician: Bool = false) -> Double {
        guard let c = state.countries[owner] else { return 1 }
        let range = (6 + 6 * c.infrastructure) * (logistician ? 1.4 : 1)
        var depth: [Int: Int] = [province: 0]
        var queue = [province]
        var head = 0
        var touchesSea = ProvinceMap.all[province].coastal
        var friendlyCache: [CountryID: Bool] = [:]
        func friendly(_ x: CountryID) -> Bool {
            if let v = friendlyCache[x] { return v }
            let v = isFriendly(owner, x)
            friendlyCache[x] = v
            return v
        }
        while head < queue.count && queue.count < 700 {
            let cur = queue[head]
            head += 1
            let d = depth[cur] ?? 0
            let holder = controller(of: cur)
            let p = ProvinceMap.all[cur]
            // Une région « chez soi » (ou chez un allié) ravitaille.
            if holder == owner && state.bases.contains(cur) { return Double(d) <= range / 2 ? 1 : max(0.5, 1 - (Double(d) - range / 2) * 0.08) }
            if holder == p.country && (holder == owner || friendly(holder)) && state.countries[holder] != nil {
                let half = range / 2
                let base = holder == owner ? 1.0 : 0.9
                return Double(d) <= half ? base : max(0.35, base - (Double(d) - half) * 0.1)
            }
            if p.coastal { touchesSea = true }
            guard Double(d) < range else { continue }
            for n in p.neighbors where depth[n] == nil {
                let h = controller(of: n)
                guard h == owner || friendly(h) else { continue }
                // Le désert allonge les lignes.
                depth[n] = d + (TerrainMap.terrain(n) == .desert ? 2 : 1)
                queue.append(n)
            }
        }
        if touchesSea && c.navalPower > 0 {
            let foes = enemies(of: owner)
            let share = foes.isEmpty ? 1 : foes.map { navalShare(owner, vs: $0) }.min() ?? 1
            if share >= 0.4 { return 0.6 }
        }
        return 0.15
    }

    mutating func updateSupply() {
        var cache: [String: Double] = [:]
        var warCache: [CountryID: Bool] = [:]
        for i in state.armies.indices {
            let a = state.armies[i]
            let atWar = warCache[a.side] ?? isAtWar(a.side)
            warCache[a.side] = atWar
            guard atWar else {
                state.armies[i].supply = 1
                continue
            }
            let key = "\(a.side)-\(a.province)-\(a.general.trait == .logistician)"
            if let v = cache[key] {
                state.armies[i].supply = v
                continue
            }
            let v = supplyLevel(owner: a.side, at: a.province, logistician: a.general.trait == .logistician)
            cache[key] = v
            if a.owner == state.playerID && v <= 0.15 && a.supply > 0.15 {
                addEvent("⛓️ \(a.name) est encerclée à \(ProvinceMap.all[a.province].name) : plus de ravitaillement !", important: true)
            }
            state.armies[i].supply = v
        }
    }

    // MARK: Tactiques disponibles

    func availableTactics(attacking: Bool, armies: [Army], owner: CountryID, province: Int, fronts: Int) -> [Tactic] {
        let terrain = TerrainMap.terrain(province)
        let total = Double(max(1, armies.reduce(0) { $0 + $1.count }))
        func share(_ types: [DivisionType]) -> Double {
            Double(armies.reduce(0) { sum, a in sum + types.reduce(0) { $0 + (a.divisions[$1] ?? 0) } }) / total
        }
        let c = state.countries[owner]
        var list: [Tactic]
        if attacking {
            list = [.assault, .barrage]
            if share([.armored, .mechanized]) >= 0.25 || armies.contains(where: { $0.general.trait == .armor }) {
                list.append(.armoredThrust)
            }
            if share([.infantry, .airborne, .marines]) >= 0.5 { list.append(.infiltration) }
            if (c?.stock(.drone) ?? 0) > 50 { list.append(.droneSwarm) }
            if fronts >= 2 { list.append(.pincer) }
        } else {
            list = [.holdFirm, .elastic]
            if !armies.isEmpty {
                list.append(.counterBattery)
                if armies.contains(where: { $0.organization > 0.5 }) { list.append(.counterattack) }
            }
            if let c = c, c.tech >= 0.6 || c.has(.electronicWarfare) { list.append(.jamming) }
            if terrain.rough { list.append(.ambush) }
        }
        return list
    }

    /// Le général choisit : selon son trait, et avec du talent il anticipe l'adversaire.
    mutating func chooseTactic(options: [Tactic], general: General, opponentLast: Tactic?, province: Int) -> Tactic {
        guard !options.isEmpty else { return .holdFirm }
        let terrain = TerrainMap.terrain(province)
        if let last = opponentLast, Double.random(in: 0...1, using: &state.rng) < 0.08 + 0.1 * Double(general.skill) {
            if let counter = options.first(where: { $0.beats.contains(last) }) { return counter }
        }
        var weights: [Double] = options.map { t in
            var w = 1.0
            switch (t, general.trait) {
            case (.armoredThrust, .armor), (.assault, .offensive), (.pincer, .offensive),
                 (.holdFirm, .defensive), (.elastic, .defensive), (.barrage, .planner), (.infiltration, .mountaineer),
                 (.ambush, .mountaineer):
                w += 2
            default: break
            }
            if t == .armoredThrust { w *= terrain.armor }
            if t == .infiltration || t == .ambush { w *= terrain.rough ? 1.8 : 0.5 }
            if t == .pincer { w += 1 }
            return w
        }
        if weights.isEmpty { weights = [1] }
        let sum = weights.reduce(0, +)
        var x = Double.random(in: 0..<sum, using: &state.rng)
        for (i, w) in weights.enumerated() {
            if x < w { return options[i] }
            x -= w
        }
        return options[0]
    }

    /// Effet d'une tactique sur son propre camp (avant les contres).
    func tacticValue(_ t: Tactic, armies: [Army], owner: CountryID, province: Int) -> Double {
        let terrain = TerrainMap.terrain(province)
        let total = Double(max(1, armies.reduce(0) { $0 + $1.count }))
        let armorShare = Double(armies.reduce(0) { $0 + ($1.divisions[.armored] ?? 0) + ($1.divisions[.mechanized] ?? 0) }) / total
        switch t {
        case .assault: return 1.10
        case .barrage: return 1.12
        case .armoredThrust: return 1 + armorShare * 0.45 * terrain.armor - (terrain.rough ? 0.1 : 0)
        case .infiltration: return terrain.rough ? 1.18 : 1.04
        case .droneSwarm:
            let drones = state.countries[owner]?.stock(.drone) ?? 0
            return 1 + min(0.2, drones.squareRoot() / 400)
        case .pincer: return 1.18
        case .holdFirm: return 1.12
        case .elastic: return 0.97
        case .counterattack: return 1.03
        case .counterBattery: return 1.05
        case .jamming: return 1.0
        case .ambush: return terrain.rough ? 1.15 : 1.0
        }
    }

    // MARK: Résolution d'une journée de bataille

    mutating func fightProvinceBattle(target: Int, attackerIndices: [Int],
                                      frontierCache: inout [CountryID: (Set<Int>, Int)]) {
        let defenderCountry = controller(of: target)
        let attackersAll = attackerIndices.filter { state.armies.indices.contains($0) }
        guard !attackersAll.isEmpty, state.countries[defenderCountry] != nil else { return }
        let defenderFoes = enemies(of: defenderCountry)
        let attackers = attackersAll.filter { defenderFoes.contains(state.armies[$0].side) }
        guard !attackers.isEmpty else { return }
        let defenders = state.armies.indices.filter { j in
            state.armies[j].province == target && isFriendly(defenderCountry, state.armies[j].side) && !attackers.contains(j)
        }
        let leadOwner = attackers.max { state.armies[$0].count < state.armies[$1].count }.map { state.armies[$0].side } ?? state.armies[attackers[0]].side
        let attArmies = attackers.map { state.armies[$0] }
        let defArmies = defenders.map { state.armies[$0] }
        let terrain = TerrainMap.terrain(target)
        let weather = self.weather(at: target)
        let fronts = Set(attArmies.map { $0.province }).count
        let today = state.day

        // Bataille en cours ou nouvelle
        let attLead = attArmies.max { $0.count < $1.count }?.general ?? .staff
        let defLead = defArmies.max { $0.count < $1.count }?.general ?? .staff
        var battle = state.battles[target] ?? Battle(
            province: target, attacker: leadOwner, defender: defenderCountry, startDay: today, phaseStart: today - 4,
            phase: 0, attackerTactic: .assault, defenderTactic: .holdFirm, playerPick: nil,
            attackMods: [], defenseMods: [], attack: 0, defense: 0, attackerOrg: 1, defenderOrg: 1,
            attackerDivisions: 0, defenderDivisions: 0, attackerLosses: 0, defenderLosses: 0,
            attackerGeneral: attLead.name, defenderGeneral: defLead.name, log: [], lastDay: today,
            airStrikeUntil: -100, airStrikeSide: nil)
        if battle.defender != defenderCountry || battle.attacker != leadOwner {
            battle.defender = defenderCountry
            battle.attacker = leadOwner
        }
        battle.attackerGeneral = attLead.name
        battle.defenderGeneral = defArmies.isEmpty ? "Garnison" : defLead.name
        battle.lastDay = today
        battle.fronts = Array(Set(attArmies.map { $0.province })).sorted()
        if battle.startDay == today, let p = state.playerID {
            let place = ProvinceMap.all[target].name
            if defenderCountry == p {
                addEvent("⚔️ \(name(leadOwner)) attaque \(place) avec \(Int(attArmies.reduce(0) { $0 + $1.count })) divisions.", important: true)
            } else if attArmies.contains(where: { $0.owner == p }) {
                addEvent("⚔️ Nos troupes passent à l'attaque sur \(place).", important: false)
            }
        }

        // Nouvelle phase tactique tous les 4 jours
        if today - battle.phaseStart >= 4 {
            let player = state.playerID
            let attOptions = availableTactics(attacking: true, armies: attArmies, owner: leadOwner, province: target, fronts: fronts)
            let defOptions = availableTactics(attacking: false, armies: defArmies, owner: defenderCountry, province: target, fronts: fronts)
            let prevAtt = battle.phase > 0 ? battle.attackerTactic : nil
            let prevDef = battle.phase > 0 ? battle.defenderTactic : nil
            var att = chooseTactic(options: attOptions, general: attLead, opponentLast: prevDef, province: target)
            var def = chooseTactic(options: defOptions, general: defArmies.isEmpty ? .staff : defLead, opponentLast: prevAtt, province: target)
            if let pick = battle.playerPick {
                if leadOwner == player && attOptions.contains(pick) { att = pick }
                if defenderCountry == player && defOptions.contains(pick) { def = pick }
            }
            battle.playerPick = nil
            battle.attackerTactic = att
            battle.defenderTactic = def
            battle.phase += 1
            battle.phaseStart = today
            var line = "Phase \(battle.phase) : \(att.name) contre \(def.name)"
            if att.beats.contains(def) { line += " — l'attaquant prend l'avantage" }
            if def.beats.contains(att) { line += " — la défense contre l'attaque" }
            battle.log.append(line)
            if battle.log.count > 8 { battle.log.removeFirst(battle.log.count - 8) }
        }
        let attTactic = battle.attackerTactic, defTactic = battle.defenderTactic

        // ---------- Attaque
        var attMods: [BattleModifier] = []
        func addA(_ name: String, _ v: Double) { if abs(v - 1) > 0.005 { attMods.append(BattleModifier(name: name, value: v)) } }
        let attTotal = Double(max(1, attArmies.reduce(0) { $0 + $1.count }))
        let armorShare = Double(attArmies.reduce(0) { $0 + ($1.divisions[.armored] ?? 0) + ($1.divisions[.mechanized] ?? 0) }) / attTotal
        let marineShare = Double(attArmies.reduce(0) { $0 + ($1.divisions[.marines] ?? 0) }) / attTotal
        let defHardness = defArmies.isEmpty ? 0.1 : defArmies.reduce(0.0) { $0 + $1.hardness } / Double(defArmies.count)
        let attHardness = attArmies.reduce(0.0) { $0 + $1.hardness } / Double(attArmies.count)

        var attack = 0.0
        var amphibiousWeight = 0.0, riverWeight = 0.0, supplySum = 0.0, generalSum = 0.0, stanceSum = 0.0
        var terrainSum = 0.0
        for a in attArmies {
            let v = armyAttack(a, vsHardness: defHardness)
            attack += v
            if a.amphibious || a.airdrop { amphibiousWeight += v }
            if TerrainMap.river(a.province, target) && !a.amphibious { riverWeight += v }
            supplySum += v * (0.45 + 0.55 * a.supply)
            var g = 1 + 0.025 * Double(a.general.skill)
            if a.general.trait == .offensive { g += 0.1 }
            if a.general.trait == .armor { g += 0.15 * armorShare }
            generalSum += v * g
            stanceSum += v * a.stance.attack
            var t = terrain.attack * (1 + armorShare * (terrain.armor - 1))
            if a.general.trait == .mountaineer { t = 1 - (1 - t) * 0.5 }
            terrainSum += v * t
        }
        let base = max(attack, 0.001)
        addA("Terrain : \(terrain.name.lowercased())", terrainSum / base)
        if riverWeight > 0 { addA("Traversée de fleuve", 1 - (0.3 - 0.15 * marineShare) * riverWeight / base) }
        if amphibiousWeight > 0 { addA("Débarquement", 1 - (0.4 - 0.25 * marineShare) * amphibiousWeight / base) }
        addA("Météo : \(weather.name.lowercased())", weather.attack * (1 + armorShare * (weather.armor - 1)))
        addA("Ravitaillement", supplySum / base)
        addA("Généraux", generalSum / base)
        addA("Posture", stanceSum / base)
        if fronts >= 2 { addA("Attaque de \(fronts) côtés", min(1.25, 1 + 0.08 * Double(fronts - 1))) }
        let air = airSuperiority(leadOwner, defenderCountry)
        addA("Maîtrise du ciel", 1 + 0.2 * (air - 0.5))
        if battle.airStrikeSide == leadOwner && today <= battle.airStrikeUntil { addA("Frappes aériennes", 1.15) }
        var attTac = tacticValue(attTactic, armies: attArmies, owner: leadOwner, province: target)
        if defTactic == .jamming && attTactic == .droneSwarm { attTac = 1 }
        addA("Tactique : \(attTactic.name.lowercased())", attTac)
        if attTactic.beats.contains(defTactic) { addA("Tactique gagnante", 1.15) }
        if defTactic.beats.contains(attTactic) { addA("Tactique contrée", 0.8) }
        for m in attMods { attack *= m.value }

        // ---------- Défense
        var defMods: [BattleModifier] = []
        func addD(_ name: String, _ v: Double) { if abs(v - 1) > 0.005 { defMods.append(BattleModifier(name: name, value: v)) } }
        if frontierCache[defenderCountry] == nil {
            let front = frontierProvinces(defenderCountry, enemies: defenderFoes)
            frontierCache[defenderCountry] = (front, provincesControlled(by: defenderCountry).count)
        }
        let (front, controlledCount) = frontierCache[defenderCountry] ?? ([], 1)
        let garrisonOrg = state.provinceOrg[target] ?? 1
        let garrison = garrisonDefense(defenderCountry, at: target, frontier: front, controlledCount: controlledCount)
            * (0.3 + 0.7 * garrisonOrg)
        var armyDef = 0.0
        var dSupply = 0.0, dGeneral = 0.0, dStance = 0.0
        for d in defArmies {
            let v = armyDefense(d, vsHardness: attHardness)
            armyDef += v
            dSupply += v * (0.45 + 0.55 * d.supply)
            var g = 1 + 0.025 * Double(d.general.skill)
            if d.general.trait == .defensive { g += 0.1 }
            dGeneral += v * g
            dStance += v * d.stance.defense
        }
        let defDivisions = defArmies.reduce(0) { $0 + $1.count }
        var armyFactor = 1.0
        if armyDef > 0 {
            armyFactor *= dSupply / armyDef * (dGeneral / armyDef) * (dStance / armyDef)
        }
        var defense = armyDef * armyFactor + garrison
        if armyDef > 0 {
            let share = armyDef / max(defense, 0.001)
            addD("Armées : ravitaillement, généraux, posture", 1 + (armyFactor - 1) * share)
        }
        if ProvinceMap.all[target].country == defenderCountry { addD("Défendre sa terre", 1.25) }
        if terrain == .urban { addD("Ville", 1.15) }
        let fort = fortLevel(target)
        if fort > 0 { addD("Fort niveau \(fort)", 1 + 0.15 * Double(fort)) }
        addD("Maîtrise du ciel", 1 - 0.2 * (air - 0.5))
        if state.bombardments[target] != nil { addD("Sous les bombes", 0.85) }
        if battle.airStrikeSide == defenderCountry && today <= battle.airStrikeUntil { addD("Frappes aériennes", 1.15) }
        addD("Tactique : \(defTactic.name.lowercased())", tacticValue(defTactic, armies: defArmies, owner: defenderCountry, province: target))
        // `defense` contient déjà les facteurs des armées ; on applique le reste.
        for m in defMods where !m.name.hasPrefix("Armées") { defense *= m.value }
        let noise = Double.random(in: 0.9...1.1, using: &state.rng)
        attack *= noise

        // ---------- Moral et pertes
        let total = max(attack + defense, 0.001)
        let onAttackers = defense / total
        let onDefenders = attack / total
        var attOrgLoss = 0.09 * onAttackers
        var defOrgLoss = 0.09 * onDefenders
        if defTactic == .counterattack { attOrgLoss *= 1.25 }
        if defTactic == .elastic { defOrgLoss *= 0.7 }
        if attTactic == .assault { attOrgLoss *= 1.1 }
        var attackerMen = 0.0, defenderMen = 0.0
        for i in attackers {
            let a = state.armies[i]
            var loss = attOrgLoss * (a.stance == .assault ? 1.1 : 1)
            if a.general.trait == .offensive { loss *= 0.95 }
            state.armies[i].organization = max(0, a.organization - loss)
            state.armies[i].experience = min(1, a.experience + 0.002)
            let intensity = 0.004 * onAttackers * a.stance.losses * (attTactic == .assault ? 1.2 : 1)
            applyArmyLosses(i, intensity: intensity)
            attackerMen += intensity * Double(a.count) * 6
            state.armies[i].general.xp += 1
        }
        for j in defenders {
            let d = state.armies[j]
            state.armies[j].organization = max(0, d.organization - defOrgLoss)
            state.armies[j].daysInPlace += 1
            let intensity = 0.004 * onDefenders * d.stance.losses
            applyArmyLosses(j, intensity: intensity)
            defenderMen += intensity * Double(d.count) * 6
            state.armies[j].general.xp += 1
            state.armies[j].experience = min(1, d.experience + 0.002)
        }
        state.provinceOrg[target] = max(0, garrisonOrg - defOrgLoss)
        if var d = state.countries[defenderCountry], defenders.isEmpty {
            let share = 1.0 / Double(max(1, controlledCount))
            let f = 0.003 * onDefenders * d.posture.losses
            d.applyLandLosses(fraction: f, share: share)
            defenderMen += f * Double(d.divisionCount) * 6 * share
            state.countries[defenderCountry] = d
        }

        // ---------- Issue
        let defenderOrg: Double
        if defense <= 0.0001 {
            defenderOrg = 0
        } else {
            let armyOrg = defenders.isEmpty ? 0 : defenders.reduce(0.0) { $0 + state.armies[$1].organization } / Double(defenders.count)
            let orgNow = state.provinceOrg[target] ?? 0
            defenderOrg = defenders.isEmpty ? orgNow : (armyOrg * armyDef + orgNow * garrison) / max(armyDef + garrison, 0.001)
        }
        let attackerOrg = attackers.reduce(0.0) { $0 + state.armies[$1].organization } / Double(attackers.count)

        battle.attackMods = attMods
        battle.defenseMods = defMods
        battle.attack = attack
        battle.defense = defense
        battle.attackerOrg = attackerOrg
        battle.defenderOrg = defenderOrg
        battle.attackerDivisions = Int(attTotal)
        battle.defenderDivisions = defDivisions
        battle.attackerLosses += attackerMen
        battle.defenderLosses += defenderMen
        state.battles[target] = battle

        if defenderOrg < 0.2 {
            let involved = Set(attArmies.map { $0.owner } + [defenderCountry])
            for i in attackers { state.armies[i].general.xp += 4 }
            captureProvince(target, by: attackers, defenders: defenders, from: defenderCountry)
            state.battles[target] = nil
            if let p = state.playerID, involved.contains(p) || attArmies.contains(where: { isFriendly(p, $0.owner) }) {
                let days = today - battle.startDay + 1
                addEvent("⚔️ Bataille de \(ProvinceMap.all[target].name) (\(days) j) : victoire de \(name(leadOwner)). Pertes : \(Int(battle.attackerLosses)) k contre \(Int(battle.defenderLosses)) k.",
                         important: false)
            }
        } else if attackerOrg < 0.25 {
            for i in attackers {
                state.armies[i].path = []
                state.armies[i].engaged = false
                state.armies[i].amphibious = false
            }
            for j in defenders { state.armies[j].general.xp += 4 }
            state.battles[target] = nil
            if attackers.contains(where: { state.armies[$0].owner == state.playerID }) {
                // Pourquoi on a perdu : ce qui a le plus aidé la défense ou gêné l'attaque.
                let why = (defMods.filter { $0.value > 1.05 }.map { ($0.name, $0.value - 1) }
                         + attMods.filter { $0.value < 0.95 }.map { ($0.name, 1 - $0.value) })
                    .sorted { $0.1 > $1.1 }.prefix(3).map { $0.0.lowercased() }
                let hint = why.isEmpty ? "" : " En cause : " + why.joined(separator: ", ") + "."
                addEvent("🛡️ Notre offensive sur \(ProvinceMap.all[target].name) est repoussée.\(hint) Essayez la tenaille, un bombardement ou plus de divisions.", important: true)
            } else if defenderCountry == state.playerID {
                addEvent("🛡️ Nous tenons \(ProvinceMap.all[target].name) : l'assaut de \(name(leadOwner)) est brisé.", important: false)
            }
        }
    }

    /// Fin de journée : batailles sans combat aujourd'hui = terminées ; généraux qui progressent.
    mutating func closeBattlesAndPromote() {
        let today = state.day
        for (p, b) in state.battles where b.lastDay < today {
            state.battles[p] = nil
        }
        for i in state.armies.indices {
            var g = state.armies[i].general
            guard g.skill < 5, g.xp >= g.nextLevelXP else { continue }
            g.xp -= g.nextLevelXP
            g.skill += 1
            state.armies[i].general = g
            if state.armies[i].owner == state.playerID {
                addEvent("⭐ \(g.name) (\(state.armies[i].name)) passe au niveau \(g.skill).", important: false)
            }
        }
    }

    // MARK: Ordres du joueur sur une bataille

    mutating func pickTactic(_ tactic: Tactic, at province: Int) -> ActionResult {
        guard var b = state.battles[province] else { return ActionResult(success: false, message: "La bataille est terminée.") }
        b.playerPick = tactic
        state.battles[province] = b
        return ActionResult(success: true, message: "\(tactic.name) : appliquée à la prochaine phase (dans \(b.daysLeftInPhase) j).")
    }

    mutating func callAirStrike(at province: Int) -> ActionResult {
        guard var b = state.battles[province], let p = state.playerID, var c = state.countries[p] else {
            return ActionResult(success: false, message: "La bataille est terminée.")
        }
        guard b.attacker == p || b.defender == p else { return ActionResult(success: false, message: "Vous ne participez pas à cette bataille.") }
        guard state.day > b.airStrikeUntil + 10 else {
            return ActionResult(success: false, message: "Les escadrilles se réarment (encore \(b.airStrikeUntil + 10 - state.day + 1) j).")
        }
        let drones = c.stock(.drone), missiles = c.stock(.missile)
        if drones >= 40 {
            c.equipment[.drone] = drones - max(20, drones * 0.04)
        } else if missiles >= 10 {
            c.equipment[.missile] = missiles - max(5, missiles * 0.03)
        } else {
            return ActionResult(success: false, message: "Pas assez de drones ni de missiles. Produisez-en.")
        }
        state.countries[p] = c
        b.airStrikeUntil = state.day + 5
        b.airStrikeSide = p
        b.log.append("Frappes aériennes demandées : +15 % pendant 5 jours")
        state.battles[province] = b
        return ActionResult(success: true, message: "Frappes aériennes sur \(ProvinceMap.all[province].name) : +15 % pendant 5 jours.")
    }

    /// Envoie dans la bataille les armées du joueur voisines et disponibles.
    mutating func reinforceBattle(at province: Int) -> ActionResult {
        guard let p = state.playerID, let b = state.battles[province] else {
            return ActionResult(success: false, message: "La bataille est terminée.")
        }
        let attacking = b.attacker == p || (b.defender != p && enemies(of: b.defender).contains(p))
        var sent = 0
        for i in state.armies.indices where state.armies[i].owner == p && state.armies[i].province != province {
            let a = state.armies[i]
            guard a.path.isEmpty || a.path.first == province, a.organization > 0.4,
                  ProvinceMap.all[a.province].neighbors.contains(province) else { continue }
            if attacking && a.path.first == province { continue }
            state.armies[i].path = [province]
            state.armies[i].progress = 0
            sent += 1
        }
        return sent > 0 ? ActionResult(success: true, message: "\(sent) armée(s) envoyée(s) en renfort.")
                        : ActionResult(success: false, message: "Aucune armée disponible dans les régions voisines.")
    }

    /// Fin de l'attaque, ou repli des défenseurs vers l'arrière.
    mutating func retreatFromBattle(at province: Int) -> ActionResult {
        guard let p = state.playerID else { return ActionResult(success: false, message: "") }
        var count = 0
        for i in state.armies.indices where state.armies[i].owner == p {
            let a = state.armies[i]
            if a.path.first == province && a.engaged {
                state.armies[i].path = []
                state.armies[i].engaged = false
                count += 1
            } else if a.province == province {
                let back = ProvinceMap.all[province].neighbors.filter { n in
                    let c = controller(of: n)
                    return (c == p || isFriendly(p, c)) && !state.battles.keys.contains(n)
                }.max { supplyLevel(owner: p, at: $0) < supplyLevel(owner: p, at: $1) }
                if let back = back {
                    state.armies[i].province = back
                    state.armies[i].path = []
                    state.armies[i].organization = max(0, a.organization - 0.1)
                    state.armies[i].daysInPlace = 0
                    count += 1
                }
            }
        }
        return count > 0 ? ActionResult(success: true, message: "Repli ordonné (\(count) armée(s)).")
                         : ActionResult(success: false, message: "Aucune armée ne peut se replier.")
    }

    mutating func setStance(_ stance: ArmyStance, for armyIDs: [Int]) {
        for i in state.armies.indices where armyIDs.contains(state.armies[i].id) {
            state.armies[i].stance = stance
        }
    }

    /// Batailles qui concernent le joueur (ou ses alliés), les plus importantes d'abord.
    func playerBattles() -> [Battle] {
        guard let p = state.playerID else { return [] }
        return state.battles.values.filter { b in
            b.attacker == p || b.defender == p || isFriendly(p, b.attacker) || isFriendly(p, b.defender)
        }.sorted { $0.attackerDivisions + $0.defenderDivisions > $1.attackerDivisions + $1.defenderDivisions }
    }

    func playerSide(in b: Battle) -> Int {
        guard let p = state.playerID else { return 0 }
        // Nos corps expéditionnaires comptent aussi.
        if state.armies.contains(where: { $0.owner == p && $0.servingFor != nil && $0.engaged && $0.path.first == b.province }) { return 1 }
        if state.armies.contains(where: { $0.owner == p && $0.servingFor != nil && $0.province == b.province }) { return -1 }
        if b.attacker == p || isFriendly(p, b.attacker) { return 1 }
        if b.defender == p || isFriendly(p, b.defender) { return -1 }
        return 0
    }
}
