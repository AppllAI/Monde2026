import SwiftUI

// =============================================================
//  BattleUI.swift
//  L'interface de la guerre, pensée pour le doigt :
//   - la fiche d'armée (général, posture, ravitaillement,
//     planification, ordres groupés),
//   - la fiche de bataille (rapport de force, tactiques à
//     choisir comme des cartes, modificateurs, frappes, renforts),
//   - la liste des batailles en cours.
// =============================================================

// MARK: - Fiche d'une armée (sur la carte)

struct ArmyCard: View {
    @ObservedObject var store: GameStore
    @State private var showOps = false

    var body: some View {
        if let sim = store.sim, let id = store.selectedArmy, let a = sim.state.armies.first(where: { $0.id == id }) {
            let mine = a.owner == store.playerID
            VStack(alignment: .leading, spacing: 10) {
                header(sim, a)
                if let b = battle(sim, a) {
                    Button { store.openBattle(b.province) } label: { BattleStrip(battle: b, side: sim.playerSide(in: b)) }
                        .buttonStyle(.plain)
                }
                HStack(spacing: 10) {
                    Gauge2(label: "Moral", value: a.organization, tint: a.organization < 0.4 ? Theme.coral : Theme.teal)
                    Gauge2(label: "Expérience", value: a.experience, tint: Theme.amber)
                    Gauge2(label: "Ravitaillement", value: a.supply,
                           tint: a.supply <= 0.15 ? Theme.coral : (a.supply < 0.6 ? Theme.amber : Theme.teal))
                }
                HStack {
                    CompositionRow(divisions: a.divisions)
                    Spacer(minLength: 0)
                }
                if mine {
                    StancePicker(current: a.stance) { stance in
                        let ids = [id] + store.armyGroup.sorted()
                        store.mutate { $0.setStance(stance, for: ids) }
                    }
                    if !store.armyGroup.isEmpty {
                        HStack {
                            Label("\(store.armyGroup.count + 1) armées ensemble", systemImage: "square.stack.3d.up.fill")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber)
                            Spacer()
                            Button("Séparer") { store.clearGroup() }
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.paper)
                        }
                    }
                    // Les 4 ordres principaux, gros et clairs ; le reste est rangé dans « Plus ».
                    let onFront = sim.front(of: id) != nil
                    HStack(spacing: 8) {
                        BigOrder(title: onFront ? "Quitter le front" : "Tenir le front", icon: "rectangle.split.3x1.fill",
                                 tint: onFront ? Theme.steel : Theme.teal) {
                            if onFront { store.leaveFront() } else { store.holdFront() }
                        }
                        BigOrder(title: "Offensive", icon: "arrow.up.right", tint: Theme.coral) {
                            store.feedback = "Appui long sur la carte, puis tracez une flèche vers l'ennemi."
                        }
                        BigOrder(title: a.training ? "Entraînement…" : "Base", icon: "star.square.fill", tint: Theme.amber) {
                            if a.training {
                                store.mutate { $0.setTraining(false, for: [id]) }
                            } else {
                                store.perform { s, _ in s.sendToBase(id) }
                            }
                        }
                        Menu {
                            if !a.path.isEmpty {
                                Button("Arrêter", systemImage: "stop.fill") {
                                    let ids = [id] + store.armyGroup.sorted()
                                    store.mutate { s in for x in ids { s.stopArmy(x) } }
                                }
                            }
                            Button("Réorganiser les divisions", systemImage: "arrow.left.arrow.right") { store.open(.army(id)) }
                            Button("Ajouter les armées voisines", systemImage: "plus.circle") { store.groupNearby() }
                            Button("Sélectionner tout le front", systemImage: "rectangle.3.group") { store.groupFront() }
                            Button("Diviser en deux", systemImage: "square.split.2x1") { store.perform { s, _ in s.splitArmy(id) } }
                            if sim.playerArmies(in: a.province).count > 1 {
                                Button("Fusionner ici", systemImage: "square.stack.3d.up") { store.perform { s, _ in s.mergeArmies(at: id) } }
                            }
                            Button("Opérations spéciales…", systemImage: "scope") { withAnimation(.snappy) { showOps.toggle() } }
                            Divider()
                            Button("Dissoudre", systemImage: "xmark.bin", role: .destructive) {
                                store.mutate { $0.dissolveArmy(id) }
                                store.clearSelection()
                            }
                        } label: {
                            BigOrderLabel(title: "Plus", icon: "ellipsis", tint: Theme.paper)
                        }
                    }
                    if showOps {
                        OperationsRow(store: store, army: a, sim: sim)
                    }
                    Text(store.waypointMode
                         ? "Mode étapes : chaque région touchée s'ajoute au trajet."
                         : "Glissez le pion vers une région (contre une frontière pour la tenir). Appui long + trait : offensive. Double-tap : tout le front.")
                        .font(.system(size: 11)).foregroundStyle(store.waypointMode ? Theme.amber : Theme.steel).lineLimit(2)
                } else {
                    GeneralRow(general: a.general)
                }
            }
            .padding(14)
            .frame(maxWidth: 600)
            .glass(24)
        }
    }

    private func battle(_ sim: Simulation, _ a: Army) -> Battle? {
        if let t = a.path.first, a.engaged, let b = sim.state.battles[t] { return b }
        return sim.state.battles[a.province]
    }

    private func header(_ sim: Simulation, _ a: Army) -> some View {
        HStack(spacing: 12) {
            UnitSymbol(type: a.mainType, color: Color(uiColor: Theme.politicalColor(a.owner)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(a.name).font(Theme.title(19)).foregroundStyle(Theme.paper)
                    Text("\(a.count)/\(Army.maxDivisions)").font(Theme.data(12, weight: .semibold)).foregroundStyle(Theme.steel)
                }
                Text(sim.armyStatus(a)).lineLimit(1)
                    .font(Theme.small)
                    .foregroundStyle(a.engaged || a.supply <= 0.15 ? Theme.coral : Theme.steel)
            }
            Spacer(minLength: 8)
            if a.owner == store.playerID {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(a.general.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.paper).lineLimit(1)
                    Text(a.general.stars + " " + a.general.trait.name).font(.system(size: 10)).foregroundStyle(Theme.amber).lineLimit(1)
                }
            }
            Button { store.clearSelection() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Désélectionner l'armée")
        }
    }
}

