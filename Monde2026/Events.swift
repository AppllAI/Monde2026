import Foundation

// =============================================================
//  Events.swift
//  Événements à choix : crises intérieures, opportunités,
//  incidents diplomatiques, et grands chocs mondiaux.
//  Le joueur choisit ; l'IA prend l'option la plus raisonnable.
// =============================================================

struct PendingEvent: Codable, Identifiable {
    let id: Int
    let definitionID: String
    let country: CountryID
    let target: CountryID?
    let day: Int
}

struct EventOption {
    let label: String
    let detail: String
    let aiWeight: Double
    let apply: (inout Simulation, PendingEvent) -> Void
}

struct EventDefinition {
    let id: String
    let title: String
    let icon: String
    let isBad: Bool
    let worldwide: Bool
    let monthlyChance: Double
    /// Renvoie nil si l'événement ne peut pas arriver ; sinon (true, cible éventuelle).
    let trigger: (Simulation, CountryID) -> (Bool, CountryID?)
    let text: (Simulation, PendingEvent) -> String
    let options: [EventOption]
}

extension Simulation {

    // MARK: Moteur des événements

    mutating func monthlyEvents() {
        // Le temps ne s'arrête pas : une décision laissée en suspens 30 jours est prise par le gouvernement.
        for pending in state.pendingEvents where state.day - pending.day >= 30 {
            guard let def = definition(for: pending), let first = def.options.first else {
                state.pendingEvents.removeAll { $0.id == pending.id }
                continue
            }
            resolveEvent(pending.id, option: 0)
            if pending.country == state.playerID {
                addEvent("🏛️ Sans réponse de votre part, le gouvernement a tranché (\(def.title)) : \(first.label).", important: false)
            }
        }
        // Grands chocs mondiaux : touchent tout le monde.
        for def in EventCatalog.all where def.worldwide {
            guard state.day > 60, def.trigger(self, "").0 else { continue }
            guard Double.random(in: 0...1, using: &state.rng) < def.monthlyChance else { continue }
            for id in countryIDs where id != state.playerID {
                let pending = PendingEvent(id: 0, definitionID: def.id, country: id, target: nil, day: state.day)
                if let best = def.options.max(by: { $0.aiWeight < $1.aiWeight }) {
                    best.apply(&self, pending)
                }
            }
            addEvent("🌍 \(def.title)", important: true)
            if let p = state.playerID { queueEvent(def.id, for: p, target: nil) }
            return
        }

        // Événements nationaux du joueur (au plus un par mois).
        guard let p = state.playerID, !state.pendingEvents.contains(where: { $0.country == p }) else { return }
        let factor = state.difficulty.badEventFactor
        var candidates = EventCatalog.all.filter { !$0.worldwide && $0.monthlyChance > 0 }
        candidates.shuffle(using: &state.rng)
        for def in candidates {
            let (ok, target) = def.trigger(self, p)
            guard ok else { continue }
            let chance = def.monthlyChance * (def.isBad ? factor : 1)
            if Double.random(in: 0...1, using: &state.rng) < chance {
                queueEvent(def.id, for: p, target: target)
                return
            }
        }
    }

    mutating func queueEvent(_ definitionID: String, for country: CountryID, target: CountryID?) {
        state.pendingEvents.append(PendingEvent(id: state.nextPendingEventID, definitionID: definitionID,
                                                country: country, target: target, day: state.day))
        state.nextPendingEventID += 1
    }

    func definition(for pending: PendingEvent) -> EventDefinition? {
        EventCatalog.all.first { $0.id == pending.definitionID }
    }

    mutating func resolveEvent(_ eventID: Int, option index: Int) {
        guard let pending = state.pendingEvents.first(where: { $0.id == eventID }) else { return }
        state.pendingEvents.removeAll { $0.id == eventID }
        guard let def = definition(for: pending), def.options.indices.contains(index) else { return }
        def.options[index].apply(&self, pending)
    }

