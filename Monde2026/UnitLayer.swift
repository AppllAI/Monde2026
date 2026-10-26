import UIKit
import MapKit
import SwiftUI

// =============================================================
//  UnitLayer.swift
//  La couche des unités, posée sur la carte (UIKit pur) :
//   - chaque armée est un pion (drapeau, pictogramme, effectif,
//     mélange des troupes), qui glisse en douceur d'une position
//     à l'autre au lieu de sauter,
//   - on fait glisser un pion du doigt jusqu'à une région — ou
//     contre une frontière pour la tenir (le pion s'y aimante) ;
//     pendant le glisser, le trajet et sa durée s'affichent,
//   - appui long sur la carte puis glisser : lasso qui entoure
//     plusieurs pions pour les commander ensemble,
//   - trajets, flèches d'attaque, badges de bataille, région
//     sélectionnée et régions constructibles sont dessinés ici :
//     la carte des régions (lourde) ne se redessine pas.
//
//  Fluidité : les positions sont calculées par une simple
//  projection affine (pas de conversion MapKit par pion), les
//  pions ne sont redessinés que si leur apparence change, et
//  ceux hors de l'écran sont cachés.
// =============================================================

/// Projection des points MapKit vers l'écran (carte sans rotation : c'est une simple mise à l'échelle).
struct ScreenProjection {
    let originX: Double
    let originY: Double
    let scale: Double          // points d'écran par point MapKit
    let minX: Double
    let maxX: Double

    init(map: MKMapView, in view: UIView) {
        let r = map.visibleMapRect
        scale = Double(view.bounds.width) / max(1, r.size.width)
        originX = r.minX
        originY = r.minY
        minX = r.minX
        maxX = r.maxX
    }

    func callAsFunction(_ p: MKMapPoint) -> CGPoint {
        // La carte peut montrer l'antiméridien : on prend la copie du point la plus proche de l'écran.
        var x = p.x
        let world = MKMapSize.world.width
        let mid = (minX + maxX) / 2
        if x - mid > world / 2 { x -= world } else if mid - x > world / 2 { x += world }
        return CGPoint(x: (x - originX) * scale, y: (p.y - originY) * scale)
    }

    /// Transformation affine équivalente (pour les contours de régions).
    var transform: CGAffineTransform {
        CGAffineTransform(a: CGFloat(scale), b: 0, c: 0, d: CGFloat(scale),
                          tx: CGFloat(-originX * scale), ty: CGFloat(-originY * scale))
    }

    /// Points MapKit par point d'écran.
    var perPoint: Double { 1 / max(scale, 1e-12) }
}

