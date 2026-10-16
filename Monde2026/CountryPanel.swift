import SwiftUI

// =============================================================
//  CountryPanel.swift
//  La fiche d'un pays : profil, géopolitique et toutes les
//  actions possibles (avec la réponse probable de l'IA).
// =============================================================

struct CountryPanel: View {
    @ObservedObject var store: GameStore
    let id: CountryID

    var body: some View {
        if let sim = store.sim, let c = sim.state.countries[id] {
            PanelHeader(title: c.name, subtitle: subtitle(sim, c), flag: id) { store.panel = nil }
            if let info = store.selectedProvinceInfo, info.1.owner == id || info.0.country == id {
                RegionCard(sim: sim, province: info.0, owner: info.1)
            }
            if let p = store.playerID, p != id {
                RelationCard(sim: sim, player: p, other: id)
                FactionInvite(store: store, sim: sim, player: p, target: id)
            }
            profile(sim, c)
            GeopoliticsCard(store: store, sim: sim, country: c)
            if let p = store.playerID, p != id, !(sim.state.countries[p]?.capitulated ?? false) {
                DiplomaticActions(store: store, sim: sim, player: p, target: id)
                WarActions(store: store, sim: sim, player: p, target: id)
                CovertOpsCard(store: store, sim: sim, player: p, target: id)
                UNCard(store: store, sim: sim, player: p, target: id)
            }
        }
    }

    private func subtitle(_ sim: Simulation, _ c: Country) -> String {
        let blocs = sim.blocs(of: c.id).map { $0.name }
        if blocs.isEmpty { return c.region.name }
        return c.region.name + ", " + blocs.joined(separator: ", ")
    }

    private func profile(_ sim: Simulation, _ c: Country) -> some View {
        let gdp = sim.effectiveGDP(c.id)
        let lost = sim.lostFraction(c.id)
        let items: [(String, String, Color)] = [
            ("PIB", Fmt.money(gdp), Theme.paper),
            ("Croissance", Fmt.signedPct(c.growth), c.growth >= 0 ? Theme.teal : Theme.coral),
            ("Population", Fmt.population(c.population), Theme.paper),
            ("Dette", Fmt.pct(c.debt / max(gdp, 0.1), 0), Theme.paper),
            ("Divisions", "\(c.divisionCount)", Theme.paper),
            ("Équipement", Fmt.pct(c.divisionFill, 0), Theme.paper),
            ("Puissance", Fmt.count(sim.militaryPower(c.id)), Theme.amber),
            ("Avions", Fmt.count(c.stock(.fighter)), Theme.paper),
            ("Flotte", "\(Fmt.count(c.stock(.warship) + c.stock(.submarine) + c.stock(.carrier))) navires", Theme.paper),
            ("Ogives", "\(c.nuclearWarheads)", c.nuclearWarheads > 0 ? Theme.amber : Theme.steel),
            ("Territoire perdu", Fmt.pct(lost, 0), lost > 0.005 ? Theme.coral : Theme.steel),
            ("Lassitude", Fmt.pct(c.warExhaustion, 0), Theme.paper),
            ("Régime", c.government.name, Theme.paper),
            ("Stabilité", Fmt.pct(c.stability, 0), c.stability < 0.3 ? Theme.coral : Theme.paper),
            ("Au pouvoir", c.ideology.name, Theme.paper),
            ("Guerre civile", c.civilWar > 0 ? Fmt.pct(c.civilWar, 0) + " rebelle" : "Non", c.civilWar > 0 ? Theme.coral : Theme.steel),
            ("Technologies", "\(c.techs.count)", Theme.paper),
            ("Soutien", Fmt.pct(c.support, 0), Theme.paper)
        ]
        return Dossier(title: "Profil") {
            FigureGrid(items: items)
        }
    }
}

// MARK: - Relation avec le joueur

struct RelationCard: View {
    let sim: Simulation
    let player: CountryID
    let other: CountryID

    var body: some View {
        let r = sim.relation(player, other)
        Dossier(title: "Relation : \(Fmt.number(r))", subtitle: status) {
            RelationScale(value: r)
            ForEach(links, id: \.self) { text in
                Label(text, systemImage: "link").font(Theme.small).foregroundStyle(Theme.paper)
            }
        }
    }

