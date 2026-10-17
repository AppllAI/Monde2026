import Foundation
import MapKit
import UIKit

// =============================================================
//  Units.swift
//  Les unités sur la carte, séparées du dessin des régions :
//   - leur position exacte (au centre d'une région, ou plaquées
//     sur une frontière qu'elles tiennent), interpolée pendant
//     les déplacements pour qu'elles glissent sur la carte,
//   - leurs pictogrammes (char, blindé, casque, parachute, ancre),
//   - les trajets, flèches d'attaque et badges de bataille.
//  La carte des régions ne se redessine plus à chaque jour :
//  seules ces unités bougent, c'est ce qui rend le jeu fluide.
// =============================================================

struct UnitToken: Equatable, Identifiable {
    let id: Int
    let point: MKMapPoint
    let owner: CountryID
    let flag: String
    let color: RGBA
    let count: Int
    let mainType: DivisionType
    let mix: [Double]
    let isPlayer: Bool
    let selected: Bool
    let engaged: Bool
    let moving: Bool
    let training: Bool
    let serving: Bool
    let onBorder: Bool

    static func == (l: UnitToken, r: UnitToken) -> Bool {
        l.id == r.id && l.point.x == r.point.x && l.point.y == r.point.y && l.count == r.count && l.selected == r.selected
            && l.engaged == r.engaged && l.moving == r.moving && l.training == r.training && l.mainType == r.mainType
            && l.serving == r.serving && l.onBorder == r.onBorder && l.mix == r.mix
    }
}

struct UnitRoute: Equatable {
    let points: [MKMapPoint]
    let hostileFrom: Int?
    let selected: Bool

    static func == (l: UnitRoute, r: UnitRoute) -> Bool {
        l.hostileFrom == r.hostileFrom && l.selected == r.selected && l.points.count == r.points.count
            && zip(l.points, r.points).allSatisfy { $0.x == $1.x && $0.y == $1.y }
    }
}

struct BattleBadge: Equatable, Identifiable {
    let id: Int
    let point: MKMapPoint
    let fronts: [MKMapPoint]
    let progress: Double
    let attackerColor: RGBA
    let side: Int
    let winning: Bool

    static func == (l: BattleBadge, r: BattleBadge) -> Bool {
        l.id == r.id && l.progress == r.progress && l.side == r.side && l.winning == r.winning && l.fronts.count == r.fronts.count
    }
}

struct UnitsSnapshot: Equatable {
    var tokens: [UnitToken] = []
    var routes: [UnitRoute] = []
    var battles: [BattleBadge] = []
    var bombed: [Int] = []

    static let empty = UnitsSnapshot()
}

// MARK: - Points d'ancrage (centre de région, ou frontière)

final class Anchors {
    static let shared = Anchors()
    private var cache: [Int: MKMapPoint] = [:]

    func center(_ p: Int) -> MKMapPoint { ProvinceMap.all[p].labelPoint }

    /// Point sur la frontière entre deux régions voisines, légèrement du côté de `a`.
    func border(_ a: Int, _ b: Int) -> MKMapPoint {
        let key = a * 100_000 + b
        if let p = cache[key] { return p }
        var best: [MKMapPoint] = []
        // Les frontières sont rangées sans ordre : on cherche (a, b) ou (b, a).
        if let list = Anchors.borderIndex[min(a, b) * 100_000 + max(a, b)] {
            for i in list {
                for line in ProvinceMap.borders[i].lines where line.count > best.count { best = line }
            }
        }
        let c = center(a)
        let point: MKMapPoint
        if best.isEmpty {
            let o = center(b)
            point = MKMapPoint(x: c.x + (o.x - c.x) * 0.42, y: c.y + (o.y - c.y) * 0.42)
        } else {
            let mid = best[best.count / 2]
            // On recule vers l'intérieur de la région (22 %) pour rester de notre côté de la ligne.
            point = MKMapPoint(x: mid.x + (c.x - mid.x) * 0.22, y: mid.y + (c.y - mid.y) * 0.22)
        }
        cache[key] = point
        return point
    }

    private static let borderIndex: [Int: [Int]] = {
        var out: [Int: [Int]] = [:]
        for (i, b) in ProvinceMap.borders.enumerated() {
            out[min(b.a, b.b) * 100_000 + max(b.a, b.b), default: []].append(i)
        }
        return out
    }()

    /// Où se tient l'armée (hors déplacement).
    func rest(_ a: Army) -> MKMapPoint {
        if let f = a.facing, ProvinceMap.all[a.province].neighbors.contains(f) { return border(a.province, f) }
        return center(a.province)
    }

