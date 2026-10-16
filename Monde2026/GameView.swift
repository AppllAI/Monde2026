import SwiftUI

// =============================================================
//  GameView.swift
//  L'écran de jeu : la carte en plein écran, la barre de
//  commandement en haut, le dock des panneaux en bas.
// =============================================================

struct GameView: View {
    @ObservedObject var store: GameStore
    @AppStorage("tutorialSeen") private var tutorialSeen = false

    var body: some View {
        ZStack {
            WorldMapView(snapshot: store.mapSnapshot, satellite: store.satellite, focus: store.focus) { point in
                store.tapMap(point)
            }
            .equatable()
            .ignoresSafeArea()
            VStack(spacing: 10) {
                CommandBar(store: store)
                ModePicker(store: store)
                Spacer()
                NoticeStack(store: store)
                if store.selectedCountry != nil {
                    InspectorCard(store: store)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                HStack(alignment: .bottom) {
                    MapLegend(mode: store.mapMode)
                    Spacer()
                    MapButtons(store: store)
                }
                .frame(maxWidth: 640)
                Dock(store: store)
            }
            .animation(.snappy, value: store.selectedCountry)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            if !tutorialSeen {
                TutorialOverlay { tutorialSeen = true }
            }
        }
        .sheet(item: $store.panel, onDismiss: { store.presentUrgent() }) { panel in
            PanelHost(store: store, panel: panel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.ink.opacity(0.96))
                .presentationCornerRadius(28)
        }
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
            item("Diplomatie", "envelope", .diplomacy, badge: inboxCount)
            item("Monde", "globe.americas", .world)
        }
        .padding(4)
        .glass(26)
        .frame(maxWidth: 640)
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
                switch panel {
                case .economy: EconomyPanel(store: store)
                case .military: MilitaryPanel(store: store)
                case .production: ProductionPanel(store: store)
                case .diplomacy: DiplomacyPanel(store: store)
                case .world: WorldPanel(store: store)
                case .country(let id): CountryPanel(store: store, id: id)
                case .politics: PoliticsPanel(store: store)
                case .research: ResearchPanel(store: store)
                case .event(let eventID): EventPanel(store: store, eventID: eventID)
                case .endGame: EndGamePanel(store: store)
                }
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
         "Pincez pour zoomer, glissez pour vous déplacer. Chaque région est coloriée selon son propriétaire. Touchez une région pour ouvrir la fiche du pays."),
        ("clock", "Le temps",
         "En haut, choisissez la vitesse. Le jeu se met en pause quand un panneau est ouvert ou qu'un événement important arrive."),
        ("square.grid.3x3", "Les panneaux",
         "En bas : économie, politique, armée, industrie, recherche, diplomatie et état du monde. Commencez par le budget et la recherche."),
        ("hand.raised", "La diplomatie",
         "Avant chaque proposition, l'IA vous montre si elle accepterait et pourquoi. Les factions vous protègent : attaquer un membre, c'est attaquer tous les autres."),
        ("trophy", "Le but",
         "Remplissez vos objectifs nationaux et faites grimper votre score jusqu'en 2050. Votre pays peut aussi être conquis, ou son régime renversé.")
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
