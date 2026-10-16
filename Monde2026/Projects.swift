import Foundation

// =============================================================
//  Projects.swift
//  Les projets nationaux (à la manière des « focus » de HOI4) :
//  un grand chantier à la fois, qui prend plusieurs mois, coûte
//  une part du PIB et change durablement le pays.
//  Les pays IA en lancent aussi, selon leur situation.
// =============================================================

struct ActiveProject: Codable {
    var id: String
    var monthsLeft: Int
    var totalMonths: Int
}

enum ProjectCategory: String, CaseIterable {
    case economy = "Économie"
    case military = "Défense"
    case politics = "Société et diplomatie"
}

struct ProjectDefinition: Identifiable {
    let id: String
    let name: String
    let icon: String
    let category: ProjectCategory
    let detail: String
    let months: Int
    let cost: Double                      // part du PIB annuel, payée au fil des mois
    let available: (Simulation, CountryID) -> Bool
    let effect: (inout Simulation, CountryID) -> Void
    let aiInterest: (Simulation, CountryID) -> Double
}

enum ProjectCatalog {

    static func find(_ id: String) -> ProjectDefinition? {
        all.first { $0.id == id }
    }

    static let all: [ProjectDefinition] = [
        // MARK: Économie
        ProjectDefinition(
            id: "reindustrialisation", name: "Plan de réindustrialisation", icon: "building.2.fill", category: .economy,
            detail: "+12 % d'usines civiles et +0,4 pt de croissance pendant 2 ans.", months: 18, cost: 0.015,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in c.civilianFactories *= 1.12 }
                sim.addModifier(id, "Réindustrialisation", growth: 0.004, months: 24)
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.industryShare ?? 0.2) < 0.15 ? 2 : 1 }),
        ProjectDefinition(
            id: "grandsTravaux", name: "Grands travaux d'infrastructure", icon: "road.lanes", category: .economy,
            detail: "Infrastructures +8 points (routes, ports, réseau ferré). Construction plus rapide.", months: 24, cost: 0.02,
            available: { sim, id in (sim.state.countries[id]?.infrastructure ?? 1) < 0.92 },
            effect: { sim, id in sim.adjust(id) { c in c.infrastructure = min(1, c.infrastructure + 0.08) } },
            aiInterest: { sim, id in (sim.state.countries[id]?.infrastructure ?? 1) < 0.6 ? 3 : 0.5 }),
        ProjectDefinition(
            id: "zoneTech", name: "Zone franche technologique", icon: "cpu.fill", category: .economy,
            detail: "Niveau technologique +0,03 et 500 points de recherche.", months: 18, cost: 0.01,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.tech += 0.03
                    c.researchProgress += 500
                }
            },
            aiInterest: { _, _ in 1.2 }),
        ProjectDefinition(
            id: "puces", name: "Souveraineté des semi-conducteurs", icon: "memorychip.fill", category: .economy,
            detail: "Construit des usines de puces : production de semi-conducteurs fortement accrue.", months: 30, cost: 0.02,
            available: { sim, id in (sim.state.countries[id]?.tech ?? 0) >= 0.6 },
            effect: { sim, id in
                sim.adjust(id) { c in
                    let current = c.resourceProduction[.semiconductors] ?? 0
                    c.resourceProduction[.semiconductors] = current * 1.5 + c.gdp / 1000 * 0.4
                }
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.resourceCoverage[.semiconductors] ?? 1) < 0.9 ? 2 : 0.4 }),
        ProjectDefinition(
            id: "energie", name: "Transition énergétique", icon: "bolt.fill", category: .economy,
            detail: "Renouvelables et nucléaire civil : besoins en pétrole et en gaz réduits pour toujours.", months: 30, cost: 0.015,
            available: { sim, id in !(sim.state.countries[id]?.has(.smartGrid) ?? true) },
            effect: { sim, id in sim.adjust(id) { c in c.techs.insert(.smartGrid) } },
            aiInterest: { sim, id in
                let c = sim.state.countries[id]
                return (c?.resourceCoverage[.oil] ?? 1) < 0.9 || (c?.resourceCoverage[.gas] ?? 1) < 0.9 ? 2 : 0.6
            }),
        ProjectDefinition(
            id: "fondsSouverain", name: "Fonds souverain", icon: "banknote.fill", category: .economy,
            detail: "Les revenus des matières premières remboursent 15 % de la dette publique.", months: 12, cost: 0,
            available: { sim, id in
                guard let c = sim.state.countries[id] else { return false }
                return c.tradeBalance * 12 > c.gdp * 0.05
            },
            effect: { sim, id in sim.adjust(id) { c in c.debt *= 0.85 } },
            aiInterest: { _, _ in 3 }),
        ProjectDefinition(
            id: "agriculture", name: "Révolution agricole", icon: "leaf.fill", category: .economy,
            detail: "Production agricole +25 % : moins de pénuries alimentaires.", months: 18, cost: 0.008,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in c.resourceProduction[.food] = (c.resourceProduction[.food] ?? 0) * 1.25 }
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.resourceCoverage[.food] ?? 1) < 0.95 ? 2.5 : 0.3 }),
        ProjectDefinition(
            id: "spatial", name: "Programme spatial", icon: "sparkles", category: .economy,
            detail: "Fusées et satellites : technologie +0,04, influence +20, satellites militaires offerts.", months: 36, cost: 0.02,
            available: { sim, id in (sim.state.countries[id]?.tech ?? 0) >= 0.7 },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.tech += 0.04
                    c.influence = min(100, c.influence + 20)
                    c.techs.insert(.militarySatellites)
                }
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.gdp ?? 0) > 1500 ? 1.5 : 0.2 }),

        // MARK: Défense
        ProjectDefinition(
            id: "industrieDefense", name: "Économie de défense", icon: "shield.checkered", category: .military,
            detail: "+25 % d'usines militaires et +15 % de chantiers navals.", months: 18, cost: 0.012,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.militaryFactories *= 1.25
                    c.dockyards *= 1.15
                }
            },
            aiInterest: { sim, id in sim.isAtWar(id) || sim.state.warPlans.contains { $0.target == id } ? 4 : 0.5 }),
        ProjectDefinition(
            id: "modernisation", name: "Modernisation des armées", icon: "scope", category: .military,
            detail: "Préparation au maximum, expérience +10 points et technologie Armée professionnelle.", months: 24, cost: 0.012,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.readiness = 1
                    c.experience = min(1, c.experience + 0.1)
                    c.techs.insert(.professionalArmy)
                }
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.aggressiveness ?? 0) > 0.3 ? 2 : 0.7 }),
        ProjectDefinition(
            id: "drones", name: "Doctrine des drones", icon: "airplane", category: .military,
            detail: "Fabrication de masse : stock de drones ×2,5 et technologie Drones autonomes.", months: 12, cost: 0.006,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.equipment[.drone] = max(c.stock(.drone) * 2.5, c.gdp * 2)
                    c.techs.insert(.autonomousDrones)
                }
            },
            aiInterest: { sim, id in sim.isAtWar(id) ? 4 : 0.6 }),
        ProjectDefinition(
            id: "bouclier", name: "Bouclier antimissile", icon: "shield.lefthalf.filled", category: .military,
            detail: "Défense antimissile nationale et 300 missiles d'interception.", months: 24, cost: 0.01,
            available: { sim, id in !(sim.state.countries[id]?.has(.missileDefense) ?? true) },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.techs.insert(.missileDefense)
                    c.equipment[.missile] = c.stock(.missile) + 300
                }
            },
            aiInterest: { sim, id in sim.strongestRival(of: id) != nil ? 1.5 : 0.3 }),
        ProjectDefinition(
            id: "marine", name: "Marine de haute mer", icon: "ferry.fill", category: .military,
            detail: "+40 % de chantiers navals et 4 navires de guerre.", months: 30, cost: 0.015,
            available: { sim, id in (sim.state.countries[id]?.gdp ?? 0) > 300 },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.dockyards = c.dockyards * 1.4 + 1
                    c.equipment[.warship] = c.stock(.warship) + 4
                }
            },
            aiInterest: { _, _ in 0.6 }),
        ProjectDefinition(
            id: "reserve", name: "Garde nationale", icon: "person.3.fill", category: .military,
            detail: "Réserve militaire augmentée de 50 % des effectifs d'active.", months: 12, cost: 0.004,
            available: { _, _ in true },
            effect: { sim, id in sim.adjust(id) { c in c.reservePersonnel += c.activePersonnel * 0.5 } },
            aiInterest: { sim, id in sim.state.warPlans.contains { $0.target == id } ? 5 : 0.5 }),
        ProjectDefinition(
            id: "nucleaire", name: "Programme nucléaire militaire", icon: "atom", category: .military,
            detail: "En 4 ans : 20 ogives nucléaires. Les puissances occidentales vous sanctionnent dès le lancement.",
            months: 48, cost: 0.03,
            available: { sim, id in
                guard let c = sim.state.countries[id] else { return false }
                return c.nuclearWarheads == 0 && c.tech >= 0.45 && c.gdp > 50
            },
            effect: { sim, id in
                sim.adjust(id) { c in c.nuclearWarheads += 20 }
                sim.addEvent("☢️ \(sim.name(id)) annonce son premier essai nucléaire.", important: true)
                sim.state.worldTension = min(100, sim.state.worldTension + 15)
            },
            aiInterest: { sim, id in
                guard let c = sim.state.countries[id], c.aggressiveness >= 0.35 else { return 0 }
                return sim.strongestRival(of: id).map { (sim.state.countries[$0]?.nuclearWarheads ?? 0) > 0 ? 1.5 : 0 } ?? 0
            }),
        ProjectDefinition(
            id: "renseignement", name: "Services de renseignement", icon: "eye.fill", category: .military,
            detail: "Renseignement +25 points : espionnage plus efficace, meilleure protection.", months: 12, cost: 0.004,
            available: { sim, id in (sim.state.countries[id]?.intelligence ?? 1) < 0.95 },
            effect: { sim, id in sim.adjust(id) { c in c.intelligence = min(1, c.intelligence + 0.25) } },
            aiInterest: { _, _ in 0.8 }),

        // MARK: Société et diplomatie
        ProjectDefinition(
            id: "reformeSociale", name: "Grande réforme sociale", icon: "heart.fill", category: .politics,
            detail: "Santé, logement, retraites : soutien +12 points et stabilité +5 pendant 3 ans.", months: 18, cost: 0.02,
            available: { _, _ in true },
            effect: { sim, id in sim.addModifier(id, "Réforme sociale", stability: 0.05, support: 0.12, months: 36) },
            aiInterest: { sim, id in (sim.state.countries[id]?.support ?? 1) < 0.4 ? 2.5 : 0.5 }),
        ProjectDefinition(
            id: "anticorruption", name: "Lutte contre la corruption", icon: "checkmark.shield.fill", category: .politics,
            detail: "Stabilité +10 points de façon durable, croissance +0,2 pt.", months: 24, cost: 0.004,
            available: { _, _ in true },
            effect: { sim, id in
                sim.adjust(id) { c in c.stabilityBase += 0.1 }
                sim.addModifier(id, "Institutions assainies", growth: 0.002, months: 60)
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.stability ?? 1) < 0.45 ? 2.5 : 0.4 }),
        ProjectDefinition(
            id: "unionNationale", name: "Union nationale", icon: "flag.fill", category: .politics,
            detail: "Gouvernement d'union : soutien +8, lassitude de guerre −30 points.", months: 6, cost: 0,
            available: { sim, id in sim.isAtWar(id) },
            effect: { sim, id in
                sim.adjust(id) { c in c.warExhaustion = max(0, c.warExhaustion - 0.3) }
                sim.addModifier(id, "Union nationale", support: 0.08, months: 18)
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.warExhaustion ?? 0) > 0.4 ? 5 : 0 }),
        ProjectDefinition(
            id: "reconciliation", name: "Réconciliation nationale", icon: "hands.sparkles.fill", category: .politics,
            detail: "Négociations et amnistie : les rebelles perdent la moitié de leurs territoires.", months: 12, cost: 0.005,
            available: { sim, id in (sim.state.countries[id]?.civilWar ?? 0) > 0 },
            effect: { sim, id in
                sim.adjust(id) { c in
                    c.civilWar *= 0.5
                    c.rebelStrength *= 0.5
                    c.stabilityBase += 0.05
                }
            },
            aiInterest: { _, _ in 5 }),
        ProjectDefinition(
            id: "softPower", name: "Rayonnement culturel", icon: "music.note.house.fill", category: .politics,
            detail: "Cinéma, universités, médias : relations +6 avec tous les pays et influence +15.", months: 24, cost: 0.006,
            available: { _, _ in true },
            effect: { sim, id in
                for other in sim.countryIDs where other != id { sim.changeRelation(id, other, by: 6) }
                sim.adjust(id) { c in c.influence = min(100, c.influence + 15) }
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.gdp ?? 0) > 1000 ? 1 : 0.3 }),
        ProjectDefinition(
            id: "voisinage", name: "Politique de bon voisinage", icon: "person.2.wave.2.fill", category: .politics,
            detail: "Relations +20 avec tous vos voisins.", months: 12, cost: 0.002,
            available: { sim, id in !(sim.state.countries[id]?.neighbors.isEmpty ?? true) },
            effect: { sim, id in
                for n in sim.state.countries[id]?.neighbors ?? [] where !sim.enemies(of: id).contains(n) {
                    sim.changeRelation(id, n, by: 20)
                }
            },
            aiInterest: { sim, id in (sim.state.countries[id]?.aggressiveness ?? 0) < 0.3 ? 1.2 : 0.2 }),
        ProjectDefinition(
            id: "democratie", name: "Transition démocratique", icon: "building.columns.fill", category: .politics,
            detail: "Constitution, élections libres : le régime devient une démocratie, relations +15 avec les démocraties.",
            months: 24, cost: 0.004,
            available: { sim, id in sim.state.countries[id]?.government != .democracy },
            effect: { sim, id in
                _ = sim.reformRegime(for: id, democratize: true)
                if sim.state.countries[id]?.government != .democracy {
                    _ = sim.reformRegime(for: id, democratize: true)
                }
            },
            aiInterest: { _, _ in 0.1 }),
        ProjectDefinition(
            id: "emprunt", name: "Restructuration de la dette", icon: "percent", category: .politics,
            detail: "Accord avec les créanciers : dette −20 %, mais relations −10 avec les grandes économies.",
            months: 9, cost: 0,
            available: { sim, id in
                guard let c = sim.state.countries[id] else { return false }
                return c.debt / max(c.gdp, 1) > 0.9
            },
            effect: { sim, id in
                sim.adjust(id) { c in c.debt *= 0.8 }
                for big in ["USA", "CHN", "DEU", "JPN", "FRA", "GBR"] where big != id {
                    sim.changeRelation(id, big, by: -10)
                }
            },
            aiInterest: { sim, id in
                guard let c = sim.state.countries[id] else { return 0 }
                return c.interestRate > 0.08 ? 3 : 0.3
            })
    ]
}

