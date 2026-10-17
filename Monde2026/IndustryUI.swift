import SwiftUI

// =============================================================
//  IndustryUI.swift
//  Les complexes industriels à l'écran : la liste par type
//  (onglet Industrie) et la construction dans une région.
// =============================================================

extension BuildingKind {
    var color: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
}

struct IndustryCard: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let country: Country

    var body: some View {
        let totals = sim.industryTotals(country.id)
        let jobs = sim.state.constructions.filter { $0.owner == country.id && $0.kind.isIndustry }
        Dossier(title: "Complexes industriels",
                subtitle: "Chaque complexe rapporte de l'argent et sert à quelque chose. Touchez « Construire », puis une région en surbrillance.") {
            ForEach(BuildingKind.industries) { kind in
                let (cost, days) = sim.buildCost(kind, at: 0, for: country.id)
                let blocked = sim.suggestedRegion(for: kind, id: country.id) == nil
                HStack(spacing: 12) {
                    Image(systemName: kind.icon).font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 42, height: 42)
                        .background(kind.color, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(kind.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                            Text("× \(totals[kind] ?? 0)").font(Theme.data(12, weight: .semibold)).foregroundStyle(kind.color)
                        }
                        Text(kind.effectSummary).font(.system(size: 11)).foregroundStyle(Theme.steel).lineLimit(2)
                        Text("\(Fmt.money(cost)) · \(days) jours").font(Theme.data(10)).foregroundStyle(Theme.steel.opacity(0.8))
                    }
                    Spacer(minLength: 4)
                    Button { store.startPlacing(kind) } label: {
                        Text("Construire").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(blocked ? Theme.steel : Theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(blocked ? Color.white.opacity(0.06) : Theme.amber, in: Capsule())
                    }
                    .buttonStyle(Pressable())
                    .disabled(blocked)
                }
            }
            if !jobs.isEmpty {
                Text("Chantiers en cours").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                ForEach(jobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: job.kind.icon).foregroundStyle(job.kind.color)
                            Text("\(job.kind.name) à \(ProvinceMap.all[job.province].name)").font(.system(size: 12)).foregroundStyle(Theme.paper)
                            Spacer()
                            Text("\(job.daysLeft) j").font(Theme.data(11)).foregroundStyle(Theme.steel)
                        }
                        Meter(value: job.progress, tint: job.kind.color, height: 4)
                    }
                }
            }
            let bonus = sim.state.industryCache[country.id] ?? IndustryBonus()
            FigureGrid(items: [
                ("Recherche", Fmt.signedPct(bonus.research - 1, 0), Theme.teal),
                ("Formation", Fmt.signedPct(bonus.training - 1, 0), Theme.amber),
                ("Divisions", Fmt.signedPct(bonus.arms - 1, 1), Theme.coral)
            ], columns: 3)
        }
    }
}

/// Dans la fiche d'une région : ses complexes et les boutons pour en construire.
struct RegionIndustry: View {
    @ObservedObject var store: GameStore
    let sim: Simulation
    let province: Int

    var body: some View {
        let list = sim.complexes(at: province)
        let used = sim.complexCount(at: province)
        let slots = sim.industrySlots(province)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Industrie").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.paper)
                Spacer()
                Text("\(used)/\(slots) emplacements").font(Theme.data(11)).foregroundStyle(Theme.steel)
            }
            HStack(spacing: 6) {
                ForEach(BuildingKind.industries.filter { (list[$0] ?? 0) > 0 }) { k in
                    HStack(spacing: 4) {
                        Image(systemName: k.icon).font(.system(size: 10, weight: .bold))
                        Text("\(list[k] ?? 0)").font(Theme.data(11, weight: .bold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(k.color, in: Capsule())
                }
                ForEach(0..<max(0, slots - used), id: \.self) { _ in
                    Capsule().strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .frame(width: 30, height: 22)
                }
            }
            if let pid = store.playerID, sim.controller(of: province) == pid, sim.construction(at: province) == nil, used < slots {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                    ForEach(BuildingKind.industries) { k in
                        let blocked = sim.canBuild(k, at: province, for: pid)
                        Button {
                            store.perform { s, p in s.build(k, at: province, for: p) }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: k.icon).font(.system(size: 14, weight: .semibold))
                                Text(k.name.replacingOccurrences(of: "Usine ", with: "")).font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(blocked == nil ? Theme.ink : Theme.steel.opacity(0.5))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(blocked == nil ? k.color : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(Pressable())
                        .disabled(blocked != nil)
                    }
                }
            }
        }
    }
}
