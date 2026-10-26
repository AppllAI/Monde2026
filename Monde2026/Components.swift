import SwiftUI

// =============================================================
//  Components.swift
//  Petites briques d'interface réutilisées partout.
// =============================================================

/// Fond des panneaux posés sur la carte (style centre de commandement, coins biseautés).
struct Glass: ViewModifier {
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content.hudPanel(max(8, radius * 0.6))
    }
}

extension View {
    func glass(_ radius: CGFloat = 20) -> some View { modifier(Glass(radius: radius)) }
}

/// Bloc de contenu dans un panneau : titre en capitales avec son accent, puis le contenu.
struct Dossier<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = Theme.amber
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HUDTitle(text: title, icon: icon, tint: tint)
                if let subtitle {
                    Text(subtitle).font(Theme.small).foregroundStyle(Theme.steel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            HUDShape(cut: 10).fill(LinearGradient(colors: [Theme.raised.opacity(0.85), Theme.deep.opacity(0.8)],
                                                 startPoint: .top, endPoint: .bottom))
        )
        .overlay(HUDShape(cut: 10).strokeBorder(Color.white.opacity(0.07)))
    }
}

/// Une valeur chiffrée avec son libellé.
struct Figure: View {
    let label: String
    let value: String
    var tint: Color = Theme.paper

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.data(19, weight: .bold)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(Theme.label(9.5)).tracking(0.8).foregroundStyle(Theme.steel).lineLimit(1)
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

/// Barre de progression : dégradé lumineux et graduations.
struct Meter: View {
    let value: Double          // 0…1
    var tint: Color = Theme.teal
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let w = max(height, geo.size.width * value.clamped(0, 1))
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.08))
                Rectangle()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
                    .shadow(color: tint.opacity(0.55), radius: 3)
                // Graduations tous les 10 %
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { _ in
                        Spacer(minLength: 0)
                        Rectangle().fill(Theme.ink.opacity(0.55)).frame(width: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 1.5))
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

/// Bouton d'action principal des panneaux : plein, biseauté, en capitales.
struct ActionButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.amber
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .bold)) }
                Text(title.uppercased()).font(Theme.label(15)).tracking(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(enabled ? Theme.ink : Theme.steel)
            .background(
                HUDShape(cut: 9).fill(enabled ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                                              : AnyShapeStyle(Color.white.opacity(0.08)))
            )
            .overlay(HUDShape(cut: 9).strokeBorder(Color.white.opacity(enabled ? 0.35 : 0.05), lineWidth: 1))
            .shadow(color: enabled ? tint.opacity(0.35) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(Pressable())
        .disabled(!enabled)
    }
}

/// Bouton secondaire : contour coloré, discret.
struct QuietButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.paper
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .foregroundStyle(tint)
            .background(HUDShape(cut: 6, radius: 2).fill(tint.opacity(0.10)))
            .overlay(HUDShape(cut: 6, radius: 2).strokeBorder(tint.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(Pressable())
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
        .background(Color.white.opacity(0.05), in: HUDShape(cut: 7))
    }
}

/// En-tête commun des panneaux : drapeau en médaillon, titre en capitales étroites.
struct PanelHeader: View {
    let title: String
    var subtitle: String? = nil
    var flag: CountryID? = nil
    let close: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let flag {
                FlagBadge(id: flag, size: 30)
                    .frame(width: 46, height: 46)
                    .background(HUDShape(cut: 9).fill(Theme.raised))
                    .overlay(HUDShape(cut: 9).strokeBorder(Theme.amber.opacity(0.5), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(Theme.title(26)).tracking(0.6).foregroundStyle(Theme.paper)
                    .lineLimit(2).minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle).font(Theme.small).foregroundStyle(Theme.steel)
                }
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.paper)
                    .frame(width: 36, height: 36)
                    .background(HUDShape(cut: 7, radius: 2).fill(Color.white.opacity(0.08)))
                    .overlay(HUDShape(cut: 7, radius: 2).strokeBorder(Color.white.opacity(0.15)))
            }
            .buttonStyle(Pressable())
            .accessibilityLabel("Fermer")
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LinearGradient(colors: [Theme.amber.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
    }
}
