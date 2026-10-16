import Foundation

// =============================================================
//  Achievements.swift
//  Les succès : des défis à débloquer, gardés d'une partie à
//  l'autre (enregistrés sur l'appareil).
// =============================================================

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let check: (Simulation, CountryID) -> Bool
}

enum AchievementCatalog {

    static let all: [Achievement] = [
        Achievement(id: "firstYear", title: "Premier mandat", detail: "Tenir une année complète.", icon: "calendar") { sim, _ in
            sim.state.day >= 365
        },
        Achievement(id: "growth5", title: "Miracle économique", detail: "Dépasser 5 % de croissance.", icon: "chart.line.uptrend.xyaxis") { sim, p in
            (sim.state.countries[p]?.growth ?? 0) > 0.05
        },
        Achievement(id: "top1", title: "Première puissance mondiale", detail: "Devenir la première économie du monde.", icon: "crown.fill") { sim, p in
            sim.rankedCountries().first?.id == p
        },
        Achievement(id: "lowDebt", title: "Gestionnaire rigoureux", detail: "Ramener la dette sous 30 % du PIB.", icon: "banknote") { sim, p in
            guard let c = sim.state.countries[p] else { return false }
            return c.debt / max(sim.effectiveGDP(p), 1) < 0.3
        },
        Achievement(id: "nuclear", title: "Club atomique", detail: "Posséder l'arme nucléaire.", icon: "atom") { sim, p in
            (sim.state.countries[p]?.nuclearWarheads ?? 0) > 0
        },
        Achievement(id: "army100", title: "Grande armée", detail: "Aligner 100 divisions.", icon: "person.3.sequence.fill") { sim, p in
            (sim.state.countries[p]?.divisionCount ?? 0) >= 100
        },
        Achievement(id: "conqueror", title: "Conquérant", detail: "Tenir des territoires dans trois pays étrangers.", icon: "flag.2.crossed.fill") { sim, p in
            sim.territoriesHeld(by: p).filter { $0.1 > 0.05 }.count >= 3
        },
        Achievement(id: "liberator", title: "Libérateur", detail: "Récupérer tous vos territoires perdus.", icon: "flag.checkered") { sim, p in
            guard let record = sim.state.record, record.goals.contains(where: { $0.kind == .recoverTerritory }) else { return false }
            return sim.lostFraction(p) - (sim.state.countries[p]?.civilWar ?? 0) < 0.005
        },
        Achievement(id: "faction10", title: "Chef de bloc", detail: "Diriger une faction d'au moins 10 pays.", icon: "shield.lefthalf.filled") { sim, p in
            guard let f = sim.faction(of: p) else { return false }
            return sim.factionLeader(f) == p && f.members.count >= 10
        },
        Achievement(id: "tech15", title: "Pionnier", detail: "Maîtriser 15 technologies.", icon: "cpu") { sim, p in
            (sim.state.countries[p]?.techs.count ?? 0) >= 15
        },
        Achievement(id: "projects5", title: "Bâtisseur", detail: "Achever 5 projets nationaux.", icon: "building.2.crop.circle") { sim, p in
            (sim.state.countries[p]?.completedProjects.count ?? 0) >= 5
        },
        Achievement(id: "stable90", title: "Havre de paix", detail: "Atteindre 90 % de stabilité.", icon: "leaf") { sim, p in
            (sim.state.countries[p]?.stability ?? 0) >= 0.9
        },
        Achievement(id: "friends10", title: "Ami de tous", detail: "Avoir 10 pays à plus de 70 de relation.", icon: "hand.wave.fill") { sim, p in
            sim.countryIDs.filter { $0 != p && sim.relation(p, $0) > 70 }.count >= 10
        },
        Achievement(id: "peaceUkraine", title: "Paix en Europe", detail: "Voir la guerre russo-ukrainienne se terminer.", icon: "dove") { sim, _ in
            !sim.state.wars.contains { $0.isActive && $0.attackers.contains("RUS") && $0.defenders.contains("UKR") }
                && sim.state.day > 0
        },
        Achievement(id: "year2050", title: "Fin de l'histoire", detail: "Atteindre l'année 2050.", icon: "hourglass") { sim, _ in
            sim.state.day >= Simulation.endDay
        },
        Achievement(id: "score2000", title: "Légende", detail: "Dépasser 2 000 points de score.", icon: "star.fill") { sim, _ in
            sim.totalScore >= 2000
        }
    ]
}

extension Simulation {

    /// Succès nouvellement remplis ce mois-ci (non encore débloqués dans cette partie).
    mutating func monthlyAchievements() {
        guard let p = state.playerID, state.countries[p] != nil else { return }
        for a in AchievementCatalog.all where !state.achievements.contains(a.id) {
            if a.check(self, p) {
                state.achievements.insert(a.id)
                addEvent("🏅 Succès débloqué : \(a.title).", important: true)
            }
        }
    }
}

/// Succès gardés sur l'appareil, toutes parties confondues.
enum AchievementStore {
    private static let key = "achievements"

    static var unlocked: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func merge(_ ids: Set<String>) {
        let merged = unlocked.union(ids)
        UserDefaults.standard.set(Array(merged).sorted(), forKey: key)
    }
}
