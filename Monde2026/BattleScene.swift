import SwiftUI
import UIKit

// =============================================================
//  BattleScene.swift
//  Le combat, lisible d'un coup d'œil :
//   - l'arène : les divisions des deux camps face à face (un
//     pictogramme par division), leur moral qui baisse en direct,
//     le duel des tactiques au centre, la corde du rapport de force,
//   - « pourquoi » en 3 images : les facteurs qui pèsent le plus,
//   - le rapport après bataille (pertes, raisons, conseil).
// =============================================================

// MARK: - Forces engagées

extension Simulation {
    /// Divisions engagées de chaque côté d'une bataille, par type.
    func battleForces(_ b: Battle) -> (attack: [DivisionType: Int], defense: [DivisionType: Int]) {
        var att: [DivisionType: Int] = [:], def: [DivisionType: Int] = [:]
        let foes = enemies(of: b.defender)
        for a in state.armies {
            if a.engaged && a.path.first == b.province && foes.contains(a.side) {
                for (t, n) in a.divisions { att[t, default: 0] += n }
            } else if a.province == b.province && isFriendly(b.defender, a.side) {
                for (t, n) in a.divisions { def[t, default: 0] += n }
            }
        }
        return (att, def)
    }
}

/// Pictogrammes des types de division (les mêmes que sur les pions de la carte).
enum UnitIcons {
    private static let images: [DivisionType: UIImage] = {
        var out: [DivisionType: UIImage] = [:]
        let size = CGSize(width: 26, height: 18)
        for t in DivisionType.allCases {
            let r = UIGraphicsImageRenderer(size: size)
            out[t] = r.image { ctx in
                UnitArt.draw(t, in: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1), context: ctx.cgContext)
            }.withRenderingMode(.alwaysTemplate)
        }
        return out
    }()

    static func image(_ t: DivisionType) -> Image {
        Image(uiImage: images[t] ?? UIImage())
    }
}

// MARK: - L'arène

