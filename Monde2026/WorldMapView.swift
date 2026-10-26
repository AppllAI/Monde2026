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

    var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

struct ProvinceFill: Equatable {
    var color: RGBA
    var stripes: RGBA?          // hachures (territoire occupé ou rebelle)
}

enum BorderKind: UInt8 {
    case hidden, region, country, player, selected, front, hot   // hot : front où l'on se bat
}

struct MapLabel: Equatable, Identifiable {
    let id: String
    let text: String
    let x: Double              // coordonnées MapKit
    let y: Double
    let size: Double           // taille de police en points MapKit
    let isCountry: Bool
    let highlighted: Bool
    var angle: Double = 0      // orientation (radians) : le nom suit l'allongement du pays
    var span: Double = 0       // longueur sur laquelle s'étale le nom (points MapKit)
    var bend: Double = 0       // courbure (fraction de la longueur)
}

struct PlanLine: Equatable, Identifiable {
    let id: String
    let from: GeoPoint
    let to: GeoPoint
}

/// Pion d'armée sur la carte.
struct ArmyMarker: Equatable, Identifiable {
    let id: Int
    let x: Double
    let y: Double
    let slot: Int              // décalage quand plusieurs armées sont dans la même région
    let text: String
    let flag: String
    let color: RGBA
    let isPlayer: Bool
    let selected: Bool
    let engaged: Bool
    var mainType: DivisionType = .infantry
    var mix: [Double] = []          // part de chaque type de division (ordre de DivisionType.allCases)
    var training = false
}

/// Fort ou base sur la carte.
struct StructureMarker: Equatable {
    let x: Double
    let y: Double
    let fort: Int
    let base: Bool
    let building: Bool
    var industry: Int = 0
}

/// Trajet d'une armée (points MapKit).
struct ArmyRoute: Equatable {
    let points: [CGPoint]
    let selected: Bool
    var hostileFrom: Int? = nil      // segment à partir duquel on entre en territoire ennemi
}

/// Bataille en cours sur la carte.
struct BattleMarker: Equatable, Identifiable {
    let id: Int                      // région disputée
    let x: Double
    let y: Double
    let balance: Double              // part de l'attaquant
    let attackerColor: RGBA
    let defenderColor: RGBA
    let side: Int                    // 1 le joueur attaque, -1 il défend, 0 non concerné
    var progress: Double = 0         // avancée de la prise
    var fronts: [CGPoint] = []       // d'où partent les attaques
}

/// Taille des pions : de près, taille normale ; vue du monde, environ moitié plus petits.
enum MarkerScale {
    static func factor(_ mapPointsPerScreenPoint: Double) -> CGFloat {
        let t = (log2(150_000) - log2(max(1, mapPointsPerScreenPoint))) / 3
        return CGFloat(min(1, max(0.42, 0.42 + 0.58 * t)))
    }
}

/// Ce que l'on a touché sur la carte.
enum MapTap {
    case point(GeoPoint)
    case army(Int)
    case battle(Int)
}

struct MapSnapshot: Equatable {
    var fills: [ProvinceFill]
    var borders: [BorderKind]
    var labels: [MapLabel]
    var plans: [PlanLine]
    var selectedProvince: Int?
    var armies: [ArmyMarker] = []
    var routes: [ArmyRoute] = []
    var battles: [BattleMarker] = []
    var structures: [StructureMarker] = []
    var highlight: Set<Int> = []        // régions où l'on peut construire
    var bombed: [CGPoint] = []          // régions sous les bombes

    static let empty = MapSnapshot(fills: [], borders: [], labels: [], plans: [], selectedProvince: nil)
}

enum MapSnapshotBuilder {