/// Gros bouton d'ordre (fiche d'armée) : facile à toucher du pouce.
struct BigOrder: View {
    let title: String
    let icon: String
    var tint: Color = Theme.amber
    let action: () -> Void

    var body: some View {
        Button(action: action) { BigOrderLabel(title: title, icon: icon, tint: tint) }
            .buttonStyle(Pressable())
    }
}

struct BigOrderLabel: View {
    let title: String
    let icon: String
    var tint: Color = Theme.amber

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold))
            Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(tint.opacity(0.13), in: HUDShape(cut: 8))
        .overlay(HUDShape(cut: 8).strokeBorder(tint.opacity(0.25)))
    }
}

/// Bandeau compact d'une bataille : qui attaque qui, et où en est la prise.
struct BattleStrip: View {
    let battle: Battle
    let side: Int

    var body: some View {
        let good = side == 1 ? battle.balance > 0.5 : battle.balance < 0.5
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
                Text(side == -1 ? "Défense de \(ProvinceMap.all[battle.province].name)" : "Attaque sur \(ProvinceMap.all[battle.province].name)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("prise \(Int(battle.captureProgress * 100)) %").font(Theme.data(12, weight: .semibold))
                    .foregroundStyle(good ? Theme.teal : Theme.coral)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.steel)
            }
            Meter(value: battle.captureProgress, tint: side == -1 ? Theme.coral : Theme.teal, height: 6)
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: HUDShape(cut: 7))
    }
}

/// Symbole d'unité (style OTAN) : croix = infanterie, ovale = blindés, les deux = mécanisée.
struct UnitSymbol: View {
    let type: DivisionType
    var color: Color = Theme.amber
    var size: CGFloat = 34