    // MARK: Petits outils pour les effets

    mutating func adjust(_ id: CountryID, _ body: (inout Country) -> Void) {
        guard var c = state.countries[id] else { return }
        body(&c)
        c.stability = c.stability.clamped(0.02, 0.98)
        c.support = c.support.clamped(0.02, 0.98)
        state.countries[id] = c
    }

    mutating func spendShareOfGDP(_ id: CountryID, _ share: Double) {
        let amount = effectiveGDP(id) * share
        state.countries[id]?.debt += amount
    }

    func strongestRival(of id: CountryID) -> CountryID? {
        countryIDs.filter { $0 != id && relation(id, $0) < -30 }.max { militaryPower($0) < militaryPower($1) }
    }

    func closestFriend(of id: CountryID) -> CountryID? {
        countryIDs.filter { $0 != id && relation(id, $0) > 40 }.max { relation(id, $0) < relation(id, $1) }
    }
}

// MARK: - Catalogue

enum EventCatalog {

    static let all: [EventDefinition] = national + worldwide + extra

    // MARK: Événements nationaux

    static let national: [EventDefinition] = [
        EventDefinition(
            id: "strikes", title: "Grève générale", icon: "person.3.fill", isBad: true, worldwide: false,
            monthlyChance: 0.06,
            trigger: { sim, id in
                guard let c = sim.state.countries[id] else { return (false, nil) }
                return (c.inflation > 0.05 || c.unemployment > c.naturalUnemployment + 0.02, nil)
            },
            text: { _, _ in "Les syndicats paralysent le pays : transports, ports et raffineries sont à l'arrêt. Ils réclament des hausses de salaires." },
            options: [
                EventOption(label: "Négocier des hausses de salaires", detail: "Soutien +, dépenses sociales +1 pt, inflation +", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support += 0.05
                        c.budget.social += 0.01
                        c.inflation += 0.01
                    }
                },
                EventOption(label: "Tenir bon", detail: "Croissance −0,5 pt pendant 3 mois, stabilité −", aiWeight: 1) { sim, e in
                    sim.addModifier(e.country, "Grève générale", growth: -0.02, stability: -0.04, months: 3)
                },
                EventOption(label: "Réquisitionner les grévistes", detail: "Stabilité +, soutien −−", aiWeight: 0.5) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support -= 0.08
                        c.stability += 0.03
                    }
                }
            ]),

        EventDefinition(
            id: "scandal", title: "Scandale de corruption", icon: "newspaper.fill", isBad: true, worldwide: false,
            monthlyChance: 0.03,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Une enquête de presse révèle des pots-de-vin versés à plusieurs ministres par un grand groupe industriel." },
            options: [
                EventOption(label: "Limoger les ministres", detail: "Soutien −0,03, stabilité +0,02", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support -= 0.03
                        c.stability += 0.02
                    }
                },
                EventOption(label: "Étouffer l'affaire", detail: "Soutien −0,08 si ça fuite (une chance sur deux)", aiWeight: 1) { sim, e in
                    if Double.random(in: 0...1, using: &sim.state.rng) < 0.5 {
                        sim.adjust(e.country) { c in c.support -= 0.08 }
                        sim.addEvent("L'affaire étouffée a fuité dans la presse.", important: e.country == sim.state.playerID)
                    }
                }
            ]),

        EventDefinition(
            id: "breakthrough", title: "Percée scientifique", icon: "atom", isBad: false, worldwide: false,
            monthlyChance: 0.04,
            trigger: { sim, id in ((sim.state.countries[id]?.budget.research ?? 0) > 0.015, nil) },
            text: { _, _ in "Un laboratoire national annonce une découverte majeure. Industriels étrangers et agences publiques se bousculent." },
            options: [
                EventOption(label: "Financer la suite", detail: "+300 points de recherche, 0,1 % du PIB", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.001)
                    sim.state.countries[e.country]?.researchProgress += 300
                },
                EventOption(label: "Vendre la licence", detail: "Recettes de 0,2 % du PIB", aiWeight: 1) { sim, e in
                    let gain = sim.effectiveGDP(e.country) * 0.002
                    sim.state.countries[e.country]?.debt -= gain
                }
            ]),

        EventDefinition(
            id: "disaster", title: "Catastrophe naturelle", icon: "tornado", isBad: true, worldwide: false,
            monthlyChance: 0.025,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Inondations et glissements de terrain ravagent plusieurs régions. Des dizaines de milliers de sinistrés attendent l'aide de l'État." },
            options: [
                EventOption(label: "Plan d'aide massif", detail: "0,5 % du PIB, soutien +0,05", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.005)
                    sim.adjust(e.country) { c in c.support += 0.05 }
                },
                EventOption(label: "Aide minimale", detail: "Soutien −0,06, stabilité −0,03", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support -= 0.06
                        c.stability -= 0.03
                    }
                }
            ]),

        EventDefinition(
            id: "refugees", title: "Afflux de réfugiés", icon: "figure.walk", isBad: true, worldwide: false,
            monthlyChance: 0.08,
            trigger: { sim, id in
                guard let c = sim.state.countries[id] else { return (false, nil) }
                let source = c.neighbors.first { sim.isAtWar($0) || (sim.state.countries[$0]?.civilWar ?? 0) > 0.1 }
                return (source != nil && !sim.isAtWar(id), source)
            },
            text: { sim, e in "Des centaines de milliers de personnes fuient les combats en \(sim.name(e.target ?? "")) et se pressent à notre frontière." },
            options: [
                EventOption(label: "Les accueillir", detail: "Soutien −0,04, relations +15 avec ce pays, image +", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support -= 0.04
                        c.population += 0.3
                    }
                    if let t = e.target { sim.changeRelation(e.country, t, by: 15) }
                },
                EventOption(label: "Fermer la frontière", detail: "Soutien +0,02, relations −10 avec ce pays", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in c.support += 0.02 }
                    if let t = e.target { sim.changeRelation(e.country, t, by: -10) }
                }
            ]),

        EventDefinition(
            id: "inflation", title: "Flambée des prix", icon: "chart.line.uptrend.xyaxis", isBad: true, worldwide: false,
            monthlyChance: 0.15,
            trigger: { sim, id in ((sim.state.countries[id]?.inflation ?? 0) > 0.08, nil) },
            text: { sim, e in "L'inflation atteint \(Fmt.pct(sim.state.countries[e.country]?.inflation ?? 0)). La banque centrale attend votre feu vert pour agir." },
            options: [
                EventOption(label: "Relever fortement les taux", detail: "Inflation −40 %, croissance −1,5 pt pendant 12 mois", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.inflation *= 0.6
                        c.inflationAnchor *= 0.6
                    }
                    sim.addModifier(e.country, "Taux d'intérêt élevés", growth: -0.015, months: 12)
                },
                EventOption(label: "Laisser filer", detail: "Inflation +2 pts, soutien −0,04", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.inflation += 0.02
                        c.support -= 0.04
                    }
                }
            ]),

        EventDefinition(
            id: "bubble", title: "Bulle immobilière", icon: "building.2.crop.circle", isBad: true, worldwide: false,
            monthlyChance: 0.05,
            trigger: { sim, id in ((sim.state.countries[id]?.growth ?? 0) > 0.045, nil) },
            text: { _, _ in "Les prix de l'immobilier ont doublé en trois ans. Les banques prêtent sans compter." },
            options: [
                EventOption(label: "Dégonfler la bulle", detail: "Croissance −1 pt pendant 6 mois", aiWeight: 2) { sim, e in
                    sim.addModifier(e.country, "Resserrement du crédit", growth: -0.01, months: 6)
                },
                EventOption(label: "Laisser courir", detail: "Une chance sur trois de krach (−5 pts pendant 12 mois)", aiWeight: 1) { sim, e in
                    if Double.random(in: 0...1, using: &sim.state.rng) < 0.33 {
                        sim.addModifier(e.country, "Krach immobilier", growth: -0.05, stability: -0.05, months: 12)
                        sim.addEvent("La bulle immobilière a éclaté.", important: e.country == sim.state.playerID)
                    } else {
                        sim.addModifier(e.country, "Euphorie immobilière", growth: 0.005, months: 6)
                    }
                }
            ]),

        EventDefinition(
            id: "peaceProtests", title: "Manifestations pour la paix", icon: "hand.raised.fill", isBad: true, worldwide: false,
            monthlyChance: 0.2,
            trigger: { sim, id in (sim.isAtWar(id) && (sim.state.countries[id]?.warExhaustion ?? 0) > 0.4, nil) },
            text: { _, _ in "Des foules immenses exigent la fin de la guerre. Des familles de soldats mènent les cortèges." },
            options: [
                EventOption(label: "Promettre des négociations", detail: "Soutien +0,04, lassitude de guerre −0,05", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.support += 0.04
                        c.warExhaustion = max(0, c.warExhaustion - 0.05)
                    }
                },
                EventOption(label: "Ignorer", detail: "Stabilité −0,05", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in c.stability -= 0.05 }
                },
                EventOption(label: "Interdire les rassemblements", detail: "Stabilité +0,03, soutien −0,07", aiWeight: 0.5) { sim, e in
                    sim.adjust(e.country) { c in
                        c.stability += 0.03
                        c.support -= 0.07
                    }
                }
            ]),

        EventDefinition(
            id: "armsDeal", title: "Contrat d'armement", icon: "shippingbox.fill", isBad: false, worldwide: false,
            monthlyChance: 0.04,
            trigger: { sim, id in
                guard let c = sim.state.countries[id], c.militaryFactories > 20 else { return (false, nil) }
                return (true, sim.closestFriend(of: id))
            },
            text: { sim, e in "\(sim.name(e.target ?? "")) veut acheter une partie de nos stocks de matériel militaire." },
            options: [
                EventOption(label: "Vendre", detail: "5 % de vos blindés et de votre artillerie, recettes, relation +15", aiWeight: 2) { sim, e in
                    guard let t = e.target else { return }
                    _ = sim.sendMilitaryAid(from: e.country, to: t, share: 0.05)
                    let gain = sim.effectiveGDP(e.country) * 0.002
                    sim.state.countries[e.country]?.debt -= gain
                },
                EventOption(label: "Refuser", detail: "Relation −5", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -5) }
                }
            ]),

        EventDefinition(
            id: "cyberIncident", title: "Cyberattaque contre nos réseaux", icon: "network.badge.shield.half.filled", isBad: true,
            worldwide: false, monthlyChance: 0.04,
            trigger: { sim, id in
                guard let rival = sim.strongestRival(of: id), sim.state.countries[rival]?.has(.cyberWarfare) ?? false else {
                    return (false, nil)
                }
                return (true, rival)
            },
            text: { sim, e in "Hôpitaux et réseau électrique sont touchés. Nos services pointent \(sim.name(e.target ?? ""))." },
            options: [
                EventOption(label: "Renforcer nos défenses", detail: "0,1 % du PIB, l'économie récupère vite", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.001)
                    sim.addModifier(e.country, "Cyberattaque", growth: -0.003, months: 2)
                },
                EventOption(label: "Accuser publiquement", detail: "Relation −20, tension mondiale +3", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -20) }
                    sim.state.worldTension = min(100, sim.state.worldTension + 3)
                    sim.addModifier(e.country, "Cyberattaque", growth: -0.006, months: 3)
                }
            ]),

        EventDefinition(
            id: "deposit", title: "Découverte d'un gisement", icon: "drop.fill", isBad: false, worldwide: false,
            monthlyChance: 0.01,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Des géologues confirment un important gisement d'hydrocarbures sur notre territoire." },
            options: [
                EventOption(label: "Exploiter au plus vite", detail: "Production de pétrole et de gaz en hausse, croissance +", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.resourceProduction[.oil] = (c.resourceProduction[.oil] ?? 0) + 1.5
                        c.resourceProduction[.gas] = (c.resourceProduction[.gas] ?? 0) + 0.8
                    }
                },
                EventOption(label: "Protéger la région", detail: "Soutien +0,02", aiWeight: 0.5) { sim, e in
                    sim.adjust(e.country) { c in c.support += 0.02 }
                }
            ]),

        EventDefinition(
            id: "spy", title: "Espion démasqué", icon: "eye.slash.fill", isBad: true, worldwide: false,
            monthlyChance: 0.03,
            trigger: { sim, id in
                let rival = sim.strongestRival(of: id)
                return (rival != nil, rival)
            },
            text: { sim, e in "Le contre-espionnage arrête un agent de \(sim.name(e.target ?? "")) au ministère de la Défense." },
            options: [
                EventOption(label: "Expulser leurs diplomates", detail: "Relation −15, soutien +0,02", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -15) }
                    sim.adjust(e.country) { c in c.support += 0.02 }
                },
                EventOption(label: "Négocier un échange discret", detail: "Influence +5", aiWeight: 2) { sim, e in
                    sim.state.countries[e.country]?.influence += 5
                }
            ]),

        EventDefinition(
            id: "summit", title: "Sommet international", icon: "globe", isBad: false, worldwide: false,
            monthlyChance: 0.05,
            trigger: { sim, _ in (sim.state.worldTension > 40, nil) },
            text: { _, _ in "Les grandes puissances se réunissent pour apaiser les tensions. Notre présence est attendue." },
            options: [
                EventOption(label: "Y participer activement", detail: "Influence +10, tension mondiale −5", aiWeight: 2) { sim, e in
                    sim.state.countries[e.country]?.influence += 10
                    sim.state.worldTension = max(0, sim.state.worldTension - 5)
                },
                EventOption(label: "Boycotter", detail: "Soutien +0,02 chez les nationalistes", aiWeight: 0.5) { sim, e in
                    sim.adjust(e.country) { c in c.support += 0.02 }
                }
            ]),

        EventDefinition(
            id: "allyPlea", title: "Un ami appelle à l'aide", icon: "sos", isBad: false, worldwide: false,
            monthlyChance: 0.1,
            trigger: { sim, id in
                guard !sim.isAtWar(id) else { return (false, nil) }
                let friend = sim.countryIDs.first { other in
                    other != id && sim.relation(id, other) > 50 && sim.isAtWar(other)
                }
                return (friend != nil, friend)
            },
            text: { sim, e in "\(sim.name(e.target ?? "")) est en guerre et nous supplie de lui envoyer des armes." },
            options: [
                EventOption(label: "Envoyer du matériel", detail: "8 % de vos stocks terrestres, relation +15", aiWeight: 2) { sim, e in
                    guard let t = e.target else { return }
                    _ = sim.sendMilitaryAid(from: e.country, to: t, share: 0.08)
                },
                EventOption(label: "Refuser", detail: "Relation −15", aiWeight: 1) { sim, e in
                    if let t = e.target { sim.changeRelation(e.country, t, by: -15) }
                }
            ]),

        EventDefinition(
            id: "drought", title: "Sécheresse", icon: "sun.max.fill", isBad: true, worldwide: false,
            monthlyChance: 0.03,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Une sécheresse historique détruit une partie des récoltes." },
            options: [
                EventOption(label: "Importations d'urgence", detail: "0,3 % du PIB", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.003)
                },
                EventOption(label: "Rationner", detail: "Stabilité −0,05, production agricole −10 %", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.stability -= 0.05
                        c.resourceProduction[.food] = (c.resourceProduction[.food] ?? 0) * 0.9
                    }
                }
            ]),

        EventDefinition(
            id: "techBoom", title: "Boom de la tech", icon: "cpu", isBad: false, worldwide: false,
            monthlyChance: 0.03,
            trigger: { sim, id in ((sim.state.countries[id]?.tech ?? 0) > 0.75, nil) },
            text: { _, _ in "Nos jeunes entreprises de l'IA lèvent des milliards. Investisseurs et talents affluent." },
            options: [
                EventOption(label: "Soutenir l'écosystème", detail: "Croissance +0,8 pt pendant 12 mois", aiWeight: 2) { sim, e in
                    sim.addModifier(e.country, "Boom technologique", growth: 0.008, months: 12)
                },
                EventOption(label: "Taxer les profits", detail: "Recettes de 0,3 % du PIB", aiWeight: 1) { sim, e in
                    let gain = sim.effectiveGDP(e.country) * 0.003
                    sim.state.countries[e.country]?.debt -= gain
                }
            ]),

        EventDefinition(
            id: "disinfo", title: "Campagne de désinformation", icon: "exclamationmark.bubble.fill", isBad: true,
            worldwide: false, monthlyChance: 0.08,
            trigger: { sim, id in
                guard let c = sim.state.countries[id], c.government.holdsElections,
                      c.nextElectionDay - sim.state.day < 180, c.nextElectionDay > sim.state.day else { return (false, nil) }
                return (true, sim.strongestRival(of: id))
            },
            text: { _, _ in "À quelques mois des élections, des milliers de faux comptes inondent les réseaux sociaux." },
            options: [
                EventOption(label: "Contre-campagne officielle", detail: "0,05 % du PIB, soutien protégé", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.0005)
                },
                EventOption(label: "Ignorer", detail: "Soutien −0,05", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in c.support -= 0.05 }
                }
            ]),

        EventDefinition(
            id: "separatism", title: "Mouvement séparatiste", icon: "flag.slash.fill", isBad: true, worldwide: false,
            monthlyChance: 0.06,
            trigger: { sim, id in ((sim.state.countries[id]?.stability ?? 1) < 0.4, nil) },
            text: { _, _ in "Une région périphérique proclame son autonomie. Des milices locales prennent les bâtiments officiels." },
            options: [
                EventOption(label: "Accorder l'autonomie", detail: "Stabilité +0,05, soutien −0,04", aiWeight: 2) { sim, e in
                    sim.adjust(e.country) { c in
                        c.stability += 0.05
                        c.support -= 0.04
                    }
                },
                EventOption(label: "Envoyer l'armée", detail: "Risque d'insurrection armée (une chance sur trois)", aiWeight: 1) { sim, e in
                    if Double.random(in: 0...1, using: &sim.state.rng) < 0.33 {
                        sim.adjust(e.country) { c in
                            c.civilWar = max(c.civilWar, 0.05)
                            c.rebelStrength = max(c.rebelStrength, c.landStrengthIndex * 0.3)
                        }
                        sim.addEvent("🔥 La répression tourne à l'insurrection.", important: true)
                    } else {
                        sim.adjust(e.country) { c in c.stability += 0.03 }
                    }
                }
            ]),

        // Déclenché par la politique intérieure (pas de tirage mensuel).
        EventDefinition(
            id: "coup", title: "Tentative de coup d'État", icon: "exclamationmark.shield.fill", isBad: true, worldwide: false,
            monthlyChance: 0,
            trigger: { _, _ in (false, nil) },
            text: { _, _ in "Des blindés encerclent le palais présidentiel. Une partie de l'état-major exige votre départ." },
            options: [
                EventOption(label: "Appeler les unités loyales", detail: "Réussite selon la préparation de l'armée", aiWeight: 2) { sim, e in
                    guard let c = sim.state.countries[e.country] else { return }
                    let chance = (0.4 + c.readiness * 0.4 + c.support * 0.3).clamped(0.2, 0.95)
                    if Double.random(in: 0...1, using: &sim.state.rng) < chance {
                        sim.adjust(e.country) { c in
                            c.stability += 0.1
                            c.readiness *= 0.85
                        }
                        sim.addEvent("Le coup d'État a échoué. Les putschistes sont arrêtés.", important: true)
                    } else {
                        sim.adjust(e.country) { c in
                            c.government = .junta
                            c.freedom = .repressed
                            c.stability = 0.4
                        }
                        sim.addEvent("🪖 Le coup d'État a réussi : l'armée gouverne désormais (vous gardez la main).", important: true)
                    }
                },
                EventOption(label: "Négocier un partage du pouvoir", detail: "L'armée entre au gouvernement : budget militaire +2 pts", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.budget.military += 0.02
                        c.stability += 0.05
                        c.support -= 0.05
                    }
                }
            ])
    ]

    // MARK: Chocs mondiaux

    static let worldwide: [EventDefinition] = [
        EventDefinition(
            id: "pandemic", title: "Nouvelle pandémie mondiale", icon: "allergens", isBad: true, worldwide: true,
            monthlyChance: 0.003,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Un virus respiratoire se répand sur tous les continents. Les hôpitaux saturent." },
            options: [
                EventOption(label: "Confinement strict", detail: "Croissance −4 pts pendant 6 mois, stabilité préservée", aiWeight: 2) { sim, e in
                    sim.addModifier(e.country, "Pandémie (confinement)", growth: -0.04, months: 6)
                },
                EventOption(label: "Rester ouvert", detail: "Croissance −1,5 pt pendant 6 mois, population et stabilité touchées", aiWeight: 1) { sim, e in
                    sim.addModifier(e.country, "Pandémie", growth: -0.015, stability: -0.05, months: 6)
                    sim.adjust(e.country) { c in c.population *= 0.998 }
                }
            ]),

        EventDefinition(
            id: "oilShock", title: "Choc pétrolier", icon: "fuelpump.fill", isBad: true, worldwide: true,
            monthlyChance: 0.004,
            trigger: { sim, _ in ((sim.state.prices[.oil] ?? 1) > 1.2 || sim.state.worldTension > 60, nil) },
            text: { _, _ in "Le baril s'envole après des attaques dans le Golfe. Les prix à la pompe explosent." },
            options: [
                EventOption(label: "Subventionner l'énergie", detail: "0,5 % du PIB, soutien préservé", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.005)
                },
                EventOption(label: "Laisser les prix monter", detail: "Inflation +2 pts, soutien −0,04", aiWeight: 1) { sim, e in
                    sim.adjust(e.country) { c in
                        c.inflation += 0.02
                        c.support -= 0.04
                    }
                }
            ]),

        EventDefinition(
            id: "crash", title: "Krach financier mondial", icon: "chart.line.downtrend.xyaxis", isBad: true, worldwide: true,
            monthlyChance: 0.003,
            trigger: { _, _ in (true, nil) },
            text: { _, _ in "Une grande banque fait faillite, les Bourses s'effondrent et le crédit se tarit partout." },
            options: [
                EventOption(label: "Plan de relance", detail: "2 % du PIB de dette, récession limitée (−1 pt, 12 mois)", aiWeight: 2) { sim, e in
                    sim.spendShareOfGDP(e.country, 0.02)
                    sim.addModifier(e.country, "Krach mondial", growth: -0.01, months: 12)
                },
                EventOption(label: "Austérité", detail: "Récession forte (−3 pts, 12 mois), dette préservée", aiWeight: 1) { sim, e in
                    sim.addModifier(e.country, "Krach mondial", growth: -0.03, stability: -0.04, months: 12)
                }
            ])
    ]
}
