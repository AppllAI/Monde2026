import SwiftUI

// =============================================================
//  Doctrine.swift
//  Les modèles de division : de la profondeur pour qui la veut.
//  Par défaut, chaque type de division (infanterie, blindée…)
//  est « standard » : correct partout, sans rien à régler.
//  Le joueur qui creuse peut lui adjoindre jusqu'à 4 compagnies
//  de soutien (artillerie, génie, drones, logistique…) : plus
//  forte là où il le veut, mais plus chère et plus longue à
//  former. Chaque choix a un prix : il n'y a pas de modèle
//  parfait, seulement des modèles adaptés à une guerre.
// =============================================================

enum SupportCompany: String, Codable, CaseIterable, Identifiable {
    case artillery, antiTank, antiAir, engineers, recon, drones, logistics, medics, electronicWarfare

    var id: String { rawValue }

    var name: String {
        switch self {
        case .artillery: return "Artillerie"
        case .antiTank: return "Antichar"
        case .antiAir: return "Défense aérienne"
        case .engineers: return "Génie"
        case .recon: return "Reconnaissance"
        case .drones: return "Drones"
        case .logistics: return "Logistique"
        case .medics: return "Santé"
        case .electronicWarfare: return "Guerre électronique"
        }
    }

    var icon: String {
        switch self {
        case .artillery: return "scope"
        case .antiTank: return "shield.slash.fill"
        case .antiAir: return "airplane.circle.fill"
        case .engineers: return "hammer.fill"
        case .recon: return "binoculars.fill"
        case .drones: return "dot.radiowaves.up.forward"
        case .logistics: return "shippingbox.fill"
        case .medics: return "cross.case.fill"
        case .electronicWarfare: return "antenna.radiowaves.left.and.right"
        }
    }

    var tint: Color {
        switch self {
        case .artillery, .antiTank: return Theme.coral
        case .antiAir, .electronicWarfare: return Theme.violet
        case .engineers, .logistics: return Theme.amber
        case .recon, .drones: return Theme.sky
        case .medics: return Theme.teal
        }
    }

    var summary: String {
        switch self {
        case .artillery: return "Écrase l'infanterie et les défenses. Ralentit un peu."
        case .antiTank: return "Brise les offensives blindées."
        case .antiAir: return "Protège des frappes : l'ennemi profite moins de son aviation."
        case .engineers: return "Retranchement, ponts : le terrain et les fleuves gênent deux fois moins."
        case .recon: return "Voit avant de frapper : percée et vitesse."
        case .drones: return "Frappes précises contre tout."
        case .logistics: return "Avance plus vite et tient mieux sans ravitaillement."
        case .medics: return "Moins de morts, moral qui remonte plus vite."
        case .electronicWarfare: return "Brouille l'ennemi : un peu plus fort en attaque comme en défense."
        }
    }

    /// Ce que la compagnie apporte (multiplicateurs ajoutés : +0,25 = +25 %).
    var effect: SupportEffect {
        switch self {
        case .artillery: return SupportEffect(soft: 0.25, hard: 0.05, defense: 0.05, breakthrough: 0.05, speed: -0.05, cost: 0.12)
        case .antiTank: return SupportEffect(hard: 0.40, defense: 0.06, cost: 0.10)
        case .antiAir: return SupportEffect(soft: 0.02, defense: 0.08, cost: 0.10, airCover: 0.5)
        case .engineers: return SupportEffect(defense: 0.14, cost: 0.08, terrain: 0.5)
        case .recon: return SupportEffect(soft: 0.05, breakthrough: 0.12, speed: 0.10, cost: 0.06)
        case .drones: return SupportEffect(soft: 0.10, hard: 0.12, defense: 0.03, cost: 0.12)
        case .logistics: return SupportEffect(speed: 0.10, cost: 0.06, supply: 0.5)
        case .medics: return SupportEffect(cost: 0.06, losses: -0.25)
        case .electronicWarfare: return SupportEffect(soft: 0.06, hard: 0.06, defense: 0.06, cost: 0.14)
        }
    }

