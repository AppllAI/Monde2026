import Foundation

// =============================================================
//  Influence.swift
//  La diplomatie « douce » :
//   - aide humanitaire (relations, stabilité du pays aidé,
//     prestige auprès de ses amis),
//   - sommet bilatéral (rapprochement rapide, une fois par an),
//   - médiation de paix entre deux pays en guerre,
//   - zones d'influence des grandes puissances (carte),
//   - l'IA propose aussi au joueur d'attaquer ensemble.
// =============================================================

extension Simulation {

    /// Grandes puissances qui se disputent le monde (carte « Influence »).
    static let powers: [CountryID] = ["USA", "CHN", "RUS", "FRA", "DEU", "GBR", "IND", "TUR", "JPN", "BRA", "SAU", "IRN"]

    /// Puissance la plus influente dans un pays (nil : aucune ne domine).
    func influenceLeader(of id: CountryID) -> CountryID? {
        if Simulation.powers.contains(id) { return id }
        var best: (CountryID, Double)?
        for power in Simulation.powers where state.countries[power] != nil {
            var score = relation(id, power)
            if hasTreaty(.alliance, id, power) { score += 40 }
            if let f = faction(of: id), faction(of: power)?.id == f.id { score += 25 }
            if hasTreaty(.tradePact, id, power) { score += 12 }
            if hasTreaty(.guarantee, power, id) { score += 15 }
            if enemies(of: id).contains(power) { score -= 100 }
            // Le poids de la puissance compte : une grande économie attire davantage.
            score += log10(max(10, state.countries[power]?.gdp ?? 10)) * 4
            if score > (best?.1 ?? 45) { best = (power, score) }
        }
        return best?.0
    }

    // MARK: Aide humanitaire

    mutating func humanitarianAid(to target: CountryID, amount: Double) -> ActionResult {
        guard let p = state.playerID, p != target, var me = state.countries[p], var them = state.countries[target] else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        guard !enemies(of: p).contains(target) else {
            return ActionResult(success: false, message: "On n'aide pas un pays avec qui l'on est en guerre.")
        }
        me.debt += amount
        let weight = amount / max(5, them.gdp)
        them.stability = min(1, them.stability + min(0.08, weight * 2))
        them.support = min(1, them.support + min(0.05, weight))
        state.countries[p] = me
        state.countries[target] = them
        changeRelation(p, target, by: min(30, 6 + weight * 400))
        // Ses amis apprécient ; ses ennemis beaucoup moins.
        for other in countryIDs where other != p && other != target {
            let r = relation(other, target)
            if r > 50 { changeRelation(p, other, by: 2) }
            if enemies(of: target).contains(other) { changeRelation(p, other, by: -4) }
        }
        state.countries[p]?.influence = min(100, (state.countries[p]?.influence ?? 0) + 2)
        return ActionResult(success: true, message: "Aide humanitaire de \(Int(amount)) Md$ à \(name(target)) : la population vous en sait gré.")
    }

    // MARK: Sommet

    func summitCooldown(_ a: CountryID, _ b: CountryID) -> Int {
        let key = a < b ? a + "|" + b : b + "|" + a
        guard let last = state.summits[key] else { return 0 }
        return max(0, last + 365 - state.day)
    }

    mutating func summit(with target: CountryID) -> ActionResult {
        guard let p = state.playerID, p != target, state.countries[target] != nil else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        let wait = summitCooldown(p, target)
        guard wait == 0 else { return ActionResult(success: false, message: "Un sommet a déjà eu lieu : encore \(wait) jours.") }
        guard !enemies(of: p).contains(target) else { return ActionResult(success: false, message: "Pas de sommet en pleine guerre : proposez la paix.") }
        guard (state.countries[p]?.influence ?? 0) >= 15 else { return ActionResult(success: false, message: "Il faut 15 d'influence.") }
        state.countries[p]?.influence -= 15
        let key = p < target ? p + "|" + target : target + "|" + p
        state.summits[key] = state.day
        let r = relation(p, target)
        // Plus on part de loin, plus un sommet rapproche (mais il ne fait pas de miracle).
        let gain = r < -40 ? 10.0 : (r < 30 ? 16.0 : 8.0)
        changeRelation(p, target, by: gain)
        addEvent("🤝 Sommet avec \(name(target)) : relations +\(Int(gain)).", important: false)
        return ActionResult(success: true, message: "Sommet réussi avec \(name(target)) : relations +\(Int(gain)).")
    }