    private var status: String {
        if sim.enemies(of: player).contains(other) { return "Vous êtes en guerre." }
        if sim.allies(of: player).contains(other) { return "Vous êtes alliés." }
        if sim.state.warPlans.contains(where: { $0.attacker == other && $0.target == player }) {
            return "Ses troupes se massent à votre frontière."
        }
        return "Pas d'engagement militaire entre vous."
    }

    private var links: [String] {
        var result: [String] = []
        for t in sim.treaties(of: player) where t.partner(of: player) == other {
            switch t.kind {
            case .guarantee:
                result.append(t.a == player ? "Vous garantissez son indépendance" : "Il garantit votre indépendance")
            case .sanctions:
                result.append(t.a == player ? "Vous le sanctionnez" : "Il vous sanctionne")
            default:
                result.append(t.kind.name)
            }
        }
        if sim.shareMilitaryBloc(player, other) { result.append("Même bloc militaire") }
        if sim.shareEconomicBloc(player, other) { result.append("Même zone économique") }
        return result
    }
}

// MARK: - Géopolitique

struct GeopoliticsCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country

    var body: some View {
        let allies = sim.allies(of: country.id).sorted()
        let guarantors = sim.guarantors(of: country.id)
        let claims = sim.claims(involving: country.id)
        let wars = sim.wars(of: country.id)
        Dossier(title: "Géopolitique") {
            if allies.isEmpty && guarantors.isEmpty {
                Text("Aucun allié militaire.").font(Theme.small).foregroundStyle(Theme.steel)
            } else {
                Text("Alliés et garants").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.steel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(allies + guarantors.filter { !allies.contains($0) }, id: \.self) { a in
                            Button { store.open(.country(a)) } label: { FlagBadge(id: a, size: 24) }
                                .buttonStyle(.plain)
                                .accessibilityLabel(sim.name(a))
                        }
                    }
                }
            }
            ForEach(claims) { c in
                Text(c.claimant == country.id ? "Revendique \(c.name) (\(sim.name(c.target)))"
                                              : "\(sim.name(c.claimant)) revendique \(c.name)")
                    .font(Theme.small).foregroundStyle(Theme.amber)
            }
            ForEach(wars) { w in
                Text("⚔️ " + w.name).font(Theme.small).foregroundStyle(Theme.coral)
            }
            if country.aggressiveness >= 0.4 {
                Text("Dirigeants enclins à utiliser la force.").font(Theme.small).foregroundStyle(Theme.steel)
            }
        }
    }
}

// MARK: - Actions diplomatiques