    static func build(_ sim: Simulation, mode: MapMode, selected: CountryID?, selectedProvince: Int?,
                      selectedArmy: Int? = nil, group: Set<Int> = [], highlight: Set<Int> = []) -> MapSnapshot {
        let provinces = ProvinceMap.all
        guard !provinces.isEmpty else { return .empty }
        let owners = sim.provinceOwners()
        let player = sim.state.playerID

        var colorCache: [CountryID: UIColor] = [:]
        func color(_ id: CountryID) -> UIColor {
            if let cached = colorCache[id] { return cached }
            let c = countryColor(id, sim: sim, mode: mode, focus: selected ?? player)
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
            case .occupied where sim.state.proxyConquests[p.id] != nil && sim.state.proxyConquests[p.id] == player:
                // Prise par nos troupes pour un autre pays : rayée de bleu (on sait que c'est nous).
                let holder = info.owner ?? p.country
                fills.append(ProvinceFill(color: RGBA(color(holder)), stripes: RGBA(allyBlue, alpha: 0.95)))
            case .occupied:
                // Territoire occupé : la couleur de l'occupant, plus claire, rayée de celle du pays d'origine.
                let holder = info.owner ?? p.country
                fills.append(ProvinceFill(color: RGBA(color(holder).lighter(0.18)),
                                          stripes: RGBA(color(p.country), alpha: 0.6)))
            case .core where mode == .terrain, .annexed where mode == .terrain:
                let t = TerrainMap.terrain(p.id).rgb
                fills.append(ProvinceFill(color: RGBA(UIColor(red: t.0, green: t.1, blue: t.2, alpha: 1)), stripes: nil))
            case .core where mode == .industry, .annexed where mode == .industry, .occupied where mode == .industry:
                let n = Double(sim.complexCount(at: p.id))
                let base = color(info.owner ?? p.country).darker(0.55)
                let lit = UIColor(red: 0.42, green: 0.80, blue: 0.95, alpha: 1)
                fills.append(ProvinceFill(color: RGBA(n == 0 ? base : UIColor(Theme.blend(Color(uiColor: base), Color(uiColor: lit), min(1, 0.25 + n / 6)))),
                                          stripes: nil))
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
                // Front actif (bataille d'un côté ou de l'autre) : ligne plus épaisse et plus vive.
                let hot = sim.state.battles[border.a] != nil || sim.state.battles[border.b] != nil
                borders.append(hot ? .hot : .front)
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
            var size = min(byArea, byWidth) * pointsPerKm
            // Allongement du territoire (analyse des axes principaux) : le nom suit le pays, légèrement courbé.
            var sxx = 0.0, syy = 0.0, sxy = 0.0
            for id in best {
                let p = provinces[id].labelPoint, w = provinces[id].weight
                let b = provinces[id].bounds
                sxx += w * ((p.x - x) * (p.x - x) + b.size.width * b.size.width / 12)
                syy += w * ((p.y - y) * (p.y - y) + b.size.height * b.size.height / 12)
                sxy += w * (p.x - x) * (p.y - y)
            }
            sxx /= bestArea; syy /= bestArea; sxy /= bestArea
            var angle = 0.5 * atan2(2 * sxy, sxx - syy)
            let tr = sxx + syy, det = sxx * syy - sxy * sxy
            let gap = max(0, tr * tr / 4 - det).squareRoot()
            let major = (tr / 2 + gap).squareRoot(), minor = max(1, (tr / 2 - gap)).squareRoot()
            var span = 0.0
            if major / minor > 1.25 && best.count > 1 {
                // On garde un sens de lecture confortable.
                angle = max(-0.9, min(0.9, angle))
                span = major * 3.0
                let n = Double(max(3, name.count))
                // Taille pour que le nom, espacé, couvre environ les trois quarts de la longueur.
                let fit = span * 0.78 / (0.62 * n + 0.3 * (n - 1))
                size = max(size, min(fit, minor * 1.6, size * 2.2))
            } else {
                angle = 0
            }
            labels.append(MapLabel(id: "c-" + owner, text: name, x: x, y: y, size: size, isCountry: true,
                                   highlighted: owner == player || owner == selected,
                                   angle: angle, span: span, bend: span > 0 ? 0.07 : 0))
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
        var structures: [StructureMarker] = []
        let building = Set(sim.state.constructions.map { $0.province })
        let industrial = Set(sim.state.complexes.keys.filter { sim.complexCount(at: $0) > 0 })
        for p in Set(sim.state.forts.keys).union(sim.state.bases).union(building).union(industrial).sorted() {
            let lp = provinces[p].labelPoint
            let isFortJob = sim.construction(at: p).map { $0.kind == .fort } ?? false
            structures.append(StructureMarker(x: lp.x, y: lp.y, fort: sim.fortLevel(p), base: sim.state.bases.contains(p),
                                              building: isFortJob, industry: sim.complexCount(at: p)))
        }
        var snap = MapSnapshot(fills: fills, borders: borders, labels: labels, plans: plans,
                               selectedProvince: selectedProvince)
        snap.structures = structures
        snap.highlight = highlight
        return snap
    }

    static let focusGreen = UIColor(red: 0.30, green: 0.80, blue: 0.45, alpha: 1)
    static let allyBlue = UIColor(red: 0.33, green: 0.56, blue: 0.96, alpha: 1)

    static func countryColor(_ id: CountryID, sim: Simulation, mode: MapMode, focus: CountryID? = nil) -> UIColor {
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
            // Le pays regardé s'allume en vert ; ses ennemis en rouge, ses alliés en bleu, le reste en gris.
            guard let f = focus ?? player else { return Theme.neutralLand }
            if id == f { return focusGreen }
            if sim.enemies(of: f).contains(id) { return UIColor(Theme.coral) }
            if sim.hasTreaty(.alliance, f, id) { return allyBlue }
            if let fac = sim.faction(of: f), sim.faction(of: id)?.id == fac.id { return allyBlue.lighter(0.2) }
            if sim.hasTreaty(.guarantee, f, id) || sim.hasTreaty(.guarantee, id, f) { return allyBlue.lighter(0.45) }
            let r = sim.relation(f, id)
            let grey = UIColor(white: 0.42 + 0.18 * CGFloat(max(-1, min(1, r / 100))), alpha: 1)
            if r < -50 { return UIColor(red: 0.45, green: 0.30, blue: 0.30, alpha: 1) }
            return grey
        case .economy:
            return UIColor(Theme.growthColor(sim.state.countries[id]?.growth ?? 0))
        case .military:
            if sim.isAtWar(id) { return UIColor(Theme.coral) }
            return UIColor(Theme.blend(Theme.steel, Theme.amber, min(1, sim.militaryPower(id) / 6000)))
        case .terrain, .industry:
            return Theme.politicalColor(id)
        case .influence:
            // Chaque pays prend la couleur de la grande puissance qui y pèse le plus.
            guard let leader = sim.influenceLeader(of: id) else { return Theme.neutralLand }
            return leader == id ? Theme.politicalColor(id).lighter(0.1) : Theme.politicalColor(leader).darker(0.18)
        case .trade:
            guard let p = player else { return Theme.neutralLand }
            if id == p { return UIColor(Theme.amber) }
            if sim.enemies(of: p).contains(id) { return UIColor(Theme.coral).darker(0.35) }
            if sim.hasTreaty(.sanctions, p, id) || sim.hasTreaty(.sanctions, id, p) { return UIColor(Theme.coral) }
            if sim.hasTreaty(.tradePact, p, id) { return UIColor(Theme.teal) }
            let r = sim.relation(p, id)
            return UIColor(Theme.blend(Theme.steel.opacity(0.6), Theme.sky, max(0, r) / 100)).darker(0.25)
        case .conflicts:
            guard sim.isAtWar(id) else { return Theme.neutralLand.darker(0.35) }
            if let p = player {
                if id == p || sim.allies(of: p).contains(id) && !sim.enemies(of: id).isDisjoint(with: sim.enemies(of: p)) {
                    return UIColor(Theme.teal)
                }
                if sim.enemies(of: p).contains(id) { return UIColor(Theme.coral) }
            }
            return UIColor(red: 0.93, green: 0.55, blue: 0.22, alpha: 1)
        case .allies:
            guard let p = focus ?? player else { return Theme.neutralLand }
            if id == p { return UIColor(Theme.amber) }
            if sim.enemies(of: p).contains(id) { return UIColor(Theme.coral) }
            if sim.hasTreaty(.alliance, p, id) { return UIColor(Theme.teal) }
            if let mine = sim.faction(of: p), sim.faction(of: id)?.id == mine.id { return UIColor(Theme.teal).lighter(0.25) }
            if sim.hasTreaty(.guarantee, p, id) || sim.hasTreaty(.guarantee, id, p) { return UIColor(Theme.sky) }
            if sim.hasTreaty(.nonAggression, p, id) { return UIColor(Theme.steel) }
            return Theme.neutralLand.darker(0.3)
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
    var units: UnitsSnapshot = .empty
    var unitAnimation: TimeInterval = 0.3
    let satellite: Bool
    let focus: MapFocus?
    let onTap: (MapTap) -> Void
    var onDrop: (Int, Int, Int?) -> Void = { _, _, _ in }
    var onPreview: (Int, Int) -> (path: [Int], days: Int, attack: Bool)? = { _, _ in nil }
    var onStroke: ([Int], [GeoPoint]) -> Void = { _, _ in }

    static func == (lhs: WorldMapView, rhs: WorldMapView) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.units == rhs.units && lhs.satellite == rhs.satellite && lhs.focus == rhs.focus
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
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(MapCoordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        context.coordinator.mapView = map
        // La couche des unités, au-dessus de la carte.
        let layer = UnitLayerView(frame: map.bounds)
        layer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.map = map
        map.addSubview(layer)
        context.coordinator.unitLayer = layer
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        if coordinator.satellite != satellite || coordinator.configured == false {
            coordinator.satellite = satellite
            coordinator.configured = true
            // Fond satellite sans aucun nom : en mode normal, la carte du jeu le recouvre entièrement
            // (océans compris), comme dans un jeu de grande stratégie.
            map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
            // On remplace la couche des régions (le remplacement du fond se décide à sa création).
            map.removeOverlay(coordinator.overlay)
            coordinator.overlay = ProvinceOverlay(replaces: !satellite)
            map.addOverlay(coordinator.overlay, level: .aboveLabels)
        }
        if let focus = focus, focus.id != coordinator.lastFocusID {
            coordinator.lastFocusID = focus.id
            map.setVisibleMapRect(focus.rect, edgePadding: UIEdgeInsets(top: 180, left: 40, bottom: 220, right: 40),
                                  animated: true)
        }
        coordinator.apply(snapshot)
        coordinator.unitLayer?.onDrop = onDrop
        coordinator.unitLayer?.onPreview = onPreview
        coordinator.unitLayer?.onStroke = onStroke
        coordinator.unitLayer?.apply(units, animated: unitAnimation)
    }
}

// MARK: - Couche unique de toutes les régions

final class ProvinceOverlay: NSObject, MKOverlay {
    /// Sans fond satellite, la carte du jeu remplace entièrement celle d'Apple : MapKit ne télécharge
    /// ni ne dessine plus rien dessous (gros gain de fluidité).
    let replaces: Bool
    init(replaces: Bool = true) { self.replaces = replaces }
    var canReplaceMapContent: Bool { replaces }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: 0, longitude: 0) }
    var boundingMapRect: MKMapRect { .world }
}

