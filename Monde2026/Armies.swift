import Foundation

// =============================================================
//  Armies.swift
//  La guerre région par région, façon Age of History :
//   - des armées (piles de divisions) posées dans des régions,
//   - qu'on déplace de région en région (chemin automatique),
//   - qui attaquent les régions ennemies voisines,
//   - batailles jour après jour (organisation, pertes, retraite),
//   - chaque région prise change de propriétaire sur la carte,
//   - débarquements si l'on domine la mer.
//  Les divisions qui ne sont dans aucune armée forment la
//  garnison : elles défendent les régions, surtout au front.
// =============================================================

struct Army: Codable, Identifiable {
    let id: Int
    var owner: CountryID
    var name: String
    var province: Int
    var divisions: [DivisionType: Int]
    var path: [Int]              // prochaines régions à rejoindre
    var progress: Double         // 0…1 vers path.first
    var organization: Double     // 0…1 : moral et cohésion
    var daysInPlace: Int         // sert au retranchement
    var engaged: Bool            // en train d'attaquer
    var amphibious: Bool         // débarquement en cours
    var general: General = .staff
    var stance: ArmyStance = .balanced
    var experience: Double = 0.3 // 0…1 : entraînement des troupes
    var training: Bool = false   // à l'entraînement (deux fois plus vite dans une base)
    var supply: Double = 1       // 0…1 : ravitaillement

    static let maxDivisions = 30

    var count: Int { divisions.values.reduce(0, +) }

    /// Type de division dominant (pour le symbole sur la carte).
    var mainType: DivisionType {
        let armor = (divisions[.armored] ?? 0)
        let mech = (divisions[.mechanized] ?? 0)
        let total = max(1, count)
        if Double(armor) / Double(total) >= 0.3 { return .armored }
        if Double(armor + mech) / Double(total) >= 0.35 { return .mechanized }
        return DivisionType.allCases.max { (divisions[$0] ?? 0) < (divisions[$1] ?? 0) } ?? .infantry
    }
    var destination: Int? { path.last }

    var isMotorized: Bool {
        let slow = (divisions[.infantry] ?? 0) + (divisions[.airborne] ?? 0) + (divisions[.marines] ?? 0)
        return slow == 0
    }

    var hardness: Double {
        var w = 0.0, n = 0.0
        for (t, c) in divisions {
            w += Double(c) * t.stats.hardness
            n += Double(c)
        }
        return n > 0 ? w / n : 0
    }
}

extension Simulation {

    // MARK: - Contrôle des régions

    func controller(of province: Int) -> CountryID {
        state.control[province] ?? ProvinceMap.all[province].country
    }

    /// Place la situation de départ (Crimée, Donbass, Abkhazie, Nord de Chypre…) région par région.
    mutating func initializeControl() {
        state.control = [:]
        state.annexedProvinces = []
        for (id, owner) in ownersFromFractions() {
            let original = ProvinceMap.all[id].country
            guard let holder = owner.owner, holder != original, owner.status == .occupied || owner.status == .annexed else { continue }
            state.control[id] = holder
            if owner.status == .annexed { state.annexedProvinces.insert(id) }
        }
        var victims = Set<CountryID>()
        for id in state.control.keys { victims.insert(ProvinceMap.all[id].country) }
        for v in victims { recomputeTerritory(v) }
    }

    /// Recalcule les pourcentages d'occupation et d'annexion d'un pays à partir de ses régions.
    mutating func recomputeTerritory(_ victim: CountryID) {
        guard let ids = ProvinceMap.byCountry[victim], state.countries[victim] != nil else { return }
        let provinces = ProvinceMap.all
        let total = ids.reduce(0.0) { $0 + provinces[$1].weight }
        guard total > 0 else { return }
        var occupied: [CountryID: Double] = [:]
        var annexed: [CountryID: Double] = [:]
        for id in ids {
            guard let holder = state.control[id], holder != victim else { continue }
            let share = provinces[id].weight / total
            if state.annexedProvinces.contains(id) {
                annexed[holder, default: 0] += share
            } else {
                occupied[holder, default: 0] += share
            }
        }
        state.occupation[victim] = occupied.isEmpty ? nil : occupied
        state.annexation[victim] = annexed.isEmpty ? nil : annexed
    }

    /// Fin de guerre : statu quo (les régions tenues sont annexées) ou paix blanche (tout est rendu).
    mutating func settleProvinces(between sideA: [CountryID], and sideB: [CountryID], keep: Bool) {
        var victims = Set<CountryID>()
        for (id, holder) in state.control {
            let original = ProvinceMap.all[id].country
            let crossed = (sideA.contains(holder) && sideB.contains(original)) || (sideB.contains(holder) && sideA.contains(original))
            guard crossed else { continue }
            if keep {
                state.annexedProvinces.insert(id)
            } else {
                state.control[id] = nil
                state.annexedProvinces.remove(id)
            }
            victims.insert(original)
        }
        for v in victims { recomputeTerritory(v) }
        // Les armées restées en territoire ennemi rentrent chez elles.
        for i in state.armies.indices {
            let a = state.armies[i]
            let here = controller(of: a.province)
            if here != a.owner && !isFriendly(a.owner, here) {
                if let home = homeProvince(for: a.owner) {
                    state.armies[i].province = home
                }
            }
            if sideA.contains(a.owner) || sideB.contains(a.owner) {
                state.armies[i].path = []
                state.armies[i].engaged = false
                state.armies[i].amphibious = false
            }
        }
    }

