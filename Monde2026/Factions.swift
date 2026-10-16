import Foundation

// =============================================================
//  Factions.swift
//  Les factions militaires (OTAN, OTSC… ou la vôtre) :
//  créer, inviter, demander l'adhésion, quitter.
//  Une faction est une défense collective : attaquer un membre,
//  c'est attaquer tout le monde.
// =============================================================

extension Simulation {

    func faction(of id: CountryID) -> Bloc? {
        state.blocs.first { $0.isMilitary && $0.members.contains(id) }
    }

    var factions: [Bloc] {
        state.blocs.filter { $0.isMilitary && !$0.members.isEmpty }
    }

    func factionLeader(_ bloc: Bloc) -> CountryID? {
        if let leader = bloc.leader, bloc.members.contains(leader) { return leader }
        return bloc.members.max { militaryPower($0) < militaryPower($1) }
    }

    func factionPower(_ bloc: Bloc) -> Double {
        bloc.members.reduce(0.0) { $0 + militaryPower($1) }
    }

    /// Un pays a-t-il envie d'entrer dans cette faction ?
    func evaluateFactionJoin(country x: CountryID, bloc: Bloc) -> Evaluation {
        var e = Evaluation()
        guard let leader = factionLeader(bloc) else { return e }
        if let current = faction(of: x) {
            e.add("Déjà membre de : \(current.name)", -100)
            return e
        }
        e.add("Abandon d'une partie de sa souveraineté", -20)
        e.add("Relations avec \(name(leader))", relation(x, leader) * 0.5)
        let average = bloc.members.reduce(0.0) { $0 + relation(x, $1) } / Double(max(1, bloc.members.count))
        e.add("Relations avec les membres", average * 0.2)
        var threatened = false
        for rival in countryIDs where relation(x, rival) < -50 && !bloc.members.contains(rival) {
            if militaryPower(rival) > militaryPower(x) {
                threatened = true
                break
            }
        }
        if threatened { e.add("Besoin de protection face à un rival", 25) }
        if bloc.members.contains(where: { claim(by: $0, on: x) != nil || claim(by: x, on: $0) != nil }) {
            e.add("Différend territorial avec un membre", -40)
        }
        if bloc.members.contains(where: { enemies(of: x).contains($0) }) {
            e.add("En guerre contre un membre", -100)
        }
        if reach(leader, x) < 0.5 { e.add("Chef de file trop éloigné", -10) }
        if x != state.playerID, let p = state.playerID, bloc.members.contains(p) {
            e.add("Niveau de difficulté", state.difficulty.diplomacyBias)
        }
        return e
    }

    /// Le chef de file accepte-t-il un nouveau membre ?
    func evaluateFactionAdmission(applicant x: CountryID, bloc: Bloc) -> Evaluation {
        var e = Evaluation()
        guard let leader = factionLeader(bloc) else { return e }
        e.add("Prudence", -10)
        e.add("Relations avec \(name(x))", relation(leader, x) * 0.5)
        let added = militaryPower(x) / max(factionPower(bloc), 1)
        e.add(added > 0.05 ? "Renfort militaire utile" : "Apport militaire faible", min(20, added * 100))
        let foes = enemies(of: x)
        if !foes.isEmpty && !bloc.members.contains(where: { m in foes.allSatisfy { enemies(of: m).contains($0) } }) {
            e.add("Il nous entraînerait dans sa guerre", -40)
        }
        if state.claims.contains(where: { ($0.claimant == x || $0.target == x) && $0.major }) {
            e.add("Différends territoriaux", -20)
        }
        if x == state.playerID {
            e.add("Niveau de difficulté", state.difficulty.diplomacyBias)
        }
        return e
    }

    mutating func createFaction(named title: String, by id: CountryID) -> ActionResult {
        guard faction(of: id) == nil else { return ActionResult(success: false, message: "Quittez d'abord votre faction.") }
        guard let c = state.countries[id], c.influence >= 30 else {
            return ActionResult(success: false, message: "Il faut 30 d'influence.")
        }
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let factionName = cleaned.isEmpty ? "Pacte de \(c.name)" : cleaned
        state.countries[id]?.influence -= 30
        state.blocs.append(Bloc(id: "F-\(id)-\(state.day)", name: factionName, members: [id],
                                isMilitary: true, isEconomic: false, leader: id))
        addEvent("🛡️ \(c.name) fonde une nouvelle faction : \(factionName).", important: true)
        return ActionResult(success: true, message: "Faction « \(factionName) » créée. Invitez des pays depuis leur fiche.")
    }