final class UnitLayerView: UIView, UIGestureRecognizerDelegate {
    weak var map: MKMapView? {
        didSet { installLasso() }
    }
    var onDrop: ((Int, Int, Int?) -> Void)?           // armée, région, frontière tenue
    var onPreview: ((Int, Int) -> (path: [Int], days: Int, attack: Bool)?)?
    var onStroke: (([Int], [GeoPoint]) -> Void)?       // pions entourés, trait (lasso ou flèche d'offensive)
    private(set) var snapshot = UnitsSnapshot.empty
    private var tokens: [Int: UnitTokenView] = [:]
    private var badges: [Int: BattleBadgeView] = [:]
    private var bombs: [Int: UILabel] = [:]
    private let selectionLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let routeLayer = CAShapeLayer()
    private let hostileLayer = CAShapeLayer()
    private let arrowLayer = CALayer()
    private var arrowPool: [(CAShapeLayer, CAShapeLayer)] = []
    private let dragLine = CAShapeLayer()
    private let dragRoute = CAShapeLayer()
    private let lassoLayer = CAShapeLayer()
    private var lassoPoints: [CGPoint] = []
    private var ghost: UnitTokenView?
    private let ghostLabel = PaddedLabel()
    private var dragging: (army: Int, province: Int?, facing: Int?)?
    private var lastPreviewKey = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        highlightLayer.fillColor = UIColor(Theme.amber).withAlphaComponent(0.22).cgColor
        highlightLayer.strokeColor = UIColor(Theme.amber).cgColor
        highlightLayer.lineWidth = 1.6
        highlightLayer.lineJoin = .round
        selectionLayer.fillColor = UIColor.white.withAlphaComponent(0.16).cgColor
        selectionLayer.strokeColor = UIColor(Theme.amber).cgColor
        selectionLayer.lineWidth = 2.5
        selectionLayer.lineJoin = .round
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
        dragLine.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        dragLine.lineWidth = 1.5
        dragLine.lineDashPattern = [3, 4]
        dragRoute.fillColor = nil
        dragRoute.lineWidth = 4
        dragRoute.lineCap = .round
        dragRoute.lineJoin = .round
        dragRoute.shadowColor = UIColor.black.cgColor
        dragRoute.shadowOpacity = 0.7
        dragRoute.shadowRadius = 2
        dragRoute.shadowOffset = .zero
        lassoLayer.fillColor = UIColor(Theme.amber).withAlphaComponent(0.12).cgColor
        lassoLayer.strokeColor = UIColor(Theme.amber).cgColor
        lassoLayer.lineWidth = 2
        lassoLayer.lineDashPattern = [6, 4]
        for l in [highlightLayer, selectionLayer, arrowLayer, routeLayer, hostileLayer, dragRoute, dragLine, lassoLayer] as [CALayer] {
            l.actions = ["path": NSNull(), "position": NSNull(), "bounds": NSNull()]
            layer.addSublayer(l)
        }
        ghostLabel.font = .systemFont(ofSize: 14, weight: .bold)
        ghostLabel.textColor = .white
        ghostLabel.backgroundColor = UIColor(red: 0.04, green: 0.08, blue: 0.13, alpha: 0.94)
        ghostLabel.layer.cornerRadius = 11
        ghostLabel.layer.masksToBounds = true
        ghostLabel.numberOfLines = 2
        ghostLabel.isHidden = true
        addSubview(ghostLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Seuls nos pions captent le doigt (pour les faire glisser) ; ailleurs, la carte.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var best: (UnitTokenView, CGFloat)?
        for v in tokens.values where !v.isHidden && v.token.isPlayer {
            guard v.frame.insetBy(dx: -10, dy: -10).contains(point) else { continue }
            let d = hypot(point.x - v.center.x, point.y - v.center.y)
            if d < (best?.1 ?? .infinity) { best = (v, d) }
        }
        return best?.0
    }

    // MARK: Mise à jour

