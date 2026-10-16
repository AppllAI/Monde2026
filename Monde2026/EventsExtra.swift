import Foundation

// =============================================================
//  EventsExtra.swift
//  Événements supplémentaires à choix, et grands rendez-vous
//  prévus du calendrier mondial (Coupe du monde, JO…).
// =============================================================

extension EventCatalog {

    static let extra: [EventDefinition] = [
        EventDefinition(
            id: "farmers", title: "Colère des agriculteurs", icon: "cart.fill", isBad: true, worldwide: false,
            monthlyChance: 0.03,
            trigger: { sim, id in ((sim.state.prices[.food] ?? 1) < 0.95 || (sim.state.countries[id]?.inflation ?? 0) > 0.04, nil) },
            text: { _, _ in "Des milliers de tracteurs bloquent les autoroutes et la capitale. Les agriculteurs dénoncent des revenus en chute libre." },
            options: [
                EventOption(label: "Aides d'urgence", detail: "0,2 % du PIB, soutien +0,03", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.002)
                    sim.adjust(e.country) { c in c.support += 0.03 }
                },
                EventOption(label: "Laisser passer la colère", detail: "Stabilité −0,04 pendant 3 mois", aiWeight: 1) { sim, e in
                    sim.addModifier(e.country, "Blocages agricoles", growth: -0.004, stability: -0.04, months: 3)
                }
            ]),

