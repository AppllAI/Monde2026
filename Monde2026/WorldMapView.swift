import SwiftUI
import MapKit
import UIKit

// =============================================================
//  WorldMapView.swift
//  La carte façon « grande stratégie » : ~530 régions coloriées
//  selon leur propriétaire, posées sur le relief d'Apple Plans,
//  noms de pays avec drapeaux, zones occupées et rebelles.
//
//  Toutes les régions sont dessinées dans UNE seule couche
//  (MKOverlayRenderer, dessin par tuiles) : c'est stable et
//  fluide, contrairement à des centaines de formes séparées.
// =============================================================

// MARK: - Image de la carte

struct ProvinceStyle: Equatable, Identifiable {
    let id: Int
    let fill: UIColor
    let stroke: UIColor
    let lineWidth: CGFloat
}

struct CountryLabel: Equatable, Identifiable {
    let id: CountryID
    let name: String
    let lat: Double
    let lon: Double
    let size: CGFloat
    let tier: Int            // 0 = toujours visible, 1 = vue moyenne, 2 = vue rapprochée
    let atWar: Bool
    let highlighted: Bool
}

struct PlanLine: Equatable, Identifiable {
    let id: String
    let from: GeoPoint
    let to: GeoPoint
}

struct MapSnapshot: Equatable {
    var provinces: [ProvinceStyle]
    var labels: [CountryLabel]
    var plans: [PlanLine]

    static let empty = MapSnapshot(provinces: [], labels: [], plans: [])
}

/// Contours des régions en coordonnées MapKit (calculés une seule fois).
enum ProvinceGeometry {
    struct Shape {
        let points: [MKMapPoint]
        let bounds: MKMapRect
    }

    static let shapes: [Shape] = ProvinceMap.all.map { province in
        // On « déplie » la longitude pour qu'une région à cheval sur la ligne de changement de date reste d'un seul tenant.
        var previous = province.center.lon
        var points: [MKMapPoint] = []
        for p in province.outline {
            var lon = p.lon
            while lon - previous > 180 { lon -= 360 }
            while lon - previous < -180 { lon += 360 }
            previous = lon
            let clampedLon = lon.clamped(-180, 180)
            points.append(MKMapPoint(CLLocationCoordinate2D(latitude: p.lat.clamped(-84, 84), longitude: clampedLon)))
        }
        var rect = MKMapRect.null
        for pt in points {
            rect = rect.union(MKMapRect(x: pt.x, y: pt.y, width: 0, height: 0))
        }
        return Shape(points: points, bounds: rect)
    }
}

enum MapSnapshotBuilder {

    static func build(_ sim: Simulation, mode: MapMode, selected: CountryID?, selectedProvince: Int?) -> MapSnapshot {
        let owners = sim.provinceOwners()
        let player = sim.state.playerID
        var colorCache: [CountryID: Color] = [:]
        func color(_ id: CountryID) -> Color {
            if let cached = colorCache[id] { return cached }
            let c = countryColor(id, sim: sim, mode: mode)
            colorCache[id] = c
            return c
        }

        var styles: [ProvinceStyle] = []
        styles.reserveCapacity(ProvinceMap.all.count)
        for p in ProvinceMap.all {
            let info = owners[p.id] ?? ProvinceOwner(owner: p.country, status: .core)
            let fill: Color
            var stroke = Theme.ink.opacity(0.6)
            var width: CGFloat = 0.6
            var opacity = 0.55
            if let owner = info.owner {
                fill = color(owner)
            } else {
                fill = Color(red: 0.35, green: 0.05, blue: 0.08)
                opacity = 0.7
            }
            switch info.status {
            case .occupied:
                stroke = Theme.coral
                width = 1.5
                opacity = 0.62
            case .rebel:
                stroke = Theme.coral.opacity(0.8)
                width = 1.2
            default:
                break
            }
            if let owner = info.owner, owner == selected || p.country == selected {
                stroke = Theme.paper
                width = 2
                opacity += 0.1
            }
            if p.id == selectedProvince {
                stroke = Theme.amber
                width = 3
            }
            if info.owner == player && player != nil {
                opacity += 0.05
            }
            styles.append(ProvinceStyle(id: p.id, fill: UIColor(fill.opacity(min(0.9, opacity))),
                                        stroke: UIColor(stroke), lineWidth: width))
        }

        var labels: [CountryLabel] = []
        for id in sim.countryIDs {
            guard let c = sim.state.countries[id], sim.lostFraction(id) < 0.95 else { continue }
            let g = Geo.info(id)
            let tier = c.area > 1500 ? 0 : (c.area > 250 ? 1 : 2)
            let size = CGFloat((10 + c.area.squareRoot() / 9).clamped(10, 26))
            labels.append(CountryLabel(id: id, name: c.name, lat: g.lat, lon: g.lon, size: size, tier: tier,
                                       atWar: sim.isAtWar(id), highlighted: id == player || id == selected))
        }

        var plans: [PlanLine] = []
        for plan in sim.state.warPlans {
            let a = Geo.info(plan.attacker), b = Geo.info(plan.target)
            plans.append(PlanLine(id: plan.attacker + ">" + plan.target,
                                  from: GeoPoint(lat: a.lat, lon: a.lon), to: GeoPoint(lat: b.lat, lon: b.lon)))
        }
        return MapSnapshot(provinces: styles, labels: labels, plans: plans)
    }

