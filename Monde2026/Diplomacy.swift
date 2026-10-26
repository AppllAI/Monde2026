import Foundation

// =============================================================
//  Diplomacy.swift
//  Relations, traités, blocs, revendications, déclarations de
//  guerre, alliés qui entrent en guerre, paix, et l'IA
//  diplomatique (qui juge chaque proposition et explique pourquoi).
// =============================================================

// MARK: - Types

enum TreatyKind: String, Codable, CaseIterable {
    case alliance, nonAggression, tradePact, guarantee, sanctions

    var name: String {
        switch self {
        case .alliance: return "Alliance défensive"
        case .nonAggression: return "Pacte de non-agression"
        case .tradePact: return "Accord commercial"
        case .guarantee: return "Garantie d'indépendance"
        case .sanctions: return "Sanctions"
        }
    }

    /// Garantie et sanctions vont d'un pays vers un autre ; les autres traités sont réciproques.
    var isDirectional: Bool { self == .guarantee || self == .sanctions }
}

struct Treaty: Codable, Identifiable {
    let id: Int
    let kind: TreatyKind
    let a: CountryID
    let b: CountryID
    let sinceDay: Int

    func involves(_ x: CountryID) -> Bool { a == x || b == x }
    func partner(of x: CountryID) -> CountryID { a == x ? b : a }
}

struct Bloc: Codable, Identifiable {
    let id: String
    let name: String
    var members: [CountryID]
    let isMilitary: Bool
    let isEconomic: Bool
    var leader: CountryID? = nil
}

struct Claim: Codable, Identifiable {
    let claimant: CountryID
    let target: CountryID
    let name: String
    let major: Bool
    var id: String { claimant + ">" + target }
}

struct WarPlan: Codable {
    var attacker: CountryID
    var target: CountryID
    var monthsLeft: Int
}

enum PeaceTerms: String, Codable, CaseIterable {
    case whitePeace, statusQuo

    var name: String {
        switch self {
        case .whitePeace: return "Paix blanche (chacun rend tout)"
        case .statusQuo: return "Statu quo (chacun garde ce qu'il occupe)"
        }
    }
}

enum ProposalKind: String, Codable, CaseIterable {
    case alliance, nonAggression, tradePact, peace, jointAttack

    var name: String {
        switch self {
        case .alliance: return "Alliance défensive"
        case .nonAggression: return "Pacte de non-agression"
        case .tradePact: return "Accord commercial"
        case .peace: return "Traité de paix"
        case .jointAttack: return "Attaque commune"
        }
    }

    var treaty: TreatyKind? {
        switch self {
        case .alliance: return .alliance
        case .nonAggression: return .nonAggression
        case .tradePact: return .tradePact
        case .peace, .jointAttack: return nil
        }
    }

    /// Coût en influence pour le joueur.
    var influenceCost: Double {
        switch self {
        case .alliance: return 25
        case .nonAggression: return 15
        case .tradePact: return 15
        case .peace, .jointAttack: return 0
        }
    }
}

struct Proposal: Codable, Identifiable {
    let id: Int
    let from: CountryID
    let to: CountryID
    let kind: ProposalKind
    let warID: Int?
    let terms: PeaceTerms?
    let day: Int
    var target: CountryID? = nil      // attaque commune : le pays visé
    var inDays: Int = 60
}

struct EvalReason: Identifiable {
    let id: Int
    let text: String
    let value: Double
}

/// Décision de l'IA, avec le détail de ses raisons (affiché au joueur).
struct Evaluation {
    private(set) var reasons: [EvalReason] = []

    var score: Double { reasons.reduce(0) { $0 + $1.value } }
    var accepted: Bool { score > 0 }

    mutating func add(_ text: String, _ value: Double) {
        guard abs(value) >= 0.5 else { return }
        reasons.append(EvalReason(id: reasons.count, text: text, value: value.rounded()))
    }
}

struct GameEvent: Codable, Identifiable {
    let id: Int
    let day: Int
    let text: String
    let important: Bool
}

struct ActionResult {
    let success: Bool
    let message: String
}

// MARK: - Relations, blocs, traités

extension Simulation {

    static func pairKey(_ a: CountryID, _ b: CountryID) -> String {
        a < b ? a + "|" + b : b + "|" + a
    }

    func bloc(_ id: String) -> Bloc? {
        state.blocs.first { $0.id == id }
    }

    func blocs(of id: CountryID) -> [Bloc] {
        state.blocs.filter { $0.members.contains(id) }
    }

    func shareMilitaryBloc(_ a: CountryID, _ b: CountryID) -> Bool {
        state.blocs.contains { $0.isMilitary && $0.members.contains(a) && $0.members.contains(b) }
    }

    func shareEconomicBloc(_ a: CountryID, _ b: CountryID) -> Bool {
        state.blocs.contains { $0.isEconomic && $0.members.contains(a) && $0.members.contains(b) }
    }

    func sharePoliticalBloc(_ a: CountryID, _ b: CountryID) -> Bool {
        state.blocs.contains { !$0.isMilitary && !$0.isEconomic && $0.members.contains(a) && $0.members.contains(b) }
    }

    func inOpposedBlocs(_ a: CountryID, _ b: CountryID) -> Bool {
        for (x, y) in WorldRelations.opposedBlocs {
            guard let bx = bloc(x), let by = bloc(y) else { continue }
            if (bx.members.contains(a) && by.members.contains(b)) || (bx.members.contains(b) && by.members.contains(a)) {
                return true
            }
        }
        return false
    }

    func hasTreaty(_ kind: TreatyKind, _ a: CountryID, _ b: CountryID) -> Bool {
        state.treaties.contains { t in
            guard t.kind == kind else { return false }
            if kind.isDirectional { return t.a == a && t.b == b }
            return (t.a == a && t.b == b) || (t.a == b && t.b == a)
        }
    }

    func treaties(of id: CountryID) -> [Treaty] {
        state.treaties.filter { $0.involves(id) }
    }

    func partners(of id: CountryID, _ kind: TreatyKind) -> [CountryID] {
        treaties(of: id).filter { $0.kind == kind }.map { $0.partner(of: id) }
    }

    /// Alliés militaires : traités d'alliance + membres des mêmes blocs militaires.
    func allies(of id: CountryID) -> Set<CountryID> {
        relCache.allies(id, key: relationKey()) { computeAllies(of: id) }
    }

    private func computeAllies(of id: CountryID) -> Set<CountryID> {
        var result = Set(partners(of: id, .alliance))
        for b in blocs(of: id) where b.isMilitary {
            result.formUnion(b.members)
        }
        result.remove(id)
        return result.filter { state.countries[$0] != nil }
    }