        EventDefinition(
            id: "rareEarths", title: "Gisement de terres rares", icon: "diamond.fill", isBad: false, worldwide: false,
            monthlyChance: 0.008,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Un gisement de métaux critiques d'ampleur mondiale est découvert. Les géants de l'industrie se pressent." },
            options: [
                EventOption(label: "Exploitation nationale", detail: "Production de métaux critiques fortement accrue", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.resourceProduction[.criticalMinerals] = (c.resourceProduction[.criticalMinerals] ?? 0) + 1.2
                    }
                },
                EventOption(label: "Concession à un allié", detail: "Recettes de 0,5 % du PIB, relation +20 avec votre meilleur ami", aiWeight: 1) { sim, e in
                    let newValue_debt = sim.effectiveGDP(e.country) * 0.005
                    sim.state.countries[e.country]?.debt -= newValue_debt
                    if let f = sim.closestFriend(of: e.country) { sim.changeRelation(e.country, f, by: 20) }
                }
            ]),

        EventDefinition(
            id: "brainDrain", title: "Fuite des cerveaux", icon: "airplane.departure", isBad: true, worldwide: false,
            monthlyChance: 0.03,
            trigger: { sim, id in
                guard let c = sim.state.countries[id] else { return (false, nil) }
                return (c.unemployment > 0.09 || c.stability < 0.4, nil)
            },
            text: { _, _ in "Ingénieurs, médecins et chercheurs partent en masse vers l'étranger." },
            options: [
                EventOption(label: "Programme pour les retenir", detail: "0,1 % du PIB", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.001)
                },
                EventOption(label: "Laisser faire", detail: "Technologie −0,01", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in c.tech = max(0.05, c.tech - 0.01) }
                }
            ]),

        EventDefinition(
            id: "terror", title: "Attentat terroriste", icon: "exclamationmark.octagon.fill", isBad: true, worldwide: false,
            monthlyChance: 0.015,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Un attentat frappe la capitale. Le pays est sous le choc et l'opposition réclame des mesures fortes." },
            options: [
                EventOption(label: "Unité nationale", detail: "Soutien +0,05 pendant 6 mois", aiWeight: 2) { sim, e in
                    sim.addModifier(e.country, "Unité après l'attentat", support: 0.05, months: 6)
                },
                EventOption(label: "État d'urgence", detail: "Stabilité +0,05, libertés restreintes", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.stability += 0.05
                        if c.freedom == .open { c.freedom = .restricted }
                    }
                }
            ]),

        EventDefinition(
            id: "leak", title: "Fuite de documents secrets", icon: "doc.on.doc.fill", isBad: true, worldwide: false,
            monthlyChance: 0.02,
            trigger: { sim, id in
                let f = sim.closestFriend(of: id)
                return (f != nil, f)
            },
            text: { sim, e in "Des câbles diplomatiques publiés en ligne révèlent que nous espionnions \(sim.name(e.target ?? ""))." },
            options: [
                EventOption(label: "Présenter des excuses", detail: "Relation −5, influence −5", aiWeight: 2) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -5) }
                    sim.adjust(e.country) { c in c.influence = max(0, c.influence - 5) }
                },
                EventOption(label: "Nier en bloc", detail: "Relation −15", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -15) }
                }
            ]),

        EventDefinition(
            id: "stateVisit", title: "Visite d'État", icon: "airplane.arrival", isBad: false, worldwide: false,
            monthlyChance: 0.04,
            trigger: { sim, id in
                let f = sim.closestFriend(of: id)
                return (f != nil, f)
            },
            text: { sim, e in "Le chef d'État de \(sim.name(e.target ?? "")) propose une visite officielle en grande pompe." },
            options: [
                EventOption(label: "Accueil grandiose", detail: "Relation +15, influence +5", aiWeight: 2) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: 15) }
                    sim.adjust(e.country) { c in c.influence = min(100, c.influence + 5) }
                },
                EventOption(label: "Visite de travail discrète", detail: "Relation +5", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: 5) }
                }
            ]),

        EventDefinition(
            id: "blackout", title: "Panne d'électricité géante", icon: "bolt.slash.fill", isBad: true, worldwide: false,
            monthlyChance: 0.02,
            trigger: { sim, id in ((sim.state.countries[id]?.infrastructure ?? 1) < 0.7, nil) },
            text: { _, _ in "Une panne plonge la moitié du pays dans le noir pendant deux jours." },
            options: [
                EventOption(label: "Moderniser le réseau", detail: "0,3 % du PIB, infrastructures +2", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.003)
                    sim.adjust(e.country) { c in c.infrastructure = min(1, c.infrastructure + 0.02) }
                },
                EventOption(label: "Réparations minimales", detail: "Croissance −0,5 pt pendant 3 mois", aiWeight: 1) { sim, e in
                    sim.addModifier(e.country, "Réseau électrique fragile", growth: -0.005, months: 3)
                }
            ]),

        EventDefinition(
            id: "students", title: "Révolte étudiante", icon: "graduationcap.fill", isBad: true, worldwide: false,
            monthlyChance: 0.04,
            trigger: { sim, id in
                guard let c = sim.state.countries[id] else { return (false, nil) }
                return (c.freedom != .open && c.support < 0.5, nil)
            },
            text: { _, _ in "Les universités sont occupées. Les étudiants réclament plus de libertés et la fin de la censure." },
            options: [
                EventOption(label: "Ouvrir le dialogue", detail: "Libertés élargies, soutien +0,04", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.freedom = c.freedom == .repressed ? .restricted : .open
                        c.support += 0.04
                    }
                },
                EventOption(label: "Disperser les manifestants", detail: "Stabilité +0,03, soutien −0,06, démocraties mécontentes", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.stability += 0.03
                        c.support -= 0.06
                    }
                    for other in sim.countryIDs where sim.state.countries[other]?.government == .democracy {
                        sim.changeRelation(e.country, other, by: -3)
                    }
                }
            ]),

        EventDefinition(
            id: "sportsWin", title: "Victoire sportive historique", icon: "trophy.fill", isBad: false, worldwide: false,
            monthlyChance: 0.02,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "L'équipe nationale remporte un titre mondial. Le pays entier descend dans la rue pour fêter ça." },
            options: [
                EventOption(label: "Recevoir les champions", detail: "Soutien +0,05 pendant 6 mois", aiWeight: 2) { sim, e in
                    sim.addModifier(e.country, "Fierté nationale", support: 0.05, months: 6)
                }
            ]),

        EventDefinition(
            id: "gasDeal", title: "Contrat gazier géant", icon: "flame.fill", isBad: false, worldwide: false,
            monthlyChance: 0.03,
            trigger: { sim, id in
                guard let c = sim.state.countries[id], (c.resourceCoverage[.gas] ?? 1) < 0.95 else { return (false, nil) }
                let seller = sim.countryIDs.first { other in
                    other != id && sim.relation(id, other) > 10 && !sim.areSanctioning(id, other)
                        && (sim.state.countries[other]?.resourceExports[.gas] ?? 0) > 0.5
                }
                return (seller != nil, seller)
            },
            text: { sim, e in "\(sim.name(e.target ?? "")) propose un contrat de livraison de gaz sur vingt ans." },
            options: [
                EventOption(label: "Signer", detail: "Accord commercial et relation +10", aiWeight: 2) { sim, e in
                    guard let t = e.target else { return }
                    sim.addTreaty(.tradePact, e.country, t)
                    sim.changeRelation(e.country, t, by: 10)
                },
                EventOption(label: "Diversifier nos sources", detail: "Rien ne change", aiWeight: 1) { _, _ in }
            ]),

        EventDefinition(
            id: "heatwave", title: "Canicule extrême", icon: "thermometer.sun.fill", isBad: true, worldwide: false,
            monthlyChance: 0.025,
            trigger: { sim, _ in
                let month = Simulation.calendar.component(.month, from: sim.currentDate)
                return ((6...8).contains(month), nil)
            },
            text: { _, _ in "Des températures record mettent à genoux les hôpitaux, les centrales et les récoltes." },
            options: [
                EventOption(label: "Plan canicule", detail: "0,1 % du PIB", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.001)
                },
                EventOption(label: "Laisser les régions gérer", detail: "Soutien −0,04, agriculture −5 %", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support -= 0.04
                        c.resourceProduction[.food] = (c.resourceProduction[.food] ?? 0) * 0.95
                    }
                }
            ]),

        EventDefinition(
            id: "takeover", title: "Rachat d'un champion national", icon: "building.columns.circle.fill", isBad: false,
            worldwide: false, monthlyChance: 0.02,
            trigger: { sim, id in
                let rival = sim.countryIDs.first { other in
                    other != id && (sim.state.countries[other]?.gdp ?? 0) > 2000 && sim.relation(id, other) < 40
                }
                return (rival != nil && (sim.state.countries[id]?.tech ?? 0) > 0.6, rival)
            },
            text: { sim, e in "Un groupe de \(sim.name(e.target ?? "")) veut racheter notre fleuron de l'aéronautique." },
            options: [
                EventOption(label: "Bloquer le rachat", detail: "Relation −10, soutien +0,03", aiWeight: 2) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -10) }
                    sim.adjust(e.country) { c in c.support += 0.03 }
                },
                EventOption(label: "Accepter l'offre", detail: "Recettes de 0,3 % du PIB, relation +10", aiWeight: 1) { sim, e in
                    let newValue_debt = sim.effectiveGDP(e.country) * 0.003
                    sim.state.countries[e.country]?.debt -= newValue_debt
                    if let t = e.target { sim.changeRelation(e.country, t, by: 10) }
                }
            ]),

        EventDefinition(
            id: "borderClash", title: "Incident de frontière", icon: "exclamationmark.triangle.fill", isBad: true,
            worldwide: false, monthlyChance: 0.04,
            trigger: { sim, id in
                guard let c = sim.state.countries[id] else { return (false, nil) }
                let rival = c.neighbors.first { sim.relation(id, $0) < -40 && !sim.enemies(of: id).contains($0) }
                return (rival != nil, rival)
            },
            text: { sim, e in "Des tirs éclatent à la frontière avec \(sim.name(e.target ?? "")). Plusieurs soldats sont tués." },
            options: [
                EventOption(label: "Calmer le jeu", detail: "Relation +5, soutien −0,02", aiWeight: 2) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: 5) }
                    sim.adjust(e.country) { c in c.support -= 0.02 }
                },
                EventOption(label: "Riposter fermement", detail: "Relation −20, tension mondiale +4, soutien +0,03", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -20) }
                    sim.state.worldTension = min(100, sim.state.worldTension + 4)
                    sim.adjust(e.country) { c in c.support += 0.03 }
                }
            ]),

        EventDefinition(
            id: "aiRevolution", title: "Révolution de l'IA", icon: "brain.head.profile", isBad: false, worldwide: false,
            monthlyChance: 0.02,
            trigger: { sim, id in (sim.state.countries[id]?.has(.appliedAI) ?? false, nil) },
            text: { _, _ in "L'intelligence artificielle bouleverse les bureaux et les usines. Productivité record, mais emplois menacés." },
            options: [
                EventOption(label: "Accélérer l'adoption", detail: "Croissance +1 pt pendant 2 ans, chômage +1 pt", aiWeight: 2) { sim, e in
                    sim.addModifier(e.country, "Boom de l'IA", growth: 0.01, months: 24)
                    sim.adjust(e.country) { c in c.unemployment += 0.01 }
                },
                EventOption(label: "Encadrer et protéger", detail: "Croissance +0,4 pt, soutien +0,02", aiWeight: 1) { sim, e in
                    sim.addModifier(e.country, "IA encadrée", growth: 0.004, support: 0.02, months: 24)
                }
            ])
    ]

    /// Grands rendez-vous du calendrier (jour de la partie, texte, pays hôtes, effet sur le soutien).
    static let scheduled: [(id: String, day: Int, text: String, hosts: [CountryID], support: Double)] = [
        ("worldcup2026", 161, "⚽ La Coupe du monde 2026 s'ouvre aux États-Unis, au Canada et au Mexique.", ["USA", "CAN", "MEX"], 0.03),
        ("cop31", 310, "🌍 Conférence mondiale sur le climat (COP31) en Turquie.", ["TUR"], 0.01),
        ("olympics2028", 925, "🏅 Ouverture des Jeux olympiques de Los Angeles.", ["USA"], 0.04),
        ("worldcup2030", 1621, "⚽ Coupe du monde 2030 au Maroc, en Espagne et au Portugal.", ["MAR", "ESP", "PRT"], 0.04),
        ("olympics2032", 2392, "🏅 Jeux olympiques de Brisbane.", ["AUS"], 0.04)
    ]
}

extension Simulation {

    mutating func scheduledNews() {
        for item in EventCatalog.scheduled where state.day >= item.day && !state.firedNews.contains(item.id) {
            state.firedNews.insert(item.id)
            addEvent(item.text, important: item.hosts.contains(state.playerID ?? ""))
            for host in item.hosts where state.countries[host] != nil {
                addModifier(host, "Fierté nationale (grand événement)", support: item.support, months: 4)
            }
        }
    }
}