    func apply(_ new: UnitsSnapshot, animated duration: TimeInterval) {
        let old = snapshot
        snapshot = new
        guard let map = map else { return }
        let ids = Set(new.tokens.map { $0.id })
        for (id, v) in tokens where !ids.contains(id) {
            UIView.animate(withDuration: 0.25, animations: { v.alpha = 0 }, completion: { _ in v.removeFromSuperview() })
            tokens[id] = nil
        }
        for t in new.tokens {
            if let v = tokens[t.id] {
                if !v.token.looksSame(as: t) { v.token = t } else { v.position = t.point }
            } else {
                let v = UnitTokenView(token: t)
                v.alpha = 0
                let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
                pan.delegate = self
                pan.maximumNumberOfTouches = 1
                v.addGestureRecognizer(pan)
                insertSubview(v, belowSubview: ghostLabel)
                tokens[t.id] = v
                UIView.animate(withDuration: 0.3) { v.alpha = 1 }
            }
        }
        let bids = Set(new.battles.map { $0.id })
        for (id, v) in badges where !bids.contains(id) { v.removeFromSuperview(); badges[id] = nil }
        for b in new.battles {
            if let v = badges[b.id] {
                if v.badge != b { v.badge = b }
            } else {
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
            insertSubview(l, belowSubview: ghostLabel)
            bombs[id] = l
        }
        let projection = ScreenProjection(map: map, in: self)
        let tokensMoved = old.tokens != new.tokens
        if tokensMoved && duration > 0.02 {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear, .beginFromCurrentState, .allowUserInteraction]) {
                self.layoutUnits(projection)
            }
        } else {
            UIView.performWithoutAnimation { layoutUnits(projection) }
        }
        drawLines(projection)
        if old.selectedProvince != new.selectedProvince || old.highlight != new.highlight {
            drawAreas(projection)
        }
    }

    /// Repositionne tout (la carte a bougé ou zoomé) : appelé à chaque image pendant un geste, donc léger.
    func relayout() {
        guard let map = map else { return }
        let projection = ScreenProjection(map: map, in: self)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation { layoutUnits(projection) }
        drawLines(projection)
        drawAreas(projection)
        CATransaction.commit()
    }

    private func layoutUnits(_ project: ScreenProjection) {
        let perPoint = project.perPoint
        let k = MarkerScale.factor(perPoint)
        let showAll = perPoint < 16_384
        let size = CGSize(width: UnitTokenView.size.width * k, height: UnitTokenView.size.height * k)
        let visibleRect = bounds.insetBy(dx: -size.width, dy: -size.height)
        // Plusieurs armées au même endroit : côte à côte, puis décalées pour ne pas se recouvrir.
        var counts: [Int: Int] = [:]
        func key(_ p: MKMapPoint) -> Int { Int(p.x / 4000) &* 92_821 &+ Int(p.y / 4000) }
        for t in snapshot.tokens { counts[key(t.point), default: 0] += 1 }
        var stacks: [Int: Int] = [:]
        // Grille de l'écran pour tester les chevauchements sans tout comparer à tout.
        var grid: [Int: [CGRect]] = [:]
        let cell = max(20, size.height * 2)
        func cells(_ r: CGRect) -> [Int] {
            var out: [Int] = []
            for gx in Int(floor(r.minX / cell))...Int(floor(r.maxX / cell)) {
                for gy in Int(floor(r.minY / cell))...Int(floor(r.maxY / cell)) { out.append(gx &* 7919 &+ gy) }
            }
            return out
        }
        for t in snapshot.tokens.sorted(by: { ($0.isPlayer ? 0 : 1, $0.id) < ($1.isPlayer ? 0 : 1, $1.id) }) {
            guard let v = tokens[t.id] else { continue }
            let show = t.isPlayer || t.selected || showAll || t.engaged
            let kk = key(t.point)
            let n = counts[kk] ?? 1
            let i = stacks[kk, default: 0]
            stacks[kk] = i + 1
            var c = project(t.point)
            c.x += (CGFloat(i) - CGFloat(n - 1) / 2) * (size.width + 3)
            let hidden = !show || !visibleRect.contains(c)
            if v.isHidden != hidden { v.isHidden = hidden }
            guard !hidden else { continue }
            func frame(_ y: CGFloat) -> CGRect {
                CGRect(x: c.x - size.width / 2, y: y - size.height / 2, width: size.width, height: size.height)
            }
            var tries = 0
            var offset: CGFloat = 0
            while tries < 6 {
                let f = frame(c.y + offset).insetBy(dx: 2, dy: 2)
                let clash = cells(f).contains { cellKey in (grid[cellKey] ?? []).contains { other in other.intersects(f) } }
                guard clash else { break }
                tries += 1
                offset = (tries % 2 == 1 ? 1 : -1) * CGFloat((tries + 1) / 2) * (size.height + 2)
            }
            c.y += offset
            let f = frame(c.y)
            for g in cells(f) { grid[g, default: []].append(f) }
            if v.center != c { v.center = c }
            if v.scale != k {
                v.scale = k
                v.transform = CGAffineTransform(scaleX: k, y: k)
            }
        }
        for b in snapshot.battles {
            guard let v = badges[b.id] else { continue }
            var c = project(b.point)
            c.y -= 30 * k
            v.center = c
            let s = max(0.6, k)
            v.transform = CGAffineTransform(scaleX: s, y: s)
            v.isHidden = !(b.side != 0 || showAll) || !visibleRect.contains(c)
        }
        for (id, l) in bombs {
            var c = project(ProvinceMap.all[id].labelPoint)
            c.x += 28 * k
            c.y -= 26 * k
            l.center = c
        }
    }

    /// Région sélectionnée et régions constructibles (contours transformés à l'échelle de l'écran).
    private func drawAreas(_ project: ScreenProjection) {
        var t = project.transform
        let screen = bounds.insetBy(dx: -40, dy: -40)
        func path(_ ids: [Int]) -> CGPath? {
            let out = CGMutablePath()
            var any = false
            for id in ids where ProvinceMap.all.indices.contains(id) {
                let p = ProvinceMap.all[id]
                let b = p.bounds
                let r = CGRect(origin: project(b.origin), size: CGSize(width: b.size.width * project.scale, height: b.size.height * project.scale))
                guard r.intersects(screen) else { continue }
                if let c = p.path.copy(using: &t) { out.addPath(c); any = true }
            }
            return any ? out : nil
        }
        selectionLayer.path = snapshot.selectedProvince.flatMap { path([$0]) }
        highlightLayer.path = snapshot.highlight.isEmpty ? nil : path(snapshot.highlight)
    }

    private func drawLines(_ project: ScreenProjection) {
        let perPoint = project.perPoint
        let showAll = perPoint < 16_384
        let k = MarkerScale.factor(perPoint)
        let dashed = UIBezierPath()
        let hostile = UIBezierPath()
        for r in snapshot.routes where r.points.count >= 2 {
            let pts = r.points.map { project($0) }
            let split = min(pts.count - 1, r.hostileFrom ?? pts.count - 1)
            if split > 0 {
                dashed.move(to: pts[0])
                for p in pts[1...split] { dashed.addLine(to: p) }
            }
            if r.hostileFrom != nil {
                hostile.move(to: pts[split])
                for p in pts[(split + 1)...] { hostile.addLine(to: p) }
                addHead(hostile, from: pts[pts.count - 2], to: pts[pts.count - 1], size: 14)
            } else if let last = pts.last {
                dashed.move(to: CGPoint(x: last.x + 4, y: last.y))
                dashed.addArc(withCenter: last, radius: 4, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            }
        }
        routeLayer.path = dashed.cgPath
        hostileLayer.path = hostile.cgPath
        // Flèches d'attaque des batailles, à la couleur de l'attaquant (calques réutilisés).
        var used = 0
        for b in snapshot.battles where b.side != 0 || showAll {
            let target = project(b.point)
            for f in b.fronts {
                let from = project(f)
                let dx = target.x - from.x, dy = target.y - from.y
                guard hypot(dx, dy) > 6 else { continue }
                if used == arrowPool.count {
                    let shape = CAShapeLayer(), head = CAShapeLayer()
                    shape.lineCap = .round
                    shape.fillColor = nil
                    shape.shadowColor = UIColor.black.cgColor
                    shape.shadowOpacity = 0.6
                    shape.shadowRadius = 2
                    shape.shadowOffset = .zero
                    for l in [shape, head] { l.actions = ["path": NSNull(), "hidden": NSNull()] }
                    arrowLayer.addSublayer(shape)
                    arrowLayer.addSublayer(head)
                    arrowPool.append((shape, head))
                }
                let (shape, head) = arrowPool[used]
                used += 1
                let tip = CGPoint(x: from.x + dx * 0.78, y: from.y + dy * 0.78)
                let start = CGPoint(x: from.x - dx * 0.2, y: from.y - dy * 0.2)
                let line = UIBezierPath()
                line.move(to: start)
                line.addLine(to: tip)
                shape.path = line.cgPath
                shape.strokeColor = b.attackerColor.cgColor
                shape.lineWidth = max(3, 7 * k)
                shape.isHidden = false
                let hp = UIBezierPath()
                addHead(hp, from: start, to: CGPoint(x: from.x + dx * 0.9, y: from.y + dy * 0.9), size: max(10, 18 * k))
                head.path = hp.cgPath
                head.fillColor = b.attackerColor.cgColor
                head.isHidden = false
            }
        }
        for i in used..<arrowPool.count {
            arrowPool[i].0.isHidden = true
            arrowPool[i].1.isHidden = true
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

    // MARK: Gestes : le pion passe avant la carte

    /// Tant que le glisser d'un pion n'a pas échoué, la carte ne bouge pas.
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        g.view is UnitTokenView && !(other.view is UnitTokenView)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Le lasso (appui long) n'empêche pas les autres gestes de la carte de démarrer ; il les coupe ensuite.
        g === lassoGesture
    }

    // MARK: Glisser-déposer

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        guard let v = g.view as? UnitTokenView, v.token.isPlayer, let map = map else { return }
        let loc = g.location(in: self)
        let project = ScreenProjection(map: map, in: self)
        switch g.state {
        case .began:
            map.isScrollEnabled = false
            map.isZoomEnabled = false
            let gh = UnitTokenView(token: v.token)
            gh.alpha = 0.95
            gh.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            gh.isUserInteractionEnabled = false
            addSubview(gh)
            ghost = gh
            dragging = (v.token.id, nil, nil)
            lastPreviewKey = -1
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            fallthrough
        case .changed:
            let coordinate = map.convert(loc, toCoordinateFrom: self)
            let province = ProvinceMap.province(at: GeoPoint(lat: coordinate.latitude, lon: coordinate.longitude))?.id
            let facing = province.flatMap { nearBorder(of: $0, at: loc, project: project) }
            if province != dragging?.province || facing != dragging?.facing {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            dragging = (v.token.id, province, facing)
            // Aimant : contre une frontière, le pion se colle à la ligne.
            var spot = CGPoint(x: loc.x, y: loc.y - 34)
            if let p = province, let f = facing {
                let anchor = project(Anchors.shared.border(p, f))
                spot = CGPoint(x: anchor.x, y: anchor.y)
            }
            ghost?.center = spot
            let line = UIBezierPath()
            line.move(to: v.center)
            line.addLine(to: spot)
            dragLine.path = line.cgPath
            updatePreview(army: v.token.id, province: province, facing: facing, from: v.center, at: spot, project: project)
        default:
            map.isScrollEnabled = true
            map.isZoomEnabled = true
            dragLine.path = nil
            dragRoute.path = nil
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

    /// Trajet et durée affichés pendant le glisser (recalculés seulement quand la région visée change).
    private func updatePreview(army: Int, province: Int?, facing: Int?, from: CGPoint, at spot: CGPoint, project: ScreenProjection) {
        guard let p = province else {
            ghostLabel.isHidden = true
            dragRoute.path = nil
            return
        }
        let previewKey = p * 10_000 + (facing ?? 9_999)
        if previewKey != lastPreviewKey {
            lastPreviewKey = previewKey
            var text = ProvinceMap.all[p].name
            let preview = onPreview?(army, p)
            if let pr = preview {
                if pr.path.isEmpty {
                    text = facing != nil ? "Tenir la frontière" : "Rester ici"
                } else {
                    text = (pr.attack ? "⚔︎ Attaque · " : "→ ") + text + " · \(pr.days) j"
                }
                let route = UIBezierPath()
                route.move(to: from)
                for (i, id) in pr.path.enumerated() {
                    let last = i == pr.path.count - 1
                    let point = last && facing != nil ? Anchors.shared.border(id, facing!) : ProvinceMap.all[id].labelPoint
                    route.addLine(to: project(point))
                }
                dragRoute.path = route.cgPath
                dragRoute.strokeColor = (pr.attack ? UIColor(Theme.coral) : UIColor(Theme.amber)).cgColor
            } else {
                text = "⛔︎ " + text + " · inaccessible"
                dragRoute.path = nil
            }
            if let f = facing { text += "\n⟂ tenir la frontière face à " + ProvinceMap.all[f].name }
            ghostLabel.text = text
            ghostLabel.textColor = preview == nil ? UIColor(Theme.coral) : .white
            let size = ghostLabel.sizeThatFits(CGSize(width: 320, height: 80))
            ghostLabel.bounds.size = CGSize(width: min(340, size.width + 20), height: size.height + 12)
        }
        ghostLabel.center = CGPoint(x: spot.x, y: spot.y - 44)
        ghostLabel.isHidden = false
        bringSubviewToFront(ghostLabel)
    }

    /// Le doigt est-il tout près d'une frontière de cette région ? Laquelle (voisine) ?
    private func nearBorder(of province: Int, at point: CGPoint, project: ScreenProjection) -> Int? {
        var best: (Int, CGFloat)?
        for b in ProvinceMap.borders where b.a == province || b.b == province {
            let other = b.a == province ? b.b : b.a
            for line in b.lines {
                let stride = max(1, line.count / 40)
                var i = 0
                while i < line.count {
                    let s = project(line[i])
                    let d = hypot(s.x - point.x, s.y - point.y)
                    if d < (best?.1 ?? 30) { best = (other, d) }
                    i += stride
                }
            }
        }
        return best?.0
    }

    // MARK: Lasso (appui long sur la carte, puis entourer les pions)

    private var lassoGesture: UILongPressGestureRecognizer?

    private func installLasso() {
        guard let map = map, lassoGesture == nil else { return }
        let g = UILongPressGestureRecognizer(target: self, action: #selector(lasso(_:)))
        g.minimumPressDuration = 0.35
        g.allowableMovement = 12
        g.delegate = self
        map.addGestureRecognizer(g)
        lassoGesture = g
    }

    @objc private func lasso(_ g: UILongPressGestureRecognizer) {
        guard let map = map else { return }
        let loc = g.location(in: self)
        switch g.state {
        case .began:
            map.isScrollEnabled = false
            map.isZoomEnabled = false
            lassoPoints = [loc]
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .changed:
            if let last = lassoPoints.last, hypot(last.x - loc.x, last.y - loc.y) > 4 { lassoPoints.append(loc) }
            let path = UIBezierPath()
            path.move(to: lassoPoints[0])
            for p in lassoPoints.dropFirst() { path.addLine(to: p) }
            if arrowMode {
                // Des armées sont sélectionnées : le trait est une flèche d'offensive.
                if lassoPoints.count >= 3 {
                    let n = lassoPoints.count
                    addHead(path, from: lassoPoints[max(0, n - 4)], to: lassoPoints[n - 1], size: 22)
                }
                lassoLayer.fillColor = nil
                lassoLayer.strokeColor = UIColor(Theme.coral).cgColor
                lassoLayer.lineWidth = 6
                lassoLayer.lineCap = .round
                lassoLayer.lineJoin = .round
                lassoLayer.lineDashPattern = nil
            } else {
                path.close()
                lassoLayer.fillColor = UIColor(Theme.amber).withAlphaComponent(0.12).cgColor
                lassoLayer.strokeColor = UIColor(Theme.amber).cgColor
                lassoLayer.lineWidth = 2
                lassoLayer.lineDashPattern = [6, 4]
            }
            lassoLayer.path = path.cgPath
        default:
            map.isScrollEnabled = true
            map.isZoomEnabled = true
            lassoLayer.path = nil
            defer { lassoPoints = [] }
            guard g.state == .ended, lassoPoints.count > 4 else { return }
            let shape = UIBezierPath()
            shape.move(to: lassoPoints[0])
            for p in lassoPoints.dropFirst() { shape.addLine(to: p) }
            shape.close()
            let picked = tokens.values.filter { !$0.isHidden && $0.token.isPlayer && shape.contains($0.center) }.map { $0.token.id }
            let geo = lassoPoints.map { pt -> GeoPoint in
                let c = map.convert(pt, toCoordinateFrom: self)
                return GeoPoint(lat: c.latitude, lon: c.longitude)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onStroke?(picked.sorted(), geo)
        }
    }

    /// Une de nos armées est sélectionnée : le trait au doigt devient une flèche d'offensive.
    private var arrowMode: Bool { snapshot.tokens.contains { $0.selected && $0.isPlayer } }
}

// MARK: - Le pion

final class UnitTokenView: UIView {
    static let size = CGSize(width: 92, height: 34)

    var token: UnitToken { didSet { setNeedsDisplay(); updatePulse() } }
    var position: MKMapPoint = MKMapPoint(x: 0, y: 0)
    var scale: CGFloat = 1

    init(token: UnitToken) {
        self.token = token
        super.init(frame: CGRect(origin: .zero, size: UnitTokenView.size))
        isOpaque = false
        backgroundColor = .clear
        contentScaleFactor = UIScreen.main.scale
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        // Ombre à forme fixe : bien moins coûteuse à afficher qu'une ombre calculée à chaque image.
        layer.shadowPath = UnitTokenView.plate(bounds.insetBy(dx: 1.5, dy: 1.5)).cgPath
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

    /// Contour de la plaque : coins haut-gauche et bas-droit coupés (style jeu de stratégie).
    static func plate(_ r: CGRect) -> UIBezierPath {
        let c: CGFloat = 7
        let p = UIBezierPath()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.close()
        return p
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let r = bounds.insetBy(dx: 1.5, dy: 1.5)
        let body = UnitTokenView.plate(r)
        let country = token.color.uiColor
        // Fond : nuit profonde, éclairée par le haut
        ctx.saveGState()
        ctx.addPath(body.cgPath)
        ctx.clip()
        let space = CGColorSpaceCreateDeviceRGB()
        if let g = CGGradient(colorsSpace: space, colors: [UIColor(red: 0.13, green: 0.18, blue: 0.26, alpha: 0.97).cgColor,
                                                            UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 0.97).cgColor] as CFArray,
                              locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: r.minY), end: CGPoint(x: 0, y: r.maxY), options: [])
        }
        // Bande du pays à gauche, sous le drapeau
        ctx.setFillColor(country.withAlphaComponent(0.75).cgColor)
        ctx.fill(CGRect(x: r.minX, y: r.minY, width: 28, height: r.height))
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.25).cgColor)
        ctx.fill(CGRect(x: r.minX + 28, y: r.minY, width: 1, height: r.height))
        // Composition (haut) : une couleur par type de division
        var x = r.minX
        for (k, share) in token.mix.enumerated() where share > 0 {
            let w = r.width * CGFloat(share)
            ctx.setFillColor(UnitArt.mixColors[k % UnitArt.mixColors.count].cgColor)
            ctx.fill(CGRect(x: x, y: r.minY, width: w, height: 2.5))
            x += w
        }
        // Moral (bas) : vert, ambre ou rouge
        let org = CGFloat(token.org)
        let moraleColor: UIColor = org >= 0.6 ? UIColor(Theme.teal) : (org >= 0.3 ? UIColor(Theme.amber) : UIColor(Theme.coral))
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.10).cgColor)
        ctx.fill(CGRect(x: r.minX + 29, y: r.maxY - 3.5, width: r.width - 29, height: 3.5))
        ctx.setFillColor(moraleColor.cgColor)
        ctx.fill(CGRect(x: r.minX + 29, y: r.maxY - 3.5, width: (r.width - 29) * org, height: 3.5))
        ctx.restoreGState()
        // Contour : couleur du pays (doré si sélectionné, rouge au combat, pointillé si au service d'un autre)
        let stroke: UIColor = token.selected ? UIColor(Theme.amber) : (token.engaged ? UIColor(Theme.coral) : country.lighter(0.25))
        ctx.addPath(body.cgPath)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(token.selected ? 3 : 1.6)
        if token.serving { ctx.setLineDash(phase: 0, lengths: [4, 3]) }
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        // Drapeau
        let flag = token.flag as NSString
        let fAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15)]
        let fs = flag.size(withAttributes: fAttrs)
        flag.draw(at: CGPoint(x: r.minX + 14 - fs.width / 2, y: r.midY - fs.height / 2), withAttributes: fAttrs)
        // Pictogramme du type dominant
        UnitArt.draw(token.mainType, in: CGRect(x: r.minX + 33, y: r.minY + 7, width: 26, height: 16), context: ctx)
        // Effectif
        let count = "\(token.count)" as NSString
        let cAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .black),
            .foregroundColor: UIColor.white
        ]
        let cs = count.size(withAttributes: cAttrs)
        count.draw(at: CGPoint(x: r.maxX - 7 - cs.width, y: r.midY - cs.height / 2 - 1.5), withAttributes: cAttrs)
        // Galons d'expérience (chevrons dorés) au-dessus du pictogramme
        if token.rank > 0 {
            ctx.setStrokeColor(UIColor(Theme.amber).cgColor)
            ctx.setLineWidth(1.4)
            for k in 0..<token.rank {
                let y0 = r.minY + 3.5 + CGFloat(k) * 2.6
                ctx.move(to: CGPoint(x: r.minX + 41, y: y0 + 2))
                ctx.addLine(to: CGPoint(x: r.minX + 46, y: y0))
                ctx.addLine(to: CGPoint(x: r.minX + 51, y: y0 + 2))
            }
            ctx.strokePath()
        }
        // Point d'état : entraînement (or), en marche (bleu), tient une frontière (vert)
        var badge: UIColor?
        if token.training { badge = UIColor(Theme.amber) } else if token.moving { badge = UIColor(Theme.sky) }
        else if token.onBorder { badge = UIColor(Theme.teal) }
        if let b = badge {
            let d = CGRect(x: r.maxX - 9, y: r.minY - 2, width: 9, height: 9)
            let diamond = UIBezierPath()
            diamond.move(to: CGPoint(x: d.midX, y: d.minY))
            diamond.addLine(to: CGPoint(x: d.maxX, y: d.midY))
            diamond.addLine(to: CGPoint(x: d.midX, y: d.maxY))
            diamond.addLine(to: CGPoint(x: d.minX, y: d.midY))
            diamond.close()
            ctx.addPath(diamond.cgPath)
            ctx.setFillColor(b.cgColor)
            ctx.fillPath()
            ctx.addPath(diamond.cgPath)
            ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(1)
            ctx.strokePath()
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
        layer.shadowPath = UnitTokenView.plate(bounds.insetBy(dx: 1, dy: 1)).cgPath
        // Pulsation de l'ombre (et non de la taille, qui suit le zoom).
        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 2; pulse.toValue = 8; pulse.duration = 0.6; pulse.autoreverses = true; pulse.repeatCount = .infinity
        layer.add(pulse, forKey: "pulse")
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let r = bounds.insetBy(dx: 1, dy: 1)
        let path = UnitTokenView.plate(r)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(UIColor(red: 0.14, green: 0.04, blue: 0.05, alpha: 0.96).cgColor)
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