    func guarantors(of id: CountryID) -> [CountryID] {
        state.treaties.filter { $0.kind == .guarantee && $0.b == id }.map { $0.a }
    }

    func areSanctioning(_ a: CountryID, _ b: CountryID) -> Bool {
        hasTreaty(.sanctions, a, b) || hasTreaty(.sanctions, b, a)
    }

    /// Pays avec lesquels le commerce est impossible (guerre ou sanctions).
    func tradeBlockedPartners(of id: CountryID) -> Set<CountryID> {
        var result = enemies(of: id)
        for t in state.treaties where t.kind == .sanctions && t.involves(id) {
            result.insert(t.partner(of: id))
        }
        return result
    }

    func claim(by a: CountryID, on b: CountryID) -> Claim? {
        state.claims.first { $0.claimant == a && $0.target == b }
    }

    func claims(involving id: CountryID) -> [Claim] {
        state.claims.filter { $0.claimant == id || $0.target == id }
    }

    @discardableResult
    mutating func addTreaty(_ kind: TreatyKind, _ a: CountryID, _ b: CountryID) -> Bool {
        guard a != b, state.countries[a] != nil, state.countries[b] != nil, !hasTreaty(kind, a, b) else { return false }
        state.treaties.append(Treaty(id: state.nextTreatyID, kind: kind, a: a, b: b, sinceDay: state.day))
        state.nextTreatyID += 1
        return true
    }

    mutating func removeTreaties(_ kinds: [TreatyKind], between a: CountryID, _ b: CountryID) {
        state.treaties.removeAll { t in
            kinds.contains(t.kind) && ((t.a == a && t.b == b) || (t.a == b && t.b == a))
        }
    }

    /// Relation « structurelle » : ce que justifient blocs, traités, revendications et guerres.
    /// Relation justifiée par les blocs, traités, revendications et guerres (un seul passage sur chaque liste).
    func structuralRelation(_ a: CountryID, _ b: CountryID) -> Double {
        var r = 0.0
        var military = false, economic = false, political = false
        var aInNato = false, bInNato = false, aInCsto = false, bInCsto = false
        for bloc in state.blocs {
            let hasA = bloc.members.contains(a)
            let hasB = bloc.members.contains(b)
            if hasA && hasB {
                if bloc.isMilitary { military = true } else if bloc.isEconomic { economic = true } else { political = true }
            }
            if bloc.id == "OTAN" { aInNato = hasA; bInNato = hasB }
            if bloc.id == "OTSC" { aInCsto = hasA; bInCsto = hasB }
        }
        if military { r += 35 }
        if economic { r += 20 }
        if political { r += 10 }
        var guarantee = false, sanctions = false
        for t in state.treaties where (t.a == a && t.b == b) || (t.a == b && t.b == a) {
            switch t.kind {
            case .alliance: r += 30
            case .tradePact: r += 10
            case .nonAggression: r += 5
            case .guarantee: guarantee = true
            case .sanctions: sanctions = true
            }
        }
        if guarantee { r += 20 }
        if sanctions { r -= 35 }
        if state.claims.contains(where: { ($0.claimant == a && $0.target == b) || ($0.claimant == b && $0.target == a) }) {
            r -= 30
        }
        if (aInNato && bInCsto) || (aInCsto && bInNato) { r -= 25 }
        for war in state.wars where war.isActive {
            if (war.attackers.contains(a) && war.defenders.contains(b)) || (war.attackers.contains(b) && war.defenders.contains(a)) {
                r -= 100
                break
            }
        }
        r += regimeAffinity(a, b)
        return r.clamped(-100, 100)
    }

    func relation(_ a: CountryID, _ b: CountryID) -> Double {
        if a == b { return 100 }
        return state.relations[Simulation.pairKey(a, b)] ?? structuralRelation(a, b)
    }

    mutating func setRelation(_ a: CountryID, _ b: CountryID, _ value: Double) {
        guard a != b else { return }
        state.relations[Simulation.pairKey(a, b)] = value.clamped(-100, 100)
    }

    mutating func changeRelation(_ a: CountryID, _ b: CountryID, by delta: Double) {
        guard a != b else { return }
        setRelation(a, b, relation(a, b) + delta)
    }

    /// Chaque mois, les relations tendent vers (structure + mémoire historique). La mémoire s'efface lentement.
    mutating func driftRelations() {
        // Tout ce qui fait la relation « structurelle » est rangé une fois pour toutes (traités, blocs,
        // revendications, guerres) : la mise à jour des ~14 000 paires de pays devient très rapide.
        var treatyFlags: [String: (Double, Bool, Bool)] = [:]     // bonus, garantie, sanctions
        for t in state.treaties {
            let k = Simulation.pairKey(t.a, t.b)
            var f = treatyFlags[k] ?? (0, false, false)
            switch t.kind {
            case .alliance: f.0 += 30
            case .tradePact: f.0 += 10
            case .nonAggression: f.0 += 5
            case .guarantee: f.1 = true
            case .sanctions: f.2 = true
            }
            treatyFlags[k] = f
        }
        var blocsOf: [CountryID: [Int]] = [:]
        for (i, b) in state.blocs.enumerated() { for m in b.members { blocsOf[m, default: []].append(i) } }
        let nato = Set(bloc("OTAN")?.members ?? []), csto = Set(bloc("OTSC")?.members ?? [])
        var claimed = Set<String>()
        for c in state.claims { claimed.insert(Simulation.pairKey(c.claimant, c.target)) }
        var atWar = Set<String>()
        for w in state.wars where w.isActive {
            for x in w.attackers { for y in w.defenders { atWar.insert(Simulation.pairKey(x, y)) } }
        }
        var democratic: [CountryID: Bool] = [:]
        for (id, c) in state.countries { democratic[id] = c.government.isDemocratic }
        func structural(_ a: CountryID, _ b: CountryID, _ key: String) -> Double {
            var r = 0.0
            var military = false, economic = false, political = false
            let ba = blocsOf[a] ?? [], bb = blocsOf[b] ?? []
            for i in ba where bb.contains(i) {
                let bloc = state.blocs[i]
                if bloc.isMilitary { military = true } else if bloc.isEconomic { economic = true } else { political = true }
            }
            if military { r += 35 }
            if economic { r += 20 }
            if political { r += 10 }
            if let f = treatyFlags[key] {
                r += f.0
                if f.1 { r += 20 }
                if f.2 { r -= 35 }
            }
            if claimed.contains(key) { r -= 30 }
            if (nato.contains(a) && csto.contains(b)) || (csto.contains(a) && nato.contains(b)) { r -= 25 }
            if atWar.contains(key) { r -= 100 }
            if let da = democratic[a], let db = democratic[b] {
                r += da && db ? 10 : (da != db ? -5 : 5)
            }
            return r.clamped(-100, 100)
        }
        for (key, value) in state.relations {
            let parts = key.split(separator: "|")
            guard parts.count == 2 else { continue }
            let a = String(parts[0]), b = String(parts[1])
            let memory = state.relationMemory[key] ?? 0
            let target = (structural(a, b, key) + memory).clamped(-100, 100)
            state.relations[key] = value + (target - value) * 0.04
        }
        for key in Array(state.relationMemory.keys) {
            state.relationMemory[key] = (state.relationMemory[key] ?? 0) * 0.99
        }
    }