    mutating func inviteToFaction(_ target: CountryID, by id: CountryID) -> ActionResult {
        guard let bloc = faction(of: id), factionLeader(bloc) == id else {
            return ActionResult(success: false, message: "Seul le chef de file peut inviter.")
        }
        guard (state.countries[id]?.influence ?? 0) >= 15 else {
            return ActionResult(success: false, message: "Il faut 15 d'influence.")
        }
        state.countries[id]?.influence -= 15
        if evaluateFactionJoin(country: target, bloc: bloc).accepted {
            addMember(target, to: bloc.id)
            return ActionResult(success: true, message: "\(name(target)) rejoint \(bloc.name).")
        }
        changeRelation(id, target, by: -3)
        return ActionResult(success: false, message: "\(name(target)) décline l'invitation.")
    }

    mutating func requestJoinFaction(_ blocID: String, by id: CountryID) -> ActionResult {
        guard let bloc = state.blocs.first(where: { $0.id == blocID }), let leader = factionLeader(bloc) else {
            return ActionResult(success: false, message: "Faction introuvable.")
        }
        guard faction(of: id) == nil else { return ActionResult(success: false, message: "Quittez d'abord votre faction.") }
        guard (state.countries[id]?.influence ?? 0) >= 20 else {
            return ActionResult(success: false, message: "Il faut 20 d'influence.")
        }
        state.countries[id]?.influence -= 20
        if evaluateFactionAdmission(applicant: id, bloc: bloc).accepted {
            addMember(id, to: bloc.id)
            return ActionResult(success: true, message: "Bienvenue dans \(bloc.name) !")
        }
        changeRelation(id, leader, by: -5)
        return ActionResult(success: false, message: "\(name(leader)) refuse votre adhésion.")
    }

    mutating func leaveFaction(by id: CountryID) -> ActionResult {
        guard let index = state.blocs.firstIndex(where: { $0.isMilitary && $0.members.contains(id) }) else {
            return ActionResult(success: false, message: "Vous n'êtes dans aucune faction.")
        }
        let bloc = state.blocs[index]
        state.blocs[index].members.removeAll { $0 == id }
        for m in bloc.members where m != id {
            changeRelation(id, m, by: -20)
        }
        if state.blocs[index].leader == id {
            state.blocs[index].leader = nil
        }
        addEvent("\(name(id)) quitte \(bloc.name).", important: id == state.playerID)
        return ActionResult(success: true, message: "Vous avez quitté \(bloc.name).")
    }

    private mutating func addMember(_ id: CountryID, to blocID: String) {
        guard let index = state.blocs.firstIndex(where: { $0.id == blocID }) else { return }
        guard !state.blocs[index].members.contains(id) else { return }
        state.blocs[index].members.append(id)
        let bloc = state.blocs[index]
        for m in bloc.members where m != id {
            changeRelation(id, m, by: 10)
        }
        addEvent("🛡️ \(name(id)) rejoint \(bloc.name).", important: bloc.members.contains(state.playerID ?? "") || id == state.playerID)
    }

    /// IA : les pays isolés et menacés rejoignent parfois une faction amie.
    mutating func aiFactions() {
        let all = factions
        for id in countryIDs where id != state.playerID && faction(of: id) == nil {
            guard Double.random(in: 0...1, using: &state.rng) < 0.02 else { continue }
            for bloc in all {
                guard let leader = factionLeader(bloc), relation(id, leader) > 50 else { continue }
                if evaluateFactionJoin(country: id, bloc: bloc).accepted
                    && evaluateFactionAdmission(applicant: id, bloc: bloc).accepted {
                    if leader == state.playerID {
                        // Le joueur est chef de file : il reçoit une demande à la place.
                        continue
                    }
                    addMember(id, to: bloc.id)
                    break
                }
            }
        }
    }
}