    var body: some View {
        Canvas { ctx, sz in
            let r = CGRect(x: 1, y: sz.height * 0.15, width: sz.width - 2, height: sz.height * 0.7)
            ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(color.opacity(0.9)))
            ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(.white), lineWidth: 1.5)
            for p in UnitGlyph.paths(type, in: r) {
                ctx.stroke(p, with: .color(.white), lineWidth: 1.6)
            }
        }
        .frame(width: size, height: size)
    }
}

enum UnitGlyph {
    /// Les traits du symbole, dans le rectangle donné.
    static func paths(_ type: DivisionType, in r: CGRect) -> [Path] {
        var out: [Path] = []
        func cross() -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            return p
        }
        func oval() -> Path {
            Path(roundedRect: r.insetBy(dx: r.width * 0.2, dy: r.height * 0.25), cornerRadius: r.height * 0.25)
        }
        switch type {
        case .infantry: out.append(cross())
        case .armored: out.append(oval())
        case .mechanized: out.append(cross()); out.append(oval())
        case .airborne:
            out.append(cross())
            var p = Path()
            p.addArc(center: CGPoint(x: r.midX - r.width * 0.1, y: r.maxY - r.height * 0.05), radius: r.width * 0.1,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addArc(center: CGPoint(x: r.midX + r.width * 0.1, y: r.maxY - r.height * 0.05), radius: r.width * 0.1,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            out.append(p)
        case .marines:
            out.append(cross())
            var p = Path()
            p.move(to: CGPoint(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.18))
            p.addCurve(to: CGPoint(x: r.maxX - r.width * 0.2, y: r.maxY - r.height * 0.18),
                       control1: CGPoint(x: r.midX - r.width * 0.1, y: r.maxY - r.height * 0.45),
                       control2: CGPoint(x: r.midX + r.width * 0.1, y: r.maxY + r.height * 0.1))
            out.append(p)
        }
        return out
    }
}

struct GeneralRow: View {
    let general: General

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: general.trait.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .background(Theme.amber, in: HUDShape(cut: 5))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(general.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text(general.stars).font(.system(size: 11)).foregroundStyle(Theme.amber)
                }
                Text("\(general.trait.name) · \(general.trait.summary)").font(.system(size: 11)).foregroundStyle(Theme.steel)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if general.skill < 5 {
                Meter(value: general.xp / max(1, general.nextLevelXP), tint: Theme.amber, height: 4)
                    .frame(width: 44)
                    .accessibilityLabel("Expérience")
            }
        }
    }
}

struct Gauge2: View {
    let label: String
    let value: Double
    var tint: Color = Theme.teal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(Fmt.pct(value, 0)).font(Theme.data(13, weight: .semibold)).foregroundStyle(tint)
            }
            Meter(value: value, tint: tint, height: 5)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.steel).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompositionRow: View {
    let divisions: [DivisionType: Int]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DivisionType.allCases.filter { (divisions[$0] ?? 0) > 0 }, id: \.self) { t in
                HStack(spacing: 4) {
                    UnitSymbol(type: t, color: Theme.steel.opacity(0.6), size: 18)
                    Text("\(divisions[t] ?? 0)").font(Theme.data(12, weight: .semibold))
                    Text(t.short).font(.system(size: 10))
                }
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.07), in: Capsule())
            }
        }
    }
}

struct StancePicker: View {
    let current: ArmyStance
    let pick: (ArmyStance) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ArmyStance.allCases, id: \.self) { s in
                Button { pick(s) } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 5) {
                            Image(systemName: s.icon)
                            Text(s.name)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        Text(detail(s)).font(.system(size: 9.5)).opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(current == s ? Theme.ink : Theme.paper)
                    .background(current == s ? tint(s) : Color.white.opacity(0.07),
                                in: HUDShape(cut: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Posture \(s.name)")
            }
        }
    }

    private func tint(_ s: ArmyStance) -> Color {
        switch s {
        case .defend: return Theme.teal
        case .balanced: return Theme.paper
        case .assault: return Theme.coral
        }
    }

    private func detail(_ s: ArmyStance) -> String {
        switch s {
        case .defend: return "déf. +15 %, att. −25 %"
        case .balanced: return "polyvalent"
        case .assault: return "att. +15 %, pertes +30 %"
        }
    }
}