extension Simulation {

    func availableProjects(for id: CountryID) -> [ProjectDefinition] {
        guard let c = state.countries[id] else { return [] }
        return ProjectCatalog.all.filter { !c.completedProjects.contains($0.id) && $0.available(self, id) }
    }

    mutating func startProject(_ projectID: String, for id: CountryID) -> ActionResult {
        guard let c = state.countries[id], let def = ProjectCatalog.find(projectID) else {
            return ActionResult(success: false, message: "Projet introuvable.")
        }
        guard c.activeProject == nil else {
            return ActionResult(success: false, message: "Un projet est déjà en cours.")
        }
        guard def.available(self, id), !c.completedProjects.contains(projectID) else {
            return ActionResult(success: false, message: "Ce projet n'est pas disponible.")
        }
        state.countries[id]?.activeProject = ActiveProject(id: projectID, monthsLeft: def.months, totalMonths: def.months)
        if projectID == "nucleaire" {
            for s in WorldRelations.westernSanctioners + WorldRelations.europeanUnion where s != id {
                addTreaty(.sanctions, s, id)
                changeRelation(id, s, by: -25)
            }
            state.worldTension = min(100, state.worldTension + 8)
            addEvent("☢️ \(c.name) lance un programme nucléaire militaire. Sanctions occidentales.", important: true)
        }
        return ActionResult(success: true, message: "Projet lancé : \(def.name) (\(def.months) mois).")
    }