    static func countryColor(_ id: CountryID, sim: Simulation, mode: MapMode) -> Color {
        let player = sim.state.playerID
        switch mode {
        case .political:
            return id == player ? Theme.amber : Theme.countryColor(id)
        case .alliances:
            if let bloc = sim.faction(of: id) { return Theme.blocColor(bloc.id) }
            let allies = sim.allies(of: id)
            if allies.contains("USA") || sim.guarantors(of: id).contains("USA") { return Theme.blocColor("USA-ALLY") }
            if allies.contains("CHN") || allies.contains("RUS") || id == "CHN" { return Theme.blocColor("CHN-ALLY") }
            return Theme.blocColor(nil)
        case .relations:
            guard let p = player else { return Theme.steel }
            return id == p ? Theme.amber : Theme.relationColor(sim.relation(p, id))
        case .economy:
            return Theme.growthColor(sim.state.countries[id]?.growth ?? 0)
        case .military:
            if sim.isAtWar(id) { return Theme.coral }
            return Theme.blend(Theme.steel, Theme.amber, min(1, sim.militaryPower(id) / 6000))
        }
    }
}

// MARK: - Vue SwiftUI

struct WorldMapView: UIViewRepresentable, Equatable {
    let snapshot: MapSnapshot
    let satellite: Bool
    let onTap: (GeoPoint) -> Void

    static func == (lhs: WorldMapView, rhs: WorldMapView) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.satellite == rhs.satellite
    }

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.overrideUserInterfaceStyle = .dark
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.register(CountryLabelView.self, forAnnotationViewWithReuseIdentifier: CountryLabelView.reuseID)
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40, longitude: 20),
                                         span: MKCoordinateSpan(latitudeDelta: 110, longitudeDelta: 160)),
                      animated: false)
        map.addOverlay(context.coordinator.overlay, level: .aboveRoads)
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
                map.preferredConfiguration = config
            }
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
    private var styles: [ProvinceStyle] = []
    private var plans: [PlanLine] = []

    func update(styles newStyles: [ProvinceStyle], plans newPlans: [PlanLine]) {
        lock.lock()
        styles = newStyles
        plans = newPlans
        lock.unlock()
        setNeedsDisplay()
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        lock.lock()
        let currentStyles = styles
        let currentPlans = plans
        lock.unlock()
        guard !currentStyles.isEmpty else { return }
        let shapes = ProvinceGeometry.shapes
        let margin = mapRect.size.width * 0.02
        let area = mapRect.insetBy(dx: -margin, dy: -margin)
        context.setLineJoin(.round)
        for style in currentStyles where style.id < shapes.count {
            let shape = shapes[style.id]
            guard shape.points.count >= 3, shape.bounds.intersects(area) else { continue }
            let path = CGMutablePath()
            path.move(to: point(for: shape.points[0]))
            for pt in shape.points.dropFirst() {
                path.addLine(to: point(for: pt))
            }
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(style.fill.cgColor)
            context.fillPath()
            context.addPath(path)
            context.setStrokeColor(style.stroke.cgColor)
            context.setLineWidth(style.lineWidth / zoomScale)
            context.strokePath()
        }
        // Troupes massées à une frontière : flèches pointillées.
        context.setStrokeColor(UIColor(Theme.amber).cgColor)
        context.setLineWidth(2.5 / zoomScale)
        context.setLineDash(phase: 0, lengths: [6 / zoomScale, 6 / zoomScale])
        for line in currentPlans {
            let a = MKMapPoint(CLLocationCoordinate2D(latitude: line.from.lat, longitude: line.from.lon))
            let b = MKMapPoint(CLLocationCoordinate2D(latitude: line.to.lat, longitude: line.to.lon))
            context.move(to: point(for: a))
            context.addLine(to: point(for: b))
            context.strokePath()
        }
    }
}