extension DivisionType {
    var icon: String {
        switch self {
        case .infantry: return "figure.walk"
        case .mechanized: return "car.fill"
        case .armored: return "shield.checkered"
        case .airborne: return "parachute.fill"
        case .marines: return "water.waves"
        }
    }

    var short: String {
        switch self {
        case .infantry: return "inf."
        case .mechanized: return "méca."
        case .armored: return "blindés"
        case .airborne: return "aéro."
        case .marines: return "marine"
        }
    }
}

// MARK: - Fiche de bataille

struct BattlePanel: View {
    @ObservedObject var store: GameStore
    let province: Int
    @State private var details = false

    var body: some View {
        let _ = store.version
        if let sim = store.sim {
            let p = ProvinceMap.all[province]
            let terrain = TerrainMap.terrain(province)
            let weather = sim.weather(at: province)
            VStack(alignment: .leading, spacing: 14) {
                PanelHeader(title: "Bataille de \(p.name)",
                            subtitle: TerrainMap.city(province).map { "Autour de \($0)" } ?? p.countryName) { store.panel = nil }
                HStack(spacing: 8) {
                    Tag(icon: terrain.icon, text: terrain.name)
                    if weather != .clear { Tag(icon: weather.icon, text: weather.name, tint: Theme.amber) }
                    if sim.fortLevel(province) > 0 {
                        Tag(icon: "building.columns.fill", text: "Fort \(sim.fortLevel(province))", tint: Theme.sky)
                    }
                    Spacer()
                    SpeedControl(store: store)
                }
                if let b = sim.state.battles[province] {
                    content(sim, b)
                } else {
                    Dossier(title: "La bataille est terminée") {
                        Text("\(p.name) est tenue par \(sim.name(sim.controller(of: province))).")
                            .font(Theme.body).foregroundStyle(Theme.paper.opacity(0.85))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ sim: Simulation, _ b: Battle) -> some View {
        let side = sim.playerSide(in: b)
        // 1. L'essentiel : où en est la prise de la région
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Prise de la région").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("\(Int(b.captureProgress * 100)) %").font(Theme.data(22, weight: .bold))
                    .foregroundStyle(side == -1 ? Theme.coral : Theme.teal)
            }
            Meter(value: b.captureProgress, tint: side == -1 ? Theme.coral : Theme.teal, height: 12)
            Text(explanation(b)).font(.system(size: 12)).foregroundStyle(Theme.steel)
        }
        .padding(14)
        .background(Theme.deep.opacity(0.75), in: HUDShape(cut: 10))
        // 2. L'arène : les deux camps face à face, le duel des tactiques, la corde du rapport de force
        let forces = sim.battleForces(b)
        BattleArena(battle: b, attack: forces.attack, defense: forces.defense, side: side,
                    attackerName: sim.name(b.attacker), defenderName: sim.name(b.defender))
        // 2b. Pourquoi, en 3 images
        VStack(alignment: .leading, spacing: 8) {
            Text("Ce qui pèse le plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
            WhyStrip(factors: b.decisiveFactors(), side: side)
        }
        // 2c. La tactique de la prochaine phase (si c'est nous qui menons ce camp)
        if let options = playerTactics(sim, b, side: side), !options.isEmpty {
            let opponent = side == 1 ? b.defenderTactic : b.attackerTactic
            VStack(alignment: .leading, spacing: 8) {
                Text("Votre tactique (prochaine phase dans \(b.daysLeftInPhase) j)")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(options) { t in
                        TacticChoice(tactic: t, selected: b.playerPick == t, beatsCurrent: t.beats.contains(opponent)) {
                            store.perform { s, _ in s.pickTactic(t, at: province) }
                        }
                    }
                }
            }
        }
        // 3. Ce que le joueur peut faire
        if side != 0 {
            HStack(spacing: 8) {
                ActionButton(title: "Frappes", icon: "airplane", tint: Theme.sky,
                             enabled: sim.state.day > b.airStrikeUntil + 10) {
                    store.perform { s, _ in s.callAirStrike(at: province) }
                }
                ActionButton(title: "Renforts", icon: "plus.circle.fill", tint: Theme.teal) {
                    store.perform { s, _ in s.reinforceBattle(at: province) }
                }
                ActionButton(title: side == 1 ? "Stopper" : "Se replier", icon: "arrow.uturn.backward", tint: Theme.coral) {
                    store.perform { s, _ in s.retreatFromBattle(at: province) }
                }
            }
        }
        // 4. Le détail, pour qui veut comprendre
        Button { withAnimation(.snappy) { details.toggle() } } label: {
            HStack {
                Text("Tout le détail des calculs").font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: details ? "chevron.up" : "chevron.down")
            }
            .foregroundStyle(Theme.paper)
            .padding(12)
            .background(Color.white.opacity(0.05), in: HUDShape(cut: 7))
        }
        .buttonStyle(.plain)
        if details {
            HStack(alignment: .top, spacing: 10) {
                ModifierList(title: "Attaque", mods: b.attackMods)
                ModifierList(title: "Défense", mods: b.defenseMods)
            }
            if !b.log.isEmpty {
                Dossier(title: "Journal") {
                    ForEach(Array(b.log.reversed().enumerated()), id: \.offset) { _, line in
                        Text(line).font(Theme.small).foregroundStyle(Theme.paper.opacity(0.85))
                    }
                }
            }
        }
    }

    /// Tactiques que le joueur peut choisir (seulement s'il mène l'attaque ou la défense).
    private func playerTactics(_ sim: Simulation, _ b: Battle, side: Int) -> [Tactic]? {
        guard let p = sim.state.playerID else { return nil }
        if side == 1 && b.attacker == p {
            let armies = sim.state.armies.filter { $0.side == p && $0.engaged && $0.path.first == province }
            let fronts = Set(armies.map { $0.province }).count
            return sim.availableTactics(attacking: true, armies: armies, owner: p, province: province, fronts: fronts)
        }
        if side == -1 && b.defender == p {
            let armies = sim.state.armies.filter { $0.province == province && $0.side == p }
            return sim.availableTactics(attacking: false, armies: armies, owner: p, province: province, fronts: b.fronts.count)
        }
        return nil
    }

    private func explanation(_ b: Battle) -> String {
        let ratio = b.attack / max(b.defense, 0.001)
        let r = String(format: "%.1f", ratio).replacingOccurrences(of: ".", with: ",")
        if b.balance > 0.5 {
            return "L'attaque est \(r) fois plus forte : le moral des défenseurs s'effondre. La région tombe quand il passe sous 20 %."
        }
        return "La défense tient (attaque \(r) fois sa force) : les attaquants s'usent. Ils renoncent quand leur moral passe sous 25 %."
    }
}

struct Tag: View {
    let icon: String
    let text: String
    var tint: Color = Theme.steel

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

struct BalanceBar: View {
    let battle: Battle
    let playerSide: Int

