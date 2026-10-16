import SwiftUI
import MapKit
import UIKit

// =============================================================
//  WorldMapView.swift
//  La carte de grande stratégie :
//   - vraies régions (Natural Earth) coloriées par propriétaire,
//   - frontières de pays épaisses, frontières de régions fines,
//   - lignes de front rouges entre pays en guerre,
//   - territoires occupés hachurés aux couleurs de l'occupant,
//   - noms des pays écrits SUR la carte (taille selon le pays,
//     ils grossissent avec le zoom), noms des régions de près.
//
//  Tout est dessiné dans UNE seule couche MapKit, par tuiles, en
//  arrière-plan : c'est fluide, même avec ~2 000 régions.
// =============================================================

// MARK: - Image de la carte (calculée sur le fil principal, dessinée en arrière-plan)

/// Couleur compacte (RGBA 8 bits) : rapide à comparer et à copier.
struct RGBA: Equatable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8

    init(_ color: UIColor, alpha: CGFloat? = nil) {
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        color.getRed(&rr, green: &gg, blue: &bb, alpha: &aa)
        r = UInt8((rr.clamped(0, 1) * 255).rounded())
        g = UInt8((gg.clamped(0, 1) * 255).rounded())
        b = UInt8((bb.clamped(0, 1) * 255).rounded())
        a = UInt8(((alpha ?? aa).clamped(0, 1) * 255).rounded())
    }

    var cgColor: CGColor {
        CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

struct ProvinceFill: Equatable {
    var color: RGBA
    var stripes: RGBA?          // hachures (territoire occupé ou rebelle)
}

enum BorderKind: UInt8 {
    case hidden, region, country, player, selected, front
}

struct MapLabel: Equatable, Identifiable {
    let id: String
    let text: String
    let x: Double              // coordonnées MapKit
    let y: Double
    let size: Double           // taille de police en points MapKit
    let isCountry: Bool
    let highlighted: Bool
}

struct PlanLine: Equatable, Identifiable {
    let id: String
    let from: GeoPoint
    let to: GeoPoint
}

struct MapSnapshot: Equatable {
    var fills: [ProvinceFill]
    var borders: [BorderKind]
    var labels: [MapLabel]
    var plans: [PlanLine]
    var selectedProvince: Int?

    static let empty = MapSnapshot(fills: [], borders: [], labels: [], plans: [], selectedProvince: nil)
}

enum MapSnapshotBuilder {

    static func build(_ sim: Simulation, mode: MapMode, selected: CountryID?, selectedProvince: Int?) -> MapSnapshot {
        let provinces = ProvinceMap.all
        guard !provinces.isEmpty else { return .empty }
        let owners = sim.provinceOwners()
        let player = sim.state.playerID

        var colorCache: [CountryID: UIColor] = [:]
        func color(_ id: CountryID) -> UIColor {
            if let cached = colorCache[id] { return cached }
            let c = countryColor(id, sim: sim, mode: mode)
            colorCache[id] = c
            return c
        }

        // 1. Couleur de chaque région
        var fills: [ProvinceFill] = []
        fills.reserveCapacity(provinces.count)
        var ownerOf: [CountryID?] = []
        ownerOf.reserveCapacity(provinces.count)
        for p in provinces {
            let info = owners[p.id] ?? ProvinceOwner(owner: p.country, status: .core)
            ownerOf.append(info.owner)
            switch info.status {
            case .neutral:
                fills.append(ProvinceFill(color: RGBA(Theme.neutralLand), stripes: nil))
            case .rebel:
                fills.append(ProvinceFill(color: RGBA(Theme.rebelLand),
                                          stripes: RGBA(UIColor.black, alpha: 0.35)))
            case .occupied:
                let holder = info.owner ?? p.country
                fills.append(ProvinceFill(color: RGBA(color(holder)),
                                          stripes: RGBA(color(p.country), alpha: 0.85)))
            case .core, .annexed:
                var base = color(info.owner ?? p.country)
                if let s = selected, info.owner == s {
                    base = base.lighter(0.12)
                }
                fills.append(ProvinceFill(color: RGBA(base), stripes: nil))
            }
        }

        // 2. Style de chaque frontière
        var enemiesCache: [CountryID: Set<CountryID>] = [:]
        func enemies(_ id: CountryID) -> Set<CountryID> {
            if let e = enemiesCache[id] { return e }
            let e = sim.enemies(of: id)
            enemiesCache[id] = e
            return e
        }
        var borders: [BorderKind] = []
        borders.reserveCapacity(ProvinceMap.borders.count)
        for border in ProvinceMap.borders {
            let oa = ownerOf[border.a], ob = ownerOf[border.b]
            if oa == ob {
                borders.append(provinces[border.a].country == provinces[border.b].country ? .region : .country)
                continue
            }
            if let a = oa, let b = ob, enemies(a).contains(b) {
                borders.append(.front)
            } else if oa == nil || ob == nil {
                borders.append(.front)        // front contre les rebelles
            } else if let s = selected, oa == s || ob == s {
                borders.append(.selected)
            } else if let p = player, oa == p || ob == p {
                borders.append(.player)
            } else {
                borders.append(.country)
            }
        }

        // 3. Noms des pays (sur leur plus grand territoire d'un seul tenant)
        var labels: [MapLabel] = []
        var byOwner: [CountryID: [Int]] = [:]
        for (i, o) in ownerOf.enumerated() {
            if let o = o { byOwner[o, default: []].append(i) }
        }
        for (owner, ids) in byOwner {
            let set = Set(ids)
            var seen = Set<Int>()
            var best: [Int] = []
            var bestArea = 0.0
            for start in ids where !seen.contains(start) {
                var component: [Int] = []
                var stack = [start]
                seen.insert(start)
                while let cur = stack.popLast() {
                    component.append(cur)
                    for n in provinces[cur].neighbors where set.contains(n) && !seen.contains(n) {
                        seen.insert(n)
                        stack.append(n)
                    }
                }
                let area = component.reduce(0.0) { $0 + provinces[$1].weight }
                if area > bestArea {
                    bestArea = area
                    best = component
                }
            }
            guard !best.isEmpty else { continue }
            var x = 0.0, y = 0.0
            for id in best {
                let p = provinces[id].labelPoint
                x += p.x * provinces[id].weight
                y += p.y * provinces[id].weight
            }
            x /= bestArea
            y /= bestArea
            // Si le centre tombe hors du territoire (forme en croissant), on prend la région la plus proche.
            let center = CGPoint(x: x, y: y)
            if !best.contains(where: { provinces[$0].path.contains(center) }) {
                let nearest = best.min { a, b in
                    let pa = provinces[a].labelPoint, pb = provinces[b].labelPoint
                    return hypot(pa.x - x, pa.y - y) < hypot(pb.x - x, pb.y - y)
                }
                if let n = nearest {
                    x = provinces[n].labelPoint.x
                    y = provinces[n].labelPoint.y
                }
            }
            let name = sim.state.countries[owner]?.name ?? provinces[best[0]].countryName
            let lat = MKMapPoint(x: x, y: y).coordinate.latitude
            let pointsPerKm = MKMapPointsPerMeterAtLatitude(lat) * 1000
            let side = bestArea.squareRoot()
            let byArea = side * 0.20
            let byWidth = side * 1.5 / (0.62 * Double(max(4, name.count)))
            let size = min(byArea, byWidth) * pointsPerKm
            labels.append(MapLabel(id: "c-" + owner, text: name, x: x, y: y, size: size, isCountry: true,
                                   highlighted: owner == player || owner == selected))
        }
        // Noms des régions (visibles seulement de près)
        for p in provinces where p.weight > 2000 {
            let lp = p.labelPoint
            let pointsPerKm = MKMapPointsPerMeterAtLatitude(p.label.lat) * 1000
            let side = p.weight.squareRoot()
            let size = min(side * 0.11, side * 1.3 / (0.6 * Double(max(4, p.name.count)))) * pointsPerKm
            labels.append(MapLabel(id: "p-\(p.id)", text: p.name, x: lp.x, y: lp.y + size * 1.6, size: size,
                                   isCountry: false, highlighted: p.id == selectedProvince))
        }

        // 4. Troupes massées
        var plans: [PlanLine] = []
        for plan in sim.state.warPlans {
            let a = Geo.info(plan.attacker), b = Geo.info(plan.target)
            plans.append(PlanLine(id: plan.attacker + ">" + plan.target,
                                  from: GeoPoint(lat: a.lat, lon: a.lon), to: GeoPoint(lat: b.lat, lon: b.lon)))
        }
        return MapSnapshot(fills: fills, borders: borders, labels: labels, plans: plans,
                           selectedProvince: selectedProvince)
    }

    static func countryColor(_ id: CountryID, sim: Simulation, mode: MapMode) -> UIColor {
        let player = sim.state.playerID
        guard sim.state.countries[id] != nil else { return Theme.neutralLand }
        switch mode {
        case .political:
            return Theme.politicalColor(id)
        case .alliances:
            if let bloc = sim.faction(of: id) { return UIColor(Theme.blocColor(bloc.id)) }
            let allies = sim.allies(of: id)
            if allies.contains("USA") || sim.guarantors(of: id).contains("USA") { return UIColor(Theme.blocColor("USA-ALLY")) }
            if allies.contains("CHN") || allies.contains("RUS") || id == "CHN" { return UIColor(Theme.blocColor("CHN-ALLY")) }
            return Theme.neutralLand
        case .relations:
            guard let p = player else { return Theme.neutralLand }
            return id == p ? UIColor(Theme.amber) : UIColor(Theme.relationColor(sim.relation(p, id)))
        case .economy:
            return UIColor(Theme.growthColor(sim.state.countries[id]?.growth ?? 0))
        case .military:
            if sim.isAtWar(id) { return UIColor(Theme.coral) }
            return UIColor(Theme.blend(Theme.steel, Theme.amber, min(1, sim.militaryPower(id) / 6000)))
        }
    }
}

extension UIColor {
    func lighter(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r + (1 - r) * amount, green: g + (1 - g) * amount, blue: b + (1 - b) * amount, alpha: a)
    }

    func darker(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount), alpha: a)
    }
}

