import SwiftUI

// =============================================================
//  ProductionPanel.swift
//  Usines, lignes de production militaire et chantiers.
// =============================================================

struct ProductionPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Industrie", subtitle: c.name, flag: c.id) { store.panel = nil }
            IndustryCard(store: store, sim: sim, country: c)
            ProductionLinesCard(store: store, country: c)
            overview(sim, c)
        }
    }

    private func overview(_ sim: Simulation, _ c: Country) -> some View {
        let civ = sim.effectiveCivilianFactories(c.id)
        let points = sim.constructionPoints(c, effectiveCivilian: civ)
        let items: [(String, String, Color)] = [
            ("Usines civiles", Fmt.number(civ), Theme.paper),
            ("Usines militaires", Fmt.number(sim.effectiveMilitaryFactories(c.id)), Theme.paper),
            ("Chantiers navals", Fmt.number(sim.effectiveDockyards(c.id)), Theme.paper),
            ("Construction", Fmt.count(points) + " pts/mois", Theme.amber),
            ("Fonds de chantier", Fmt.money(c.constructionFunds), Theme.paper),
            ("Fonds d'achat", Fmt.money(c.procurementFunds), Theme.paper)
        ]
        return Dossier(title: "Capacités") {
            FigureGrid(items: items)
        }
    }
}

struct ProductionLinesCard: View {
    @ObservedObject var store: GameStore
    let country: Country

    var body: some View {
        Dossier(title: "Production militaire",
                subtitle: "1 usine ≈ 5 M$ de matériel par jour à pleine efficacité. L'argent vient du budget de défense.") {
            Toggle(isOn: Binding(
                get: { country.autoProduction },
                set: { value in
                    let id = country.id
                    store.mutate { $0.setAutoProduction(value, for: id) }
                })) {
                Text("Production automatique").font(.system(size: 14)).foregroundStyle(Theme.paper)
            }
            .tint(Theme.amber)
            ForEach(country.productionLines) { line in
                lineRow(line)
            }
            addMenu
        }
    }

    private func lineRow(_ line: ProductionLine) -> some View {
        let perMonth = line.factories * 5 * line.efficiency * 30 / line.equipment.cost
        let id = country.id
        let equipment = line.equipment
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.equipment.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                    Text("\(Fmt.number(line.factories, 1)) \(line.equipment.isNaval ? "chantiers" : "usines"), ≈ \(Fmt.number(perMonth, perMonth < 10 ? 1 : 0)) par mois")
                        .font(Theme.small).foregroundStyle(Theme.steel)
                }
                Spacer()
                Button {
                    store.mutate { $0.setProduction(equipment, factories: max(0, line.factories - 1), for: id) }
                } label: {
                    Image(systemName: "minus").frame(width: 34, height: 30)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retirer une usine")
                Button {
                    store.mutate { $0.setProduction(equipment, factories: line.factories + 1, for: id) }
                } label: {
                    Image(systemName: "plus").frame(width: 34, height: 30)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajouter une usine")
            }
            .foregroundStyle(Theme.paper)
            Meter(value: line.efficiency, tint: Theme.amber, height: 4)
        }
    }

    private var addMenu: some View {
        let used = Set(country.productionLines.map { $0.equipment })
        let id = country.id
        return Menu {
            ForEach(EquipmentType.allCases.filter { !used.contains($0) }, id: \.self) { e in
                Button(e.name) {
                    store.mutate { $0.setProduction(e, factories: 1, for: id) }
                }
            }
        } label: {
            Label("Nouvelle ligne de production", systemImage: "plus.circle")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.amber)
        }
    }
}

struct ConstructionCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country

    var body: some View {
        Dossier(title: "Chantiers",
                subtitle: "Quand la file est vide, le pays construit automatiquement ce qui lui manque le plus.") {
            ForEach(country.constructionQueue.prefix(8)) { project in
                projectRow(project)
            }
            if country.constructionQueue.count > 8 {
                Text("+ \(country.constructionQueue.count - 8) autres projets").font(Theme.small).foregroundStyle(Theme.steel)
            }
            HStack(spacing: 8) {
                ForEach(ConstructionKind.allCases, id: \.self) { kind in
                    let id = country.id
                    Button {
                        store.mutate { $0.queueConstruction(kind, for: id) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: icon(kind)).font(.system(size: 18))
                            Text(kind.name).font(.system(size: 11)).multilineTextAlignment(.center)
                            Text(Fmt.money(kind.moneyCost(area: country.area))).font(Theme.data(10)).foregroundStyle(Theme.steel)
                        }
                        .foregroundStyle(Theme.paper)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func projectRow(_ project: ConstructionProject) -> some View {
        let id = country.id
        let pid = project.id
        return HStack(spacing: 10) {
            Image(systemName: icon(project.kind)).foregroundStyle(Theme.amber).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.kind.name).font(.system(size: 14)).foregroundStyle(Theme.paper)
                Meter(value: project.progress / project.kind.constructionCost, tint: Theme.amber, height: 4)
            }
            Button {
                store.mutate { $0.removeConstruction(pid, for: id) }
            } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.steel)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Annuler le projet")
        }
    }

    private func icon(_ kind: ConstructionKind) -> String {
        switch kind {
        case .civilianFactory: return "building.2"
        case .militaryFactory: return "shield.checkered"
        case .dockyard: return "ferry"
        case .infrastructure: return "road.lanes"
        }
    }
}
