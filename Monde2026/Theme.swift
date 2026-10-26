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

    // MARK: Couleurs politiques de la carte (façon jeu de grande stratégie)

    static let neutralLand = UIColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1)
    static let rebelLand = UIColor(red: 0.30, green: 0.08, blue: 0.10, alpha: 1)

    private static func hex(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// Couleurs « historiques » des grandes puissances, reconnaissables au premier coup d'œil.
    private static let iconic: [CountryID: UInt32] = [
        "USA": 0x3D6CB4, "CAN": 0xC05656, "MEX": 0x4E9A6A, "BRA": 0x3E9E5C, "ARG": 0x86B9DF, "COL": 0xD9B649,
        "VEN": 0xB24A4A, "CHL": 0xA0526D, "PER": 0xC77B5B, "CUB": 0x5E7FB8,
        "GBR": 0xB43C49, "FRA": 0x3A58A8, "DEU": 0x6E7378, "ITA": 0x4F9E6E, "ESP": 0xD4A83B, "PRT": 0x2F7D57,
        "NLD": 0xE08A3A, "BEL": 0xC9B347, "CHE": 0xC8504F, "AUT": 0xD7D3C6, "POL": 0xCC5A6E, "SWE": 0x4F8FC7,
        "NOR": 0x8E4C4C, "FIN": 0xE3E1D5, "DNK": 0xA84444, "GRC": 0x5AA0D6, "ROU": 0xD8C24A, "HUN": 0x6E9E4A,
        "CZE": 0x4E6FA6, "UKR": 0xE3C14B, "BLR": 0x7FA56A, "RUS": 0x4E7D46, "SRB": 0x9B4F5C, "BGR": 0x6EA56B,
        "TUR": 0xB34A3E, "IRN": 0x5FA376, "IRQ": 0xB8A06A, "SYR": 0x9C8A6A, "SAU": 0x5E9E5E, "ISR": 0x6F94C9,
        "EGY": 0xD6B66B, "ARE": 0x4F8C7A, "ARM": 0xD07E3E, "AZE": 0x4B9DB8, "GEO": 0xC9C1B6,
        "CHN": 0xC74B3A, "JPN": 0xE3D6B8, "KOR": 0x5A7DB5, "PRK": 0x8B3B48, "TWN": 0x3F6E9E, "MNG": 0x7C9BC9,
        "IND": 0xE38B3F, "PAK": 0x2E7A4E, "BGD": 0x4F9C66, "AFG": 0x9A8B6E, "KAZ": 0x58AFC9,
        "IDN": 0xB94A40, "VNM": 0xD2B04C, "THA": 0x6C5AA8, "MYS": 0x3F7BAE, "PHL": 0x5A88C8, "MMR": 0x7AA35A,
        "AUS": 0x5F8AB7, "NZL": 0x4F6E8E, "ZAF": 0xC8933F, "NGA": 0x4C9A5B, "ETH": 0xD3B24C, "COD": 0x6AA8D0,
        "DZA": 0x4E8F5A, "MAR": 0xB2504A, "LBY": 0x6E8F4A, "SDN": 0xA8875A, "KEN": 0x9C4E4E, "AGO": 0xB5544A
    ]

    static func politicalColor(_ id: CountryID) -> UIColor {
        if let c = palette[id] { return c }
        return baseColor(id)
    }

    private static func baseColor(_ id: CountryID) -> UIColor {
        if let v = iconic[id] { return hex(v) }
        var hash: UInt32 = 2166136261
        for scalar in id.unicodeScalars {
            hash = (hash ^ scalar.value) &* 16777619
        }
        let hue = CGFloat(hash % 360) / 360
        let sat = 0.38 + CGFloat((hash >> 9) % 20) / 100
        let bri = 0.62 + CGFloat((hash >> 17) % 18) / 100
        return UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1)
    }

    /// Palette finale : chaque pays garde sa couleur « historique », sauf si un voisin a presque la même
    /// (Ukraine et Roumanie, par exemple) ; le plus petit des deux change alors légèrement de teinte.
    private static let palette: [CountryID: UIColor] = {
        var area: [CountryID: Double] = [:]
        var neighbors: [CountryID: Set<CountryID>] = [:]
        let provinces = ProvinceMap.all
        for p in provinces {
            area[p.country, default: 0] += p.weight
            for n in p.neighbors where provinces[n].country != p.country {
                neighbors[p.country, default: []].insert(provinces[n].country)
            }
        }
        func rgb(_ c: UIColor) -> (CGFloat, CGFloat, CGFloat) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b)
        }
        func distance(_ a: UIColor, _ b: UIColor) -> CGFloat {
            let x = rgb(a), y = rgb(b)
            let dr = x.0 - y.0, dg = x.1 - y.1, db = x.2 - y.2
            return (2 * dr * dr + 4 * dg * dg + 3 * db * db).squareRoot() / 3
        }
        var out: [CountryID: UIColor] = [:]
        for id in area.keys.sorted(by: { (area[$0] ?? 0, $0) > (area[$1] ?? 0, $1) }) {
            let base = baseColor(id)
            let near = (neighbors[id] ?? []).compactMap { out[$0] }
            func score(_ c: UIColor) -> CGFloat { near.map { distance(c, $0) }.min() ?? 1 }
            if score(base) >= 0.13 {
                out[id] = base
                continue
            }
            var h: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, a: CGFloat = 0
            base.getHue(&h, saturation: &sat, brightness: &bri, alpha: &a)
            var best = base
            var bestScore = score(base)
            search: for shift in [0.07, -0.07, 0.14, -0.14, 0.22, -0.22, 0.33, -0.33, 0.5] as [CGFloat] {
                for dBri in [0, -0.12, 0.1] as [CGFloat] {
                    var hue = (h + shift).truncatingRemainder(dividingBy: 1)
                    if hue < 0 { hue += 1 }
                    let c = UIColor(hue: hue, saturation: sat, brightness: min(0.9, max(0.4, bri + dBri)), alpha: 1)
                    let sc = score(c)
                    if sc > bestScore { best = c; bestScore = sc }
                    if sc >= 0.13 { break search }
                }
            }
            out[id] = best
        }
        return out
    }()

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
