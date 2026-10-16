import Foundation

// =============================================================
//  Provinces.swift
//  Géométrie des régions et propriétaire de chacune.
//
//  Chaque région est une cellule de Voronoï autour de son centre,
//  limitée à un rayon proportionnel à sa superficie : la carte
//  ressemble à un vrai découpage, sans fichier de frontières.
//  Les territoires occupés, annexés ou tenus par des rebelles
//  sont attribués région par région, en partant du front.
// =============================================================

struct GeoPoint: Codable, Hashable {
    var lat: Double
    var lon: Double
}

struct Province: Identifiable {
    let id: Int
    let country: CountryID
    let name: String
    let center: GeoPoint
    let weight: Double
    let radiusKm: Double
    let outline: [GeoPoint]
}

enum ProvinceStatus: String {
    case core, occupied, annexed, rebel
}

struct ProvinceOwner {
    let owner: CountryID?        // nil = rebelles
    let status: ProvinceStatus
}

enum ProvinceMap {

    static let all: [Province] = build()

    static let byCountry: [CountryID: [Int]] = {
        var result: [CountryID: [Int]] = [:]
        for p in all { result[p.country, default: []].append(p.id) }
        return result
    }()

    // MARK: Plan local (km) autour d'un point

    private static func local(_ p: GeoPoint, around o: GeoPoint) -> (Double, Double) {
        var dLon = p.lon - o.lon
        if dLon > 180 { dLon -= 360 }
        if dLon < -180 { dLon += 360 }
        let x = dLon * 111.32 * cos(o.lat * .pi / 180)
        let y = (p.lat - o.lat) * 110.57
        return (x, y)
    }

    private static func geo(_ x: Double, _ y: Double, around o: GeoPoint) -> GeoPoint {
        let lat = (o.lat + y / 110.57).clamped(-85, 85)
        var lon = o.lon + x / (111.32 * max(0.05, cos(o.lat * .pi / 180)))
        if lon > 180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        return GeoPoint(lat: lat, lon: lon.clamped(-179.9, 179.9))
    }

    static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let (x, y) = local(b, around: a)
        return (x * x + y * y).squareRoot()
    }

    // MARK: Construction

    private static func build() -> [Province] {
        // 1. Centres et superficies
        var areas: [CountryID: Double] = [:]
        var names: [CountryID: String] = [:]
        for s in WorldData.seeds() + WorldDataExtra.seeds() {
            areas[s.id] = s.area * 1000
            names[s.id] = s.name
        }
        struct Seed {
            let country: CountryID
            let name: String
            let center: GeoPoint
            let weight: Double
            let radius: Double
        }
        var seeds: [Seed] = []
        for id in Geo.table.keys.sorted() {
            let entries: [ProvinceData.Entry]
            if let list = ProvinceData.lists[id], !list.isEmpty {
                entries = list
            } else {
                let g = Geo.info(id)
                entries = [(names[id] ?? id, g.lat, g.lon)]
            }
            let totalWeight = entries.reduce(0.0) { $0 + ProvinceData.weight(id, $1.0) }
            for e in entries {
                let w = ProvinceData.weight(id, e.0)
                let area = (areas[id] ?? 50_000) * w / max(totalWeight, 0.001)
                let radius = ((area / Double.pi).squareRoot() * 1.7).clamped(25, 800)
                seeds.append(Seed(country: id, name: e.0, center: GeoPoint(lat: e.1, lon: e.2), weight: w, radius: radius))
            }
        }

        // 2. Cellule de chaque région : cercle découpé par les médiatrices des voisines
        var provinces: [Province] = []
        for (i, s) in seeds.enumerated() {
            var polygon: [(Double, Double)] = []
            let sides = 30
            for k in 0..<sides {
                let a = Double(k) / Double(sides) * 2 * Double.pi
                polygon.append((cos(a) * s.radius, sin(a) * s.radius))
            }
            for (j, other) in seeds.enumerated() where j != i {
                let (ox, oy) = local(other.center, around: s.center)
                let d2 = ox * ox + oy * oy
                let reach = s.radius + other.radius
                guard d2 < reach * reach, d2 > 0.0001 else { continue }
                polygon = clip(polygon, nx: ox, ny: oy, limit: d2 / 2)
                if polygon.count < 3 { break }
            }
            let outline = polygon.map { geo($0.0, $0.1, around: s.center) }
            provinces.append(Province(id: i, country: s.country, name: s.name, center: s.center,
                                      weight: s.weight, radiusKm: s.radius, outline: outline))
        }
        return provinces
    }

    /// Garde la partie du polygone où  x·nx + y·ny ≤ limit  (Sutherland–Hodgman).
    private static func clip(_ poly: [(Double, Double)], nx: Double, ny: Double, limit: Double) -> [(Double, Double)] {
        guard !poly.isEmpty else { return poly }
        var result: [(Double, Double)] = []
        for k in 0..<poly.count {
            let a = poly[k]
            let b = poly[(k + 1) % poly.count]
            let va = a.0 * nx + a.1 * ny - limit
            let vb = b.0 * nx + b.1 * ny - limit
            if va <= 0 { result.append(a) }
            if (va <= 0) != (vb <= 0) {
                let t = va / (va - vb)
                result.append((a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t))
            }
        }
        return result
    }

    /// Région sous un point de la carte (la plus proche dont le rayon couvre le point).
    static func province(at point: GeoPoint) -> Province? {
        var best: Province?
        var bestDistance = Double.infinity
        for p in all {
            guard abs(p.center.lat - point.lat) < 12 else { continue }
            let d = distanceKm(p.center, point)
            if d < bestDistance && d <= p.radiusKm {
                best = p
                bestDistance = d
            }
        }
        return best
    }
}

