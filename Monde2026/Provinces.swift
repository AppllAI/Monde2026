import Foundation
import MapKit

// =============================================================
//  Provinces.swift
//  Les régions du monde, chargées depuis Resources/map.bin
//  (construit par tools/build_map.py à partir de Natural Earth,
//  données du domaine public) : vraies frontières, voisins,
//  frontières partagées. Et le propriétaire de chaque région.
// =============================================================

struct GeoPoint: Codable, Hashable {
    var lat: Double
    var lon: Double
}

struct Province: Identifiable {
    let id: Int
    let country: CountryID          // pays d'origine (peut être un pays neutre, non jouable)
    let countryName: String
    let name: String
    let label: GeoPoint             // point où écrire le nom
    let areaKm2: Double
    let rings: [[MKMapPoint]]       // contours en coordonnées MapKit
    let bounds: MKMapRect
    let path: CGPath                // contour prêt à dessiner (coordonnées MapKit)
    let neighbors: [Int]
    let coastal: Bool

    var weight: Double { max(areaKm2, 1) }
    var center: GeoPoint { label }
    var labelPoint: MKMapPoint { MKMapPoint(CLLocationCoordinate2D(latitude: label.lat, longitude: label.lon)) }
}

struct ProvinceBorder {
    let a: Int
    let b: Int
    let lines: [[MKMapPoint]]
    let path: CGPath
    let bounds: MKMapRect
}

enum ProvinceStatus: String {
    case core, occupied, annexed, rebel, neutral
}

struct ProvinceOwner: Equatable {
    let owner: CountryID?        // nil = rebelles
    let status: ProvinceStatus
}

enum ProvinceMap {

    private static let loaded: (provinces: [Province], borders: [ProvinceBorder]) = load()

    static var all: [Province] { loaded.provinces }
    static var borders: [ProvinceBorder] { loaded.borders }

    static let byCountry: [CountryID: [Int]] = {
        var result: [CountryID: [Int]] = [:]
        for p in all { result[p.country, default: []].append(p.id) }
        return result
    }()

    /// Ordre dans lequel un occupant prend les régions (les autres : les plus proches de lui d'abord).
    static let occupationOrder: [String: [String]] = [
        "UKR|RUS": ["Crimée", "Crimea", "Lougansk", "Louhansk", "Luhansk", "Donetsk", "Zaporijjia", "Zaporizhzhia",
                    "Kherson"],
        "GEO|RUS": ["Ossétie du Sud", "Abkhazie", "Abkhazia", "Shida Kartli"],
        "MDA|RUS": ["Transnistrie", "Stînga Nistrului", "Transnistria"],
        "CYP|TUR": ["Chypre du Nord", "Northern Cyprus", "Lefkoşa", "Gazimağusa", "Girne", "Güzelyurt", "İskele"],
        "SYR|ISR": ["Quneitra", "Kuneitra"]
    ]

    // MARK: Lecture du fichier