    var body: some View {
        let share = battle.balance
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.attacker)))
                        .frame(width: geo.size.width * share)
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.defender)))
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.white).frame(width: 2).offset(x: geo.size.width * share - 1)
                }
            }
            .frame(height: 16)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
            .animation(.snappy, value: share)
            HStack {
                Text("\(Geo.flag(battle.attacker)) \(Int((share * 100).rounded())) %")
                Spacer()
                Text(verdict).foregroundStyle(verdictTint)
                Spacer()
                Text("\(Int(((1 - share) * 100).rounded())) % \(Geo.flag(battle.defender))")
            }
            .font(Theme.data(13, weight: .semibold))
            .foregroundStyle(Theme.paper)
        }
    }

    private var verdict: String {
        let s = battle.balance
        if s > 0.62 { return "L'attaquant perce" }
        if s > 0.52 { return "L'attaquant progresse" }
        if s > 0.48 { return "Équilibre" }
        if s > 0.38 { return "La défense tient" }
        return "L'attaque s'enlise"
    }

    private var verdictTint: Color {
        guard playerSide != 0 else { return Theme.steel }
        let good = playerSide == 1 ? battle.balance > 0.5 : battle.balance < 0.5
        return good ? Theme.teal : Theme.coral
    }
}

struct SideCard: View {
    let title: String
    let id: CountryID
    let name: String
    let general: String
    let divisions: Int
    let org: Double
    let losses: Double
    let power: Double
    let isPlayer: Bool
    let tactic: Tactic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                FlagBadge(id: id, size: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.steel)
                    Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(isPlayer ? Theme.amber : Theme.paper)
                        .lineLimit(1)
                }
            }
            HStack {
                Readout(label: "Divisions", value: divisions > 0 ? "\(divisions)" : "garnison")
                Spacer()
                Readout(label: "Force", value: Fmt.number(power))
                Spacer()
                Readout(label: "Pertes", value: "\(Int(losses)) k", tint: Theme.coral)
            }
            VStack(alignment: .leading, spacing: 3) {
                Meter(value: org, tint: org < 0.3 ? Theme.coral : Theme.teal, height: 6)
                Text("Moral \(Fmt.pct(org, 0))").font(.system(size: 10)).foregroundStyle(org < 0.3 ? Theme.coral : Theme.steel)
            }
            Label(tactic.name, systemImage: tactic.icon).font(.system(size: 11)).foregroundStyle(Theme.steel).lineLimit(1)
            Text(general).font(.system(size: 10)).foregroundStyle(Theme.steel.opacity(0.8)).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.deep.opacity(0.75), in: HUDShape(cut: 8))
        .overlay(HUDShape(cut: 8).strokeBorder(isPlayer ? Theme.amber.opacity(0.6) : Color.clear))
    }
}