final class ProvinceRenderer: MKOverlayRenderer {
    private let lock = NSLock()
    private var snapshot = MapSnapshot.empty
    var fillAlpha: CGFloat = 1.0
    var drawsOcean = true
    private static let coast = UIColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 0.9)

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
        let level = MapDetail.level(forPixel: Double(px))
        func shape(_ i: Int) -> CGPath { MapDetail.provincePath(i, level: level) }
        let visible = provinces.indices.filter { provinces[$0].bounds.intersects(area) }

        if drawsOcean {
            // Mer : dégradé selon la latitude (plus sombre vers les pôles), continu d'une tuile à l'autre.
            context.saveGState()
            context.clip(to: rect(for: mapRect))
            let world = MKMapSize.world.height
            context.drawLinearGradient(MapArt.oceanGradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: world), options: [])
            context.restoreGState()
            // Eaux peu profondes : un halo clair le long des côtes.
            context.setLineJoin(.round)
            for (width, alpha) in [(22.0, 0.06), (12.0, 0.09), (5.0, 0.14)] as [(CGFloat, CGFloat)] {
                context.setStrokeColor(UIColor(red: 0.40, green: 0.68, blue: 0.84, alpha: alpha).cgColor)
                context.setLineWidth(width * px)
                for i in visible where provinces[i].coastal { context.addPath(shape(i)) }
                context.strokePath()
            }
        }
        context.setAlpha(fillAlpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        // 1. Remplissage des régions
        for i in visible {
            let fill = snap.fills[i]
            context.addPath(shape(i))
            context.setFillColor(fill.color.cgColor)
            context.fillPath()
        }
        // 1b. Relief : motifs discrets selon le terrain (montagnes, collines, forêts, déserts…), de près.
        if zoomScale > 1.0 / 20_000 && drawsOcean {
            let tile = MapArt.patternSize * px
            for i in visible {
                guard let image = MapArt.pattern(TerrainMap.terrain(i)) else { continue }
                let b = provinces[i].bounds.intersection(area)
                guard !b.isNull, b.size.width > 0 else { continue }
                context.saveGState()
                context.addPath(shape(i))
                context.clip()
                // Motif calé sur une grille fixe : il se raccorde parfaitement d'une tuile à l'autre.
                let x0 = floor(b.minX / Double(tile)) * Double(tile), y0 = floor(b.minY / Double(tile)) * Double(tile)
                context.draw(image, in: CGRect(x: x0, y: y0, width: Double(tile), height: Double(tile)), byTiling: true)
                context.restoreGState()
            }
        }
        // 1c. Hachures des territoires occupés
        for i in visible {
            if let stripes = snap.fills[i].stripes {
                drawStripes(in: i, path: shape(i), color: stripes, spacing: 7 * px, width: 2.2 * px, rect: area, context: context)
            }
        }
        context.endTransparencyLayer()
        context.setAlpha(1)

        // Côtes : un trait sombre autour de chaque région (les frontières sont redessinées par-dessus).
        context.setStrokeColor(ProvinceRenderer.coast.cgColor)
        context.setLineWidth(0.9 * px)
        context.setLineJoin(.round)
        for i in visible where provinces[i].coastal { context.addPath(shape(i)) }
        context.strokePath()

        // 2. Frontières
        context.setLineJoin(.round)
        context.setLineCap(.round)
        let borders = ProvinceMap.borders
        let kinds = snap.borders
        guard kinds.count == borders.count else { return }
        let visibleBorders = borders.indices.filter { borders[$0].bounds.intersects(area) }
        func line(_ i: Int) -> CGPath { MapDetail.borderPath(i, level: level) }
        // Passe 1 : frontières de régions (fines), seulement de près.
        if detailed {
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.20).cgColor)
            context.setLineWidth(0.6 * px)
            for i in visibleBorders where kinds[i] == .region { context.addPath(line(i)) }
            context.strokePath()
        }
        // Grands fleuves : un filet bleu le long des frontières qu'ils dessinent.
        if zoomScale > 1.0 / 12_000 {
            context.setStrokeColor(UIColor(red: 0.45, green: 0.72, blue: 0.92, alpha: 0.85).cgColor)
            context.setLineWidth(1.6 * px)
            var any = false
            for i in visibleBorders where TerrainMap.river(borders[i].a, borders[i].b) {
                context.addPath(line(i))
                any = true
            }
            if any { context.strokePath() }
        }
        // Passe 2 : frontières de pays : une bande sombre large et douce, puis un trait net et clair.
        let countryKinds: Set<BorderKind> = [.country, .player, .selected]
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(6 * px)
        for i in visibleBorders where countryKinds.contains(kinds[i]) { context.addPath(line(i)) }
        context.strokePath()
        context.setStrokeColor(UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 0.9).cgColor)
        context.setLineWidth(1.8 * px)
        for i in visibleBorders where countryKinds.contains(kinds[i]) { context.addPath(line(i)) }
        context.strokePath()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(0.6 * px)
        for i in visibleBorders where countryKinds.contains(kinds[i]) { context.addPath(line(i)) }
        context.strokePath()
        // Passe 3 : frontières du joueur et du pays sélectionné.
        stroke(kinds, .player, among: visibleBorders, level: level, color: UIColor(Theme.amber).withAlphaComponent(0.9), width: 2 * px, context: context)
        stroke(kinds, .selected, among: visibleBorders, level: level, color: UIColor.white.withAlphaComponent(0.95), width: 2.2 * px, context: context)
        // Passe 4 : lignes de front (halo + trait).
        stroke(kinds, .front, among: visibleBorders, level: level, color: UIColor(Theme.coral).withAlphaComponent(0.30), width: 9 * px, context: context)
        stroke(kinds, .front, among: visibleBorders, level: level, color: UIColor(Theme.coral), width: 2.6 * px, context: context)
        // Fronts où l'on se bat : halo large, trait épais, cœur clair.
        stroke(kinds, .hot, among: visibleBorders, level: level, color: UIColor(red: 1, green: 0.35, blue: 0.2, alpha: 0.28), width: 18 * px, context: context)
        stroke(kinds, .hot, among: visibleBorders, level: level, color: UIColor(Theme.coral), width: 4.5 * px, context: context)
        stroke(kinds, .hot, among: visibleBorders, level: level, color: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 0.9), width: 1.2 * px, context: context)

        // 4. Troupes massées : flèches pointillées
        if !snap.plans.isEmpty {
            context.setStrokeColor(UIColor(Theme.amber).cgColor)
            context.setLineWidth(2.5 * px)
            context.setLineDash(phase: 0, lengths: [7 * px, 6 * px])
            for plan in snap.plans {
                let a = MKMapPoint(CLLocationCoordinate2D(latitude: plan.from.lat, longitude: plan.from.lon))
                let b = MKMapPoint(CLLocationCoordinate2D(latitude: plan.to.lat, longitude: plan.to.lon))
                context.move(to: CGPoint(x: a.x, y: a.y))
                context.addLine(to: CGPoint(x: b.x, y: b.y))
            }
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        }

        // 5. Grain discret sur toute la carte (aspect « carte imprimée »).
        if drawsOcean {
            let tile = MapArt.grainSize * px
            let x0 = floor(mapRect.minX / Double(tile)) * Double(tile), y0 = floor(mapRect.minY / Double(tile)) * Double(tile)
            context.saveGState()
            context.clip(to: rect(for: mapRect))
            context.draw(MapArt.grain, in: CGRect(x: x0, y: y0, width: Double(tile), height: Double(tile)), byTiling: true)
            context.restoreGState()
        }

        // 6. Noms
        UIGraphicsPushContext(context)
        for label in snap.labels {
            let screen = label.size * zoomScale
            if label.isCountry {
                guard screen >= 7, screen <= 70 || label.highlighted else { continue }
            } else {
                guard screen >= 8.5, screen <= 34 else { continue }
            }
            let halfWidth = max(label.span / 2, label.size * 0.5 * Double(label.text.count)) + label.size
            let halfHeight = label.angle == 0 ? label.size : halfWidth
            let rect = MKMapRect(x: label.x - halfWidth, y: label.y - halfHeight, width: halfWidth * 2, height: halfHeight * 2)
            guard rect.intersects(mapRect) else { continue }
            drawLabel(label, context: context)
        }
        // 7. Forts, bases et usines (de près, taille fixe à l'écran)
        let unit = px * 2
        let u = unit * MarkerScale.factor(Double(unit))
        if zoomScale > 1.0 / 16384 {
            for st in snap.structures {
                let c = CGPoint(x: CGFloat(st.x) - 40 * u, y: CGFloat(st.y) + 22 * u)
                guard MKMapRect(x: Double(c.x) - 40, y: Double(c.y) - 40, width: 80, height: 80)
                    .insetBy(dx: -Double(30 * u), dy: -Double(30 * u)).intersects(mapRect) else { continue }
                drawStructure(st, at: c, px: u, context: context)
            }
        }
        UIGraphicsPopContext()
    }

    private func stroke(_ kinds: [BorderKind], _ kind: BorderKind, among ids: [Int], level: Int?, color: UIColor,
                        width: CGFloat, context: CGContext) {
        var any = false
        for i in ids where kinds[i] == kind {
            context.addPath(MapDetail.borderPath(i, level: level))
            any = true
        }
        guard any else { return }
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.strokePath()
    }

    private func drawStripes(in id: Int, path: CGPath, color: RGBA, spacing: CGFloat, width: CGFloat,
                             rect: MKMapRect, context: CGContext) {
        let box = ProvinceMap.all[id].bounds.intersection(rect)
        guard !box.isNull, box.size.width > 0 else { return }
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        // Hachures calées sur une grille fixe (elles se raccordent d'une tuile à l'autre).
        let minX = CGFloat(box.minX), maxX = CGFloat(box.maxX), minY = CGFloat(box.minY), maxY = CGFloat(box.maxY)
        let height = maxY - minY
        var x = floor((minX - height + maxY) / spacing) * spacing - maxY
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

    private func drawMarker(_ m: ArmyMarker, in box: CGRect, px: CGFloat, context: CGContext) {
        let path = UIBezierPath(roundedRect: box, cornerRadius: 5 * px).cgPath
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1.5 * px), blur: 4 * px, color: UIColor.black.withAlphaComponent(0.6).cgColor)
        context.addPath(path)
        context.setFillColor(UIColor(red: 0.06, green: 0.09, blue: 0.13, alpha: 0.94).cgColor)
        context.fillPath()
        context.restoreGState()
        // Symbole d'unité (style OTAN) dans la couleur du pays
        let sym = CGRect(x: box.minX + 4 * px, y: box.minY + 4 * px, width: 25 * px, height: 15 * px)
        context.setFillColor(m.color.cgColor)
        context.fill(sym)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.3 * px)
        context.stroke(sym)
        context.saveGState()
        context.clip(to: sym)
        for p in UnitGlyph.paths(m.mainType, in: sym) {
            context.addPath(p.cgPath)
        }
        context.setLineWidth(1.4 * px)
        context.strokePath()
        context.restoreGState()
        // Mélange des troupes : petite barre colorée en bas
        if m.mix.count == DivisionType.allCases.count {
            let colors: [UIColor] = [UIColor(white: 0.85, alpha: 1), UIColor(Theme.sky), UIColor(Theme.amber),
                                     UIColor(Theme.teal), UIColor(red: 0.3, green: 0.5, blue: 0.95, alpha: 1)]
            var x = box.minX + 4 * px
            let width = box.width - 8 * px
            for (k, share) in m.mix.enumerated() where share > 0 {
                let w = width * CGFloat(share)
                context.setFillColor(colors[k].cgColor)
                context.fill(CGRect(x: x, y: box.maxY - 4.5 * px, width: w, height: 2.5 * px))
                x += w
            }
        }
        // Contour
        let stroke: UIColor = m.selected ? UIColor(Theme.amber) : (m.engaged ? UIColor(Theme.coral) : UIColor.white.withAlphaComponent(m.isPlayer ? 0.75 : 0.35))
        context.addPath(path)
        context.setStrokeColor(stroke.cgColor)
        context.setLineWidth((m.selected ? 2.6 : 1.2) * px)
        context.strokePath()
        // Nombre de divisions
        let text = m.text as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .heavy),
            .foregroundColor: UIColor.white
        ]
        let size = text.size(withAttributes: attrs)
        context.saveGState()
        context.translateBy(x: box.minX + 46 * px, y: box.midY - 1 * px)
        context.scaleBy(x: px, y: px)
        text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
        context.restoreGState()
        // Entraînement : petite étoile
        if m.training {
            context.setFillColor(UIColor(Theme.amber).cgColor)
            context.fillEllipse(in: CGRect(x: box.maxX - 6 * px, y: box.minY - 3 * px, width: 9 * px, height: 9 * px))
        }
    }

    private func drawAttackArrow(from a: CGPoint, to b: CGPoint, color: RGBA, px: CGFloat, context: CGContext) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = hypot(dx, dy)
        guard len > 1 else { return }
        let ux = dx / len, uy = dy / len
        let start = CGPoint(x: a.x + ux * len * 0.18, y: a.y + uy * len * 0.18)
        let tip = CGPoint(x: a.x + ux * len * 0.82, y: a.y + uy * len * 0.82)
        let head = min(18 * px, len * 0.3)
        let base = CGPoint(x: tip.x - ux * head, y: tip.y - uy * head)
        let nx = -uy, ny = ux
        context.saveGState()
        context.setLineCap(.round)
        // Contour sombre puis couleur de l'attaquant
        for (w, c) in [(9 * px, UIColor.black.withAlphaComponent(0.55)), (5.5 * px, color.uiColor)] {
            context.setStrokeColor(c.cgColor)
            context.setLineWidth(w)
            context.move(to: start)
            context.addLine(to: base)
            context.strokePath()
        }
        context.setFillColor(color.uiColor.cgColor)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(1.5 * px)
        context.move(to: tip)
        context.addLine(to: CGPoint(x: base.x + nx * head * 0.7, y: base.y + ny * head * 0.7))
        context.addLine(to: CGPoint(x: base.x - nx * head * 0.7, y: base.y - ny * head * 0.7))
        context.closePath()
        context.drawPath(using: .fillStroke)
        context.restoreGState()
    }

    private func drawStructure(_ st: StructureMarker, at c: CGPoint, px: CGFloat, context: CGContext) {
        var x = c.x
        if st.fort > 0 || st.building {
            let r = CGRect(x: x - 9 * px, y: c.y - 9 * px, width: 18 * px, height: 18 * px)
            context.setFillColor(UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 0.92).cgColor)
            context.fill(r)
            // Créneaux
            context.setFillColor(UIColor(white: 0.85, alpha: 1).cgColor)
            let w = r.width / 5
            for k in [0, 2, 4] {
                context.fill(CGRect(x: r.minX + CGFloat(k) * w, y: r.minY + 2 * px, width: w, height: 4 * px))
            }
            context.fill(CGRect(x: r.minX, y: r.minY + 6 * px, width: r.width, height: r.height - 8 * px))
            let text = (st.fort > 0 ? "\(st.fort)" : "…") as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .heavy),
                                                        .foregroundColor: UIColor.black]
            let size = text.size(withAttributes: attrs)
            context.saveGState()
            context.translateBy(x: r.midX, y: r.midY + 2.5 * px)
            context.scaleBy(x: px, y: px)
            text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
            context.restoreGState()
            x += 21 * px
        }
        if st.industry > 0 {
            let r = CGRect(x: x - 9 * px, y: c.y - 9 * px, width: 18 * px, height: 18 * px)
            context.setFillColor(UIColor(red: 0.42, green: 0.66, blue: 0.95, alpha: 1).cgColor)
            context.fill(r)
            // Toit en dents de scie
            context.setFillColor(UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1).cgColor)
            context.move(to: CGPoint(x: r.minX + 2 * px, y: r.maxY - 3 * px))
            context.addLine(to: CGPoint(x: r.minX + 2 * px, y: r.minY + 9 * px))
            context.addLine(to: CGPoint(x: r.minX + 7 * px, y: r.minY + 5 * px))
            context.addLine(to: CGPoint(x: r.minX + 7 * px, y: r.minY + 9 * px))
            context.addLine(to: CGPoint(x: r.minX + 12 * px, y: r.minY + 5 * px))
            context.addLine(to: CGPoint(x: r.minX + 12 * px, y: r.minY + 9 * px))
            context.addLine(to: CGPoint(x: r.maxX - 2 * px, y: r.minY + 5 * px))
            context.addLine(to: CGPoint(x: r.maxX - 2 * px, y: r.maxY - 3 * px))
            context.closePath()
            context.fillPath()
            if st.industry > 1 {
                let text = "\(st.industry)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8, weight: .heavy),
                                                            .foregroundColor: UIColor.white]
                let size = text.size(withAttributes: attrs)
                context.saveGState()
                context.translateBy(x: r.midX, y: r.maxY - 6 * px)
                context.scaleBy(x: px, y: px)
                text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
                context.restoreGState()
            }
            x += 21 * px
        }
        if st.base {
            let r = CGRect(x: x - 9 * px, y: c.y - 9 * px, width: 18 * px, height: 18 * px)
            context.setFillColor(UIColor(Theme.amber).cgColor)
            context.fill(r)
            let text = "★" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .bold),
                                                        .foregroundColor: UIColor.black]
            let size = text.size(withAttributes: attrs)
            context.saveGState()
            context.translateBy(x: r.midX, y: r.midY)
            context.scaleBy(x: px, y: px)
            text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
            context.restoreGState()
        }
    }

    private func drawBattle(_ b: BattleMarker, center c: CGPoint, radius r: CGFloat, px: CGFloat, context: CGContext) {
        // Badge : ⚔︎ + avancée de la prise, avec une barre de progression.
        let box = CGRect(x: c.x - 26 * px, y: c.y - 11 * px, width: 52 * px, height: 22 * px)
        let path = UIBezierPath(roundedRect: box, cornerRadius: 11 * px).cgPath
        let tint: UIColor
        if b.side == 0 { tint = UIColor(white: 0.7, alpha: 1) } else {
            let winning = b.side == 1 ? b.balance > 0.5 : b.balance < 0.5
            tint = winning ? UIColor(Theme.teal) : UIColor(Theme.coral)
        }
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1.5 * px), blur: 5 * px, color: UIColor.black.withAlphaComponent(0.7).cgColor)
        context.addPath(path)
        context.setFillColor(UIColor(red: 0.10, green: 0.05, blue: 0.05, alpha: 0.95).cgColor)
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setFillColor(b.attackerColor.uiColor.withAlphaComponent(0.55).cgColor)
        context.fill(CGRect(x: box.minX, y: box.minY, width: box.width * CGFloat(b.progress), height: box.height))
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(tint.cgColor)
        context.setLineWidth(1.8 * px)
        context.strokePath()
        let text = "⚔︎ \(Int(b.progress * 100))%" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .heavy),
                                                    .foregroundColor: UIColor.white]
        let size = text.size(withAttributes: attrs)
        context.saveGState()
        context.translateBy(x: c.x, y: c.y)
        context.scaleBy(x: px, y: px)
        text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
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
            textColor = label.highlighted ? UIColor(Theme.amber) : UIColor.white.withAlphaComponent(0.82)
        }
        let kern: CGFloat = label.isCountry ? 2.5 : 0.5
        let outline: [NSAttributedString.Key: Any] = [
            .font: font, .kern: kern,
            .strokeColor: UIColor.black.withAlphaComponent(label.isCountry ? 0.75 : 0.35),
            .strokeWidth: label.isCountry ? 9.0 : 4.0, .foregroundColor: UIColor.clear
        ]
        let fill: [NSAttributedString.Key: Any] = [.font: font, .kern: kern, .foregroundColor: textColor]
        if label.isCountry && (label.span > 0 || label.text.count > 2) {
            drawCurved(label, font: font, color: textColor, context: context)
            return
        }
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

