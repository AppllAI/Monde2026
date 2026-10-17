import Foundation

// =============================================================
//  Industry.swift
//  Les complexes industriels, construits région par région.
//  Chacun rapporte de l'argent (PIB, donc impôts) ET sert à
//  quelque chose de précis :
//   - Usine de biens : le plus rentable, fait tourner l'économie,
//   - Haute technologie : recherche plus rapide, technologie,
//   - Armement : matériel, divisions formées plus vite et plus fortes,
//   - Chantier naval (côte) : navires,
//   - Centre spatial : satellites (renseignement, maîtrise du ciel).
//  Une région accueille un nombre limité de complexes (selon sa
//  taille ; les villes davantage). Prendre une région, c'est
//  prendre ses usines.
// =============================================================

extension BuildingKind {

    /// Ce que le complexe apporte, en une ligne.
    var effectSummary: String {
        switch self {
        case .consumerPlant: return "PIB +0,6 % · le meilleur revenu"
        case .techPlant: return "Recherche +6 % · technologie · PIB +0,4 %"
        case .armsPlant: return "Matériel +4 % · formation −8 % · divisions +1,5 %"
        case .shipyard: return "Chantiers navals +6 % · PIB +0,2 %"
        case .spaceCenter: return "Renseignement · ciel +3 % · satellites dès 2 centres"
        case .fort: return "+15 % de défense par niveau"
        case .base: return "Entraînement ×2, ravitaillement, recrues"
        }
    }

    /// Couleur de la catégorie (r, v, b).
    var rgb: (Double, Double, Double) {
        switch self {
        case .consumerPlant: return (0.42, 0.66, 0.95)
        case .techPlant: return (0.23, 0.72, 0.65)
        case .armsPlant: return (0.90, 0.33, 0.29)
        case .shipyard: return (0.35, 0.50, 0.95)
        case .spaceCenter: return (0.75, 0.55, 0.95)
        case .fort: return (0.85, 0.85, 0.85)
        case .base: return (0.95, 0.71, 0.27)
        }
    }

    var days: Int {
        switch self {
        case .consumerPlant: return 120
        case .techPlant: return 180
        case .armsPlant: return 150
        case .shipyard: return 150
        case .spaceCenter: return 240
        case .fort, .base: return 90
        }
    }
}

extension Simulation {

    // MARK: Lecture

    func complexes(at province: Int) -> [BuildingKind: Int] { state.complexes[province] ?? [:] }

    func complexCount(at province: Int) -> Int { complexes(at: province).values.reduce(0, +) }

    /// Nombre de complexes qu'une région peut accueillir.
    func industrySlots(_ province: Int) -> Int {
        let p = ProvinceMap.all[province]
        var slots = 2 + Int(p.weight.squareRoot() / 90)
        if TerrainMap.terrain(province) == .urban { slots += 2 }
        return min(6, max(2, slots))
    }

    /// Complexes d'un type dans les régions tenues par le pays.
    func industryCount(_ kind: BuildingKind, for id: CountryID) -> Int {
        var n = 0
        for (p, list) in state.complexes where controller(of: p) == id { n += list[kind] ?? 0 }
        return n
    }

    func industryTotals(_ id: CountryID) -> [BuildingKind: Int] {
        var out: [BuildingKind: Int] = [:]
        for (p, list) in state.complexes where controller(of: p) == id {
            for (k, n) in list { out[k, default: 0] += n }
        }
        return out
    }

    // MARK: Bonus permanents (selon les complexes tenus)

    func researchBonus(_ id: CountryID) -> Double { 1 + min(0.4, 0.06 * Double(industryCount(.techPlant, for: id))) }
    func trainingBonus(_ id: CountryID) -> Double { 1 - min(0.4, 0.08 * Double(industryCount(.armsPlant, for: id))) }
    func armsQuality(_ id: CountryID) -> Double { 1 + min(0.1, 0.015 * Double(industryCount(.armsPlant, for: id))) }
    func spaceBonus(_ id: CountryID) -> Double { min(0.15, 0.03 * Double(industryCount(.spaceCenter, for: id))) }

