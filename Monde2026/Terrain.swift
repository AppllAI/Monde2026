import Foundation

// =============================================================
//  Terrain.swift
//  Le terrain de chaque région (relief réel tiré de Natural
//  Earth), les grands fleuves entre régions, et la météo
//  (hiver, raspoutitsa, mousson) qui pèsent sur les combats.
// =============================================================

enum Terrain: Int, Codable, CaseIterable {
    case plains, forest, hills, mountains, desert, jungle, urban, tundra

    var name: String {
        switch self {
        case .plains: return "Plaine"
        case .forest: return "Forêt"
        case .hills: return "Collines"
        case .mountains: return "Montagne"
        case .desert: return "Désert"
        case .jungle: return "Jungle et marais"
        case .urban: return "Zone urbaine"
        case .tundra: return "Toundra"
        }
    }

    var icon: String {
        switch self {
        case .plains: return "leaf"
        case .forest: return "tree.fill"
        case .hills: return "mountain.2"
        case .mountains: return "mountain.2.fill"
        case .desert: return "sun.max.fill"
        case .jungle: return "drop.fill"
        case .urban: return "building.2.fill"
        case .tundra: return "snowflake"
        }
    }

    /// Ce que le terrain enlève à l'attaquant.
    var attack: Double {
        switch self {
        case .plains: return 1.0
        case .forest: return 0.85
        case .hills: return 0.8
        case .mountains: return 0.6
        case .desert: return 0.95
        case .jungle: return 0.7
        case .urban: return 0.7
        case .tundra: return 0.85
        }
    }

    /// Efficacité des blindés et de la mécanisée.
    var armor: Double {
        switch self {
        case .plains: return 1.15
        case .desert: return 1.1
        case .tundra: return 0.9
        case .hills: return 0.85
        case .forest: return 0.7
        case .urban: return 0.6
        case .mountains, .jungle: return 0.5
        }
    }

    /// Largeur de front (combien de divisions peuvent s'engager).
    var width: Double {
        switch self {
        case .plains, .desert: return 1.1
        case .tundra: return 0.9
        case .forest, .hills: return 0.85
        case .urban: return 0.75
        case .jungle: return 0.7
        case .mountains: return 0.6
        }
    }

    var movement: Double {
        switch self {
        case .plains: return 1.0
        case .desert: return 0.9
        case .hills, .urban: return 0.8
        case .forest, .tundra: return 0.75
        case .mountains: return 0.55
        case .jungle: return 0.5
        }
    }

    /// Terrain où l'on peut tendre des embuscades et s'infiltrer.
    var rough: Bool {
        switch self {
        case .forest, .hills, .mountains, .jungle, .urban: return true
        default: return false
        }
    }

    /// Couleur du mode de carte « Terrain ».
    var rgb: (Double, Double, Double) {
        switch self {
        case .plains: return (0.55, 0.66, 0.38)
        case .forest: return (0.20, 0.42, 0.26)
        case .hills: return (0.62, 0.55, 0.36)
        case .mountains: return (0.50, 0.42, 0.36)
        case .desert: return (0.86, 0.74, 0.48)
        case .jungle: return (0.12, 0.38, 0.30)
        case .urban: return (0.62, 0.60, 0.62)
        case .tundra: return (0.72, 0.78, 0.80)
        }
    }
}

enum TerrainMap {
    private struct File: Decodable {
        let regions: Int
        let terrain: [Int]
        let rivers: [[Int]]
        let cities: [String: String]?
    }

    private static let data: (terrain: [Terrain], rivers: Set<Int>, cities: [Int: String], real: Bool) = load()

    static var hasRealData: Bool { data.real }

    static func terrain(_ province: Int) -> Terrain {
        data.terrain.indices.contains(province) ? data.terrain[province] : .plains
    }

    /// Un grand fleuve sépare-t-il ces deux régions voisines ?
    static func river(_ a: Int, _ b: Int) -> Bool {
        data.rivers.contains(key(a, b))
    }