// MARK: - Vue SwiftUI

/// Demande de recentrage de la carte (l'identifiant change à chaque demande).
struct MapFocus: Equatable {
    let id: Int
    let rect: MKMapRect

    static func == (lhs: MapFocus, rhs: MapFocus) -> Bool { lhs.id == rhs.id }
}

struct WorldMapView: UIViewRepresentable, Equatable {
    let snapshot: MapSnapshot
    let satellite: Bool
    let focus: MapFocus?
    let onTap: (GeoPoint) -> Void

    static func == (lhs: WorldMapView, rhs: WorldMapView) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.satellite == rhs.satellite && lhs.focus == rhs.focus
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.overrideUserInterfaceStyle = .dark
        map.delegate = context.coordinator
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 150_000,
                                                        maxCenterCoordinateDistance: 40_000_000)
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 42, longitude: 20),
                                         span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 150)),
                      animated: false)
        map.addOverlay(context.coordinator.overlay, level: .aboveLabels)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(MapCoordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        context.coordinator.mapView = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        if coordinator.satellite != satellite || coordinator.configured == false {
            coordinator.satellite = satellite
            coordinator.configured = true
            if satellite {
                map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
            } else {
                let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                config.pointOfInterestFilter = .excludingAll
                config.showsTraffic = false
                map.preferredConfiguration = config
            }
            coordinator.renderer?.fillAlpha = satellite ? 0.55 : 1.0
            coordinator.renderer?.setNeedsDisplay()
        }
        if let focus = focus, focus.id != coordinator.lastFocusID {
            coordinator.lastFocusID = focus.id
            map.setVisibleMapRect(focus.rect, edgePadding: UIEdgeInsets(top: 180, left: 40, bottom: 220, right: 40),
                                  animated: true)
        }
        coordinator.apply(snapshot)
    }
}