    // MARK: - Puissance

    func militaryPower(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        return c.landStrengthIndex + c.airPower * 1.5 + c.navalPower * 0.5 + Double(c.divisionCount) * 2
    }

    func sidePower(_ ids: [CountryID]) -> Double {
        ids.reduce(0.0) { $0 + ((state.countries[$1]?.capitulated ?? true) ? 0 : militaryPower($1)) }
    }

    /// Capacité d'un pays à peser sur un conflit lointain (0…1).
    func reach(_ from: CountryID, _ to: CountryID) -> Double {
        guard let A = state.countries[from], let B = state.countries[to] else { return 0 }
        if A.neighbors.contains(to) || A.region == B.region { return 1 }
        return projection(from: A, to: B)
    }

    /// Qui viendrait défendre `target` s'il était attaqué par `attacker`, et avec quelle probabilité.
    func defensiveSupporters(of target: CountryID, against attacker: CountryID) -> [(CountryID, Double)] {
        var probs: [CountryID: Double] = [:]
        let attackerAllies = allies(of: attacker)
        for ally in allies(of: target) where ally != attacker && !attackerAllies.contains(ally) {
            let formal = hasTreaty(.alliance, ally, target)
            let base = formal ? 0.65 : 0.8   // bloc militaire = défense collective
            probs[ally] = max(probs[ally] ?? 0, (base + relation(ally, target) / 400).clamped(0.1, 0.98))
        }
        for g in guarantors(of: target) where g != attacker && !attackerAllies.contains(g) {
            probs[g] = max(probs[g] ?? 0, (0.6 + relation(g, target) / 400).clamped(0.1, 0.95))
        }
        return probs.keys.sorted().map { ($0, probs[$0] ?? 0) }
    }

    /// Force d'un pays attaqué, en comptant ses alliés probables.
    func defensiveStrength(of target: CountryID, against attacker: CountryID) -> Double {
        var total = militaryPower(target)
        for (ally, p) in defensiveSupporters(of: target, against: attacker) {
            total += militaryPower(ally) * p * reach(ally, target)
        }
        return total
    }

    func isNuclearProtected(_ target: CountryID, against attacker: CountryID) -> Bool {
        if (state.countries[target]?.nuclearWarheads ?? 0) > 0 { return true }
        for (ally, p) in defensiveSupporters(of: target, against: attacker) where p >= 0.5 {
            if (state.countries[ally]?.nuclearWarheads ?? 0) > 0 { return true }
        }
        return false
    }

    func isJustified(_ attacker: CountryID, _ defender: CountryID) -> Bool {
        claim(by: attacker, on: defender) != nil || relation(attacker, defender) < -50
    }

    // MARK: - Mise en place du monde de 2026

    mutating func setupWorldRelations() {
        state.blocs = WorldRelations.blocs.map { b in
            var copy = b
            copy.members = b.members.filter { state.countries[$0] != nil }
            return copy
        }
        for (a, b) in WorldRelations.alliances { addTreaty(.alliance, a, b) }
        for (a, b) in WorldRelations.guarantees { addTreaty(.guarantee, a, b) }
        for (a, b) in WorldRelations.nonAggressionPacts { addTreaty(.nonAggression, a, b) }
        for (a, b) in WorldRelations.tradePacts { addTreaty(.tradePact, a, b) }
        for s in WorldRelations.westernSanctioners + WorldRelations.europeanUnion {
            for t in WorldRelations.westernSanctionTargets {
                addTreaty(.sanctions, s, t)
            }
        }
        for (a, b) in WorldRelations.otherSanctions { addTreaty(.sanctions, a, b) }
        state.claims = WorldRelations.claims.filter { state.countries[$0.claimant] != nil && state.countries[$0.target] != nil }

        // Territoires tenus par un autre pays. Les données décrivent la partie contrôlée :
        // on reconstitue l'économie du territoire complet.
        for (victim, occupier, fraction, atWar) in WorldRelations.initialControl {
            guard var v = state.countries[victim], state.countries[occupier] != nil else { continue }
            v.gdp /= 1 - fraction * 0.9
            v.civilianFactories /= 1 - fraction
            v.militaryFactories /= 1 - fraction
            for r in Resource.allCases {
                v.resourceProduction[r] = (v.resourceProduction[r] ?? 0) / (1 - fraction)
            }
            state.countries[victim] = v
            if var o = state.countries[occupier] {
                o.gdp = max(o.gdp * 0.5, o.gdp - v.gdp * fraction * 0.35)
                state.countries[occupier] = o
            }
            if atWar {
                state.occupation[victim, default: [:]][occupier] = fraction
                state.wars.append(War(id: state.nextWarID, name: "Guerre russo-ukrainienne",
                                      attackers: [occupier], defenders: [victim], startDay: -1407,
                                      isActive: true, lastNet: fraction, momentum: 0))
                state.nextWarID += 1
            } else {
                state.annexation[victim, default: [:]][occupier] = fraction
            }
        }
        if state.countries["UKR"] != nil {
            state.countries["UKR"]?.economyMode = .warEconomy
            state.countries["UKR"]?.warExhaustion = 0.45
        }
        if state.countries["RUS"] != nil {
            state.countries["RUS"]?.economyMode = .partialMobilization
            state.countries["RUS"]?.warExhaustion = 0.3
        }

        // Relations historiques : la différence avec la structure devient une « mémoire ».
        for (a, b, value) in WorldRelations.relations {
            guard state.countries[a] != nil, state.countries[b] != nil, a != b else { continue }
            let key = Simulation.pairKey(a, b)
            state.relations[key] = value
            state.relationMemory[key] = value - structuralRelation(a, b)
        }
        state.worldTension = 45
    }

