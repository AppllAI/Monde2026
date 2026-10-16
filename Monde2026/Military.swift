import Foundation

// =============================================================
//  Military.swift
//  Le moteur militaire (calculé chaque jour) :
//  production, formation, renforts, combats terrestres,
//  aériens et navals, frappes de missiles, capitulation.
// =============================================================

/// Un front entre deux pays en guerre.
struct Front {
    let a: CountryID
    let b: CountryID
    let landBorder: Bool
}

// MARK: - Capacités de combat d'un pays

extension Country {

    /// Dureté moyenne de l'armée (part de blindés).
    var averageHardness: Double {
        var weighted = 0.0
        var count = 0.0
        for (type, n) in divisions {
            weighted += Double(n) * type.stats.hardness
            count += Double(n)
        }
        return count > 0 ? weighted / count : 0
    }

    /// Qualité : équipement, technologie, entraînement, expérience.
    var combatMultiplier: Double {
        divisionFill * (0.4 + 0.6 * tech) * (0.6 + 0.4 * readiness) * (1 + 0.3 * experience) * techCombatFactor
    }

    func offensePower(vsHardness h: Double) -> Double {
        var total = 0.0
        for (type, n) in divisions {
            let s = type.stats
            let armorBonus = has(.nextGenArmor) && (type == .armored || type == .mechanized) ? 1.12 : 1.0
            total += Double(n) * (s.softAttack * (1 - h) + s.hardAttack * h + s.breakthrough * 0.5) * armorBonus
        }
        return total
    }

    func defensePower(vsHardness h: Double) -> Double {
        var total = 0.0
        for (type, n) in divisions {
            let s = type.stats
            total += Double(n) * (s.defense + 0.3 * (s.softAttack * (1 - h) + s.hardAttack * h))
        }
        return total
    }

    /// Puissance terrestre globale (sert à répartir les troupes entre les fronts).
    var landStrengthIndex: Double {
        var total = 0.0
        for (type, n) in divisions {
            total += Double(n) * (type.stats.softAttack + type.stats.defense)
        }
        return total * combatMultiplier
    }

    /// Pertes terrestres sur la part de l'armée engagée sur un front.
    mutating func applyLandLosses(fraction: Double, share: Double) {
        guard fraction > 0, share > 0 else { return }
        let men = landPersonnel * share * fraction * (has(.combatMedicine) ? 0.8 : 1)
        activePersonnel = max(0, activePersonnel - men)
        casualties += men
        population = max(0.01, population - men * 0.3 / 1000)   // ~30 % de tués
        let exposure: [EquipmentType: Double] = [.infantryKit: 0.6, .tank: 1.3, .armoredVehicle: 1.1, .artillery: 0.7]
        for (e, k) in exposure {
            let committed = min(stock(e), equipmentRequired(e)) * share
            equipment[e] = max(0, stock(e) - committed * fraction * k)
        }
    }

    mutating func applyNavalLosses(_ fraction: Double) {
        guard fraction > 0 else { return }
        equipment[.warship] = max(0, stock(.warship) * (1 - fraction))
        equipment[.submarine] = max(0, stock(.submarine) * (1 - fraction * 0.8))
        equipment[.carrier] = max(0, stock(.carrier) * (1 - fraction * 0.4))
    }

    // MARK: Production automatique (IA)

    func productionWeights(_ targets: [EquipmentType: Double]) -> [EquipmentType: Double] {
        var weights: [EquipmentType: Double] = [:]
        for (e, target) in targets where target > 0 {
            let gap = max(0, target - stock(e))
            weights[e] = (gap + target * 0.03) * e.cost   // 3 % de renouvellement permanent
        }
        return weights
    }