    /// Certaines compagnies demandent une technologie.
    var requiredTech: TechID? {
        switch self {
        case .drones: return .autonomousDrones
        case .electronicWarfare: return .electronicWarfare
        default: return nil
        }
    }
}

/// Effets cumulés d'un modèle de division.
struct SupportEffect: Equatable {
    var soft = 0.0
    var hard = 0.0
    var defense = 0.0
    var breakthrough = 0.0
    var speed = 0.0
    var cost = 0.0              // hommes, matériel et temps de formation en plus
    var airCover = 0.0          // part de la supériorité aérienne ennemie annulée
    var terrain = 0.0           // part de la gêne du terrain annulée
    var supply = 0.0            // part de la pénalité de ravitaillement annulée
    var losses = 0.0            // pertes en moins (négatif)

    init(soft: Double = 0, hard: Double = 0, defense: Double = 0, breakthrough: Double = 0, speed: Double = 0,
         cost: Double = 0, airCover: Double = 0, terrain: Double = 0, supply: Double = 0, losses: Double = 0) {
        self.soft = soft; self.hard = hard; self.defense = defense; self.breakthrough = breakthrough
        self.speed = speed; self.cost = cost; self.airCover = airCover; self.terrain = terrain
        self.supply = supply; self.losses = losses
    }

    static func + (l: SupportEffect, r: SupportEffect) -> SupportEffect {
        SupportEffect(soft: l.soft + r.soft, hard: l.hard + r.hard, defense: l.defense + r.defense,
                      breakthrough: l.breakthrough + r.breakthrough, speed: l.speed + r.speed, cost: l.cost + r.cost,
                      airCover: min(1, l.airCover + r.airCover), terrain: min(1, l.terrain + r.terrain),
                      supply: min(1, l.supply + r.supply), losses: max(-0.6, l.losses + r.losses))
    }
}

struct DivisionTemplate: Codable, Equatable {
    var supports: [SupportCompany] = []

    static let maxSupports = 4

    var effect: SupportEffect {
        supports.reduce(SupportEffect()) { $0 + $1.effect }
    }
}

/// Modèles tout prêts : un geste pour orienter son armée.
enum TemplatePreset: String, CaseIterable, Identifiable {
    case standard, assault, defense, mobile, attrition

    var id: String { rawValue }

    var name: String {
        switch self {
        case .standard: return "Standard"
        case .assault: return "Choc"
        case .defense: return "Rempart"
        case .mobile: return "Éclair"
        case .attrition: return "Usure"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "circle.grid.2x2"
        case .assault: return "flame.fill"
        case .defense: return "shield.fill"
        case .mobile: return "bolt.fill"
        case .attrition: return "hourglass"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "Aucun soutien : pas cher, rapide à former."
        case .assault: return "Artillerie et reconnaissance pour percer."
        case .defense: return "Génie et antichar pour tenir la ligne."
        case .mobile: return "Reconnaissance et logistique pour aller vite et loin."
        case .attrition: return "Artillerie, santé et logistique pour une longue guerre."
        }
    }

    var supports: [SupportCompany] {
        switch self {
        case .standard: return []
        case .assault: return [.artillery, .recon]
        case .defense: return [.engineers, .antiTank]
        case .mobile: return [.recon, .logistics]
        case .attrition: return [.artillery, .medics, .logistics]
        }
    }
}

extension Simulation {

    func template(_ owner: CountryID, _ type: DivisionType) -> DivisionTemplate {
        state.templates[owner]?[type] ?? DivisionTemplate()
    }

    /// Effet moyen des modèles sur une armée (pondéré par le nombre de divisions).
    func armyEffect(_ a: Army) -> SupportEffect {
        guard let byType = state.templates[a.owner], !byType.isEmpty else { return SupportEffect() }
        var total = SupportEffect()
        var minSpeed = 0.0
        var first = true
        let n = Double(max(1, a.count))
        for (t, count) in a.divisions where count > 0 {
            let e = byType[t]?.effect ?? SupportEffect()
            let w = Double(count) / n
            total.soft += e.soft * w
            total.hard += e.hard * w
            total.defense += e.defense * w
            total.breakthrough += e.breakthrough * w
            total.cost += e.cost * w
            total.airCover += e.airCover * w
            total.terrain += e.terrain * w
            total.supply += e.supply * w
            total.losses += e.losses * w
            // Une armée va à la vitesse de ses divisions les plus lentes.
            minSpeed = first ? e.speed : min(minSpeed, e.speed)
            first = false
        }
        total.speed = minSpeed
        return total
    }

