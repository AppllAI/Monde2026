import Foundation

// =============================================================
//  Goals.swift
//  Difficulté, objectifs nationaux, score, fin de partie
//  et arme nucléaire.
// =============================================================

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, normal, hard

    var id: String { rawValue }

    var name: String {
        switch self {
        case .easy: return "Facile"
        case .normal: return "Normal"
        case .hard: return "Difficile"
        }
    }

    var summary: String {
        switch self {
        case .easy: return "Économie plus robuste, IA conciliante, moins de crises."
        case .normal: return "Le monde tel qu'il est."
        case .hard: return "IA méfiante et plus agressive envers vous, crises plus fréquentes."
        }
    }

    /// Bonus ajouté aux évaluations de l'IA quand le joueur propose quelque chose.
    var diplomacyBias: Double {
        switch self {
        case .easy: return 10
        case .normal: return 0
        case .hard: return -10
        }
    }

    /// Multiplie le risque que l'IA prépare une guerre contre le joueur.
    var threatFactor: Double {
        switch self {
        case .easy: return 0.5
        case .normal: return 1
        case .hard: return 1.6
        }
    }

    var playerGrowthBonus: Double {
        switch self {
        case .easy: return 0.005
        case .normal: return 0
        case .hard: return -0.003
        }
    }

    var badEventFactor: Double {
        switch self {
        case .easy: return 0.6
        case .normal: return 1
        case .hard: return 1.4
        }
    }
}

enum GoalKind: String, Codable, CaseIterable {
    case doubleGDP, topTenEconomy, recoverTerritory, achieveClaim, lowDebt, alliances, techLeader,
         stableNation, endCivilWar, peacemaker

    var points: Int {
        switch self {
        case .doubleGDP, .achieveClaim, .recoverTerritory, .endCivilWar: return 300
        case .topTenEconomy, .techLeader: return 250
        default: return 150
        }
    }
}

struct NationalGoal: Codable, Identifiable {
    let kind: GoalKind
    let title: String
    let detail: String
    var completedDay: Int?
    var id: String { kind.rawValue }
}

struct PlayerRecord: Codable {
    var startGDP: Double
    var startTech: Double
    var startRank: Int
    var goals: [NationalGoal]
    var gameOver: Bool
    var victory: Bool
    var endReason: String
    var acknowledged: Bool
}

extension Simulation {

    static let endDay = 8766   // 1er janvier 2050

    // MARK: Objectifs

    mutating func setupGoals() {
        guard let p = state.playerID, let c = state.countries[p] else { return }
        let ranked = rankedCountries().map { $0.id }
        let rank = ranked.firstIndex(of: p) ?? 99
        var goals: [NationalGoal] = []
        goals.append(NationalGoal(kind: .doubleGDP, title: "Doubler le PIB",
                                  detail: "Atteindre \(Fmt.money(effectiveGDP(p) * 2)).", completedDay: nil))
        if rank >= 10 {
            goals.append(NationalGoal(kind: .topTenEconomy, title: "Entrer dans le top 10",
                                      detail: "Devenir l'une des dix premières économies.", completedDay: nil))
        }
        if lostFraction(p) > 0.01 && c.civilWar < lostFraction(p) {
            goals.append(NationalGoal(kind: .recoverTerritory, title: "Récupérer nos territoires",
                                      detail: "Ne plus avoir de territoire occupé ou annexé.", completedDay: nil))
        }
        if c.civilWar > 0 {
            goals.append(NationalGoal(kind: .endCivilWar, title: "Réunifier le pays",
                                      detail: "Gagner la guerre civile.", completedDay: nil))
        }
        if let claim = state.claims.first(where: { $0.claimant == p && $0.major }) {
            goals.append(NationalGoal(kind: .achieveClaim, title: claim.name,
                                      detail: "Contrôler au moins 30 % de \(name(claim.target)).", completedDay: nil))
        }
        goals.append(NationalGoal(kind: .lowDebt, title: "Finances saines",
                                  detail: "Dette publique sous 60 % du PIB et déficit sous 3 %.", completedDay: nil))
        goals.append(NationalGoal(kind: .alliances, title: "Un pays entouré d'amis",
                                  detail: "Au moins 5 pays à plus de 60 de relation.", completedDay: nil))
        goals.append(NationalGoal(kind: .techLeader, title: "Puissance technologique",
                                  detail: "Maîtriser 14 technologies.", completedDay: nil))
        goals.append(NationalGoal(kind: .stableNation, title: "Nation stable",
                                  detail: "Stabilité supérieure à 80 %.", completedDay: nil))
        goals.append(NationalGoal(kind: .peacemaker, title: "Artisan de paix",
                                  detail: "Une guerre où vous étiez impliqué se termine par un traité.", completedDay: nil))
        state.record = PlayerRecord(startGDP: effectiveGDP(p), startTech: c.tech, startRank: rank, goals: goals,
                                    gameOver: false, victory: false, endReason: "", acknowledged: false)
    }