    mutating func autoAllocateProduction(atWar: Bool) {
        var land: [EquipmentType: Double] = [:]
        for e in EquipmentType.allCases where e.isLandEquipment {
            land[e] = max(forceTargets[e] ?? 0, equipmentRequired(e) * 1.1)
        }
        land[.fighter] = (forceTargets[.fighter] ?? 0) * (atWar ? 1.2 : 1.0)
        land[.drone] = (forceTargets[.drone] ?? 0) * (atWar ? 3.0 : 1.0)
        land[.missile] = (forceTargets[.missile] ?? 0) * (atWar ? 2.0 : 1.0)
        let naval: [EquipmentType: Double] = [
            .warship: forceTargets[.warship] ?? 0,
            .submarine: forceTargets[.submarine] ?? 0,
            .carrier: forceTargets[.carrier] ?? 0
        ]
        let landWeights = productionWeights(land)
        let navalWeights = productionWeights(naval)
        let landTotal = landWeights.values.reduce(0, +)
        let navalTotal = navalWeights.values.reduce(0, +)
        var allocation: [EquipmentType: Double] = [:]
        if landTotal > 0 {
            for (e, w) in landWeights {
                allocation[e] = militaryFactories * w / landTotal
            }
        }
        if navalTotal > 0 {
            for (e, w) in navalWeights {
                allocation[e] = dockyards * w / navalTotal
            }
        }
        setProductionAllocation(allocation)
    }

    /// Réaffecte les usines. Ajouter des usines à une ligne fait baisser son efficacité moyenne.
    mutating func setProductionAllocation(_ allocation: [EquipmentType: Double]) {
        var lines: [ProductionLine] = []
        for e in EquipmentType.allCases {
            let factories = allocation[e] ?? 0
            guard factories >= 0.05 else { continue }
            if let old = productionLines.first(where: { $0.equipment == e }) {
                var line = old
                if factories > old.factories {
                    let added = factories - old.factories
                    line.efficiency = (old.factories * old.efficiency + added * 0.3) / factories
                }
                line.factories = factories
                lines.append(line)
            } else {
                lines.append(ProductionLine(id: nextLineID, equipment: e, factories: factories, efficiency: 0.3, progress: 0))
                nextLineID += 1
            }
        }
        productionLines = lines
    }
}

// MARK: - Simulation militaire

extension Simulation {

    // MARK: Relations de guerre

    func enemies(of id: CountryID) -> Set<CountryID> {
        guard let me = state.countries[id], !me.capitulated else { return [] }
        var result = Set<CountryID>()
        for war in state.wars where war.isActive {
            if war.attackers.contains(id) {
                result.formUnion(war.defenders)
            } else if war.defenders.contains(id) {
                result.formUnion(war.attackers)
            }
        }
        return result.filter { !(state.countries[$0]?.capitulated ?? true) }
    }

    func isAtWar(_ id: CountryID) -> Bool {
        !enemies(of: id).isEmpty
    }

    func isFightingAtHome(_ id: CountryID) -> Bool {
        occupiedFraction(id) > 0.001 && isAtWar(id)
    }

    /// Capacité à projeter des forces loin de chez soi (0…1).
    func projection(from a: Country, to b: Country) -> Double {
        if a.region == b.region { return 1 }
        let satellites = a.has(.militarySatellites) ? 0.15 : 0
        return (0.25 + a.stock(.carrier) * 0.07 + a.navalPower / 3000 + satellites).clamped(0, 1)
    }

    /// Part de la maîtrise de la mer entre deux ennemis (flotte divisée entre tous ses ennemis).
    func navalShare(_ a: CountryID, vs b: CountryID) -> Double {
        guard let A = state.countries[a], let B = state.countries[b] else { return 0.5 }
        let na = (A.navalPower + A.seaDenial) / Double(max(1, enemies(of: a).count))
        let nb = (B.navalPower + B.seaDenial) / Double(max(1, enemies(of: b).count))
        return na + nb > 0 ? na / (na + nb) : 0.5
    }

    /// `a` peut-il porter la guerre sur le sol de `b` ?
    func canInvade(_ a: CountryID, _ b: CountryID, landBorder: Bool) -> Bool {
        if landBorder { return true }
        guard let A = state.countries[a], let B = state.countries[b], A.divisionCount > 0 else { return false }
        return navalShare(a, vs: b) >= 0.65 && projection(from: A, to: B) > 0.2
    }

