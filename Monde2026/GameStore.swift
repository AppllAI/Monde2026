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
        }
    }

    /// Panneau qui laisse le temps s'écouler (on regarde la bataille se dérouler).
    var isLive: Bool {
        if case .battle = self { return true }
        return false
    }
}

enum MapMode: String, CaseIterable, Identifiable {
    case political = "Pays"
    case alliances = "Factions"
    case relations = "Relations"
    case economy = "Économie"
    case military = "Armées"
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
    @Published var selectedProvince: Int?
    @Published var selectedCountry: CountryID?
    @Published var selectedArmy: Int?
    @Published var armyGroup: Set<Int> = []    // armées commandées avec l'armée sélectionnée
    @Published private(set) var focus: MapFocus?
    private var focusCounter = 0
    @Published var satellite = false
    @Published var toasts: [GameEvent] = []
    @Published var feedback: String?
    @Published var autoPause = true

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
                if self.speed > 0 && (self.panel == nil || self.panel?.isLive == true) {
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
        let after = sim!.state.day
        let armiesActive = sim!.state.armies.contains { !$0.path.isEmpty }
        if after / 5 != before / 5 || Simulation.calendar.component(.day, from: sim!.currentDate) == 1
            || (armiesActive && after / 2 != before / 2) {
            refreshMap()
        }
        if let id = selectedArmy, !(sim!.state.armies.contains { $0.id == id }) {
            selectedArmy = nil
            armyGroup = []
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
        toasts.append(contentsOf: fresh.suffix(3))
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        if autoPause { speed = 0 }
        for event in fresh.suffix(3) {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
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
    func perform(_ body: (inout Simulation, CountryID) -> ActionResult) {
        guard sim != nil, let p = playerID else { return }
        let result = body(&sim!, p)
        feedback = result.message
        version += 1
        refreshMap()
        collectEvents()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if self?.feedback == result.message { self?.feedback = nil }
        }
    }

    func open(_ p: Panel) {
        panel = p
        refreshMap()
    }

    // MARK: - Carte

    func refreshMap() {
        guard let s = sim else {
            mapSnapshot = .empty
            return
        }
        var selected = selectedCountry
        if case .country(let id)? = panel { selected = id }
        mapSnapshot = MapSnapshotBuilder.build(s, mode: mapMode, selected: selected, selectedProvince: selectedProvince,
                                               selectedArmy: selectedArmy, group: armyGroup)
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
        if ids.count == 1 {
            perform { sim, _ in sim.orderArmy(lead, to: province) }
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
