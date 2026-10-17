import UIKit
import MapKit
import SwiftUI

// =============================================================
//  UnitLayer.swift
//  La couche des unités, posée sur la carte (UIKit pur) :
//   - chaque armée est un pion (drapeau, pictogramme, effectif,
//     mélange des troupes), qui glisse en douceur d'une position
//     à l'autre au lieu de sauter,
//   - on peut toucher un pion, ou le faire glisser du doigt
//     jusqu'à une région — ou contre une frontière pour la tenir,
//   - trajets, flèches d'attaque et badges de bataille sont
//     dessinés ici aussi : la carte des régions ne bouge plus.
// =============================================================

final class UnitLayerView: UIView {
    weak var map: MKMapView?
    var onDrop: ((Int, Int, Int?) -> Void)?           // armée, région, frontière tenue
    var onDragStart: ((Int) -> Void)?
    private(set) var snapshot = UnitsSnapshot.empty
    private var tokens: [Int: UnitTokenView] = [:]
    private var badges: [Int: BattleBadgeView] = [:]
    private var bombs: [Int: UILabel] = [:]
    private let routeLayer = CAShapeLayer()
    private let hostileLayer = CAShapeLayer()
    private let arrowLayer = CALayer()
    private let dragLine = CAShapeLayer()
    private var ghost: UnitTokenView?
    private let ghostLabel = PaddedLabel()
    private var dragging: (army: Int, province: Int?, facing: Int?)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        routeLayer.fillColor = nil
        routeLayer.strokeColor = UIColor(Theme.amber).cgColor
        routeLayer.lineWidth = 2.5
        routeLayer.lineDashPattern = [7, 5]
        routeLayer.lineCap = .round
        hostileLayer.fillColor = UIColor(Theme.coral).cgColor
        hostileLayer.strokeColor = UIColor(Theme.coral).cgColor
        hostileLayer.lineWidth = 3.5
        hostileLayer.lineCap = .round
        dragLine.fillColor = nil
        dragLine.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        dragLine.lineWidth = 2.5
        dragLine.lineDashPattern = [5, 5]
        layer.addSublayer(arrowLayer)
        layer.addSublayer(routeLayer)
        layer.addSublayer(hostileLayer)
        layer.addSublayer(dragLine)
        ghostLabel.font = .systemFont(ofSize: 13, weight: .bold)
        ghostLabel.textColor = .white
        ghostLabel.backgroundColor = UIColor(red: 0.04, green: 0.08, blue: 0.13, alpha: 0.92)
        ghostLabel.layer.cornerRadius = 10
        ghostLabel.layer.masksToBounds = true
        ghostLabel.isHidden = true
        addSubview(ghostLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Seuls les pions et badges captent le doigt ; ailleurs, la carte.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Seuls nos pions se saisissent (pour les faire glisser) ; le reste laisse passer vers la carte.
        for v in subviews.reversed() {
            guard let t = v as? UnitTokenView, !t.isHidden, t.token.isPlayer else { continue }
            if t.frame.insetBy(dx: -8, dy: -8).contains(point) { return t }
        }
        return nil
    }

    // MARK: Mise à jour

