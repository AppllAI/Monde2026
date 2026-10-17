import SwiftUI

// =============================================================
//  GameView.swift
//  L'écran de jeu : la carte en plein écran, la barre de
//  commandement en haut, le dock des panneaux en bas.
// =============================================================

struct GameView: View {
    @ObservedObject var store: GameStore
    @AppStorage("tutorialSeen") private var tutorialSeen = false

    @State private var wideLayout = true

    private let spring = Animation.spring(response: 0.38, dampingFraction: 0.86)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 700
            ZStack(alignment: .trailing) {
                WorldMapView(snapshot: store.mapSnapshot, satellite: store.satellite, focus: store.focus) { tap in
                    store.handleTap(tap)
                }
                .equatable()
                .ignoresSafeArea()
                VStack(spacing: 10) {
                    TopBar(store: store, wide: wide)
                    HStack(alignment: .top, spacing: 10) {
                        if wide && store.selectedCountry != nil && store.selectedArmy == nil && store.placing == nil {
                            CountrySidebar(store: store)
                                .frame(width: 350)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 10) {
                            if store.mapTray {
                                MapTray(store: store)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity),
                                                            removal: .opacity))
                            }
                            NoticeStack(store: store)
                                .frame(maxWidth: wide ? 360 : .infinity)
                            MapControls(store: store)
                        }
                    }
                    PlacementBanner(store: store)
                    Spacer(minLength: 0)
                    if store.selectedArmy != nil {
                        ArmyCard(store: store)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !wide && store.selectedCountry != nil {
                        CountrySidebar(store: store)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    SectionDock(store: store)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                if store.selectedArmy != nil {
                    HStack {
                        WaypointHandle(store: store)
                            .padding(.leading, 14)
                        Spacer()
                    }
                    .transition(.opacity)
                }
                // Sur iPad : les panneaux glissent depuis la droite, la carte reste visible et vivante.
                if wide, let panel = store.panel, !panel.isModal {
                    Color.black.opacity(0.18).ignoresSafeArea()
                        .onTapGesture { withAnimation(spring) { store.panel = nil } }
                        .transition(.opacity)
                    PanelDrawer(store: store, panel: panel)
                        .frame(width: min(540, geo.size.width * 0.5))
                        .transition(.move(edge: .trailing))
                        .id(GameSection.of(panel).map { "\($0)" } ?? panel.id)
                }
                if !tutorialSeen {
                    TutorialOverlay { tutorialSeen = true }
                }
            }
            .animation(spring, value: store.selectedCountry)
            .animation(spring, value: store.selectedArmy)
            .animation(spring, value: store.panel)
            .animation(spring, value: store.placing)
            .animation(spring, value: store.mapTray)
            .onAppear { wideLayout = wide }
            .onChange(of: wide) { _, w in wideLayout = w }
        }
        .sheet(item: sheetBinding, onDismiss: { store.presentUrgent() }) { panel in
            PanelHost(store: store, panel: panel)
                .presentationDetents(panel.isLive ? [.medium, .large] : [.large, .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.ink.opacity(0.96))
                .presentationCornerRadius(28)
        }
    }

    /// Sur iPad, seuls les panneaux « décision » (événement, fin de partie) s'ouvrent en feuille.
    private var sheetBinding: Binding<Panel?> {
        Binding(get: {
            guard let p = store.panel else { return nil }
            return (wideLayout && !p.isModal) ? nil : p
        }, set: { value in
            if value == nil, let p = store.panel, !(wideLayout && !p.isModal) { store.panel = nil }
        })
    }
}

/// Panneau latéral (iPad) : glisse depuis la droite, se ferme d'un geste vers la droite.
struct PanelDrawer: View {
    @ObservedObject var store: GameStore
    let panel: Panel
    @State private var drag: CGFloat = 0

    var body: some View {
        PanelHost(store: store, panel: panel)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.ink.opacity(0.97))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.line))
            .overlay(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 5, height: 46).padding(.leading, 6)
            }
            .shadow(color: .black.opacity(0.45), radius: 24, x: -6)
            .padding(.top, 70)
            .padding(.bottom, 74)
            .padding(.trailing, 12)
            .offset(x: max(0, drag))
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { v in if abs(v.translation.width) > abs(v.translation.height) { drag = v.translation.width } }
                    .onEnded { v in
                        if v.translation.width > 120 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { store.panel = nil }
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = 0 }
                    }
            )
    }
}

// MARK: - Barre de commandement