    mutating func cancelProject(for id: CountryID) {
        state.countries[id]?.activeProject = nil
    }

    /// Chaque mois : paiement, avancement, achèvement. L'IA choisit ses projets.
    mutating func monthlyProjects(_ id: CountryID) {
        guard let c = state.countries[id] else { return }
        if var active = c.activeProject, let def = ProjectCatalog.find(active.id) {
            let monthlyCost = effectiveGDP(id) * def.cost / Double(max(1, def.months))
            state.countries[id]?.debt += monthlyCost
            active.monthsLeft -= 1
            if active.monthsLeft <= 0 {
                state.countries[id]?.activeProject = nil
                state.countries[id]?.completedProjects.insert(def.id)
                def.effect(&self, id)
                if id == state.playerID {
                    addEvent("🏗️ Projet terminé : \(def.name).", important: true)
                } else if (state.countries[id]?.gdp ?? 0) > 800 {
                    addEvent("\(c.name) achève : \(def.name).")
                }
            } else {
                state.countries[id]?.activeProject = active
            }
            return
        }
        guard id != state.playerID else { return }
        // IA : un nouveau projet de temps en temps, selon ses besoins.
        guard Double.random(in: 0...1, using: &state.rng) < 0.15 else { return }
        let options = availableProjects(for: id)
        guard !options.isEmpty else { return }
        let weights = options.map { max(0, $0.aiInterest(self, id)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return }
        var roll = Double.random(in: 0..<total, using: &state.rng)
        for (i, option) in options.enumerated() {
            roll -= weights[i]
            if roll <= 0 {
                _ = startProject(option.id, for: id)
                break
            }
        }
    }
}