    // MARK: - Guerre et paix

    @discardableResult
    mutating func declareWar(attacker: CountryID, defender: CountryID) -> Int? {
        guard attacker != defender,
              let a = state.countries[attacker], let d = state.countries[defender],
              !a.capitulated, !d.capitulated,
              !enemies(of: attacker).contains(defender) else { return nil }
        let justified = isJustified(attacker, defender)
        let brokePact = hasTreaty(.nonAggression, attacker, defender)
        removeTreaties([.alliance, .nonAggression, .tradePact, .guarantee], between: attacker, defender)

        let id = state.nextWarID
        state.nextWarID += 1
        let warName: String
        if let c = claim(by: attacker, on: defender) {
            warName = "Guerre pour \(c.name)"
        } else {
            warName = "Guerre \(a.name) – \(d.name)"
        }
        state.wars.append(War(id: id, name: warName, attackers: [attacker], defenders: [defender],
                              startDay: state.day, isActive: true, lastNet: 0, momentum: 0))
        setRelation(attacker, defender, -100)
        state.worldTension = min(100, state.worldTension + (justified ? 8 : 20))
        state.warPlans.removeAll { $0.attacker == attacker }

        if !justified || brokePact {
            for other in countryIDs where other != attacker && other != defender {
                let penalty = 10 + max(0, relation(other, defender)) * 0.3 + (brokePact ? 10 : 0)
                changeRelation(other, attacker, by: -penalty)
            }
        }
        let suffix = justified ? "" : " sans motif légitime"
        addEvent("⚔️ \(a.name) déclare la guerre à \(d.name)\(suffix).", important: true)
        if let p = state.playerID, attacker == p || defender == p || allies(of: p).contains(defender) {
            state.pauseRequested = true
        }

        // Les alliés et garants du défenseur décident d'entrer en guerre.
        for (ally, probability) in defensiveSupporters(of: defender, against: attacker) {
            guard let allyCountry = state.countries[ally], !allyCountry.capitulated,
                  !enemies(of: ally).contains(attacker) else { continue }
            let joins = ally == state.playerID || Double.random(in: 0...1, using: &state.rng) < probability
            if joins {
                joinWar(warID: id, country: ally, asAttacker: false)
                addEvent("🛡️ \(allyCountry.name) entre en guerre aux côtés de \(d.name).", important: true)
            } else if probability >= 0.5 {
                changeRelation(ally, defender, by: -20)
                addEvent("\(allyCountry.name) refuse d'honorer son engagement envers \(d.name).")
            }
        }

        // Une agression injustifiée déclenche des sanctions occidentales.
        if !justified {
            let attackerAllies = allies(of: attacker)
            var count = 0
            for s in WorldRelations.westernSanctioners + WorldRelations.europeanUnion
            where s != attacker && s != defender && !attackerAllies.contains(s) && relation(s, defender) > 0 {
                if addTreaty(.sanctions, s, attacker) { count += 1 }
            }
            if count > 0 {
                addEvent("🚫 \(count) pays imposent des sanctions à \(a.name).", important: attacker == state.playerID)
            }
        }
        return id
    }

    mutating func joinWar(warID: Int, country: CountryID, asAttacker: Bool) {
        guard let index = state.wars.firstIndex(where: { $0.id == warID && $0.isActive }) else { return }
        let war = state.wars[index]
        guard !war.attackers.contains(country), !war.defenders.contains(country) else { return }
        let enemySide = asAttacker ? war.defenders : war.attackers
        if asAttacker {
            state.wars[index].attackers.append(country)
        } else {
            state.wars[index].defenders.append(country)
        }
        for enemy in enemySide {
            removeTreaties([.alliance, .nonAggression, .tradePact, .guarantee], between: country, enemy)
            changeRelation(country, enemy, by: -40)
        }
    }

    /// Fin d'une guerre. Statu quo : les zones occupées deviennent des annexions.
    mutating func applyPeace(warID: Int, terms: PeaceTerms) {
        guard let index = state.wars.firstIndex(where: { $0.id == warID && $0.isActive }) else { return }
        let war = state.wars[index]
        state.wars[index].isActive = false
        settleProvinces(between: war.attackers, and: war.defenders, keep: terms == .statusQuo)
        for id in war.attackers + war.defenders {
            state.countries[id]?.capitulated = false
            relCache.reset()
        }
        if let a = war.attackers.first, let d = war.defenders.first {
            changeRelation(a, d, by: 25)
        }
        state.worldTension = max(0, state.worldTension - 5)
        state.proposals.removeAll { $0.warID == warID }
        let involvesPlayer = state.playerID.map { war.attackers.contains($0) || war.defenders.contains($0) } ?? false
        addEvent("🕊️ Paix : \(war.name) — \(terms.name).", important: involvesPlayer)
    }

    func warSide(of id: CountryID, in war: War) -> (mine: [CountryID], enemy: [CountryID])? {
        if war.attackers.contains(id) { return (war.attackers, war.defenders) }
        if war.defenders.contains(id) { return (war.defenders, war.attackers) }
        return nil
    }

    func leader(of side: [CountryID]) -> CountryID? {
        side.first { !(state.countries[$0]?.capitulated ?? true) } ?? side.first
    }

    // MARK: - Évaluations de l'IA (avec raisons)

    func evaluate(_ kind: ProposalKind, from: CountryID, to: CountryID,
                  warID: Int? = nil, terms: PeaceTerms? = nil) -> Evaluation {
        var e: Evaluation
        switch kind {
        case .alliance: e = evaluateAlliance(from: from, to: to)
        case .nonAggression: e = evaluateNonAggression(from: from, to: to)
        case .tradePact: e = evaluateTradePact(from: from, to: to)
        case .peace:
            guard let warID = warID, let terms = terms else { return Evaluation() }
            e = evaluatePeace(warID: warID, evaluator: to, terms: terms)
        case .jointAttack:
            e = Evaluation()
        }
        if from == state.playerID {
            e.add("Niveau de difficulté", state.difficulty.diplomacyBias)
        }
        return e
    }

