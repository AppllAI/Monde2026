import SwiftUI
import MapKit

// =============================================================
//  GameStore.swift
//  Relie le moteur à l'interface : horloge en temps réel,
//  vitesse, sélection, panneaux, notifications, sauvegarde.
// =============================================================

enum Panel: Identifiable, Hashable {
    case economy, military, production, diplomacy, world, politics, research, endGame, projects
    case country(CountryID)
    case event(Int)
    case battle(Int)
    case army(Int)
    case diplo(CountryID, DiploAction)
    case report(Int)

    var id: String {
        switch self {
        case .economy: return "economy"
        case .military: return "military"
        case .production: return "production"
        case .diplomacy: return "diplomacy"
        case .world: return "world"
        case .politics: return "politics"
        case .research: return "research"
        case .projects: return "projects"
        case .endGame: return "endGame"
        case .country(let c): return "country-" + c
        case .event(let e): return "event-\(e)"
        case .battle(let p): return "battle-\(p)"
        case .army(let a): return "army-\(a)"
        case .diplo(let c, let a): return "diplo-\(c)-\(a.rawValue)"
        case .report(let r): return "report-\(r)"
        }
    }

    /// Panneau qui arrête le temps (une décision à prendre).
    var isModal: Bool {
        switch self {
        case .event, .endGame: return true
        default: return false
        }
    }

    /// Panneau qui laisse le temps s'écouler (on regarde la bataille se dérouler).
    var isLive: Bool {
        if case .battle = self { return true }
        return false
    }
}

/// Opérations qui demandent de toucher une région cible.
enum ArmyOperation: String {
    case bombard, airdrop, encircle

    var title: String {
        switch self {
        case .bombard: return "Touchez la région à bombarder (6 jours de frappes)"
        case .airdrop: return "Touchez la région où sauter (700 km au plus)"
        case .encircle: return "Touchez la région à encercler (au moins 2 armées groupées)"
        }
    }

    var icon: String {
        switch self {
        case .bombard: return "burst.fill"
        case .airdrop: return "parachute.fill"
        case .encircle: return "arrow.triangle.merge"
        }
    }
}

enum MapMode: String, CaseIterable, Identifiable {
    case political = "Pays"
    case relations = "Diplomatie"
    case trade = "Commerce"
    case conflicts = "Conflits"
    case allies = "Alliés"
    case alliances = "Factions"
    case economy = "Économie"
    case military = "Puissance"
    case industry = "Industrie"
    case terrain = "Terrain"
    case influence = "Influence"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .political: return "globe.europe.africa"
        case .alliances: return "shield.lefthalf.filled"
        case .relations: return "hand.raised"
        case .economy: return "chart.line.uptrend.xyaxis"
        case .military: return "scope"
        case .terrain: return "mountain.2.fill"
        case .trade: return "shippingbox.fill"
        case .conflicts: return "flame.fill"
        case .allies: return "person.2.fill"
        case .industry: return "building.2.fill"
        case .influence: return "dot.radiowaves.left.and.right"
        }
    }
}

/// Ce que la carte affiche. Séparé du magasin : la carte se met à jour à chaque jour de jeu
/// sans que tout le reste de l'interface (barres, panneaux) soit recalculé.
@MainActor
final class MapFeed: ObservableObject {
    @Published var map = MapSnapshot.empty
    @Published var units = UnitsSnapshot.empty
    /// Durée du glissement des pions : l'intervalle réel entre deux jours de jeu.
    var animation: TimeInterval = 0.3
}

/// Résultat d'un jour de jeu calculé en arrière-plan.
private struct StepResult {
    let sim: Simulation
    let signature: Int
    let units: UnitsSnapshot
    let selection: Int?
    let group: Set<Int>
    let elapsed: TimeInterval
}

@MainActor
final class GameStore: ObservableObject {
    /// Le moteur. Il n'est pas « @Published » pour être modifié sur place (rapide) ;
    /// `version` prévient l'interface à chaque changement.
    private(set) var sim: Simulation?
    @Published private(set) var version = 0

