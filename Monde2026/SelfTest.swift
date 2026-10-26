import Foundation

// =============================================================
//  SelfTest.swift
//  Outils de test automatique (utilisés par la compilation sur
//  GitHub, sans effet en jeu normal) :
//   -selftest      fait tourner le monde 5 ans et affiche un bilan
//   -autostart FRA lance directement une partie avec ce pays
// =============================================================

enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var selfTest: Bool { arguments.contains("-selftest") }

    static var autostart: CountryID? {
        guard let i = arguments.firstIndex(of: "-autostart"), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static func value(_ key: String) -> String? {
        guard let i = arguments.firstIndex(of: key), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    static var autoSpeed: Int {
        guard let i = arguments.firstIndex(of: "-speed"), i + 1 < arguments.count else { return 0 }
        return Int(arguments[i + 1]) ?? 0
    }
}

enum SelfTest {

    static func run() {
        func log(_ text: String) {
            print("SELFTEST " + text)
        }
        let start = Date()
        var sim = Simulation(playerID: "FRA", difficulty: .normal)
        log("init \(String(format: "%.2f", Date().timeIntervalSince(start))) s, \(sim.state.countries.count) pays, \(ProvinceMap.all.count) régions")
        log("terrain réel : \(TerrainMap.hasRealData), " + Terrain.allCases.map { t in "\(t.name) \(ProvinceMap.all.filter { TerrainMap.terrain($0.id) == t }.count)" }.joined(separator: ", "))
        let owners = sim.provinceOwners()
        log("régions attribuées : \(owners.count)")
        let bad = ProvinceMap.all.filter { $0.rings.isEmpty }.count
        log("régions sans contour : \(bad), frontières : \(ProvinceMap.borders.count)")
        let t0 = Date()
        _ = MapSnapshotBuilder.build(sim, mode: .political, selected: nil, selectedProvince: nil)
        log("image de la carte : \(String(format: "%.3f", Date().timeIntervalSince(t0))) s")

        // Suivi détaillé du front russo-ukrainien pendant les 6 premiers mois.
        var probe = sim
        for month in 1...6 {
            probe.advance(days: 30)
            let lost = (ProvinceMap.byCountry["UKR"] ?? []).filter { probe.controller(of: $0) != "UKR" }
            let names = lost.map { ProvinceMap.all[$0].name }.sorted().joined(separator: ", ")
            let ru = probe.armies(of: "RUS"), ua = probe.armies(of: "UKR")
            let ruOrg = ru.isEmpty ? 0 : ru.reduce(0.0) { $0 + $1.organization } / Double(ru.count)
            let uaOrg = ua.isEmpty ? 0 : ua.reduce(0.0) { $0 + $1.organization } / Double(ua.count)
            let ruDiv = ru.reduce(0) { $0 + $1.count }, uaDiv = ua.reduce(0) { $0 + $1.count }
            let uaFront = probe.frontierProvinces("UKR", enemies: ["RUS"])
            let covered = uaFront.filter { p in ua.contains { $0.province == p } }.count
            log("mois \(month) : UKR perd \(lost.count) [\(names)]")
            let bs = Array(probe.state.battles.values)
            let tactics = Dictionary(grouping: bs.flatMap { [$0.attackerTactic.name, $0.defenderTactic.name] }, by: { $0 }).mapValues { $0.count }
            let cut = probe.state.armies.filter { $0.supply < 0.4 }.count
            let skills = probe.state.armies.map { $0.general.skill }
            log("   batailles \(bs.count) (\(bs.map { "\(ProvinceMap.all[$0.province].name) \(Int($0.balance * 100))%" }.prefix(6).joined(separator: ", "))) ; météo Donetsk \(probe.weather(at: lost.first ?? 0).name)")
            log("   tactiques : \(tactics.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")) ; armées mal ravitaillées \(cut) ; niveau moyen des généraux \(String(format: "%.2f", Double(skills.reduce(0, +)) / Double(max(1, skills.count))))")
            log("   RUS \(ru.count) armées / \(ruDiv) div / org \(Int(ruOrg * 100)) % ; UKR \(ua.count) armées / \(uaDiv) div / org \(Int(uaOrg * 100)) % ; garnison UKR \(probe.unassignedCount("UKR")) ; front UKR \(covered)/\(uaFront.count) régions tenues par une armée")
        }

        // Profil : où part le temps de calcul d'un jour (90 jours en guerre).
        var prof = probe
        var times: [String: Double] = [:]
        let tp = Date()
        for _ in 0..<90 { prof.advanceDayProfiled(&times) }
        let total = Date().timeIntervalSince(tp)
        log("profil 90 j : \(String(format: "%.1f", total * 1000 / 90)) ms/jour — " + times.sorted { $0.value > $1.value }
            .map { "\($0.key) \(String(format: "%.2f", $0.value * 1000 / 90))" }.joined(separator: ", "))
        let tu = Date()
        for _ in 0..<20 { _ = UnitsBuilder.build(prof, selectedArmy: nil, group: []) }
        log("instantané des unités : \(String(format: "%.2f", Date().timeIntervalSince(tu) * 1000 / 20)) ms, carte : " +
            "\(String(format: "%.1f", { () -> Double in let t = Date(); _ = MapSnapshotBuilder.build(prof, mode: .political, selected: nil, selectedProvince: nil); return Date().timeIntervalSince(t) * 1000 }())) ms")

        // Lignes de front : l'Ukraine confie toutes ses armées au front.
        var front = Simulation(playerID: "UKR", difficulty: .normal)
        let uaIDs = front.armies(of: "UKR").map { $0.id }
        log("front : " + front.assignFront(uaIDs, owner: "UKR").message)
        front.advance(days: 12)
        let line = front.frontierProvinces("UKR", enemies: front.enemies(of: "UKR"))
        let held = line.filter { p in front.armies(of: "UKR").contains { $0.province == p } }.count
        log("front : après 12 jours, \(held)/\(line.count) régions du front tenues, \(front.armies(of: "UKR").filter { $0.facing != nil }.count) armées plaquées")
        if let a = front.armies(of: "UKR").first, let target = ProvinceMap.all[a.province].neighbors.first(where: { front.enemies(of: "UKR").contains(front.controller(of: $0)) }) {
            log("flèche : " + front.arrowOffensive([a.id], along: [a.province, target]).message)
        }

        let watched: [CountryID] = ["USA", "CHN", "FRA", "DEU", "RUS", "UKR", "IND", "BRA", "ARM", "SDN"]
        for year in 1...5 {
            let t = Date()
            sim.advance(days: 365)
            log("— année \(2025 + year + 1) : \(String(format: "%.2f", Date().timeIntervalSince(t))) s de calcul")
            for id in watched {
                guard let c = sim.state.countries[id] else { continue }
                let gdp = sim.effectiveGDP(id)
                log("\(id) PIB \(Int(gdp)) Md$ croiss \(String(format: "%.1f", c.growth * 100))% dette \(Int(c.debt / gdp * 100))% infl \(String(format: "%.1f", c.inflation * 100))% stab \(Int(c.stability * 100)) div \(c.divisionCount) perdu \(Int(sim.lostFraction(id) * 100))%")
            }
            log("guerres : " + sim.activeWarsList.map { $0.name }.joined(separator: " | "))
            for id in ["RUS", "UKR"] {
                guard let c = sim.state.countries[id] else { continue }
                log("  \(id) équip \(Int(c.divisionFill * 100))% mult \(String(format: "%.2f", c.combatMultiplier)) terre \(Int(c.landStrengthIndex)) air \(Int(c.airPower)) missiles \(Int(c.stock(.missile))) drones \(Int(c.stock(.drone))) pertes \(Int(c.casualties))k lassitude \(Int(c.warExhaustion * 100))% posture \(c.posture.name)")
            }
            let ukrLost = (ProvinceMap.byCountry["UKR"] ?? []).filter { sim.controller(of: $0) != "UKR" }.count
            log("  armées : RUS \(sim.armies(of: "RUS").count), UKR \(sim.armies(of: "UKR").count), total \(sim.state.armies.count) ; régions ukrainiennes tenues par l'ennemi : \(ukrLost)/\(ProvinceMap.byCountry["UKR"]?.count ?? 0)")
            if year == 2 {
                _ = sim.declareWar(attacker: "VEN", defender: "GUY")
                log("  test : le Venezuela attaque le Guyana")
            }
            if year >= 2 {
                let guy = (ProvinceMap.byCountry["GUY"] ?? []).filter { sim.controller(of: $0) != "GUY" }.count
                log("  Guyana : \(guy)/\(ProvinceMap.byCountry["GUY"]?.count ?? 0) régions perdues, armées VEN \(sim.armies(of: "VEN").count)")
            }
            log("tension \(Int(sim.state.worldTension)), plans de guerre \(sim.state.warPlans.count), prix pétrole \(String(format: "%.2f", sim.state.prices[.oil] ?? 1))")
        }
        let suspicious = sim.state.countries.values.filter { c in
            let g = sim.effectiveGDP(c.id)
            return !g.isFinite || g <= 0 || !c.debt.isFinite || !c.inflation.isFinite || c.inflation > 2 || c.growth < -0.25
        }
        log("pays aux chiffres suspects : " + suspicious.map { $0.id }.sorted().joined(separator: ", "))
        let events = sim.state.events.suffix(40).map { $0.text }
        for e in events { log("évènement : " + e) }
        if let data = try? sim.saveData() {
            log("sauvegarde : \(data.count / 1024) ko")
            if (try? Simulation(saveData: data)) != nil { log("rechargement OK") } else { log("rechargement ECHEC") }
        }
        // Test des intrigues : la Pologne envoie des « volontaires » en Ukraine.
        var spy = Simulation(playerID: "POL", difficulty: .normal)
        if let a = spy.armies(of: "POL").first {
            let r = spy.sendExpedition(a.id, to: "UKR", covert: true)
            log("intrigue : \(r.message)")
            let arms = spy.sendArms(to: "UKR", share: 0.05, covert: true)
            log("intrigue : \(arms.message)")
            let lend = spy.lendFactories(to: "UKR", share: 0.1, months: 6, covert: false)
            log("intrigue : \(lend.message)")
            spy.advance(days: 200)
            let serving = spy.armies(of: "POL").filter { $0.servingFor == "UKR" }
            log("intrigue : armées polonaises au service de l'Ukraine \(serving.count), conquêtes pour l'Ukraine \(spy.proxyRegions(for: "UKR").count), en guerre avec la Russie : \(spy.enemies(of: "POL").contains("RUS"))")
            if !spy.proxyRegions(for: "UKR").isEmpty { log("intrigue : trahison → \(spy.betray("UKR").message)") }
        }
        let e = spy.evaluateJointAttack(partner: "LTU", target: "BLR", from: "POL")
        log("intrigue : attaque conjointe Lituanie→Biélorussie : score \(Int(e.score))")
        log("intrigue : ultimatum à la Biélorussie : score \(Int(spy.evaluateUltimatum(target: "BLR", from: "POL").score))")
        log("total \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
        log("FIN")
    }
}
