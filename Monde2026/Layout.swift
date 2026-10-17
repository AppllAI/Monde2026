import SwiftUI

// =============================================================
//  Layout.swift
//  La disposition de l'écran de jeu, pensée pour jouer :
//   - une barre du haut minimale (pays, date, vitesse),
//   - à gauche, la fiche du pays touché (onglets : Aperçu,
//     Armée, Région) — tout est là sans chercher,
//   - à droite, les boutons de carte (batailles, modes, recentrer),
//   - en bas, 4 sections seulement (Économie, Armée, Diplomatie,
//     Politique) ; le détail est dans des onglets.
//   - le bouton ✋ pour tracer un trajet par étapes.
// =============================================================

// MARK: - Barre du haut

struct TopBar: View {
    @ObservedObject var store: GameStore
    let wide: Bool

    var body: some View {
        if let sim = store.sim, let player = store.player {
            HStack(spacing: 12) {
                Button { store.open(.country(player.id)) } label: {
                    HStack(spacing: 10) {
                        FlagBadge(id: player.id, size: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(player.name).font(Theme.title(17)).foregroundStyle(Theme.paper).lineLimit(1)
                            Text(sim.dateString).font(Theme.data(12)).foregroundStyle(Theme.steel)
                        }
                    }
                }
                .buttonStyle(.plain)
                if wide {
                    Divider().frame(height: 26).overlay(Theme.line)
                    MiniStat(icon: "banknote", value: Fmt.money(sim.effectiveGDP(player.id)),
                             tint: player.growth >= 0 ? Theme.paper : Theme.coral)
                    MiniStat(icon: "person.3.fill", value: Fmt.pct(player.stability, 0),
                             tint: player.stability < 0.35 ? Theme.coral : Theme.paper)
                    MiniStat(icon: "shield.lefthalf.filled", value: "\(player.divisionCount)", tint: Theme.paper)
                    if sim.isAtWar(player.id) {
                        MiniStat(icon: "flame.fill", value: "En guerre", tint: Theme.coral)
                    }
                }
                Spacer(minLength: 4)
                SpeedControl(store: store)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { store.mapTray.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: store.mapMode.icon).font(.system(size: 13, weight: .semibold))
                        if wide { Text("Carte").font(.system(size: 13, weight: .semibold)) }
                    }
                    .foregroundStyle(store.mapTray ? Theme.ink : Theme.paper)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(store.mapTray ? Theme.amber : Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(Pressable())
                .accessibilityLabel("Changer de carte")
                GameMenu(store: store)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glass(22)
        }
    }
}

struct MiniStat: View {
    let icon: String
    let value: String
    var tint: Color = Theme.paper

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Theme.steel)
            Text(value).font(Theme.data(13, weight: .semibold)).foregroundStyle(tint).lineLimit(1)
        }
    }
}

// MARK: - Boutons de carte (à droite)

struct MapControls: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            if let sim = store.sim {
                let battles = sim.playerBattles()
                if !battles.isEmpty {
                    Button { store.openBattle(battles[0].province) } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "flame.fill").font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.coral)
                                .frame(width: 48, height: 48)
                                .glass(24)
                            Text("\(battles.count)").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Theme.coral, in: Capsule())
                                .offset(x: 4, y: -4)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Batailles en cours : \(battles.count)")
                }
            }
            round("location.fill", "Centrer sur mon pays") {
                if let p = store.playerID { store.focusOn(p) }
            }
            round(store.satellite ? "map" : "globe.europe.africa.fill", "Changer le fond de carte") {
                store.satellite.toggle()
            }
        }
    }

    private func round(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .frame(width: 48, height: 48)
                .glass(24)
        }
        .buttonStyle(Pressable())
        .accessibilityLabel(label)
    }
}

// MARK: - Bouton ✋ : trajet par étapes

/// Garder le pouce dessus et toucher des régions avec l'autre main = chaque région devient une étape.
/// Toucher le cadenas = garder le mode actif sans tenir le bouton.
struct WaypointHandle: View {
    @ObservedObject var store: GameStore