    @Published var speed = 0                  // 0 = pause, 1…3
    @Published var panel: Panel?
    @Published var mapMode: MapMode = .political {
        didSet { refreshMap() }
    }
    let feed = MapFeed()
    var mapSnapshot: MapSnapshot { feed.map }
    var unitsSnapshot: UnitsSnapshot { feed.units }
    private var territorySignature = 0
    /// Change à chaque action du joueur : un jour calculé en arrière-plan pendant une action est jeté (puis recalculé).
    private var mutationCount = 0
    private var mapGeneration = 0
    private var mapSelected: CountryID?
    private var lastArmyTap: (id: Int, time: Date)?
    private var lastLanded = Date()
    private var lastUIPublish = Date.distantPast
    private var achievementCount = 0
    /// Temps de calcul moyen d'un jour (affiché dans le menu, utile pour mesurer sur iPad).
    private(set) var dayCost: TimeInterval = 0
    @Published var selectedProvince: Int?
    @Published var selectedCountry: CountryID?
    @Published var selectedArmy: Int?
    @Published var armyGroup: Set<Int> = []    // armées commandées avec l'armée sélectionnée
    @Published var waypointMode = false         // chaque région touchée s'ajoute au trajet
    @Published var waypointLocked = false       // mode étapes verrouillé (sans garder le doigt)
    @Published var mapTray = false              // le sélecteur de cartes est ouvert
    @Published var placing: BuildingKind? {     // on choisit la région où construire
        didSet { refreshMap() }
    }
    @Published var armyOp: ArmyOperation?       // opération en attente d'une région cible
    @Published private(set) var focus: MapFocus?
    private var focusCounter = 0
    @Published var satellite = false
    @Published var toasts: [GameEvent] = []
    @Published var feedback: String?
    @Published var autoPause = false
    /// Dernier rapport de bataille (une carte s'affiche quelques secondes pour l'ouvrir).
    @Published var reportNotice: Int?
    private var lastReportID = 0

    private var lastSeenEventID = 0
    private var loop: Task<Void, Never>?

    var playerID: CountryID? { sim?.state.playerID }
    var player: Country? { playerID.flatMap { sim?.state.countries[$0] } }
    var hasGame: Bool { sim != nil }

    // MARK: - Partie

    func newGame(as id: CountryID, difficulty: Difficulty = .normal) {
        mutationCount += 1
        sim = Simulation(playerID: id, difficulty: difficulty)
        lastSeenEventID = (sim?.state.nextEventID ?? 1) - 1
        lastReportID = sim?.state.reports.last?.id ?? 0
        speed = 0
        panel = nil
        toasts = []
        selectedProvince = nil
        selectedCountry = nil
        version += 1
        refreshMap()
        focusOn(id)
        startLoop()
    }

    func quitToMenu() {
        loop?.cancel()
        mutationCount += 1
        sim = nil
        panel = nil
        version += 1
    }

    /// L'horloge : chaque jour est calculé HORS du fil principal (la carte et les gestes restent fluides),
    /// puis le nouvel état remplace l'ancien d'un coup.
    private func startLoop() {
        loop?.cancel()
        lastLanded = Date()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let started = Date()
                if self.speed > 0 && self.panel?.isModal != true, let current = self.sim {
                    let stamp = self.mutationCount
                    let selection = self.selectedArmy
                    let group = self.armyGroup
                    let result = await Task.detached(priority: .userInitiated) { () -> StepResult in
                        let t0 = Date()
                        var next = current
                        next.advance(days: 1)
                        let signature = GameStore.territoryHash(next)
                        let units = UnitsBuilder.build(next, selectedArmy: selection, group: group)
                        return StepResult(sim: next, signature: signature, units: units, selection: selection,
                                          group: group, elapsed: Date().timeIntervalSince(t0))
                    }.value
                    if Task.isCancelled { return }
                    // Le joueur a agi pendant le calcul : on garde son action, le jour sera recalculé.
                    if stamp == self.mutationCount && self.sim != nil {
                        self.land(result)
                    }
                }
                let wait = max(0.012, self.dayInterval - Date().timeIntervalSince(started))
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }

