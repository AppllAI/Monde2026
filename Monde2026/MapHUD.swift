import SwiftUI

// =============================================================
//  MapHUD.swift
//  Ce qui flotte sur la carte : la fiche rapide du pays touché,
//  la légende du mode de carte et les boutons de navigation.
// =============================================================

// MARK: - Fiche rapide

struct InspectorCard: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let id = store.selectedCountry {
            let country = sim.state.countries[id]
            let province = store.selectedProvinceInfo
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(country != nil ? Geo.flag(id) : "🏳️").font(.system(size: 34))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(country?.name ?? province?.0.countryName ?? id)
                            .font(Theme.title(21)).foregroundStyle(Theme.paper)
                        if let info = province {
                            Text(regionLine(info.0, info.1, sim))
                                .font(Theme.small)
                                .foregroundStyle(info.1.status == .core || info.1.status == .neutral ? Theme.steel : Theme.coral)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    Button { store.clearSelection() } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer")
                }
                if let c = country {
                    HStack(spacing: 14) {
                        Readout(label: "PIB", value: Fmt.money(sim.effectiveGDP(id)))
                        Readout(label: "Croissance", value: Fmt.signedPct(c.growth), tint: c.growth >= 0 ? Theme.teal : Theme.coral)
                        Readout(label: "Divisions", value: "\(c.divisionCount)")
                        Readout(label: "Stabilité", value: Fmt.pct(c.stability, 0), tint: c.stability < 0.3 ? Theme.coral : Theme.paper)
                        if let p = store.playerID, p != id {
                            let r = sim.relation(p, id)
                            Readout(label: "Relation", value: Fmt.number(r), tint: Theme.relationColor(r))
                        }
                    }
                    statusLine(sim, id)
                    HStack(spacing: 8) {
                        if id == store.playerID {
                            ActionButton(title: "Gérer mon pays", icon: "slider.horizontal.3") { store.open(.economy) }
                        } else {
                            ActionButton(title: "Ouvrir la fiche", icon: "doc.text.magnifyingglass") { store.open(.country(id)) }
                        }
                        Button { store.focusOn(id) } label: {
                            Image(systemName: "scope").font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.paper)
                                .frame(width: 46, height: 44)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Centrer sur ce pays")
                    }
                } else {
                    Text("Territoire neutre : ce pays n'est pas jouable dans cette version.")
                        .font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .glass(24)
        }
    }

    private func regionLine(_ p: Province, _ owner: ProvinceOwner, _ sim: Simulation) -> String {
        switch owner.status {
        case .core, .neutral: return "Région : \(p.name)"
        case .occupied: return "\(p.name) : occupée par \(sim.name(owner.owner ?? ""))"
        case .annexed: return "\(p.name) : annexée par \(sim.name(owner.owner ?? ""))"
        case .rebel: return "\(p.name) : aux mains des rebelles"
        }
    }

    @ViewBuilder
    private func statusLine(_ sim: Simulation, _ id: CountryID) -> some View {
        let wars = sim.wars(of: id)
        let threatened = sim.state.warPlans.contains { $0.target == id }
        if !wars.isEmpty {
            Label(wars.map { $0.name }.joined(separator: ", "), systemImage: "flame.fill")
                .font(Theme.small).foregroundStyle(Theme.coral).lineLimit(2)
        } else if threatened {
            Label("Des troupes étrangères se massent à ses frontières", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.small).foregroundStyle(Theme.amber)
        } else if let bloc = sim.faction(of: id) {
            Label("Membre de \(bloc.name)", systemImage: "shield.lefthalf.filled")
                .font(Theme.small).foregroundStyle(Theme.steel)
        }
    }
}

// MARK: - Légende

struct MapLegend: View {
    let mode: MapMode
    @State private var expanded = true

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: mode.icon).font(.system(size: 11, weight: .semibold))
                    Text(mode.rawValue).font(.system(size: 12, weight: .semibold))
                    Image(systemName: expanded ? "chevron.down" : "chevron.up").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(Theme.paper)
                if expanded {
                    content
                }
            }
            .padding(10)
            .glass(14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Légende")
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .political:
            item(Theme.coral, "Ligne de front", line: true)
            item(Theme.amber, "Vos frontières", line: true)
            stripes("Territoire occupé")
            item(Color(uiColor: Theme.rebelLand), "Rebelles")
            item(Color(uiColor: Theme.neutralLand), "Non jouable")
        case .alliances:
            item(Theme.blocColor("OTAN"), "OTAN")
            item(Theme.blocColor("OTSC"), "OTSC")
            item(Theme.blocColor("CCG"), "Golfe")
            item(Theme.blocColor("AES"), "Sahel")
            item(Theme.blocColor("USA-ALLY"), "Alliés des États-Unis")
            item(Theme.blocColor("CHN-ALLY"), "Proches de Pékin et Moscou")
        case .relations:
            gradient([Theme.coral, Theme.steel, Theme.teal], "Hostile", "Allié")
        case .economy:
            gradient([Theme.coral, Theme.steel, Theme.teal], "Récession", "Forte croissance")
        case .military:
            item(Theme.coral, "En guerre")
            gradient([Theme.steel, Theme.amber], "Faible", "Puissante")
        }
    }

    private func item(_ color: Color, _ text: String, line: Bool = false) -> some View {
        HStack(spacing: 6) {
            if line {
                Capsule().fill(color).frame(width: 14, height: 3)
            } else {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 10)
            }
            Text(text).font(.system(size: 11)).foregroundStyle(Theme.paper.opacity(0.85))
        }
    }

    private func stripes(_ text: String) -> some View {
        HStack(spacing: 6) {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.steel))
                var x: CGFloat = -size.height
                while x < size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    ctx.stroke(p, with: .color(Theme.amber), lineWidth: 1.5)
                    x += 4
                }
            }
            .frame(width: 14, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(text).font(.system(size: 11)).foregroundStyle(Theme.paper.opacity(0.85))
        }
    }

    private func gradient(_ colors: [Color], _ low: String, _ high: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                .frame(width: 130, height: 6).clipShape(Capsule())
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.system(size: 10)).foregroundStyle(Theme.steel)
            .frame(width: 130)
        }
    }
}

// MARK: - Boutons de carte

struct MapButtons: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            round("location.fill", "Centrer sur mon pays") {
                if let p = store.playerID { store.focusOn(p) }
            }
            round(store.satellite ? "map" : "globe.europe.africa.fill", "Changer le fond de carte") {
                store.satellite.toggle()
            }
        }
    }

    private func round(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .frame(width: 44, height: 44)
                .glass(22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
