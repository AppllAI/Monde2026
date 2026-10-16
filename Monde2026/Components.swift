import SwiftUI

// =============================================================
//  Components.swift
//  Petites briques d'interface réutilisées partout.
// =============================================================

/// Fond « verre fumé » des panneaux posés sur la carte.
struct Glass: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.line))
    }
}

extension View {
    func glass(_ radius: CGFloat = 20) -> some View { modifier(Glass(radius: radius)) }
}

/// Bloc de contenu dans un panneau : un titre en serif et son contenu.
struct Dossier<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.title(19)).foregroundStyle(Theme.paper)
                if let subtitle {
                    Text(subtitle).font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.deep.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Une valeur chiffrée avec son libellé.
struct Figure: View {
    let label: String
    let value: String
    var tint: Color = Theme.paper

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(Theme.data(18, weight: .semibold)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(Theme.small).foregroundStyle(Theme.steel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Grille de chiffres sur 2 ou 3 colonnes.
struct FigureGrid: View {
    let items: [(String, String, Color)]
    var columns = 3

    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: columns)
        LazyVGrid(columns: cols, alignment: .leading, spacing: 14) {
            ForEach(items.indices, id: \.self) { i in
                Figure(label: items[i].0, value: items[i].1, tint: items[i].2)
            }
        }
    }
}

/// Barre de progression fine.
struct Meter: View {
    let value: Double          // 0…1
    var tint: Color = Theme.teal
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(tint).frame(width: max(height, geo.size.width * value.clamped(0, 1)))
            }
        }
        .frame(height: height)
    }
}

/// Relation de −100 à +100 sur une échelle centrée.
struct RelationScale: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = w / 2 + CGFloat(value.clamped(-100, 100) / 100) * w / 2
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Theme.coral, Theme.steel.opacity(0.6), Theme.teal],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 4).clipShape(Capsule())
                Circle().fill(Theme.paper).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    .offset(x: x - 6)
            }
        }
        .frame(height: 12)
    }
}

struct FlagBadge: View {
    let id: CountryID
    var size: CGFloat = 28

    var body: some View {
        Text(Geo.flag(id)).font(.system(size: size))
    }
}

/// Ligne « pays » réutilisable dans les listes.
struct CountryRow: View {
    let country: Country
    var detail: String
    var trailing: String? = nil
    var trailingTint: Color = Theme.steel

    var body: some View {
        HStack(spacing: 12) {
            FlagBadge(id: country.id, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(country.name).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.paper)
                Text(detail).font(Theme.small).foregroundStyle(Theme.steel).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing).font(Theme.data(14, weight: .semibold)).foregroundStyle(trailingTint)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Bouton d'action principal des panneaux.
struct ActionButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.amber
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(enabled ? Theme.ink : Theme.steel)
            .background(enabled ? tint : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Bouton secondaire discret.
struct QuietButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.paper
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(tint)
            .background(Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Décision de l'IA : verdict + raisons détaillées.
struct EvaluationView: View {
    let evaluation: Evaluation
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: evaluation.accepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(evaluation.accepted ? Theme.teal : Theme.coral)
                    Text(evaluation.accepted ? "Accepterait" : "Refuserait")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.paper)
                    Text("(\(Int(evaluation.score)))").font(Theme.data(13)).foregroundStyle(Theme.steel)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(Theme.steel)
                }
            }
            .buttonStyle(.plain)
            if expanded {
                ForEach(evaluation.reasons) { reason in
                    HStack {
                        Text(reason.text).font(Theme.small).foregroundStyle(Theme.paper.opacity(0.85))
                        Spacer()
                        Text(reason.value > 0 ? "+\(Int(reason.value))" : "\(Int(reason.value))")
                            .font(Theme.data(12, weight: .semibold))
                            .foregroundStyle(reason.value >= 0 ? Theme.teal : Theme.coral)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// En-tête commun des panneaux.
struct PanelHeader: View {
    let title: String
    var subtitle: String? = nil
    var flag: CountryID? = nil
    let close: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let flag { FlagBadge(id: flag, size: 36) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.title(26)).foregroundStyle(Theme.paper)
                if let subtitle {
                    Text(subtitle).font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
        }
    }
}
