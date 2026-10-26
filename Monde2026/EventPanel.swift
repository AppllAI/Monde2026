import SwiftUI

// =============================================================
//  EventPanel.swift
//  Les événements à choix et l'écran de fin de partie.
// =============================================================

struct EventPanel: View {
    @ObservedObject var store: GameStore
    let eventID: Int

    var body: some View {
        if let sim = store.sim,
           let pending = sim.state.pendingEvents.first(where: { $0.id == eventID }),
           let def = sim.definition(for: pending) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: def.icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(def.isBad ? Theme.coral : Theme.amber)
                    .frame(width: 64, height: 64)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                Text(def.title).font(Theme.title(28)).foregroundStyle(Theme.paper)
                Text(def.text(sim, pending)).font(.system(size: 16)).foregroundStyle(Theme.paper.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(def.options.indices, id: \.self) { index in
                    let option = def.options[index]
                    Button {
                        store.mutate { $0.resolveEvent(eventID, option: index) }
                        store.panel = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                            Text(option.detail).font(Theme.small).foregroundStyle(Theme.ink.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(index == 0 ? Theme.amber : Theme.paper.opacity(0.85),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Text("Cet événement est terminé.").foregroundStyle(Theme.steel)
            QuietButton(title: "Fermer") { store.panel = nil }
        }
    }
}

struct EndGamePanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let record = sim.state.record {
            PanelHeader(title: record.gameOver ? (record.victory ? "Fin de partie" : "Défaite") : "Score et objectifs",
                        subtitle: record.gameOver ? record.endReason : "Partie jusqu'au 1er janvier 2050.",
                        flag: sim.state.playerID) {
                if record.gameOver { store.acknowledgeEnd() } else { store.panel = nil }
            }
            Dossier(title: "Score : \(sim.totalScore)", subtitle: "Difficulté : \(sim.state.difficulty.name)") {
                ForEach(sim.scoreBreakdown()) { line in
                    HStack {
                        Text(line.label).font(.system(size: 14)).foregroundStyle(Theme.paper)
                        Spacer()
                        Text(line.points >= 0 ? "+\(line.points)" : "\(line.points)")
                            .font(Theme.data(14, weight: .semibold))
                            .foregroundStyle(line.points >= 0 ? Theme.teal : Theme.coral)
                    }
                }
            }
            Dossier(title: "Objectifs nationaux") {
                ForEach(record.goals) { goal in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: goal.completedDay != nil ? "checkmark.seal.fill" : "seal")
                            .foregroundStyle(goal.completedDay != nil ? Theme.amber : Theme.steel)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                            Text(goal.detail).font(Theme.small).foregroundStyle(Theme.steel)
                        }
                        Spacer()
                        Text("\(goal.kind.points)").font(Theme.data(13)).foregroundStyle(Theme.steel)
                    }
                }
            }
            AchievementsCard(unlockedHere: sim.state.achievements)
            if record.gameOver {
                ActionButton(title: "Continuer à jouer", icon: "play.fill") { store.acknowledgeEnd() }
                QuietButton(title: "Retour au menu", icon: "house", tint: Theme.coral) { store.quitToMenu() }
            }
        }
    }
}
