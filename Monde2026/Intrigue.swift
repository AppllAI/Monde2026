import Foundation

// =============================================================
//  Intrigue.swift
//  La diplomatie de l'ombre et les grandes manœuvres :
//   - attaque conjointe à une date convenue,
//   - armes et usines prêtées, en public ou en secret,
//   - corps expéditionnaires : nos armées se battent pour un
//     autre pays ; leurs conquêtes vont à ce pays… mais on sait
//     qui les a prises (et on peut le trahir pour les garder),
//   - ultimatum : exiger une région sans combattre,
//   - opérations : bombardement préparatoire, parachutage,
//     encerclement (poches qui se rendent), sièges.
// =============================================================

struct JointPlan: Codable, Identifiable {
    let id: Int
    let partner: CountryID
    let target: CountryID
    let day: Int                 // jour de l'attaque
}

struct FactoryLease: Codable, Identifiable {
    let id: Int
    let to: CountryID
    let factories: Double
    let untilDay: Int
    let covert: Bool
}

struct CovertAid: Codable, Identifiable {
    let id: Int
    let to: CountryID
    let against: [CountryID]
    let untilDay: Int
}

struct Bombardment: Codable {
    let by: CountryID
    var daysLeft: Int
}

extension Simulation {

    // MARK: - Attaque conjointe

    func evaluateJointAttack(partner: CountryID, target: CountryID, from p: CountryID) -> Evaluation {
        var e = Evaluation()
        guard state.countries[partner] != nil, state.countries[target] != nil else { return e }
        e.add("Relation avec vous", relation(partner, p) * 0.5)
        e.add("Hostilité envers \(name(target))", -relation(partner, target) * 0.6)
        if claim(by: partner, on: target) != nil { e.add("Revendication sur \(name(target))", 30) }
        if allies(of: partner).contains(target) { e.add("Allié de \(name(target))", -120) }
        if hasTreaty(.nonAggression, partner, target) { e.add("Pacte de non-agression", -40) }
        let ours = militaryPower(p) + militaryPower(partner)
        let theirs = max(1, defensiveStrength(of: target, against: partner))
        e.add("Chances de victoire à deux", (min(3, ours / theirs) - 1.2) * 30)
        if isNuclearProtected(target, against: partner) { e.add("Arme nucléaire adverse", -60) }
        e.add("Prudence", -25)
        e.add("Niveau de difficulté", state.difficulty.diplomacyBias)
        return e
    }

    mutating func proposeJointAttack(partner: CountryID, target: CountryID, inDays days: Int) -> ActionResult {
        guard let p = state.playerID, partner != target, partner != p, target != p else {
            return ActionResult(success: false, message: "Choix impossible.")
        }
        guard (state.countries[p]?.influence ?? 0) >= 20 else { return ActionResult(success: false, message: "Il faut 20 d'influence.") }
        state.countries[p]?.influence -= 20
        let e = evaluateJointAttack(partner: partner, target: target, from: p)
        guard e.accepted else {
            changeRelation(p, partner, by: -5)
            return ActionResult(success: false, message: "\(name(partner)) refuse d'attaquer \(name(target)) avec vous.")
        }
        state.jointPlans.append(JointPlan(id: state.nextPlanID, partner: partner, target: target, day: state.day + days))
        state.nextPlanID += 1
        changeRelation(p, partner, by: 10)
        return ActionResult(success: true, message: "Accord secret : \(name(partner)) attaquera \(name(target)) avec vous dans \(days) jours. Tenez parole.")
    }

    // MARK: - Aides publiques ou secrètes

    /// Armes : en public, tout le monde le sait ; en secret, l'ennemi n'en veut qu'à celui qu'il démasque.
    mutating func sendArms(to target: CountryID, share: Double, covert: Bool) -> ActionResult {
        guard let p = state.playerID, state.countries[target] != nil, target != p else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        if covert {
            let before = enemies(of: target)
            // Même transfert, sans les sanctions diplomatiques immédiates.
            _ = sendMilitaryAid(from: p, to: target, share: share)
            for foe in before { changeRelation(p, foe, by: 10) }       // on annule la colère publique
            state.covertAid.append(CovertAid(id: state.nextPlanID, to: target, against: Array(before), untilDay: state.day + 180))
            state.nextPlanID += 1
            return ActionResult(success: true, message: "Livraison secrète à \(name(target)) (\(Int(share * 100)) % de vos stocks). Risque d'être découvert.")
        }
        let r = sendMilitaryAid(from: p, to: target, share: share)
        if r.success { addEvent("📦 \(name(p)) livre officiellement des armes à \(name(target)).", important: false) }
        return r
    }