extension ProvinceRenderer {
    /// Nom de pays espacé, tourné selon l'allongement du territoire et légèrement courbé (lettre par lettre).
    func drawCurved(_ label: MapLabel, font: UIFont, color: UIColor, context: CGContext) {
        let base = font.pointSize
        let letters = Array(label.text.uppercased())
        let fill: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let outline: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.clear,
                                                      .strokeColor: UIColor.black.withAlphaComponent(0.55), .strokeWidth: 7.0]
        let widths = letters.map { (String($0) as NSString).size(withAttributes: fill).width }
        let tracking = base * 0.30
        let natural = widths.reduce(0, +) + tracking * CGFloat(max(0, letters.count - 1))
        // Taille : celle prévue, sans dépasser la longueur du pays.
        let wanted = label.span > 0 ? label.span * 0.8 : label.size * 0.62 * Double(max(3, letters.count)) * 1.15
        let scale = min(CGFloat(label.size) / base, CGFloat(wanted) / max(1, natural))
        let width = natural
        let bend = CGFloat(label.bend) * width
        context.saveGState()
        context.translateBy(x: CGFloat(label.x), y: CGFloat(label.y))
        context.rotate(by: CGFloat(label.angle))
        context.scaleBy(x: scale, y: scale)
        context.setAlpha(label.highlighted ? 1 : 0.86)
        var x = -width / 2
        for (i, ch) in letters.enumerated() {
            let w = widths[i]
            let cx = x + w / 2
            let t = cx / max(1, width / 2)                     // -1 … 1
            let y = -bend * (1 - t * t)                          // arche douce
            let slope = 2 * bend * t / max(1, width / 2)         // pente de l'arche à cet endroit
            context.saveGState()
            context.translateBy(x: cx, y: y)
            context.rotate(by: atan(slope))
            let s = String(ch) as NSString
            let h = font.lineHeight
            let origin = CGPoint(x: -w / 2, y: -h / 2)
            s.draw(at: origin, withAttributes: outline)
            s.draw(at: origin, withAttributes: fill)
            context.restoreGState()
            x += w + tracking
        }
        context.restoreGState()
    }
}

// MARK: - Coordinateur

final class MapCoordinator: NSObject, MKMapViewDelegate {
    var overlay = ProvinceOverlay()
    weak var mapView: MKMapView?
    var renderer: ProvinceRenderer?
    var onTap: ((MapTap) -> Void)?
    var satellite = false
    var configured = false
    var lastFocusID = -1
    weak var unitLayer: UnitLayerView?
    private var lastSnapshot: MapSnapshot?

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        unitLayer?.relayout()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        unitLayer?.relayout()
    }

    func apply(_ snapshot: MapSnapshot) {
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        renderer?.update(snapshot)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let map = mapView, gesture.state == .ended else { return }
        let point = gesture.location(in: map)
        if let tap = unitLayer?.hit(point) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap?(tap)
            return
        }
        let coordinate = map.convert(point, toCoordinateFrom: map)
        onTap?(.point(GeoPoint(lat: coordinate.latitude, lon: coordinate.longitude)))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? ProvinceOverlay {
            let r = ProvinceRenderer(overlay: overlay)
            r.fillAlpha = satellite ? 0.55 : 1.0
            r.drawsOcean = !satellite
            if let snapshot = lastSnapshot { r.update(snapshot) }
            renderer = r
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
