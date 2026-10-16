import Foundation

// =============================================================
//  Economy.swift
//  Le moteur économique (calculé chaque mois) :
//  marché mondial des ressources, budget, dette, croissance,
//  inflation, chômage, recherche et construction.
// =============================================================

/// Résultat mensuel du budget d'un pays (Md$ / mois).
struct BudgetOutcome {
    var revenue: Double
    var interest: Double
    var military: Double
    var infrastructure: Double
    var research: Double
    var social: Double
    var balance: Double     // négatif = déficit
}

extension Simulation {

    // MARK: - Territoire et occupation

    /// Part du territoire occupée par l'ennemi pendant une guerre en cours.
    func occupiedFraction(_ id: CountryID) -> Double {
        let total = state.occupation[id]?.values.reduce(0, +) ?? 0
        return total.clamped(0, 0.99)
    }

    /// Part du territoire perdue au total : occupation + annexions.
    func lostFraction(_ id: CountryID) -> Double {
        let occupied = state.occupation[id]?.values.reduce(0, +) ?? 0
        let annexed = state.annexation[id]?.values.reduce(0, +) ?? 0
        let rebels = state.countries[id]?.civilWar ?? 0
        return (occupied + annexed + rebels).clamped(0, 0.99)
    }

    /// Part du territoire de `victim` tenue par `holder` (occupation + annexion).
    func heldFraction(of victim: CountryID, by holder: CountryID) -> Double {
        (state.occupation[victim]?[holder] ?? 0) + (state.annexation[victim]?[holder] ?? 0)
    }

    /// Territoires tenus par un pays (occupés ou annexés) : (victime, fraction).
    func territoriesHeld(by occupier: CountryID) -> [(CountryID, Double)] {
        var totals: [CountryID: Double] = [:]
        for (victim, occupiers) in state.occupation {
            if let f = occupiers[occupier], f > 0.0001 { totals[victim, default: 0] += f }
        }
        for (victim, holders) in state.annexation {
            if let f = holders[occupier], f > 0.0001 { totals[victim, default: 0] += f }
        }
        return totals.keys.sorted().map { ($0, totals[$0] ?? 0) }
    }

    /// PIB réellement disponible : territoire contrôlé + 35 % de la valeur des zones conquises.
    func effectiveGDP(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var value = c.gdp * (1 - lostFraction(id) * 0.9)
        for (victim, f) in territoriesHeld(by: id) {
            value += (state.countries[victim]?.gdp ?? 0) * f * 0.35
        }
        return max(value, 0.1)
    }

    func effectiveCivilianFactories(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var value = c.civilianFactories * (1 - lostFraction(id))
        for (victim, f) in territoriesHeld(by: id) {
            value += (state.countries[victim]?.civilianFactories ?? 0) * f * 0.3
        }
        return value
    }

    func effectiveMilitaryFactories(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var value = c.militaryFactories * (1 - lostFraction(id))
        for (victim, f) in territoriesHeld(by: id) {
            value += (state.countries[victim]?.militaryFactories ?? 0) * f * 0.3
        }
        return value
    }

    func effectiveDockyards(_ id: CountryID) -> Double {
        guard let c = state.countries[id] else { return 0 }
        return c.dockyards * (1 - lostFraction(id))
    }