    var body: some View {
        let active = store.waypointMode || store.waypointLocked
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(active ? Theme.ink : Theme.paper)
                .frame(width: 68, height: 68)
                .background(active ? Theme.amber : Color.clear, in: Circle())
                .glass(34)
                .onLongPressGesture(minimumDuration: 0.05, maximumDistance: 60, pressing: { pressing in
                    store.waypointMode = pressing
                }, perform: {})
                .accessibilityLabel("Maintenir pour ajouter des étapes")
            Button {
                store.waypointLocked.toggle()
            } label: {
                Image(systemName: store.waypointLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.waypointLocked ? Theme.amber : Theme.steel)
                    .frame(width: 36, height: 36)
                    .glass(18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Verrouiller le mode étapes")
            Text("Étapes").font(.system(size: 10, weight: .semibold)).foregroundStyle(active ? Theme.amber : Theme.steel)
        }
        .sensoryFeedback(.selection, trigger: store.waypointMode)
    }
}

// MARK: - Les 4 sections du bas

enum GameSection: CaseIterable {
    case economy, military, diplomacy, politics

    var title: String {
        switch self {
        case .economy: return "Économie"
        case .military: return "Armée"
        case .diplomacy: return "Diplomatie"
        case .politics: return "Politique"
        }
    }

    var icon: String {
        switch self {
        case .economy: return "chart.bar.xaxis"
        case .military: return "shield.lefthalf.filled"
        case .diplomacy: return "globe.europe.africa"
        case .politics: return "building.columns"
        }
    }

    /// Onglets de la section, dans l'ordre.
    var tabs: [(String, Panel)] {
        switch self {
        case .economy: return [("Économie", .economy), ("Industrie", .production), ("Recherche", .research), ("Projets", .projects)]
        case .military: return [("Armée", .military)]
        case .diplomacy: return [("Diplomatie", .diplomacy), ("Monde", .world)]
        case .politics: return [("Politique", .politics)]
        }
    }

    static func of(_ panel: Panel) -> GameSection? {
        allCases.first { s in s.tabs.contains { $0.1 == panel } }
    }
}

struct SectionDock: View {
    @ObservedObject var store: GameStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GameSection.allCases, id: \.self) { section in
                Button {
                    if let current = store.panel, GameSection.of(current) == section { store.panel = nil } else { store.open(section.tabs[0].1) }
                } label: {
                    HStack(spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: section.icon).font(.system(size: 17, weight: .medium))
                            if section == .diplomacy && inboxCount > 0 {
                                Circle().fill(Theme.amber).frame(width: 8, height: 8).offset(x: 4, y: -3)
                            }
                            if section == .military && atWar {
                                Circle().fill(Theme.coral).frame(width: 8, height: 8).offset(x: 4, y: -3)
                            }
                        }
                        Text(section.title).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isOpen(section) ? Theme.ink : Theme.paper)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(isOpen(section) ? Theme.amber : Color.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(Pressable())
            }
        }
        .padding(4)
        .glass(26)
        .frame(maxWidth: 640)
    }

    private func isOpen(_ section: GameSection) -> Bool {
        guard let p = store.panel else { return false }
        return GameSection.of(p) == section
    }

    private var inboxCount: Int {
        guard let sim = store.sim, let p = store.playerID else { return 0 }
        return sim.state.proposals.filter { $0.to == p }.count
    }

    private var atWar: Bool {
        guard let sim = store.sim, let p = store.playerID else { return false }
        return sim.isAtWar(p)
    }
}

/// Onglets en haut des panneaux d'une même section.
struct SectionTabs: View {
    @ObservedObject var store: GameStore
    let panel: Panel

