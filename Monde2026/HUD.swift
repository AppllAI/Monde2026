import SwiftUI

// =============================================================
//  HUD.swift
//  Le langage visuel du jeu, façon « centre de commandement » :
//   - panneaux à coins coupés (biseaux), liseré lumineux,
//   - tuiles d'icônes colorées (chaque notion a son logo),
//   - titres en capitales étroites, chiffres arrondis,
//   - jauges segmentées.
//  Tout le reste de l'interface s'appuie sur ces briques.
// =============================================================

/// Rectangle aux coins biseautés (haut-gauche et bas-droit coupés).
struct HUDShape: InsettableShape {
    var cut: CGFloat = 12
    var radius: CGFloat = 4
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = min(cut, r.width / 3, r.height / 3)
        let k = min(radius, c)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - k, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + k), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + k, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - k), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> HUDShape {
        var s = self
        s.inset += amount
        return s
    }
}

/// Tuile d'icône : un logo coloré pour chaque notion du jeu.
struct IconTile: View {
    let icon: String
    var tint: Color = Theme.amber
    var size: CGFloat = 34
    var filled = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(filled ? Theme.ink : tint)
            .frame(width: size, height: size)
            .background(
                HUDShape(cut: size * 0.22, radius: 3)
                    .fill(filled ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0.10)], startPoint: .top, endPoint: .bottom)))
            )
            .overlay(HUDShape(cut: size * 0.22, radius: 3).strokeBorder(tint.opacity(filled ? 0 : 0.45), lineWidth: 1))
    }
}

/// Titre de section : petite barre d'accent, capitales, filet qui s'étire.
struct HUDTitle: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Theme.amber

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                IconTile(icon: icon, tint: tint, size: 24)
            } else {
                Rectangle().fill(tint).frame(width: 3, height: 14)
            }
            Text(text.uppercased())
                .font(Theme.label(13))
                .tracking(1.2)
                .foregroundStyle(Theme.paper)
                .lineLimit(1)
            Rectangle()
                .fill(LinearGradient(colors: [tint.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
    }
}

/// Fond des panneaux : dégradé sombre, biseaux, liseré et reflet en haut.
struct HUDPanel: ViewModifier {
    var cut: CGFloat = 14
    var tint: Color = Theme.sky

    func body(content: Content) -> some View {
        content
            .background(
                HUDShape(cut: cut)
                    .fill(LinearGradient(colors: [Theme.deep.opacity(0.94), Theme.ink.opacity(0.92)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .background(.ultraThinMaterial, in: HUDShape(cut: cut))
            .overlay(
                HUDShape(cut: cut)
                    .strokeBorder(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.08), tint.opacity(0.25)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }
}

extension View {
    func hudPanel(_ cut: CGFloat = 14, tint: Color = Theme.sky) -> some View { modifier(HUDPanel(cut: cut, tint: tint)) }
}

/// Jauge segmentée (façon jeu) : lisible d'un coup d'œil.
struct SegmentBar: View {
    let value: Double
    var tint: Color = Theme.teal
    var segments = 10
    var height: CGFloat = 7

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                let filled = Double(i) < (value.clamped(0, 1) * Double(segments)).rounded(.up) && value > 0
                Rectangle()
                    .fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .frame(height: height)
                    .shadow(color: filled ? tint.opacity(0.6) : .clear, radius: 2)
            }
        }
    }
}

/// Ressource de la barre du haut : tuile d'icône + valeur + libellé.
struct ResourceChip: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = Theme.amber
    var warn = false

    var body: some View {
        HStack(spacing: 7) {
            IconTile(icon: icon, tint: warn ? Theme.coral : tint, size: 28)
            VStack(alignment: .leading, spacing: -1) {
                Text(value).font(Theme.data(14, weight: .bold)).foregroundStyle(warn ? Theme.coral : Theme.paper).lineLimit(1)
                Text(label.uppercased()).font(Theme.label(9)).tracking(0.8).foregroundStyle(Theme.steel).lineLimit(1)
            }
        }
    }
}
