import SwiftUI
import Charts

// =============================================================
//  EconomyPanel.swift
//  Tableau de bord économique, budget, mode d'économie,
//  ressources et commerce.
// =============================================================

struct EconomyPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Économie", subtitle: c.name, flag: c.id) { store.panel = nil }
            overview(sim, c)
            GDPChart(history: c.history, sim: sim)
            BudgetEditor(store: store, country: c)
            EconomyModeCard(store: store, country: c)
            ResourcesCard(sim: sim, country: c)
        }
    }

    private func overview(_ sim: Simulation, _ c: Country) -> some View {
        let gdp = sim.effectiveGDP(c.id)
        let deficit = -c.lastBudgetBalance * 12 / max(gdp, 0.1)
        let debt = c.debt / max(gdp, 0.1)
        let items: [(String, String, Color)] = [
            ("PIB", Fmt.money(gdp), Theme.paper),
            ("Croissance", Fmt.signedPct(c.growth), c.growth >= 0 ? Theme.teal : Theme.coral),
            ("Population", Fmt.population(c.population), Theme.paper),
            ("Dette publique", Fmt.pct(debt, 0), debt > 1 ? Theme.coral : Theme.paper),
            ("Déficit", Fmt.pct(deficit), deficit > 0.05 ? Theme.coral : Theme.paper),
            ("Inflation", Fmt.pct(c.inflation), c.inflation > 0.06 ? Theme.coral : Theme.paper),
            ("Chômage", Fmt.pct(c.unemployment), Theme.paper),
            ("Taux d'emprunt", Fmt.pct(c.interestRate), c.interestRate > 0.08 ? Theme.coral : Theme.paper),
            ("Technologie", Fmt.number(c.tech, 2), Theme.paper),
            ("Infrastructures", Fmt.pct(c.infrastructure, 0), Theme.paper),
            ("Commerce", Fmt.money(c.tradeBalance * 12) + "/an", c.tradeBalance >= 0 ? Theme.teal : Theme.coral),
            ("Lassitude", Fmt.pct(c.warExhaustion, 0), c.warExhaustion > 0.5 ? Theme.coral : Theme.paper)
        ]
        return Dossier(title: "Situation", subtitle: c.defaultMonthsLeft > 0 ? "Pays en défaut de paiement" : nil) {
            FigureGrid(items: items)
        }
    }
}

struct GDPChart: View {
    let history: [Snapshot]
    let sim: Simulation

    var body: some View {
        Dossier(title: "PIB", subtitle: history.count < 2 ? "La courbe apparaît après le premier mois." : nil) {
            if history.count >= 2 {
                Chart(history) { snap in
                    AreaMark(x: .value("Jour", snap.day), y: .value("PIB", snap.gdp))
                        .foregroundStyle(LinearGradient(colors: [Theme.amber.opacity(0.35), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Jour", snap.day), y: .value("PIB", snap.gdp))
                        .foregroundStyle(Theme.amber)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
                HStack {
                    Text(sim.dateString(forDay: history.first?.day ?? 0))
                    Spacer()
                    Text(sim.dateString(forDay: history.last?.day ?? 0))
                }
                .font(Theme.small).foregroundStyle(Theme.steel)
            }
        }
    }
}

struct BudgetEditor: View {
    @ObservedObject var store: GameStore
    let country: Country
    @State private var draft = Budget(taxRate: 0, military: 0, infrastructure: 0, research: 0, social: 0)
    @State private var loaded = false

    var body: some View {
        Dossier(title: "Budget de l'État", subtitle: "En part du PIB. Les dépenses d'infrastructures financent vos chantiers.") {
            slider("Recettes fiscales", value: $draft.taxRate, range: 0.05...0.70, tint: Theme.teal)
            slider("Défense", value: $draft.military, range: 0...0.40, tint: Theme.coral)
            slider("Infrastructures", value: $draft.infrastructure, range: 0...0.15, tint: Theme.amber)
            slider("Recherche", value: $draft.research, range: 0...0.10, tint: Theme.sky)
            slider("Social, santé, éducation", value: $draft.social, range: 0...0.50, tint: Theme.steel)
            projection
            ActionButton(title: "Appliquer le budget", icon: "checkmark", enabled: draft != country.budget) {
                let b = draft
                let id = country.id
                store.mutate { $0.setBudget(b, for: id) }
                store.feedback = "Budget appliqué."
            }
        }
        .onAppear {
            if !loaded {
                draft = country.budget
                loaded = true
            }
        }
    }

    private var projection: some View {
        let gdp = store.sim?.effectiveGDP(country.id) ?? country.gdp
        let monthly = gdp / 12
        let revenue = monthly * draft.taxRate + country.foreignAid / 12
        let spending = monthly * draft.totalSpending + country.debt * country.interestRate / 12
        let balance = (revenue - spending) * 12
        let share = balance / max(gdp, 0.1)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Solde prévu").font(.system(size: 14)).foregroundStyle(Theme.steel)
                Spacer()
                Text("\(Fmt.money(balance))/an (\(Fmt.signedPct(share)))")
                    .font(Theme.data(15, weight: .semibold))
                    .foregroundStyle(balance >= 0 ? Theme.teal : (share < -0.05 ? Theme.coral : Theme.amber))
            }
            Text("Intérêts de la dette : \(Fmt.money(country.debt * country.interestRate)) par an.")
                .font(Theme.small).foregroundStyle(Theme.steel)
            if draft.taxRate > country.baseTaxRate + 0.02 {
                Text("Des impôts plus élevés que d'habitude freinent la croissance.")
                    .font(Theme.small).foregroundStyle(Theme.amber)
            }
        }
        .padding(.top, 4)
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 14)).foregroundStyle(Theme.paper)
                Spacer()
                Text(Fmt.pct(value.wrappedValue)).font(Theme.data(14, weight: .semibold)).foregroundStyle(tint)
            }
            Slider(value: value, in: range, step: 0.001).tint(tint)
                .accessibilityLabel(label)
        }
    }
}