    // MARK: Médiation

    /// Guerres de la cible où le joueur n'est pas partie prenante.
    func mediableWars(_ target: CountryID) -> [War] {
        guard let p = state.playerID else { return [] }
        return wars(of: target).filter { !$0.attackers.contains(p) && !$0.defenders.contains(p) }
    }

    func mediationChance(_ war: War) -> Double {
        guard let p = state.playerID else { return 0 }
        let sides = [war.attackers, war.defenders].compactMap { leader(of: $0) }
        guard sides.count == 2 else { return 0 }
        let tired = sides.map { state.countries[$0]?.warExhaustion ?? 0 }.reduce(0, +) / 2
        let trust = sides.map { relation($0, p) }.reduce(0, +) / 200        // −1 … 1
        let days = Double(state.day - war.startDay)
        return (0.08 + tired * 0.6 + trust * 0.2 + min(0.15, days / 3000)).clamped(0.02, 0.85)
    }

    mutating func mediate(_ warID: Int) -> ActionResult {
        guard let p = state.playerID, let war = state.wars.first(where: { $0.id == warID && $0.isActive }) else {
            return ActionResult(success: false, message: "Cette guerre est finie.")
        }
        guard (state.countries[p]?.influence ?? 0) >= 25 else { return ActionResult(success: false, message: "Il faut 25 d'influence.") }
        state.countries[p]?.influence -= 25
        let chance = mediationChance(war)
        let sides = [war.attackers, war.defenders].compactMap { leader(of: $0) }
        if Double.random(in: 0...1, using: &state.rng) < chance {
            applyPeace(warID: warID, terms: .statusQuo)
            for s in sides { changeRelation(p, s, by: 15) }
            for other in countryIDs where other != p { changeRelation(p, other, by: 1) }
            addEvent("🕊️ Grâce à notre médiation, la paix est signée : \(war.name).", important: true)
            return ActionResult(success: true, message: "Médiation réussie : \(war.name) prend fin.")
        }
        for s in sides { changeRelation(p, s, by: -3) }
        return ActionResult(success: false, message: "Médiation refusée (\(Int(chance * 100)) % de chances). Réessayez quand ils seront plus las de la guerre.")
    }

    // MARK: Attaques communes proposées par l'IA

    mutating func acceptJointAttack(from partner: CountryID, target: CountryID, inDays days: Int) {
        state.jointPlans.append(JointPlan(id: state.nextPlanID, partner: partner, target: target, day: state.day + days))
        state.nextPlanID += 1
        changeRelation(partner, state.playerID ?? partner, by: 10)
        addEvent("🤝 Accord secret avec \(name(partner)) : attaque commune de \(name(target)) dans \(days) jours.", important: true)
    }

    /// Chaque mois, un ami du joueur peut lui proposer d'attaquer ensemble un ennemi commun.
    mutating func aiJointProposals() {
        guard let p = state.playerID, let me = state.countries[p], !me.capitulated else { return }
        guard !state.proposals.contains(where: { $0.to == p && $0.kind == .jointAttack }) else { return }
        guard Double.random(in: 0...1, using: &state.rng) < 0.05 else { return }
        for id in countryIDs where id != p && relation(id, p) > 40 && !isAtWar(id) {
            guard let c = state.countries[id], c.aggressiveness > 0.35 else { continue }
            // Un ennemi commun, voisin de lui, que nous n'aimons pas non plus.
            let rivals = c.neighbors.filter { y in
                y != p && state.countries[y] != nil && relation(id, y) < -40 && relation(p, y) < -20 && !isFriendly(p, y)
            }
            guard let y = rivals.min(by: { relation(id, $0) < relation(id, $1) }) else { continue }
            guard militaryPower(id) + militaryPower(p) > militaryPower(y) * 1.2 else { continue }
            state.proposals.append(Proposal(id: state.nextProposalID, from: id, to: p, kind: .jointAttack,
                                            warID: nil, terms: nil, day: state.day, target: y, inDays: 60))
            state.nextProposalID += 1
            addEvent("📨 \(name(id)) vous propose d'attaquer \(name(y)) ensemble dans 60 jours.", important: true)
            return
        }
    }
}