struct TacticTile: View {
    let tactic: Tactic
    let highlight: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tactic.icon).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tactic.isAttack ? Theme.coral : Theme.teal)
            VStack(alignment: .leading, spacing: 1) {
                Text(tactic.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper).lineLimit(1)
                Text(highlight ? "Contre l'adversaire !" : tactic.summary).font(.system(size: 10))
                    .foregroundStyle(highlight ? Theme.amber : Theme.steel).lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(highlight ? 0.12 : 0.05), in: HUDShape(cut: 7))
        .overlay(HUDShape(cut: 7).strokeBorder(highlight ? Theme.amber : Color.clear))
    }
}

struct TacticChoice: View {
    let tactic: Tactic
    let selected: Bool
    let beatsCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: tactic.icon).font(.system(size: 14, weight: .semibold))
                    Text(tactic.name).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    if selected { Image(systemName: "checkmark.circle.fill") }
                }
                .foregroundStyle(selected ? Theme.ink : Theme.paper)
                Text(tactic.summary).font(.system(size: 10.5))
                    .foregroundStyle(selected ? Theme.ink.opacity(0.8) : Theme.steel)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("Bat : " + tactic.beats.map { $0.name }.joined(separator: ", "))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? Theme.ink : (beatsCurrent ? Theme.amber : Theme.teal))
                    .lineLimit(2)
                Text("Craint : " + tactic.weakAgainst.map { $0.name }.joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(selected ? Theme.ink.opacity(0.7) : Theme.coral.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(selected ? Theme.amber : Color.white.opacity(0.06), in: HUDShape(cut: 7))
            .overlay(HUDShape(cut: 7)
                .strokeBorder(beatsCurrent && !selected ? Theme.amber.opacity(0.7) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tactic.name)
    }
}

struct ModifierList: View {
    let title: String
    let mods: [BattleModifier]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
            ForEach(mods, id: \.self) { m in
                HStack(alignment: .firstTextBaseline) {
                    Text(m.name).font(.system(size: 11)).foregroundStyle(Theme.paper.opacity(0.85)).lineLimit(2)
                    Spacer(minLength: 4)
                    Text(percent(m.value)).font(Theme.data(11, weight: .semibold))
                        .foregroundStyle(m.value >= 1 ? Theme.teal : Theme.coral)
                }
            }
            if mods.isEmpty {
                Text("Aucun").font(.system(size: 11)).foregroundStyle(Theme.steel)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.deep.opacity(0.75), in: HUDShape(cut: 8))
    }

    private func percent(_ v: Double) -> String {
        let p = Int(((v - 1) * 100).rounded())
        return p >= 0 ? "+\(p) %" : "\(p) %"
    }
}