struct CommandBar: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let player = store.player {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button { store.open(.country(player.id)) } label: {
                        HStack(spacing: 10) {
                            FlagBadge(id: player.id, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(player.name).font(Theme.title(18)).foregroundStyle(Theme.paper)
                                Text(sim.dateString).font(Theme.data(12)).foregroundStyle(Theme.steel)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 4)
                    SpeedControl(store: store)
                    GameMenu(store: store)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        Readout(label: "PIB", value: Fmt.money(sim.effectiveGDP(player.id)))
                        Readout(label: "Croissance", value: Fmt.signedPct(player.growth),
                                tint: player.growth >= 0 ? Theme.teal : Theme.coral)
                        Readout(label: "Dette", value: Fmt.pct(player.debt / max(sim.effectiveGDP(player.id), 1), 0),
                                tint: player.debt / max(sim.effectiveGDP(player.id), 1) > 1 ? Theme.coral : Theme.paper)
                        Readout(label: "Influence", value: Fmt.number(player.influence), tint: Theme.amber)
                        Readout(label: "Divisions", value: "\(player.divisionCount)")
                        Readout(label: "Tension mondiale", value: Fmt.number(sim.state.worldTension),
                                tint: sim.state.worldTension > 60 ? Theme.coral : Theme.paper)
                    }
                }
            }
            .padding(14)
            .glass(22)
        }
    }
}

struct Readout: View {
    let label: String
    let value: String
    var tint: Color = Theme.paper

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.data(15, weight: .semibold)).foregroundStyle(tint)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.steel)
        }
    }
}

struct SpeedControl: View {
    @ObservedObject var store: GameStore

    var body: some View {
        HStack(spacing: 2) {
            speedButton(0, icon: "pause.fill", label: "Pause")
            speedButton(1, icon: "play.fill", label: "Vitesse 1")
            speedButton(2, icon: "forward.fill", label: "Vitesse 2")
            speedButton(3, icon: "forward.end.alt.fill", label: "Vitesse 3")
        }
        .padding(3)
        .background(Color.white.opacity(0.07), in: Capsule())
    }