    var body: some View {
        if let section = GameSection.of(panel), section.tabs.count > 1 {
            HStack(spacing: 4) {
                ForEach(section.tabs, id: \.0) { tab in
                    Button { withAnimation(.snappy) { store.panel = tab.1 } } label: {
                        Text(tab.0).font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .foregroundStyle(panel == tab.1 ? Theme.ink : Theme.paper)
                            .background(panel == tab.1 ? Theme.paper : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
    }
}

// MARK: - Fiche du pays (à gauche)

struct CountrySidebar: View {
    @ObservedObject var store: GameStore
    @State private var tab = 0

    var body: some View {
        if let sim = store.sim, let id = store.selectedCountry {
            let country = sim.state.countries[id]
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(country != nil ? Geo.flag(id) : "🏳️").font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(country?.name ?? store.selectedProvinceInfo?.0.countryName ?? id)
                            .font(Theme.title(20)).foregroundStyle(Theme.paper).lineLimit(1)
                        if let c = country {
                            Text("\(c.government.name) · \(relationText(sim, id))").font(Theme.small)
                                .foregroundStyle(Theme.steel).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    Button { store.clearSelection() } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer")
                }
                if country != nil {
                    Picker("", selection: $tab) {
                        Text("Aperçu").tag(0)
                        Text("Armée").tag(1)
                        Text("Région").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        if let c = country {
                            switch tab {
                            case 0: overview(sim, c)
                            case 1: military(sim, c)
                            default: region(sim)
                            }
                        } else {
                            Text("Territoire neutre : ce pays n'est pas jouable dans cette version.")
                                .font(Theme.small).foregroundStyle(Theme.steel)
                            region(sim)
                        }
                    }
                }
            }
            .padding(14)
            .glass(24)
            .onChange(of: store.selectedCountry) { _, _ in
                if store.selectedCountry == store.playerID && store.selectedProvince != nil { tab = 2 }
            }
        }
    }

    private func relationText(_ sim: Simulation, _ id: CountryID) -> String {
        guard let p = store.playerID else { return "" }
        if id == p { return "Votre pays" }
        if sim.enemies(of: p).contains(id) { return "En guerre contre vous" }
        if sim.allies(of: p).contains(id) { return "Allié" }
        let r = sim.relation(p, id)
        if r > 40 { return "Ami" }
        if r < -40 { return "Hostile" }
        return "Neutre"
    }

    // Aperçu : l'essentiel en 6 chiffres + actions
    @ViewBuilder
    private func overview(_ sim: Simulation, _ c: Country) -> some View {
        let gdp = sim.effectiveGDP(c.id)
        FigureGrid(items: [
            ("PIB", Fmt.money(gdp), Theme.paper),
            ("Croissance", Fmt.signedPct(c.growth), c.growth >= 0 ? Theme.teal : Theme.coral),
            ("Stabilité", Fmt.pct(c.stability, 0), c.stability < 0.35 ? Theme.coral : Theme.paper),
            ("Dette", Fmt.pct(c.debt / max(gdp, 1), 0), c.debt / max(gdp, 1) > 1 ? Theme.coral : Theme.paper),
            ("Population", Fmt.population(c.population), Theme.paper),
            ("Influence", Fmt.number(c.influence), Theme.amber)
        ], columns: 3)
        if let p = store.playerID, p != c.id {
            let r = sim.relation(p, c.id)
            VStack(alignment: .leading, spacing: 4) {
                Text("Relation avec vous : \(Fmt.number(r))").font(Theme.small).foregroundStyle(Theme.steel)
                RelationScale(value: r)
            }
        }
        let wars = sim.wars(of: c.id)
        if !wars.isEmpty {
            Label(wars.map { $0.name }.joined(separator: ", "), systemImage: "flame.fill")
                .font(Theme.small).foregroundStyle(Theme.coral).lineLimit(2)
        } else if let bloc = sim.faction(of: c.id) {
            Label("Membre de \(bloc.name)", systemImage: "shield.lefthalf.filled")
                .font(Theme.small).foregroundStyle(Theme.steel)
        }
        HStack(spacing: 8) {
            if c.id == store.playerID {
                ActionButton(title: "Gérer mon pays", icon: "slider.horizontal.3") { store.open(.economy) }
            } else {
                ActionButton(title: "Diplomatie", icon: "hand.raised") { store.open(.country(c.id)) }
            }
            Button { store.focusOn(c.id) } label: {
                Image(systemName: "scope").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 46, height: 44)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Centrer sur ce pays")
        }
    }

    // Armée : ce que nos services savent
    @ViewBuilder
    private func military(_ sim: Simulation, _ c: Country) -> some View {
        let intel = sim.intel(on: c.id)
        let near = sim.armiesNearPlayer(of: c.id)
        VStack(alignment: .leading, spacing: 4) {
            Label(intel.exact ? "Renseignement complet" : "Estimations de nos services (précision \(Int(intel.precision * 100)) %)",
                  systemImage: intel.exact ? "checkmark.seal.fill" : "eye")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(intel.exact ? Theme.teal : Theme.amber)
        }
        FigureGrid(items: [
            ("Divisions", intel.divisions, Theme.paper),
            ("Armées formées", intel.armies, Theme.paper),
            ("Près de vos frontières", near > 0 ? "\(near) armées" : "aucune", near > 0 ? Theme.coral : Theme.teal),
            ("Aviation", intel.air, Theme.paper),
            ("Marine", intel.navy, Theme.paper),
            ("Bases / forts", "\(sim.bases(of: c.id).count) / \(sim.fortCount(c.id))", Theme.paper)
        ], columns: 2)
        if c.nuclearWarheads > 0 {
            Label("Puissance nucléaire", systemImage: "atom").font(Theme.small).foregroundStyle(Theme.coral)
        }
        if c.id != store.playerID {
            Text("Vos services de renseignement (Politique) améliorent la précision.").font(.system(size: 10)).foregroundStyle(Theme.steel)
        }
    }

    // Région : terrain, défenses, chantiers
    @ViewBuilder
    private func region(_ sim: Simulation) -> some View {
        if let id = store.selectedProvince {
            RegionDetail(store: store, sim: sim, province: id)
        } else {
            Text("Touchez une région sur la carte pour voir son terrain, ses défenses et y construire.")
                .font(Theme.small).foregroundStyle(Theme.steel)
        }
    }
}

struct RegionDetail: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let province: Int

    var body: some View {
        let p = ProvinceMap.all[province]
        let terrain = TerrainMap.terrain(province)
        let weather = sim.weather(at: province)
        let holder = sim.controller(of: province)
        let mine = holder == store.playerID
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(p.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                if holder != p.country { Tag(icon: "flag.fill", text: "Tenue par \(sim.name(holder))", tint: Theme.coral) }
            }
            HStack(spacing: 6) {
                Tag(icon: terrain.icon, text: terrain.name)
                if weather != .clear { Tag(icon: weather.icon, text: weather.name, tint: Theme.amber) }
            }
            Text(terrainHint(terrain)).font(.system(size: 11)).foregroundStyle(Theme.steel)
            HStack(spacing: 10) {
                defenseTile("Fort", sim.fortLevel(province) > 0 ? "niveau \(sim.fortLevel(province))" : "aucun",
                            "building.columns.fill", sim.fortLevel(province) > 0)
                defenseTile("Base", sim.state.bases.contains(province) ? "oui" : "non",
                            "star.square.fill", sim.state.bases.contains(province))
            }
            let here = sim.state.armies.filter { $0.province == province }
            if !here.isEmpty {
                ForEach(here.prefix(4)) { a in
                    Button { store.tapArmy(a.id) } label: {
                        HStack(spacing: 8) {
                            UnitSymbol(type: a.mainType, color: Color(uiColor: Theme.politicalColor(a.owner)), size: 24)
                            Text(a.owner == store.playerID ? "\(a.name) · \(a.count) div." : "\(Geo.flag(a.owner)) Armée · \(a.count) div.")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.paper)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if let job = sim.construction(at: province) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chantier : \(job.kind == .fort ? "fort" : "base") — encore \(job.daysLeft) j")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber)
                    Meter(value: job.progress, tint: Theme.amber)
                }
            }
            RegionIndustry(store: store, sim: sim, province: province)
            if mine, let pid = store.playerID {
                VStack(spacing: 8) {
                    buildButton(.fort, pid)
                    buildButton(.base, pid)
                }
            }
        }
    }

    private func terrainHint(_ t: Terrain) -> String {
        "Attaque ici : \(Int((t.attack - 1) * 100)) %. Blindés : \(t.armor >= 1 ? "+" : "")\(Int(((t.armor - 1) * 100).rounded())) %. Déplacement : \(Int(t.movement * 100)) %."
    }

    private func defenseTile(_ title: String, _ value: String, _ icon: String, _ on: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(on ? Theme.amber : Theme.steel)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                Text(title).font(.system(size: 10)).foregroundStyle(Theme.steel)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func buildButton(_ kind: BuildingKind, _ pid: CountryID) -> some View {
        let blocked = sim.canBuild(kind, at: province, for: pid)
        let (cost, days) = sim.buildCost(kind, at: province, for: pid)
        let title = kind == .fort ? (sim.fortLevel(province) > 0 ? "Renforcer le fort" : "Construire un fort") : "Construire une base"
        if blocked == nil {
            Button {
                store.perform { s, p in s.build(kind, at: province, for: p) }
            } label: {
                HStack {
                    Image(systemName: kind.icon)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 14, weight: .semibold))
                        Text(kind == .fort ? "+15 % de défense par niveau" : "Entraînement ×2, ravitaillement, garnison")
                            .font(.system(size: 10)).opacity(0.8)
                    }
                    Spacer()
                    Text("\(Fmt.money(cost)) · \(days) j").font(Theme.data(12, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .padding(12)
                .background(Theme.amber, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        } else if kind == .fort || !sim.state.bases.contains(province) {
            Text("\(title) : \(blocked ?? "")").font(.system(size: 11)).foregroundStyle(Theme.steel)
        }
    }
}

// MARK: - Renseignement

extension Simulation {

    struct IntelReport {
        let exact: Bool
        let precision: Double
        let divisions: String
        let armies: String
        let air: String
        let navy: String
    }

    func intel(on id: CountryID) -> IntelReport {
        guard let c = state.countries[id] else {
            return IntelReport(exact: false, precision: 0, divisions: "?", armies: "?", air: "?", navy: "?")
        }
        let p = state.playerID
        let mine = p == id
        let allied = p.map { allies(of: $0).contains(id) } ?? false
        let skill = p.flatMap { state.countries[$0]?.intelligence } ?? 0.4
        let exact = mine || allied || skill >= 0.8
        let precision = exact ? 1 : (0.35 + 0.65 * skill).clamped(0.3, 0.95)
        func show(_ v: Double) -> String {
            if exact { return Fmt.number(v) }
            let spread = v * (1 - precision)
            // Fourchette stable (sans hasard) arrondie, pour ne pas trahir la vraie valeur.
            let low = max(0, (v - spread * 0.8) / 5).rounded(.down) * 5
            let high = ((v + spread * 1.1) / 5).rounded(.up) * 5
            return low == high ? "≈ \(Fmt.number(v))" : "\(Fmt.number(low))–\(Fmt.number(high))"
        }
        return IntelReport(exact: exact, precision: precision,
                           divisions: show(Double(c.divisionCount)),
                           armies: exact ? "\(armies(of: id).count)" : "≈ \(armies(of: id).count)",
                           air: show(c.stock(.fighter)) + " avions",
                           navy: show(c.stock(.warship) + c.stock(.submarine)) + " navires")
    }

    /// Armées de ce pays posées sur nos frontières (ou dedans).
    func armiesNearPlayer(of id: CountryID) -> Int {
        guard let p = state.playerID, id != p else { return 0 }
        var near = Set<Int>()
        for prov in provincesControlled(by: p) {
            near.insert(prov)
            for n in ProvinceMap.all[prov].neighbors { near.insert(n) }
        }
        return state.armies.filter { $0.owner == id && near.contains($0.province) }.count
    }

    func fortCount(_ id: CountryID) -> Int {
        state.forts.keys.filter { controller(of: $0) == id }.count
    }
}


// MARK: - Effet d'appui (tout bouton réagit sous le doigt)

struct Pressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Sélecteur de cartes (en haut à droite)

/// S'ouvre sous le bouton « Carte » ; reste ouvert jusqu'à ce qu'on retouche le bouton ou la croix.
/// Trois cartes visibles à la fois, on fait défiler pour les autres.
struct MapTray: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cartes").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.steel)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { store.mapTray = false }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.paper)
                        .frame(width: 26, height: 26).background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(Pressable())
                .accessibilityLabel("Fermer le sélecteur de cartes")
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MapMode.allCases) { mode in
                            let on = store.mapMode == mode
                            Button {
                                withAnimation(.snappy) { store.mapMode = mode }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.icon).font(.system(size: 18, weight: .semibold))
                                    Text(mode.rawValue).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                }
                                .foregroundStyle(on ? Theme.ink : Theme.paper)
                                .frame(width: 96, height: 62)
                                .background(on ? Theme.amber : Color.white.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(Pressable())
                            .id(mode)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(store.mapMode, anchor: .center) }
            }
            .frame(width: 3 * 96 + 2 * 8 + 10)
            LegendRow(mode: store.mapMode)
        }
        .padding(12)
        .frame(width: 3 * 96 + 2 * 8 + 10 + 24)
        .glass(20)
        .sensoryFeedback(.selection, trigger: store.mapMode)
    }
}

/// Légende du mode de carte, en une ou deux lignes.
struct LegendRow: View {
    let mode: MapMode