    /// Blocus naval subi par chaque pays (0…0,9).
    func computeBlockades() -> [CountryID: Double] {
        var result: [CountryID: Double] = [:]
        for id in countryIDs {
            guard let C = state.countries[id] else { continue }
            var worst = 0.0
            for e in enemies(of: id) {
                guard let E = state.countries[e] else { continue }
                if E.region != C.region && projection(from: E, to: C) < 0.3 { continue }
                let share = navalShare(e, vs: id)
                worst = max(worst, ((share - 0.55) * 2).clamped(0, 0.9))
            }
            if !C.neighbors.isEmpty { worst *= 0.7 }   // le commerce terrestre continue
            result[id] = worst
        }
        return result
    }

    func currentFronts() -> [Front] {
        var fronts: [Front] = []
        var seen = Set<String>()
        for war in state.wars where war.isActive {
            for a in war.attackers {
                for b in war.defenders {
                    guard let A = state.countries[a], let B = state.countries[b],
                          !A.capitulated, !B.capitulated else { continue }
                    let key = a < b ? a + "|" + b : b + "|" + a
                    if seen.contains(key) { continue }
                    seen.insert(key)
                    let land = A.neighbors.contains(b)
                        || (state.occupation[a]?[b] ?? 0) > 0
                        || (state.occupation[b]?[a] ?? 0) > 0
                    fronts.append(Front(a: a, b: b, landBorder: land))
                }
            }
        }
        return fronts
    }

    /// Répartition de l'armée de chaque pays entre ses fronts (selon la menace).
    func frontAllocations(_ fronts: [Front]) -> [CountryID: [Int: Double]] {
        var raw: [CountryID: [Int: Double]] = [:]
        for (i, f) in fronts.enumerated() {
            for (me, other) in [(f.a, f.b), (f.b, f.a)] {
                guard let O = state.countries[other], let M = state.countries[me] else { continue }
                let threat = max(1, O.landStrengthIndex)
                var w = 0.0
                if f.landBorder {
                    w = threat
                } else {
                    if canInvade(other, me, landBorder: false) { w += 0.6 * threat }
                    if canInvade(me, other, landBorder: false) { w += 0.35 * projection(from: M, to: O) * threat }
                }
                raw[me, default: [:]][i] = w
            }
        }
        var result: [CountryID: [Int: Double]] = [:]
        for (id, weights) in raw {
            let total = weights.values.reduce(0, +)
            var normalized: [Int: Double] = [:]
            for (i, w) in weights {
                normalized[i] = total > 0 ? w / total : 0
            }
            result[id] = normalized
        }
        return result
    }

    // MARK: Journée militaire

    mutating func dailyMilitary() {
        for id in countryIDs {
            dailyProduction(id)
            dailyTrainingAndReinforcement(id)
        }
    }

    private mutating func dailyProduction(_ id: CountryID) {
        let milFactories = effectiveMilitaryFactories(id)
        let docks = effectiveDockyards(id)
        guard var c = state.countries[id] else { return }
        var landAssigned = 0.0, navalAssigned = 0.0
        for line in c.productionLines {
            if line.equipment.isNaval { navalAssigned += line.factories } else { landAssigned += line.factories }
        }
        let landScale = landAssigned > milFactories && landAssigned > 0 ? milFactories / landAssigned : 1
        let navalScale = navalAssigned > docks && navalAssigned > 0 ? docks / navalAssigned : 1
        var resourceFactor = 0.4
        for r in Resource.allCases {
            resourceFactor += 0.6 * (c.resourceCoverage[r] ?? 1) * r.militaryImportance
        }
        let techFactor = 0.6 + 0.4 * c.tech
        let bonus = c.economyMode.militaryOutputBonus * c.techProductionFactor * stabilityFactor(c)
        let budgetPP = c.procurementFunds * 1000 / c.costMultiplier
        var remaining = budgetPP
        for i in c.productionLines.indices {
            var line = c.productionLines[i]
            let scale = line.equipment.isNaval ? navalScale : landScale
            var output = line.factories * scale * 5 * line.efficiency * resourceFactor * techFactor * bonus
            output = max(0, min(output, remaining))
            remaining -= output
            line.progress += output
            let cost = line.equipment.cost
            if line.progress >= cost {
                let units = (line.progress / cost).rounded(.down)
                line.progress -= units * cost
                c.equipment[line.equipment, default: 0] += units
            }
            line.efficiency = min(1, line.efficiency + 0.004)
            c.productionLines[i] = line
        }
        c.procurementFunds = max(0, c.procurementFunds - (budgetPP - remaining) * c.costMultiplier / 1000)
        state.countries[id] = c
    }

