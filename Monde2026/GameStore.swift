import SwiftUI

// =============================================================
//  GameStore.swift
//  Relie le moteur à l'interface : horloge en temps réel,
//  vitesse, sélection, panneaux, notifications, sauvegarde.
// =============================================================

enum Panel: Identifiable, Hashable {
    case economy, military, production, diplomacy, world, politics, research, endGame
    case country(CountryID)
    case event(Int)

    var id: String {
        switch self {
        case .economy: return "economy"
        case .military: return "military"
        case .production: return "production"
        case .diplomacy: return "diplomacy"
        case .world: return "world"
        case .politics: return "politics"
        case .research: return "research"
        case .endGame: return "endGame"
        case .country(let c): return "country-" + c
        case .event(let e): return "event-\(e)"
        }
    }
}

enum MapMode: String, CaseIterable, Identifiable {
    case political = "Pays"
    case alliances = "Factions"
    case relations = "Relations"
    case economy = "Économie"
    case military = "Armées"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .political: return "globe.europe.africa"
        case .alliances: return "shield.lefthalf.filled"
        case .relations: return "hand.raised"
        case .economy: return "chart.line.uptrend.xyaxis"
        case .military: return "scope"
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
        version += 1
        refreshMap()
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
                if self.speed > 0 && self.panel == nil {
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
        if after / 5 != before / 5 || Simulation.calendar.component(.day, from: sim!.currentDate) == 1 {
            refreshMap()
        }
        collectEvents()
        presentUrgent()
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
        var selected: CountryID?
        if case .country(let id)? = panel { selected = id }
        mapSnapshot = MapSnapshotBuilder.build(s, mode: mapMode, selected: selected, selectedProvince: selectedProvince)
    }

    /// Toucher la carte : sélectionne la région et ouvre la fiche de son propriétaire.
    func tapMap(_ point: GeoPoint) {
        guard let s = sim, let province = ProvinceMap.province(at: point) else {
            selectedProvince = nil
            refreshMap()
            return
        }
        selectedProvince = province.id
        let owner = s.provinceOwners()[province.id]?.owner
        open(.country(owner ?? province.country))
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