    func apply(_ new: UnitsSnapshot, animated duration: TimeInterval) {
        let old = snapshot
        snapshot = new
        guard let map = map else { return }
        let ids = Set(new.tokens.map { $0.id })
        for (id, v) in tokens where !ids.contains(id) {
            UIView.animate(withDuration: 0.25, animations: { v.alpha = 0; v.transform = v.transform.scaledBy(x: 0.6, y: 0.6) },
                           completion: { _ in v.removeFromSuperview() })
            tokens[id] = nil
        }
        for t in new.tokens {
            if let v = tokens[t.id] {
                if v.token != t { v.token = t }
            } else {
                let v = UnitTokenView(token: t)
                v.alpha = 0
                let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
                v.addGestureRecognizer(pan)
                insertSubview(v, belowSubview: ghostLabel)
                tokens[t.id] = v
                UIView.animate(withDuration: 0.3) { v.alpha = 1 }
            }
        }
        let bids = Set(new.battles.map { $0.id })
        for (id, v) in badges where !bids.contains(id) { v.removeFromSuperview(); badges[id] = nil }
        for b in new.battles {
            if let v = badges[b.id] { v.badge = b } else {
                let v = BattleBadgeView(badge: b)
                insertSubview(v, belowSubview: ghostLabel)
                badges[b.id] = v
            }
        }
        let bomb = Set(new.bombed)
        for (id, v) in bombs where !bomb.contains(id) { v.removeFromSuperview(); bombs[id] = nil }
        for id in bomb where bombs[id] == nil {
            let l = UILabel()
            l.text = "💥"
            l.font = .systemFont(ofSize: 20)
            l.sizeToFit()
            l.isUserInteractionEnabled = false
            insertSubview(l, at: 0)
            bombs[id] = l
        }
        let moved = old.tokens.count != new.tokens.count || old != new
        if moved && duration > 0.02 {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear, .beginFromCurrentState, .allowUserInteraction]) {
                self.layoutUnits(in: map)
            }
            drawLines(in: map)
        } else {
            relayout()
        }
    }

    /// Repositionne tout (la carte a bougé ou zoomé).
    func relayout() {
        guard let map = map else { return }
        UIView.performWithoutAnimation { layoutUnits(in: map) }
        drawLines(in: map)
    }

    private func screen(_ p: MKMapPoint, _ map: MKMapView) -> CGPoint {
        map.convert(p.coordinate, toPointTo: self)
    }

    private func layoutUnits(in map: MKMapView) {
        let perPoint = map.visibleMapRect.size.width / Double(max(1, map.bounds.width))
        let k = MarkerScale.factor(perPoint)
        let showAll = perPoint < 16_384
        // Plusieurs armées au même endroit : côte à côte.
        var stacks: [String: Int] = [:]
        var counts: [String: Int] = [:]
        for t in snapshot.tokens {
            let key = "\(Int(t.point.x / 4000))-\(Int(t.point.y / 4000))"
            counts[key, default: 0] += 1
        }
        let visibleRect = bounds.insetBy(dx: -80, dy: -80)
        for t in snapshot.tokens {
            guard let v = tokens[t.id] else { continue }
            let show = t.isPlayer || t.selected || showAll || t.engaged
            let key = "\(Int(t.point.x / 4000))-\(Int(t.point.y / 4000))"
            let n = counts[key] ?? 1
            let i = stacks[key, default: 0]
            stacks[key] = i + 1
            var c = screen(t.point, map)
            let step = UnitTokenView.size.width * k + 3
            c.x += (CGFloat(i) - CGFloat(n - 1) / 2) * step
            v.isHidden = !show || !visibleRect.contains(c)
            v.center = c
            v.transform = CGAffineTransform(scaleX: k, y: k)
        }
        for b in snapshot.battles {
            guard let v = badges[b.id] else { continue }
            var c = screen(b.point, map)
            c.y -= 30 * k
            v.center = c
            v.transform = CGAffineTransform(scaleX: max(0.6, k), y: max(0.6, k))
            v.isHidden = !(b.side != 0 || showAll) || !visibleRect.contains(c)
        }
        for (id, l) in bombs {
            var c = screen(ProvinceMap.all[id].labelPoint, map)
            c.x += 28 * k
            c.y -= 26 * k
            l.center = c
        }
    }

    private func drawLines(in map: MKMapView) {
        let perPoint = map.visibleMapRect.size.width / Double(max(1, map.bounds.width))
        let showAll = perPoint < 16_384
        let k = MarkerScale.factor(perPoint)
        let dashed = UIBezierPath()
        let hostile = UIBezierPath()
        for r in snapshot.routes where r.points.count >= 2 {
            let pts = r.points.map { screen($0, map) }
            let split = min(pts.count - 1, r.hostileFrom ?? pts.count - 1)
            if split > 0 {
                dashed.move(to: pts[0])
                for p in pts[1...split] { dashed.addLine(to: p) }
            }
            if r.hostileFrom != nil {
                hostile.move(to: pts[split])
                for p in pts[(split + 1)...] { hostile.addLine(to: p) }
            } else if let last = pts.last {
                dashed.move(to: CGPoint(x: last.x + 4, y: last.y))
                dashed.addArc(withCenter: last, radius: 4, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            }
        }
        routeLayer.path = dashed.cgPath
        // Les pointes de flèche des offensives
        let heads = UIBezierPath()
        for r in snapshot.routes where r.hostileFrom != nil && r.points.count >= 2 {
            let a = screen(r.points[r.points.count - 2], map), b = screen(r.points[r.points.count - 1], map)
            addHead(heads, from: a, to: b, size: 14)
        }
        hostile.append(heads)
        hostileLayer.path = hostile.cgPath
        // Flèches d'attaque des batailles, à la couleur de l'attaquant
        arrowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        for b in snapshot.battles where b.side != 0 || showAll {
            let target = screen(b.point, map)
            for f in b.fronts {
                let from = screen(f, map)
                let shape = CAShapeLayer()
                let path = UIBezierPath()
                let dx = target.x - from.x, dy = target.y - from.y
                let len = hypot(dx, dy)
                guard len > 6 else { continue }
                let tip = CGPoint(x: from.x + dx * 0.78, y: from.y + dy * 0.78)
                let start = CGPoint(x: from.x - dx * 0.2, y: from.y - dy * 0.2)
                path.move(to: start); path.addLine(to: tip)
                shape.path = path.cgPath
                shape.strokeColor = b.attackerColor.uiColor.cgColor
                shape.lineWidth = max(3, 7 * k)
                shape.lineCap = .round
                shape.shadowColor = UIColor.black.cgColor
                shape.shadowOpacity = 0.6
                shape.shadowRadius = 2
                shape.shadowOffset = .zero
                let head = CAShapeLayer()
                let hp = UIBezierPath()
                addHead(hp, from: start, to: CGPoint(x: from.x + dx * 0.9, y: from.y + dy * 0.9), size: max(10, 18 * k))
                head.path = hp.cgPath
                head.fillColor = b.attackerColor.uiColor.cgColor
                arrowLayer.addSublayer(shape)
                arrowLayer.addSublayer(head)
            }
        }
    }

    private func addHead(_ path: UIBezierPath, from a: CGPoint, to b: CGPoint, size: CGFloat) {
        let ang = atan2(b.y - a.y, b.x - a.x)
        path.move(to: b)
        path.addLine(to: CGPoint(x: b.x - size * cos(ang - 0.45), y: b.y - size * sin(ang - 0.45)))
        path.addLine(to: CGPoint(x: b.x - size * cos(ang + 0.45), y: b.y - size * sin(ang + 0.45)))
        path.close()
    }

    /// Le pion ou le badge sous le doigt.
    func hit(_ point: CGPoint) -> MapTap? {
        for (id, v) in badges where !v.isHidden && v.frame.insetBy(dx: -6, dy: -6).contains(point) { return .battle(id) }
        var best: (Int, CGFloat)?
        for (id, v) in tokens where !v.isHidden {
            let f = v.frame.insetBy(dx: -8, dy: -8)
            guard f.contains(point) else { continue }
            let d = hypot(point.x - v.center.x, point.y - v.center.y) - (v.token.isPlayer ? 10 : 0)
            if d < (best?.1 ?? .infinity) { best = (id, d) }
        }
        return best.map { .army($0.0) }
    }

    // MARK: Glisser-déposer

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        guard let v = g.view as? UnitTokenView, v.token.isPlayer, let map = map else { return }
        let loc = g.location(in: self)
        switch g.state {
        case .began:
            map.isScrollEnabled = false
            map.isZoomEnabled = false
            onDragStart?(v.token.id)
            let gh = UnitTokenView(token: v.token)
            gh.alpha = 0.92
            gh.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            gh.isUserInteractionEnabled = false
            addSubview(gh)
            ghost = gh
            dragging = (v.token.id, nil, nil)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            fallthrough
        case .changed:
            ghost?.center = CGPoint(x: loc.x, y: loc.y - 34)
            let line = UIBezierPath()
            line.move(to: v.center)
            line.addLine(to: loc)
            dragLine.path = line.cgPath
            let coordinate = map.convert(loc, toCoordinateFrom: self)
            let province = ProvinceMap.province(at: GeoPoint(lat: coordinate.latitude, lon: coordinate.longitude))?.id
            let facing = province.flatMap { nearBorder(of: $0, at: loc, map: map) }
            if province != dragging?.province || facing != dragging?.facing {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            dragging = (v.token.id, province, facing)
            if let p = province {
                var text = "→ " + ProvinceMap.all[p].name
                if let f = facing { text += "  ⟂ face à " + ProvinceMap.all[f].name }
                ghostLabel.text = text
                ghostLabel.sizeToFit()
                ghostLabel.frame.size.width += 18
                ghostLabel.frame.size.height += 10
                ghostLabel.center = CGPoint(x: loc.x, y: loc.y - 72)
                ghostLabel.isHidden = false
            } else {
                ghostLabel.isHidden = true
            }
        default:
            map.isScrollEnabled = true
            map.isZoomEnabled = true
            dragLine.path = nil
            ghost?.removeFromSuperview()
            ghost = nil
            ghostLabel.isHidden = true
            if g.state == .ended, let d = dragging, let p = d.province {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                onDrop?(d.army, p, d.facing)
            }
            dragging = nil
        }
    }

    /// Le doigt est-il tout près d'une frontière de cette région ? Laquelle (voisine) ?
    private func nearBorder(of province: Int, at point: CGPoint, map: MKMapView) -> Int? {
        var best: (Int, CGFloat)?
        for b in ProvinceMap.borders where b.a == province || b.b == province {
            let other = b.a == province ? b.b : b.a
            for line in b.lines {
                let stride = max(1, line.count / 40)
                var i = 0
                while i < line.count {
                    let s = screen(line[i], map)
                    let d = hypot(s.x - point.x, s.y - point.y)
                    if d < (best?.1 ?? 28) { best = (other, d) }
                    i += stride
                }
            }
        }
        return best?.0
    }
}