    mutating func setTemplate(_ template: DivisionTemplate, for type: DivisionType, owner: CountryID) -> ActionResult {
        guard template.supports.count <= DivisionTemplate.maxSupports else {
            return ActionResult(success: false, message: "Au plus \(DivisionTemplate.maxSupports) compagnies de soutien.")
        }
        if let c = state.countries[owner], let missing = template.supports.first(where: { $0.requiredTech.map { !c.has($0) } ?? false }) {
            return ActionResult(success: false, message: "\(missing.name) : technologie à rechercher d'abord.")
        }
        var all = state.templates[owner] ?? [:]
        all[type] = template.supports.isEmpty ? nil : template
        state.templates[owner] = all.isEmpty ? nil : all
        return ActionResult(success: true, message: "Modèle « \(type.name) » mis à jour : effet immédiat ; chaque recrue coûte désormais un peu plus.")
    }
}

// MARK: - Éditeur de modèles

struct TemplatesPanel: View {
    @ObservedObject var store: GameStore
    @State private var picking: DivisionType?

    var body: some View {
        if let sim = store.sim, let c = store.player {
            PanelHeader(title: "Modèles de division", subtitle: "Facultatif : les divisions standard suffisent pour jouer", flag: c.id) {
                store.panel = nil
            }
            HStack(alignment: .top, spacing: 10) {
                IconTile(icon: "lightbulb.fill", tint: Theme.amber, size: 30)
                Text("Ajoutez des compagnies de soutien à chaque type de division. Plus fortes là où vous le voulez, mais plus chères et plus longues à former. Adaptez vos modèles à la guerre que vous menez.")
                    .font(.system(size: 12.5)).foregroundStyle(Theme.paper.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(DivisionType.allCases, id: \.self) { type in
                TemplateCard(store: store, sim: sim, country: c, type: type, picking: $picking)
            }
        }
    }
}

struct TemplateCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country
    let type: DivisionType
    @Binding var picking: DivisionType?

    var body: some View {
        let t = sim.template(country.id, type)
        let e = t.effect
        let owned = country.divisions[type] ?? 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                UnitIcons.image(type).resizable().scaledToFit()
                    .foregroundStyle(Theme.paper)
                    .padding(7)
                    .frame(width: 46, height: 36)
                    .background(HUDShape(cut: 7).fill(Color(uiColor: Theme.politicalColor(country.id)).opacity(0.55)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.name.uppercased()).font(Theme.title(17)).tracking(0.6).foregroundStyle(Theme.paper)
                    Text("\(owned) division\(owned > 1 ? "s" : "") · formation \(Int(Double(type.trainingDays) * (1 + e.cost))) j")
                        .font(Theme.small).foregroundStyle(Theme.steel)
                }
                Spacer()
                Menu {
                    ForEach(TemplatePreset.allCases) { preset in
                        Button(preset.name + " — " + preset.detail, systemImage: preset.icon) {
                            let tpl = DivisionTemplate(supports: preset.supports)
                            store.perform { s, p in s.setTemplate(tpl, for: type, owner: p) }
                        }
                    }
                } label: {
                    Label("Modèle", systemImage: "wand.and.stars").font(Theme.label(12))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(HUDShape(cut: 6, radius: 2).fill(Theme.amber.opacity(0.12)))
                        .overlay(HUDShape(cut: 6, radius: 2).strokeBorder(Theme.amber.opacity(0.35)))
                }
            }
            // Les statistiques : base et effet du modèle
            let s = type.stats
            VStack(spacing: 6) {
                statRow("Attaque infanterie", base: s.softAttack, bonus: e.soft, max: 25, tint: Theme.coral)
                statRow("Attaque blindés", base: s.hardAttack, bonus: e.hard, max: 25, tint: Theme.coral)
                statRow("Défense", base: s.defense, bonus: e.defense, max: 25, tint: Theme.teal)
                statRow("Percée", base: s.breakthrough, bonus: e.breakthrough, max: 25, tint: Theme.amber)
                statRow("Vitesse", base: 10, bonus: e.speed, max: 13, tint: Theme.sky)
                statRow("Coût", base: 10, bonus: e.cost, max: 16, tint: Theme.steel)
            }
            // Les 4 emplacements de soutien
            HStack(spacing: 8) {
                ForEach(0..<DivisionTemplate.maxSupports, id: \.self) { i in
                    if i < t.supports.count {
                        let sc = t.supports[i]
                        Button {
                            var tpl = t
                            tpl.supports.remove(at: i)
                            store.perform { s, p in s.setTemplate(tpl, for: type, owner: p) }
                        } label: {
                            VStack(spacing: 4) {
                                IconTile(icon: sc.icon, tint: sc.tint, size: 34, filled: true)
                                Text(sc.name).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Theme.paper)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(Pressable())
                    } else {
                        Button { withAnimation(.snappy) { picking = picking == type ? nil : type } } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.steel)
                                    .frame(width: 34, height: 34)
                                    .overlay(HUDShape(cut: 7, radius: 2).strokeBorder(Theme.steel.opacity(0.5),
                                                                                  style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                                Text("Soutien").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Theme.steel)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(Pressable())
                    }
                }
            }
            if picking == type {
                let available = SupportCompany.allCases.filter { !t.supports.contains($0) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(available) { sc in
                        let locked = sc.requiredTech.map { !country.has($0) } ?? false
                        Button {
                            var tpl = t
                            tpl.supports.append(sc)
                            store.perform { s, p in s.setTemplate(tpl, for: type, owner: p) }
                            picking = nil
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                IconTile(icon: locked ? "lock.fill" : sc.icon, tint: locked ? Theme.steel : sc.tint, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sc.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.paper)
                                    Text(locked ? "Technologie requise" : sc.summary).font(.system(size: 10.5))
                                        .foregroundStyle(Theme.steel).lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HUDShape(cut: 7).fill(Color.white.opacity(0.05)))
                            .overlay(HUDShape(cut: 7).strokeBorder(sc.tint.opacity(locked ? 0.1 : 0.3)))
                        }
                        .buttonStyle(Pressable())
                        .disabled(locked)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(HUDShape(cut: 10).fill(LinearGradient(colors: [Theme.raised.opacity(0.85), Theme.deep.opacity(0.8)],
                                                          startPoint: .top, endPoint: .bottom)))
        .overlay(HUDShape(cut: 10).strokeBorder(t.supports.isEmpty ? Color.white.opacity(0.07) : Theme.amber.opacity(0.35)))
    }

    /// Une statistique : barre segmentée de base, et la part ajoutée (ou retirée) par le modèle.
    private func statRow(_ label: String, base: Double, bonus: Double, max: Double, tint: Color) -> some View {
        let value = base * (1 + bonus)
        return HStack(spacing: 8) {
            Text(label.uppercased()).font(Theme.label(10)).tracking(0.6).foregroundStyle(Theme.steel)
                .frame(width: 118, alignment: .leading)
            SegmentBar(value: value / max, tint: tint, segments: 14, height: 6)
            Text(bonus == 0 ? "—" : (bonus > 0 ? "+\(Int((bonus * 100).rounded())) %" : "\(Int((bonus * 100).rounded())) %"))
                .font(Theme.data(11, weight: .bold))
                .foregroundStyle(bonus == 0 ? Theme.steel : (label == "Coût" ? (bonus > 0 ? Theme.coral : Theme.teal) : (bonus > 0 ? Theme.teal : Theme.coral)))
                .frame(width: 44, alignment: .trailing)
        }
    }
}