    private mutating func dailyTrainingAndReinforcement(_ id: CountryID) {
        guard var c = state.countries[id] else { return }
        // Formation des nouvelles divisions
        var stillTraining: [TrainingBatch] = []
        for var batch in c.training {
            batch.daysLeft -= 1
            if batch.daysLeft <= 0 {
                c.divisions[batch.type, default: 0] += batch.count
            } else {
                stillTraining.append(batch)
            }
        }
        c.training = stillTraining
        // Renforts : on comble les pertes avec la main-d'œuvre disponible.
        let deficit = c.landPersonnelRequired - c.landPersonnel
        if deficit > 0 {
            let flow = max(1, c.recruitableManpower * 0.002)
            c.activePersonnel += min(deficit, c.availableManpower, flow)
        }
        state.countries[id] = c
    }

    // MARK: Guerre

    mutating func dailyWar() {
        let fronts = currentFronts()
        guard !fronts.isEmpty else { return }
        let allocation = frontAllocations(fronts)
        var frontCount: [CountryID: Int] = [:]
        for f in fronts {
            frontCount[f.a, default: 0] += 1
            frontCount[f.b, default: 0] += 1
        }
        for (i, f) in fronts.enumerated() {
            let landA = allocation[f.a]?[i] ?? 0
            let landB = allocation[f.b]?[i] ?? 0
            // L'aviation suit l'armée ; sans front terrestre, elle se répartit également.
            let sumA = allocation[f.a]?.values.reduce(0, +) ?? 0
            let sumB = allocation[f.b]?.values.reduce(0, +) ?? 0
            let airA = sumA > 0 ? landA : 1 / Double(max(1, frontCount[f.a] ?? 1))
            let airB = sumB > 0 ? landB : 1 / Double(max(1, frontCount[f.b] ?? 1))
            resolveBattle(f, landA: landA, landB: landB, airA: airA, airB: airB)
        }
        resolveNaval(fronts)
        for f in fronts {
            missileStrike(from: f.a, to: f.b)
            missileStrike(from: f.b, to: f.a)
        }
        checkCapitulations()
    }

    /// Vitesse d'avancée sur un territoire : les grands pays sont longs à conquérir.
    func territorySpeed(_ c: Country) -> Double {
        (300 / max(c.area, 1)).squareRoot().clamped(0.15, 3) * (0.6 + 0.4 * c.infrastructure)
    }