    // MARK: - Outils

    func isFriendly(_ a: CountryID, _ b: CountryID) -> Bool {
        if a == b { return true }
        guard state.countries[a] != nil, state.countries[b] != nil else { return false }
        return allies(of: a).contains(b)
    }

    func provincesControlled(by id: CountryID) -> [Int] {
        var result: [Int] = []
        for p in ProvinceMap.all where controller(of: p.id) == id {
            result.append(p.id)
        }
        return result
    }

    /// La plus grande région contrôlée par le pays (sa « capitale » militaire).
    func homeProvince(for id: CountryID) -> Int? {
        let core = (ProvinceMap.byCountry[id] ?? []).filter { controller(of: $0) == id }
        let pool = core.isEmpty ? provincesControlled(by: id) : core
        return pool.max { ProvinceMap.all[$0].weight < ProvinceMap.all[$1].weight }
    }

    func armies(of id: CountryID) -> [Army] {
        state.armies.filter { $0.owner == id }
    }

    /// Divisions de chaque type qui ne sont dans aucune armée (garnison).
    func unassignedDivisions(_ id: CountryID) -> [DivisionType: Int] {
        guard let c = state.countries[id] else { return [:] }
        var left = c.divisions
        for a in state.armies where a.owner == id {
            for (t, n) in a.divisions {
                left[t] = max(0, (left[t] ?? 0) - n)
            }
        }
        return left
    }

    func unassignedCount(_ id: CountryID) -> Int {
        unassignedDivisions(id).values.reduce(0, +)
    }

    /// Une armée ne peut pas contenir plus de divisions que le pays n'en possède.
    mutating func normalizeArmies(_ id: CountryID) {
        guard let c = state.countries[id] else {
            state.armies.removeAll { $0.owner == id }
            return
        }
        for t in DivisionType.allCases {
            var assigned = state.armies.filter { $0.owner == id }.reduce(0) { $0 + ($1.divisions[t] ?? 0) }
            var excess = assigned - (c.divisions[t] ?? 0)
            while excess > 0 {
                guard let i = state.armies.indices
                    .filter({ state.armies[$0].owner == id && (state.armies[$0].divisions[t] ?? 0) > 0 })
                    .max(by: { state.armies[$0].count < state.armies[$1].count }) else { break }
                let take = min(excess, state.armies[i].divisions[t] ?? 0)
                state.armies[i].divisions[t] = (state.armies[i].divisions[t] ?? 0) - take
                excess -= take
                assigned -= take
            }
        }
        state.armies.removeAll { $0.owner == id && $0.count == 0 }
    }

    /// Nombre de divisions qui peuvent combattre en même temps dans une région.
    func combatWidth(_ province: Int) -> Double {
        12 + ProvinceMap.all[province].weight.squareRoot() / 30
    }

    func distanceKm(_ a: Int, _ b: Int) -> Double {
        ProvinceMap.distanceKm(ProvinceMap.all[a].label, ProvinceMap.all[b].label)
    }

    // MARK: - Puissance d'une armée

    func armyAttack(_ a: Army, vsHardness h: Double) -> Double {
        guard let c = state.countries[a.owner] else { return 0 }
        var total = 0.0
        for (t, n) in a.divisions {
            let s = t.stats
            let armor = c.has(.nextGenArmor) && (t == .armored || t == .mechanized) ? 1.12 : 1.0
            total += Double(n) * (s.softAttack * (1 - h) + s.hardAttack * h + s.breakthrough * 0.5) * armor
        }
        return (total * c.combatMultiplier + droneSupport(c, armyCount: a.count)) * c.posture.attack * (0.3 + 0.7 * a.organization)
            * (0.8 + 0.4 * a.experience)
    }

    func armyDefense(_ a: Army, vsHardness h: Double) -> Double {
        guard let c = state.countries[a.owner] else { return 0 }
        var total = 0.0
        for (t, n) in a.divisions {
            let s = t.stats
            total += Double(n) * (s.defense + 0.3 * (s.softAttack * (1 - h) + s.hardAttack * h))
        }
        // Retranchement progressif : jusqu'à +50 % après un mois sur place.
        let entrenched = 1 + min(0.5, Double(a.daysInPlace) / 60)
        return (total * c.combatMultiplier + droneSupport(c, armyCount: a.count)) * c.posture.defense
            * (0.3 + 0.7 * a.organization) * entrenched * (0.8 + 0.4 * a.experience)
    }

    /// Appui des drones : rendements décroissants (des milliers de drones ne remplacent pas une armée).
    func droneSupport(_ c: Country, armyCount: Int) -> Double {
        let share = Double(armyCount) / Double(max(1, c.divisionCount))
        let quality = c.tech * (c.has(.autonomousDrones) ? 1.6 : 1) * (c.has(.electronicWarfare) ? 1.1 : 1)
        return 3 * (c.stock(.drone) * share).squareRoot() * quality
    }