    func evaluateAlliance(from f: CountryID, to t: CountryID) -> Evaluation {
        var e = Evaluation()
        guard let F = state.countries[f], let T = state.countries[t] else { return e }
        if hasTreaty(.alliance, f, t) || shareMilitaryBloc(f, t) {
            e.add("Déjà alliés", -100)
            return e
        }
        e.add("Une alliance est un engagement lourd", -25)
        let rel = relation(t, f)
        e.add(rel >= 0 ? "Bonnes relations" : "Mauvaises relations", rel * 0.6)
        var sharedThreat = false
        for x in countryIDs where x != f && x != t {
            if relation(t, x) < -50 && relation(f, x) < -50 && militaryPower(x) > militaryPower(t) * 0.8 {
                sharedThreat = true
                break
            }
        }
        if sharedThreat { e.add("Menace commune", 25) }
        let ratio = militaryPower(f) / max(militaryPower(t), 1)
        e.add(ratio >= 1 ? "Votre armée nous protégerait" : "Votre armée est plus faible que la nôtre",
              (log2(max(ratio, 0.01)) * 8).clamped(-20, 20))
        let fEnemies = enemies(of: f)
        if !fEnemies.isEmpty && !fEnemies.isSubset(of: enemies(of: t)) {
            e.add("Vous êtes en guerre : nous serions entraînés", -40)
        }
        var closeToRival = false
        for x in countryIDs where x != f && x != t {
            if relation(t, x) > 50 && relation(f, x) < -40 {
                closeToRival = true
                break
            }
        }
        if closeToRival { e.add("Nous sommes proches de vos rivaux", -30) }
        if inOpposedBlocs(f, t) { e.add("Blocs militaires opposés", -50) }
        if claim(by: f, on: t) != nil || claim(by: t, on: f) != nil { e.add("Différend territorial", -60) }
        if !F.neighbors.contains(t) && F.region != T.region { e.add("Trop éloignés", -15) }
        if hasTreaty(.nonAggression, f, t) { e.add("Pacte de non-agression existant", 10) }
        if hasTreaty(.tradePact, f, t) { e.add("Partenaires commerciaux", 5) }
        if T.nuclearWarheads == 0 && F.nuclearWarheads > 0 { e.add("Parapluie nucléaire", 10) }
        if areSanctioning(f, t) { e.add("Sanctions entre nous", -50) }
        return e
    }

    func evaluateNonAggression(from f: CountryID, to t: CountryID) -> Evaluation {
        var e = Evaluation()
        guard let T = state.countries[t] else { return e }
        if hasTreaty(.nonAggression, f, t) {
            e.add("Pacte déjà en vigueur", -100)
            return e
        }
        if enemies(of: t).contains(f) {
            e.add("Nous sommes en guerre", -100)
            return e
        }
        e.add("Gage de stabilité", 10)
        let rel = relation(t, f)
        e.add(rel >= 0 ? "Bonnes relations" : "Mauvaises relations", rel * 0.4)
        if let c = claim(by: t, on: f), c.major { e.add("Nous revendiquons \(c.name)", -35) }
        if militaryPower(f) > militaryPower(t) * 1.5 { e.add("Votre armée nous inquiète", 15) }
        if T.aggressiveness > 0.4 { e.add("Nous voulons garder les mains libres", -15) }
        if inOpposedBlocs(f, t) { e.add("Blocs rivaux", -10) }
        return e
    }

    func evaluateTradePact(from f: CountryID, to t: CountryID) -> Evaluation {
        var e = Evaluation()
        guard let F = state.countries[f], let T = state.countries[t] else { return e }
        if hasTreaty(.tradePact, f, t) {
            e.add("Accord déjà en vigueur", -100)
            return e
        }
        if areSanctioning(f, t) { e.add("Sanctions en vigueur", -100) }
        if enemies(of: t).contains(f) { e.add("Nous sommes en guerre", -100) }
        e.add("Intérêt économique", 15)
        let rel = relation(t, f)
        e.add(rel >= 0 ? "Bonnes relations" : "Mauvaises relations", rel * 0.4)
        var complementary = false
        for r in Resource.allCases {
            if (F.resourceExports[r] ?? 0) > 0.05 && (T.resourceImports[r] ?? 0) > 0.05 {
                complementary = true
                break
            }
        }
        if complementary { e.add("Vos ressources nous intéressent", 10) }
        let marketRatio = F.gdp / max(T.gdp, 1)
        e.add(marketRatio >= 1 ? "Accès à un grand marché" : "Votre marché est petit",
              (log10(max(marketRatio, 0.001)) * 8).clamped(-10, 15))
        if shareEconomicBloc(f, t) { e.add("Même zone économique", 5) }
        return e
    }

    func evaluatePeace(warID: Int, evaluator: CountryID, terms: PeaceTerms) -> Evaluation {
        var e = Evaluation()
        guard let war = state.wars.first(where: { $0.id == warID && $0.isActive }),
              let sides = warSide(of: evaluator, in: war),
              let me = state.countries[evaluator],
              let enemyLeader = leader(of: sides.enemy),
              let enemy = state.countries[enemyLeader] else { return e }
        var occMine = 0.0
        for o in sides.enemy { occMine += state.occupation[evaluator]?[o] ?? 0 }
        var occTheirs = 0.0
        for m in sides.mine { occTheirs += state.occupation[enemyLeader]?[m] ?? 0 }

        e.add("Volonté de poursuivre le combat", -10)
        e.add("Lassitude de guerre", me.warExhaustion * 70)
        e.add("L'ennemi s'épuise", -enemy.warExhaustion * 30)
        let momentum = war.attackers.contains(evaluator) ? war.momentum : -war.momentum
        e.add(momentum > 0 ? "Le front avance en notre faveur" : "Le front recule", (-momentum * 1500).clamped(-30, 30))
        switch terms {
        case .whitePeace:
            let v = (occMine - occTheirs) * 120
            e.add(v >= 0 ? "Récupérer nos territoires" : "Rendre nos conquêtes", v)
        case .statusQuo:
            let v = (occTheirs - occMine) * 120
            e.add(v >= 0 ? "Garder nos conquêtes" : "Abandonner des territoires occupés", v)
            if occMine > 0.01 { e.add("Accepter la perte de territoires", -15) }
        }
        if state.day - war.startDay < 90 { e.add("La guerre vient de commencer", -20) }
        if me.divisionFill < 0.4 { e.add("Armée à bout de souffle", 15) }
        let ratio = sidePower(sides.mine) / max(sidePower(sides.enemy), 1)
        if ratio > 1.5 {
            e.add("Nous sommes plus forts", -15)
        } else if ratio < 0.67 {
            e.add("Nous sommes plus faibles", 15)
        }
        if relation(evaluator, enemyLeader) < -90 { e.add("Haine profonde", -10) }
        return e
    }