struct EconomyModeCard: View {
    @ObservedObject var store: GameStore
    let country: Country

    var body: some View {
        Dossier(title: "Mobilisation de l'économie", subtitle: description) {
            Picker("Mode", selection: Binding(
                get: { country.economyMode },
                set: { mode in
                    let id = country.id
                    store.mutate { $0.setEconomyMode(mode, for: id) }
                })) {
                ForEach(EconomyMode.allCases, id: \.self) { mode in
                    Text(shortName(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var description: String {
        let m = country.economyMode
        return "Production militaire ×\(Fmt.number(m.militaryOutputBonus, 2)), biens de consommation \(Fmt.pct(m.consumerGoodsShare, 0)) des usines, croissance −\(Fmt.pct(m.growthPenalty))."
    }

    private func shortName(_ m: EconomyMode) -> String {
        switch m {
        case .civilian: return "Civile"
        case .partialMobilization: return "Partielle"
        case .warEconomy: return "Guerre"
        }
    }
}

struct ResourcesCard: View {
    let sim: Simulation
    let country: Country

    var body: some View {
        Dossier(title: "Ressources et marché mondial", subtitle: blockedText) {
            ForEach(Resource.allCases, id: \.self) { r in
                row(r)
            }
        }
    }

    private var blockedText: String {
        let blocked = sim.tradeBlockedPartners(of: country.id).count
        return blocked == 0 ? "Vous commercez avec le monde entier." : "Commerce impossible avec \(blocked) pays (guerre ou sanctions)."
    }

    private func row(_ r: Resource) -> some View {
        let production = sim.effectiveResourceProduction(country.id, r)
        let demand = country.resourceDemand[r] ?? 0
        let coverage = country.resourceCoverage[r] ?? 1
        let price = sim.state.prices[r] ?? 1
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(r.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                Spacer()
                Text("prix \(Fmt.number(price * 100)) %")
                    .font(Theme.data(12)).foregroundStyle(price > 1.15 ? Theme.coral : (price < 0.9 ? Theme.teal : Theme.steel))
            }
            Meter(value: coverage, tint: coverage > 0.95 ? Theme.teal : (coverage > 0.75 ? Theme.amber : Theme.coral))
            Text("Production \(Fmt.money(production * 12))/an, besoins \(Fmt.money(demand * 12))/an, couverts à \(Fmt.pct(coverage, 0))")
                .font(Theme.small).foregroundStyle(Theme.steel)
        }
        .padding(.vertical, 2)
    }
}
