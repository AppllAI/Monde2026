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
            RadialGradient(colors: [Theme.sky.opacity(0.18), .clear], center: .topTrailing, startRadius: 20, endRadius: 520)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.amber.opacity(0.10), .clear], center: .bottomLeading, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monde 2026").font(Theme.title(44)).foregroundStyle(Theme.paper)
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
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CountryFilter.allCases) { f in
                        Button {
                            filter = f
                        } label: {
                            Text(f.rawValue).font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .foregroundStyle(filter == f ? Theme.ink : Theme.paper)
                                .background(filter == f ? Theme.paper : Color.white.opacity(0.06), in: Capsule())
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
                    CountryCard(country: c, selected: chosen == c.id, atWar: c.id == "UKR" || c.id == "RUS")
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

    var body: some View {
        HStack(spacing: 12) {
            FlagBadge(id: country.id, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(country.name).font(Theme.title(17)).foregroundStyle(Theme.paper).lineLimit(1)
                Text("\(Fmt.money(country.gdp)), \(Fmt.troops(country.activePersonnel)) soldats")
                    .font(Theme.data(12)).foregroundStyle(Theme.steel)
                if atWar {
                    Text("En guerre").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.coral)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(selected ? Theme.amber.opacity(0.16) : Color.white.opacity(0.05),
                    in: HUDShape(cut: 8))
        .overlay(HUDShape(cut: 8)
            .strokeBorder(selected ? Theme.amber : Theme.line, lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
    }
}
