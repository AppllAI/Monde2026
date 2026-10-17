import Foundation

// =============================================================
//  Bases.swift
//  Ce qu'on construit sur la carte :
//   - les forts (niveaux 1 à 5) : chaque niveau +15 % en défense
//     pour qui tient la région ; un niveau est détruit à la prise,
//   - les bases militaires : on y stationne et on y entraîne ses
//     armées (entraînement deux fois plus rapide qu'en campagne),
//     et elles ravitaillent les armées autour.
//  Et l'entraînement des armées (expérience 0…100 %).
// =============================================================

enum BuildingKind: String, Codable, CaseIterable, Identifiable {
    case fort, base
    // Complexes industriels (voir Industry.swift)
    case consumerPlant, techPlant, armsPlant, shipyard, spaceCenter

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fort: return "Fort"
        case .base: return "Base militaire"
        case .consumerPlant: return "Usine de biens"
        case .techPlant: return "Usine haute technologie"
        case .armsPlant: return "Usine d'armement"
        case .shipyard: return "Chantier naval"
        case .spaceCenter: return "Centre spatial"
        }
    }

    var icon: String {
        switch self {
        case .fort: return "building.columns.fill"
        case .base: return "star.square.fill"
        case .consumerPlant: return "building.2.fill"
        case .techPlant: return "cpu.fill"
        case .armsPlant: return "shield.checkered"
        case .shipyard: return "ferry.fill"
        case .spaceCenter: return "airplane.departure"
        }
    }

    var isIndustry: Bool { self != .fort && self != .base }

    static var industries: [BuildingKind] { [.consumerPlant, .techPlant, .armsPlant, .shipyard, .spaceCenter] }
}

struct ConstructionJob: Codable, Identifiable {
    let id: Int
    let province: Int
    let kind: BuildingKind
    let owner: CountryID
    var daysLeft: Int
    let totalDays: Int

    var progress: Double { 1 - Double(daysLeft) / Double(max(1, totalDays)) }
}

extension Simulation {

    static let maxFortLevel = 5

    func fortLevel(_ province: Int) -> Int { state.forts[province] ?? 0 }

    func hasBase(_ province: Int, for owner: CountryID) -> Bool {
        state.bases.contains(province) && controller(of: province) == owner
    }

    func bases(of id: CountryID) -> [Int] {
        state.bases.filter { controller(of: $0) == id }.sorted()
    }

    func construction(at province: Int) -> ConstructionJob? {
        state.constructions.first { $0.province == province }
    }

    /// Coût (milliards de dollars) et durée (jours) d'une construction.
    func buildCost(_ kind: BuildingKind, at province: Int, for id: CountryID) -> (cost: Double, days: Int) {
        let infra = state.countries[id]?.infrastructure ?? 0.5
        switch kind {
        case .fort:
            let next = fortLevel(province) + 1
            return (0.8 * Double(next), Int(Double(40 + 15 * next) * (1.3 - 0.5 * infra)))
        case .base:
            return (3, Int(90 * (1.3 - 0.5 * infra)))
        default:
            return industryCost(kind, for: id)
        }
    }

    func canBuild(_ kind: BuildingKind, at province: Int, for id: CountryID) -> String? {
        guard ProvinceMap.all.indices.contains(province) else { return "Région inconnue." }
        guard controller(of: province) == id else { return "Il faut tenir cette région." }
        if construction(at: province) != nil { return "Un chantier est déjà en cours ici." }
        switch kind {
        case .consumerPlant, .techPlant, .armsPlant, .shipyard, .spaceCenter:
            if let reason = industryBlocked(kind, at: province, for: id) { return reason }
        case .fort:
            if fortLevel(province) >= Simulation.maxFortLevel { return "Fort déjà au niveau maximum." }
        case .base:
            if state.bases.contains(province) { return "Il y a déjà une base ici." }
            if bases(of: id).count >= 2 + (state.countries[id]?.divisionCount ?? 0) / 40 {
                return "Trop de bases pour votre armée (une de plus tous les 40 divisions)."
            }
        }
        return nil
    }

    @discardableResult
    mutating func build(_ kind: BuildingKind, at province: Int, for id: CountryID) -> ActionResult {
        if let reason = canBuild(kind, at: province, for: id) { return ActionResult(success: false, message: reason) }
        let (cost, days) = buildCost(kind, at: province, for: id)
        state.countries[id]?.debt += cost
        state.constructions.append(ConstructionJob(id: state.nextConstructionID, province: province, kind: kind,
                                                   owner: id, daysLeft: days, totalDays: days))
        state.nextConstructionID += 1
        let what = kind == .fort ? "Fort niveau \(fortLevel(province) + 1)" : kind.name
        return ActionResult(success: true, message: "\(what) en chantier à \(ProvinceMap.all[province].name) : \(days) jours, \(Fmt.money(cost)).")
    }

    mutating func cancelConstruction(at province: Int) {
        state.constructions.removeAll { $0.province == province }
    }