    var body: some View {
        let items = entries
        FlowLayout(spacing: 8) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(items[i].0).frame(width: 12, height: 9)
                    Text(items[i].1).font(.system(size: 10.5)).foregroundStyle(Theme.paper.opacity(0.85))
                }
            }
        }
        .frame(width: 3 * 96 + 2 * 8 + 10, alignment: .leading)
    }

    private var entries: [(Color, String)] {
        switch mode {
        case .political: return [(Theme.coral, "Front"), (Theme.amber, "Vos frontières"), (Color(uiColor: Theme.rebelLand), "Rebelles")]
        case .relations: return [(Theme.teal, "Amis"), (Theme.steel, "Neutres"), (Theme.coral, "Hostiles")]
        case .trade: return [(Theme.teal, "Accord commercial"), (Theme.sky, "Bonnes relations"), (Theme.coral, "Sanctions")]
        case .conflicts: return [(Theme.teal, "Votre camp"), (Theme.coral, "Vos ennemis"),
                                 (Color(red: 0.93, green: 0.55, blue: 0.22), "Autres guerres")]
        case .allies: return [(Theme.teal, "Alliés"), (Theme.sky, "Garanties"), (Theme.steel, "Non-agression"), (Theme.coral, "Ennemis")]
        case .alliances: return [(Theme.blocColor("OTAN"), "OTAN"), (Theme.blocColor("OTSC"), "OTSC"),
                                 (Theme.blocColor("USA-ALLY"), "Alliés US"), (Theme.blocColor("CHN-ALLY"), "Proches Pékin/Moscou")]
        case .economy: return [(Theme.teal, "Croissance"), (Theme.steel, "Stagnation"), (Theme.coral, "Récession")]
        case .military: return [(Theme.amber, "Puissante"), (Theme.steel, "Faible"), (Theme.coral, "En guerre")]
        case .industry: return [(Color(red: 0.42, green: 0.80, blue: 0.95), "Régions industrielles"), (Theme.steel.opacity(0.5), "Sans usines")]
        case .terrain: return Terrain.allCases.map { t in (Color(red: t.rgb.0, green: t.rgb.1, blue: t.rgb.2), t.name) }
        }
    }
}

/// Disposition en lignes qui passent à la ligne quand il n'y a plus de place.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { x = 0; y += row + 6; row = 0 }
            x += s.width + spacing
            row = max(row, s.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += row + 6; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}

// MARK: - Bandeau du mode placement

struct PlacementBanner: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let kind = store.placing {
            HStack(spacing: 12) {
                Image(systemName: kind.icon).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Color(red: kind.rgb.0, green: kind.rgb.1, blue: kind.rgb.2), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Où construire : \(kind.name) ?").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text("Touchez une région en surbrillance.").font(.system(size: 11)).foregroundStyle(Theme.steel)
                }
                Spacer(minLength: 8)
                if let sim = store.sim, let p = store.playerID, let best = sim.suggestedRegion(for: kind, id: p) {
                    Button("Au mieux") {
                        store.placing = nil
                        store.perform { s, p in s.build(kind, at: best, for: p) }
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.amber)
                }
                Button { store.placing = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.paper)
                        .frame(width: 30, height: 30).background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(Pressable())
            }
            .padding(12)
            .frame(maxWidth: 520)
            .glass(20)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