    private mutating func resolveBattle(_ f: Front, landA: Double, landB: Double, airA: Double, airB: Double) {
        guard var A = state.countries[f.a], var B = state.countries[f.b] else { return }

        // --- Guerre aérienne
        let airPowerA = A.airPower * airA
        let airPowerB = B.airPower * airB
        let airSup = airPowerA + airPowerB > 0 ? airPowerA / (airPowerA + airPowerB) : 0.5
        if airPowerA > 0 && airPowerB > 0 {
            A.equipment[.fighter] = max(0, A.stock(.fighter) - A.stock(.fighter) * airA * 0.0008 * (1 - airSup) * 2)
            B.equipment[.fighter] = max(0, B.stock(.fighter) - B.stock(.fighter) * airB * 0.0008 * airSup * 2)
        }
        let airMultA = 1 + 0.3 * (airSup - 0.5) * 2
        let airMultB = 1 + 0.3 * (0.5 - airSup) * 2

        // --- Guerre terrestre
        let aCanEnter = canInvade(f.a, f.b, landBorder: f.landBorder)
        let bCanEnter = canInvade(f.b, f.a, landBorder: f.landBorder)
        if landA > 0 || landB > 0 {
            let noiseA = Double.random(in: 0.9...1.1, using: &state.rng)
            let noiseB = Double.random(in: 0.9...1.1, using: &state.rng)
            let multA = A.combatMultiplier * airMultA * noiseA
            let multB = B.combatMultiplier * airMultB * noiseB
            // Débarquement : pénalité amphibie et logistique ; l'infrastructure ennemie aide le ravitaillement.
            let reachA = (f.landBorder ? 1.0 : 0.6 * projection(from: A, to: B)) * (0.7 + 0.3 * B.infrastructure)
            let reachB = (f.landBorder ? 1.0 : 0.6 * projection(from: B, to: A)) * (0.7 + 0.3 * A.infrastructure)
            let dronesA = A.stock(.drone) * landA
            let dronesB = B.stock(.drone) * landB
            let droneValueA = 0.03 * A.tech * (A.has(.autonomousDrones) ? 1.6 : 1) * (B.has(.electronicWarfare) ? 0.7 : 1)
            let droneValueB = 0.03 * B.tech * (B.has(.autonomousDrones) ? 1.6 : 1) * (A.has(.electronicWarfare) ? 0.7 : 1)
            let offA = A.offensePower(vsHardness: B.averageHardness) * landA * multA * reachA * A.posture.attack + dronesA * droneValueA
            let offB = B.offensePower(vsHardness: A.averageHardness) * landB * multB * reachB * B.posture.attack + dronesB * droneValueB
            var defA = A.defensePower(vsHardness: B.averageHardness) * landA * multA * A.posture.defense
            var defB = B.defensePower(vsHardness: A.averageHardness) * landB * multB * B.posture.defense
            // Celui qui se bat chez lui a l'avantage du terrain.
            let aHoldsB = heldFraction(of: f.b, by: f.a)
            let bHoldsA = heldFraction(of: f.a, by: f.b)
            if aHoldsB > 0.0005 {
                defB *= 1.2
            } else if bHoldsA > 0.0005 {
                defA *= 1.2
            }
            let eps = 0.01
            let net = log((offA + eps) / (defB + eps)) - log((offB + eps) / (defA + eps))
            // Guerre d'usure si les forces sont proches, percée rapide si l'écart est énorme.
            let intensity = pow(tanh(abs(net) / 2), 3)
            let noise = Double.random(in: 0.85...1.15, using: &state.rng)
            let step = 0.03 * intensity * noise
            if net > 0 {
                if bHoldsA > 0 {
                    reduceOccupation(of: f.a, by: f.b, amount: step * territorySpeed(A))
                } else if aCanEnter {
                    increaseOccupation(of: f.b, by: f.a, amount: step * territorySpeed(B))
                }
            } else if net < 0 {
                if aHoldsB > 0 {
                    reduceOccupation(of: f.b, by: f.a, amount: step * territorySpeed(B))
                } else if bCanEnter {
                    increaseOccupation(of: f.a, by: f.b, amount: step * territorySpeed(A))
                }
            }
            // Pertes proportionnelles à la puissance de feu adverse.
            let totalA = offA + defA
            let totalB = offB + defB
            let sum = max(totalA + totalB, eps)
            A.applyLandLosses(fraction: 0.002 * totalB / sum * A.posture.losses, share: landA)
            B.applyLandLosses(fraction: 0.002 * totalA / sum * B.posture.losses, share: landB)
            // Les drones engagés s'usent vite.
            A.equipment[.drone] = max(0, A.stock(.drone) - dronesA * 0.004)
            B.equipment[.drone] = max(0, B.stock(.drone) - dronesB * 0.004)
            if landA > 0 { A.experience = min(1, A.experience + 0.0005) }
            if landB > 0 { B.experience = min(1, B.experience + 0.0005) }
        }

        state.countries[f.a] = A
        state.countries[f.b] = B
    }

    private mutating func increaseOccupation(of victim: CountryID, by occupier: CountryID, amount: Double) {
        let room = 0.99 - lostFraction(victim)
        let add = min(amount, max(0, room))
        guard add > 0 else { return }
        state.occupation[victim, default: [:]][occupier, default: 0] += add
    }