    /// Un pays accepterait-il d'entrer dans une guerre existante ?
    func evaluateJoinWar(country x: CountryID, warID: Int, asAttacker: Bool) -> Evaluation {
        var e = Evaluation()
        guard let war = state.wars.first(where: { $0.id == warID && $0.isActive }),
              let X = state.countries[x] else { return e }
        let friends = asAttacker ? war.attackers : war.defenders
        let foes = asAttacker ? war.defenders : war.attackers
        guard let friend = leader(of: friends), let foe = leader(of: foes) else { return e }
        if foes.contains(x) || friends.contains(x) {
            e.add("Déjà impliqué", -100)
            return e
        }
        e.add("Risque d'entrer en guerre", -20)
        e.add("Relations avec \(state.countries[friend]?.name ?? friend)", relation(x, friend) * 0.4)
        e.add("Hostilité envers \(state.countries[foe]?.name ?? foe)", -relation(x, foe) * 0.4)
        if !asAttacker && allies(of: x).contains(friend) { e.add("Obligation d'alliance", 40) }
        var nuclearFoe = false
        for f in foes where (state.countries[f]?.nuclearWarheads ?? 0) > 0 { nuclearFoe = true }
        if nuclearFoe && X.nuclearWarheads == 0 { e.add("L'ennemi a l'arme nucléaire", -40) }
        let ratio = (sidePower(friends) + militaryPower(x)) / max(sidePower(foes), 1)
        e.add(ratio >= 1 ? "Camp en position de force" : "Camp en difficulté", (log2(max(ratio, 0.01)) * 10).clamped(-25, 20))
        e.add("Lassitude de guerre", -X.warExhaustion * 50)
        if reach(x, foe) < 0.5 { e.add("Trop éloigné du conflit", -20) }
        return e
    }

    // MARK: - Actions du joueur

    private mutating func spendInfluence(_ id: CountryID, _ amount: Double) -> Bool {
        guard let c = state.countries[id], c.influence >= amount else { return false }
        state.countries[id]?.influence = c.influence - amount
        return true
    }

    mutating func improveRelations(from id: CountryID, with target: CountryID) -> ActionResult {
        guard spendInfluence(id, 10) else { return ActionResult(success: false, message: "Pas assez d'influence (10).") }
        changeRelation(id, target, by: 12)
        return ActionResult(success: true, message: "Relations améliorées (+12).")
    }

    mutating func denounce(from id: CountryID, target: CountryID) -> ActionResult {
        changeRelation(id, target, by: -20)
        for other in countryIDs where other != id && other != target && relation(other, target) < -40 {
            changeRelation(other, id, by: 3)
        }
        return ActionResult(success: true, message: "Dénonciation publique : relations −20, vos alliés apprécient.")
    }

    mutating func propose(_ kind: ProposalKind, from id: CountryID, to target: CountryID) -> ActionResult {
        guard let treaty = kind.treaty, let t = state.countries[target] else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        let cost = kind.influenceCost
        guard (state.countries[id]?.influence ?? 0) >= cost else {
            return ActionResult(success: false, message: "Pas assez d'influence (\(Int(cost))).")
        }
        let evaluation = evaluate(kind, from: id, to: target)
        if evaluation.accepted {
            _ = spendInfluence(id, cost)
            addTreaty(treaty, id, target)
            changeRelation(id, target, by: 10)
            addEvent("✍️ \(state.countries[id]?.name ?? id) et \(t.name) signent : \(kind.name).", important: true)
            return ActionResult(success: true, message: "\(t.name) accepte : \(kind.name).")
        }
        _ = spendInfluence(id, cost / 2)
        changeRelation(id, target, by: -3)
        return ActionResult(success: false, message: "\(t.name) refuse.")
    }

    mutating func proposePeace(warID: Int, from id: CountryID, terms: PeaceTerms) -> ActionResult {
        guard let war = state.wars.first(where: { $0.id == warID && $0.isActive }),
              let sides = warSide(of: id, in: war), let foe = leader(of: sides.enemy) else {
            return ActionResult(success: false, message: "Guerre introuvable.")
        }
        let evaluation = evaluatePeace(warID: warID, evaluator: foe, terms: terms)
        if evaluation.accepted {
            applyPeace(warID: warID, terms: terms)
            return ActionResult(success: true, message: "\(state.countries[foe]?.name ?? foe) accepte la paix.")
        }
        return ActionResult(success: false, message: "\(state.countries[foe]?.name ?? foe) refuse la paix.")
    }

    mutating func askToJoinWar(country x: CountryID, warID: Int, requester id: CountryID) -> ActionResult {
        guard let war = state.wars.first(where: { $0.id == warID && $0.isActive }) else {
            return ActionResult(success: false, message: "Guerre introuvable.")
        }
        guard spendInfluence(id, 10) else { return ActionResult(success: false, message: "Pas assez d'influence (10).") }
        let asAttacker = war.attackers.contains(id)
        let evaluation = evaluateJoinWar(country: x, warID: warID, asAttacker: asAttacker)
        let name = state.countries[x]?.name ?? x
        if evaluation.accepted {
            joinWar(warID: warID, country: x, asAttacker: asAttacker)
            addEvent("🛡️ \(name) rejoint la guerre à vos côtés.", important: true)
            return ActionResult(success: true, message: "\(name) entre en guerre.")
        }
        return ActionResult(success: false, message: "\(name) refuse d'entrer en guerre.")
    }

    mutating func setSanctions(from id: CountryID, on target: CountryID, active: Bool) -> ActionResult {
        if active {
            addTreaty(.sanctions, id, target)
            changeRelation(id, target, by: -30)
            return ActionResult(success: true, message: "Sanctions imposées : plus de commerce entre vous.")
        }
        state.treaties.removeAll { $0.kind == .sanctions && $0.a == id && $0.b == target }
        changeRelation(id, target, by: 10)
        return ActionResult(success: true, message: "Sanctions levées.")
    }

    mutating func guaranteeIndependence(from id: CountryID, of target: CountryID) -> ActionResult {
        guard !hasTreaty(.guarantee, id, target) else { return ActionResult(success: false, message: "Déjà garanti.") }
        guard spendInfluence(id, 10) else { return ActionResult(success: false, message: "Pas assez d'influence (10).") }
        addTreaty(.guarantee, id, target)
        changeRelation(id, target, by: 15)
        for c in claims(involving: target) where c.target == target {
            changeRelation(id, c.claimant, by: -15)
        }
        return ActionResult(success: true, message: "Vous garantissez son indépendance : vous entrerez en guerre s'il est attaqué.")
    }

