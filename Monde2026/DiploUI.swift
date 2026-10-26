import SwiftUI

// =============================================================
//  DiploUI.swift
//  Les actions diplomatiques à portée de pouce : une barre
//  d'icônes en haut de la fiche d'un pays. Chaque icône ouvre
//  un petit panneau avec la réponse probable et les options
//  (date, en secret ou en public, quantité…).
// =============================================================

enum DiploAction: String, CaseIterable, Identifiable, Hashable {
    case war, treaties, aid, joint, arms, factories, expedition, betray, ultimatum, pressure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .war: return "Guerre"
        case .treaties: return "Traités"
        case .joint: return "Attaque à deux"
        case .arms: return "Armes"
        case .factories: return "Usines"
        case .expedition: return "Troupes"
        case .betray: return "Trahir"
        case .ultimatum: return "Ultimatum"
        case .pressure: return "Pression"
        case .aid: return "Aide et paix"
        }
    }

    var icon: String {
        switch self {
        case .war: return "flame.fill"
        case .treaties: return "signature"
        case .joint: return "person.2.wave.2.fill"
        case .arms: return "shippingbox.fill"
        case .factories: return "building.2.fill"
        case .expedition: return "figure.walk.departure"
        case .betray: return "theatermask.and.paintbrush.fill"
        case .ultimatum: return "exclamationmark.bubble.fill"
        case .pressure: return "hand.raised.fill"
        case .aid: return "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .war, .ultimatum, .betray: return Theme.coral
        case .treaties, .joint: return Theme.teal
        case .arms, .factories, .expedition: return Theme.amber
        case .pressure: return Theme.sky
        case .aid: return Theme.teal
        }
    }
}

/// Barre d'actions en haut de la fiche d'un pays étranger.
struct QuickDiplomacyBar: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let target: CountryID

    var body: some View {
        let actions = DiploAction.allCases.filter { visible($0) }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 6) {
            ForEach(actions) { a in
                Button { store.open(.diplo(target, a)) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: a.icon).font(.system(size: 16, weight: .semibold))
                        Text(a.title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(a.tint)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(a.tint.opacity(0.12), in: HUDShape(cut: 7))
                }
                .buttonStyle(Pressable())
            }
        }
    }

    private func visible(_ a: DiploAction) -> Bool {
        guard let p = store.playerID else { return false }
        switch a {
        case .betray: return !sim.proxyRegions(for: target).isEmpty
        case .ultimatum: return !sim.ultimatumTargets(target).isEmpty && !sim.enemies(of: p).contains(target)
        case .joint: return !sim.enemies(of: p).contains(target)
        case .arms, .factories, .expedition: return !sim.enemies(of: p).contains(target)
        default: return true
        }
    }
}

/// Le panneau d'une action : explication, options, réponse probable, bouton.
struct DiploActionPanel: View {
    @ObservedObject var store: GameStore
    let target: CountryID
    let action: DiploAction
    @State private var covert = true
    @State private var share = 0.1
    @State private var months = 6
    @State private var days = 60
    @State private var jointTarget: CountryID = ""
    @State private var armyID = -1
    @State private var region = -1