    // MARK: Construction

    /// Gain de PIB d'un complexe (proportionnel à la taille de l'économie) et son coût.
    func industryCost(_ kind: BuildingKind, for id: CountryID) -> (cost: Double, days: Int) {
        let gdp = state.countries[id]?.gdp ?? 50
        let infra = state.countries[id]?.infrastructure ?? 0.5
        let base = max(0.3, gdp * 0.006)
        let factor: Double
        switch kind {
        case .consumerPlant: factor = 1.6
        case .techPlant: factor = 2.4
        case .armsPlant: factor = 2.0
        case .shipyard: factor = 2.0
        case .spaceCenter: factor = 4.0
        default: factor = 1
        }
        return (base * factor, Int(Double(kind.days) * (1.3 - 0.5 * infra)))
    }

    func industryBlocked(_ kind: BuildingKind, at province: Int, for id: CountryID) -> String? {
        guard let c = state.countries[id] else { return "Pays inconnu." }
        if complexCount(at: province) >= industrySlots(province) {
            return "Région pleine (\(industrySlots(province)) complexes au maximum)."
        }
        switch kind {
        case .shipyard where !ProvinceMap.all[province].coastal: return "Il faut une région côtière."
        case .techPlant where c.tech < 0.45: return "Technologie trop faible (il faut 45)."
        case .spaceCenter where c.tech < 0.7: return "Technologie trop faible (il faut 70)."
        default: return nil
        }
    }

    mutating func completeIndustry(_ kind: BuildingKind, at province: Int, for id: CountryID) {
        state.complexes[province, default: [:]][kind, default: 0] += 1
        guard var c = state.countries[id] else { return }
        switch kind {
        case .consumerPlant:
            c.gdp *= 1.006
            c.civilianFactories *= 1.02
        case .techPlant:
            c.gdp *= 1.004
            c.tech += 0.004
        case .armsPlant:
            c.gdp *= 1.002
            c.militaryFactories = max(c.militaryFactories + 1, c.militaryFactories * 1.04)
        case .shipyard:
            c.gdp *= 1.002
            c.dockyards = max(c.dockyards + 1, c.dockyards * 1.06)
        case .spaceCenter:
            c.tech += 0.005
            c.intelligence = min(0.95, c.intelligence + 0.03)
        default: break
        }
        state.countries[id] = c
        if kind == .spaceCenter && industryCount(.spaceCenter, for: id) >= 2 && !(state.countries[id]?.has(.militarySatellites) ?? true) {
            state.countries[id]?.techs.insert(.militarySatellites)
            if id == state.playerID { addEvent("🛰️ Nos satellites militaires sont en orbite.", important: true) }
        }
    }

    /// Meilleure région pour un complexe : la plus grande région libre.
    func suggestedRegion(for kind: BuildingKind, id: CountryID) -> Int? {
        (ProvinceMap.byCountry[id] ?? [])
            .filter { controller(of: $0) == id && canBuild(kind, at: $0, for: id) == nil }
            .max { a, b in
                let wa = ProvinceMap.all[a].weight * (TerrainMap.terrain(a) == .urban ? 4 : 1) / Double(1 + complexCount(at: a))
                let wb = ProvinceMap.all[b].weight * (TerrainMap.terrain(b) == .urban ? 4 : 1) / Double(1 + complexCount(at: b))
                return wa < wb
            }
    }