    func isGoalMet(_ kind: GoalKind) -> Bool {
        guard let p = state.playerID, let c = state.countries[p], let record = state.record else { return false }
        let gdp = effectiveGDP(p)
        switch kind {
        case .doubleGDP:
            return gdp >= record.startGDP * 2
        case .topTenEconomy:
            return (rankedCountries().prefix(10).map { $0.id }).contains(p)
        case .recoverTerritory:
            return lostFraction(p) - c.civilWar < 0.005
        case .endCivilWar:
            return c.civilWar == 0
        case .achieveClaim:
            guard let claim = state.claims.first(where: { $0.claimant == p && $0.major }) else { return false }
            return heldFraction(of: claim.target, by: p) >= 0.3
        case .lowDebt:
            return c.debt / gdp < 0.6 && -c.lastBudgetBalance * 12 / gdp < 0.03
        case .alliances:
            return countryIDs.filter { $0 != p && relation(p, $0) > 60 }.count >= 5
        case .techLeader:
            return c.techs.count >= 14
        case .stableNation:
            return c.stability > 0.8
        case .peacemaker:
            return state.events.contains { $0.text.hasPrefix("🕊️ Paix") && $0.important }
        }
    }

    mutating func monthlyGoals() {
        guard var record = state.record, !record.gameOver, let p = state.playerID else { return }
        for i in record.goals.indices where record.goals[i].completedDay == nil {
            if isGoalMet(record.goals[i].kind) {
                record.goals[i].completedDay = state.day
                addEvent("🏆 Objectif atteint : \(record.goals[i].title) (+\(record.goals[i].kind.points) points).", important: true)
            }
        }
        state.record = record
        if lostFraction(p) >= 0.9 {
            endGame(victory: false, reason: "Votre pays a été conquis.")
        } else if state.day >= Simulation.endDay {
            endGame(victory: true, reason: "Nous sommes en 2050 : votre mandat historique s'achève.")
        }
    }

    mutating func endGame(victory: Bool, reason: String) {
        guard var record = state.record, !record.gameOver else { return }
        record.gameOver = true
        record.victory = victory
        record.endReason = reason
        state.record = record
        addEvent(victory ? "🏁 Fin de partie." : "💀 Défaite : \(reason)", important: true)
    }

    // MARK: Score

    struct ScoreLine: Identifiable {
        let id: String
        let label: String
        let points: Int
    }

