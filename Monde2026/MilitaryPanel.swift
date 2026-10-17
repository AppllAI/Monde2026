import SwiftUI

// =============================================================
//  MilitaryPanel.swift
//  Armée de terre, recrutement, conscription, réserves,
//  matériel et guerres en cours.
// =============================================================

struct MilitaryPanel: View {
    @ObservedObject var store: GameStore
    @AppStorage("militaryTab") private var tab = 0

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Armée", subtitle: c.name, flag: c.id) { store.panel = nil }
            Picker("", selection: $tab) {
                Text("Armées").tag(0)
                Text("Recrutement").tag(1)
                Text("Guerres").tag(2)
                Text("Matériel").tag(3)
            }
            .pickerStyle(.segmented)
            switch tab {
            case 0:
                ArmyBuilderCard(store: store, sim: sim, country: c)
                ArmiesCard(store: store, sim: sim, country: c)
                BasesCard(store: store, sim: sim, country: c)
            case 1:
                DivisionsCard(store: store, country: c)
                overview(sim, c)
                ConscriptionCard(store: store, country: c)
            case 2:
                BattlesCard(store: store)
                WarsCard(store: store, sim: sim, country: c)
                PostureCard(store: store, country: c)
            default:
                EquipmentCard(country: c)
            }
        }
    }

    private func overview(_ sim: Simulation, _ c: Country) -> some View {
        let items: [(String, String, Color)] = [
            ("Divisions", "\(c.divisionCount)", Theme.paper),
            ("Équipement", Fmt.pct(c.divisionFill, 0), c.divisionFill < 0.7 ? Theme.coral : Theme.teal),
            ("Puissance", Fmt.count(sim.militaryPower(c.id)), Theme.amber),
            ("Soldats d'active", Fmt.troops(c.activePersonnel), Theme.paper),
            ("Réservistes", Fmt.troops(c.reservePersonnel), Theme.paper),
            ("Mobilisables", Fmt.troops(c.availableManpower), c.availableManpower < 50 ? Theme.coral : Theme.paper),
            ("Préparation", Fmt.pct(c.readiness, 0), Theme.paper),
            ("Expérience", Fmt.pct(c.experience, 0), Theme.paper),
            ("Pertes", Fmt.troops(c.casualties), c.casualties > 0 ? Theme.coral : Theme.paper),
            ("Budget achats", Fmt.money(c.procurementFunds), Theme.paper),
            ("Lassitude", Fmt.pct(c.warExhaustion, 0), c.warExhaustion > 0.5 ? Theme.coral : Theme.paper),
            ("Ogives nucléaires", "\(c.nuclearWarheads)", c.nuclearWarheads > 0 ? Theme.amber : Theme.steel)
        ]
        return Dossier(title: "Forces armées") {
            FigureGrid(items: items)
        }
    }
}