    /// Défense des divisions hors armées : concentrée sur les régions du front.
    func garrisonDefense(_ id: CountryID, at province: Int, frontier: Set<Int>, controlledCount: Int) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var total = 0.0
        for (t, n) in unassignedDivisions(id) {
            total += Double(n) * (t.stats.defense + 4.5)
        }
        total *= c.combatMultiplier * c.posture.defense
        let share: Double
        if frontier.contains(province) {
            share = 0.85 / Double(max(1, frontier.count))
        } else {
            share = 0.15 / Double(max(1, controlledCount - frontier.count))
        }
        // Milice minimale : une région n'est jamais vide.
        let militia = 12 * c.combatMultiplier
        // Fortifications : sur son propre sol, la garnison tient mieux.
        let fortified = ProvinceMap.all[province].country == id ? 1.3 : 1.0
        return (total * share + militia) * fortified
    }

    /// Régions d'un pays qui touchent une région tenue par un ennemi.
    func frontierProvinces(_ id: CountryID, enemies: Set<CountryID>) -> Set<Int> {
        var result = Set<Int>()
        guard !enemies.isEmpty else { return result }
        for p in provincesControlled(by: id) {
            if ProvinceMap.all[p].neighbors.contains(where: { enemies.contains(controller(of: $0)) }) {
                result.insert(p)
            }
        }
        return result
    }

    /// Maîtrise du ciel au-dessus d'une bataille (0…1 pour l'attaquant).
    func airSuperiority(_ attacker: CountryID, _ defender: CountryID) -> Double {
        guard let a = state.countries[attacker], let d = state.countries[defender] else { return 0.5 }
        let enemiesA = Double(max(1, enemies(of: attacker).count))
        let enemiesD = Double(max(1, enemies(of: defender).count))
        let pa = (a.airPower + a.stock(.missile) * 0.4 * a.tech) / enemiesA
        let pd = (d.airPower + d.stock(.missile) * 0.4 * d.tech) / enemiesD
        return pa + pd > 0 ? pa / (pa + pd) : 0.5
    }

    // MARK: - Chemins

    /// Chemin jusqu'à une région, à travers des régions amies ou ennemies (pas les pays neutres).
    /// Si aucun chemin terrestre n'existe, débarquement possible quand on domine la mer.
    func route(for army: Army, to target: Int, throughEnemy: Bool = false) -> (path: [Int], amphibious: Bool)? {
        guard target != army.province, ProvinceMap.all.indices.contains(target) else { return nil }
        let owner = army.owner
        let foes = enemies(of: owner)
        var allowedCache: [CountryID: Bool] = [:]
        func allowed(_ p: Int) -> Bool {
            let c = controller(of: p)
            if let v = allowedCache[c] { return v }
            let v = c == owner || foes.contains(c) || isFriendly(owner, c)
            allowedCache[c] = v
            return v
        }
        guard allowed(target) else { return nil }
        var previous: [Int: Int] = [army.province: -1]
        var queue = [army.province]
        var head = 0
        while head < queue.count {
            let cur = queue[head]
            head += 1
            if cur == target { break }
            // On ne traverse pas une région ennemie pour aller plus loin : on s'y arrête pour combattre.
            if cur != army.province && foes.contains(controller(of: cur)) && !throughEnemy { continue }
            for n in ProvinceMap.all[cur].neighbors where previous[n] == nil && allowed(n) {
                previous[n] = cur
                queue.append(n)
            }
            if queue.count > 4000 { break }
        }
        if previous[target] != nil {
            var path: [Int] = []
            var cur = target
            while cur != army.province {
                path.append(cur)
                cur = previous[cur] ?? army.province
                if path.count > 400 { return nil }
            }
            return (path.reversed(), false)
        }
        // Débarquement ou transport maritime : seulement d'une côte à une autre.
        guard let me = state.countries[owner], me.navalPower > 0,
              ProvinceMap.all[target].coastal, ProvinceMap.all[army.province].coastal else { return nil }
        let destOwner = controller(of: target)
        if foes.contains(destOwner) {
            guard navalShare(owner, vs: destOwner) >= 0.55, distanceKm(army.province, target) < 3500 else { return nil }
        }
        return ([target], true)
    }

    // MARK: - Ordres (joueur et IA)

    @discardableResult
    mutating func createArmy(for id: CountryID, composition: [DivisionType: Int], at province: Int? = nil) -> ActionResult {
        let left = unassignedDivisions(id)
        var picked: [DivisionType: Int] = [:]
        var total = 0
        for t in DivisionType.allCases {
            let n = min(composition[t] ?? 0, left[t] ?? 0, Army.maxDivisions - total)
            if n > 0 { picked[t] = n; total += n }
        }
        guard total > 0 else { return ActionResult(success: false, message: "Aucune division disponible de ce type.") }
        return createArmy(for: id, size: total, at: province, picked: picked)
    }

    mutating func createArmy(for id: CountryID, size: Int, at province: Int? = nil, picked forced: [DivisionType: Int]? = nil) -> ActionResult {
        var left = unassignedDivisions(id)
        let size = min(size, Army.maxDivisions)
        let available = left.values.reduce(0, +)
        guard available > 0 else {
            return ActionResult(success: false, message: "Toutes vos divisions sont déjà dans des armées. Recrutez-en d'autres.")
        }
        let wanted = min(size, available)
        var picked: [DivisionType: Int] = forced ?? [:]
        // Composition proportionnelle à la réserve.
        for t in DivisionType.allCases where forced == nil {
            let n = left[t] ?? 0
            let take = Int((Double(n) * Double(wanted) / Double(available)).rounded())
            picked[t] = min(n, take)
            left[t] = n - (picked[t] ?? 0)
        }
        var total = picked.values.reduce(0, +)
        for t in DivisionType.allCases where total < wanted {
            let extra = min(left[t] ?? 0, wanted - total)
            picked[t, default: 0] += extra
            total += extra
        }
        picked = picked.filter { $0.value > 0 }
        guard total > 0 else { return ActionResult(success: false, message: "Aucune division disponible.") }
        if forced != nil { total = picked.values.reduce(0, +) }
        let place = province ?? (isAtWar(id) ? deploymentProvince(for: id) : nil) ?? bases(of: id).first ?? homeProvince(for: id)
        guard let start = place else { return ActionResult(success: false, message: "Aucune région où rassembler l'armée.") }
        let name = nextArmyName(for: id)
        let general = makeGeneral(for: id, divisions: picked)
        let experience = startingExperience(id)
        state.armies.append(Army(id: state.nextArmyID, owner: id, name: name, province: start, divisions: picked,
                                 path: [], progress: 0, organization: 1, daysInPlace: 0, engaged: false, amphibious: false,
                                 general: general, experience: experience))
        state.nextArmyID += 1
        return ActionResult(success: true, message: "\(name) formée : \(total) divisions à \(ProvinceMap.all[start].name), sous les ordres du \(general.name).")
    }

    func nextArmyName(for id: CountryID) -> String {
        let used = Set(state.armies.filter { $0.owner == id }.map { $0.name })
        var n = 1
        while used.contains(n == 1 ? "1re armée" : "\(n)e armée") { n += 1 }
        return n == 1 ? "1re armée" : "\(n)e armée"
    }

    /// Région de rassemblement : au front si l'on est en guerre, sinon la capitale.
    func deploymentProvince(for id: CountryID) -> Int? {
        let foes = enemies(of: id)
        let front = frontierProvinces(id, enemies: foes)
        if let best = front.max(by: { a, b in
            let ea = ProvinceMap.all[a].neighbors.filter { foes.contains(controller(of: $0)) }.count
            let eb = ProvinceMap.all[b].neighbors.filter { foes.contains(controller(of: $0)) }.count
            return ea < eb
        }) {
            return best
        }
        return homeProvince(for: id)
    }

    mutating func orderArmy(_ armyID: Int, to target: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        let offensive = enemies(of: state.armies[i].owner).contains(controller(of: target))
        guard let r = route(for: state.armies[i], to: target, throughEnemy: offensive) else {
            let c = controller(of: target)
            if c != state.armies[i].owner && !enemies(of: state.armies[i].owner).contains(c) && !isFriendly(state.armies[i].owner, c) {
                return ActionResult(success: false, message: "Pas d'accès : \(name(c)) n'est ni allié ni ennemi.")
            }
            return ActionResult(success: false, message: "Aucun chemin possible (il faut la maîtrise de la mer pour débarquer).")
        }
        state.armies[i].path = r.path
        state.armies[i].amphibious = r.amphibious
        state.armies[i].progress = 0
        state.armies[i].engaged = false
        state.armies[i].training = false
        let dest = ProvinceMap.all[target].name
        let foes = enemies(of: state.armies[i].owner)
        let hostile = r.path.filter { foes.contains(controller(of: $0)) }.count
        if r.amphibious { return ActionResult(success: true, message: "Débarquement ordonné vers \(dest).") }
        if hostile > 1 { return ActionResult(success: true, message: "Offensive vers \(dest) : \(hostile) régions ennemies à prendre l'une après l'autre.") }
        return ActionResult(success: true, message: hostile == 1 ? "Attaque sur \(dest)." : "En route vers \(dest) (\(r.path.count) régions).")
    }

    /// Ajoute une étape : l'armée finit son trajet actuel puis va jusqu'à cette région (détours, contournements).
    mutating func appendRoute(_ armyID: Int, via target: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        var ghost = state.armies[i]
        let from = ghost.path.last ?? ghost.province
        guard from != target else { return ActionResult(success: false, message: "L'armée passe déjà par là.") }
        ghost.province = from
        let offensive = enemies(of: ghost.owner).contains(controller(of: target))
        guard let r = route(for: ghost, to: target, throughEnemy: offensive), !r.amphibious || ghost.path.isEmpty else {
            return ActionResult(success: false, message: "Pas de chemin vers \(ProvinceMap.all[target].name).")
        }
        if state.armies[i].path.isEmpty {
            state.armies[i].amphibious = r.amphibious
            state.armies[i].progress = 0
        }
        state.armies[i].path += r.path
        state.armies[i].training = false
        return ActionResult(success: true, message: "Étape ajoutée : \(ProvinceMap.all[target].name) (\(state.armies[i].path.count) régions au total).")
    }

    /// Début de partie : les divisions du joueur sont déjà rangées en armées, dans leurs bases.
    mutating func formStartingArmies(_ id: CountryID) {
        guard let c = state.countries[id], armies(of: id).isEmpty else { return }
        let atWar = isAtWar(id)
        let own = bases(of: id)
        let target = Int(Double(c.divisionCount) * 0.85)
        var k = 0
        var guardCount = 0
        while armies(of: id).reduce(0, { $0 + $1.count }) < target && unassignedCount(id) > 0 && guardCount < 40 {
            guardCount += 1
            let size = min(Army.maxDivisions, max(4, min(20, c.divisionCount / 4)))
            let front = atWar ? Array(frontierProvinces(id, enemies: enemies(of: id))).sorted() : []
            let place: Int? = !front.isEmpty ? front[k % front.count] : (own.isEmpty ? nil : own[k % own.count])
            k += 1
            if !createArmy(for: id, size: size, at: place).success { break }
        }
        for i in state.armies.indices where state.armies[i].owner == id {
            state.armies[i].training = !atWar
            state.armies[i].stance = atWar ? .balanced : .defend
            state.armies[i].daysInPlace = 60
        }
    }

    mutating func stopArmy(_ armyID: Int) {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else { return }
        state.armies[i].path = []
        state.armies[i].engaged = false
        state.armies[i].amphibious = false
    }

    mutating func splitArmy(_ armyID: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }), state.armies[i].count >= 2 else {
            return ActionResult(success: false, message: "Il faut au moins 2 divisions pour diviser l'armée.")
        }
        var half: [DivisionType: Int] = [:]
        var remaining = state.armies[i].count / 2
        for t in DivisionType.allCases where remaining > 0 {
            let n = state.armies[i].divisions[t] ?? 0
            let take = min(remaining, (n + 1) / 2)
            if take > 0 {
                half[t] = take
                state.armies[i].divisions[t] = n - take
                remaining -= take
            }
        }
        let a = state.armies[i]
        let newName = nextArmyName(for: a.owner)
        let newGeneral = makeGeneral(for: a.owner, divisions: half)
        state.armies.append(Army(id: state.nextArmyID, owner: a.owner, name: newName, province: a.province,
                                 divisions: half, path: [], progress: 0, organization: a.organization,
                                 daysInPlace: a.daysInPlace, engaged: false, amphibious: false,
                                 general: newGeneral, stance: a.stance,
                                 experience: a.experience, training: a.training, supply: a.supply))
        state.nextArmyID += 1
        return ActionResult(success: true, message: "Armée divisée en deux.")
    }

    mutating func mergeArmies(at armyID: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        let main = state.armies[i]
        let others = state.armies.filter { $0.owner == main.owner && $0.province == main.province && $0.id != main.id }
        guard !others.isEmpty else { return ActionResult(success: false, message: "Aucune autre armée dans cette région.") }
        var merged = main.divisions
        var size = main.count
        guard size < Army.maxDivisions else {
            return ActionResult(success: false, message: "\(main.name) est déjà au maximum (\(Army.maxDivisions) divisions).")
        }
        var org = main.organization * Double(main.count)
        var exp = main.experience * Double(main.count)
        var absorbed = 0
        for o in others {
            guard let j = state.armies.firstIndex(where: { $0.id == o.id }) else { continue }
            for t in DivisionType.allCases {
                let room = Army.maxDivisions - size
                let n = min(room, state.armies[j].divisions[t] ?? 0)
                guard n > 0 else { continue }
                merged[t, default: 0] += n
                state.armies[j].divisions[t] = (state.armies[j].divisions[t] ?? 0) - n
                org += o.organization * Double(n)
                exp += o.experience * Double(n)
                size += n
            }
            absorbed += 1
        }
        let k = state.armies.firstIndex(where: { $0.id == main.id }) ?? i
        state.armies[k].divisions = merged
        state.armies[k].organization = org / Double(max(1, size))
        state.armies[k].experience = exp / Double(max(1, size))
        state.armies.removeAll { $0.count == 0 }
        return ActionResult(success: true, message: size >= Army.maxDivisions
                            ? "Regroupées : \(main.name) est au complet (\(Army.maxDivisions) divisions)."
                            : "\(absorbed + 1) armées regroupées (\(size) divisions).")
    }

    mutating func dissolveArmy(_ armyID: Int) {
        state.armies.removeAll { $0.id == armyID }
    }

    // MARK: - Journée militaire

    mutating func dailyArmies() {
        guard !state.armies.isEmpty || state.wars.contains(where: { $0.isActive }) else {
            if !state.battles.isEmpty { state.battles = [:] }
            return
        }
        let ownersWithArmies = Set(state.armies.map { $0.owner })
        for id in ownersWithArmies { normalizeArmies(id) }
        if state.day % 2 == 0 { updateSupply() }
        if state.day % 3 == 0 { aiArmies() }

        var enemiesCache: [CountryID: Set<CountryID>] = [:]
        func foes(_ id: CountryID) -> Set<CountryID> {
            if let e = enemiesCache[id] { return e }
            let e = enemies(of: id)
            enemiesCache[id] = e
            return e
        }

        // 1. Déplacements, planification, ravitaillement
        var attacks: [Int: [Int]] = [:]       // région visée -> indices d'armées
        for i in state.armies.indices {
            var a = state.armies[i]
            let readiness = state.countries[a.owner]?.readiness ?? 0.5
            // Sans ravitaillement : le moral ne remonte plus, l'armée s'use.
            if a.supply < 0.4 {
                a.organization = max(0, a.organization - (a.supply <= 0.15 ? 0.02 : 0.005))
                if state.day % 5 == 0 {
                    state.armies[i] = a
                    applyArmyLosses(i, intensity: a.supply <= 0.15 ? 0.01 : 0.004)
                    a = state.armies[i]
                }
            }
            guard let next = a.path.first else {
                a.engaged = false
                a.daysInPlace += a.general.trait == .defensive ? 2 : 1
                let defending = state.battles[a.province] != nil
                if a.supply >= 0.4 && !defending {
                    let regen = 0.03 * (0.5 + 0.5 * readiness) * (a.general.trait == .logistician ? 1.3 : 1) * a.supply
                    a.organization = min(1, a.organization + regen)
                }
                state.armies[i] = a
                continue
            }
            let holder = controller(of: next)
            if foes(a.owner).contains(holder) {
                if a.amphibious && a.progress < 1 {
                    // Traversée avant le débarquement.
                    let days = distanceKm(a.province, next) / 300 + 5
                    a.progress += 1 / max(1, days)
                    state.armies[i] = a
                    continue
                }
                a.engaged = true
                attacks[next, default: []].append(i)
                state.armies[i] = a
            } else if holder == a.owner || isFriendly(a.owner, holder) {
                var speed = (a.isMotorized ? 45.0 : 30.0) * (0.6 + 0.4 * (state.countries[a.owner]?.infrastructure ?? 0.5))
                speed *= TerrainMap.terrain(next).movement * weather(at: next).movement
                if a.supply < 0.4 { speed *= 0.7 }
                let days = a.amphibious ? distanceKm(a.province, next) / 400 + 3 : distanceKm(a.province, next) / max(5, speed)
                a.progress += 1 / max(1, days)
                a.engaged = false
                if a.progress >= 1 {
                    a.province = next
                    a.path.removeFirst()
                    a.progress = 0
                    a.daysInPlace = 0
                    a.amphibious = false
                }
                state.armies[i] = a
            } else {
                // Le pays traversé n'est plus ami ni ennemi : l'armée s'arrête.
                a.path = []
                a.engaged = false
                state.armies[i] = a
            }
        }

        // 2. Batailles
        if !attacks.isEmpty {
            var frontierCache: [CountryID: (Set<Int>, Int)] = [:]
            for (target, attackerIndices) in attacks.sorted(by: { $0.key < $1.key }) {
                fightProvinceBattle(target: target, attackerIndices: attackerIndices, frontierCache: &frontierCache)
            }
            state.armies.removeAll { $0.count == 0 }
        }
        closeBattlesAndPromote()
        regenerateProvinceOrganization()
    }

    private mutating func regenerateProvinceOrganization() {
        for (p, org) in state.provinceOrg {
            let next = org + 0.05
            state.provinceOrg[p] = next >= 1 ? nil : next
        }
    }

    mutating func applyArmyLosses(_ index: Int, intensity: Double) {
        let a = state.armies[index]
        guard var c = state.countries[a.owner] else { return }
        let share = Double(a.count) / Double(max(1, c.divisionCount))
        c.applyLandLosses(fraction: intensity * c.posture.losses, share: share)
        state.countries[a.owner] = c
    }

    mutating func captureProvince(_ target: Int, by attackers: [Int], defenders: [Int], from loser: CountryID) {
        let province = ProvinceMap.all[target]
        let winner = state.armies[attackers[0]].owner
        // Retraite des défenseurs vers une région amie voisine, sinon destruction.
        var destroyed: [Int] = []
        for j in defenders {
            let owner = state.armies[j].owner
            let retreat = province.neighbors.first { n in
                let c = controller(of: n)
                return c == owner || isFriendly(owner, c)
            }
            if let r = retreat {
                state.armies[j].province = r
                state.armies[j].organization = 0.3
                state.armies[j].path = []
                state.armies[j].daysInPlace = 0
            } else {
                destroyed.append(j)
            }
        }
        for j in destroyed {
            let a = state.armies[j]
            if var c = state.countries[a.owner] {
                for (t, n) in a.divisions { c.divisions[t] = max(0, (c.divisions[t] ?? 0) - n) }
                let men = Double(a.count) * 6
                c.activePersonnel = max(0, c.activePersonnel - men)
                c.casualties += men
                state.countries[a.owner] = c
            }
            state.armies[j].divisions = [:]
            if a.owner == state.playerID {
                addEvent("💀 \(a.name) est encerclée et détruite à \(province.name).", important: true)
            }
        }
        // Changement de propriétaire
        if province.country == winner {
            state.control[target] = nil              // libération
        } else {
            state.control[target] = winner
        }
        state.annexedProvinces.remove(target)
        state.provinceOrg[target] = 0.3
        if let f = state.forts[target] { state.forts[target] = f > 1 ? f - 1 : nil }
        state.constructions.removeAll { $0.province == target }
        recomputeTerritory(province.country)
        // Les vainqueurs entrent dans la région.
        for i in attackers where state.armies.indices.contains(i) {
            // Tenir le terrain conquis épuise : pas d'enchaînement immédiat.
            state.armies[i].organization = max(0, state.armies[i].organization - 0.2)
            state.armies[i].province = target
            if state.armies[i].path.first == target { state.armies[i].path.removeFirst() }
            state.armies[i].progress = 0
            state.armies[i].engaged = false
            state.armies[i].amphibious = false
            state.armies[i].daysInPlace = 0
        }
        if winner == state.playerID {
            addEvent("🎖️ Nos troupes prennent \(province.name).", important: province.weight > 15000)
        } else if loser == state.playerID {
            addEvent("⚠️ \(province.name) tombe aux mains de \(name(winner)).", important: true)
        }
    }

    // MARK: - IA des armées

    mutating func aiArmies() {
        let atWar = Set(state.wars.filter { $0.isActive }.flatMap { $0.attackers + $0.defenders })
        // Paix : les armées des pays IA rentrent et se dispersent en garnison.
        // Paix : les armées de l'IA rentrent dans leurs bases et s'y entraînent (elles ne disparaissent plus).
        let idle = Set(state.armies.map { $0.owner }).subtracting(atWar)
        for id in idle where id != state.playerID || state.autoArmies {
            let own = bases(of: id)
            for i in state.armies.indices where state.armies[i].owner == id && state.armies[i].path.isEmpty
                && !state.armies[i].training {
                if own.contains(state.armies[i].province) || own.isEmpty {
                    state.armies[i].training = true
                    state.armies[i].stance = .defend
                } else {
                    _ = sendToBase(state.armies[i].id)
                }
            }
        }
        for id in atWar.sorted() {
            guard let c = state.countries[id], !c.capitulated else { continue }
            if id == state.playerID && !state.autoArmies {
                // Le joueur commande ; on l'aide seulement à déployer s'il n'a encore aucune armée.
                if armies(of: id).isEmpty && c.divisionCount > 0 {
                    deployDefaultArmies(id, ratio: 0.7)
                    addEvent("🪖 Vos armées se déploient au front. Touchez un pion pour lui donner des ordres.", important: true)
                }
                continue
            }
            commandArmies(id)
        }
    }

    /// Guerres déjà en cours au début de la partie : armées déployées et retranchées depuis longtemps.
    mutating func deployInitialArmies() {
        let fighting = Set(state.wars.filter { $0.isActive }.flatMap { $0.attackers + $0.defenders })
        for id in fighting.sorted() {
            deployDefaultArmies(id, ratio: 0.8)
        }
        for i in state.armies.indices {
            state.armies[i].daysInPlace = 90
        }
    }

    /// Forme des armées (environ 10 divisions chacune) et les place au front.
    mutating func deployDefaultArmies(_ id: CountryID, ratio: Double) {
        guard let c = state.countries[id] else { return }
        let target = Int(Double(c.divisionCount) * ratio)
        var assigned = armies(of: id).reduce(0) { $0 + $1.count }
        let foes = enemies(of: id)
        let front = Array(frontierProvinces(id, enemies: foes)).sorted()
        var k = 0
        var guardCount = 0
        while assigned < target && unassignedCount(id) > 0 && guardCount < 20 {
            guardCount += 1
            let size = max(1, min(Army.maxDivisions, max(4, c.divisionCount / 8)))
            let place: Int? = front.isEmpty ? deploymentProvince(for: id) : front[k % front.count]
            k += 1
            let result = createArmy(for: id, size: size, at: place)
            if !result.success { break }
            assigned += size
        }
    }

    /// Le commandement automatique : renforcer le front, attaquer là où l'on est nettement plus fort.
    private mutating func commandArmies(_ id: CountryID) {
        guard let c = state.countries[id] else { return }
        // Posture défensive : davantage de divisions en garnison, réparties sur tout le front.
        let ratio = c.posture == .defensive ? 0.6 : 0.8
        if armies(of: id).reduce(0, { $0 + $1.count }) < Int(Double(c.divisionCount) * (ratio - 0.2)) {
            deployDefaultArmies(id, ratio: ratio)
        }
        let foes = enemies(of: id)
        guard !foes.isEmpty else { return }
        let front = frontierProvinces(id, enemies: foes)
        let threshold: Double
        switch c.posture {
        case .offensive: threshold = 1.05
        case .balanced: threshold = 1.25
        case .defensive: threshold = 1.9
        }
        var frontierCache: [CountryID: (Set<Int>, Int)] = [:]
        let mine = state.armies.indices.filter { state.armies[$0].owner == id && state.armies[$0].path.isEmpty }
        var occupiedFront = Set(state.armies.filter { $0.owner == id }.map { $0.province })
        for i in mine {
            let a = state.armies[i]
            // Pas encore au front : y aller.
            if !front.contains(a.province) {
                if front.isEmpty {
                    // Guerre lointaine : rejoindre une côte, puis débarquer si la flotte le permet.
                    if !ProvinceMap.all[a.province].coastal {
                        let coasts = provincesControlled(by: id).filter { ProvinceMap.all[$0].coastal }
                        if let port = coasts.min(by: { distanceKm(a.province, $0) < distanceKm(a.province, $1) }),
                           let r = route(for: a, to: port), !r.amphibious {
                            state.armies[i].path = r.path
                        }
                    } else if a.organization > 0.85, Double.random(in: 0...1, using: &state.rng) < 0.1,
                              let target = nearestEnemyProvince(from: a.province, owner: id),
                              let r = route(for: a, to: target) {
                        state.armies[i].path = r.path
                        state.armies[i].amphibious = r.amphibious
                    }
                    continue
                }
                let free = front.filter { !occupiedFront.contains($0) }
                let pool = free.isEmpty ? Array(front) : Array(free)
                if let dest = pool.min(by: { distanceKm(a.province, $0) < distanceKm(a.province, $1) }),
                   let r = route(for: a, to: dest), !r.amphibious {
                    state.armies[i].path = r.path
                    occupiedFront.insert(dest)
                }
                continue
            }
            guard a.organization > 0.7 else { continue }
            // Au front : chercher la région ennemie voisine la plus faible.
            var best: (Int, Double)?
            for n in ProvinceMap.all[a.province].neighbors where foes.contains(controller(of: n)) {
                let defender = controller(of: n)
                if frontierCache[defender] == nil {
                    frontierCache[defender] = (frontierProvinces(defender, enemies: enemies(of: defender)),
                                               provincesControlled(by: defender).count)
                }
                let (dFront, dCount) = frontierCache[defender] ?? ([], 1)
                var def = garrisonDefense(defender, at: n, frontier: dFront, controlledCount: dCount)
                for d in state.armies where d.province == n && isFriendly(defender, d.owner) {
                    def += armyDefense(d, vsHardness: a.hardness)
                }
                if ProvinceMap.all[n].country == defender { def *= 1.25 }
                // Les armées amies voisines de la même cible attaquent avec nous (dans la limite du front).
                var att = 0.0
                var divs = 0
                let terrain = TerrainMap.terrain(n)
                for j in mine where state.armies[j].organization > 0.6 && ProvinceMap.all[state.armies[j].province].neighbors.contains(n) {
                    let b = state.armies[j]
                    var v = armyAttack(b, vsHardness: 0.2) * (0.45 + 0.55 * b.supply)
                    if TerrainMap.river(b.province, n) { v *= 0.75 }
                    att += v
                    divs += b.count
                }
                att *= terrain.attack * weather(at: n).attack
                let ratio = att / max(def, 0.001)
                if ratio > (best?.1 ?? 0) { best = (n, ratio) }
            }
            // On attend que l'offensive soit préparée, sauf si l'avantage est écrasant.
            if let (target, ratio) = best, ratio >= threshold {
                let stance: ArmyStance = ratio >= threshold * 1.5 ? .assault : .balanced
                for j in mine where state.armies[j].path.isEmpty && state.armies[j].organization > 0.6
                    && ProvinceMap.all[state.armies[j].province].neighbors.contains(target) {
                    state.armies[j].path = [target]
                    state.armies[j].amphibious = false
                    state.armies[j].stance = stance
                }
            }
        }
        rebalanceDefense(id, front: front, foes: foes)
        // Les armées qui n'attaquent pas se mettent en défense (sauf doctrine offensive).
        for i in state.armies.indices where state.armies[i].owner == id && state.armies[i].path.isEmpty {
            state.armies[i].stance = c.posture == .offensive && state.armies[i].organization > 0.8 ? .balanced : .defend
        }
    }

    /// Défense : les armées au calme rejoignent les régions du front les plus menacées.
    private mutating func rebalanceDefense(_ id: CountryID, front: Set<Int>, foes: Set<CountryID>) {
        guard !front.isEmpty else { return }
        let enemyArmies = state.armies.filter { foes.contains($0.owner) }
        guard !enemyArmies.isEmpty else { return }
        let controlled = provincesControlled(by: id).count
        func threat(_ p: Int) -> Double {
            let around = Set(ProvinceMap.all[p].neighbors)
            return enemyArmies.filter { around.contains($0.province) }.reduce(0.0) { $0 + armyAttack($1, vsHardness: 0.3) }
        }
        func cover(_ p: Int) -> Double {
            var total = garrisonDefense(id, at: p, frontier: front, controlledCount: controlled)
            for a in state.armies where a.owner == id && (a.province == p || a.path.last == p) {
                total += armyDefense(a, vsHardness: 0.3)
            }
            return max(total, 1)
        }
        var pressure: [Int: Double] = [:]
        for p in front { pressure[p] = threat(p) / cover(p) }
        for i in state.armies.indices where state.armies[i].owner == id && state.armies[i].path.isEmpty {
            let here = state.armies[i].province
            guard front.contains(here), (pressure[here] ?? 0) < 0.6 else { continue }
            guard let (target, value) = pressure.max(by: { $0.value < $1.value }), value > 1.2, target != here,
                  let r = route(for: state.armies[i], to: target), !r.amphibious, r.path.count <= 4 else { continue }
            state.armies[i].path = r.path
            pressure[target] = value * 0.5
        }
    }

    private func nearestEnemyProvince(from province: Int, owner: CountryID) -> Int? {
        let foes = enemies(of: owner)
        var best: (Int, Double)?
        for p in ProvinceMap.all where p.coastal && foes.contains(controller(of: p.id)) {
            let d = distanceKm(province, p.id)
            if d < (best?.1 ?? .infinity) { best = (p.id, d) }
        }
        return best?.0
    }
}

