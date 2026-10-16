import Foundation

// =============================================================
//  Intelligence.swift
//  Espionnage (opérations secrètes contre un autre pays) et
//  Conseil de sécurité de l'ONU (résolutions, vetos).
// =============================================================

// MARK: - Opérations secrètes

enum CovertOperation: String, CaseIterable, Identifiable {
    case stealTech, sabotage, fundOpposition, disinformation, supportRebels, coup

    var id: String { rawValue }

    var name: String {
        switch self {
        case .stealTech: return "Voler des technologies"
        case .sabotage: return "Saboter l'industrie"
        case .fundOpposition: return "Financer l'opposition"
        case .disinformation: return "Campagne de désinformation"
        case .supportRebels: return "Armer les rebelles"
        case .coup: return "Fomenter un coup d'État"
        }
    }

    var detail: String {
        switch self {
        case .stealTech: return "Gagne des points de recherche, d'autant plus que la cible est avancée."
        case .sabotage: return "Détruit 3 % de ses usines civiles et militaires."
        case .fundOpposition: return "Stabilité et soutien au gouvernement en baisse pendant un an."
        case .disinformation: return "Soutien au gouvernement −8 points, surtout utile avant une élection."
        case .supportRebels: return "Seulement en cas de guerre civile : les rebelles se renforcent."
        case .coup: return "Seulement si la cible est très instable : un régime ami prend le pouvoir."
        }
    }

    var icon: String {
        switch self {
        case .stealTech: return "doc.text.magnifyingglass"
        case .sabotage: return "flame"
        case .fundOpposition: return "banknote"
        case .disinformation: return "antenna.radiowaves.left.and.right"
        case .supportRebels: return "figure.run"
        case .coup: return "crown"
        }
    }

    var influenceCost: Double {
        switch self {
        case .stealTech: return 15
        case .sabotage: return 15
        case .fundOpposition: return 12
        case .disinformation: return 10
        case .supportRebels: return 15
        case .coup: return 35
        }
    }

    /// Difficulté de base (plus c'est haut, plus c'est dur).
    var difficulty: Double {
        switch self {
        case .disinformation: return 0.0
        case .fundOpposition: return 0.1
        case .stealTech: return 0.2
        case .sabotage: return 0.25
        case .supportRebels: return 0.15
        case .coup: return 0.45
        }
    }
}

extension Simulation {

    func covertAvailable(_ op: CovertOperation, target: CountryID) -> Bool {
        guard let t = state.countries[target] else { return false }
        switch op {
        case .supportRebels: return t.civilWar > 0
        case .coup: return t.stability < 0.3 && t.government != .democracy
        default: return true
        }
    }

    /// Chance de réussite (0…1) : vos services contre les siens.
    func covertChance(_ op: CovertOperation, from id: CountryID, on target: CountryID) -> Double {
        guard let a = state.countries[id], let t = state.countries[target] else { return 0 }
        var chance = 0.55 + (a.intelligence - t.intelligence) * 0.6 - op.difficulty
        if a.has(.cyberWarfare) { chance += 0.05 }
        if t.freedom == .repressed { chance -= 0.1 }
        if op == .coup { chance += (0.3 - t.stability) }
        return chance.clamped(0.05, 0.9)
    }

    mutating func covertOperation(_ op: CovertOperation, from id: CountryID, on target: CountryID) -> ActionResult {
        guard id != target, let a = state.countries[id], let t = state.countries[target] else {
            return ActionResult(success: false, message: "Opération impossible.")
        }
        guard covertAvailable(op, target: target) else {
            return ActionResult(success: false, message: "Conditions non réunies pour cette opération.")
        }
        guard a.influence >= op.influenceCost else {
            return ActionResult(success: false, message: "Pas assez d'influence (\(Int(op.influenceCost))).")
        }
        state.countries[id]?.influence -= op.influenceCost
        let success = Double.random(in: 0...1, using: &state.rng) < covertChance(op, from: id, on: target)
        let exposedChance = success ? 0.25 : 0.6
        let exposed = Double.random(in: 0...1, using: &state.rng) < exposedChance * (1.2 - a.intelligence * 0.5)
        if exposed {
            changeRelation(id, target, by: op == .coup ? -50 : -25)
            for friend in countryIDs where friend != id && friend != target && relation(friend, target) > 50 {
                changeRelation(id, friend, by: -5)
            }
            state.worldTension = min(100, state.worldTension + (op == .coup ? 6 : 2))
            addEvent("🕵️ \(t.name) démasque une opération de \(a.name) : \(op.name.lowercased()).",
                     important: target == state.playerID || id == state.playerID)
        }
        guard success else {
            return ActionResult(success: false, message: exposed ? "Échec, et vos agents ont été démasqués." : "Échec discret.")
        }
        switch op {
        case .stealTech:
            let gain = 150 + max(0, t.tech - a.tech) * 2000
            state.countries[id]?.researchProgress += gain
        case .sabotage:
            adjust(target) { c in
                c.civilianFactories *= 0.97
                c.militaryFactories *= 0.97
            }
        case .fundOpposition:
            addModifier(target, "Opposition financée de l'étranger", stability: -0.06, support: -0.06, months: 12)
        case .disinformation:
            addModifier(target, "Désinformation", support: -0.08, months: 8)
        case .supportRebels:
            adjust(target) { c in c.rebelStrength *= 1.3 }
        case .coup:
            adjust(target) { c in
                c.government = .junta
                c.freedom = .repressed
                c.stability = 0.45
                c.support = 0.5
                c.nextElectionDay = Int.max / 2
            }
            setRelation(id, target, 60)
            addEvent("🪖 Coup d'État : l'armée prend le pouvoir (\(t.name)).", important: true)
        }
        return ActionResult(success: true, message: exposed ? "Réussie, mais l'opération a été révélée." : "Opération réussie, sans laisser de traces.")
    }
}

