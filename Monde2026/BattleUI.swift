import SwiftUI

// =============================================================
//  BattleUI.swift
//  L'interface de la guerre, pensée pour le doigt :
//   - la fiche d'armée (général, posture, ravitaillement,
//     planification, ordres groupés),
//   - la fiche de bataille (rapport de force, tactiques à
//     choisir comme des cartes, modificateurs, frappes, renforts),
//   - la liste des batailles en cours.
// =============================================================

// MARK: - Fiche d'une armée (sur la carte)

struct ArmyCard: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let id = store.selectedArmy, let a = sim.state.armies.first(where: { $0.id == id }) {
            let mine = a.owner == store.playerID
            VStack(alignment: .leading, spacing: 10) {
                header(sim, a)
                GeneralRow(general: a.general)
                HStack(spacing: 10) {
                    Gauge2(label: "Moral", value: a.organization, tint: a.organization < 0.4 ? Theme.coral : Theme.teal)
                    Gauge2(label: "Ravitaillement", value: a.supply,
                           tint: a.supply <= 0.15 ? Theme.coral : (a.supply < 0.6 ? Theme.amber : Theme.teal))
                    Gauge2(label: "Plan d'attaque", value: a.planning, tint: Theme.sky)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sim.armyPower(a))").font(Theme.data(17, weight: .bold)).foregroundStyle(Theme.amber)
                        Text("Puissance").font(.system(size: 10)).foregroundStyle(Theme.steel)
                    }
                }
                CompositionRow(divisions: a.divisions)
                if mine {
                    StancePicker(current: a.stance) { stance in
                        let ids = [id] + store.armyGroup.sorted()
                        store.mutate { $0.setStance(stance, for: ids) }
                    }
                    if !store.armyGroup.isEmpty {
                        HStack {
                            Label("Groupe : \(store.armyGroup.count + 1) armées — les ordres s'appliquent à toutes",
                                  systemImage: "square.stack.3d.up.fill")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber)
                            Spacer()
                            Button("Défaire") { store.clearGroup() }
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.paper)
                        }
                    }
                    Text(hint(a)).font(Theme.small).foregroundStyle(Theme.steel).lineLimit(2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let target = a.path.first, sim.state.battles[target] != nil {
                                QuietButton(title: "Voir la bataille", icon: "flame.fill", tint: Theme.coral) { store.openBattle(target) }
                            } else if sim.state.battles[a.province] != nil {
                                QuietButton(title: "Voir la bataille", icon: "flame.fill", tint: Theme.coral) { store.openBattle(a.province) }
                            }
                            if !a.path.isEmpty {
                                QuietButton(title: "Arrêter", icon: "stop.fill") {
                                    let ids = [id] + store.armyGroup.sorted()
                                    store.mutate { s in for x in ids { s.stopArmy(x) } }
                                }
                            }
                            QuietButton(title: "+ Voisines", icon: "plus.circle") { store.groupNearby() }
                            QuietButton(title: "Tout le front", icon: "rectangle.3.group") { store.groupFront() }
                            QuietButton(title: "Diviser", icon: "square.split.2x1") {
                                store.perform { s, _ in s.splitArmy(id) }
                            }
                            if sim.playerArmies(in: a.province).count > 1 {
                                QuietButton(title: "Regrouper ici", icon: "square.stack.3d.up") {
                                    store.perform { s, _ in s.mergeArmies(at: id) }
                                }
                            }
                            QuietButton(title: "En garnison", icon: "house", tint: Theme.coral) {
                                store.mutate { $0.dissolveArmy(id) }
                                store.clearSelection()
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: 640)
            .glass(24)
        }
    }

    private func header(_ sim: Simulation, _ a: Army) -> some View {
        HStack(spacing: 12) {
            Text(Geo.flag(a.owner)).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(a.name).font(Theme.title(19)).foregroundStyle(Theme.paper)
                HStack(spacing: 6) {
                    let t = TerrainMap.terrain(a.province)
                    Image(systemName: t.icon).font(.system(size: 10))
                    Text(sim.armyStatus(a)).lineLimit(1)
                }
                .font(Theme.small)
                .foregroundStyle(a.engaged || a.supply <= 0.15 ? Theme.coral : Theme.steel)
            }
            Spacer(minLength: 8)
            Text("\(a.count) div.").font(Theme.data(14, weight: .semibold)).foregroundStyle(Theme.paper)
            Button { store.clearSelection() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Désélectionner l'armée")
        }
    }

    private func hint(_ a: Army) -> String {
        if a.supply <= 0.15 { return "Encerclée : reprenez une région voisine pour rouvrir la route, ou percez vers vos lignes." }
        if a.path.isEmpty {
            return "Touchez une région : ami = déplacement, ennemi voisin = attaque, ennemi lointain = offensive région par région (trait rouge)."
        }
        return "Touchez une autre région pour changer d'objectif. Un plan d'attaque complet donne jusqu'à +25 %."
    }
}