    mutating func dailyConstruction() {
        guard !state.constructions.isEmpty else { return }
        var done: [ConstructionJob] = []
        for i in state.constructions.indices {
            state.constructions[i].daysLeft -= 1
            if state.constructions[i].daysLeft <= 0 { done.append(state.constructions[i]) }
        }
        let jobs = state.constructions
        state.constructions = jobs.filter { $0.daysLeft > 0 && controller(of: $0.province) == $0.owner }
        for job in done where controller(of: job.province) == job.owner {
            switch job.kind {
            case .fort: state.forts[job.province] = min(Simulation.maxFortLevel, fortLevel(job.province) + 1)
            case .base: state.bases.insert(job.province)
            default: completeIndustry(job.kind, at: job.province, for: job.owner)
            }
            if job.owner == state.playerID {
                let what = job.kind == .fort ? "Fort niveau \(fortLevel(job.province))" : job.kind.name
                addEvent("🏗️ \(what) terminé à \(ProvinceMap.all[job.province].name).", important: true)
            }
        }
    }

    /// Bases de départ : une à la capitale militaire, plus pour les grandes armées ;
    /// forts sur les fronts déjà actifs.
    mutating func setupBases() {
        state.bases = []
        state.forts = [:]
        for (id, c) in state.countries where c.divisionCount > 0 {
            guard let home = homeProvince(for: id) else { continue }
            state.bases.insert(home)
            let extra = min(4, c.divisionCount / 80)
            guard extra > 0 else { continue }
            let others = (ProvinceMap.byCountry[id] ?? []).filter { $0 != home && controller(of: $0) == id }
                .sorted { ProvinceMap.all[$0].weight > ProvinceMap.all[$1].weight }
            // Bases réparties : on évite deux bases voisines.
            var picked: [Int] = []
            for p in others where picked.count < extra {
                let near = ([home] + picked).contains { distanceKm($0, p) < 600 }
                if !near { picked.append(p) }
            }
            for p in picked { state.bases.insert(p) }
        }
        for war in state.wars where war.isActive {
            for id in war.attackers + war.defenders {
                for p in frontierProvinces(id, enemies: enemies(of: id)) {
                    state.forts[p] = max(fortLevel(p), 1)
                }
            }
        }
    }

    // MARK: Entraînement

    /// Expérience de départ d'une armée selon la préparation du pays (et la guerre en cours).
    func startingExperience(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0.3 }
        return (0.15 + 0.35 * c.readiness + 0.3 * c.experience + (isAtWar(id) ? 0.15 : 0)).clamped(0.1, 0.85)
    }

    /// Chaque jour : les armées à l'entraînement progressent (deux fois plus vite dans une base).
    mutating func dailyTraining() {
        for i in state.armies.indices where state.armies[i].training {
            let a = state.armies[i]
            guard a.path.isEmpty, !a.engaged else { continue }
            let rate = hasBase(a.province, for: a.owner) ? 0.006 : 0.003
            state.armies[i].experience = min(1, a.experience + rate * (1 - a.experience * 0.5))
        }
    }

    /// Envoie une armée à la base la plus proche (en garnison, à l'entraînement).
    mutating func sendToBase(_ armyID: Int) -> ActionResult {
        guard let i = state.armies.firstIndex(where: { $0.id == armyID }) else {
            return ActionResult(success: false, message: "Armée introuvable.")
        }
        let a = state.armies[i]
        let own = bases(of: a.owner)
        guard !own.isEmpty else { return ActionResult(success: false, message: "Aucune base : construisez-en une (touchez une de vos régions).") }
        if own.contains(a.province) {
            state.armies[i].path = []
            state.armies[i].training = true
            state.armies[i].stance = .defend
            return ActionResult(success: true, message: "\(a.name) s'entraîne à la base de \(ProvinceMap.all[a.province].name).")
        }
        let target = own.min { distanceKm(a.province, $0) < distanceKm(a.province, $1) } ?? own[0]
        guard let r = route(for: a, to: target), !r.amphibious || state.countries[a.owner] != nil else {
            return ActionResult(success: false, message: "Pas de chemin jusqu'à la base.")
        }
        state.armies[i].path = r.path
        state.armies[i].amphibious = r.amphibious
        state.armies[i].progress = 0
        state.armies[i].training = true
        state.armies[i].stance = .defend
        return ActionResult(success: true, message: "\(a.name) rentre à la base de \(ProvinceMap.all[target].name) pour s'entraîner.")
    }

    mutating func setTraining(_ on: Bool, for armyIDs: [Int]) {
        for i in state.armies.indices where armyIDs.contains(state.armies[i].id) {
            state.armies[i].training = on
        }
    }

    // MARK: IA : forts sur les fronts menacés

    mutating func aiFortify() {
        for war in state.wars where war.isActive {
            for id in war.attackers + war.defenders where id != state.playerID {
                guard let c = state.countries[id], c.debtRatio < 1.5,
                      state.constructions.filter({ $0.owner == id }).count < 2 else { continue }
                let front = frontierProvinces(id, enemies: enemies(of: id))
                    .filter { fortLevel($0) < 3 && construction(at: $0) == nil }
                guard let p = front.max(by: { ProvinceMap.all[$0].weight < ProvinceMap.all[$1].weight }) else { continue }
                build(.fort, at: p, for: id)
            }
        }
    }
}