    mutating func breakTreaty(_ treatyID: Int, by id: CountryID) -> ActionResult {
        guard let t = state.treaties.first(where: { $0.id == treatyID }), t.involves(id) else {
            return ActionResult(success: false, message: "Traité introuvable.")
        }
        state.treaties.removeAll { $0.id == treatyID }
        let other = t.partner(of: id)
        if t.kind != .sanctions {
            changeRelation(id, other, by: t.kind == .alliance ? -35 : -20)
        }
        return ActionResult(success: true, message: "\(t.kind.name) rompu(e).")
    }

    /// Envoie une part du matériel terrestre, des drones et des missiles.
    mutating func sendMilitaryAid(from id: CountryID, to target: CountryID, share: Double = 0.1) -> ActionResult {
        guard state.countries[id] != nil, state.countries[target] != nil, id != target else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        transferEquipment(from: id, to: target, share: share)
        changeRelation(id, target, by: 12)
        for foe in enemies(of: target) { changeRelation(id, foe, by: -10) }
        return ActionResult(success: true, message: "Matériel envoyé (\(Int(share * 100)) % de vos stocks terrestres).")
    }

    mutating func sendEconomicAid(from id: CountryID, to target: CountryID, amount: Double) -> ActionResult {
        guard amount > 0, var donor = state.countries[id], var receiver = state.countries[target], id != target else {
            return ActionResult(success: false, message: "Action impossible.")
        }
        donor.debt += amount
        receiver.debt = max(0, receiver.debt - amount * 0.5)
        receiver.procurementFunds += amount * 0.5
        state.countries[id] = donor
        state.countries[target] = receiver
        changeRelation(id, target, by: min(25, amount / max(receiver.gdp, 1) * 500))
        return ActionResult(success: true, message: "Aide de \(Int(amount)) Md$ versée.")
    }

    mutating func respond(to proposalID: Int, accept: Bool) {
        guard let p = state.proposals.first(where: { $0.id == proposalID }) else { return }
        state.proposals.removeAll { $0.id == proposalID }
        guard accept else {
            changeRelation(p.from, p.to, by: -5)
            return
        }
        if p.kind == .peace, let warID = p.warID, let terms = p.terms {
            applyPeace(warID: warID, terms: terms)
        } else if p.kind == .jointAttack, let target = p.target {
            acceptJointAttack(from: p.from, target: target, inDays: p.inDays)
        } else if let treaty = p.kind.treaty {
            addTreaty(treaty, p.from, p.to)
            changeRelation(p.from, p.to, by: 10)
            addEvent("✍️ \(state.countries[p.from]?.name ?? p.from) et \(state.countries[p.to]?.name ?? p.to) signent : \(p.kind.name).",
                     important: true)
        }
    }

    private mutating func transferEquipment(from donorID: CountryID, to receiverID: CountryID, share: Double) {
        guard var donor = state.countries[donorID], var receiver = state.countries[receiverID] else { return }
        let types: [EquipmentType] = [.infantryKit, .tank, .armoredVehicle, .artillery, .drone, .missile]
        for e in types {
            let amount = donor.stock(e) * share
            donor.equipment[e] = donor.stock(e) - amount
            receiver.equipment[e] = receiver.stock(e) + amount
        }
        state.countries[donorID] = donor
        state.countries[receiverID] = receiver
    }

    // MARK: - IA diplomatique (chaque mois)

    mutating func monthlyDiplomacy() {
        timed("d.relations") { $0.driftRelations() }
        for id in countryIDs {
            guard let c = state.countries[id] else { continue }
            let gain = 1 + log10(max(c.gdp, 1)) / 2
            state.countries[id]?.influence = min(100, c.influence + gain)
        }
        updateWarMomentum()
        timed("d.paix") { $0.aiPeace() }
        timed("d.aide") { $0.aiMilitaryAid() }
        timed("d.plans") { $0.aiWarPlans() }
        timed("d.accords") { $0.aiAgreements() }
        timed("d.factions") { $0.aiFactions() }
        timed("d.joueur") { sim in
            sim.aiProposalsToPlayer()
            sim.aiJointProposals()
        }
        let today = state.day
        state.proposals.removeAll { today - $0.day > 60 }
        state.worldTension = (state.worldTension * 0.97 + Double(activeWarsList.count) * 0.8).clamped(0, 100)
    }

    private mutating func updateWarMomentum() {
        for index in state.wars.indices where state.wars[index].isActive {
            let war = state.wars[index]
            var net = 0.0
            for d in war.defenders {
                for a in war.attackers { net += state.occupation[d]?[a] ?? 0 }
            }
            for a in war.attackers {
                for d in war.defenders { net -= state.occupation[a]?[d] ?? 0 }
            }
            state.wars[index].momentum = net - war.lastNet
            state.wars[index].lastNet = net
        }
    }

    private mutating func aiPeace() {
        for war in activeWarsList {
            guard let attacker = leader(of: war.attackers), let defender = leader(of: war.defenders) else { continue }
            let playerIn = state.playerID.map { war.attackers.contains($0) || war.defenders.contains($0) } ?? false
            if playerIn, let player = state.playerID, let sides = warSide(of: player, in: war),
               let foe = leader(of: sides.enemy) {
                // L'ennemi du joueur peut lui proposer la paix.
                guard !state.proposals.contains(where: { $0.warID == war.id }) else { continue }
                for terms in [PeaceTerms.statusQuo, .whitePeace] {
                    if evaluatePeace(warID: war.id, evaluator: foe, terms: terms).score > 10 {
                        addProposal(from: foe, to: player, kind: .peace, warID: war.id, terms: terms)
                        addEvent("🕊️ \(state.countries[foe]?.name ?? foe) vous propose la paix.", important: true)
                        break
                    }
                }
                continue
            }
            for terms in [PeaceTerms.statusQuo, .whitePeace] {
                let a = evaluatePeace(warID: war.id, evaluator: attacker, terms: terms)
                let d = evaluatePeace(warID: war.id, evaluator: defender, terms: terms)
                if a.accepted && d.accepted {
                    applyPeace(warID: war.id, terms: terms)
                    break
                }
            }
        }
    }

    /// Les pays proches d'un belligérant (et hostiles à son ennemi) lui envoient du matériel.
    private mutating func aiMilitaryAid() {
        for war in activeWarsList {
            for asAttacker in [false, true] {
                let side = asAttacker ? war.attackers : war.defenders
                let foes = asAttacker ? war.defenders : war.attackers
                guard let foe = leader(of: foes) else { continue }
                for donor in countryIDs where donor != state.playerID && !side.contains(donor) && !foes.contains(donor) {
                    for recipient in side where !(state.countries[recipient]?.capitulated ?? true) {
                        if relation(donor, recipient) > 55 && relation(donor, foe) < -40 {
                            transferEquipment(from: donor, to: recipient, share: 0.004)
                            if let d = state.countries[donor] {
                                let money = d.gdp * 0.0003
                                state.countries[donor]?.debt += money
                                state.countries[recipient]?.procurementFunds += money
                            }
                            break
                        }
                    }
                }
            }
        }
    }