// MARK: - Pour l'interface

extension Simulation {

    mutating func setAutoArmies(_ enabled: Bool) {
        state.autoArmies = enabled
    }

    func armyStatus(_ a: Army) -> String {
        if a.supply <= 0.15 { return "Encerclée à \(ProvinceMap.all[a.province].name)" }
        if state.battles[a.province] != nil && a.path.isEmpty { return "Défend \(ProvinceMap.all[a.province].name)" }
        if a.training && a.path.isEmpty {
            return hasBase(a.province, for: a.owner) ? "Entraînement à la base de \(ProvinceMap.all[a.province].name)"
                                                     : "Entraînement en campagne à \(ProvinceMap.all[a.province].name)"
        }
        if let next = a.path.first {
            let nextName = ProvinceMap.all[next].name
            if a.amphibious { return "Débarquement vers \(nextName)" }
            if a.engaged { return "Combat pour \(nextName)" }
            if let dest = a.path.last, dest != next {
                return "En marche vers \(ProvinceMap.all[dest].name) (\(a.path.count) régions)"
            }
            return "En marche vers \(nextName)"
        }
        return a.daysInPlace >= 5 ? "Retranchée à \(ProvinceMap.all[a.province].name)" : "En position à \(ProvinceMap.all[a.province].name)"
    }

    /// Valeur d'attaque affichée (arrondie) pour comparer les armées.
    func armyPower(_ a: Army) -> Int {
        Int(armyAttack(a, vsHardness: 0.3).rounded())
    }

    func playerArmies(in province: Int) -> [Army] {
        guard let p = state.playerID else { return [] }
        return state.armies.filter { $0.owner == p && $0.province == province }
    }
}