struct GeneralRow: View {
    let general: General

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: general.trait.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(Theme.amber, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(general.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text(general.stars).font(.system(size: 11)).foregroundStyle(Theme.amber)
                }
                Text("\(general.trait.name) · \(general.trait.summary)").font(.system(size: 11)).foregroundStyle(Theme.steel)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if general.skill < 5 {
                Meter(value: general.xp / max(1, general.nextLevelXP), tint: Theme.amber, height: 4)
                    .frame(width: 44)
                    .accessibilityLabel("Expérience")
            }
        }
    }
}

struct Gauge2: View {
    let label: String
    let value: Double
    var tint: Color = Theme.teal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(Fmt.pct(value, 0)).font(Theme.data(13, weight: .semibold)).foregroundStyle(tint)
            }
            Meter(value: value, tint: tint, height: 5)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.steel).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompositionRow: View {
    let divisions: [DivisionType: Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DivisionType.allCases.filter { (divisions[$0] ?? 0) > 0 }, id: \.self) { t in
                HStack(spacing: 4) {
                    Image(systemName: t.icon).font(.system(size: 10, weight: .semibold))
                    Text("\(divisions[t] ?? 0)").font(Theme.data(12, weight: .semibold))
                    Text(t.short).font(.system(size: 10))
                }
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.07), in: Capsule())
            }
        }
    }
}

struct StancePicker: View {
    let current: ArmyStance
    let pick: (ArmyStance) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ArmyStance.allCases, id: \.self) { s in
                Button { pick(s) } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 5) {
                            Image(systemName: s.icon)
                            Text(s.name)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        Text(detail(s)).font(.system(size: 9.5)).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(current == s ? Theme.ink : Theme.paper)
                    .background(current == s ? tint(s) : Color.white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Posture \(s.name)")
            }
        }
    }

    private func tint(_ s: ArmyStance) -> Color {
        switch s {
        case .defend: return Theme.teal
        case .balanced: return Theme.paper
        case .assault: return Theme.coral
        }
    }

    private func detail(_ s: ArmyStance) -> String {
        switch s {
        case .defend: return "déf. +15 %, att. −25 %"
        case .balanced: return "polyvalent"
        case .assault: return "att. +15 %, pertes +30 %"
        }
    }
}

extension DivisionType {
    var icon: String {
        switch self {
        case .infantry: return "figure.walk"
        case .mechanized: return "car.fill"
        case .armored: return "shield.checkered"
        case .airborne: return "parachute.fill"
        case .marines: return "water.waves"
        }
    }

    var short: String {
        switch self {
        case .infantry: return "inf."
        case .mechanized: return "méca."
        case .armored: return "blindés"
        case .airborne: return "aéro."
        case .marines: return "marine"
        }
    }
}

// MARK: - Fiche de bataille

struct BattlePanel: View {
    @ObservedObject var store: GameStore
    let province: Int

