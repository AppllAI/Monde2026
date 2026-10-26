import Foundation
import MapKit

// =============================================================
//  Fronts.swift
//  Les lignes de front, en plus simple que dans les grands jeux
//  de stratégie : on confie un groupe d'armées à un front (contre
//  un pays ou contre tous nos ennemis) et le jeu les répartit tout
//  le long, chacune plaquée contre la frontière la plus menacée.
//  Quand la ligne avance ou recule, les armées suivent.
//  Une flèche d'offensive tracée au doigt lance le groupe à
//  l'attaque le long de la flèche ; ensuite il reprend sa place.
// =============================================================

struct FrontOrder: Codable, Identifiable {
    let id: Int
    var owner: CountryID
    var armies: [Int]
    var enemy: CountryID?          // nil = face à tous nos ennemis
}

extension Simulation {

    /// Le front d'une armée, s'il y en a un.
    func front(of armyID: Int) -> FrontOrder? {
        state.fronts.first { $0.armies.contains(armyID) }
    }

    /// Confie ces armées à un front (elles quittent leur ancien front).
    mutating func assignFront(_ armyIDs: [Int], owner: CountryID, enemy: CountryID? = nil) -> ActionResult {
        let ids = armyIDs.filter { id in state.armies.contains { $0.id == id && $0.owner == owner } }
        guard !ids.isEmpty else { return ActionResult(success: false, message: "Aucune armée à placer.") }
        let foes = enemy.map { Set([$0]) } ?? enemies(of: owner)
        guard !foes.isEmpty else {
            return ActionResult(success: false, message: "Aucun ennemi : il n'y a pas de front à tenir.")
        }
        for i in state.fronts.indices { state.fronts[i].armies.removeAll { ids.contains($0) } }
        state.fronts.removeAll { $0.armies.isEmpty }
        state.fronts.append(FrontOrder(id: state.nextFrontID, owner: owner, armies: ids, enemy: enemy))
        state.nextFrontID += 1
        manageFront(state.fronts.count - 1)
        let line = frontierProvinces(owner, enemies: foes).count
        return ActionResult(success: true, message: "\(ids.count) armée\(ids.count > 1 ? "s" : "") sur le front (\(line) régions) : elles se répartissent tout le long.")
    }

    mutating func leaveFront(_ armyIDs: [Int]) {
        for i in state.fronts.indices { state.fronts[i].armies.removeAll { armyIDs.contains($0) } }
        state.fronts.removeAll { $0.armies.isEmpty }
    }

    mutating func manageFronts() {
        guard !state.fronts.isEmpty else { return }
        let alive = Set(state.armies.map { $0.id })
        for i in state.fronts.indices { state.fronts[i].armies.removeAll { !alive.contains($0) } }
        state.fronts.removeAll { $0.armies.isEmpty }
        for i in state.fronts.indices { manageFront(i) }
    }