struct DiplomaticActions: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID
    let target: CountryID

    var body: some View {
        let atWar = sim.enemies(of: player).contains(target)
        Dossier(title: "Diplomatie", subtitle: "Votre influence : \(Fmt.number(sim.state.countries[player]?.influence ?? 0))") {
            if !atWar {
                simpleAction("Améliorer les relations", detail: "+12 de relation, coûte 10 d'influence.", icon: "hand.wave") {
                    store.perform { s, p in s.improveRelations(from: p, with: target) }
                }
                proposal(.tradePact, exists: sim.hasTreaty(.tradePact, player, target))
                proposal(.nonAggression, exists: sim.hasTreaty(.nonAggression, player, target))
                proposal(.alliance, exists: sim.hasTreaty(.alliance, player, target) || sim.shareMilitaryBloc(player, target))
                if !sim.hasTreaty(.guarantee, player, target) {
                    simpleAction("Garantir son indépendance", detail: "Vous entrerez en guerre s'il est attaqué. 10 d'influence.",
                                 icon: "shield") {
                        store.perform { s, p in s.guaranteeIndependence(from: p, of: target) }
                    }
                }
                let sanctioning = sim.hasTreaty(.sanctions, player, target)
                simpleAction(sanctioning ? "Lever les sanctions" : "Imposer des sanctions",
                             detail: sanctioning ? "Rétablit le commerce." : "Coupe tout commerce entre vos deux pays.",
                             icon: "nosign") {
                    store.perform { s, p in s.setSanctions(from: p, on: target, active: !sanctioning) }
                }
                simpleAction("Dénoncer publiquement", detail: "−20 de relation ; ses ennemis vous apprécient.", icon: "megaphone") {
                    store.perform { s, p in s.denounce(from: p, target: target) }
                }
            }
            Text("Aide").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.steel).padding(.top, 4)
            simpleAction("Envoyer du matériel", detail: "10 % de vos chars, blindés, artillerie, drones et missiles.",
                         icon: "shippingbox") {
                store.perform { s, p in s.sendMilitaryAid(from: p, to: target) }
            }
            HStack(spacing: 8) {
                QuietButton(title: "Aide de 5 Md$", icon: "banknote") {
                    store.perform { s, p in s.sendEconomicAid(from: p, to: target, amount: 5) }
                }
                QuietButton(title: "Aide de 25 Md$", icon: "banknote") {
                    store.perform { s, p in s.sendEconomicAid(from: p, to: target, amount: 25) }
                }
            }
        }
    }

    private func simpleAction(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Theme.amber).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                    Text(detail).font(Theme.small).foregroundStyle(Theme.steel)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.steel)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func proposal(_ kind: ProposalKind, exists: Bool) -> some View {
        if exists {
            Label("\(kind.name) en vigueur", systemImage: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.teal)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(kind.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                EvaluationView(evaluation: sim.evaluate(kind, from: player, to: target))
                ActionButton(title: "Proposer (\(Int(kind.influenceCost)) d'influence)", icon: "paperplane",
                             enabled: (sim.state.countries[player]?.influence ?? 0) >= kind.influenceCost) {
                    store.perform { s, p in s.propose(kind, from: p, to: target) }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Guerre et paix

struct WarActions: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID
    let target: CountryID
    @State private var confirmWar = false
    @State private var confirmNuclear = false

    var body: some View {
        let sharedWars = sim.wars(of: player).filter { $0.attackers.contains(target) || $0.defenders.contains(target) }
        let opposed = sharedWars.filter { w in
            (w.attackers.contains(player) && w.defenders.contains(target)) || (w.defenders.contains(player) && w.attackers.contains(target))
        }
        let joinable = sim.wars(of: player).filter { !$0.attackers.contains(target) && !$0.defenders.contains(target) }
        Dossier(title: opposed.isEmpty ? "Guerre" : "Négocier la paix") {
            ForEach(opposed) { war in
                peaceBlock(war)
            }
            ForEach(joinable) { war in
                joinBlock(war)
            }
            if opposed.isEmpty {
                declareBlock
            }
            covertBlock(atWar: !opposed.isEmpty)
        }
        .confirmationDialog("Déclarer la guerre à \(sim.name(target)) ?", isPresented: $confirmWar, titleVisibility: .visible) {
            Button("Déclarer la guerre", role: .destructive) {
                let t = target
                store.mutate { s in
                    if let p = s.state.playerID { _ = s.declareWar(attacker: p, defender: t) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(sim.isJustified(player, target)
                 ? "Vous avez un motif reconnu. Ses alliés peuvent entrer en guerre contre vous."
                 : "Sans motif légitime, le monde entier vous en voudra et des sanctions suivront.")
        }
    }

    private func peaceBlock(_ war: War) -> some View {
        let foes = war.attackers.contains(player) ? war.defenders : war.attackers
        let negotiator = sim.leader(of: foes) ?? target
        return VStack(alignment: .leading, spacing: 10) {
            Text(war.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.coral)
            if negotiator != target {
                Text("La paix se négocie avec \(sim.name(negotiator)), chef de file du camp adverse.")
                    .font(Theme.small).foregroundStyle(Theme.steel)
            }
            ForEach(PeaceTerms.allCases, id: \.self) { terms in
                VStack(alignment: .leading, spacing: 6) {
                    Text(terms.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                    EvaluationView(evaluation: sim.evaluatePeace(warID: war.id, evaluator: negotiator, terms: terms))
                    ActionButton(title: "Proposer cette paix", icon: "hand.raised", tint: Theme.teal) {
                        let wid = war.id
                        store.perform { s, p in s.proposePeace(warID: wid, from: p, terms: terms) }
                    }
                }
            }
        }
    }

    private func joinBlock(_ war: War) -> some View {
        let asAttacker = war.attackers.contains(player)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Rejoindre : \(war.name)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
            EvaluationView(evaluation: sim.evaluateJoinWar(country: target, warID: war.id, asAttacker: asAttacker))
            ActionButton(title: "Lui demander d'entrer en guerre (10 d'influence)", icon: "flag.2.crossed") {
                let wid = war.id
                store.perform { s, p in s.askToJoinWar(country: target, warID: wid, requester: p) }
            }
        }
    }

    /// Cyberattaque et arme nucléaire.
    @ViewBuilder
    private func covertBlock(atWar: Bool) -> some View {
        let me = sim.state.countries[player]
        if me?.has(.cyberWarfare) ?? false {
            QuietButton(title: "Lancer une cyberattaque (15 d'influence)", icon: "network", tint: Theme.amber) {
                store.perform { s, p in s.cyberAttack(from: p, on: target) }
            }
        }
        if atWar && (me?.nuclearWarheads ?? 0) >= 10 {
            ActionButton(title: "Frappe nucléaire", icon: "exclamationmark.triangle.fill", tint: Theme.coral) {
                confirmNuclear = true
            }
            .confirmationDialog("Utiliser l'arme nucléaire contre \(sim.name(target)) ?", isPresented: $confirmNuclear,
                                titleVisibility: .visible) {
                Button("Lancer la frappe", role: .destructive) {
                    store.perform { s, p in s.nuclearStrike(from: p, on: target) }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Destruction massive, condamnation mondiale et riposte probable si l'ennemi ou ses alliés sont nucléaires.")
            }
        }
    }

    private var declareBlock: some View {
        let supporters = sim.defensiveSupporters(of: target, against: player)
        let justified = sim.isJustified(player, target)
        let nuclear = sim.isNuclearProtected(target, against: player)
        let ratio = sim.militaryPower(player) / max(sim.defensiveStrength(of: target, against: player), 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text(justified ? "Motif reconnu : revendication ou hostilité ouverte." : "Aucun motif légitime.")
                .font(Theme.small).foregroundStyle(justified ? Theme.amber : Theme.coral)
            Text("Rapport de force avec ses alliés probables : \(Fmt.number(ratio, 2))")
                .font(Theme.small).foregroundStyle(ratio >= 1.5 ? Theme.teal : Theme.coral)
            if nuclear {
                Text("☢️ Ce pays est protégé par l'arme nucléaire.").font(Theme.small).foregroundStyle(Theme.coral)
            }
            if !supporters.isEmpty {
                Text("Le défendraient : " + supporters.prefix(8).map { "\(sim.name($0.0)) (\(Fmt.pct($0.1, 0)))" }.joined(separator: ", ")
                     + (supporters.count > 8 ? " et \(supporters.count - 8) autres" : ""))
                    .font(Theme.small).foregroundStyle(Theme.steel)
            }
            ActionButton(title: "Déclarer la guerre", icon: "flame", tint: Theme.coral) {
                confirmWar = true
            }
        }
    }
}

// MARK: - Région touchée sur la carte

struct RegionCard: View {
    let sim: Simulation
    let province: Province
    let owner: ProvinceOwner

    var body: some View {
        Dossier(title: province.name, subtitle: status) {
            HStack(spacing: 8) {
                FlagBadge(id: province.country, size: 20)
                Text("Région historique de \(sim.name(province.country))").font(Theme.small).foregroundStyle(Theme.steel)
            }
        }
    }

    private var status: String {
        switch owner.status {
        case .core: return "Contrôlée par \(sim.name(province.country))."
        case .occupied: return "Occupée par \(sim.name(owner.owner ?? "")) : la guerre décidera de son sort."
        case .annexed: return "Annexée par \(sim.name(owner.owner ?? ""))."
        case .rebel: return "Aux mains des rebelles."
        case .neutral: return "Territoire neutre."
        }
    }
}

// MARK: - Factions

struct FactionInvite: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let player: CountryID
    let target: CountryID

    var body: some View {
        if let mine = sim.faction(of: player), sim.factionLeader(mine) == player, sim.faction(of: target) == nil {
            Dossier(title: "Inviter dans \(mine.name)") {
                EvaluationView(evaluation: sim.evaluateFactionJoin(country: target, bloc: mine))
                ActionButton(title: "Envoyer l'invitation (15 d'influence)", icon: "person.badge.plus", tint: Theme.teal) {
                    store.perform { s, p in s.inviteToFaction(target, by: p) }
                }
            }
        } else if sim.faction(of: player) == nil, let theirs = sim.faction(of: target), sim.factionLeader(theirs) == target {
            Dossier(title: "Rejoindre \(theirs.name)") {
                EvaluationView(evaluation: sim.evaluateFactionAdmission(applicant: player, bloc: theirs))
                ActionButton(title: "Demander l'adhésion (20 d'influence)", icon: "person.badge.plus", tint: Theme.teal) {
                    let id = theirs.id
                    store.perform { s, p in s.requestJoinFaction(id, by: p) }
                }
            }
        }
    }
}
