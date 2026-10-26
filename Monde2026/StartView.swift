import SwiftUI

// =============================================================
//  StartView.swift
//  Choix du pays avant de commencer.
// =============================================================

enum CountryFilter: String, CaseIterable, Identifiable {
    case powers = "Puissances"
    case europe = "Europe"
    case americas = "Amériques"
    case middleEast = "Moyen-Orient"
    case africa = "Afrique"
    case asia = "Asie et Océanie"
    case all = "Tous"

    var id: String { rawValue }

    func matches(_ c: Country, rank: Int) -> Bool {
        switch self {
        case .powers: return rank < 20
        case .europe: return c.region == .westernEurope || c.region == .easternEurope
        case .americas: return c.region == .northAmerica || c.region == .latinAmerica
        case .middleEast: return c.region == .middleEast
        case .africa: return c.region == .northAfrica || c.region == .subSaharanAfrica
        case .asia: return [.southAsia, .centralAsia, .eastAsia, .southeastAsia, .oceania].contains(c.region)
        case .all: return true
        }
    }
}

struct StartView: View {
    @ObservedObject var store: GameStore
    @State private var catalog: [Country] = []
    @State private var filter: CountryFilter = .powers
    @State private var search = ""
    @State private var chosen: CountryID?
    @State private var loading = false
    @State private var difficulty: Difficulty = .normal

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 18) {
                header
                if store.hasSave {
                    QuietButton(title: "Reprendre la partie sauvegardée", icon: "arrow.uturn.forward") { store.load() }
                }
                filters
                countryList
                difficultyPicker
                startBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .frame(maxWidth: 820)
        }
        .onAppear {
            if catalog.isEmpty {
                catalog = WorldData.makeCountries().values.sorted { $0.gdp > $1.gdp }
            }
        }
    }

    private var background: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            // Grille tactique et lueurs : l'ambiance d'une salle de commandement.
            Canvas { ctx, size in
                let step: CGFloat = 36
                var grid = Path()
                var x: CGFloat = 0
                while x < size.width { grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y: CGFloat = 0
                while y < size.height { grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                ctx.stroke(grid, with: .color(Theme.sky.opacity(0.06)), lineWidth: 1)
                // Cercles de radar
                let c = CGPoint(x: size.width * 0.82, y: size.height * 0.18)
                for r in stride(from: 80.0, through: 520.0, by: 110.0) {
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .color(Theme.sky.opacity(0.07)), lineWidth: 1)
                }
            }
            .ignoresSafeArea()
            RadialGradient(colors: [Theme.sky.opacity(0.22), .clear], center: .topTrailing, startRadius: 20, endRadius: 560)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.amber.opacity(0.14), .clear], center: .bottomLeading, startRadius: 10, endRadius: 460)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GRANDE STRATÉGIE · LE MONDE D'AUJOURD'HUI").font(Theme.label(12)).tracking(2.4).foregroundStyle(Theme.amber)
            Text("MONDE 2026")
                .font(.system(size: 64, weight: .black).width(.condensed))
                .tracking(2)
                .foregroundStyle(LinearGradient(colors: [Theme.paper, Theme.amber], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.amber.opacity(0.35), radius: 16)
            Text("Prenez la tête d'un pays au 1er janvier 2026. Économie, armées, alliances et rivalités sont celles d'aujourd'hui.")
                .font(.system(size: 15)).foregroundStyle(Theme.steel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.steel)
                TextField("Rechercher un pays", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.paper)
            }
            .padding(12)
            .background(HUDShape(cut: 8).fill(Color.white.opacity(0.06)))
            .overlay(HUDShape(cut: 8).strokeBorder(Theme.edge))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CountryFilter.allCases) { f in
                        Button {
                            filter = f
                        } label: {
                            Text(f.rawValue.uppercased()).font(Theme.label(12.5)).tracking(0.8)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(filter == f ? Theme.ink : Theme.paper)
                                .background(HUDShape(cut: 6, radius: 2).fill(filter == f ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(Color.white.opacity(0.06))))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var visible: [Country] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        var result: [Country] = []
        for (rank, c) in catalog.enumerated() {
            if !query.isEmpty {
                if c.name.lowercased().contains(query) { result.append(c) }
            } else if filter.matches(c, rank: rank) {
                result.append(c)
            }
        }
        return result
    }

    private var countryList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(visible) { c in
                    CountryCard(country: c, selected: chosen == c.id, atWar: c.id == "UKR" || c.id == "RUS",
                                rank: catalog.firstIndex(where: { $0.id == c.id }) ?? 0)
                        .onTapGesture { chosen = c.id }
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Difficulté", selection: $difficulty) {
                ForEach(Difficulty.allCases) { d in
                    Text(d.name).tag(d)
                }
            }
            .pickerStyle(.segmented)
            Text(difficulty.summary).font(Theme.small).foregroundStyle(Theme.steel)
        }
    }

    private var startBar: some View {
        Group {
            if let id = chosen, let c = catalog.first(where: { $0.id == id }) {
                ActionButton(title: loading ? "Préparation du monde…" : "Jouer \(c.name)", icon: "play.fill",
                             enabled: !loading) {
                    loading = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        store.newGame(as: id, difficulty: difficulty)
                        loading = false
                    }
                }
            } else {
                Text("Touchez un pays pour le choisir.").font(.system(size: 14)).foregroundStyle(Theme.steel)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
        }
        .padding(.bottom, 8)
    }
}

struct CountryCard: View {
    let country: Country
    let selected: Bool
    let atWar: Bool
    var rank = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                FlagBadge(id: country.id, size: 28)
                    .frame(width: 44, height: 44)
                    .background(HUDShape(cut: 8).fill(Theme.raised))
                    .overlay(HUDShape(cut: 8).strokeBorder(selected ? Theme.amber : Theme.edge, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name.uppercased()).font(Theme.title(17)).tracking(0.5).foregroundStyle(Theme.paper).lineLimit(1)
                    if atWar {
                        Label("EN GUERRE", systemImage: "flame.fill").font(Theme.label(10)).foregroundStyle(Theme.coral)
                    } else {
                        Text("PUISSANCE N° \(rank + 1)").font(Theme.label(10)).tracking(0.6).foregroundStyle(Theme.steel)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                stat("banknote.fill", Fmt.money(country.gdp), Theme.amber)
                stat("shield.lefthalf.filled", "\(country.divisionCount) div.", Theme.sky)
                stat("person.3.fill", Fmt.troops(country.activePersonnel), Theme.teal)
            }
        }
        .padding(12)
        .background(HUDShape(cut: 10).fill(selected ? AnyShapeStyle(LinearGradient(colors: [Theme.amber.opacity(0.22), Theme.amber.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                                                    : AnyShapeStyle(LinearGradient(colors: [Theme.raised.opacity(0.7), Theme.deep.opacity(0.6)], startPoint: .top, endPoint: .bottom))))
        .overlay(HUDShape(cut: 10).strokeBorder(selected ? Theme.amber : Theme.line, lineWidth: selected ? 2 : 1))
        .shadow(color: selected ? Theme.amber.opacity(0.3) : .clear, radius: 10)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
    }

    private func stat(_ icon: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            Text(value).font(Theme.data(11.5, weight: .semibold)).foregroundStyle(Theme.paper.opacity(0.9)).lineLimit(1)
        }
    }
}