    var body: some View {
        let _ = store.version
        if let sim = store.sim {
            let p = ProvinceMap.all[province]
            let terrain = TerrainMap.terrain(province)
            let weather = sim.weather(at: province)
            VStack(alignment: .leading, spacing: 14) {
                PanelHeader(title: "Bataille de \(p.name)",
                            subtitle: TerrainMap.city(province).map { "Autour de \($0)" } ?? p.countryName) { store.panel = nil }
                HStack(spacing: 8) {
                    Tag(icon: terrain.icon, text: terrain.name)
                    Tag(icon: weather.icon, text: weather.name, tint: weather == .clear ? Theme.steel : Theme.amber)
                    Spacer()
                    SpeedControl(store: store)
                }
                if let b = sim.state.battles[province] {
                    content(sim, b)
                } else {
                    Dossier(title: "La bataille est terminée") {
                        Text("Plus aucune armée ne combat pour \(p.name). Elle est tenue par \(sim.name(sim.controller(of: province))).")
                            .font(Theme.body).foregroundStyle(Theme.paper.opacity(0.85))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ sim: Simulation, _ b: Battle) -> some View {
        let side = sim.playerSide(in: b)
        let rivers = sim.state.armies.contains { $0.path.first == province && $0.engaged && TerrainMap.river($0.province, province) }
        if rivers {
            Tag(icon: "water.waves", text: "Attaque à travers un fleuve", tint: Theme.sky)
        }
        BalanceBar(battle: b, playerSide: side)
        HStack(alignment: .top, spacing: 10) {
            SideCard(title: "Attaquant", id: b.attacker, name: sim.name(b.attacker), general: b.attackerGeneral,
                     divisions: b.attackerDivisions, org: b.attackerOrg, losses: b.attackerLosses, isPlayer: side == 1)
            SideCard(title: "Défenseur", id: b.defender, name: sim.name(b.defender), general: b.defenderGeneral,
                     divisions: b.defenderDivisions, org: b.defenderOrg, losses: b.defenderLosses, isPlayer: side == -1)
        }
        Dossier(title: "Phase \(b.phase)", subtitle: "Nouvelle phase dans \(b.daysLeftInPhase) j — chaque camp choisit une tactique") {
            HStack(spacing: 8) {
                TacticTile(tactic: b.attackerTactic, highlight: b.attackerTactic.beats.contains(b.defenderTactic))
                Text("contre").font(Theme.small).foregroundStyle(Theme.steel)
                TacticTile(tactic: b.defenderTactic, highlight: b.defenderTactic.beats.contains(b.attackerTactic))
            }
        }
        if side != 0, let options = playerOptions(sim, b, side: side), !options.isEmpty {
            Dossier(title: "Votre prochaine tactique",
                    subtitle: "Choisissez-la, ou laissez faire votre général. L'adversaire voit votre tactique actuelle : changez-en.") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(options) { t in
                        TacticChoice(tactic: t, selected: b.playerPick == t,
                                     beatsCurrent: t.beats.contains(side == 1 ? b.defenderTactic : b.attackerTactic)) {
                            store.perform { s, _ in s.pickTactic(t, at: province) }
                        }
                    }
                }
            }
        }
        if side != 0 {
            HStack(spacing: 8) {
                ActionButton(title: "Frappes aériennes", icon: "airplane", tint: Theme.sky,
                             enabled: sim.state.day > b.airStrikeUntil + 10) {
                    store.perform { s, _ in s.callAirStrike(at: province) }
                }
                ActionButton(title: "Renforts", icon: "plus.circle.fill", tint: Theme.teal) {
                    store.perform { s, _ in s.reinforceBattle(at: province) }
                }
                ActionButton(title: side == 1 ? "Arrêter" : "Se replier", icon: "arrow.uturn.backward", tint: Theme.coral) {
                    store.perform { s, _ in s.retreatFromBattle(at: province) }
                }
            }
        }
        HStack(alignment: .top, spacing: 10) {
            ModifierList(title: "Attaque", mods: b.attackMods)
            ModifierList(title: "Défense", mods: b.defenseMods)
        }
        if !b.log.isEmpty {
            Dossier(title: "Journal") {
                ForEach(Array(b.log.reversed().enumerated()), id: \.offset) { _, line in
                    Text(line).font(Theme.small).foregroundStyle(Theme.paper.opacity(0.85))
                }
            }
        }
    }

    private func playerOptions(_ sim: Simulation, _ b: Battle, side: Int) -> [Tactic]? {
        guard let p = sim.state.playerID else { return nil }
        if side == 1 {
            let mine = sim.state.armies.filter { $0.owner == p && $0.path.first == province && $0.engaged }
            guard !mine.isEmpty, b.attacker == p else { return nil }
            let all = sim.state.armies.filter { $0.path.first == province && $0.engaged }
            return sim.availableTactics(attacking: true, armies: all, owner: p, province: province,
                                        fronts: Set(all.map { $0.province }).count)
        }
        guard b.defender == p else { return nil }
        let mine = sim.state.armies.filter { $0.owner == p && $0.province == province }
        return sim.availableTactics(attacking: false, armies: mine, owner: p, province: province, fronts: 1)
    }
}

struct Tag: View {
    let icon: String
    let text: String
    var tint: Color = Theme.steel

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

struct BalanceBar: View {
    let battle: Battle
    let playerSide: Int

    var body: some View {
        let share = battle.balance
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.attacker)))
                        .frame(width: geo.size.width * share)
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.defender)))
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.white).frame(width: 2).offset(x: geo.size.width * share - 1)
                }
            }
            .frame(height: 16)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
            .animation(.snappy, value: share)
            HStack {
                Text("\(Geo.flag(battle.attacker)) \(Int((share * 100).rounded())) %")
                Spacer()
                Text(verdict).foregroundStyle(verdictTint)
                Spacer()
                Text("\(Int(((1 - share) * 100).rounded())) % \(Geo.flag(battle.defender))")
            }
            .font(Theme.data(13, weight: .semibold))
            .foregroundStyle(Theme.paper)
        }
    }

    private var verdict: String {
        let s = battle.balance
        if s > 0.62 { return "L'attaquant perce" }
        if s > 0.52 { return "L'attaquant progresse" }
        if s > 0.48 { return "Équilibre" }
        if s > 0.38 { return "La défense tient" }
        return "L'attaque s'enlise"
    }

    private var verdictTint: Color {
        guard playerSide != 0 else { return Theme.steel }
        let good = playerSide == 1 ? battle.balance > 0.5 : battle.balance < 0.5
        return good ? Theme.teal : Theme.coral
    }
}

