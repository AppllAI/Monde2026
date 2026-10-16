import SwiftUI
import MapKit

// =============================================================
//  WorldMapView.swift
//  La carte façon « grande stratégie » : ~600 régions coloriées
//  selon leur propriétaire, posées sur le relief d'Apple Plans,
//  noms de pays avec drapeaux, zones occupées et rebelles.
//  La carte ne se redessine que quand l'image change vraiment
//  (pas à chaque jour de jeu), pour rester fluide.
// =============================================================

// MARK: - Image de la carte

struct ProvinceStyle: Equatable, Identifiable {
    let id: Int
    let fill: Color
    let opacity: Double
    let stroke: Color
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

enum ProvinceGeometry {
    static let coordinates: [[CLLocationCoordinate2D]] = ProvinceMap.all.map { province in
        province.outline.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
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
            var stroke = Theme.ink.opacity(0.55)
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
            styles.append(ProvinceStyle(id: p.id, fill: fill, opacity: opacity, stroke: stroke, lineWidth: width))
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

// MARK: - Vue

struct WorldMapView: View, Equatable {
    let snapshot: MapSnapshot
    let satellite: Bool
    let onTap: (GeoPoint) -> Void

    static func == (lhs: WorldMapView, rhs: WorldMapView) -> Bool {
        lhs.snapshot == rhs.snapshot && lhs.satellite == rhs.satellite
    }

    @State private var position: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 40, longitude: 20), distance: 22_000_000)
    )
    @State private var distance: Double = 22_000_000

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                ForEach(snapshot.provinces) { style in
                    MapPolygon(coordinates: ProvinceGeometry.coordinates[style.id])
                        .foregroundStyle(style.fill.opacity(style.opacity))
                        .stroke(style.stroke, lineWidth: style.lineWidth)
                }
                ForEach(visibleLabels) { label in
                    Annotation(label.name, coordinate: CLLocationCoordinate2D(latitude: label.lat, longitude: label.lon),
                               anchor: .center) {
                        CountryNameTag(label: label, zoom: zoom)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(snapshot.plans) { line in
                    MapPolyline(coordinates: [
                        CLLocationCoordinate2D(latitude: line.from.lat, longitude: line.from.lon),
                        CLLocationCoordinate2D(latitude: line.to.lat, longitude: line.to.lon)
                    ])
                    .stroke(Theme.amber, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 6]))
                }
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                distance = context.camera.distance
            }
            .onTapGesture(coordinateSpace: .local) { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    onTap(GeoPoint(lat: coordinate.latitude, lon: coordinate.longitude))
                }
            }
        }
    }

    private var mapStyle: MapStyle {
        if satellite {
            return MapStyle.imagery(elevation: .realistic)
        }
        return MapStyle.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll)
    }

    /// 1 = vue du monde entier ; plus grand quand on zoome.
    private var zoom: CGFloat {
        CGFloat((22_000_000 / max(distance, 1)).clamped(1, 12))
    }

    private var visibleLabels: [CountryLabel] {
        snapshot.labels.filter { label in
            if label.highlighted { return true }
            switch label.tier {
            case 0: return true
            case 1: return distance < 14_000_000
            default: return distance < 6_000_000
            }
        }
    }
}

/// Nom d'un pays posé sur son territoire, avec son drapeau.
struct CountryNameTag: View {
    let label: CountryLabel
    let zoom: CGFloat

    var body: some View {
        let scale = min(1.6, 0.75 + zoom * 0.12)
        HStack(spacing: 4) {
            Text(Geo.flag(label.id)).font(.system(size: label.size * scale * 0.9))
            Text(label.name)
                .font(.system(size: label.size * scale * 0.75, weight: .bold, design: .serif))
                .foregroundStyle(label.highlighted ? Theme.amber : Theme.paper)
                .shadow(color: .black.opacity(0.85), radius: 2)
            if label.atWar {
                Image(systemName: "flame.fill").font(.system(size: label.size * scale * 0.55)).foregroundStyle(Theme.coral)
            }
        }
        .fixedSize()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
