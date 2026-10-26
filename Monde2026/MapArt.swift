import CoreGraphics
import Foundation

// =============================================================
//  MapArt.swift
//  L'habillage de la carte : mer en dégradé, motifs de relief
//  selon le terrain (sommets, collines, forêts, dunes…), grain
//  « papier » discret. Tout est dessiné une fois en petites
//  images répétées : la carte reste rapide à dessiner.
// =============================================================

enum MapArt {
    /// Taille d'un motif de terrain, en points d'écran.
    static let patternSize: Double = 46
    /// Taille du motif de grain, en points d'écran.
    static let grainSize: Double = 96

    static let oceanGradient: CGGradient = {
        let space = CGColorSpaceCreateDeviceRGB()
        let colors: [CGFloat] = [
            0.035, 0.07, 0.12, 1,
            0.06, 0.13, 0.21, 1,
            0.075, 0.16, 0.25, 1,
            0.06, 0.13, 0.21, 1,
            0.035, 0.07, 0.12, 1
        ]
        let locations: [CGFloat] = [0, 0.32, 0.5, 0.68, 1]
        return CGGradient(colorSpace: space, colorComponents: colors, locations: locations, count: 5)!
    }()

    static func pattern(_ t: Terrain) -> CGImage? { patterns[t.rawValue] }

    private static let patterns: [CGImage?] = Terrain.allCases.map { makePattern($0) }

    /// Petit générateur pseudo-aléatoire stable (mêmes motifs à chaque lancement).
    private struct Rand {
        var s: UInt64
        mutating func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double((s >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
        }
    }