    /// Complexes de départ : répartis selon l'industrie réelle de chaque pays (pour qu'on les voie sur la carte).
    mutating func setupIndustry() {
        state.complexes = [:]
        for (id, c) in state.countries {
            let regions = (ProvinceMap.byCountry[id] ?? []).filter { controller(of: $0) == id }
                .sorted { ProvinceMap.all[$0].weight * (TerrainMap.terrain($0) == .urban ? 4 : 1)
                        > ProvinceMap.all[$1].weight * (TerrainMap.terrain($1) == .urban ? 4 : 1) }
            guard !regions.isEmpty else { continue }
            let civ = max(0, Int((c.civilianFactories / 60).squareRoot().rounded()))
            let mil = max(0, Int((c.militaryFactories / 40).squareRoot().rounded()))
            var plan: [BuildingKind] = Array(repeating: .consumerPlant, count: min(10, civ))
            plan += Array(repeating: .armsPlant, count: min(5, mil))
            if c.tech >= 0.6 { plan += Array(repeating: .techPlant, count: min(4, Int(c.tech * 4))) }
            if c.dockyards > 20 { plan.append(.shipyard) }
            if c.tech >= 0.9 && c.gdp > 1500 { plan.append(.spaceCenter) }
            var k = 0
            for kind in plan {
                var tries = 0
                while tries < regions.count {
                    let p = regions[k % regions.count]
                    k += 1
                    tries += 1
                    if complexCount(at: p) < industrySlots(p) && (kind != .shipyard || ProvinceMap.all[p].coastal) {
                        state.complexes[p, default: [:]][kind, default: 0] += 1
                        break
                    }
                }
            }
        }
    }

    /// L'IA investit : de temps en temps un nouveau complexe dans sa meilleure région.
    mutating func aiIndustry() {
        for (id, c) in state.countries where id != state.playerID {
            guard c.debtRatio < 1.2, !isAtWar(id) || c.gdp > 500,
                  Double.random(in: 0...1, using: &state.rng) < 0.12,
                  !state.constructions.contains(where: { $0.owner == id && $0.kind.isIndustry }) else { continue }
            let kind: BuildingKind
            if isAtWar(id) { kind = .armsPlant }
            else if c.tech >= 0.6 && Double.random(in: 0...1, using: &state.rng) < 0.3 { kind = .techPlant }
            else { kind = .consumerPlant }
            if let p = suggestedRegion(for: kind, id: id) { build(kind, at: p, for: id) }
        }
    }
}

// MARK: - Bonus mis en cache (recalculés chaque mois et à chaque chantier terminé)

struct IndustryBonus: Codable {
    var research: Double = 1
    var training: Double = 1
    var arms: Double = 1
    var space: Double = 0
}

extension Simulation {

    mutating func refreshIndustryBonuses() {
        var totals: [CountryID: [BuildingKind: Int]] = [:]
        for (p, list) in state.complexes {
            let holder = controller(of: p)
            for (k, n) in list { totals[holder, default: [:]][k, default: 0] += n }
        }
        var cache: [CountryID: IndustryBonus] = [:]
        for (id, t) in totals {
            cache[id] = IndustryBonus(research: 1 + min(0.4, 0.06 * Double(t[.techPlant] ?? 0)),
                                      training: 1 - min(0.4, 0.08 * Double(t[.armsPlant] ?? 0)),
                                      arms: 1 + min(0.1, 0.015 * Double(t[.armsPlant] ?? 0)),
                                      space: min(0.15, 0.03 * Double(t[.spaceCenter] ?? 0)))
        }
        state.industryCache = cache
    }
}

// MARK: - Réserves du joueur, rangées dans ses bases

extension Simulation {

    func depot(at base: Int) -> [DivisionType: Int] { state.depots[base] ?? [:] }

    /// Les réserves rangées par base doivent correspondre aux divisions hors armée.
    mutating func syncDepots() {
        guard let p = state.playerID else { return }
        let own = bases(of: p)
        // Base perdue : ses réserves se replient sur une autre base.
        for (b, list) in state.depots where !own.contains(b) {
            state.depots[b] = nil
            if let other = own.first {
                for (t, n) in list { state.depots[other, default: [:]][t, default: 0] += n }
            }
        }
        let free = unassignedDivisions(p)
        for t in DivisionType.allCases {
            let want = free[t] ?? 0
            var have = state.depots.values.reduce(0) { $0 + ($1[t] ?? 0) }
            if have < want, let home = own.first {
                state.depots[home, default: [:]][t, default: 0] += want - have
            }
            while have > want {
                guard let b = state.depots.keys.max(by: { (state.depots[$0]?[t] ?? 0) < (state.depots[$1]?[t] ?? 0) }),
                      let n = state.depots[b]?[t], n > 0 else { break }
                let take = min(n, have - want)
                state.depots[b]?[t] = n - take
                have -= take
            }
        }
    }