struct BattleArena: View {
    let battle: Battle
    let attack: [DivisionType: Int]
    let defense: [DivisionType: Int]
    let side: Int
    let attackerName: String
    let defenderName: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                column(title: "Attaque", id: battle.attacker, name: attackerName, divisions: attack,
                       org: battle.attackerOrg, isPlayer: side == 1, garrison: false, trailing: false)
                duel
                column(title: "Défense", id: battle.defender, name: defenderName, divisions: defense,
                       org: battle.defenderOrg, isPlayer: side == -1, garrison: defense.isEmpty, trailing: true)
            }
            TugOfWar(balance: battle.balance, attacker: battle.attacker, defender: battle.defender, side: side)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(uiColor: Theme.politicalColor(battle.attacker)).opacity(0.22), Theme.deep.opacity(0.9),
                                    Color(uiColor: Theme.politicalColor(battle.defender)).opacity(0.22)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    private func column(title: String, id: CountryID, name: String, divisions: [DivisionType: Int], org: Double,
                        isPlayer: Bool, garrison: Bool, trailing: Bool) -> some View {
        let list = DivisionType.allCases.flatMap { t in Array(repeating: t, count: divisions[t] ?? 0) }
        let shown = Array(list.prefix(30))
        let tint = Color(uiColor: Theme.politicalColor(id))
        let columns = Array(repeating: GridItem(.fixed(22), spacing: 3), count: 5)
        return VStack(alignment: trailing ? .trailing : .leading, spacing: 8) {
            HStack(spacing: 6) {
                if trailing { Spacer(minLength: 0) }
                Text(Geo.flag(id)).font(.system(size: 18))
                VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
                    Text(title.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.steel)
                    Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .foregroundStyle(isPlayer ? Theme.amber : Theme.paper)
                }
                if !trailing { Spacer(minLength: 0) }
            }
            if garrison {
                Label("Garnison seule", systemImage: "shield.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.steel)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: trailing ? .trailing : .leading)
            } else {
                LazyVGrid(columns: columns, alignment: trailing ? .trailing : .leading, spacing: 3) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, t in
                        UnitIcons.image(t)
                            .resizable().scaledToFit()
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(2)
                            .frame(width: 22, height: 16)
                            .background(tint.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                            // Le moral en berne : les pictogrammes pâlissent.
                            .opacity(0.35 + 0.65 * org)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: trailing ? .topTrailing : .topLeading)
                if list.count > 30 {
                    Text("+\(list.count - 30) division\(list.count - 30 > 1 ? "s" : "")").font(.system(size: 10)).foregroundStyle(Theme.steel)
                }
            }
            VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
                Meter(value: org, tint: org < 0.3 ? Theme.coral : (org < 0.55 ? Theme.amber : Theme.teal), height: 7)
                    .animation(.easeInOut(duration: 0.6), value: org)
                Text("Moral \(Int((org * 100).rounded())) %").font(Theme.data(11, weight: .semibold))
                    .foregroundStyle(org < 0.3 ? Theme.coral : Theme.steel)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Au centre : les deux tactiques face à face, et qui contre qui.
    private var duel: some View {
        let a = battle.attackerTactic, d = battle.defenderTactic
        let attWins = a.beats.contains(d), defWins = d.beats.contains(a)
        return VStack(spacing: 6) {
            tacticBadge(a, winning: attWins, tint: Theme.coral)
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.amber)
                .symbolEffect(.pulse, options: .repeating)
            tacticBadge(d, winning: defWins, tint: Theme.teal)
            Text(attWins ? "L'attaque contre" : (defWins ? "La défense contre" : "Phase \(battle.phase)"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(attWins || defWins ? Theme.amber : Theme.steel)
                .multilineTextAlignment(.center)
            Text("encore \(battle.daysLeftInPhase) j").font(.system(size: 9)).foregroundStyle(Theme.steel)
        }
        .frame(width: 92)
    }

    private func tacticBadge(_ t: Tactic, winning: Bool, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: t.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(winning ? Theme.ink : tint)
                .frame(width: 38, height: 38)
                .background(winning ? Theme.amber : Color.white.opacity(0.08), in: Circle())
            Text(t.name).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Theme.paper)
                .lineLimit(2).multilineTextAlignment(.center)
        }
    }
}

/// La corde : où penche le rapport de force.
struct TugOfWar: View {
    let balance: Double
    let attacker: CountryID
    let defender: CountryID
    let side: Int

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color(uiColor: Theme.politicalColor(attacker))).frame(width: w * balance)
                        Rectangle().fill(Color(uiColor: Theme.politicalColor(defender)))
                    }
                    // Repère du centre et nœud de la corde
                    Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1).offset(x: w / 2)
                    Circle().fill(Color.white).frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .offset(x: w * balance - 7)
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: balance)
            HStack {
                Text("Force \(Int((balance * 100).rounded())) %")
                Spacer()
                Text(verdict).foregroundStyle(tint)
                Spacer()
                Text("\(Int(((1 - balance) * 100).rounded())) %")
            }
            .font(Theme.data(11, weight: .semibold))
            .foregroundStyle(Theme.steel)
        }
    }

    private var verdict: String {
        if balance > 0.66 { return "Percée en vue" }
        if balance > 0.52 { return "L'attaque progresse" }
        if balance > 0.48 { return "Équilibre" }
        if balance > 0.34 { return "La défense tient" }
        return "L'attaque s'enlise"
    }

    private var tint: Color {
        guard side != 0 else { return Theme.paper }
        return (side == 1) == (balance > 0.5) ? Theme.teal : Theme.coral
    }
}

// MARK: - Pourquoi (3 images)