    /// L'IA ne déclare la guerre que pour une revendication majeure ou une haine profonde,
    /// avec un net avantage militaire et sans risque nucléaire. Elle prévient 3 mois avant.
    private mutating func aiWarPlans() {
        // Plans en cours
        var remaining: [WarPlan] = []
        for var plan in state.warPlans {
            plan.monthsLeft -= 1
            if plan.monthsLeft > 0 {
                remaining.append(plan)
                continue
            }
            if warIsAttractive(plan.attacker, plan.target) != nil {
                state.warPlans = remaining
                declareWar(attacker: plan.attacker, defender: plan.target)
                remaining = state.warPlans
            } else if let a = state.countries[plan.attacker], let t = state.countries[plan.target] {
                addEvent("\(a.name) retire ses troupes de la frontière de \(t.name).",
                         important: plan.target == state.playerID)
            }
        }
        state.warPlans = remaining

        // Nouveaux plans
        for id in countryIDs where id != state.playerID {
            guard let c = state.countries[id], c.aggressiveness > 0.1,
                  !state.warPlans.contains(where: { $0.attacker == id }) else { continue }
            var candidates = state.claims.filter { $0.claimant == id && $0.major }.map { $0.target }
            for n in c.neighbors where relation(id, n) < -80 && !candidates.contains(n) {
                candidates.append(n)
            }
            for target in candidates {
                guard let ratio = warIsAttractive(id, target) else { continue }
                let hasClaim = claim(by: id, on: target) != nil
                let threat = target == state.playerID ? state.difficulty.threatFactor : 1
                let chance = c.aggressiveness * c.ideology.aggressionFactor * 0.03 * min(2, ratio / 2.5)
                    * (hasClaim ? 1.5 : 0.7) * (1 + state.worldTension / 200) * threat
                if Double.random(in: 0...1, using: &state.rng) < chance {
                    state.warPlans.append(WarPlan(attacker: id, target: target, monthsLeft: 3))
                    changeRelation(id, target, by: -15)
                    state.worldTension = min(100, state.worldTension + 5)
                    if let t = state.countries[target] {
                        addEvent("⚠️ \(c.name) masse des troupes à la frontière de \(t.name).",
                                 important: target == state.playerID || allies(of: target).contains(state.playerID ?? ""))
                    }
                    break
                }
            }
        }
    }

    /// Renvoie le rapport de force si l'attaque est raisonnable, sinon nil.
    private func warIsAttractive(_ attacker: CountryID, _ target: CountryID) -> Double? {
        guard let A = state.countries[attacker], let T = state.countries[target],
              !A.capitulated, !T.capitulated, A.divisionCount >= 3,
              !isAtWar(attacker), A.warExhaustion < 0.2,
              !allies(of: attacker).contains(target),
              !hasTreaty(.nonAggression, attacker, target) || A.aggressiveness > 0.6,
              !isNuclearProtected(target, against: attacker) else { return nil }
        let reachable = A.neighbors.contains(target)
            || (navalShare(attacker, vs: target) >= 0.65 && projection(from: A, to: T) > 0.3)
        guard reachable else { return nil }
        let ratio = militaryPower(attacker) / max(defensiveStrength(of: target, against: attacker), 1)
        let needed = 2.5 - A.aggressiveness
        guard ratio >= needed, A.debtRatio < 1.5 else { return nil }
        return ratio
    }

    /// Accords entre pays IA : commerce, non-agression, et (rarement) alliances.
    private mutating func aiAgreements() {
        let ids = countryIDs
        for id in ids where id != state.playerID {
            guard Double.random(in: 0...1, using: &state.rng) < 0.12 else { continue }
            let friends = ids.filter { $0 != id && $0 != state.playerID && relation(id, $0) > 30 }
            guard !friends.isEmpty else { continue }
            let pick = friends[Int.random(in: 0..<friends.count, using: &state.rng)]
            let kind: ProposalKind
            if !hasTreaty(.tradePact, id, pick) {
                kind = .tradePact
            } else if (state.countries[id]?.neighbors.contains(pick) ?? false) && !hasTreaty(.nonAggression, id, pick) {
                kind = .nonAggression
            } else if relation(id, pick) > 70 && !hasTreaty(.alliance, id, pick) && !shareMilitaryBloc(id, pick) {
                kind = .alliance
            } else {
                continue
            }
            guard let treaty = kind.treaty else { continue }
            if evaluate(kind, from: id, to: pick).accepted && evaluate(kind, from: pick, to: id).accepted {
                addTreaty(treaty, id, pick)
                if kind == .alliance, let a = state.countries[id], let b = state.countries[pick] {
                    addEvent("🤝 Alliance : \(a.name) et \(b.name).")
                }
            }
        }
    }

    private mutating func aiProposalsToPlayer() {
        guard let player = state.playerID, let p = state.countries[player], !p.capitulated else { return }
        var created = 0
        for id in countryIDs where id != player && created < 2 {
            guard !state.proposals.contains(where: { $0.from == id && $0.to == player }) else { continue }
            let rel = relation(id, player)
            let roll = Double.random(in: 0...1, using: &state.rng)
            var kind: ProposalKind?
            if rel > 45 && !hasTreaty(.tradePact, id, player) && !areSanctioning(id, player) && roll < 0.02 {
                kind = .tradePact
            } else if rel > 70 && !hasTreaty(.alliance, id, player) && !shareMilitaryBloc(id, player) && roll < 0.008 {
                kind = .alliance
            } else if rel > 20 && p.neighbors.contains(id) && !hasTreaty(.nonAggression, id, player) && roll < 0.01 {
                kind = .nonAggression
            }
            guard let k = kind, evaluate(k, from: player, to: id).accepted else { continue }
            addProposal(from: id, to: player, kind: k, warID: nil, terms: nil)
            addEvent("📨 \(state.countries[id]?.name ?? id) vous propose : \(k.name).", important: true)
            created += 1
        }
    }

    private mutating func addProposal(from: CountryID, to: CountryID, kind: ProposalKind, warID: Int?, terms: PeaceTerms?) {
        state.proposals.append(Proposal(id: state.nextProposalID, from: from, to: to, kind: kind,
                                        warID: warID, terms: terms, day: state.day))
        state.nextProposalID += 1
    }
}