struct WarsCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country

    var body: some View {
        let wars = sim.wars(of: country.id)
        if !wars.isEmpty {
            Dossier(title: "Guerres en cours", subtitle: "La paix se négocie depuis la fiche du pays ennemi.") {
                ForEach(wars) { war in
                    warRow(war)
                }
            }
        }
    }

    private func warRow(_ war: War) -> some View {
        let mine = war.attackers.contains(country.id) ? war.attackers : war.defenders
        let foes = war.attackers.contains(country.id) ? war.defenders : war.attackers
        let gains = sim.heldShare(of: foes, by: mine)
        let losses = sim.heldShare(of: mine, by: foes)
        let momentum = war.attackers.contains(country.id) ? war.momentum : -war.momentum
        return VStack(alignment: .leading, spacing: 8) {
            Text(war.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.paper)
            Text("Ennemis : " + foes.map { sim.name($0) }.joined(separator: ", "))
                .font(Theme.small).foregroundStyle(Theme.steel)
            ForEach(gains, id: \.0) { item in
                Text("Nous tenons \(Fmt.pct(item.1)) de \(sim.name(item.0))").font(Theme.small).foregroundStyle(Theme.teal)
            }
            ForEach(losses, id: \.0) { item in
                Text("\(sim.name(item.0)) : \(Fmt.pct(item.1)) occupé par l'ennemi").font(Theme.small).foregroundStyle(Theme.coral)
            }
            Text(momentum > 0.0005 ? "Le front avance en notre faveur." : (momentum < -0.0005 ? "Le front recule." : "Le front est figé."))
                .font(Theme.small).foregroundStyle(Theme.steel)
            if let foe = sim.leader(of: foes) {
                QuietButton(title: "Négocier avec \(sim.name(foe))", icon: "hand.raised") {
                    store.open(.country(foe))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DivisionsCard: View {
    @ObservedObject var store: GameStore
    let country: Country
    @State private var base: Int = -1

    var body: some View {
        let bases = store.sim?.bases(of: country.id) ?? []
        let target = bases.contains(base) ? base : (bases.first ?? -1)
        Dossier(title: "Recruter", subtitle: "Choisissez la base où les recrues s'entraînent. Elles y apparaîtront, prêtes à former une armée.") {
            if !bases.isEmpty {
                Picker("Base d'arrivée", selection: Binding(get: { target }, set: { base = $0 })) {
                    ForEach(bases, id: \.self) { b in Text("Base de \(ProvinceMap.all[b].name)").tag(b) }
                }
                .pickerStyle(.menu)
                .tint(Theme.amber)
            }
            ForEach(DivisionType.allCases, id: \.self) { type in
                row(type, base: target >= 0 ? target : nil)
            }
            if !country.training.isEmpty {
                Text("À l'entraînement").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                ForEach(country.training.indices, id: \.self) { i in
                    let batch = country.training[i]
                    let total = Double(batch.totalDays ?? batch.type.trainingDays)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            UnitSymbol(type: batch.type, color: Theme.steel.opacity(0.6), size: 20)
                            Text("\(batch.count) × \(batch.type.name)").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.paper)
                            Spacer()
                            Text(batch.base.map { "→ \(ProvinceMap.all[$0].name) · \(batch.daysLeft) j" } ?? "\(batch.daysLeft) j")
                                .font(Theme.data(11)).foregroundStyle(Theme.steel)
                        }
                        Meter(value: 1 - Double(batch.daysLeft) / max(1, total), tint: Theme.amber, height: 4)
                    }
                }
            }
        }
    }

    private func row(_ type: DivisionType, base: Int?) -> some View {
        let count = country.divisions[type] ?? 0
        let men = type.stats.manpower
        let canRecruit = country.availableManpower >= men
        let id = country.id
        let days = Int(Double(type.trainingDays) * (store.sim?.state.industryCache[id]?.training ?? 1))
        return HStack(spacing: 10) {
            UnitSymbol(type: type, color: Theme.steel.opacity(0.6), size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(type.name) : \(count)").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper)
                Text("\(Fmt.troops(men)) hommes · \(days) jours").font(Theme.small).foregroundStyle(Theme.steel)
            }
            Spacer()
            stepButton("plus", enabled: canRecruit) {
                store.mutate { _ = $0.recruit(type, count: 1, for: id, base: base) }
            }
            stepButton("plus.square.on.square", enabled: country.availableManpower >= men * 5) {
                store.mutate { _ = $0.recruit(type, count: 5, for: id, base: base) }
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
                .frame(width: 40, height: 36)
                .foregroundStyle(enabled ? Theme.paper : Theme.steel.opacity(0.5))
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(Pressable())
        .disabled(!enabled)
    }
}

struct ConscriptionCard: View {
    @ObservedObject var store: GameStore
    let country: Country

    var body: some View {
        let law = country.conscription
        Dossier(title: "Conscription",
                subtitle: "\(Fmt.pct(law.recruitableFraction)) de la population mobilisable, croissance −\(Fmt.pct(law.growthPenalty)).") {
            Picker("Loi", selection: Binding(
                get: { country.conscription },
                set: { newLaw in
                    let id = country.id
                    store.mutate { $0.setConscription(newLaw, for: id) }
                })) {
                ForEach(ConscriptionLaw.allCases, id: \.self) { l in
                    Text(l.name).tag(l)
                }
            }
            .pickerStyle(.menu)
            if country.reservePersonnel >= 12 {
                let amount = max(12, country.reservePersonnel * 0.25)
                QuietButton(title: "Rappeler \(Fmt.troops(amount)) réservistes (30 jours)", icon: "person.3.fill", tint: Theme.amber) {
                    let id = country.id
                    store.mutate { _ = $0.mobilizeReserves(thousands: amount, for: id) }
                }
            }
        }
    }
}

struct EquipmentCard: View {
    let country: Country

    var body: some View {
        Dossier(title: "Matériel", subtitle: "Stock et besoins des divisions.") {
            ForEach(EquipmentType.allCases, id: \.self) { e in
                row(e)
            }
        }
    }

    private func row(_ e: EquipmentType) -> some View {
        let stock = country.stock(e)
        let need = country.equipmentRequired(e)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(e.name).font(.system(size: 14)).foregroundStyle(Theme.paper)
                Spacer()
                Text(need > 0 ? "\(Fmt.count(stock)) / \(Fmt.count(need))" : Fmt.count(stock))
                    .font(Theme.data(13, weight: .semibold)).foregroundStyle(Theme.paper)
            }
            if need > 0 {
                Meter(value: stock / need, tint: stock >= need ? Theme.teal : Theme.coral, height: 4)
            }
        }
    }
}

struct PostureCard: View {
    @ObservedObject var store: GameStore
    let country: Country

    var body: some View {
        Dossier(title: "Posture de l'armée", subtitle: country.posture.summary) {
            Picker("Posture", selection: Binding(
                get: { country.posture },
                set: { value in
                    let id = country.id
                    store.mutate { $0.setPosture(value, for: id) }
                })) {
                ForEach(WarPosture.allCases, id: \.self) { p in
                    Text(p.name).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct ArmiesCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country

    var body: some View {
        let mine = sim.armies(of: country.id)
        Dossier(title: "Vos armées (\(mine.count))", subtitle: "Touchez une armée pour la voir sur la carte et lui donner des ordres.") {
            ForEach(mine) { a in
                Button { store.selectArmy(a.id) } label: {
                    HStack(spacing: 10) {
                        UnitSymbol(type: a.mainType, color: Color(uiColor: Theme.politicalColor(a.owner)), size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(a.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                                Text("\(a.count)/\(Army.maxDivisions)").font(Theme.data(11)).foregroundStyle(Theme.steel)
                            }
                            Text(sim.armyStatus(a)).font(Theme.small)
                                .foregroundStyle(a.engaged ? Theme.coral : Theme.steel).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Exp. \(Fmt.pct(a.experience, 0))").font(Theme.data(11)).foregroundStyle(Theme.amber)
                            Text("Moral \(Fmt.pct(a.organization, 0))").font(Theme.data(11)).foregroundStyle(Theme.steel)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.steel)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Toggle(isOn: Binding(
                get: { sim.state.autoArmies },
                set: { value in store.mutate { $0.setAutoArmies(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Commandement automatique").font(.system(size: 14)).foregroundStyle(Theme.paper)
                    Text("Vos généraux déploient et attaquent seuls en guerre.").font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            .tint(Theme.amber)
        }
    }
}

/// Former une armée soi-même, dans une base, avec les réserves qui s'y trouvent (30 divisions au maximum).
struct ArmyBuilderCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country
    @State private var pick: [DivisionType: Int] = [:]
    @State private var base: Int = -1

    var body: some View {
        let bases = sim.bases(of: country.id)
        let chosen = bases.contains(base) ? base : (bases.max { sim.depot(at: $0).values.reduce(0, +) < sim.depot(at: $1).values.reduce(0, +) } ?? -1)
        let reserve = chosen >= 0 ? sim.depot(at: chosen) : [:]
        let total = pick.values.reduce(0, +)
        Dossier(title: "Former une armée",
                subtitle: "Les recrues attendent dans les bases. On y forme les armées, qui partent ensuite où vous voulez.") {
            if bases.isEmpty {
                Text("Aucune base : touchez une de vos régions et construisez-en une.").font(Theme.small).foregroundStyle(Theme.coral)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bases, id: \.self) { b in
                            let n = sim.depot(at: b).values.reduce(0, +)
                            Button { base = b; pick = [:] } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(ProvinceMap.all[b].name, systemImage: "star.square.fill").font(.system(size: 12, weight: .semibold))
                                    Text("\(n) en réserve").font(.system(size: 10))
                                }
                                .foregroundStyle(chosen == b ? Theme.ink : Theme.paper)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(chosen == b ? Theme.amber : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(Pressable())
                        }
                    }
                }
                if reserve.values.reduce(0, +) == 0 {
                    Text("Pas de réserve ici. Recrutez (onglet Recrutement) en choisissant cette base.").font(Theme.small).foregroundStyle(Theme.steel)
                }
                ForEach(DivisionType.allCases.filter { (reserve[$0] ?? 0) > 0 }, id: \.self) { t in
                    let available = reserve[t] ?? 0
                    let n = min(pick[t] ?? 0, available)
                    HStack(spacing: 10) {
                        UnitSymbol(type: t, color: Theme.steel.opacity(0.6), size: 26)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(t.name).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                            Text("\(available) dans la base").font(.system(size: 10)).foregroundStyle(Theme.steel)
                        }
                        Spacer()
                        stepButton("minus", enabled: n > 0) { pick[t] = max(0, n - 1) }
                        Text("\(n)").font(Theme.data(16, weight: .bold)).foregroundStyle(Theme.paper).frame(minWidth: 30)
                        stepButton("plus", enabled: n < available && total < Army.maxDivisions) { pick[t] = n + 1 }
                        stepButton("plus.square.on.square", enabled: n < available && total < Army.maxDivisions) {
                            pick[t] = min(available, n + min(5, Army.maxDivisions - total))
                        }
                    }
                }
                HStack {
                    Text("\(total)/\(Army.maxDivisions) divisions").font(Theme.data(13, weight: .semibold))
                        .foregroundStyle(total == Army.maxDivisions ? Theme.amber : Theme.steel)
                    Spacer()
                    QuietButton(title: "Remplir", icon: "wand.and.stars") {
                        var left = Army.maxDivisions
                        var p: [DivisionType: Int] = [:]
                        for t in DivisionType.allCases {
                            let n = min(left, reserve[t] ?? 0)
                            p[t] = n
                            left -= n
                        }
                        pick = p
                    }
                }
                ActionButton(title: "Former l'armée à \(chosen >= 0 ? ProvinceMap.all[chosen].name : "la base")", icon: "plus",
                             enabled: total > 0 && chosen >= 0) {
                    let composition = pick
                    let b = chosen
                    store.perform { s, _ in s.formArmy(at: b, composition: composition) }
                    pick = [:]
                }
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.paper : Theme.steel.opacity(0.4))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(enabled ? 0.09 : 0.03), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(Pressable())
        .disabled(!enabled)
    }
}

struct BasesCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country

    var body: some View {
        let bases = sim.bases(of: country.id)
        let jobs = sim.state.constructions.filter { $0.owner == country.id }
        Dossier(title: "Bases et forts",
                subtitle: "Pour construire : touchez une de vos régions sur la carte, onglet Région.") {
            ForEach(bases, id: \.self) { b in
                let here = sim.state.armies.filter { $0.province == b && $0.owner == country.id }
                HStack(spacing: 10) {
                    Image(systemName: "star.square.fill").foregroundStyle(Theme.amber)
                    Text("Base de \(ProvinceMap.all[b].name)").font(.system(size: 14)).foregroundStyle(Theme.paper)
                    Spacer()
                    Text(here.isEmpty ? "vide" : "\(here.count) armée(s)").font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            ForEach(jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: job.kind.icon).foregroundStyle(Theme.sky)
                        Text("\(job.kind.name) à \(ProvinceMap.all[job.province].name)").font(.system(size: 13)).foregroundStyle(Theme.paper)
                        Spacer()
                        Text("\(job.daysLeft) j").font(Theme.data(12)).foregroundStyle(Theme.steel)
                    }
                    Meter(value: job.progress, tint: Theme.sky, height: 4)
                }
            }
            Text("Forts : \(sim.fortCount(country.id)) régions fortifiées.").font(Theme.small).foregroundStyle(Theme.steel)
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