    /// Prête des usines d'armement : elles produisent pour l'allié pendant quelques mois.
    mutating func lendFactories(to target: CountryID, share: Double, months: Int, covert: Bool) -> ActionResult {
        guard let p = state.playerID, var me = state.countries[p], state.countries[target] != nil, target != p else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        let n = (me.militaryFactories * share).rounded()
        guard n >= 1 else { return ActionResult(success: false, message: "Pas assez d'usines d'armement.") }
        me.militaryFactories -= n
        state.countries[p] = me
        state.countries[target]?.militaryFactories += n
        state.leases.append(FactoryLease(id: state.nextPlanID, to: target, factories: n, untilDay: state.day + months * 30, covert: covert))
        state.nextPlanID += 1
        changeRelation(p, target, by: covert ? 10 : 15)
        if !covert {
            for foe in enemies(of: target) { changeRelation(p, foe, by: -12) }
            addEvent("🏭 \(name(p)) prête \(Int(n)) usines d'armement à \(name(target)).", important: false)
        } else {
            state.covertAid.append(CovertAid(id: state.nextPlanID, to: target, against: Array(enemies(of: target)), untilDay: state.day + months * 30))
            state.nextPlanID += 1
        }
        return ActionResult(success: true, message: "\(Int(n)) usines produisent pour \(name(target)) pendant \(months) mois.")
    }

    // MARK: - Corps expéditionnaire