// MARK: - Batailles en cours (panneau Armée)

struct BattlesCard: View {
    @ObservedObject var store: GameStore

    var body: some View {
        if let sim = store.sim {
            let battles = sim.playerBattles()
            if !battles.isEmpty {
                Dossier(title: "Batailles en cours", subtitle: "Touchez une bataille pour choisir vos tactiques") {
                    ForEach(battles.prefix(12)) { b in
                        Button { store.openBattle(b.province) } label: {
                            BattleRow(battle: b, side: sim.playerSide(in: b))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct BattleRow: View {
    let battle: Battle
    let side: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: TerrainMap.terrain(battle.province).icon).font(.system(size: 12)).foregroundStyle(Theme.steel)
                Text(ProvinceMap.all[battle.province].name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("\(Geo.flag(battle.attacker)) \(battle.attackerDivisions) ⚔︎ \(battle.defenderDivisions) \(Geo.flag(battle.defender))")
                    .font(Theme.data(12, weight: .semibold)).foregroundStyle(Theme.paper)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.steel)
            }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.attacker))).frame(width: geo.size.width * battle.balance)
                    Rectangle().fill(Color(uiColor: Theme.politicalColor(battle.defender)))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: HUDShape(cut: 7))
    }
}

// MARK: - Réorganiser une armée (division par division)

/// Déplacer des divisions entre les armées d'une même région, ou entre l'armée et la réserve de la base.
struct ArmyOrganizer: View {
    @ObservedObject var store: GameStore
    let armyID: Int

    var body: some View {
        let _ = store.version
        if let sim = store.sim, let a = sim.state.armies.first(where: { $0.id == armyID }) {
            let others = sim.state.armies.filter { $0.owner == a.owner && $0.province == a.province && $0.id != a.id }
            let atBase = sim.hasBase(a.province, for: a.owner)
            let depot = sim.depot(at: a.province)
            PanelHeader(title: a.name, subtitle: "\(a.count)/\(Army.maxDivisions) divisions · \(ProvinceMap.all[a.province].name)",
                        flag: a.owner) { store.panel = nil }
            Text("Touchez ← ou → pour faire passer une division d'un côté à l'autre. Seules les forces d'une même région peuvent s'échanger des divisions.")
                .font(Theme.small).foregroundStyle(Theme.steel)
            if atBase {
                exchange(sim, a, title: "Réserve de la base", subtitle: "Divisions prêtes, hors armée", other: depot, otherID: nil)
            }
            ForEach(others) { o in
                exchange(sim, a, title: o.name, subtitle: "\(o.count)/\(Army.maxDivisions) · \(o.general.name)", other: o.divisions, otherID: o.id)
            }
            if !atBase && others.isEmpty {
                Dossier(title: "Personne à côté") {
                    Text("Amenez une autre armée dans \(ProvinceMap.all[a.province].name), ou envoyez celle-ci à une base pour puiser dans la réserve.")
                        .font(Theme.small).foregroundStyle(Theme.steel)
                    QuietButton(title: "Rentrer à la base", icon: "star.square", tint: Theme.amber) {
                        store.perform { s, _ in s.sendToBase(armyID) }
                    }
                }
            }
            HStack(spacing: 8) {
                ActionButton(title: "Diviser en deux", icon: "square.split.2x1", tint: Theme.sky) {
                    store.perform { s, _ in s.splitArmy(armyID) }
                }
                if !others.isEmpty {
                    ActionButton(title: "Tout fusionner", icon: "square.stack.3d.up", tint: Theme.teal) {
                        store.perform { s, _ in s.mergeArmies(at: armyID) }
                    }
                }
            }
        } else {
            PanelHeader(title: "Armée dissoute") { store.panel = nil }
        }
    }