struct WhyStrip: View {
    let factors: [BattleModifier]      // exprimés pour l'attaquant
    let side: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(factors, id: \.self) { f in
                let helpsAttack = f.value >= 1
                let good = side == 0 ? nil : (side == 1) == helpsAttack
                let tint = good == nil ? Theme.paper : (good! ? Theme.teal : Theme.coral)
                VStack(spacing: 5) {
                    Image(systemName: BattleAdvice.icon(f.name))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 40, height: 40)
                        .background(tint.opacity(0.14), in: Circle())
                    Text(f.name).font(.system(size: 10.5, weight: .medium)).foregroundStyle(Theme.paper)
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
                    Text((helpsAttack ? "Aide l'attaque " : "Aide la défense ") + percent(f.value))
                        .font(Theme.data(10, weight: .semibold)).foregroundStyle(tint)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 112)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func percent(_ v: Double) -> String {
        let p = Int((abs(v - 1) * 100).rounded())
        return "\(p) %"
    }
}

// MARK: - Rapport après bataille

struct ReportNotice: View {
    let report: BattleReport
    let open: () -> Void

    var body: some View {
        let won = report.attackerWon == (report.playerSide == 1)
        Button(action: open) {
            HStack(spacing: 10) {
                Image(systemName: won ? "flag.checkered" : "flag.slash.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(won ? Theme.teal : Theme.coral)
                VStack(alignment: .leading, spacing: 1) {
                    Text((won ? "Victoire à " : "Défaite à ") + ProvinceMap.all[report.province].name)
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text("Voir le rapport : pertes, raisons, conseil").font(.system(size: 11)).foregroundStyle(Theme.steel)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.steel)
            }
            .padding(12)
            .glass(16)
        }
        .buttonStyle(.plain)
    }
}

struct BattleReportPanel: View {
    @ObservedObject var store: GameStore
    let reportID: Int

    var body: some View {
        if let sim = store.sim, let r = sim.state.reports.first(where: { $0.id == reportID }) {
            let won = r.attackerWon == (r.playerSide == 1)
            let place = ProvinceMap.all[r.province].name
            VStack(alignment: .leading, spacing: 14) {
                PanelHeader(title: (won ? "Victoire à " : "Défaite à ") + place,
                            subtitle: "\(r.days) jour\(r.days > 1 ? "s" : "") de combats · \(sim.dateString(forDay: r.day))") {
                    store.panel = nil
                }
                HStack(spacing: 10) {
                    Image(systemName: won ? "flag.checkered" : "flag.slash.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(won ? Theme.teal : Theme.coral)
                    Text(summary(r, sim)).font(.system(size: 14)).foregroundStyle(Theme.paper)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.deep.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Dossier(title: "Pertes") {
                    lossRow(r.attacker, sim.name(r.attacker), r.attackerLosses, r.attackerDivisions,
                            max(r.attackerLosses, r.defenderLosses))
                    lossRow(r.defender, sim.name(r.defender), r.defenderLosses, r.defenderDivisions,
                            max(r.attackerLosses, r.defenderLosses))
                }
                Text("Pourquoi").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                WhyStrip(factors: r.reasons, side: r.playerSide)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 18)).foregroundStyle(Theme.amber)
                    Text(r.advice).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.amber.opacity(0.4)))
            }
        } else {
            PanelHeader(title: "Rapport indisponible", subtitle: nil) { store.panel = nil }
        }
    }

    private func summary(_ r: BattleReport, _ sim: Simulation) -> String {
        let place = ProvinceMap.all[r.province].name
        if r.attackerWon {
            return "\(sim.name(r.attacker)) prend \(place)" + (r.breakthrough ? " d'un coup : c'est une percée." : ".")
        }
        return "\(sim.name(r.defender)) tient \(place) : l'attaque de \(sim.name(r.attacker)) est repoussée."
    }

    private func lossRow(_ id: CountryID, _ name: String, _ losses: Double, _ divisions: Int, _ top: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(Geo.flag(id)) \(name)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text(Fmt.count(losses * 1000) + " hommes").font(Theme.data(12, weight: .semibold)).foregroundStyle(Theme.coral)
            }
            Meter(value: top > 0 ? losses / top : 0, tint: Theme.coral, height: 6)
            Text(divisions > 0 ? "\(divisions) divisions engagées" : "Garnison").font(.system(size: 10)).foregroundStyle(Theme.steel)
        }
    }
}
