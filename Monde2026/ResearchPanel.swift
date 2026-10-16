import SwiftUI

// =============================================================
//  ResearchPanel.swift
//  L'arbre technologique.
// =============================================================

struct ResearchPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let c = store.player {
            let points = sim.researchPoints(c.id)
            PanelHeader(title: "Recherche",
                        subtitle: "\(Fmt.number(points)) points par mois, \(c.techs.count) technologies maîtrisées",
                        flag: c.id) { store.panel = nil }
            current(c, points: points)
            ForEach(TechCategory.allCases, id: \.self) { category in
                Dossier(title: category.rawValue) {
                    ForEach(TechID.allCases.filter { $0.category == category }, id: \.self) { tech in
                        TechRow(store: store, country: c, tech: tech, points: points)
                    }
                }
            }
        }
    }

    private func current(_ c: Country, points: Double) -> some View {
        Dossier(title: "En cours",
                subtitle: c.researching == nil ? "Choisissez une technologie disponible ci-dessous. Le budget de recherche se règle dans Économie." : nil) {
            if let tech = c.researching {
                Text(tech.name).font(Theme.title(17)).foregroundStyle(Theme.paper)
                Meter(value: c.researchProgress / tech.cost, tint: Theme.sky, height: 8)
                let months = points > 0 ? Int(((tech.cost - c.researchProgress) / points).rounded(.up)) : 999
                Text("Encore environ \(months) mois.").font(Theme.small).foregroundStyle(Theme.steel)
            }
        }
    }
}

struct TechRow: View {
    @ObservedObject var store: GameStore
    let country: Country
    let tech: TechID
    let points: Double

    var body: some View {
        let owned = country.has(tech)
        let available = country.canResearch(tech)
        let active = country.researching == tech
        Button {
            guard available else { return }
            let id = country.id
            store.mutate { $0.setResearch(active ? nil : tech, for: id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: owned ? "checkmark.circle.fill" : (active ? "hourglass" : (available ? "circle" : "lock.fill")))
                    .foregroundStyle(owned ? Theme.teal : (active ? Theme.sky : (available ? Theme.paper : Theme.steel)))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tech.name).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(available || owned ? Theme.paper : Theme.steel)
                    Text(tech.effect).font(Theme.small).foregroundStyle(Theme.steel)
                        .fixedSize(horizontal: false, vertical: true)
                    if !owned && !available {
                        Text("Nécessite : " + tech.requires.map { $0.name }.joined(separator: ", "))
                            .font(Theme.small).foregroundStyle(Theme.coral.opacity(0.8))
                    }
                }
                Spacer()
                if !owned {
                    Text(points > 0 ? "\(Int((tech.cost / points).rounded(.up))) mois" : "—")
                        .font(Theme.data(12)).foregroundStyle(Theme.steel)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(owned)
    }
}