// MARK: - Couche unique de toutes les régions

final class ProvinceOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }
    var boundingMapRect: MKMapRect { .world }
}

final class ProvinceRenderer: MKOverlayRenderer {
    private let lock = NSLock()
    private var snapshot = MapSnapshot.empty
    var fillAlpha: CGFloat = 1.0

    func update(_ newSnapshot: MapSnapshot) {
        lock.lock()
        snapshot = newSnapshot
        lock.unlock()
        setNeedsDisplay()
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        lock.lock()
        let snap = snapshot
        lock.unlock()
        let provinces = ProvinceMap.all
        guard snap.fills.count == provinces.count else { return }
        let px = 1 / zoomScale                       // un point d'écran, en points MapKit
        let margin = mapRect.size.width * 0.05
        let area = mapRect.insetBy(dx: -margin, dy: -margin)
        let detailed = zoomScale > 1.0 / 4096        // zoom suffisant pour les détails

        context.setAlpha(fillAlpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        // 1. Remplissage des régions
        for (i, p) in provinces.enumerated() where p.bounds.intersects(area) {
            let fill = snap.fills[i]
            context.addPath(p.path)
            context.setFillColor(fill.color.cgColor)
            context.fillPath()
            if let stripes = fill.stripes {
                drawStripes(in: p, color: stripes, spacing: 7 * px, width: 2.2 * px, rect: area, context: context)
            }
        }
        context.endTransparencyLayer()
        context.setAlpha(1)

        // 2. Frontières
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let borders = ProvinceMap.borders
        let kinds = snap.borders
        guard kinds.count == borders.count else { return }
        // Passe 1 : frontières de régions (fines), seulement de près.
        if detailed {
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.22).cgColor)
            context.setLineWidth(0.6 * px)
            for (i, b) in borders.enumerated() where kinds[i] == .region && b.bounds.intersects(area) {
                context.addPath(b.path)
            }
            context.strokePath()
        }
        // Passe 2 : frontières de pays.
        context.setStrokeColor(UIColor(red: 0.05, green: 0.07, blue: 0.1, alpha: 0.85).cgColor)
        context.setLineWidth(1.4 * px)
        for (i, b) in borders.enumerated() where (kinds[i] == .country || kinds[i] == .player || kinds[i] == .selected)
            && b.bounds.intersects(area) {
            context.addPath(b.path)
        }
        context.strokePath()
        // Passe 3 : frontières du joueur et du pays sélectionné.
        stroke(kinds, .player, color: UIColor(Theme.amber).withAlphaComponent(0.9), width: 2 * px, area: area, context: context)
        stroke(kinds, .selected, color: UIColor.white.withAlphaComponent(0.95), width: 2.2 * px, area: area, context: context)
        // Passe 4 : lignes de front (halo + trait).
        stroke(kinds, .front, color: UIColor(Theme.coral).withAlphaComponent(0.35), width: 7 * px, area: area, context: context)
        stroke(kinds, .front, color: UIColor(Theme.coral), width: 2.6 * px, area: area, context: context)