    /// Intervalle visé entre deux jours de jeu.
    private var dayInterval: TimeInterval {
        switch speed {
        case 1: return 0.55
        case 2: return 0.2
        case 3: return 0.07
        default: return 0.15
        }
    }

    private func land(_ r: StepResult) {
        let now = Date()
        let gap = min(1.0, now.timeIntervalSince(lastLanded))
        lastLanded = now
        sim = r.sim
        dayCost = dayCost == 0 ? r.elapsed : dayCost * 0.9 + r.elapsed * 0.1
        // Les pions glissent pendant exactement l'intervalle entre deux jours : mouvement continu.
        feed.animation = max(0.05, gap)
        if r.selection == selectedArmy && r.group == armyGroup {
            feed.units = decorate(r.units)
        } else {
            refreshUnits()
        }
        afterStep(signature: r.signature, publish: now.timeIntervalSince(lastUIPublish) > 0.25 || speed == 1)
    }

    /// Avance immédiatement (sur le fil principal) : tests et « avancer d'un mois ».
    func step(days: Int = 1) {
        guard sim != nil else { return }
        mutationCount += 1
        sim!.advance(days: days)
        refreshUnits()
        afterStep(signature: GameStore.territoryHash(sim!), publish: true)
    }

    private func afterStep(signature: Int, publish: Bool) {
        guard sim != nil else { return }
        if signature != territorySignature || Simulation.calendar.component(.day, from: sim!.currentDate) == 1 {
            territorySignature = signature
            refreshMap(units: false)
        }
        if let id = selectedArmy, !(sim!.state.armies.contains { $0.id == id }) {
            selectedArmy = nil
            armyGroup = []
        }
        // Le temps ne s'arrête que pour l'essentiel : une guerre qui nous concerne.
        if sim!.state.pauseRequested {
            sim!.state.pauseRequested = false
            speed = 0
        }
        if !armyGroup.isEmpty {
            let alive = Set(sim!.state.armies.map { $0.id })
            let kept = armyGroup.intersection(alive)
            if kept != armyGroup { armyGroup = kept }
        }
        collectEvents()
        if let last = sim!.state.reports.last, last.id > lastReportID {
            lastReportID = last.id
            reportNotice = last.id
            let id = last.id
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if self?.reportNotice == id { self?.reportNotice = nil }
            }
        }
        presentUrgent()
        if let unlocked = sim?.state.achievements, unlocked.count != achievementCount {
            achievementCount = unlocked.count
            AchievementStore.merge(unlocked)
        }
        // Le reste de l'interface (chiffres, panneaux) est rafraîchi au plus 4 fois par seconde.
        if publish {
            lastUIPublish = Date()
            version += 1
        }
    }

    /// Ouvre automatiquement un événement à choix ou l'écran de fin.
    func presentUrgent() {
        guard panel == nil, let s = sim, let p = s.state.playerID else { return }
        if let record = s.state.record, record.gameOver, !record.acknowledged {
            speed = 0
            panel = .endGame
        } else if let event = s.state.pendingEvents.first(where: { $0.country == p }) {
            speed = 0
            panel = .event(event.id)
        }
    }

    func acknowledgeEnd() {
        guard sim != nil else { return }
        mutationCount += 1
        sim!.state.record?.acknowledged = true
        panel = nil
        version += 1
    }

    private func collectEvents() {
        guard let events = sim?.state.events else { return }
        let fresh = events.filter { $0.id > lastSeenEventID && $0.important }
        lastSeenEventID = events.last?.id ?? lastSeenEventID
        guard !fresh.isEmpty else { return }
        if autoPause { speed = 0 }
        let keep = fresh.suffix(2)
        toasts = Array(toasts.suffix(2 - min(2, keep.count))) + keep
        for event in fresh.suffix(3) {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_500_000_000)
                self?.toasts.removeAll { $0.id == event.id }
            }
        }
    }

    // MARK: - Actions

    /// Modifie le moteur puis rafraîchit l'interface.
    func mutate(_ body: (inout Simulation) -> Void) {
        guard sim != nil else { return }
        mutationCount += 1
        body(&sim!)
        version += 1
        refreshMap()
        collectEvents()
    }

    /// Action diplomatique avec message de retour.
    @discardableResult
    func perform(_ body: (inout Simulation, CountryID) -> ActionResult) -> ActionResult {
        guard sim != nil, let p = playerID else { return ActionResult(success: false, message: "") }
        mutationCount += 1
        let result = body(&sim!, p)
        feedback = result.message.isEmpty ? nil : result.message
        version += 1
        refreshMap()
        collectEvents()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if self?.feedback == result.message { self?.feedback = nil }
        }
        return result
    }

    /// Choisir la région d'un nouveau bâtiment : le panneau se ferme, les régions possibles s'allument.
    func startPlacing(_ kind: BuildingKind) {
        panel = nil
        selectedArmy = nil
        placing = kind
    }

    func open(_ p: Panel) {
        panel = p
        refreshMap()
    }

    // MARK: - Carte

    var unitAnimation: TimeInterval { feed.animation }

    func refreshUnits() {
        guard let s = sim else { feed.units = .empty; return }
        feed.units = decorate(UnitsBuilder.build(s, selectedArmy: selectedArmy, group: armyGroup))
    }

    /// Ajoute aux unités ce qui dépend de l'interface : région sélectionnée, régions constructibles.
    private func decorate(_ units: UnitsSnapshot) -> UnitsSnapshot {
        var u = units
        u.selectedProvince = selectedProvince
        u.highlight = highlightProvinces
        return u
    }

    private var highlightProvinces: [Int] {
        guard let kind = placing, let p = playerID, let s = sim else { return [] }
        return (ProvinceMap.byCountry[p] ?? []).filter { s.canBuild(kind, at: $0, for: p) == nil }
    }

    /// Empreinte de ce qui change la couleur des régions (contrôle, guerres, traités, chantiers).
    nonisolated static func territoryHash(_ s: Simulation) -> Int {
        var h = Hasher()
        h.combine(s.state.control.count)
        for (k, v) in s.state.control.sorted(by: { $0.key < $1.key }) { h.combine(k); h.combine(v) }
        h.combine(s.state.wars.filter { $0.isActive }.count)
        h.combine(s.state.treaties.count)
        h.combine(s.state.constructions.count)
        h.combine(s.state.forts.count)
        h.combine(s.state.bases.count)
        h.combine(s.state.complexes.count)
        h.combine(s.state.warPlans.count)
        return h.finalize()
    }

    /// Pion déposé du doigt sur une région (et peut-être contre une frontière).
    func dropArmy(_ id: Int, at province: Int, facing: Int?) {
        let ids = (selectedArmy == id ? [id] + armyGroup.sorted() : [id])
        perform { sim, _ in
            var last = ActionResult(success: false, message: "")
            var ok = 0
            for a in ids {
                let r = sim.orderArmy(a, to: province, facing: facing)
                if r.success { ok += 1; last = r } else if ok == 0 { last = r }
            }
            return ids.count > 1 && ok > 1 ? ActionResult(success: true, message: "\(ok) armées en route.") : last
        }
        selectedArmy = nil
        armyGroup = []
        refreshUnits()
    }

    /// Après un changement de sélection : la carte des régions ne se recalcule que si le pays mis en valeur change.
    func refreshSelection() {
        var selected = selectedCountry
        if case .country(let id)? = panel { selected = id }
        if selected != mapSelected { refreshMap() } else { refreshUnits() }
    }

    /// Recalcule l'image de la carte des régions EN ARRIÈRE-PLAN ; seule la dernière demande compte.
    /// Aperçu d'un ordre pendant le glisser d'un pion.
    func previewOrder(_ army: Int, to province: Int) -> (path: [Int], days: Int, attack: Bool)? {
        sim?.previewOrder(army, to: province)
    }

    /// Trait dessiné au doigt (appui long puis glisser) : avec des armées sélectionnées et un trait qui
    /// entre chez l'ennemi, c'est une flèche d'offensive ; sinon, un lasso qui sélectionne les pions entourés.
    func handleStroke(enclosed ids: [Int], path: [GeoPoint]) {
        if let lead = selectedArmy, sim?.state.armies.first(where: { $0.id == lead })?.owner == playerID,
           let s = sim, let last = path.last, let end = ProvinceMap.province(at: last),
           s.enemies(of: playerID ?? "").contains(s.controller(of: end.id)) {
            var provinces: [Int] = []
            for p in path {
                guard let pr = ProvinceMap.province(at: p)?.id else { continue }
                if provinces.last != pr && !provinces.contains(pr) { provinces.append(pr) }
            }
            let group = [lead] + armyGroup.sorted()
            perform { sim, _ in sim.arrowOffensive(group, along: provinces) }
            selectedArmy = nil
            armyGroup = []
            refreshUnits()
            return
        }
        guard let first = ids.first else { return }
        selectedArmy = first
        armyGroup = Set(ids.dropFirst())
        selectedCountry = nil
        selectedProvince = nil
        feedback = ids.count > 1 ? "\(ids.count) armées sélectionnées." : nil
        refreshSelection()
    }

    /// Confie l'armée sélectionnée (et son groupe) au front.
    func holdFront() {
        guard let lead = selectedArmy, let p = playerID else { return }
        let ids = [lead] + armyGroup.sorted()
        let r = perform { sim, _ in sim.assignFront(ids, owner: p) }
        if r.success {
            selectedArmy = nil
            armyGroup = []
            refreshUnits()
        }
    }

    func leaveFront() {
        guard let lead = selectedArmy else { return }
        let ids = [lead] + armyGroup.sorted()
        mutate { $0.leaveFront(ids) }
        feedback = "Ces armées ne sont plus affectées au front."
    }

    func refreshMap(units: Bool = true) {
        if units { refreshUnits() }
        guard let s = sim else {
            feed.map = .empty
            return
        }
        var selected = selectedCountry
        if case .country(let id)? = panel { selected = id }
        let mode = mapMode
        mapSelected = selected
        mapGeneration += 1
        let generation = mapGeneration
        Task.detached(priority: .userInitiated) { [weak self] in
            let snap = MapSnapshotBuilder.build(s, mode: mode, selected: selected, selectedProvince: nil)
            await MainActor.run {
                guard let self, generation == self.mapGeneration else { return }
                if snap != self.feed.map { self.feed.map = snap }
            }
        }
    }

    func handleTap(_ tap: MapTap) {
        switch tap {
        case .point(let p): tapMap(p)
        case .army(let id): tapArmy(id)
        case .battle(let province): openBattle(province)
        }
    }

    func openBattle(_ province: Int) {
        guard sim?.state.battles[province] != nil else { return }
        panel = .battle(province)
    }

    /// Toucher un pion : le sien = sélection (ou ajout au groupe) ; un ennemi = l'attaquer.
    func tapArmy(_ id: Int) {
        guard let s = sim, let a = s.state.armies.first(where: { $0.id == id }) else { return }
        let now = Date()
        let doubleTap = lastArmyTap?.id == id && now.timeIntervalSince(lastArmyTap!.time) < 0.4
        lastArmyTap = (id, now)
        if a.owner == playerID && doubleTap {
            // Double-tap sur un pion : toutes nos armées du front avec lui.
            selectedArmy = id
            armyGroup = []
            groupFront()
            if !armyGroup.isEmpty { feedback = "Tout le front : \(armyGroup.count + 1) armées." }
            return
        }
        if a.owner == playerID {
            if selectedArmy == id {
                selectedArmy = nil
                armyGroup = []
            } else if let current = selectedArmy, s.state.armies.first(where: { $0.id == current })?.owner == playerID, !armyGroup.isEmpty {
                // Mode groupe : toucher une armée l'ajoute ou la retire.
                if armyGroup.contains(id) { armyGroup.remove(id) } else { armyGroup.insert(id) }
            } else {
                selectedArmy = id
                armyGroup = []
                selectedCountry = nil
                selectedProvince = nil
            }
            refreshSelection()
            return
        }
        if let current = selectedArmy, s.state.armies.first(where: { $0.id == current })?.owner == playerID,
           s.enemies(of: playerID ?? "").contains(a.owner) {
            orderSelected(to: a.province)
            return
        }
        selectedArmy = id
        armyGroup = []
        selectedCountry = nil
        selectedProvince = nil
        refreshSelection()
    }

    /// Ordre à l'armée sélectionnée et à tout son groupe.
    func orderSelected(to province: Int) {
        guard let lead = selectedArmy else { return }
        let ids = [lead] + armyGroup.sorted()
        if waypointMode || waypointLocked {
            perform { sim, _ in
                var last = ActionResult(success: false, message: "")
                for id in ids { last = sim.appendRoute(id, via: province) }
                return last
            }
            return
        }
        if ids.count == 1 {
            let r = perform { sim, _ in sim.orderArmy(lead, to: province) }
            // L'ordre est donné : l'armée se désélectionne (le trajet reste visible).
            if r.success {
                selectedArmy = nil
                armyGroup = []
                refreshUnits()
            }
            return
        }
        perform { sim, _ in
            var ok = 0
            var last = ActionResult(success: false, message: "")
            for id in ids {
                let r = sim.orderArmy(id, to: province)
                if r.success { ok += 1 } else { last = r }
            }
            if ok == 0 { return last }
            return ActionResult(success: true, message: "\(ok) armées en route vers \(ProvinceMap.all[province].name).")
        }
        selectedArmy = nil
        armyGroup = []
        refreshUnits()
    }

    /// Sélectionne en plus les armées voisines (même région ou régions adjacentes).
    func groupNearby() {
        guard let s = sim, let id = selectedArmy, let a = s.state.armies.first(where: { $0.id == id }), a.owner == playerID else { return }
        let around = Set(ProvinceMap.all[a.province].neighbors + [a.province])
        armyGroup = Set(s.state.armies.filter { $0.owner == a.owner && $0.id != id && around.contains($0.province) }.map { $0.id })
        refreshSelection()
    }

    /// Sélectionne toutes les armées du joueur placées sur le front.
    func groupFront() {
        guard let s = sim, let id = selectedArmy, let p = playerID else { return }
        let front = s.frontierProvinces(p, enemies: s.enemies(of: p))
        armyGroup = Set(s.state.armies.filter { $0.owner == p && $0.id != id && front.contains($0.province) }.map { $0.id })
        refreshSelection()
    }

    func clearGroup() {
        armyGroup = []
        refreshSelection()
    }

    /// Toucher la carte : sélectionne la région et affiche la fiche rapide de son propriétaire.
    func tapMap(_ point: GeoPoint) {
        guard let s = sim, let province = ProvinceMap.province(at: point) else {
            clearSelection()
            return
        }
        if let op = armyOp, let lead = selectedArmy {
            armyOp = nil
            let ids = [lead] + armyGroup.sorted()
            perform { sim, _ in
                switch op {
                case .bombard: return sim.bombard(province.id, from: lead)
                case .airdrop: return sim.airdrop(lead, to: province.id)
                case .encircle: return sim.encircle(province.id, with: ids)
                }
            }
            return
        }
        if let kind = placing {
            guard let p = playerID else { return }
            if let reason = s.canBuild(kind, at: province.id, for: p) {
                feedback = reason
                return
            }
            placing = nil
            selectedProvince = province.id
            selectedCountry = p
            perform { sim, p in sim.build(kind, at: province.id, for: p) }
            return
        }
        let here = s.playerArmies(in: province.id)
        // Une armée est sélectionnée : toucher une autre région = lui donner l'ordre d'y aller.
        if let armyID = selectedArmy {
            if let current = s.state.armies.first(where: { $0.id == armyID }), current.province == province.id {
                // Toucher la région de l'armée : passer à l'armée suivante ici, ou désélectionner.
                if let next = here.first(where: { $0.id > armyID }) ?? (here.count > 1 ? here.first : nil), next.id != armyID {
                    selectedArmy = next.id
                } else {
                    selectedArmy = nil
                }
                refreshSelection()
                return
            }
            if !here.isEmpty && s.state.armies.first(where: { $0.id == armyID })?.path.isEmpty == true
                && !(s.enemies(of: playerID ?? "").contains(s.controller(of: province.id))) {
                // On touche une autre armée à nous : on la sélectionne.
                selectedArmy = here[0].id
                refreshSelection()
                return
            }
            orderSelected(to: province.id)
            return
        }
        if let first = here.first {
            selectedArmy = first.id
            selectedCountry = nil
            selectedProvince = nil
            refreshSelection()
            return
        }
        selectedProvince = province.id
        let owner = s.provinceOwners()[province.id]?.owner
        selectedCountry = owner ?? province.country
        refreshSelection()
    }

    func clearSelection() {
        guard selectedProvince != nil || selectedCountry != nil || selectedArmy != nil else { return }
        selectedProvince = nil
        selectedCountry = nil
        selectedArmy = nil
        armyGroup = []
        waypointLocked = false
        refreshSelection()
    }

    func selectArmy(_ id: Int) {
        guard let s = sim, let a = s.state.armies.first(where: { $0.id == id }) else { return }
        selectedArmy = id
        armyGroup = []
        selectedCountry = nil
        selectedProvince = nil
        panel = nil
        let b = ProvinceMap.all[a.province].bounds
        focusCounter += 1
        focus = MapFocus(id: focusCounter, rect: b.insetBy(dx: -b.size.width * 3 - 300_000, dy: -b.size.height * 3 - 300_000))
        refreshSelection()
    }

    /// Centre la carte sur un pays (ses régions actuelles).
    func focusOn(_ id: CountryID) {
        guard let s = sim else { return }
        let owners = s.provinceOwners()
        var rect = MKMapRect.null
        for p in ProvinceMap.all where owners[p.id]?.owner == id {
            // On ignore les petits territoires lointains (îles, outre-mer) pour bien cadrer le pays.
            if p.weight < 3000 && !rect.isNull { continue }
            rect = rect.union(p.bounds)
        }
        if let core = ProvinceMap.byCountry[id], rect.isNull {
            for i in core { rect = rect.union(ProvinceMap.all[i].bounds) }
        }
        guard !rect.isNull else { return }
        // Un pays immense (Russie, États-Unis avec l'Alaska…) : on cadre sur sa plus grande région.
        if rect.size.width > MKMapRect.world.size.width * 0.45,
           let big = ProvinceMap.all.filter({ owners[$0.id]?.owner == id }).max(by: { $0.weight < $1.weight }) {
            rect = big.bounds.insetBy(dx: -big.bounds.size.width * 2, dy: -big.bounds.size.height * 2)
        }
        focusCounter += 1
        focus = MapFocus(id: focusCounter, rect: rect)
    }

    var selectedProvinceInfo: (Province, ProvinceOwner)? {
        guard let id = selectedProvince, let s = sim, ProvinceMap.all.indices.contains(id) else { return nil }
        let province = ProvinceMap.all[id]
        let owner = s.provinceOwners()[id] ?? ProvinceOwner(owner: province.country, status: .core)
        return (province, owner)
    }

    // MARK: - Sauvegarde

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("partie.json")
    }

    var hasSave: Bool { FileManager.default.fileExists(atPath: saveURL.path) }

    func save() {
        guard let data = try? sim?.saveData() else { return }
        do {
            try data.write(to: saveURL, options: .atomic)
            feedback = "Partie sauvegardée."
        } catch {
            feedback = "Sauvegarde impossible : \(error.localizedDescription)"
        }
    }

    func load() {
        do {
            let data = try Data(contentsOf: saveURL)
            mutationCount += 1
            sim = try Simulation(saveData: data)
            lastSeenEventID = (sim?.state.nextEventID ?? 1) - 1
            lastReportID = sim?.state.reports.last?.id ?? 0
            speed = 0
            version += 1
            refreshMap()
            startLoop()
        } catch {
            feedback = "Chargement impossible : la sauvegarde est illisible."
        }
    }
}