    var body: some View {
        let _ = store.version
        if let sim = store.sim, let p = store.playerID, let t = sim.state.countries[target] {
            PanelHeader(title: action.title, subtitle: t.name, flag: target) { store.panel = nil }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DiploAction.allCases) { a in
                        Button { store.panel = .diplo(target, a) } label: {
                            Label(a.title, systemImage: a.icon).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(a == action ? Theme.ink : Theme.paper)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(a == action ? a.tint : Color.white.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(Pressable())
                    }
                }
            }
            switch action {
            case .war:
                WarActions(store: store, sim: sim, player: p, target: target)
            case .treaties:
                DiplomaticActions(store: store, sim: sim, player: p, target: target)
            case .joint: joint(sim, p)
            case .arms: arms(sim, p)
            case .factories: factories(sim, p)
            case .expedition: expedition(sim, p)
            case .betray: betray(sim, p)
            case .ultimatum: ultimatum(sim, p)
            case .pressure:
                CovertOpsCard(store: store, sim: sim, player: p, target: target)
                UNCard(store: store, sim: sim, player: p, target: target)
            case .aid: aid(sim, p)
            }
        }
    }

    // MARK: Aide, sommet, médiation

    @ViewBuilder
    private func aid(_ sim: Simulation, _ p: CountryID) -> some View {
        let wait = sim.summitCooldown(p, target)
        Dossier(title: "Sommet", subtitle: "Une rencontre au plus haut niveau : rapproche vite (une fois par an, 15 d'influence).") {
            ActionButton(title: wait > 0 ? "Prochain sommet dans \(wait) j" : "Organiser un sommet", icon: "person.2.fill",
                         tint: Theme.teal, enabled: wait == 0) {
                let t = target
                store.perform { s, _ in s.summit(with: t) }
            }
        }
        Dossier(title: "Aide humanitaire", subtitle: "Stabilise le pays et améliore les relations. Ses amis apprécient, ses ennemis non.") {
            Picker("Montant", selection: $share) {
                Text("1 Md$").tag(1.0)
                Text("5 Md$").tag(5.0)
                Text("20 Md$").tag(20.0)
            }
            .pickerStyle(.segmented)
            ActionButton(title: "Envoyer l'aide", icon: "heart.fill", tint: Theme.teal) {
                let t = target, amount = [1.0, 5.0, 20.0].contains(share) ? share : 1.0
                store.perform { s, _ in s.humanitarianAid(to: t, amount: amount) }
            }
        }
        let wars = sim.mediableWars(target)
        Dossier(title: "Médiation de paix", subtitle: wars.isEmpty ? "\(sim.name(target)) n'est pas en guerre." :
                    "Proposez-vous comme médiateur (25 d'influence). Plus ils sont las de la guerre, plus ils écoutent.") {
            ForEach(wars) { w in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                        Text("Chances : \(Int(sim.mediationChance(w) * 100)) %").font(Theme.small).foregroundStyle(Theme.steel)
                    }
                    Spacer()
                    QuietButton(title: "Proposer", icon: "hand.wave.fill", tint: Theme.teal) {
                        let id = w.id
                        store.perform { s, _ in s.mediate(id) }
                    }
                }
            }
        }
    }

    // MARK: Attaque conjointe

    @ViewBuilder
    private func joint(_ sim: Simulation, _ p: CountryID) -> some View {
        let candidates = sim.countryIDs.filter { $0 != p && $0 != target && sim.state.countries[$0] != nil }
            .sorted { sim.relation(target, $0) < sim.relation(target, $1) }
            .prefix(14)
        let chosen = candidates.contains(jointTarget) ? jointTarget : (candidates.first ?? "")
        Dossier(title: "Attaquer ensemble", subtitle: "\(sim.name(target)) et vous déclarez la guerre au même pays, à une date convenue. Ne trahissez pas votre parole.") {
            Text("Cible").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.steel)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(candidates), id: \.self) { c in
                        Button { jointTarget = c } label: {
                            HStack(spacing: 6) {
                                Text(Geo.flag(c))
                                Text(sim.name(c)).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                            }
                            .foregroundStyle(chosen == c ? Theme.ink : Theme.paper)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(chosen == c ? Theme.coral : Color.white.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(Pressable())
                    }
                }
            }
            Text("Jour J").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.steel)
            Picker("Date", selection: $days) {
                Text("Dans 1 mois").tag(30)
                Text("2 mois").tag(60)
                Text("3 mois").tag(90)
                Text("6 mois").tag(180)
            }
            .pickerStyle(.segmented)
            if !chosen.isEmpty {
                EvaluationView(evaluation: sim.evaluateJointAttack(partner: target, target: chosen, from: p))
                ActionButton(title: "Proposer (20 d'influence)", icon: "paperplane.fill", tint: Theme.teal) {
                    let partner = target, foe = chosen, d = days
                    store.perform { s, _ in s.proposeJointAttack(partner: partner, target: foe, inDays: d) }
                }
            }
            ForEach(sim.state.jointPlans.filter { $0.partner == target }) { plan in
                Label("Prévu : attaque de \(sim.name(plan.target)) dans \(max(0, plan.day - sim.state.day)) jours",
                      systemImage: "calendar.badge.clock")
                    .font(Theme.small).foregroundStyle(Theme.amber)
            }
        }
    }

    // MARK: Armes et usines

    private var modeToggle: some View {
        Picker("Mode", selection: $covert) {
            Label("En secret", systemImage: "eye.slash").tag(true)
            Label("En public", systemImage: "megaphone").tag(false)
        }
        .pickerStyle(.segmented)
    }

    private var modeHint: some View {
        Text(covert
             ? "En secret : ses ennemis ne vous en veulent pas… sauf si leurs espions découvrent l'affaire (scandale)."
             : "En public : tout le monde le sait. Ses ennemis vous en veulent tout de suite, mais votre parole compte.")
            .font(.system(size: 11)).foregroundStyle(Theme.steel)
    }

    @ViewBuilder
    private func arms(_ sim: Simulation, _ p: CountryID) -> some View {
        Dossier(title: "Livrer des armes", subtitle: "Une part de vos stocks : équipement, blindés, artillerie, drones, missiles.") {
            Picker("Part", selection: $share) {
                Text("5 %").tag(0.05)
                Text("10 %").tag(0.1)
                Text("20 %").tag(0.2)
            }
            .pickerStyle(.segmented)
            modeToggle
            modeHint
            ActionButton(title: "Livrer", icon: "shippingbox.fill") {
                let t = target, sh = share, c = covert
                store.perform { s, _ in s.sendArms(to: t, share: sh, covert: c) }
            }
        }
    }

    @ViewBuilder
    private func factories(_ sim: Simulation, _ p: CountryID) -> some View {
        let mine = sim.state.countries[p]?.militaryFactories ?? 0
        Dossier(title: "Prêter des usines d'armement", subtitle: "Elles produisent pour lui, puis vous reviennent. Vous en avez \(Int(mine)).") {
            Picker("Part", selection: $share) {
                Text("10 %").tag(0.1)
                Text("25 %").tag(0.25)
                Text("40 %").tag(0.4)
            }
            .pickerStyle(.segmented)
            Picker("Durée", selection: $months) {
                Text("6 mois").tag(6)
                Text("1 an").tag(12)
                Text("2 ans").tag(24)
            }
            .pickerStyle(.segmented)
            modeToggle
            modeHint
            ActionButton(title: "Prêter \(Int((mine * share).rounded())) usines", icon: "building.2.fill") {
                let t = target, sh = share, m = months, c = covert
                store.perform { s, _ in s.lendFactories(to: t, share: sh, months: m, covert: c) }
            }
            ForEach(sim.state.leases.filter { $0.to == target }) { l in
                Text("\(Int(l.factories)) usines prêtées, retour dans \(max(0, l.untilDay - sim.state.day)) jours")
                    .font(Theme.small).foregroundStyle(Theme.amber)
            }
        }
    }

    // MARK: Corps expéditionnaire

    @ViewBuilder
    private func expedition(_ sim: Simulation, _ p: CountryID) -> some View {
        let mine = sim.armies(of: p).filter { $0.servingFor == nil }
        let serving = sim.armies(of: p).filter { $0.servingFor == target }
        let chosen = mine.contains { $0.id == armyID } ? armyID : (mine.first?.id ?? -1)
        Dossier(title: "Envoyer des troupes",
                subtitle: "Votre armée combat pour \(sim.name(target)) sans que vous soyez en guerre. Ses conquêtes vont à \(sim.name(target)) — rayées de bleu pour vous : vous pourrez les reprendre en trahissant.") {
            if mine.isEmpty {
                Text("Aucune armée disponible.").font(Theme.small).foregroundStyle(Theme.steel)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(mine) { a in
                            Button { armyID = a.id } label: {
                                HStack(spacing: 6) {
                                    UnitSymbol(type: a.mainType, color: Color(uiColor: Theme.politicalColor(p)), size: 20)
                                    Text("\(a.name) · \(a.count)").font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(chosen == a.id ? Theme.ink : Theme.paper)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(chosen == a.id ? Theme.amber : Color.white.opacity(0.07), in: Capsule())
                            }
                            .buttonStyle(Pressable())
                        }
                    }
                }
                modeToggle
                Text(covert
                     ? "« Volontaires » : l'ennemi l'ignore tant qu'il ne les démasque pas au combat."
                     : "Officiel : vous gagnez du prestige, mais ses ennemis peuvent vous déclarer la guerre.")
                    .font(.system(size: 11)).foregroundStyle(Theme.steel)
                ActionButton(title: "Envoyer", icon: "figure.walk.departure", enabled: chosen >= 0) {
                    let id = chosen, t = target, c = covert
                    store.perform { s, _ in s.sendExpedition(id, to: t, covert: c) }
                }
            }
            ForEach(serving) { a in
                HStack {
                    Label("\(a.name) combat ici\(a.covert ? " (secret)" : "")", systemImage: a.covert ? "eye.slash" : "megaphone")
                        .font(Theme.small).foregroundStyle(Theme.amber)
                    Spacer()
                    Button("Rappeler") { store.perform { s, _ in s.recallExpedition(a.id) } }
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.paper)
                }
            }
        }
    }

    // MARK: Trahison

    @ViewBuilder
    private func betray(_ sim: Simulation, _ p: CountryID) -> some View {
        let regions = sim.proxyRegions(for: target)
        Dossier(title: "Garder nos conquêtes", subtitle: "Nos troupes ont pris ces régions pour \(sim.name(target)). Elles peuvent passer sous notre drapeau… au prix de son amitié, et peut-être d'une guerre.") {
            ForEach(regions, id: \.self) { r in
                Label(ProvinceMap.all[r].name, systemImage: "flag.fill").font(.system(size: 13)).foregroundStyle(Theme.paper)
            }
            ActionButton(title: "Trahir \(sim.name(target))", icon: "theatermask.and.paintbrush.fill", tint: Theme.coral, enabled: !regions.isEmpty) {
                let t = target
                store.perform { s, _ in s.betray(t) }
            }
        }
    }

    // MARK: Ultimatum

    @ViewBuilder
    private func ultimatum(_ sim: Simulation, _ p: CountryID) -> some View {
        let options = sim.ultimatumTargets(target)
        let chosen = options.contains(region) ? region : (options.first ?? -1)
        Dossier(title: "Exiger une région", subtitle: "S'il a peur de vous, il cède sans combattre. Sinon, vous gagnez un motif de guerre.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { r in
                        Button { region = r } label: {
                            Text(ProvinceMap.all[r].name).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(chosen == r ? Theme.ink : Theme.paper)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(chosen == r ? Theme.coral : Color.white.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(Pressable())
                    }
                }
            }
            EvaluationView(evaluation: sim.evaluateUltimatum(target: target, from: p))
            ActionButton(title: "Lancer l'ultimatum", icon: "exclamationmark.bubble.fill", tint: Theme.coral, enabled: chosen >= 0) {
                let t = target, r = chosen
                store.perform { s, _ in s.ultimatum(target: t, province: r) }
            }
        }
    }
}
