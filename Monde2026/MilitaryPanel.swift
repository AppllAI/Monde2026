import SwiftUI

// =============================================================
//  MilitaryPanel.swift
//  Armée de terre, recrutement, conscription, réserves,
//  matériel et guerres en cours.
// =============================================================

struct MilitaryPanel: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Armée", subtitle: c.name, flag: c.id) { store.panel = nil }
            overview(sim, c)
            WarsCard(store: store, sim: sim, country: c)
            PostureCard(store: store, country: c)
            ArmiesCard(store: store, sim: sim, country: c)
            DivisionsCard(store: store, country: c)
            ConscriptionCard(store: store, country: c)
            EquipmentCard(country: c)
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

    var body: some View {
        Dossier(title: "Divisions", subtitle: "Une division s'entraîne avant d'arriver au front ; elle utilise le matériel en stock.") {
            ForEach(DivisionType.allCases, id: \.self) { type in
                row(type)
            }
            if !country.training.isEmpty {
                Text("À l'entraînement").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                ForEach(country.training.indices, id: \.self) { i in
                    let batch = country.training[i]
                    Text("\(batch.count) × \(batch.type.name) : prêtes dans \(batch.daysLeft) jours")
                        .font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
        }
    }

    private func row(_ type: DivisionType) -> some View {
        let count = country.divisions[type] ?? 0
        let men = type.stats.manpower
        let canRecruit = country.availableManpower >= men
        let id = country.id
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(type.name) : \(count)").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper)
                Text("\(Fmt.troops(men)) hommes, \(type.trainingDays) jours d'entraînement")
                    .font(Theme.small).foregroundStyle(Theme.steel)
            }
            Spacer()
            stepButton("minus", enabled: count > 0) {
                store.mutate { $0.disband(type, count: 1, for: id) }
            }
            stepButton("plus", enabled: canRecruit) {
                store.mutate { _ = $0.recruit(type, count: 1, for: id) }
            }
            stepButton("plus.square.on.square", enabled: country.availableManpower >= men * 5) {
                store.mutate { _ = $0.recruit(type, count: 5, for: id) }
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 32)
                .foregroundStyle(enabled ? Theme.paper : Theme.steel.opacity(0.5))
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
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
        let free = sim.unassignedCount(country.id)
        Dossier(title: "Armées sur la carte",
                subtitle: "\(mine.count) armées, \(free) divisions en garnison. Les garnisons défendent vos régions, surtout au front.") {
            Toggle(isOn: Binding(
                get: { sim.state.autoArmies },
                set: { value in store.mutate { $0.setAutoArmies(value) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Commandement automatique").font(.system(size: 14)).foregroundStyle(Theme.paper)
                    Text("Vos généraux déploient et attaquent seuls.").font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            .tint(Theme.amber)
            ForEach(mine) { a in
                Button { store.selectArmy(a.id) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: a.engaged ? "flame.fill" : (a.path.isEmpty ? "shield.fill" : "arrow.right.circle.fill"))
                            .foregroundStyle(a.engaged ? Theme.coral : Theme.amber).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(a.name) : \(a.count) divisions").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.paper)
                            Text(sim.armyStatus(a)).font(Theme.small).foregroundStyle(Theme.steel).lineLimit(1)
                        }
                        Spacer()
                        Text(Fmt.pct(a.organization, 0)).font(Theme.data(12)).foregroundStyle(Theme.steel)
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.steel)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if free > 0 {
                HStack(spacing: 8) {
                    ForEach([5, 10, free].filter { $0 <= free }.removingDuplicates(), id: \.self) { n in
                        QuietButton(title: n == free ? "Former avec tout (\(n))" : "Former une armée de \(n)",
                                    icon: "plus", tint: Theme.amber) {
                            let id = country.id
                            store.perform { s, _ in s.createArmy(for: id, size: n) }
                        }
                    }
                }
            }
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