    /// Libération : d'abord les zones occupées, puis les zones annexées.
    private mutating func reduceOccupation(of victim: CountryID, by occupier: CountryID, amount: Double) {
        var left = amount
        if let current = state.occupation[victim]?[occupier] {
            let taken = min(current, left)
            left -= taken
            if current - taken <= 0.0001 {
                state.occupation[victim]?[occupier] = nil
                if state.occupation[victim]?.isEmpty ?? false { state.occupation[victim] = nil }
            } else {
                state.occupation[victim]?[occupier] = current - taken
            }
        }
        if left > 0, let annexed = state.annexation[victim]?[occupier] {
            let taken = min(annexed, left)
            if annexed - taken <= 0.0001 {
                state.annexation[victim]?[occupier] = nil
                if state.annexation[victim]?.isEmpty ?? false { state.annexation[victim] = nil }
            } else {
                state.annexation[victim]?[occupier] = annexed - taken
            }
        }
    }

    private mutating func resolveNaval(_ fronts: [Front]) {
        for f in fronts {
            guard var A = state.countries[f.a], var B = state.countries[f.b] else { continue }
            guard A.navalPower > 0 && B.navalPower > 0 else { continue }
            let inReach = A.region == B.region
                || projection(from: A, to: B) >= 0.3
                || projection(from: B, to: A) >= 0.3
            guard inReach else { continue }
            let share = navalShare(f.a, vs: f.b)
            A.applyNavalLosses(0.0012 * (1 - share))
            B.applyNavalLosses(0.0012 * share)
            state.countries[f.a] = A
            state.countries[f.b] = B
        }
    }

    /// Frappes de missiles sur l'industrie et les infrastructures ennemies.
    private mutating func missileStrike(from a: CountryID, to b: CountryID) {
        guard var A = state.countries[a], var B = state.countries[b] else { return }
        let stock = A.stock(.missile)
        guard stock >= 1 else { return }
        let inRange = A.neighbors.contains(b) || A.region == B.region || stock >= 1500
            || projection(from: A, to: B) >= 0.5
        guard inRange else { return }
        let enemyCount = Double(max(1, enemies(of: a).count))
        let used = min(stock, max(1, stock * 0.004 / enemyCount))
        A.equipment[.missile] = stock - used
        let defense = (B.has(.missileDefense) ? 0.2 : 0) - (A.has(.hypersonic) ? 0.15 : 0)
        let intercept = (0.2 + 0.5 * B.tech * min(1, B.stock(.fighter) / 400) + defense).clamped(0.05, 0.9)
        let hits = used * (1 - intercept)
        let damage = hits * 0.0001 * (300 / max(B.area, 1)).squareRoot().clamped(0.1, 3)
        B.civilianFactories *= 1 - damage
        B.militaryFactories *= 1 - damage
        B.dockyards *= 1 - damage
        B.gdp *= 1 - damage * 0.2
        B.infrastructure = max(0.1, B.infrastructure - damage * 0.5)
        state.countries[a] = A
        state.countries[b] = B
    }

    private mutating func checkCapitulations() {
        for index in state.wars.indices where state.wars[index].isActive {
            let war = state.wars[index]
            for id in war.attackers + war.defenders {
                guard var c = state.countries[id], !c.capitulated else { continue }
                let occupied = occupiedFraction(id)
                let army = Double(c.divisionCount) * c.divisionFill
                if occupied >= 0.8 || (occupied >= 0.4 && army < 3) {
                    c.capitulated = true
                    state.countries[id] = c
                    addEvent("🏳️ \(c.name) capitule.", important: true)
                }
            }
            let attackersOut = war.attackers.allSatisfy { state.countries[$0]?.capitulated ?? true }
            let defendersOut = war.defenders.allSatisfy { state.countries[$0]?.capitulated ?? true }
            if attackersOut || defendersOut {
                // Le vainqueur garde ce qu'il occupe.
                applyPeace(warID: war.id, terms: .statusQuo)
            }
        }
    }
}
