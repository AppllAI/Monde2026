import SwiftUI

// =============================================================
//  WorldPanel.swift
//  L'état du monde : tension, guerres, crises, marchés,
//  classements et journal des événements.
// =============================================================

struct WorldPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim {
            PanelHeader(title: "Le monde", subtitle: sim.dateString) { store.panel = nil }
            tension(sim)
            conflicts(sim)
            markets(sim)
            rankings(sim)
            journal(sim)
        }
    }

    private func tension(_ sim: Simulation) -> some View {
        let t = sim.state.worldTension
        let label = t > 70 ? "Le monde est au bord d'une guerre majeure." :
            (t > 45 ? "Crises nombreuses, équilibre fragile." : "Période relativement calme.")
        return Dossier(title: "Tension mondiale : \(Fmt.number(t))", subtitle: label) {
            Meter(value: t / 100, tint: t > 60 ? Theme.coral : Theme.amber, height: 8)
        }
    }

    private func conflicts(_ sim: Simulation) -> some View {
        Dossier(title: "Guerres et crises") {
            let wars = sim.activeWarsList
            if wars.isEmpty && sim.state.warPlans.isEmpty {
                Text("Aucun conflit armé entre États.").font(Theme.small).foregroundStyle(Theme.steel)
            }
            ForEach(wars) { war in
                VStack(alignment: .leading, spacing: 4) {
                    Text(war.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.coral)
                    Text(war.attackers.map { sim.name($0) }.joined(separator: ", ")
                         + " contre " + war.defenders.map { sim.name($0) }.joined(separator: ", "))
                        .font(Theme.small).foregroundStyle(Theme.paper)
                    ForEach(sim.heldShare(of: war.defenders, by: war.attackers), id: \.0) { item in
                        Text("\(sim.name(item.0)) occupé à \(Fmt.pct(item.1))").font(Theme.small).foregroundStyle(Theme.steel)
                    }
                    ForEach(sim.heldShare(of: war.attackers, by: war.defenders), id: \.0) { item in
                        Text("\(sim.name(item.0)) occupé à \(Fmt.pct(item.1))").font(Theme.small).foregroundStyle(Theme.steel)
                    }
                }
                .padding(.vertical, 3)
            }
            ForEach(sim.state.warPlans.indices, id: \.self) { i in
                let plan = sim.state.warPlans[i]
                Text("⚠️ \(sim.name(plan.attacker)) masse des troupes face à \(sim.name(plan.target))")
                    .font(Theme.small).foregroundStyle(Theme.amber)
            }
        }
    }

    private func markets(_ sim: Simulation) -> some View {
        Dossier(title: "Matières premières", subtitle: "100 % = prix de janvier 2026.") {
            ForEach(Resource.allCases, id: \.self) { r in
                let price = sim.state.prices[r] ?? 1
                HStack {
                    Text(r.name).font(.system(size: 14)).foregroundStyle(Theme.paper)
                    Spacer()
                    Image(systemName: price > 1.02 ? "arrow.up.right" : (price < 0.98 ? "arrow.down.right" : "arrow.right"))
                        .foregroundStyle(price > 1.02 ? Theme.coral : (price < 0.98 ? Theme.teal : Theme.steel))
                    Text("\(Fmt.number(price * 100)) %").font(Theme.data(14, weight: .semibold)).foregroundStyle(Theme.paper)
                }
            }
        }
    }

    private func rankings(_ sim: Simulation) -> some View {
        let byGDP = Array(sim.rankedCountries().prefix(10))
        let byPower = Array(sim.countryIDs.sorted { sim.militaryPower($0) > sim.militaryPower($1) }.prefix(10))
        return Dossier(title: "Classements") {
            Text("Économies").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.steel)
            ForEach(byGDP) { c in
                Button { store.open(.country(c.id)) } label: {
                    CountryRow(country: c, detail: Fmt.signedPct(c.growth) + " de croissance",
                               trailing: Fmt.money(sim.effectiveGDP(c.id)), trailingTint: Theme.paper)
                }
                .buttonStyle(.plain)
            }
            Text("Armées").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.steel).padding(.top, 6)
            ForEach(byPower, id: \.self) { id in
                if let c = sim.state.countries[id] {
                    Button { store.open(.country(id)) } label: {
                        CountryRow(country: c, detail: "\(c.divisionCount) divisions, \(Fmt.count(c.stock(.fighter))) avions",
                                   trailing: Fmt.count(sim.militaryPower(id)), trailingTint: Theme.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func journal(_ sim: Simulation) -> some View {
        Dossier(title: "Journal") {
            ForEach(Array(sim.state.events.suffix(40).reversed())) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text(sim.dateString(forDay: e.day)).font(Theme.data(11)).foregroundStyle(Theme.steel)
                    Text(e.text).font(.system(size: 13)).foregroundStyle(e.important ? Theme.paper : Theme.paper.opacity(0.75))
                }
                .padding(.vertical, 2)
            }
        }
    }
}