    func scoreBreakdown() -> [ScoreLine] {
        guard let p = state.playerID, let c = state.countries[p], let record = state.record else { return [] }
        var lines: [ScoreLine] = []
        let economy = Int((effectiveGDP(p) / max(record.startGDP, 1) - 1) * 500)
        lines.append(ScoreLine(id: "eco", label: "Croissance de l'économie", points: economy))
        let goals = record.goals.filter { $0.completedDay != nil }.reduce(0) { $0 + $1.kind.points }
        lines.append(ScoreLine(id: "goals", label: "Objectifs nationaux", points: goals))
        var conquered = 0.0
        for (victim, f) in territoriesHeld(by: p) {
            conquered += f * effectiveGDP(victim)
        }
        lines.append(ScoreLine(id: "land", label: "Territoires conquis", points: Int(conquered / max(record.startGDP, 1) * 300)))
        lines.append(ScoreLine(id: "lost", label: "Territoires perdus", points: -Int(lostFraction(p) * 400)))
        lines.append(ScoreLine(id: "stab", label: "Stabilité", points: Int((c.stability - 0.5) * 200)))
        lines.append(ScoreLine(id: "tech", label: "Progrès technologique", points: Int((c.tech - record.startTech) * 300) + c.techs.count * 10))
        let multiplier: Double
        switch state.difficulty {
        case .easy: multiplier = 0.7
        case .normal: multiplier = 1
        case .hard: multiplier = 1.4
        }
        let subtotal = lines.reduce(0) { $0 + $1.points }
        lines.append(ScoreLine(id: "diff", label: "Difficulté ×\(Fmt.number(multiplier, 1))",
                               points: Int(Double(subtotal) * (multiplier - 1))))
        return lines
    }

    var totalScore: Int { scoreBreakdown().reduce(0) { $0 + $1.points } }

    // MARK: Arme nucléaire

    /// Frappe nucléaire : dévastatrice, et la riposte est probable.
    mutating func nuclearStrike(from id: CountryID, on target: CountryID) -> ActionResult {
        guard let a = state.countries[id], let t = state.countries[target], a.nuclearWarheads >= 10 else {
            return ActionResult(success: false, message: "Il faut au moins 10 ogives.")
        }
        guard enemies(of: id).contains(target) else {
            return ActionResult(success: false, message: "Seulement contre un pays avec qui vous êtes en guerre.")
        }
        state.countries[id]?.nuclearWarheads -= 10
        devastate(target)
        state.worldTension = 100
        for other in countryIDs where other != id {
            changeRelation(other, id, by: -50)
        }
        addEvent("☢️ \(a.name) a utilisé l'arme nucléaire contre \(t.name).", important: true)

        // Riposte : la cible ou un allié nucléaire en guerre contre l'agresseur.
        var retaliator: CountryID?
        if t.nuclearWarheads >= 10 {
            retaliator = target
        } else {
            for ally in enemies(of: id) where (state.countries[ally]?.nuclearWarheads ?? 0) >= 10 {
                retaliator = ally
                break
            }
        }
        if let r = retaliator, let rc = state.countries[r] {
            state.countries[r]?.nuclearWarheads -= 10
            devastate(id)
            addEvent("☢️ Riposte nucléaire de \(rc.name) contre \(a.name).", important: true)
            return ActionResult(success: true, message: "Frappe effectuée. \(rc.name) a riposté.")
        }
        return ActionResult(success: true, message: "Frappe effectuée. Le monde entier vous condamne.")
    }

    private mutating func devastate(_ id: CountryID) {
        guard var c = state.countries[id] else { return }
        c.gdp *= 0.75
        c.civilianFactories *= 0.7
        c.militaryFactories *= 0.7
        c.population *= 0.99
        c.infrastructure = max(0.1, c.infrastructure - 0.2)
        c.stability = max(0.02, c.stability - 0.2)
        c.addModifier("Frappe nucléaire", growth: -0.05, stability: -0.15, months: 24)
        state.countries[id] = c
    }

    /// L'IA n'utilise l'arme nucléaire qu'en dernier recours : envahie à plus de 40 %.
    mutating func aiNuclearDecisions() {
        for id in countryIDs where id != state.playerID {
            guard let c = state.countries[id], c.nuclearWarheads >= 10, occupiedFraction(id) > 0.4 else { continue }
            guard Double.random(in: 0...1, using: &state.rng) < 0.1 else { continue }
            let occupiers = state.occupation[id]?.keys.sorted() ?? []
            if let target = occupiers.first(where: { enemies(of: id).contains($0) }) {
                _ = nuclearStrike(from: id, on: target)
            }
        }
    }
}
