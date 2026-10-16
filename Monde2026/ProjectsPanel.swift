import SwiftUI

// =============================================================
//  ProjectsPanel.swift
//  Les projets nationaux, les opérations secrètes, l'ONU
//  et les succès.
// =============================================================

struct ProjectsPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Projets nationaux", subtitle: "\(c.completedProjects.count) projets achevés", flag: c.id) {
                store.panel = nil
            }
            current(sim, c)
            ForEach(ProjectCategory.allCases, id: \.self) { category in
                let items = ProjectCatalog.all.filter { $0.category == category }
                Dossier(title: category.rawValue) {
                    ForEach(items) { def in
                        ProjectRow(store: store, sim: sim, country: c, def: def)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func current(_ sim: Simulation, _ c: Country) -> some View {
        if let active = c.activeProject, let def = ProjectCatalog.find(active.id) {
            Dossier(title: def.name, subtitle: "Encore \(active.monthsLeft) mois") {
                Meter(value: 1 - Double(active.monthsLeft) / Double(max(1, active.totalMonths)), tint: Theme.amber, height: 8)
                Text(def.detail).font(Theme.small).foregroundStyle(Theme.steel)
                QuietButton(title: "Abandonner le projet", icon: "xmark", tint: Theme.coral) {
                    let id = c.id
                    store.mutate { $0.cancelProject(for: id) }
                }
            }
        } else {
            Dossier(title: "Aucun projet en cours",
                    subtitle: "Un seul grand projet à la fois. Son coût est ajouté à la dette mois après mois.") {
                EmptyView()
            }
        }
    }
}

struct ProjectRow: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country
    let def: ProjectDefinition

    var body: some View {
        let done = country.completedProjects.contains(def.id)
        let available = !done && def.available(sim, country.id)
        let busy = country.activeProject != nil
        let cost = sim.effectiveGDP(country.id) * def.cost
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.seal.fill" : def.icon)
                .font(.system(size: 18))
                .foregroundStyle(done ? Theme.teal : (available ? Theme.amber : Theme.steel))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(def.name).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(available || done ? Theme.paper : Theme.steel)
                Text(def.detail).font(Theme.small).foregroundStyle(Theme.steel)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(def.months) mois" + (cost > 0.05 ? ", \(Fmt.money(cost))" : ", gratuit"))
                    .font(Theme.data(11)).foregroundStyle(Theme.steel)
                if !done && !available {
                    Text("Conditions non remplies").font(Theme.small).foregroundStyle(Theme.coral.opacity(0.8))
                }
            }
            Spacer(minLength: 6)
            if available {
                Button {
                    let id = def.id
                    store.perform { s, p in s.startProject(id, for: p) }
                } label: {
                    Text("Lancer").font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .foregroundStyle(busy ? Theme.steel : Theme.ink)
                        .background(busy ? Color.white.opacity(0.08) : Theme.amber, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Opérations secrètes (dans la fiche d'un pays)

struct CovertOpsCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID
    let target: CountryID

    var body: some View {
        let me = sim.state.countries[player]
        Dossier(title: "Opérations secrètes",
                subtitle: "Vos services : \(Fmt.pct(me?.intelligence ?? 0, 0)), les siens : \(Fmt.pct(sim.state.countries[target]?.intelligence ?? 0, 0)). Une opération démasquée crée un incident.") {
            ForEach(CovertOperation.allCases.filter { sim.covertAvailable($0, target: target) }) { op in
                let chance = sim.covertChance(op, from: player, on: target)
                Button {
                    store.perform { s, p in s.covertOperation(op, from: p, on: target) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: op.icon).font(.system(size: 16)).foregroundStyle(Theme.amber).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(op.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                            Text(op.detail).font(Theme.small).foregroundStyle(Theme.steel)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.pct(chance, 0)).font(Theme.data(13, weight: .semibold))
                                .foregroundStyle(chance > 0.5 ? Theme.teal : Theme.coral)
                            Text("\(Int(op.influenceCost)) infl.").font(Theme.data(11)).foregroundStyle(Theme.steel)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - ONU (dans la fiche d'un pays)

struct UNCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID
    let target: CountryID

    var body: some View {
        Dossier(title: "Conseil de sécurité de l'ONU",
                subtitle: "15 membres, dont 5 permanents avec droit de veto. Il faut 9 voix et aucun veto. Coûte 20 d'influence.") {
            ForEach(ResolutionKind.allCases) { kind in
                if kind != .ceasefire || !sim.enemies(of: target).isEmpty {
                    resolution(kind)
                }
            }
        }
    }

    private func resolution(_ kind: ResolutionKind) -> some View {
        let votes = sim.predictVotes(kind, target: target, sponsor: player)
        let yes = votes.filter { $0.inFavor }.count
        let vetoes = votes.filter { Simulation.permanentMembers.contains($0.id) && !$0.inFavor }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(kind.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("\(yes)/15").font(Theme.data(13, weight: .semibold)).foregroundStyle(yes >= 9 && vetoes.isEmpty ? Theme.teal : Theme.coral)
            }
            Text(kind.detail).font(Theme.small).foregroundStyle(Theme.steel)
            if !vetoes.isEmpty {
                Text("Veto probable : " + vetoes.map { sim.name($0.id) }.joined(separator: ", "))
                    .font(Theme.small).foregroundStyle(Theme.coral)
            }
            HStack(spacing: 4) {
                ForEach(votes) { v in
                    Text(Geo.flag(v.id)).font(.system(size: 14)).opacity(v.inFavor ? 1 : 0.3)
                }
            }
            QuietButton(title: "Déposer la résolution", icon: "building.columns", tint: Theme.amber) {
                store.perform { s, p in s.proposeResolution(kind, target: target, by: p) }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Succès

struct AchievementsCard: View {
    let unlockedHere: Set<String>

    var body: some View {
        let everywhere = AchievementStore.unlocked.union(unlockedHere)
        Dossier(title: "Succès", subtitle: "\(everywhere.count) sur \(AchievementCatalog.all.count) débloqués") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(AchievementCatalog.all) { a in
                    let got = everywhere.contains(a.id)
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: a.icon).font(.system(size: 18))
                            .foregroundStyle(got ? Theme.amber : Theme.steel.opacity(0.6))
                        Text(a.title).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(got ? Theme.paper : Theme.steel)
                        Text(a.detail).font(.system(size: 11)).foregroundStyle(Theme.steel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(got ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