    func lerp(_ a: MKMapPoint, _ b: MKMapPoint, _ t: Double) -> MKMapPoint {
        MKMapPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
}

// MARK: - Construction de l'instantané

enum UnitsBuilder {

    static func build(_ sim: Simulation, selectedArmy: Int?, group: Set<Int>) -> UnitsSnapshot {
        let anchors = Anchors.shared
        let player = sim.state.playerID
        var snap = UnitsSnapshot()
        var foesCache: [CountryID: Set<CountryID>] = [:]
        func foes(_ id: CountryID) -> Set<CountryID> {
            if let f = foesCache[id] { return f }
            let f = sim.enemies(of: id)
            foesCache[id] = f
            return f
        }
        for a in sim.state.armies.sorted(by: { $0.id < $1.id }) {
            let rest = anchors.rest(a)
            var point = rest
            if let next = a.path.first {
                // En chemin : l'unité glisse vers la prochaine région (ou s'arrête sur la ligne si elle attaque).
                let target = foes(a.side).contains(sim.controller(of: next))
                    ? anchors.border(a.province, next)
                    : (a.path.count == 1 && a.facing != nil && ProvinceMap.all[next].neighbors.contains(a.facing!)
                       ? anchors.border(next, a.facing!) : anchors.center(next))
                let start = anchors.center(a.province)
                point = a.engaged ? target : anchors.lerp(start, target, min(1, a.progress))
            }
            let total = Double(max(1, a.count))
            let selected = a.id == selectedArmy || group.contains(a.id)
            snap.tokens.append(UnitToken(id: a.id, point: point, owner: a.owner, flag: Geo.flag(a.owner),
                                         color: RGBA(Theme.politicalColor(a.owner)), count: a.count, mainType: a.mainType,
                                         mix: DivisionType.allCases.map { (Double(a.divisions[$0] ?? 0) / total * 20).rounded() / 20 },
                                         isPlayer: a.owner == player, selected: selected, engaged: a.engaged,
                                         moving: !a.path.isEmpty && !a.engaged, training: a.training && a.path.isEmpty,
                                         serving: a.servingFor != nil, onBorder: a.facing != nil && a.path.isEmpty))
            if a.owner == player && !a.path.isEmpty {
                var pts = [point]
                var hostile: Int?
                var prev = a.province
                for (k, p) in a.path.enumerated() {
                    let isFoe = foes(a.side).contains(sim.controller(of: p))
                    if hostile == nil && isFoe { hostile = k }
                    let last = k == a.path.count - 1
                    pts.append(last && a.facing != nil && ProvinceMap.all[p].neighbors.contains(a.facing!)
                               ? anchors.border(p, a.facing!) : anchors.center(p))
                    prev = p
                }
                _ = prev
                snap.routes.append(UnitRoute(points: pts, hostileFrom: hostile, selected: selected))
            }
        }
        for b in sim.state.battles.values.sorted(by: { $0.province < $1.province }) {
            let side = sim.playerSide(in: b)
            snap.battles.append(BattleBadge(id: b.province, point: anchors.center(b.province),
                                            fronts: b.fronts.map { anchors.border($0, b.province) },
                                            progress: (b.captureProgress * 20).rounded() / 20,
                                            attackerColor: RGBA(Theme.politicalColor(b.attacker)), side: side,
                                            winning: side == 1 ? b.balance > 0.5 : b.balance < 0.5))
        }
        snap.bombed = sim.state.bombardments.keys.sorted()
        return snap
    }
}

// MARK: - Pictogrammes des unités

enum UnitArt {
    /// Dessine le pictogramme du type d'unité dans `r` (blanc sur fond sombre).
    static func draw(_ type: DivisionType, in r: CGRect, color: UIColor = .white, context ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let w = r.width, h = r.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        switch type {
        case .armored:
            // Char : chenilles, caisse, tourelle et canon.
            ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: p(0.04, 0.66), size: CGSize(width: w * 0.80, height: h * 0.28)),
                                     cornerRadius: h * 0.14).cgPath)
            ctx.fillPath()
            ctx.fill(CGRect(origin: p(0.10, 0.46), size: CGSize(width: w * 0.66, height: h * 0.22)))
            ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: p(0.24, 0.22), size: CGSize(width: w * 0.34, height: h * 0.26)),
                                     cornerRadius: h * 0.08).cgPath)
            ctx.fillPath()
            ctx.setLineWidth(h * 0.10)
            ctx.move(to: p(0.56, 0.32)); ctx.addLine(to: p(0.98, 0.26)); ctx.strokePath()
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            for x in [0.16, 0.34, 0.52, 0.70] as [CGFloat] {
                ctx.fillEllipse(in: CGRect(origin: p(x - 0.05, 0.72), size: CGSize(width: w * 0.10, height: h * 0.16)))
            }
        case .mechanized:
            // Blindé de transport : caisse inclinée, roues.
            let body = UIBezierPath()
            body.move(to: p(0.04, 0.70)); body.addLine(to: p(0.04, 0.38)); body.addLine(to: p(0.62, 0.30))
            body.addLine(to: p(0.94, 0.48)); body.addLine(to: p(0.96, 0.70)); body.close()
            ctx.addPath(body.cgPath); ctx.fillPath()
            ctx.fill(CGRect(origin: p(0.26, 0.16), size: CGSize(width: w * 0.20, height: h * 0.16)))
            ctx.setLineWidth(h * 0.08)
            ctx.move(to: p(0.44, 0.22)); ctx.addLine(to: p(0.70, 0.18)); ctx.strokePath()
            for x in [0.20, 0.50, 0.80] as [CGFloat] {
                ctx.fillEllipse(in: CGRect(origin: p(x - 0.09, 0.66), size: CGSize(width: w * 0.18, height: h * 0.32)))
            }
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            for x in [0.20, 0.50, 0.80] as [CGFloat] {
                ctx.fillEllipse(in: CGRect(origin: p(x - 0.04, 0.75), size: CGSize(width: w * 0.08, height: h * 0.14)))
            }
        case .infantry:
            // Casque de soldat et fusil.
            let helmet = UIBezierPath()
            helmet.move(to: p(0.16, 0.66))
            helmet.addCurve(to: p(0.70, 0.66), controlPoint1: p(0.16, 0.06), controlPoint2: p(0.70, 0.06))
            helmet.addLine(to: p(0.86, 0.70)); helmet.addLine(to: p(0.00, 0.70)); helmet.close()
            ctx.addPath(helmet.cgPath); ctx.fillPath()
            ctx.fill(CGRect(origin: p(0.04, 0.70), size: CGSize(width: w * 0.80, height: h * 0.10)))
            // Lunettes (bande sur le casque) pour bien le reconnaître.
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.45).cgColor)
            ctx.fill(CGRect(origin: p(0.22, 0.44), size: CGSize(width: w * 0.42, height: h * 0.08)))
        case .airborne:
            // Parachute.
            let canopy = UIBezierPath()
            canopy.move(to: p(0.10, 0.45))
            canopy.addCurve(to: p(0.90, 0.45), controlPoint1: p(0.10, -0.10), controlPoint2: p(0.90, -0.10))
            canopy.close()
            ctx.addPath(canopy.cgPath); ctx.fillPath()
            ctx.setLineWidth(max(1, h * 0.05))
            for x in [0.12, 0.38, 0.62, 0.88] as [CGFloat] { ctx.move(to: p(x, 0.45)); ctx.addLine(to: p(0.5, 0.80)) }
            ctx.strokePath()
            ctx.fillEllipse(in: CGRect(origin: p(0.42, 0.76), size: CGSize(width: w * 0.16, height: h * 0.22)))
        case .marines:
            // Ancre.
            ctx.setLineWidth(h * 0.10)
            ctx.strokeEllipse(in: CGRect(origin: p(0.42, 0.04), size: CGSize(width: w * 0.16, height: h * 0.20)))
            ctx.move(to: p(0.5, 0.24)); ctx.addLine(to: p(0.5, 0.92))
            ctx.move(to: p(0.30, 0.38)); ctx.addLine(to: p(0.70, 0.38))
            ctx.strokePath()
            let arc = UIBezierPath()
            arc.move(to: p(0.14, 0.62))
            arc.addQuadCurve(to: p(0.86, 0.62), controlPoint: p(0.5, 1.12))
            ctx.addPath(arc.cgPath); ctx.strokePath()
        }
        ctx.restoreGState()
    }

    static let mixColors: [UIColor] = [UIColor(white: 0.88, alpha: 1), UIColor(red: 0.42, green: 0.66, blue: 0.95, alpha: 1),
                                       UIColor(red: 0.95, green: 0.71, blue: 0.27, alpha: 1), UIColor(red: 0.23, green: 0.72, blue: 0.65, alpha: 1),
                                       UIColor(red: 0.55, green: 0.45, blue: 0.95, alpha: 1)]
}