    private func exchange(_ sim: Simulation, _ a: Army, title: String, subtitle: String,
                          other: [DivisionType: Int], otherID: Int?) -> some View {
        Dossier(title: title, subtitle: subtitle) {
            HStack {
                Text(a.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.amber)
                Spacer()
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.steel)
            }
            ForEach(DivisionType.allCases.filter { (a.divisions[$0] ?? 0) + (other[$0] ?? 0) > 0 }, id: \.self) { t in
                let mine = a.divisions[t] ?? 0
                let theirs = other[t] ?? 0
                HStack(spacing: 8) {
                    Text("\(mine)").font(Theme.data(16, weight: .bold)).foregroundStyle(Theme.paper).frame(width: 34)
                    arrow("arrow.left", enabled: theirs > 0 && a.count < Army.maxDivisions) {
                        store.perform { s, _ in
                            if let o = otherID { return s.transferDivisions(t, count: 1, from: o, to: a.id) }
                            return s.reinforceFromDepot(a.id, type: t, count: 1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        UnitSymbol(type: t, color: Theme.steel.opacity(0.6), size: 22)
                        Text(t.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.paper)
                    }
                    Spacer()
                    arrow("arrow.right", enabled: mine > 0) {
                        store.perform { s, _ in s.transferDivisions(t, count: 1, from: a.id, to: otherID) }
                    }
                    Text("\(theirs)").font(Theme.data(16, weight: .bold)).foregroundStyle(Theme.paper).frame(width: 34)
                }
            }
        }
    }

    private func arrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? Theme.ink : Theme.steel.opacity(0.4))
                .frame(width: 44, height: 38)
                .background(enabled ? Theme.amber : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(Pressable())
        .disabled(!enabled)
    }
}


// MARK: - Opérations d'une armée

/// Plusieurs façons d'envahir : assaut, tenaille, bombardement, parachutage, troupes envoyées chez un allié.
struct OperationsRow: View {
    @ObservedObject var store: GameStore
    let army: Army
    let sim: Simulation

    var body: some View {
        let para = Double(army.divisions[.airborne] ?? 0) / Double(max(1, army.count))
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                op(.encircle, "Tenaille", enabled: !store.armyGroup.isEmpty)
                op(.bombard, "Bombarder", enabled: true)
                op(.airdrop, "Parachuter", enabled: para >= 0.6)
                Menu {
                    let p = store.playerID ?? ""
                    let hosts = sim.countryIDs.filter { $0 != p && sim.isAtWar($0) && !sim.enemies(of: p).contains($0) && sim.relation(p, $0) > -20 }
                        .sorted { sim.relation(p, $0) > sim.relation(p, $1) }.prefix(12)
                    if let host = army.servingFor {
                        Button("Rappeler (sert \(sim.name(host)))", systemImage: "arrow.uturn.backward") {
                            let id = army.id
                            store.perform { s, _ in s.recallExpedition(id) }
                        }
                    }
                    Section("En secret (volontaires)") {
                        ForEach(Array(hosts), id: \.self) { h in
                            Button("\(Geo.flag(h)) \(sim.name(h))") {
                                let id = army.id
                                store.perform { s, _ in s.sendExpedition(id, to: h, covert: true) }
                            }
                        }
                    }
                    Section("Officiellement") {
                        ForEach(Array(hosts), id: \.self) { h in
                            Button("\(Geo.flag(h)) \(sim.name(h))") {
                                let id = army.id
                                store.perform { s, _ in s.sendExpedition(id, to: h, covert: false) }
                            }
                        }
                    }
                } label: {
                    chip(army.servingFor == nil ? "Aider un pays" : "Au service de \(sim.name(army.servingFor ?? ""))",
                         icon: "figure.walk.departure", on: army.servingFor != nil, enabled: true)
                }
            }
        }
    }

    private func op(_ o: ArmyOperation, _ title: String, enabled: Bool) -> some View {
        Button {
            store.armyOp = store.armyOp == o ? nil : o
        } label: {
            chip(title, icon: o.icon, on: store.armyOp == o, enabled: enabled)
        }
        .buttonStyle(Pressable())
        .disabled(!enabled)
    }

    private func chip(_ title: String, icon: String, on: Bool, enabled: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(on ? Theme.ink : (enabled ? Theme.coral : Theme.steel.opacity(0.5)))
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(on ? Theme.coral : Theme.coral.opacity(enabled ? 0.12 : 0.04), in: Capsule())
    }
}
