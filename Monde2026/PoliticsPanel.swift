import SwiftUI

// =============================================================
//  PoliticsPanel.swift
//  Régime, stabilité, soutien, élections, libertés,
//  guerre civile et effets en cours.
// =============================================================

struct PoliticsPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Politique", subtitle: "\(c.government.name), \(c.ideology.name.lowercased()) au pouvoir", flag: c.id) {
                store.panel = nil
            }
            overview(sim, c)
            if c.civilWar > 0 { civilWar(sim, c) }
            FreedomCard(store: store, country: c)
            actions(c)
            modifiers(c)
        }
    }

    private func overview(_ sim: Simulation, _ c: Country) -> some View {
        let days = c.nextElectionDay - sim.state.day
        let election = c.government.holdsElections ? (days > 0 ? "dans \(days / 30) mois" : "imminentes") : "aucune"
        return Dossier(title: "État du pays") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Stabilité").font(.system(size: 14)).foregroundStyle(Theme.paper)
                    Spacer()
                    Text(Fmt.pct(c.stability, 0)).font(Theme.data(15, weight: .semibold))
                        .foregroundStyle(c.stability < 0.3 ? Theme.coral : Theme.paper)
                }
                Meter(value: c.stability, tint: c.stability < 0.3 ? Theme.coral : (c.stability < 0.5 ? Theme.amber : Theme.teal))
                HStack {
                    Text("Soutien au gouvernement").font(.system(size: 14)).foregroundStyle(Theme.paper)
                    Spacer()
                    Text(Fmt.pct(c.support, 0)).font(Theme.data(15, weight: .semibold))
                        .foregroundStyle(c.support < c.government.electionThreshold ? Theme.coral : Theme.paper)
                }
                Meter(value: c.support, tint: Theme.amber)
            }
            FigureGrid(items: [
                ("Prochaines élections", election, Theme.paper),
                ("Seuil de victoire", c.government.holdsElections ? Fmt.pct(c.government.electionThreshold, 0) : "—", Theme.steel),
                ("Production", "×" + Fmt.number(sim.stabilityFactor(c), 2), Theme.paper)
            ])
            Text(explanation(c)).font(Theme.small).foregroundStyle(Theme.steel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explanation(_ c: Country) -> String {
        if c.stability < 0.22 && c.government.coupProne {
            return "Danger : avec une stabilité aussi basse, l'armée peut tenter un coup d'État."
        }
        if c.stability < 0.12 {
            return "Danger : le pays peut basculer dans l'insurrection armée."
        }
        return "La stabilité dépend du soutien populaire, de l'économie, de la guerre et des libertés. Elle fait varier production, construction et recherche."
    }

    private func civilWar(_ sim: Simulation, _ c: Country) -> some View {
        let government = c.landStrengthIndex * 0.6
        let ratio = government / max(c.rebelStrength, 1)
        return Dossier(title: "Guerre civile", subtitle: "Les rebelles tiennent \(Fmt.pct(c.civilWar, 0)) du pays.") {
            Meter(value: c.civilWar / 0.65, tint: Theme.coral, height: 8)
            Text(ratio > 1.1 ? "Nos forces prennent l'avantage." : (ratio < 0.9 ? "Les rebelles progressent." : "Le front est figé."))
                .font(Theme.small).foregroundStyle(Theme.paper)
            Text("Si les rebelles tiennent 65 % du pays, le régime tombe.").font(Theme.small).foregroundStyle(Theme.steel)
            QuietButton(title: "Négocier un cessez-le-feu", icon: "hand.raised", tint: Theme.amber) {
                store.perform { s, p in s.negotiateWithRebels(for: p) }
            }
        }
    }

    private func actions(_ c: Country) -> some View {
        Dossier(title: "Décisions") {
            row("Campagne de communication", detail: "Soutien en hausse pendant 6 mois, coûte 0,1 % du PIB.", icon: "megaphone") {
                store.perform { s, p in s.propagandaCampaign(for: p) }
            }
            row("Réprimer l'opposition", detail: "Stabilité +, soutien −, les démocraties désapprouvent.", icon: "hand.raised.slash") {
                store.perform { s, p in s.crackdown(for: p) }
            }
            if c.government.holdsElections {
                row("Élections anticipées", detail: "Seuil : \(Fmt.pct(c.government.electionThreshold, 0)) de soutien. Gagnées : mandat renouvelé.",
                    icon: "checkmark.rectangle.stack") {
                    store.perform { s, p in s.callEarlyElections(for: p) }
                }
            }
            if c.government != .democracy {
                row("Démocratiser le régime", detail: "Stabilité −0,15 pendant un an, relations avec les démocraties +10.",
                    icon: "building.columns") {
                    store.perform { s, p in s.reformRegime(for: p, democratize: true) }
                }
            }
            if c.government == .democracy || c.government == .hybrid {
                row("Durcir le régime", detail: "Moins d'élections et de contre-pouvoirs ; soutien −, démocraties −15.",
                    icon: "lock.fill") {
                    store.perform { s, p in s.reformRegime(for: p, democratize: false) }
                }
            }
        }
    }

    private func modifiers(_ c: Country) -> some View {
        Dossier(title: "Effets en cours", subtitle: c.modifiers.isEmpty ? "Aucun effet temporaire." : nil) {
            ForEach(c.modifiers) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                        Text(describe(m)).font(Theme.small).foregroundStyle(Theme.steel)
                    }
                    Spacer()
                    Text("\(m.monthsLeft) mois").font(Theme.data(12)).foregroundStyle(Theme.steel)
                }
            }
        }
    }

    private func describe(_ m: Modifier) -> String {
        var parts: [String] = []
        if m.growth != 0 { parts.append("croissance \(Fmt.signedPct(m.growth))") }
        if m.stability != 0 { parts.append("stabilité \(m.stability > 0 ? "+" : "−")\(Fmt.number(abs(m.stability) * 100))") }
        if m.support != 0 { parts.append("soutien \(m.support > 0 ? "+" : "−")\(Fmt.number(abs(m.support) * 100))") }
        return parts.joined(separator: ", ")
    }

    private func row(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Theme.amber).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                    Text(detail).font(Theme.small).foregroundStyle(Theme.steel)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FreedomCard: View {
    @ObservedObject var store: GameStore
    let country: Country

    var body: some View {
        Dossier(title: "Libertés publiques", subtitle: hint) {
            Picker("Libertés", selection: Binding(
                get: { country.freedom },
                set: { level in store.perform { s, p in s.setFreedom(level, for: p) } })) {
                ForEach(FreedomLevel.allCases, id: \.self) { level in
                    Text(short(level)).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var hint: String {
        country.government.isDemocratic
            ? "En démocratie, restreindre les libertés déstabilise le pays."
            : "Dans un régime autoritaire, la répression stabilise mais rend impopulaire."
    }

    private func short(_ level: FreedomLevel) -> String {
        switch level {
        case .open: return "Garanties"
        case .restricted: return "Restreintes"
        case .repressed: return "Répression"
        }
    }
}