    /// Dessine en coordonnées « écran » (y vers le bas) : la carte retourne l'image en la posant.
    private static func makePattern(_ t: Terrain) -> CGImage? {
        guard t != .plains else { return nil }
        let scale: CGFloat = 2
        let size = Int(patternSize * Double(scale))
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let S = CGFloat(patternSize)
        var r = Rand(s: UInt64(t.rawValue + 7) &* 2654435761)
        let dark = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let light = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        // Positions en quinconce, légèrement décalées, qui se raccordent aux bords.
        func spots(_ n: Int) -> [CGPoint] {
            var out: [CGPoint] = []
            let side = Int(Double(n).squareRoot().rounded(.up))
            let step = S / CGFloat(side)
            for i in 0..<side {
                for j in 0..<side where out.count < n {
                    let jitter = CGFloat(r.next() - 0.5) * step * 0.5
                    let x = (CGFloat(j) + 0.5 + (i % 2 == 0 ? 0 : 0.5)) * step + jitter
                    let y = (CGFloat(i) + 0.5) * step + CGFloat(r.next() - 0.5) * step * 0.4
                    out.append(CGPoint(x: x.truncatingRemainder(dividingBy: S), y: y))
                }
            }
            return out
        }
        switch t {
        case .mountains:
            for p in spots(4) {
                let w: CGFloat = 9 + CGFloat(r.next()) * 4, h: CGFloat = 7 + CGFloat(r.next()) * 3
                // Versant éclairé puis versant à l'ombre, et l'arête.
                ctx.setFillColor(light.copy(alpha: 0.13)!)
                ctx.move(to: CGPoint(x: p.x - w, y: p.y + h / 2)); ctx.addLine(to: CGPoint(x: p.x, y: p.y - h))
                ctx.addLine(to: CGPoint(x: p.x, y: p.y + h / 2)); ctx.closePath(); ctx.fillPath()
                ctx.setFillColor(dark.copy(alpha: 0.20)!)
                ctx.move(to: CGPoint(x: p.x, y: p.y - h)); ctx.addLine(to: CGPoint(x: p.x + w, y: p.y + h / 2))
                ctx.addLine(to: CGPoint(x: p.x, y: p.y + h / 2)); ctx.closePath(); ctx.fillPath()
                ctx.setStrokeColor(dark.copy(alpha: 0.32)!)
                ctx.setLineWidth(1.1)
                ctx.move(to: CGPoint(x: p.x - w, y: p.y + h / 2)); ctx.addLine(to: CGPoint(x: p.x, y: p.y - h))
                ctx.addLine(to: CGPoint(x: p.x + w, y: p.y + h / 2)); ctx.strokePath()
            }
        case .hills:
            ctx.setLineWidth(1.2)
            for p in spots(5) {
                let w: CGFloat = 7 + CGFloat(r.next()) * 3
                ctx.setStrokeColor(dark.copy(alpha: 0.22)!)
                ctx.move(to: CGPoint(x: p.x - w, y: p.y + 2))
                ctx.addQuadCurve(to: CGPoint(x: p.x + w, y: p.y + 2), control: CGPoint(x: p.x, y: p.y - 7))
                ctx.strokePath()
                ctx.setStrokeColor(light.copy(alpha: 0.10)!)
                ctx.move(to: CGPoint(x: p.x - w + 1, y: p.y + 1))
                ctx.addQuadCurve(to: CGPoint(x: p.x - 1, y: p.y - 3), control: CGPoint(x: p.x - w / 2, y: p.y - 4))
                ctx.strokePath()
            }
        case .forest, .jungle:
            let n = t == .jungle ? 14 : 9
            for p in spots(n) {
                let rad: CGFloat = t == .jungle ? 2.6 : 3.1
                ctx.setFillColor(dark.copy(alpha: t == .jungle ? 0.22 : 0.18)!)
                ctx.fillEllipse(in: CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2))
                ctx.setFillColor(light.copy(alpha: 0.08)!)
                ctx.fillEllipse(in: CGRect(x: p.x - rad * 0.8, y: p.y - rad * 0.9, width: rad, height: rad))
            }
            if t == .jungle {
                ctx.setStrokeColor(dark.copy(alpha: 0.14)!)
                ctx.setLineWidth(1)
                for p in spots(5) {
                    ctx.move(to: CGPoint(x: p.x - 4, y: p.y + 5)); ctx.addLine(to: CGPoint(x: p.x + 4, y: p.y + 5))
                }
                ctx.strokePath()
            }
        case .desert:
            ctx.setLineWidth(1)
            for p in spots(4) {
                ctx.setStrokeColor(dark.copy(alpha: 0.13)!)
                ctx.move(to: CGPoint(x: p.x - 8, y: p.y))
                ctx.addQuadCurve(to: CGPoint(x: p.x + 8, y: p.y), control: CGPoint(x: p.x, y: p.y - 5))
                ctx.strokePath()
            }
            ctx.setFillColor(dark.copy(alpha: 0.10)!)
            for p in spots(16) { ctx.fill(CGRect(x: p.x, y: p.y, width: 1, height: 1)) }
        case .tundra:
            ctx.setStrokeColor(light.copy(alpha: 0.16)!)
            ctx.setLineWidth(1)
            for p in spots(6) {
                ctx.move(to: CGPoint(x: p.x - 3, y: p.y)); ctx.addLine(to: CGPoint(x: p.x + 3, y: p.y))
                ctx.move(to: CGPoint(x: p.x, y: p.y - 3)); ctx.addLine(to: CGPoint(x: p.x, y: p.y + 3))
            }
            ctx.strokePath()
        case .urban:
            ctx.setFillColor(dark.copy(alpha: 0.16)!)
            for p in spots(9) {
                ctx.fill(CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4))
            }
        case .plains:
            break
        }
        return ctx.makeImage()
    }

    /// Grain « papier » : un bruit très léger, clair et sombre.
    static let grain: CGImage = {
        let n = 128
        var r = Rand(s: 2026)
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        for i in 0..<(n * n) {
            let v = r.next()
            let a = UInt8(min(255, abs(v - 0.5) * 2 * 14))
            let white = v > 0.5
            // Pré-multiplié : la couleur ne dépasse pas l'alpha.
            let c: UInt8 = white ? a : 0
            pixels[i * 4] = c
            pixels[i * 4 + 1] = c
            pixels[i * 4 + 2] = c
            pixels[i * 4 + 3] = a
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }()
}