    private func speedButton(_ value: Int, icon: String, label: String) -> some View {
        Button {
            store.speed = value
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 32, height: 28)
                .foregroundStyle(store.speed == value ? Theme.ink : Theme.paper)
                .background(store.speed == value ? Theme.amber : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct GameMenu: View {
    @ObservedObject var store: GameStore

    var body: some View {
        Menu {
            Button { store.save() } label: { Label("Sauvegarder", systemImage: "square.and.arrow.down") }
            Button { store.load() } label: { Label("Charger la sauvegarde", systemImage: "arrow.clockwise") }
            Toggle(isOn: $store.satellite) { Label("Vue satellite", systemImage: "globe") }
            Toggle(isOn: $store.autoPause) { Label("Pause sur les événements", systemImage: "bell") }
            Button { store.step(days: 30) } label: { Label("Avancer d'un mois", systemImage: "calendar") }
            Button { store.open(.endGame) } label: { Label("Score et objectifs", systemImage: "trophy") }
            Divider()
            Button(role: .destructive) { store.quitToMenu() } label: {
                Label("Quitter vers le menu", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.paper)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.07), in: Circle())
        }
        .accessibilityLabel("Menu")
    }
}

// MARK: - Modes de carte

struct ModePicker: View {
    @ObservedObject var store: GameStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(MapMode.allCases) { mode in
                    Button {
                        withAnimation(.snappy) { store.mapMode = mode }
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(store.mapMode == mode ? Theme.ink : Theme.paper)
                            .background(store.mapMode == mode ? Theme.paper : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .glass(24)
        .frame(maxWidth: 560)
    }
}

// MARK: - Notifications

struct NoticeStack: View {
    @ObservedObject var store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            ForEach(store.toasts) { event in
                HStack(alignment: .top, spacing: 10) {
                    Text(event.text).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        store.toasts.removeAll { $0.id == event.id }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.steel)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Masquer")
                }
                .padding(12)
                .glass(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let message = store.feedback {
                Text(message).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.amber, in: Capsule())
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 560)
        .sensoryFeedback(.warning, trigger: store.toasts.count)
        .animation(.snappy, value: store.toasts.map { $0.id })
        .animation(.snappy, value: store.feedback)
    }
}

// MARK: - Dock

struct Dock: View {
    @ObservedObject var store: GameStore

    var body: some View {
        HStack(spacing: 4) {
            item("Économie", "chart.bar.xaxis", .economy)
            item("Politique", "building.columns", .politics)
            item("Armée", "shield.lefthalf.filled", .military)
            item("Industrie", "gearshape.2", .production)
            item("Recherche", "atom", .research)
            item("Projets", "hammer", .projects)
            item("Diplomatie", "envelope", .diplomacy, badge: inboxCount)
            item("Monde", "globe.americas", .world)
        }
        .padding(4)
        .glass(26)
        .frame(maxWidth: 700)
    }

    private var inboxCount: Int {
        guard let sim = store.sim, let p = store.playerID else { return 0 }
        return sim.state.proposals.filter { $0.to == p }.count
    }

    private func item(_ title: String, _ icon: String, _ panel: Panel, badge: Int = 0) -> some View {
        Button {
            store.open(panel)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.system(size: 17, weight: .medium))
                    if badge > 0 {
                        Text("\(badge)").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.ink)
                            .padding(4).background(Theme.amber, in: Circle())
                            .offset(x: 10, y: -8)
                    }
                }
                Text(title).font(.system(size: 9.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hôte des panneaux

struct PanelHost: View {
    @ObservedObject var store: GameStore
    let panel: Panel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTabs(store: store, panel: panel)
                Group {
                switch panel {
                case .economy: EconomyPanel(store: store)
                case .military: MilitaryPanel(store: store)
                case .production: ProductionPanel(store: store)
                case .diplomacy: DiplomacyPanel(store: store)
                case .world: WorldPanel(store: store)
                case .country(let id): CountryPanel(store: store, id: id)
                case .politics: PoliticsPanel(store: store)
                case .research: ResearchPanel(store: store)
                case .projects: ProjectsPanel(store: store)
                case .event(let eventID): EventPanel(store: store, eventID: eventID)
                case .endGame: EndGamePanel(store: store)
                case .battle(let province): BattlePanel(store: store, province: province)
                case .army(let id): ArmyOrganizer(store: store, armyID: id)
                }
                }
                .id(panel)
                .transition(.opacity.combined(with: .offset(y: 8)))
                if let message = store.feedback {
                    Text(message).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                        .padding(12).frame(maxWidth: .infinity)
                        .background(Theme.amber, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Tutoriel (premier lancement)

struct TutorialOverlay: View {
    let finish: () -> Void
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("globe.europe.africa", "La carte",
         "Pincez pour zoomer, glissez pour vous déplacer. Touchez un pays : sa fiche s'ouvre à gauche (aperçu, armée, région). Dans une de vos régions, vous pouvez construire forts et bases."),
        ("shield.lefthalf.filled", "Vos armées",
         "Chaque pion est une armée (30 divisions maximum). Le symbole indique les troupes : croix = infanterie, ovale = blindés, les deux = mécanisée. Touchez un pion, puis une région pour l'y envoyer."),
        ("hand.raised.fill", "Tracer un trajet",
         "Gardez le pouce sur ✋ (à gauche) et touchez plusieurs régions de l'autre main : l'armée passera par chacune. Le cadenas garde ce mode sans tenir le bouton."),
        ("flame.fill", "Les batailles",
         "Une flèche relie l'attaquant à la région visée, et le badge ⚔︎ montre l'avancée de la prise. Plus vous engagez de divisions, plus vous frappez fort. Touchez le badge pour le détail."),
        ("star.square.fill", "Bases et entraînement",
         "Une armée envoyée à sa base s'entraîne deux fois plus vite qu'en campagne. L'expérience rend les troupes jusqu'à 40 % plus efficaces."),
        ("square.grid.2x2", "Les sections",
         "En bas : Économie, Armée, Diplomatie, Politique. Le temps ne s'arrête que lorsqu'une guerre vous concerne ou qu'une décision vous attend.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: pages[page].0).font(.system(size: 30)).foregroundStyle(Theme.amber)
                Text(pages[page].1).font(Theme.title(26)).foregroundStyle(Theme.paper)
                Text(pages[page].2).font(.system(size: 16)).foregroundStyle(Theme.paper.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("\(page + 1) / \(pages.count)").font(Theme.data(13)).foregroundStyle(Theme.steel)
                    Spacer()
                    QuietButton(title: "Passer") { finish() }
                    QuietButton(title: page == pages.count - 1 ? "Jouer" : "Suivant", tint: Theme.amber) {
                        if page == pages.count - 1 {
                            finish()
                        } else {
                            withAnimation(.snappy) { page += 1 }
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 460)
            .glass(24)
            .padding(24)
        }
    }
}