struct SideCard: View {
    let title: String
    let id: CountryID
    let name: String
    let general: String
    let divisions: Int
    let org: Double
    let losses: Double
    let isPlayer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                FlagBadge(id: id, size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.steel)
                    Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(isPlayer ? Theme.amber : Theme.paper)
                        .lineLimit(1)
                }
            }
            Text(general).font(.system(size: 11)).foregroundStyle(Theme.steel).lineLimit(1)
            HStack {
                Readout(label: "Divisions", value: divisions > 0 ? "\(divisions)" : "garnison")
                Spacer()
                Readout(label: "Pertes", value: "\(Int(losses)) k", tint: Theme.coral)
            }
            VStack(alignment: .leading, spacing: 3) {
                Meter(value: org, tint: org < 0.3 ? Theme.coral : Theme.teal, height: 6)
                Text("Moral \(Fmt.pct(org, 0))\(org < 0.3 ? " — sur le point de céder" : "")")
                    .font(.system(size: 10)).foregroundStyle(org < 0.3 ? Theme.coral : Theme.steel)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.deep.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isPlayer ? Theme.amber.opacity(0.6) : Color.clear))
    }
}

struct TacticTile: View {
    let tactic: Tactic
    let highlight: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tactic.icon).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tactic.isAttack ? Theme.coral : Theme.teal)
            VStack(alignment: .leading, spacing: 1) {
                Text(tactic.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper).lineLimit(1)
                Text(highlight ? "Contre l'adversaire !" : tactic.summary).font(.system(size: 10))
                    .foregroundStyle(highlight ? Theme.amber : Theme.steel).lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(highlight ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(highlight ? Theme.amber : Color.clear))
    }
}

struct TacticChoice: View {
    let tactic: Tactic
    let selected: Bool
    let beatsCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: tactic.icon).font(.system(size: 14, weight: .semibold))
                    Text(tactic.name).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    if selected { Image(systemName: "checkmark.circle.fill") }
                }
                .foregroundStyle(selected ? Theme.ink : Theme.paper)
                Text(tactic.summary).font(.system(size: 10.5))
                    .foregroundStyle(selected ? Theme.ink.opacity(0.8) : Theme.steel)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("Bat : " + tactic.beats.map { $0.name }.joined(separator: ", "))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? Theme.ink : (beatsCurrent ? Theme.amber : Theme.teal))
                    .lineLimit(2)
                Text("Craint : " + tactic.weakAgainst.map { $0.name }.joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(selected ? Theme.ink.opacity(0.7) : Theme.coral.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(selected ? Theme.amber : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(beatsCurrent && !selected ? Theme.amber.opacity(0.7) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tactic.name)
    }
}

struct ModifierList: View {
    let title: String
    let mods: [BattleModifier]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
            ForEach(mods, id: \.self) { m in
                HStack(alignment: .firstTextBaseline) {
                    Text(m.name).font(.system(size: 11)).foregroundStyle(Theme.paper.opacity(0.85)).lineLimit(2)
                    Spacer(minLength: 4)
                    Text(percent(m.value)).font(Theme.data(11, weight: .semibold))
                        .foregroundStyle(m.value >= 1 ? Theme.teal : Theme.coral)
                }
            }
            if mods.isEmpty {
                Text("Aucun").font(.system(size: 11)).foregroundStyle(Theme.steel)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.deep.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func percent(_ v: Double) -> String {
        let p = Int(((v - 1) * 100).rounded())
        return p >= 0 ? "+\(p) %" : "\(p) %"
    }
}

// MARK: - Batailles en cours (panneau Armée)

struct BattlesCard: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim {
            let battles = sim.playerBattles()
            if !battles.isEmpty {
                Dossier(title: "Batailles en cours", subtitle: "Touchez une bataille pour choisir vos tactiques") {
                    ForEach(battles.prefix(12)) { b in
                        Button { store.openBattle(b.province) } label: {
                            BattleRow(battle: b, side: sim.playerSide(in: b))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct BattleRow: View {
    let battle: Battle
    let side: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: TerrainMap.terrain(battle.province).icon).font(.system(size: 12)).foregroundStyle(Theme.steel)
                Text(ProvinceMap.all[battle.province].name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("\(Geo.flag(battle.attacker)) \(battle.attackerDivisions) ⚔︎ \(battle.defenderDivisions) \(Geo.flag(battle.defender))")
                    .font(Theme.data(12, weight: .semibold)).foregroundStyle(Theme.paper)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.steel)
            }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.attacker))).frame(width: geo.size.width * battle.balance)
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.defender)))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