// MARK: - Propriétaire de chaque région

extension Simulation {

    /// Répartit occupations, annexions et zones rebelles entre les régions de chaque pays.
    func provinceOwners() -> [Int: ProvinceOwner] {
        var result: [Int: ProvinceOwner] = [:]
        for (country, ids) in ProvinceMap.byCountry {
            var free = ids.map { ProvinceMap.all[$0] }
            let totalWeight = free.reduce(0.0) { $0 + $1.weight }
            var parts: [(holder: CountryID?, fraction: Double, status: ProvinceStatus)] = []
            for (holder, f) in state.annexation[country] ?? [:] where f > 0.001 {
                parts.append((holder, f, .annexed))
            }
            for (holder, f) in state.occupation[country] ?? [:] where f > 0.001 {
                parts.append((holder, f, .occupied))
            }
            if let rebels = state.countries[country]?.civilWar, rebels > 0.001 {
                parts.append((nil, rebels, .rebel))
            }
            parts.sort { a, b in
                if a.status != b.status { return a.status == .annexed }
                return a.fraction > b.fraction
            }
            let capital = free.first?.center ?? GeoPoint(lat: 0, lon: 0)
            for part in parts {
                let ordered = orderFor(part.holder, victim: country, candidates: free, capital: capital)
                var taken = 0.0
                let target = part.fraction * totalWeight
                var remaining: [Province] = []
                for p in ordered {
                    if taken < target - p.weight / 2 {
                        result[p.id] = ProvinceOwner(owner: part.holder, status: part.status)
                        taken += p.weight
                    } else {
                        remaining.append(p)
                    }
                }
                free = remaining
            }
            for p in free {
                result[p.id] = ProvinceOwner(owner: country, status: .core)
            }
        }
        return result
    }

    private func orderFor(_ holder: CountryID?, victim: CountryID, candidates: [Province], capital: GeoPoint) -> [Province] {
        guard let holder = holder else {
            // Rebelles : les régions les plus éloignées de la capitale tombent d'abord.
            return candidates.sorted { ProvinceMap.distanceKm($0.center, capital) > ProvinceMap.distanceKm($1.center, capital) }
        }
        let explicit = ProvinceData.occupationOrder[victim + "|" + holder] ?? []
        let holderCenters = (ProvinceMap.byCountry[holder] ?? []).map { ProvinceMap.all[$0].center }
        func frontDistance(_ p: Province) -> Double {
            if let index = explicit.firstIndex(of: p.name) { return Double(index) - 1_000_000 }
            if holderCenters.isEmpty { return ProvinceMap.distanceKm(p.center, capital) }
            return holderCenters.map { ProvinceMap.distanceKm(p.center, $0) }.min() ?? 0
        }
        return candidates.sorted { frontDistance($0) < frontDistance($1) }
    }
}