    /// Le joueur forme une armée dans une base, avec les réserves qui s'y trouvent.
    mutating func formArmy(at base: Int, composition: [DivisionType: Int]) -> ActionResult {
        guard let p = state.playerID, hasBase(base, for: p) else {
            return ActionResult(success: false, message: "Choisissez une de vos bases.")
        }
        let stock = depot(at: base)
        var picked: [DivisionType: Int] = [:]
        var total = 0
        for t in DivisionType.allCases {
            let n = min(composition[t] ?? 0, stock[t] ?? 0, Army.maxDivisions - total)
            if n > 0 { picked[t] = n; total += n }
        }
        guard total > 0 else { return ActionResult(success: false, message: "Pas de réserves de ce type dans cette base.") }
        let r = createArmy(for: p, size: total, at: base, picked: picked)
        if r.success {
            for (t, n) in picked { state.depots[base]?[t] = max(0, (state.depots[base]?[t] ?? 0) - n) }
            if let i = state.armies.indices.last {
                state.armies[i].training = true
                state.armies[i].stance = .defend
            }
        }
        return r
    }

    /// Déplace des divisions d'une armée vers une autre armée de la même région, ou vers la réserve de la base.
    mutating func transferDivisions(_ type: DivisionType, count: Int, from source: Int, to target: Int?) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == source }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        let a = state.armies[i]
        let n = min(count, a.divisions[type] ?? 0)
        guard n > 0 else { return ActionResult(success: false, message: "Plus de divisions de ce type.") }
        if let target = target {
            guard let j = state.armies.firstIndex(where: { $0.id == target }), state.armies[j].owner == a.owner,
                  state.armies[j].province == a.province else {
                return ActionResult(success: false, message: "Les deux armées doivent être dans la même région.")
            }
            let room = Army.maxDivisions - state.armies[j].count
            let moved = min(n, room)
            guard moved > 0 else { return ActionResult(success: false, message: "\(state.armies[j].name) est au complet.") }
            state.armies[i].divisions[type] = (a.divisions[type] ?? 0) - moved
            state.armies[j].divisions[type, default: 0] += moved
            let total = Double(state.armies[j].count)
            state.armies[j].experience = (state.armies[j].experience * (total - Double(moved)) + a.experience * Double(moved)) / max(1, total)
        } else {
            guard hasBase(a.province, for: a.owner) else {
                return ActionResult(success: false, message: "Il faut être dans une base pour laisser des divisions en réserve.")
            }
            state.armies[i].divisions[type] = (a.divisions[type] ?? 0) - n
            if a.owner == state.playerID { state.depots[a.province, default: [:]][type, default: 0] += n }
        }
        state.armies.removeAll { $0.count == 0 }
        return ActionResult(success: true, message: "")
    }

    /// Prend des divisions de la réserve d'une base pour renforcer une armée qui s'y trouve.
    mutating func reinforceFromDepot(_ armyID: Int, type: DivisionType, count: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        let a = state.armies[i]
        let stock = depot(at: a.province)[type] ?? 0
        let n = min(count, stock, Army.maxDivisions - a.count)
        guard n > 0 else { return ActionResult(success: false, message: stock == 0 ? "Pas de réserve de ce type ici." : "Armée au complet.") }
        state.depots[a.province]?[type] = stock - n
        state.armies[i].divisions[type, default: 0] += n
        return ActionResult(success: true, message: "")
    }
}