        // 3. Région sélectionnée
        if let sel = snap.selectedProvince, sel < provinces.count, provinces[sel].bounds.intersects(area) {
            context.addPath(provinces[sel].path)
            context.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            context.fillPath()
            context.addPath(provinces[sel].path)
            context.setStrokeColor(UIColor(Theme.amber).cgColor)
            context.setLineWidth(2.5 * px)
            context.strokePath()
        }

        // 4. Troupes massées : flèches pointillées
        if !snap.plans.isEmpty {
            context.setStrokeColor(UIColor(Theme.amber).cgColor)
            context.setLineWidth(2.5 * px)
            context.setLineDash(phase: 0, lengths: [7 * px, 6 * px])
            for line in snap.plans {
                let a = MKMapPoint(CLLocationCoordinate2D(latitude: line.from.lat, longitude: line.from.lon))
                let b = MKMapPoint(CLLocationCoordinate2D(latitude: line.to.lat, longitude: line.to.lon))
                context.move(to: CGPoint(x: a.x, y: a.y))
                context.addLine(to: CGPoint(x: b.x, y: b.y))
            }
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        }

        // 5. Noms
        UIGraphicsPushContext(context)
        for label in snap.labels {
            let screen = label.size * zoomScale
            if label.isCountry {
                guard screen >= 7, screen <= 70 || label.highlighted else { continue }
            } else {
                guard screen >= 8.5, screen <= 34 else { continue }
            }
            let halfWidth = label.size * 0.35 * Double(label.text.count) + label.size
            let rect = MKMapRect(x: label.x - halfWidth, y: label.y - label.size, width: halfWidth * 2, height: label.size * 2)
            guard rect.intersects(mapRect) else { continue }
            drawLabel(label, context: context)
        }
        UIGraphicsPopContext()
    }

    private func stroke(_ kinds: [BorderKind], _ kind: BorderKind, color: UIColor, width: CGFloat,
                        area: MKMapRect, context: CGContext) {
        var any = false
        for (i, b) in ProvinceMap.borders.enumerated() where kinds[i] == kind && b.bounds.intersects(area) {
            context.addPath(b.path)
            any = true
        }
        guard any else { return }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.strokePath()
    }

    private func drawStripes(in province: Province, color: RGBA, spacing: CGFloat, width: CGFloat,
                             rect: MKMapRect, context: CGContext) {
        let box = province.bounds.intersection(rect)
        guard !box.isNull, box.size.width > 0 else { return }
        context.saveGState()
        context.addPath(province.path)
        context.clip()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        let minX = CGFloat(box.minX), maxX = CGFloat(box.maxX), minY = CGFloat(box.minY), maxY = CGFloat(box.maxY)
        let height = maxY - minY
        var x = minX - height
        var count = 0
        while x < maxX && count < 2000 {
            context.move(to: CGPoint(x: x, y: maxY))
            context.addLine(to: CGPoint(x: x + height, y: minY))
            x += spacing
            count += 1
        }
        context.strokePath()
        context.restoreGState()
    }

    private func drawLabel(_ label: MapLabel, context: CGContext) {
        let base: CGFloat = 40
        let scale = CGFloat(label.size) / base
        let font: UIFont
        if label.isCountry {
            let f = UIFont.systemFont(ofSize: base, weight: .bold)
            font = f.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: base) } ?? f
        } else {
            font = UIFont.italicSystemFont(ofSize: base)
        }
        let textColor: UIColor
        if label.isCountry {
            textColor = label.highlighted ? UIColor(Theme.amber) : UIColor.white.withAlphaComponent(0.92)
        } else {
            textColor = label.highlighted ? UIColor(Theme.amber) : UIColor.white.withAlphaComponent(0.7)
        }
        let kern: CGFloat = label.isCountry ? 2.5 : 0.5
        let outline: [NSAttributedString.Key: Any] = [
            .font: font, .kern: kern,
            .strokeColor: UIColor.black.withAlphaComponent(label.isCountry ? 0.75 : 0.6),
            .strokeWidth: 9.0, .foregroundColor: UIColor.clear
        ]
        let fill: [NSAttributedString.Key: Any] = [.font: font, .kern: kern, .foregroundColor: textColor]
        let text = label.text as NSString
        let size = text.size(withAttributes: fill)
        context.saveGState()
        context.translateBy(x: CGFloat(label.x), y: CGFloat(label.y))
        context.scaleBy(x: scale, y: scale)
        let origin = CGPoint(x: -size.width / 2, y: -size.height / 2)
        text.draw(at: origin, withAttributes: outline)
        text.draw(at: origin, withAttributes: fill)
        context.restoreGState()
    }
}

// MARK: - Coordinateur

final class MapCoordinator: NSObject, MKMapViewDelegate {
    let overlay = ProvinceOverlay()
    weak var mapView: MKMapView?
    var renderer: ProvinceRenderer?
    var onTap: ((GeoPoint) -> Void)?
    var satellite = false
    var configured = false
    var lastFocusID = -1
    private var lastSnapshot: MapSnapshot?

    func apply(_ snapshot: MapSnapshot) {
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        renderer?.update(snapshot)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let map = mapView, gesture.state == .ended else { return }
        let point = gesture.location(in: map)
        let coordinate = map.convert(point, toCoordinateFrom: map)
        onTap?(GeoPoint(lat: coordinate.latitude, lon: coordinate.longitude))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? ProvinceOverlay {
            let r = ProvinceRenderer(overlay: overlay)
            r.fillAlpha = satellite ? 0.55 : 1.0
            if let snapshot = lastSnapshot { r.update(snapshot) }
            renderer = r
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