    private static func load() -> ([Province], [ProvinceBorder]) {
        guard let url = Bundle.main.url(forResource: "map", withExtension: "bin"),
              let data = try? Data(contentsOf: url) else {
            return ([], [])
        }
        var reader = BinaryReader(data: data)
        let version = reader.ascii(4)
        guard version == "MAP2" || version == "MAP3" else { return ([], []) }
        let count = Int(reader.u32())
        var provinces: [Province] = []
        provinces.reserveCapacity(count)
        for id in 0..<count {
            let code = reader.ascii(3).trimmingCharacters(in: .whitespaces)
            let rawName = reader.string()
            let countryName = reader.string()
            let name = rawName == "?" || rawName.isEmpty ? countryName : rawName
            let lat = Double(reader.f32()), lon = Double(reader.f32())
            let area = Double(reader.f32())
            let ringCount = Int(reader.u16())
            var rings: [[MKMapPoint]] = []
            var bounds = MKMapRect.null
            let path = CGMutablePath()
            for _ in 0..<ringCount {
                let n = Int(reader.u32())
                var ring: [MKMapPoint] = []
                ring.reserveCapacity(n)
                for _ in 0..<n {
                    let x = Double(reader.f32()), y = Double(reader.f32())
                    ring.append(MKMapPoint(CLLocationCoordinate2D(latitude: y.clamped(-85, 85), longitude: x.clamped(-180, 180))))
                }
                if let first = ring.first {
                    path.move(to: CGPoint(x: first.x, y: first.y))
                    for p in ring.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
                    path.closeSubpath()
                }
                for p in ring { bounds = bounds.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0)) }
                rings.append(ring)
            }
            let nCount = Int(reader.u16())
            var neighbors: [Int] = []
            for _ in 0..<nCount { neighbors.append(Int(reader.u16())) }
            let coastal = version == "MAP3" ? reader.u8() != 0 : true
            provinces.append(Province(id: id, country: code, countryName: countryName, name: name,
                                      label: GeoPoint(lat: lat, lon: lon), areaKm2: area, rings: rings,
                                      bounds: bounds, path: path, neighbors: neighbors, coastal: coastal))
        }
        var borders: [ProvinceBorder] = []
        let edgeCount = Int(reader.u32())
        for _ in 0..<edgeCount {
            let a = Int(reader.u16()), b = Int(reader.u16())
            let lineCount = Int(reader.u16())
            var lines: [[MKMapPoint]] = []
            var bounds = MKMapRect.null
            let path = CGMutablePath()
            for _ in 0..<lineCount {
                let n = Int(reader.u32())
                var line: [MKMapPoint] = []
                for _ in 0..<n {
                    let x = Double(reader.f32()), y = Double(reader.f32())
                    line.append(MKMapPoint(CLLocationCoordinate2D(latitude: y.clamped(-85, 85), longitude: x.clamped(-180, 180))))
                }
                if let first = line.first {
                    path.move(to: CGPoint(x: first.x, y: first.y))
                    for p in line.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: p.y)) }
                }
                for p in line { bounds = bounds.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0)) }
                lines.append(line)
            }
            if reader.failed { break }
            borders.append(ProvinceBorder(a: a, b: b, lines: lines, path: path, bounds: bounds))
        }
        return (provinces, borders)
    }

    static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        var dLon = b.lon - a.lon
        if dLon > 180 { dLon -= 360 }
        if dLon < -180 { dLon += 360 }
        let x = dLon * 111.32 * cos(a.lat * .pi / 180)
        let y = (b.lat - a.lat) * 110.57
        return (x * x + y * y).squareRoot()
    }

    /// Région sous un point de la carte.
    static func province(at point: GeoPoint) -> Province? {
        let mp = MKMapPoint(CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon))
        let cg = CGPoint(x: mp.x, y: mp.y)
        for p in all where p.bounds.contains(mp) {
            if p.path.contains(cg) { return p }
        }
        return nil
    }
}

/// Lecture d'un fichier binaire petit-boutiste.
struct BinaryReader {
    let data: Data
    var offset = 0
    var failed = false

    init(data: Data) { self.data = data }

    private mutating func bytes(_ n: Int) -> Data? {
        guard offset + n <= data.count else {
            failed = true
            return nil
        }
        let slice = data.subdata(in: (data.startIndex + offset)..<(data.startIndex + offset + n))
        offset += n
        return slice
    }

    mutating func u8() -> UInt8 {
        guard let b = bytes(1) else { return 0 }
        return b[b.startIndex]
    }

    mutating func u16() -> UInt16 {
        guard let b = bytes(2) else { return 0 }
        return UInt16(b[b.startIndex]) | (UInt16(b[b.startIndex + 1]) << 8)
    }

    mutating func u32() -> UInt32 {
        guard let b = bytes(4) else { return 0 }
        var v: UInt32 = 0
        for i in 0..<4 { v |= UInt32(b[b.startIndex + i]) << (8 * UInt32(i)) }
        return v
    }

    mutating func f32() -> Float {
        Float(bitPattern: u32())
    }

    mutating func ascii(_ n: Int) -> String {
        guard let b = bytes(n) else { return "" }
        return String(decoding: b, as: UTF8.self)
    }

    mutating func string() -> String {
        let n = Int(u16())
        guard let b = bytes(n) else { return "" }
        return String(decoding: b, as: UTF8.self)
    }
}

// MARK: - Propriétaire de chaque région

extension Simulation {

