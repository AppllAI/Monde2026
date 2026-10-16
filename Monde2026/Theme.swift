import SwiftUI
import UIKit

// =============================================================
//  Theme.swift
//  Identité visuelle « salle de situation » : encre marine,
//  ambre de signalisation pour le joueur, corail pour la guerre,
//  sarcelle pour les alliés. Titres en serif (New York) comme
//  un dossier diplomatique, chiffres en SF à chasse fixe.
// =============================================================

enum Theme {
    static let ink = Color(red: 0.043, green: 0.086, blue: 0.133)        // #0B1622
    static let deep = Color(red: 0.067, green: 0.125, blue: 0.188)       // #112030
    static let steel = Color(red: 0.56, green: 0.64, blue: 0.72)         // #8FA3B8
    static let paper = Color(red: 0.93, green: 0.94, blue: 0.95)
    static let amber = Color(red: 0.95, green: 0.71, blue: 0.27)         // #F2B544 — le joueur
    static let coral = Color(red: 0.90, green: 0.33, blue: 0.29)         // #E5534B — la guerre
    static let teal = Color(red: 0.23, green: 0.72, blue: 0.65)          // #3BB8A6 — les alliés
    static let sky = Color(red: 0.42, green: 0.66, blue: 0.95)

    static let line = Color.white.opacity(0.10)

    // Typographie
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }
    static func data(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
    static let body = Font.system(size: 15)
    static let small = Font.system(size: 12)

    // MARK: Couleurs de carte

    /// Couleur stable propre à chaque pays (mode « Pays »).
    static func countryColor(_ id: CountryID) -> Color {
        var hash: UInt32 = 2166136261
        for scalar in id.unicodeScalars {
            hash = (hash ^ scalar.value) &* 16777619
        }
        let hue = Double(hash % 360) / 360
        return Color(hue: hue, saturation: 0.45, brightness: 0.78)
    }

    /// −100 → corail, 0 → acier, +100 → sarcelle.
    static func relationColor(_ value: Double) -> Color {
        let t = (value / 100).clamped(-1, 1)
        if t >= 0 {
            return blend(steel, teal, t)
        }
        return blend(steel, coral, -t)
    }

    /// Croissance −5 % → corail, +8 % → sarcelle.
    static func growthColor(_ growth: Double) -> Color {
        let t = ((growth + 0.05) / 0.13).clamped(0, 1)
        return t < 0.4 ? blend(coral, steel, t / 0.4) : blend(steel, teal, (t - 0.4) / 0.6)
    }

    static func blocColor(_ blocID: String?) -> Color {
        switch blocID {
        case "OTAN": return sky
        case "OTSC": return coral
        case "CCG": return Color(red: 0.36, green: 0.75, blue: 0.42)
        case "AES": return Color(red: 0.78, green: 0.55, blue: 0.33)
        case "USA-ALLY": return Color(red: 0.55, green: 0.78, blue: 0.98)
        case "CHN-ALLY": return Color(red: 0.95, green: 0.55, blue: 0.30)
        case nil: return steel.opacity(0.55)
        case .some(let custom): return countryColor(custom)
        }
    }

    static func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = UIColor(a), cb = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ca.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(t.clamped(0, 1))
        return Color(red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k),
                     blue: Double(b1 + (b2 - b1) * k), opacity: Double(a1 + (a2 - a1) * k))
    }
}

// MARK: - Formats

enum Fmt {
    private static func fr(_ value: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Montant en milliards de dollars.
    static func money(_ bn: Double) -> String {
        let v = abs(bn)
        let sign = bn < 0 ? "−" : ""
        if v >= 1000 { return sign + fr(v / 1000, 1) + " T$" }
        if v >= 10 { return sign + fr(v, 0) + " Md$" }
        if v >= 1 { return sign + fr(v, 1) + " Md$" }
        return sign + fr(v * 1000, 0) + " M$"
    }

    /// Fraction → pourcentage.
    static func pct(_ fraction: Double, _ decimals: Int = 1) -> String {
        fr(fraction * 100, decimals) + " %"
    }

    static func signedPct(_ fraction: Double, _ decimals: Int = 1) -> String {
        (fraction >= 0 ? "+" : "−") + fr(abs(fraction) * 100, decimals) + " %"
    }

    /// Nombre compact (1,2 M ; 450 k ; 37).
    static func count(_ value: Double) -> String {
        let v = abs(value)
        if v >= 1_000_000 { return fr(value / 1_000_000, 1) + " M" }
        if v >= 10_000 { return fr(value / 1000, 0) + " k" }
        return fr(value, 0)
    }

    /// Effectifs donnés en milliers d'hommes.
    static func troops(_ thousands: Double) -> String {
        if thousands >= 1000 { return fr(thousands / 1000, 2) + " M" }
        return fr(thousands, 0) + " k"
    }

    static func population(_ millions: Double) -> String {
        if millions >= 1000 { return fr(millions / 1000, 2) + " Md hab." }
        if millions >= 10 { return fr(millions, 0) + " M hab." }
        return fr(millions, 1) + " M hab."
    }

    static func number(_ value: Double, _ decimals: Int = 0) -> String { fr(value, decimals) }
}