// MARK: - Noms des pays

final class CountryAnnotation: NSObject, MKAnnotation {
    let countryID: CountryID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var label: CountryLabel

    init(label: CountryLabel) {
        self.countryID = label.id
        self.label = label
        self.coordinate = CLLocationCoordinate2D(latitude: label.lat, longitude: label.lon)
    }
}

final class CountryLabelView: MKAnnotationView {
    static let reuseID = "country-label"
    private let text = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        isUserInteractionEnabled = false
        canShowCallout = false
        collisionMode = .rectangle
        text.layer.shadowColor = UIColor.black.cgColor
        text.layer.shadowOpacity = 0.9
        text.layer.shadowRadius = 2
        text.layer.shadowOffset = .zero
        addSubview(text)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }

    func configure(_ label: CountryLabel) {
        let base = UIFont.systemFont(ofSize: label.size * 0.8, weight: .bold)
        let font = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: label.size * 0.8) } ?? base
        text.font = font
        text.textColor = label.highlighted ? UIColor(Theme.amber) : UIColor(Theme.paper)
        text.text = Geo.flag(label.id) + " " + label.name + (label.atWar ? " 🔥" : "")
        text.sizeToFit()
        frame = CGRect(origin: .zero, size: text.bounds.size)
        text.frame = bounds
        centerOffset = .zero
        displayPriority = label.highlighted ? .required : MKFeatureDisplayPriority(rawValue: Float(500 + label.size * 15))
        accessibilityLabel = label.name
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
    private var lastSnapshot: MapSnapshot?
    private var annotations: [CountryID: CountryAnnotation] = [:]
    private var longitudeSpan: Double = 160

    func apply(_ snapshot: MapSnapshot) {
        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot
        renderer?.update(styles: snapshot.provinces, plans: snapshot.plans)
        updateLabels(snapshot.labels)
    }

    private func updateLabels(_ labels: [CountryLabel]) {
        guard let map = mapView else { return }
        let visible = labels.filter { isVisible($0) }
        let wanted = Set(visible.map { $0.id })
        var toRemove: [CountryAnnotation] = []
        for (id, annotation) in annotations where !wanted.contains(id) {
            toRemove.append(annotation)
        }
        if !toRemove.isEmpty {
            map.removeAnnotations(toRemove)
            for a in toRemove { annotations[a.countryID] = nil }
        }
        var toAdd: [CountryAnnotation] = []
        for label in visible {
            if let existing = annotations[label.id] {
                if existing.label != label {
                    existing.label = label
                    (map.view(for: existing) as? CountryLabelView)?.configure(label)
                }
            } else {
                let annotation = CountryAnnotation(label: label)
                annotations[label.id] = annotation
                toAdd.append(annotation)
            }
        }
        if !toAdd.isEmpty { map.addAnnotations(toAdd) }
    }

    private func isVisible(_ label: CountryLabel) -> Bool {
        if label.highlighted { return true }
        switch label.tier {
        case 0: return true
        case 1: return longitudeSpan < 90
        default: return longitudeSpan < 35
        }
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
            if let snapshot = lastSnapshot {
                r.update(styles: snapshot.provinces, plans: snapshot.plans)
            }
            renderer = r
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? CountryAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: CountryLabelView.reuseID, for: annotation)
        (view as? CountryLabelView)?.configure(annotation.label)
        return view
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        longitudeSpan = mapView.region.span.longitudeDelta
        if let labels = lastSnapshot?.labels {
            updateLabels(labels)
        }
    }
}