    /// L'armée se met au service d'un autre pays : elle peut combattre ses ennemis sans que nous soyons en guerre.
    mutating func sendExpedition(_ armyID: Int, to host: CountryID, covert: Bool) -> ActionResult {
        guard let p = state.playerID, let i = state.armies.firstIndex(where: { $0.id == armyID && $0.owner == p }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        guard host != p, state.countries[host] != nil else { return ActionResult(success: false, message: "Pays invalide.") }
        guard !enemies(of: host).contains(p) else { return ActionResult(success: false, message: "Vous êtes en guerre contre ce pays.") }
        guard relation(p, host) > -20 || allies(of: p).contains(host) else {
            return ActionResult(success: false, message: "\(name(host)) refuse vos troupes (relation trop basse).")
        }
        state.armies[i].servingFor = host
        state.armies[i].covert = covert
        state.armies[i].training = false
        // Rejoindre le pays hôte.
        if controller(of: state.armies[i].province) != host {
            let dest = (ProvinceMap.byCountry[host] ?? []).filter { controller(of: $0) == host }
                .min { distanceKm(state.armies[i].province, $0) < distanceKm(state.armies[i].province, $1) }
            if let d = dest, let r = route(for: state.armies[i], to: d) {
                state.armies[i].path = r.path
                state.armies[i].amphibious = r.amphibious
                state.armies[i].progress = 0
            }
        }
        changeRelation(p, host, by: 15)
        if !covert {
            for foe in enemies(of: host) { changeRelation(p, foe, by: -25) }
            addEvent("🪖 \(name(p)) envoie officiellement \(state.armies[i].name) combattre aux côtés de \(name(host)).", important: true)
        }
        return ActionResult(success: true, message: covert
            ? "\(state.armies[i].name) part en « volontaires » pour \(name(host)). Ses conquêtes iront à \(name(host)) (en bleu pour vous)."
            : "\(state.armies[i].name) combat officiellement pour \(name(host)). Ses ennemis pourraient vous déclarer la guerre.")
    }

    mutating func recallExpedition(_ armyID: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else { return ActionResult(success: false, message: "") }
        state.armies[i].servingFor = nil
        state.armies[i].covert = false
        state.armies[i].path = []
        if let home = homeProvince(for: state.armies[i].owner), let r = route(for: state.armies[i], to: home) {
            state.armies[i].path = r.path
            state.armies[i].amphibious = r.amphibious
        }
        return ActionResult(success: true, message: "\(state.armies[i].name) rentre au pays.")
    }

    /// Régions prises par nos troupes pour ce pays (et qu'il tient toujours).
    func proxyRegions(for host: CountryID) -> [Int] {
        guard let p = state.playerID else { return [] }
        return state.proxyConquests.filter { $0.value == p && controller(of: $0.key) == host }.map { $0.key }.sorted()
    }

    /// Trahison : on garde pour nous ce que nos troupes ont pris, et nos armées cessent de servir l'allié.
    mutating func betray(_ host: CountryID) -> ActionResult {
        guard let p = state.playerID else { return ActionResult(success: false, message: "") }
        let regions = proxyRegions(for: host)
        guard !regions.isEmpty else { return ActionResult(success: false, message: "Nos troupes n'ont rien pris pour \(name(host)).") }
        var victims = Set<CountryID>()
        for r in regions {
            state.control[r] = ProvinceMap.all[r].country == p ? nil : p
            state.proxyConquests[r] = nil
            victims.insert(ProvinceMap.all[r].country)
        }
        for v in victims { recomputeTerritory(v) }
        for i in state.armies.indices where state.armies[i].owner == p && state.armies[i].servingFor == host {
            state.armies[i].servingFor = nil
            state.armies[i].covert = false
            state.armies[i].path = []
        }
        setRelation(p, host, -90)
        for other in countryIDs where other != p && other != host { changeRelation(other, p, by: -8) }
        addEvent("🗡️ Trahison : \(name(p)) garde \(regions.count) région(s) prises pour \(name(host)).", important: true)
        if let h = state.countries[host], h.aggressiveness > 0.3 || militaryPower(host) > militaryPower(p) * 0.6 {
            _ = declareWar(attacker: host, defender: p)
        }
        return ActionResult(success: true, message: "\(regions.count) région(s) passent sous votre drapeau. \(name(host)) ne vous le pardonnera pas.")
    }

    // MARK: - Ultimatum

    func ultimatumTargets(_ target: CountryID) -> [Int] {
        guard let p = state.playerID else { return [] }
        return provincesControlled(by: target).filter { prov in
            ProvinceMap.all[prov].neighbors.contains { controller(of: $0) == p }
        }
    }

    func evaluateUltimatum(target: CountryID, from p: CountryID) -> Evaluation {
        var e = Evaluation()
        let ratio = militaryPower(p) / max(1, defensiveStrength(of: target, against: p))
        e.add("Rapport de force", (ratio - 3) * 25)
        e.add("Relation", relation(target, p) * 0.2)
        if isNuclearProtected(target, against: p) { e.add("Protégé par l'arme nucléaire", -80) }
        if claim(by: p, on: target) != nil { e.add("Votre revendication", 15) }
        e.add("Fierté nationale", -30)
        return e
    }

    mutating func ultimatum(target: CountryID, province: Int) -> ActionResult {
        guard let p = state.playerID, controller(of: province) == target else { return ActionResult(success: false, message: "Région invalide.") }
        let e = evaluateUltimatum(target: target, from: p)
        if e.accepted {
            state.control[province] = ProvinceMap.all[province].country == p ? nil : p
            state.annexedProvinces.insert(province)
            recomputeTerritory(ProvinceMap.all[province].country)
            setRelation(p, target, min(relation(p, target), -60))
            for other in countryIDs where other != p && other != target { changeRelation(other, p, by: -5) }
            addEvent("📜 Sous la menace, \(name(target)) cède \(ProvinceMap.all[province].name) à \(name(p)).", important: true)
            return ActionResult(success: true, message: "\(name(target)) cède \(ProvinceMap.all[province].name) sans combattre.")
        }
        setRelation(p, target, min(relation(p, target), -70))
        if claim(by: p, on: target) == nil {
            state.claims.append(Claim(claimant: p, target: target, name: ProvinceMap.all[province].name, major: false))
        }
        return ActionResult(success: false, message: "\(name(target)) rejette l'ultimatum. Vous avez maintenant un motif de guerre.")
    }

    // MARK: - Opérations militaires

    /// Bombardement préparatoire : 6 jours de frappes sur une région ennemie voisine (missiles et drones).
    mutating func bombard(_ province: Int, from armyID: Int) -> ActionResult {
        guard let p = state.playerID, let a = state.armies.first(where: { $0.id == armyID }),
              enemies(of: a.side).contains(controller(of: province)) else {
            return ActionResult(success: false, message: "Il faut viser une région ennemie.")
        }
        guard ProvinceMap.all[a.province].neighbors.contains(province) || distanceKm(a.province, province) < 500 else {
            return ActionResult(success: false, message: "Trop loin : la cible doit être à portée de l'armée.")
        }
        guard var c = state.countries[p] else { return ActionResult(success: false, message: "") }
        let missiles = c.stock(.missile), drones = c.stock(.drone)
        guard missiles >= 20 || drones >= 100 else { return ActionResult(success: false, message: "Pas assez de missiles ni de drones.") }
        if missiles >= 20 { c.equipment[.missile] = missiles - max(10, missiles * 0.04) }
        else { c.equipment[.drone] = drones - max(50, drones * 0.05) }
        state.countries[p] = c
        state.bombardments[province] = Bombardment(by: p, daysLeft: 6)
        return ActionResult(success: true, message: "Bombardement de \(ProvinceMap.all[province].name) pendant 6 jours : défenses et forts affaiblis.")
    }

    /// Parachutage : une armée surtout aéroportée saute sur une région ennemie jusqu'à 700 km.
    mutating func airdrop(_ armyID: Int, to province: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else { return ActionResult(success: false, message: "") }
        let a = state.armies[i]
        let para = Double(a.divisions[.airborne] ?? 0) / Double(max(1, a.count))
        guard para >= 0.6 else { return ActionResult(success: false, message: "Il faut au moins 60 % de divisions aéroportées.") }
        guard enemies(of: a.side).contains(controller(of: province)) else { return ActionResult(success: false, message: "Visez une région ennemie.") }
        guard distanceKm(a.province, province) <= 700 else { return ActionResult(success: false, message: "Trop loin (700 km au maximum).") }
        guard airSuperiority(a.side, controller(of: province)) >= 0.45 else {
            return ActionResult(success: false, message: "La défense aérienne ennemie est trop forte.")
        }
        state.armies[i].path = [province]
        state.armies[i].airdrop = true
        state.armies[i].amphibious = false
        state.armies[i].progress = 0
        state.armies[i].training = false
        return ActionResult(success: true, message: "Parachutage sur \(ProvinceMap.all[province].name) dans 2 jours. Prenez la région derrière les lignes pour couper l'ennemi.")
    }

    /// Encerclement : les armées du groupe se placent tout autour de la région visée, puis l'assaillent ensemble.
    mutating func encircle(_ province: Int, with armyIDs: [Int]) -> ActionResult {
        guard let first = state.armies.first(where: { armyIDs.contains($0.id) }) else { return ActionResult(success: false, message: "") }
        let foes = enemies(of: first.side)
        guard foes.contains(controller(of: province)) else { return ActionResult(success: false, message: "Visez une région ennemie.") }
        var approaches = ProvinceMap.all[province].neighbors.filter { n in
            let c = controller(of: n)
            return c == first.side || c == first.owner || isFriendly(first.side, c) || foes.contains(c)
        }
        guard approaches.count >= 2, armyIDs.count >= 2 else {
            return ActionResult(success: false, message: "Il faut au moins 2 armées et 2 côtés d'approche (groupez des armées).")
        }
        var used: [Int] = []
        var ordered = 0
        for id in armyIDs {
            guard let i = state.armies.firstIndex(where: { $0.id == id }) else { continue }
            // Chaque armée prend le côté le plus proche encore libre.
            let free = approaches.filter { !used.contains($0) }
            let pool = free.isEmpty ? approaches : free
            guard let side = pool.min(by: { distanceKm(state.armies[i].province, $0) < distanceKm(state.armies[i].province, $1) }) else { continue }
            used.append(side)
            var ghost = state.armies[i]
            var path: [Int] = []
            if side != ghost.province {
                guard let r = route(for: ghost, to: side, throughEnemy: true), !r.amphibious else { continue }
                path = r.path
                ghost.province = side
            }
            state.armies[i].path = path + [province]
            state.armies[i].progress = 0
            state.armies[i].training = false
            state.armies[i].stance = .assault
            ordered += 1
        }
        approaches.removeAll()
        return ordered >= 2 ? ActionResult(success: true, message: "Tenaille sur \(ProvinceMap.all[province].name) : \(ordered) armées attaqueront de plusieurs côtés (+18 %).")
                            : ActionResult(success: false, message: "Les armées ne peuvent pas rejoindre assez de côtés.")
    }

    /// Chaque jour : bombardements, poches qui se rendent, villes assiégées qui tombent.
    mutating func dailyOperations() {
        // Bombardements
        for (prov, b) in state.bombardments {
            let org = state.provinceOrg[prov] ?? 1
            state.provinceOrg[prov] = max(0.25, org - 0.07)
            for i in state.armies.indices where state.armies[i].province == prov && enemies(of: b.by).contains(state.armies[i].side) {
                state.armies[i].organization = max(0.2, state.armies[i].organization - 0.03)
            }
            if b.daysLeft % 3 == 0, let f = state.forts[prov], f > 0 { state.forts[prov] = f > 1 ? f - 1 : nil }
            if b.daysLeft <= 1 { state.bombardments[prov] = nil } else { state.bombardments[prov]?.daysLeft -= 1 }
        }
        // Poches : une armée encerclée trop longtemps se rend.
        guard state.day % 2 == 0 else { return }
        var surrendered: [Int] = []
        for i in state.armies.indices {
            if state.armies[i].supply <= 0.15 { state.armies[i].cutDays += 2 } else { state.armies[i].cutDays = 0 }
            let a = state.armies[i]
            if a.cutDays >= 24 && a.organization < 0.35 { surrendered.append(i) }
        }
        for i in surrendered.reversed() {
            let a = state.armies[i]
            if var c = state.countries[a.owner] {
                for (t, n) in a.divisions { c.divisions[t] = max(0, (c.divisions[t] ?? 0) - n) }
                let men = Double(a.count) * 6
                c.activePersonnel = max(0, c.activePersonnel - men)
                c.casualties += men
                state.countries[a.owner] = c
            }
            let place = ProvinceMap.all[a.province].name
            if a.owner == state.playerID {
                addEvent("🏳️ Encerclée depuis des semaines, \(a.name) se rend à \(place) (\(a.count) divisions perdues).", important: true)
            } else if enemies(of: state.playerID ?? "").contains(a.side) {
                addEvent("🏳️ Une armée de \(name(a.owner)) encerclée à \(place) se rend : \(a.count) divisions capturées !", important: true)
            }
            state.armies.remove(at: i)
        }
        // Sièges : une région ennemie entièrement entourée, sans armée pour la tenir, finit par tomber.
        guard state.day % 10 == 0 else { return }
        for war in state.wars where war.isActive {
            for side in [war.attackers, war.defenders] {
                let other = side == war.attackers ? war.defenders : war.attackers
                for target in other {
                    for prov in provincesControlled(by: target) {
                        let p = ProvinceMap.all[prov]
                        guard !p.neighbors.isEmpty, !p.coastal || (state.countries[target]?.navalPower ?? 0) < 1,
                              !state.armies.contains(where: { $0.province == prov && isFriendly(target, $0.side) }) else { continue }
                        let holders = Set(p.neighbors.map { controller(of: $0) })
                        guard holders.allSatisfy({ side.contains($0) }) else { continue }
                        let winner = side.max { a, b in
                            p.neighbors.filter { controller(of: $0) == a }.count < p.neighbors.filter { controller(of: $0) == b }.count
                        } ?? side[0]
                        state.control[prov] = p.country == winner ? nil : winner
                        state.annexedProvinces.remove(prov)
                        recomputeTerritory(p.country)
                        if winner == state.playerID || target == state.playerID {
                            addEvent("🏰 Assiégée de toutes parts, \(p.name) capitule devant \(name(winner)).", important: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chaque mois : accords qui se déclenchent, secrets qui s'éventent

    mutating func monthlyIntrigue() {
        guard let p = state.playerID else { return }
        // Attaques conjointes
        var keep: [JointPlan] = []
        for plan in state.jointPlans {
            if state.day < plan.day { keep.append(plan); continue }
            guard state.countries[plan.partner] != nil, state.countries[plan.target] != nil else { continue }
            if !enemies(of: plan.target).contains(plan.partner) {
                _ = declareWar(attacker: plan.partner, defender: plan.target)
                addEvent("🤝 Comme convenu, \(name(plan.partner)) attaque \(name(plan.target)).", important: true)
            }
            if !enemies(of: plan.target).contains(p) {
                if state.day > plan.day + 30 {
                    changeRelation(p, plan.partner, by: -40)
                    addEvent("😠 \(name(plan.partner)) vous accuse de l'avoir abandonné face à \(name(plan.target)).", important: true)
                } else {
                    keep.append(plan)
                    addEvent("⏳ \(name(plan.partner)) attend votre déclaration de guerre contre \(name(plan.target)).", important: true)
                }
            }
        }
        state.jointPlans = keep
        // Usines prêtées qui reviennent
        var stillLent: [FactoryLease] = []
        for lease in state.leases {
            if state.day >= lease.untilDay {
                state.countries[lease.to]?.militaryFactories = max(0, (state.countries[lease.to]?.militaryFactories ?? 0) - lease.factories)
                state.countries[p]?.militaryFactories += lease.factories
                addEvent("🏭 Nos \(Int(lease.factories)) usines prêtées à \(name(lease.to)) nous reviennent.", important: false)
            } else {
                stillLent.append(lease)
            }
        }
        state.leases = stillLent
        // Aides secrètes : risque d'être découvert
        let intelFoe = { (id: CountryID) in self.state.countries[id]?.intelligence ?? 0.4 }
        var hidden: [CovertAid] = []
        for aid in state.covertAid where state.day < aid.untilDay {
            let spy = aid.against.map(intelFoe).max() ?? 0
            if Double.random(in: 0...1, using: &state.rng) < 0.05 + 0.12 * spy {
                for foe in aid.against { changeRelation(p, foe, by: -30) }
                for other in countryIDs where other != p { changeRelation(other, p, by: -3) }
                addEvent("🕵️ Scandale : notre aide secrète à \(name(aid.to)) est révélée au grand jour.", important: true)
            } else {
                hidden.append(aid)
            }
        }
        state.covertAid = hidden
        // Corps expéditionnaires : secret éventé, ou ennemi qui riposte
        for i in state.armies.indices where state.armies[i].owner == p {
            guard let host = state.armies[i].servingFor else { continue }
            let foes = enemies(of: host)
            if state.armies[i].covert {
                let spy = foes.map(intelFoe).max() ?? 0
                let fighting = state.armies[i].engaged || state.battles[state.armies[i].province] != nil
                if fighting && Double.random(in: 0...1, using: &state.rng) < 0.06 + 0.15 * spy {
                    state.armies[i].covert = false
                    for foe in foes { changeRelation(p, foe, by: -35) }
                    addEvent("📸 Nos « volontaires » en \(name(host)) sont identifiés : \(state.armies[i].name) est démasquée.", important: true)
                }
            } else {
                for foe in foes where !enemies(of: p).contains(foe) {
                    guard let f = state.countries[foe] else { continue }
                    let chance = 0.08 * f.aggressiveness * min(2, militaryPower(foe) / max(1, militaryPower(p)))
                    if Double.random(in: 0...1, using: &state.rng) < chance {
                        _ = declareWar(attacker: foe, defender: p)
                        addEvent("⚔️ Furieux de voir nos troupes en \(name(host)), \(name(foe)) nous déclare la guerre.", important: true)
                    }
                }
            }
            // L'hôte en paix : la mission s'achève.
            if foes.isEmpty && !state.armies[i].engaged {
                state.armies[i].servingFor = nil
                state.armies[i].covert = false
            }
        }
    }
}