    static func city(_ province: Int) -> String? { data.cities[province] }

    private static func key(_ a: Int, _ b: Int) -> Int { min(a, b) * 100_000 + max(a, b) }

    private static func load() -> ([Terrain], Set<Int>, [Int: String], Bool) {
        let provinces = ProvinceMap.all
        if let url = Bundle.main.url(forResource: "terrain", withExtension: "json"),
           let raw = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: raw),
           file.regions == provinces.count, file.terrain.count == provinces.count {
            let t = file.terrain.map { Terrain(rawValue: $0) ?? .plains }
            var r = Set<Int>()
            for pair in file.rivers where pair.count == 2 { r.insert(key(pair[0], pair[1])) }
            var c: [Int: String] = [:]
            for (k, v) in file.cities ?? [:] { if let i = Int(k) { c[i] = v } }
            return (t, r, c, true)
        }
        // Pas de fichier : estimation d'après la latitude et la taille.
        let t: [Terrain] = provinces.map { p in
            let lat = abs(p.label.lat)
            if p.weight < 2500 { return .urban }
            if lat >= 66 { return .tundra }
            if lat < 12 { return .jungle }
            if lat >= 18 && lat <= 32 && p.weight > 50_000 { return .desert }
            if lat >= 52 { return .forest }
            return .plains
        }
        return (t, [], [:], false)
    }
}

// MARK: - Météo

enum Weather: String, Codable {
    case clear, winter, mud, monsoon, heat

    var name: String {
        switch self {
        case .clear: return "Temps clair"
        case .winter: return "Hiver rigoureux"
        case .mud: return "Raspoutitsa (boue)"
        case .monsoon: return "Mousson"
        case .heat: return "Chaleur extrême"
        }
    }

    var icon: String {
        switch self {
        case .clear: return "sun.min"
        case .winter: return "snowflake"
        case .mud: return "cloud.rain"
        case .monsoon: return "cloud.heavyrain.fill"
        case .heat: return "thermometer.sun.fill"
        }
    }

    var attack: Double {
        switch self {
        case .clear: return 1
        case .winter: return 0.8
        case .mud: return 0.85
        case .monsoon: return 0.85
        case .heat: return 0.92
        }
    }

    var armor: Double {
        switch self {
        case .mud: return 0.7
        case .winter: return 0.9
        case .monsoon: return 0.8
        default: return 1
        }
    }

    var movement: Double {
        switch self {
        case .clear: return 1
        case .winter: return 0.75
        case .mud: return 0.5
        case .monsoon: return 0.7
        case .heat: return 0.9
        }
    }
}

extension Simulation {

    var currentMonth: Int {
        Calendar(identifier: .gregorian).component(.month, from: currentDate)
    }

    func weather(at province: Int) -> Weather {
        let p = ProvinceMap.all[province]
        let lat = p.label.lat, lon = p.label.lon
        let m = currentMonth
        let terrain = TerrainMap.terrain(province)
        // Hémisphère sud : saisons inversées.
        let northWinter = [12, 1, 2].contains(m)
        let southWinter = [6, 7, 8].contains(m)
        if (lat > 44 && northWinter) || (lat < -44 && southWinter) || (terrain == .mountains && abs(lat) > 30 && (lat > 0 ? northWinter : southWinter)) {
            return .winter
        }
        // Boue du printemps et de l'automne dans les grandes plaines d'Europe de l'Est.
        if lat > 44 && lat < 62 && lon > 20 && lon < 60 && [3, 4, 10, 11].contains(m) && terrain != .urban {
            return .mud
        }
        if lat > 5 && lat < 28 && lon > 65 && lon < 110 && [6, 7, 8, 9].contains(m) {
            return .monsoon
        }
        if terrain == .desert && [6, 7, 8].contains(m) && lat > 10 {
            return .heat
        }
        return .clear
    }
}