// MARK: - Conseil de sécurité de l'ONU

enum ResolutionKind: String, CaseIterable, Identifiable {
    case sanctions, ceasefire, condemnation

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sanctions: return "Sanctions internationales"
        case .ceasefire: return "Appel au cessez-le-feu"
        case .condemnation: return "Condamnation"
        }
    }

    var detail: String {
        switch self {
        case .sanctions: return "Les pays qui ont voté pour imposent des sanctions à la cible."
        case .ceasefire: return "Pression sur les deux camps : lassitude de guerre +20 points, la paix devient plus probable."
        case .condemnation: return "Relations de la cible −10 avec le monde entier."
        }
    }
}

struct ResolutionVote: Identifiable {
    let id: CountryID
    let inFavor: Bool
    let reason: String
}

extension Simulation {

    static let permanentMembers: [CountryID] = ["USA", "CHN", "RUS", "GBR", "FRA"]

    /// Membres non permanents (renouvelés tous les deux ans parmi les pays moyens).
    var securityCouncil: [CountryID] {
        let candidates = countryIDs.filter { !Simulation.permanentMembers.contains($0) && (state.countries[$0]?.gdp ?? 0) > 60 }
        guard !candidates.isEmpty else { return Simulation.permanentMembers }
        let term = state.day / 730
        var picked: [CountryID] = []
        var index = (term * 7) % candidates.count
        while picked.count < 10 && picked.count < candidates.count {
            let c = candidates[index % candidates.count]
            if !picked.contains(c) { picked.append(c) }
            index += 13
        }
        return Simulation.permanentMembers + picked
    }

    func predictVotes(_ kind: ResolutionKind, target: CountryID, sponsor: CountryID) -> [ResolutionVote] {
        securityCouncil.compactMap { member -> ResolutionVote? in
            guard state.countries[member] != nil else { return nil }
            if member == target { return ResolutionVote(id: member, inFavor: false, reason: "Pays visé") }
            if member == sponsor { return ResolutionVote(id: member, inFavor: true, reason: "Auteur du texte") }
            var score = -relation(member, target) * 0.6 + relation(member, sponsor) * 0.3
            if kind == .ceasefire { score += 25 }
            if kind == .sanctions { score -= 15 }
            if allies(of: target).contains(member) { score -= 60 }
            if enemies(of: target).contains(member) { score += 60 }
            let reason: String
            if score > 0 {
                reason = relation(member, target) < -20 ? "Hostile à la cible" : "Soutient le texte"
            } else {
                reason = relation(member, target) > 20 ? "Proche de la cible" : "Réticent"
            }
            return ResolutionVote(id: member, inFavor: score > 0, reason: reason)
        }
    }

    mutating func proposeResolution(_ kind: ResolutionKind, target: CountryID, by sponsor: CountryID) -> ActionResult {
        guard (state.countries[sponsor]?.influence ?? 0) >= 20 else {
            return ActionResult(success: false, message: "Il faut 20 d'influence pour porter une résolution.")
        }
        if kind == .ceasefire && enemies(of: target).isEmpty {
            return ActionResult(success: false, message: "Ce pays n'est pas en guerre.")
        }
        state.countries[sponsor]?.influence -= 20
        let votes = predictVotes(kind, target: target, sponsor: sponsor)
        let vetoes = votes.filter { Simulation.permanentMembers.contains($0.id) && !$0.inFavor }
        let yes = votes.filter { $0.inFavor }.count
        let title = "\(kind.name) visant \(name(target))"
        if !vetoes.isEmpty {
            let names = vetoes.map { name($0.id) }.joined(separator: ", ")
            addEvent("🇺🇳 ONU : \(title), veto de \(names).", important: true)
            return ActionResult(success: false, message: "Veto de \(names).")
        }
        guard yes >= 9 else {
            addEvent("🇺🇳 ONU : \(title), rejetée (\(yes) voix sur 15).", important: true)
            return ActionResult(success: false, message: "Rejetée : \(yes) voix sur 15 (il en faut 9).")
        }
        switch kind {
        case .sanctions:
            for v in votes where v.inFavor && v.id != target {
                addTreaty(.sanctions, v.id, target)
            }
        case .ceasefire:
            for side in [target] + Array(enemies(of: target)) {
                adjust(side) { c in c.warExhaustion = min(1, c.warExhaustion + 0.2) }
            }
        case .condemnation:
            for other in countryIDs where other != target {
                changeRelation(other, target, by: -10)
            }
        }
        changeRelation(sponsor, target, by: -15)
        let newValue_influence = min(100, (state.countries[sponsor]?.influence ?? 0) + 5)
        state.countries[sponsor]?.influence = newValue_influence
        addEvent("🇺🇳 ONU : \(title), adoptée (\(yes) voix sur 15).", important: true)
        return ActionResult(success: true, message: "Résolution adoptée (\(yes) voix sur 15).")
    }
}