    /// Répartit les armées d'un front le long de la ligne.
    private mutating func manageFront(_ index: Int) {
        let order = state.fronts[index]
        let foes = order.enemy.map { Set([$0]) } ?? enemies(of: order.owner)
        guard !foes.isEmpty else { return }
        let line = Array(frontierProvinces(order.owner, enemies: foes))
        guard !line.isEmpty else { return }
        let lineSet = Set(line)
        // Armées libres : pas au combat, pas lancées dans une offensive.
        let free = order.armies.compactMap { id -> Int? in
            guard let i = state.armies.firstIndex(where: { $0.id == id }) else { return nil }
            let a = state.armies[i]
            if a.engaged || state.battles[a.province] != nil { return nil }
            if a.path.contains(where: { foes.contains(controller(of: $0)) }) { return nil }
            return i
        }
        guard !free.isEmpty else { return }
        // La ligne, rangée dans le sens où elle s'étire le plus (ouest → est, ou nord → sud).
        let pts = line.map { ProvinceMap.all[$0].labelPoint }
        let xs = pts.map { $0.x }, ys = pts.map { $0.y }
        let horizontal = (xs.max()! - xs.min()!) >= (ys.max()! - ys.min()!)
        func along(_ p: MKMapPoint) -> Double { horizontal ? p.x : p.y }
        // Menace sur chaque région du front : armées ennemies voisines.
        var threat: [Int: Double] = [:]
        for a in state.armies where foes.contains(a.side) {
            for n in ProvinceMap.all[a.province].neighbors where lineSet.contains(n) {
                threat[n, default: 0] += Double(a.count)
            }
        }
        let sortedLine = line.sorted { along(ProvinceMap.all[$0].labelPoint) < along(ProvinceMap.all[$1].labelPoint) }
        // Les cibles : toute la ligne si on a assez d'armées, sinon des points répartis régulièrement,
        // en privilégiant les régions menacées.
        var targets: [Int] = []
        if free.count >= sortedLine.count {
            targets = sortedLine
            let extra = free.count - sortedLine.count
            let hot = sortedLine.sorted { (threat[$0] ?? 0) > (threat[$1] ?? 0) }
            for k in 0..<extra { targets.append(hot[k % hot.count]) }
        } else {
            let n = free.count, m = sortedLine.count
            var picked = Set<Int>()
            for k in 0..<n {
                // Le segment k de la ligne : on y prend la région la plus menacée.
                let lo = k * m / n, hi = max(lo + 1, (k + 1) * m / n)
                let segment = sortedLine[lo..<hi]
                let best = segment.max { (threat[$0] ?? 0) < (threat[$1] ?? 0) } ?? segment.first!
                if !picked.contains(best) { picked.insert(best); targets.append(best) }
            }
        }
        targets.sort { along(ProvinceMap.all[$0].labelPoint) < along(ProvinceMap.all[$1].labelPoint) }
        // Les armées gardent leur ordre le long de la ligne : personne ne croise personne.
        let armies = free.sorted { along(ProvinceMap.all[state.armies[$0].province].labelPoint)
                                   < along(ProvinceMap.all[state.armies[$1].province].labelPoint) }
        for (k, i) in armies.enumerated() where k < targets.count {
            let target = targets[k]
            let a = state.armies[i]
            // Face à la voisine ennemie la plus menaçante.
            let enemyNeighbors = ProvinceMap.all[target].neighbors.filter { foes.contains(controller(of: $0)) }
            let facing = enemyNeighbors.max { (enemyPressure($0, foes)) < (enemyPressure($1, foes)) }
            if a.province == target {
                if a.facing != facing, a.path.isEmpty { state.armies[i].facing = facing }
                continue
            }
            if a.path.last == target { continue }
            _ = orderArmy(a.id, to: target, facing: facing)
        }
    }

    private func enemyPressure(_ province: Int, _ foes: Set<CountryID>) -> Int {
        state.armies.filter { $0.province == province && foes.contains($0.side) }.reduce(0) { $0 + $1.count }
    }

    /// Offensive dessinée au doigt : les armées attaquent la première région ennemie traversée par la flèche,
    /// puis suivent la flèche région après région.
    mutating func arrowOffensive(_ armyIDs: [Int], along provinces: [Int]) -> ActionResult {
        guard let first = armyIDs.first, let lead = state.armies.first(where: { $0.id == first }) else {
            return ActionResult(success: false, message: "Aucune armée.")
        }
        let foes = enemies(of: lead.side)
        guard let start = provinces.firstIndex(where: { foes.contains(controller(of: $0)) }) else {
            return ActionResult(success: false, message: "La flèche doit entrer en territoire ennemi.")
        }
        let steps = Array(provinces[start...])
        var ok = 0
        for id in armyIDs {
            guard orderArmy(id, to: steps[0]).success else { continue }
            for p in steps.dropFirst() { _ = appendRoute(id, via: p) }
            ok += 1
        }
        guard ok > 0 else { return ActionResult(success: false, message: "Aucun chemin vers \(ProvinceMap.all[steps[0]].name).") }
        let goal = ProvinceMap.all[steps.last ?? steps[0]].name
        return ActionResult(success: true, message: "Offensive : \(ok) armée\(ok > 1 ? "s" : "") vers \(goal) (\(steps.count) région\(steps.count > 1 ? "s" : "") à prendre).")
    }
}
