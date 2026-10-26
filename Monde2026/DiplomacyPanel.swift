import SwiftUI

// =============================================================
//  DiplomacyPanel.swift
//  Propositions reçues, traités, blocs et relations.
// =============================================================

struct DiplomacyPanel: View {
    @ObservedObject var store: GameStore
    @State private var search = ""

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Diplomatie", subtitle: "Influence \(Fmt.number(c.influence)) / 100", flag: c.id) {
                store.panel = nil
            }
            InboxCard(store: store, sim: sim, player: c.id)
            TreatiesCard(store: store, sim: sim, player: c.id)
            FactionsCard(store: store, sim: sim, player: c.id)
            BlocsCard(sim: sim, player: c.id)
            relations(sim, c)
        }
    }

    private func relations(_ sim: Simulation, _ c: Country) -> some View {
        let query = search.lowercased()
        let others = sim.countryIDs.filter { $0 != c.id }
            .filter { query.isEmpty || sim.name($0).lowercased().contains(query) }
            .sorted { sim.relation(c.id, $0) > sim.relation(c.id, $1) }
        return Dossier(title: "Relations", subtitle: "Touchez un pays pour agir.") {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.steel)
                TextField("Rechercher", text: $search).foregroundStyle(Theme.paper)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            ForEach(others.prefix(query.isEmpty ? 60 : 154), id: \.self) { id in
                if let other = sim.state.countries[id] {
                    let r = sim.relation(c.id, id)
                    Button { store.open(.country(id)) } label: {
                        CountryRow(country: other, detail: relationLabel(r, sim: sim, me: c.id, other: id),
                                   trailing: Fmt.number(r), trailingTint: Theme.relationColor(r))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func relationLabel(_ r: Double, sim: Simulation, me: CountryID, other: CountryID) -> String {
        if sim.enemies(of: me).contains(other) { return "En guerre" }
        if sim.allies(of: me).contains(other) { return "Allié" }
        if r > 60 { return "Très proches" }
        if r > 25 { return "Amicaux" }
        if r > -25 { return "Neutres" }
        if r > -60 { return "Tendus" }
        return "Hostiles"
    }
}

struct InboxCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID

    var body: some View {
        let inbox = sim.state.proposals.filter { $0.to == player }
        Dossier(title: "Propositions reçues",
                subtitle: inbox.isEmpty ? "Aucune proposition en attente." : "Elles expirent après 60 jours.") {
            ForEach(inbox) { p in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        FlagBadge(id: p.from, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(sim.name(p.from)) propose : \(p.kind.name)")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                            if let terms = p.terms {
                                Text(terms.name).font(Theme.small).foregroundStyle(Theme.steel)
                            }
                            if let t = p.target {
                                Text("Cible : \(Geo.flag(t)) \(sim.name(t)) · dans \(p.inDays) jours. Il faudra tenir parole.")
                                    .font(Theme.small).foregroundStyle(Theme.amber)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        ActionButton(title: "Accepter", icon: "checkmark", tint: Theme.teal) {
                            let pid = p.id
                            store.mutate { $0.respond(to: pid, accept: true) }
                        }
                        ActionButton(title: "Refuser", icon: "xmark", tint: Theme.coral) {
                            let pid = p.id
                            store.mutate { $0.respond(to: pid, accept: false) }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct TreatiesCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID

    var body: some View {
        let mine = sim.treaties(of: player)
        Dossier(title: "Vos traités", subtitle: mine.isEmpty ? "Aucun traité bilatéral." : nil) {
            ForEach(mine) { t in
                let other = t.partner(of: player)
                HStack(spacing: 10) {
                    FlagBadge(id: other, size: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.kind.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                        Text(direction(t, other: other)).font(Theme.small).foregroundStyle(Theme.steel)
                    }
                    Spacer()
                    if t.kind != .sanctions || t.a == player {
                        QuietButton(title: t.kind == .sanctions && t.a == player ? "Lever" : "Rompre", tint: Theme.coral) {
                            let tid = t.id
                            store.perform { sim, p in sim.breakTreaty(tid, by: p) }
                        }
                    }
                }
            }
        }
    }

    private func direction(_ t: Treaty, other: CountryID) -> String {
        switch t.kind {
        case .guarantee: return t.a == player ? "Vous garantissez \(sim.name(other))" : "\(sim.name(other)) vous garantit"
        case .sanctions: return t.a == player ? "Vous sanctionnez \(sim.name(other))" : "\(sim.name(other)) vous sanctionne"
        default: return "Avec \(sim.name(other))"
        }
    }
}

struct BlocsCard: View {
    let sim: Simulation
    let player: CountryID

    var body: some View {
        let blocs = sim.blocs(of: player)
        let claims = sim.claims(involving: player)
        Dossier(title: "Blocs et revendications") {
            if blocs.isEmpty {
                Text("Votre pays n'appartient à aucun bloc.").font(Theme.small).foregroundStyle(Theme.steel)
            }
            ForEach(blocs) { b in
                HStack {
                    Circle().fill(Theme.blocColor(b.id)).frame(width: 10, height: 10)
                    Text(b.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                    Spacer()
                    Text(b.isMilitary ? "Défense collective" : (b.isEconomic ? "Marché commun" : "Forum politique"))
                        .font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            ForEach(claims) { claim in
                let ours = claim.claimant == player
                Text(ours ? "Vous revendiquez \(claim.name) (\(sim.name(claim.target)))"
                          : "\(sim.name(claim.claimant)) revendique \(claim.name)")
                    .font(Theme.small).foregroundStyle(ours ? Theme.amber : Theme.coral)
            }
        }
    }
}

struct FactionsCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID
    @State private var newName = ""

    var body: some View {
        let mine = sim.faction(of: player)
        Dossier(title: "Factions", subtitle: mine.map { "Vous êtes membre de \($0.name)." } ?? "Vous n'appartenez à aucune faction militaire.") {
            if let bloc = mine {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(bloc.members, id: \.self) { m in
                            Button { store.open(.country(m)) } label: { FlagBadge(id: m, size: 24) }
                                .buttonStyle(.plain)
                                .accessibilityLabel(sim.name(m))
                        }
                    }
                }
                Text(sim.factionLeader(bloc) == player
                     ? "Vous êtes le chef de file : invitez des pays depuis leur fiche (15 d'influence)."
                     : "Chef de file : \(sim.name(sim.factionLeader(bloc) ?? ""))")
                    .font(Theme.small).foregroundStyle(Theme.steel)
                QuietButton(title: "Quitter la faction", icon: "rectangle.portrait.and.arrow.right", tint: Theme.coral) {
                    store.perform { s, p in s.leaveFaction(by: p) }
                }
            } else {
                HStack {
                    TextField("Nom de votre faction", text: $newName).foregroundStyle(Theme.paper)
                        .padding(10)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    QuietButton(title: "Fonder (30)", icon: "flag.fill", tint: Theme.amber) {
                        let title = newName
                        store.perform { s, p in s.createFaction(named: title, by: p) }
                    }
                }
                ForEach(sim.factions) { bloc in
                    factionRow(bloc)
                }
            }
        }
    }

    private func factionRow(_ bloc: Bloc) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(Theme.blocColor(bloc.id)).frame(width: 10, height: 10)
                Text(bloc.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("\(bloc.members.count) membres").font(Theme.small).foregroundStyle(Theme.steel)
            }
            EvaluationView(evaluation: sim.evaluateFactionAdmission(applicant: player, bloc: bloc))
            ActionButton(title: "Demander l'adhésion (20 d'influence)", icon: "person.badge.plus", tint: Theme.teal) {
                let id = bloc.id
                store.perform { s, p in s.requestJoinFaction(id, by: p) }
            }
        }
        .padding(.vertical, 4)
    }
}