    /// Répartit occupations, annexions et zones rebelles entre les régions de chaque pays.
    /// Propriétaire de chaque région : contrôle militaire réel (armées) + zones rebelles.
    func provinceOwners() -> [Int: ProvinceOwner] {
        var result: [Int: ProvinceOwner] = [:]
        let provinces = ProvinceMap.all
        for (country, ids) in ProvinceMap.byCountry {
            guard state.countries[country] != nil else {
                for id in ids { result[id] = ProvinceOwner(owner: country, status: .neutral) }
                continue
            }
            var free: [Province] = []
            for id in ids {
                if let holder = state.control[id], holder != country {
                    result[id] = ProvinceOwner(owner: holder, status: state.annexedProvinces.contains(id) ? .annexed : .occupied)
                } else {
                    free.append(provinces[id])
                }
            }
            // Les rebelles tiennent une part des régions encore contrôlées par le gouvernement.
            if let rebels = state.countries[country]?.civilWar, rebels > 0.001 {
                let totalWeight = ids.reduce(0.0) { $0 + provinces[$1].weight }
                let capital = free.max { $0.weight < $1.weight }?.label ?? GeoPoint(lat: 0, lon: 0)
                let ordered = orderFor(nil, victim: country, candidates: free, capital: capital)
                var taken = 0.0
                var remaining: [Province] = []
                for p in ordered {
                    if taken < rebels * totalWeight - p.weight / 2 {
                        result[p.id] = ProvinceOwner(owner: nil, status: .rebel)
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

    /// Ancienne répartition à partir des pourcentages (sert seulement à placer la situation de départ).
    func ownersFromFractions() -> [Int: ProvinceOwner] {
        var result: [Int: ProvinceOwner] = [:]
        let provinces = ProvinceMap.all
        for (country, ids) in ProvinceMap.byCountry {
            guard state.countries[country] != nil else {
                for id in ids { result[id] = ProvinceOwner(owner: country, status: .neutral) }
                continue
            }
            var free = ids.map { provinces[$0] }
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
            // La « capitale » : la plus grande région du pays.
            let capital = free.max { $0.weight < $1.weight }?.label ?? GeoPoint(lat: 0, lon: 0)
            for part in parts {
                let ordered = orderFor(part.holder, victim: country, candidates: free, capital: capital)
                var taken = 0.0
                let target = part.fraction * totalWeight
                var remaining: [Province] = []
                // On prend les régions dans l'ordre du front et on s'arrête dès que la part est atteinte
                // (sinon de petites régions lointaines seraient ajoutées pour « compléter »).
                var full = false
                for p in ordered {
                    if !full && taken < target - p.weight / 2 {
                        result[p.id] = ProvinceOwner(owner: part.holder, status: part.status)
                        taken += p.weight
                    } else {
                        full = true
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
            return candidates.sorted { ProvinceMap.distanceKm($0.label, capital) > ProvinceMap.distanceKm($1.label, capital) }
        }
        let explicit = ProvinceMap.occupationOrder[victim + "|" + holder] ?? []
        let holderSet = Set(ProvinceMap.byCountry[holder] ?? [])
        // Distance en nombre de régions depuis la frontière de l'occupant (le front avance de proche en proche).
        let candidateSet = Set(candidates.map { $0.id })
        var steps: [Int: Int] = [:]
        var queue: [Int] = []
        for p in candidates where p.neighbors.contains(where: { holderSet.contains($0) }) {
            steps[p.id] = 0
            queue.append(p.id)
        }
        var head = 0
        while head < queue.count {
            let cur = queue[head]
            head += 1
            for n in ProvinceMap.all[cur].neighbors where candidateSet.contains(n) && steps[n] == nil {
                steps[n] = (steps[cur] ?? 0) + 1
                queue.append(n)
            }
        }
        func frontDistance(_ p: Province) -> Double {
            if let index = explicit.firstIndex(where: { p.name.localizedCaseInsensitiveContains($0) }) {
                return Double(index) - 1_000_000
            }
            if let s = steps[p.id] { return Double(s) * 10_000 + ProvinceMap.distanceKm(p.label, capital) * -1 }
            return 1_000_000 + ProvinceMap.distanceKm(p.label, capital)
        }
        return candidates.sorted { frontDistance($0) < frontDistance($1) }
    }
}
