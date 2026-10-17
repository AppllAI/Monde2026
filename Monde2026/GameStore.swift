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
        }
    }
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
    @Published private(set) var mapSnapshot = MapSnapshot.empty
    @Published private(set) var unitsSnapshot = UnitsSnapshot.empty
    private var territorySignature = 0
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

    private var lastSeenEventID = 0
    private var loop: Task<Void, Never>?

    var playerID: CountryID? { sim?.state.playerID }
    var player: Country? { playerID.flatMap { sim?.state.countries[$0] } }
    var hasGame: Bool { sim != nil }

    // MARK: - Partie

    func newGame(as id: CountryID, difficulty: Difficulty = .normal) {
        sim = Simulation(playerID: id, difficulty: difficulty)
        lastSeenEventID = (sim?.state.nextEventID ?? 1) - 1
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
        sim = nil
        panel = nil
        version += 1
    }

    private func startLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let delay = self?.delay ?? 300_000_000
                try? await Task.sleep(nanoseconds: delay)
                guard let self else { return }
                if self.speed > 0 && self.panel?.isModal != true {
                    self.step(days: self.speed == 3 ? 2 : 1)
                }
            }
        }
    }

    private var delay: UInt64 {
        switch speed {
        case 1: return 700_000_000
        case 2: return 250_000_000
        case 3: return 90_000_000
        default: return 300_000_000
        }
    }

    func step(days: Int = 1) {
        guard sim != nil else { return }
        let before = sim!.state.day
        sim!.advance(days: days)
        version += 1
        // La carte ne se redessine que tous les 5 jours (et au changement de mois) : c'est ce qui garde la fluidité.
        _ = before
        // Les unités bougent à chaque jour (léger) ; la carte des régions seulement si le territoire change.
        refreshUnits()
        let signature = territoryHash()
        if signature != territorySignature || Simulation.calendar.component(.day, from: sim!.currentDate) == 1 {
            territorySignature = signature
            refreshMap()
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
            armyGroup = armyGroup.intersection(alive)
        }
        collectEvents()
        presentUrgent()
        if let unlocked = sim?.state.achievements, !unlocked.isEmpty {
            AchievementStore.merge(unlocked)
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
        body(&sim!)
        version += 1
        refreshMap()
        collectEvents()
    }

    /// Action diplomatique avec message de retour.
    @discardableResult
    func perform(_ body: (inout Simulation, CountryID) -> ActionResult) -> ActionResult {
        guard sim != nil, let p = playerID else { return ActionResult(success: false, message: "") }
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

    /// Durée du glissement des pions : celle d'un jour de jeu à la vitesse choisie.
    var unitAnimation: TimeInterval {
        switch speed {
        case 1: return 0.65
        case 2: return 0.24
        case 3: return 0.09
        default: return 0.3
        }
    }

    func refreshUnits() {
        guard let s = sim else { unitsSnapshot = .empty; return }
        unitsSnapshot = UnitsBuilder.build(s, selectedArmy: selectedArmy, group: armyGroup)
    }

    /// Empreinte de ce qui change la couleur des régions (contrôle, guerres, traités, chantiers).
    private func territoryHash() -> Int {
        guard let s = sim else { return 0 }
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

    func refreshMap() {
        refreshUnits()
        guard let s = sim else {
            mapSnapshot = .empty
            return
        }
        var selected = selectedCountry
        if case .country(let id)? = panel { selected = id }
        var highlight: Set<Int> = []
        if let kind = placing, let p = playerID {
            highlight = Set((ProvinceMap.byCountry[p] ?? []).filter { s.canBuild(kind, at: $0, for: p) == nil })
        }
        mapSnapshot = MapSnapshotBuilder.build(s, mode: mapMode, selected: selected, selectedProvince: selectedProvince,
                                               selectedArmy: selectedArmy, group: armyGroup, highlight: highlight)
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
            refreshMap()
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
        refreshMap()
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
        refreshMap()
    }

    /// Sélectionne toutes les armées du joueur placées sur le front.
    func groupFront() {
        guard let s = sim, let id = selectedArmy, let p = playerID else { return }
        let front = s.frontierProvinces(p, enemies: s.enemies(of: p))
        armyGroup = Set(s.state.armies.filter { $0.owner == p && $0.id != id && front.contains($0.province) }.map { $0.id })
        refreshMap()
    }

    func clearGroup() {
        armyGroup = []
        refreshMap()
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
                refreshMap()
                return
            }
            if !here.isEmpty && s.state.armies.first(where: { $0.id == armyID })?.path.isEmpty == true
                && !(s.enemies(of: playerID ?? "").contains(s.controller(of: province.id))) {
                // On touche une autre armée à nous : on la sélectionne.
                selectedArmy = here[0].id
                refreshMap()
                return
            }
            orderSelected(to: province.id)
            return
        }
        if let first = here.first {
            selectedArmy = first.id
            selectedCountry = nil
            selectedProvince = nil
            refreshMap()
            return
        }
        selectedProvince = province.id
        let owner = s.provinceOwners()[province.id]?.owner
        selectedCountry = owner ?? province.country
        refreshMap()
    }

    func clearSelection() {
        guard selectedProvince != nil || selectedCountry != nil || selectedArmy != nil else { return }
        selectedProvince = nil
        selectedCountry = nil
        selectedArmy = nil
        armyGroup = []
        waypointLocked = false
        refreshMap()
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
        refreshMap()
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
            sim = try Simulation(saveData: data)
            lastSeenEventID = (sim?.state.nextEventID ?? 1) - 1
            speed = 0
            version += 1
            refreshMap()
            startLoop()
        } catch {
            feedback = "Chargement impossible : la sauvegarde est illisible."
        }
    }
}