// MARK: - Le pion

final class UnitTokenView: UIView {
    static let size = CGSize(width: 78, height: 32)

    var token: UnitToken { didSet { setNeedsDisplay(); updatePulse() } }

    init(token: UnitToken) {
        self.token = token
        super.init(frame: CGRect(origin: .zero, size: UnitTokenView.size))
        isOpaque = false
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        updatePulse()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updatePulse() {
        if token.engaged {
            if layer.animation(forKey: "pulse") == nil {
                let a = CABasicAnimation(keyPath: "shadowRadius")
                a.fromValue = 3; a.toValue = 10; a.duration = 0.7; a.autoreverses = true; a.repeatCount = .infinity
                layer.add(a, forKey: "pulse")
            }
            layer.shadowColor = UIColor(Theme.coral).cgColor
            layer.shadowOpacity = 0.9
        } else if token.selected {
            layer.removeAnimation(forKey: "pulse")
            layer.shadowColor = UIColor(Theme.amber).cgColor
            layer.shadowOpacity = 0.95
            layer.shadowRadius = 8
        } else {
            layer.removeAnimation(forKey: "pulse")
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.55
            layer.shadowRadius = 4
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let r = bounds.insetBy(dx: 1.5, dy: 1.5)
        let body = UIBezierPath(roundedRect: r, cornerRadius: r.height / 2)
        // Fond : sombre, teinté de la couleur du pays
        let country = token.color.uiColor
        ctx.addPath(body.cgPath)
        ctx.setFillColor(UIColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 0.96).cgColor)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(body.cgPath)
        ctx.clip()
        ctx.setFillColor(country.withAlphaComponent(0.28).cgColor)
        ctx.fill(r)
        // Mélange des troupes : bande en bas
        var x = r.minX
        for (k, share) in token.mix.enumerated() where share > 0 {
            let w = r.width * CGFloat(share)
            ctx.setFillColor(UnitArt.mixColors[k % UnitArt.mixColors.count].cgColor)
            ctx.fill(CGRect(x: x, y: r.maxY - 4, width: w, height: 4))
            x += w
        }
        ctx.restoreGState()
        // Contour : couleur du pays (doré si sélectionné, rouge au combat)
        let stroke: UIColor = token.selected ? UIColor(Theme.amber) : (token.engaged ? UIColor(Theme.coral) : country)
        ctx.addPath(body.cgPath)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(token.selected ? 3 : 2)
        if token.serving { ctx.setLineDash(phase: 0, lengths: [4, 3]) }
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        // Drapeau dans une pastille
        let flagBox = CGRect(x: r.minX + 3, y: r.midY - 12, width: 24, height: 24)
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        ctx.fillEllipse(in: flagBox)
        let flag = token.flag as NSString
        let fAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15)]
        let fs = flag.size(withAttributes: fAttrs)
        flag.draw(at: CGPoint(x: flagBox.midX - fs.width / 2, y: flagBox.midY - fs.height / 2 - 1), withAttributes: fAttrs)
        // Pictogramme du type dominant
        UnitArt.draw(token.mainType, in: CGRect(x: r.minX + 30, y: r.minY + 6, width: 24, height: 15), context: ctx)
        // Effectif
        let count = "\(token.count)" as NSString
        let cAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .heavy),
                                                     .foregroundColor: UIColor.white]
        let cs = count.size(withAttributes: cAttrs)
        count.draw(at: CGPoint(x: r.maxX - 8 - cs.width, y: r.midY - cs.height / 2 - 2), withAttributes: cAttrs)
        // Petits signes : entraînement ★, en marche ›, sur une frontière ▮
        var badge: String?
        if token.training { badge = "★" } else if token.moving { badge = "›" } else if token.onBorder { badge = "▮" }
        if let b = badge as NSString? {
            let bAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .black),
                                                         .foregroundColor: UIColor(Theme.amber)]
            b.draw(at: CGPoint(x: r.minX + 55, y: r.minY + 2), withAttributes: bAttrs)
        }
    }
}