    func effectiveResourceProduction(_ id: CountryID, _ r: Resource) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var value = (c.resourceProduction[r] ?? 0) * (1 - lostFraction(id))
        for (victim, f) in territoriesHeld(by: id) {
            value += (state.countries[victim]?.resourceProduction[r] ?? 0) * f * 0.5
        }
        return value
    }

    // MARK: - Calibrage initial

    /// Répartit la production mondiale de chaque ressource selon les parts des pays.
    mutating func calibrateResources() {
        let ids = countryIDs
        let totalPop = ids.reduce(0.0) { $0 + (state.countries[$1]?.population ?? 0) }
        for r in Resource.allCases {
            var shares: [CountryID: Double] = [:]
            var total = 0.0
            for id in ids {
                guard let c = state.countries[id] else { continue }
                var s = c.resourceShare[r] ?? 0
                if r == .food && c.resourceShare[.food] == nil {
                    s = c.population / max(totalPop, 1) * 100 * 0.8
                }
                shares[id] = s
                total += s
            }
            for id in ids {
                let value = total > 0 ? r.worldMonthlyValue * (shares[id] ?? 0) / total : 0
                state.countries[id]?.resourceProduction[r] = value
            }
        }
    }

    /// Ajuste croissance et inflation « structurelles » pour que le monde démarre sur ses vrais chiffres.
    mutating func calibrateEconomy() {
        for id in countryIDs {
            let gdp = effectiveGDP(id)
            let b = projectedBudget(id)
            let effects = growthEffects(id, budget: b, gdp: gdp, atWar: isAtWar(id), homeFront: isFightingAtHome(id))
            let construction = expectedConstructionGrowth(id, budget: b, gdp: gdp)
            let pressure = inflationPressure(id, budget: b, gdp: gdp)
            guard var c = state.countries[id] else { continue }
            c.interestRate = marketInterestRate(c, gdp: gdp)
            c.growthCalibration = c.growth - effects - construction
            c.inflationAnchor = c.inflation - pressure
            c.trendGrowth = c.growth
            c.constructionFunds = b.infrastructure
            state.countries[id] = c
        }
    }

    // MARK: - Marché mondial des ressources

    /// Production, demande, échanges, prix. Les pays en guerre ne commercent pas entre eux ;
    /// une flotte ennemie dominante impose un blocus.
    mutating func updateMarket() {
        let ids = countryIDs
        var gdpOf: [CountryID: Double] = [:]
        var industryOf: [CountryID: Double] = [:]
        var enemiesOf: [CountryID: Set<CountryID>] = [:]
        var atWar: [CountryID: Bool] = [:]
        var totalGDP = 0.0, totalPop = 0.0, totalIndustry = 0.0
        for id in ids {
            guard let c = state.countries[id] else { continue }
            let g = effectiveGDP(id)
            let ind = effectiveCivilianFactories(id) + 1.5 * effectiveMilitaryFactories(id)
            gdpOf[id] = g
            industryOf[id] = ind
            totalGDP += g
            totalPop += c.population
            totalIndustry += ind
            // Pas de commerce avec ses ennemis ni avec les pays sous sanctions mutuelles.
            enemiesOf[id] = tradeBlockedPartners(of: id)
            atWar[id] = isAtWar(id)
        }
        let blockades = computeBlockades()
        // La demande mondiale suit (en partie) la croissance du PIB mondial.
        let worldScale = pow(totalGDP / max(state.initialWorldGDP, 1), 0.7)

        for r in Resource.allCases {
            let w = r.demandWeights
            var demand: [CountryID: Double] = [:]
            var production: [CountryID: Double] = [:]
            var worldDemand = 0.0, worldSupply = 0.0
            for id in ids {
                guard let c = state.countries[id] else { continue }
                let share = w.gdp * (gdpOf[id] ?? 0) / max(totalGDP, 1)
                    + w.population * c.population / max(totalPop, 1)
                    + w.industry * (industryOf[id] ?? 0) / max(totalIndustry, 1)
                var d = r.worldMonthlyValue * share * worldScale * c.demandFactor(r)
                if r == .oil && (atWar[id] ?? false) { d *= 1.2 }
                if (r == .steel || r == .criticalMinerals || r == .semiconductors) && c.economyMode != .civilian {
                    d *= 1.1
                }
                let p = effectiveResourceProduction(id, r)
                demand[id] = d
                production[id] = p
                worldDemand += d
                worldSupply += p
            }

            // Surplus et déficits
            var surplus: [CountryID: Double] = [:]
            var deficit: [CountryID: Double] = [:]
            var worldSurplus = 0.0, worldDeficit = 0.0
            for id in ids {
                let p = production[id] ?? 0
                let d = demand[id] ?? 0
                surplus[id] = max(0, p - d)
                deficit[id] = max(0, d - p)
                worldSurplus += surplus[id] ?? 0
                worldDeficit += deficit[id] ?? 0
            }
            let globalFill = worldDeficit > 0 ? min(1, worldSurplus / worldDeficit) : 1

            // Importations : on ne peut pas acheter à ses ennemis, et le blocus coupe une partie du reste.
            var imports: [CountryID: Double] = [:]
            var worldImported = 0.0
            for id in ids {
                let need = deficit[id] ?? 0
                guard need > 0 else {
                    imports[id] = 0
                    continue
                }
                var hostile = 0.0
                for e in enemiesOf[id] ?? [] {
                    hostile += surplus[e] ?? 0
                }
                let hostileShare = worldSurplus > 0 ? hostile / worldSurplus : 0
                // La moitié de l'offre perdue est compensée par la réorganisation des flux mondiaux.
                let fill = (globalFill * (1 - hostileShare * 0.5) * (1 - (blockades[id] ?? 0))).clamped(0, 1)
                imports[id] = need * fill
                worldImported += need * fill
            }
            let sellRatio = worldSurplus > 0 ? min(1, worldImported / worldSurplus) : 0

            // Prix : rapport demande / offre, lissé.
            let ratio = worldDemand / max(worldSupply, 0.001)
            let target = pow(ratio, r.priceElasticity).clamped(0.4, 4.0)
            let old = state.prices[r] ?? 1
            state.prices[r] = old + (target - old) * 0.3

            for id in ids {
                guard var c = state.countries[id] else { continue }
                let d = demand[id] ?? 0
                let used = min(production[id] ?? 0, d) + (imports[id] ?? 0)
                c.resourceDemand[r] = d
                c.resourceCoverage[r] = d > 0 ? (used / d).clamped(0, 1) : 1
                c.resourceImports[r] = imports[id] ?? 0
                c.resourceExports[r] = (surplus[id] ?? 0) * sellRatio
                state.countries[id] = c
            }
        }

        // Balance commerciale et croissance de l'offre mondiale (+2,5 %/an).
        for id in ids {
            guard var c = state.countries[id] else { continue }
            var balance = 0.0
            for r in Resource.allCases {
                let price = state.prices[r] ?? 1
                balance += ((c.resourceExports[r] ?? 0) - (c.resourceImports[r] ?? 0)) * price
                c.resourceProduction[r] = (c.resourceProduction[r] ?? 0) * (1 + 0.025 / 12)
            }
            c.tradeBalance = balance
            state.countries[id] = c
        }
    }

    // MARK: - Budget et dette

    func marketInterestRate(_ c: Country, gdp: Double) -> Double {
        let debtRatio = c.debt / max(gdp, 0.1)
        let rate = 0.025 + max(0, debtRatio - 0.6) * 0.03 + c.inflation.clamped(0, 0.10) * 0.6 - c.borrowingBonus
        return rate.clamped(0.005, 0.35)
    }

    func projectedBudget(_ id: CountryID) -> BudgetOutcome {
        guard let c = state.countries[id] else {
            return BudgetOutcome(revenue: 0, interest: 0, military: 0, infrastructure: 0, research: 0, social: 0, balance: 0)
        }
        let monthly = effectiveGDP(id) / 12
        let revenue = monthly * c.budget.taxRate + c.foreignAid / 12
        let interest = c.debt * c.interestRate / 12
        let military = monthly * c.budget.military
        let infrastructure = monthly * c.budget.infrastructure
        let research = monthly * c.budget.research
        let social = monthly * c.budget.social
        let balance = revenue - military - infrastructure - research - social - interest
        return BudgetOutcome(revenue: revenue, interest: interest, military: military,
                             infrastructure: infrastructure, research: research, social: social, balance: balance)
    }

    // MARK: - Croissance

    /// Effets des choix et de la situation sur la croissance annuelle (hors calibrage).
    func growthEffects(_ id: CountryID, budget b: BudgetOutcome, gdp: Double, atWar: Bool, homeFront: Bool) -> Double {
        guard let c = state.countries[id] else { return 0 }
        var e = 0.0
        e += (c.infrastructure - 0.6) * 0.02
        e += (c.budget.research - 0.02) * 0.4
        e -= max(0, c.budget.military - 0.03) * 0.2
        e -= (c.budget.taxRate - c.baseTaxRate) * 0.25
        let deficit = -b.balance * 12 / gdp
        e += deficit.clamped(-0.1, 0.1) * 0.15
        let debtRatio = c.debt / gdp
        e -= max(0, debtRatio - 1.0) * 0.015
        e -= max(0, c.inflation - 0.05) * 0.15
        for r in Resource.allCases {
            e -= (1 - (c.resourceCoverage[r] ?? 1)) * r.shortageGrowthImpact
        }
        e += (c.tradeBalance * 12 / gdp).clamped(-0.1, 0.1) * 0.1
        e -= c.conscription.growthPenalty
        e -= c.economyMode.growthPenalty
        if homeFront {
            e -= 0.03
        } else if atWar {
            e -= 0.005
        }
        // Crise de la dette : taux d'intérêt hors de contrôle, ou défaut récent.
        if debtRatio > 1.3 && c.interestRate > 0.12 {
            e -= 0.03
        }
        if c.defaultMonthsLeft > 0 {
            e -= 0.04
        }
        // Accords commerciaux (+0,15 pt chacun, plafonné) et sanctions subies (selon le poids des sanctionneurs).
        let pacts = state.treaties.filter { $0.kind == .tradePact && $0.involves(id) }.count
        e += min(0.01, Double(pacts) * 0.0015)
        var sanctionersGDP = 0.0
        for t in state.treaties where t.kind == .sanctions && t.b == id {
            sanctionersGDP += state.countries[t.a]?.gdp ?? 0
        }
        e -= min(0.04, sanctionersGDP / max(state.initialWorldGDP, 1) * 0.06)
        e -= c.warExhaustion * 0.02
        // Politique intérieure, technologies, effets temporaires.
        e += (c.stability - 0.6) * 0.03
        if c.civilWar > 0 { e -= 0.03 }
        e += c.techGrowthBonus
        e += c.modifierGrowth
        return e
    }

    func constructionPoints(_ c: Country, effectiveCivilian: Double) -> Double {
        effectiveCivilian * (1 - c.economyMode.consumerGoodsShare) * 30
            * (0.5 + 0.5 * c.tech) * (0.6 + 0.4 * c.infrastructure)
            * (c.has(.automation) ? 1.1 : 1) * (0.5 + 0.5 * c.stability / 0.65).clamped(0.6, 1.15)
    }

    /// Ce que l'IA construit quand la file est vide.
    func autoConstructionKind(_ c: Country, atWar: Bool, militaryBudget: Double) -> ConstructionKind {
        if atWar {
            let spare = max(0, militaryBudget - c.militaryUpkeep)
            let desiredFactories = spare * 1000 / 30 / c.costMultiplier / 5
            if c.militaryFactories < desiredFactories * 0.9 {
                return .militaryFactory
            }
        }
        if c.infrastructure < 0.5 {
            return .infrastructure
        }
        return .civilianFactory
    }

    /// Croissance attendue de la construction au rythme actuel (sert au calibrage).
    func expectedConstructionGrowth(_ id: CountryID, budget b: BudgetOutcome, gdp: Double) -> Double {
        guard let c = state.countries[id] else { return 0 }
        let kind = autoConstructionKind(c, atWar: isAtWar(id), militaryBudget: b.military)
        let cp = constructionPoints(c, effectiveCivilian: effectiveCivilianFactories(id))
        let projects = min(cp / kind.constructionCost, max(0, b.infrastructure) / kind.moneyCost(area: c.area))
        return projects * kind.gdpValue * 12 / gdp
    }

    // MARK: - Inflation

    func inflationPressure(_ id: CountryID, budget b: BudgetOutcome, gdp: Double) -> Double {
        guard let c = state.countries[id] else { return 0 }
        let deficit = -b.balance * 12 / gdp
        var p = max(0, deficit - 0.04) * 0.3
        var importCost = 0.0
        var shortage = 0.0
        for r in Resource.allCases {
            importCost += (c.resourceImports[r] ?? 0) * ((state.prices[r] ?? 1) - 1)
            shortage += (1 - (c.resourceCoverage[r] ?? 1)) * r.shortageGrowthImpact
        }
        p += importCost * 12 / gdp * 0.5
        p += shortage * 2
        p += c.economyMode.inflationPressure
        return p
    }

    // MARK: - Mois économique d'un pays

    mutating func monthlyEconomy(_ id: CountryID) {
        let gdp = effectiveGDP(id)
        let effCiv = effectiveCivilianFactories(id)
        let atWar = isAtWar(id)
        let homeFront = isFightingAtHome(id)
        let maxTech = state.countries.values.map { $0.tech }.max() ?? 1
        let b = projectedBudget(id)
        let effects = growthEffects(id, budget: b, gdp: gdp, atWar: atWar, homeFront: homeFront)
        let pressure = inflationPressure(id, budget: b, gdp: gdp)
        let occupiedNow = occupiedFraction(id)
        guard var c = state.countries[id] else { return }

        // 1. Finances publiques
        c.debt = max(0, c.debt - b.balance)
        c.lastBudgetBalance = b.balance
        c.interestRate += (marketInterestRate(c, gdp: gdp) - c.interestRate) * 0.05
        // Défaut de paiement : si les intérêts dépassent 12 % du PIB, la dette est restructurée (−50 %)
        // mais le pays subit deux ans de récession et de taux punitifs.
        if c.defaultMonthsLeft > 0 {
            c.defaultMonthsLeft -= 1
        } else if c.debt * c.interestRate / gdp > 0.12 && c.borrowingBonus < 0.02 {
            c.debt *= 0.5
            c.interestRate = min(0.35, c.interestRate + 0.05)
            c.defaultMonthsLeft = 24
            addEvent("\(c.name) fait défaut sur sa dette.")
        }

        // 2. Budget militaire : soldes et entretien d'abord, le reste pour acheter du matériel.
        let upkeep = c.militaryUpkeep
        let leftover = b.military - upkeep
        c.procurementFunds = max(0, c.procurementFunds + leftover)
        let cap = max(b.military, 0) * 4
        var overflow = 0.0
        if c.procurementFunds > cap {
            overflow = c.procurementFunds - cap
            c.procurementFunds = cap
        }
        // Argent qui ne sert pas à produire = entraînement et entretien.
        let funding = min(1, b.military / max(upkeep * 1.5, 0.001))
        let readinessTarget = (0.35 + 0.5 * funding + (overflow > 0 ? 0.15 : 0)).clamped(0.2, 1)
        c.readiness += (readinessTarget - c.readiness) * 0.15

        // 3. Recherche : rendements décroissants + rattrapage par diffusion.
        let gain = 0.0006 * log10(1 + max(0, b.research) * 10) * max(0, 1.6 - c.tech)
            + 0.0015 * max(0, maxTech - c.tech) / 12
        c.tech += gain

        // 4. Croissance « de fond » (productivité, politique, pénuries, guerre…)
        let gdpBefore = c.gdp
        let difficultyBonus = id == state.playerID ? state.difficulty.playerGrowthBonus : 0
        let g = (c.growthCalibration + effects + difficultyBonus).clamped(-0.30, 0.15)
        c.gdp *= 1 + g / 12
        c.civilianFactories *= 1 + g / 12

        // 5. Construction (financée par le budget infrastructures) : les nouvelles usines ajoutent du PIB.
        let points = constructionPoints(c, effectiveCivilian: effCiv)
        c.constructionFunds = min(c.constructionFunds + max(0, b.infrastructure), max(b.infrastructure, 0.01) * 3)
        let autoKind = autoConstructionKind(c, atWar: atWar, militaryBudget: b.military)
        Simulation.runConstruction(&c, points: points, autoKind: autoKind)

        // Croissance totale annualisée (fond + construction)
        let totalGrowth = (c.gdp / max(gdpBefore, 0.1) - 1) * 12
        c.growth = c.growth + (totalGrowth - c.growth) * 0.5   // lissée pour l'affichage

        // 6. Inflation (ancrage qui revient doucement vers 2,5 %)
        let inflationTarget = c.inflationAnchor + pressure
        c.inflation += (inflationTarget - c.inflation) * 0.15
        c.inflationAnchor += (0.025 - c.inflationAnchor) * 0.01

        // 7. Chômage
        let laborForce = c.population * 1000 * 0.45
        let mobilized = max(0, c.activePersonnel - c.initialActivePersonnel) / max(laborForce, 1)
        let unemploymentTarget = c.naturalUnemployment - (totalGrowth - c.trendGrowth) * 0.5 - mobilized
        c.unemployment += (unemploymentTarget - c.unemployment) * 0.1
        c.unemployment = c.unemployment.clamped(0.01, 0.5)

        // 8. Population
        c.population *= 1 + c.populationGrowth / 12

        // 8 bis. À long terme, chaque économie converge vers sa croissance potentielle
        // (les pays moins avancés rattrapent leur retard plus vite). Évite les booms ou crises sans fin.
        let potential = 0.012 + 0.035 * max(0, 1 - c.tech)
        let baseline = (c.growthCalibration + effects) - potential
        c.growthCalibration -= baseline / 72
        // L'aide étrangère diminue une fois la paix revenue.
        if !atWar { c.foreignAid *= 0.97 }

        // 9. Lassitude de guerre : pertes, territoire occupé, durée.
        let newCasualties = c.casualties - c.casualtiesAtLastMonth
        c.casualtiesAtLastMonth = c.casualties
        if atWar {
            let fromLosses = newCasualties / max(c.population * 1000 * 0.03, 1)
            c.warExhaustion = min(1, c.warExhaustion + fromLosses + occupiedNow * 0.04 + 0.005)
        } else {
            c.warExhaustion = max(0, c.warExhaustion - 0.04)
        }

        state.countries[id] = c
    }

    /// Avance les projets dans l'ordre de la file. Limité par les points de construction ET l'argent.
    static func runConstruction(_ c: inout Country, points: Double, autoKind: ConstructionKind) {
        var cp = points
        var iterations = 0
        while cp > 0.01 && c.constructionFunds > 0.01 && iterations < 50 {
            iterations += 1
            if c.constructionQueue.isEmpty {
                c.constructionQueue.append(ConstructionProject(id: c.nextProjectID, kind: autoKind, progress: 0))
                c.nextProjectID += 1
            }
            var project = c.constructionQueue[0]
            let cost = project.kind.constructionCost
            let moneyPerPoint = project.kind.moneyCost(area: c.area) / cost
            var step = min(cost - project.progress, cp)
            if moneyPerPoint > 0 {
                step = min(step, c.constructionFunds / moneyPerPoint)
            }
            if step <= 0.0001 { break }
            project.progress += step
            cp -= step
            c.constructionFunds -= step * moneyPerPoint
            c.gdp += project.kind.gdpValue * step / cost   // l'investissement nourrit le PIB au fil du chantier
            if project.progress >= cost - 0.0001 {
                c.complete(project.kind)
                c.constructionQueue.removeFirst()
            } else {
                c.constructionQueue[0] = project
            }
        }
    }
}