// MARK: - Badge de bataille

final class BattleBadgeView: UIView {
    var badge: BattleBadge { didSet { setNeedsDisplay() } }

    init(badge: BattleBadge) {
        self.badge = badge
        super.init(frame: CGRect(x: 0, y: 0, width: 60, height: 24))
        isOpaque = false
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 4
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1; pulse.toValue = 1.08; pulse.duration = 0.6; pulse.autoreverses = true; pulse.repeatCount = .infinity
        layer.add(pulse, forKey: "pulse")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = UIBezierPath(roundedRect: r, cornerRadius: r.height / 2)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(UIColor(red: 0.12, green: 0.05, blue: 0.05, alpha: 0.95).cgColor)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        ctx.setFillColor(badge.attackerColor.uiColor.withAlphaComponent(0.6).cgColor)
        ctx.fill(CGRect(x: r.minX, y: r.minY, width: r.width * CGFloat(badge.progress), height: r.height))
        ctx.restoreGState()
        let tint: UIColor = badge.side == 0 ? UIColor(white: 0.75, alpha: 1) : (badge.winning ? UIColor(Theme.teal) : UIColor(Theme.coral))
        ctx.addPath(path.cgPath)
        ctx.setStrokeColor(tint.cgColor)
        ctx.setLineWidth(2)
        ctx.strokePath()
        let text = "⚔︎ \(Int(badge.progress * 100))%" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .heavy),
                                                    .foregroundColor: UIColor.white]
        let s = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: r.midX - s.width / 2, y: r.midY - s.height / 2), withAttributes: attrs)
    }
}

final class PaddedLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 9, dy: 5))
    }
}
