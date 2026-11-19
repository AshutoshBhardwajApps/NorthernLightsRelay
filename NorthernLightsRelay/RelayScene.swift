import SpriteKit
import UIKit

final class RelayScene: SKScene {
    private struct Gate {
        let node: SKNode
        let opening: CGRect
        var scored = false
        var cleared = false   // zen: dissolved after a crash, no longer collides
    }

    /// A milestone changes the sky and wakes one more aurora ribbon.
    private struct Milestone {
        let gates: Int
        let title: String
        let sky: (r: CGFloat, g: CGFloat, b: CGFloat)
    }

    private static let puckRadius: CGFloat = 15
    private static let gateThickness: CGFloat = 18
    private static let baseSky: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.025, 0.07, 0.14)
    private static let milestones: [Milestone] = [
        Milestone(gates: 10, title: "THE SKY STIRS", sky: (0.03, 0.09, 0.16)),
        Milestone(gates: 25, title: "AURORA RISING", sky: (0.03, 0.11, 0.17)),
        Milestone(gates: 50, title: "VIOLET VEIL", sky: (0.05, 0.07, 0.18)),
        Milestone(gates: 100, title: "THE NIGHT IS YOURS", sky: (0.06, 0.05, 0.16)),
    ]

    // MARK: Pre-rendered textures
    // SKShapeNodes are re-tessellated and drawn one by one every frame, which
    // made scrolling stutter once gates, ~40 trail dots/sec and aurora bands
    // were on screen. Everything that moves or repeats now uses a texture that
    // is drawn once and batched by SpriteKit.

    private static let blockTextureSize = CGSize(width: 40, height: 18)
    private static let blockTexture: SKTexture = {
        // Uses the "ArchBlock" art (120×54 px, 9-slice) once it is added.
        if UIImage(named: "ArchBlock") != nil { return SKTexture(imageNamed: "ArchBlock") }
        let size = blockTextureSize
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            UIColor(red: 0.50, green: 0.84, blue: 0.90, alpha: 0.95).setFill()
            path.fill()
            UIColor.white.withAlphaComponent(0.42).setStroke()
            path.lineWidth = 1
            path.stroke()
        }
        return SKTexture(image: image)
    }()

    private static let dotTexture: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        }
        return SKTexture(image: image)
    }()

    /// A soft radial glow (white centre fading to clear) for halos and motes.
    private static let glowTexture: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1])!
            let center = CGPoint(x: 32, y: 32)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: 32, options: [])
        }
        return SKTexture(image: image)
    }()

    let isZen: Bool
    private let puckColor: SKColor
    // Uses the new "Lantern" art as soon as it is added to the asset catalog.
    private let puck = SKSpriteNode(imageNamed: UIImage(named: "Lantern") != nil ? "Lantern" : "Puck")
    private var gates: [Gate] = []
    private var ribbons: [SKNode] = []
    private var ribbonColors: [SKColor] = []
    /// Arches passed that are needed to fully light each aurora band in turn.
    private static let ribbonThresholds = [0, 10, 25, 50, 100]
    private var stars: [SKNode] = []
    private var targetX: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private var trail: [SKSpriteNode] = []
    private var spawnClock: TimeInterval = 0
    private var trailClock: TimeInterval = 0
    private var ended = false
    private var recovering = false
    private var scoreValue = 0
    private var milestoneIndex = 0
    private var currentSky = RelayScene.baseSky
    var score: Int { scoreValue }
    var onGameOver: ((Int) -> Void)?
    var onScoreChanged: ((Int) -> Void)?

    /// Player pause. Freezes the update loop and every running action. Kept
    /// separate from `isPaused`, which SKView resets when the app comes back.
    var gamePaused = false {
        didSet {
            speed = gamePaused ? 0 : 1
            if !gamePaused { lastUpdate = 0 }   // no time jump after resuming
        }
    }

    init(size: CGSize, zen: Bool = false, puckColor: SKColor = SKColor(red: 0.42, green: 0.94, blue: 1, alpha: 1)) {
        self.isZen = zen
        self.puckColor = puckColor
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not used") }

    private var playerY: CGFloat { size.height * 0.22 }
    private var gateSpeed: CGFloat { isZen ? 240 : min(500, 255 + CGFloat(scoreValue) * 9) }
    private var spawnInterval: Double { isZen ? 1.45 : max(0.78, 1.38 - Double(scoreValue) * 0.012) }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = SKColor(red: currentSky.r, green: currentSky.g, blue: currentSky.b, alpha: 1)
        scaleMode = .resizeFill
        view.ignoresSiblingOrder = true
        drawSky()
        targetX = size.width / 2
        puck.size = CGSize(width: Self.puckRadius * 2.2, height: Self.puckRadius * 2.2)
        puck.color = puckColor
        puck.colorBlendFactor = 0.52
        puck.position = CGPoint(x: targetX, y: playerY)
        puck.zPosition = 10
        addChild(puck)
        // The lantern's halo: a soft, slowly breathing glow so the light reads
        // clearly on the dark ice, whatever the orb art looks like.
        let halo = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: 96, height: 96))
        halo.color = puckColor
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.5
        halo.zPosition = -0.2
        puck.addChild(halo)
        let breathe = SKAction.sequence([.fadeAlpha(to: 0.6, duration: 2.4), .fadeAlpha(to: 0.42, duration: 2.4)])
        breathe.timingMode = .easeInEaseOut
        halo.run(.repeatForever(breathe))
        let shadow = SKSpriteNode(texture: Self.dotTexture, size: CGSize(width: 40, height: 12))
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = 0.28
        shadow.position = CGPoint(x: 0, y: -19)
        shadow.zPosition = -0.1
        puck.addChild(shadow)
        if !isZen { addScoreHUD() }
        addGate()
    }

    // The live score is drawn by SpriteKit, not SwiftUI, so clearing a gate
    // never triggers a SwiftUI layout pass over the game view mid-run.
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
    private let scoreTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private func addScoreHUD() {
        let right = size.width - 30
        scoreTitle.text = "A R C H E S"
        scoreTitle.fontSize = 10
        scoreTitle.fontColor = SKColor.white.withAlphaComponent(0.55)
        scoreTitle.horizontalAlignmentMode = .right
        scoreTitle.position = CGPoint(x: right, y: size.height - 70)
        scoreLabel.text = "0"
        scoreLabel.fontSize = 40
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: right, y: size.height - 114)
        for label in [scoreTitle, scoreLabel] {
            label.zPosition = 30
            addChild(label)
        }
    }

    // MARK: - Sky

    private func drawSky() {
        // No side banks: the whole screen is one open stretch of ice. The moon is
        // a faint, distant backdrop so gates passing in front of it read as depth.
        let moon = SKSpriteNode(imageNamed: "Moon")
        moon.size = CGSize(width: 92, height: 92)
        moon.alpha = 0.76
        moon.position = CGPoint(x: size.width * 0.22, y: size.height * 0.70)
        moon.zPosition = -1
        addChild(moon)
        for i in 0..<20 {
            let diameter: CGFloat = i % 5 == 0 ? 3.6 : 2
            let star = SKSpriteNode(texture: Self.dotTexture, size: CGSize(width: diameter, height: diameter))
            star.alpha = i % 3 == 0 ? 0.68 : 0.34
            star.position = CGPoint(x: CGFloat((i * 71 + 33) % max(1, Int(size.width))), y: CGFloat((i * 131 + 80) % max(1, Int(size.height))))
            star.zPosition = -0.8
            addChild(star)
            stars.append(star)
        }

        // Aurora ribbons start invisible; each milestone wakes the next one.
        let ribbonSpecs: [(y: CGFloat, color: UIColor, phase: CGFloat)] = [
            (0.80, UIColor(red: 0.35, green: 1.0, blue: 0.62, alpha: 1), 0),
            (0.68, UIColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1), 1.7),
            (0.88, UIColor(red: 0.70, green: 0.50, blue: 1.0, alpha: 1), 3.1),
            (0.58, UIColor(red: 0.45, green: 1.0, blue: 0.80, alpha: 1), 4.4),
        ]
        for spec in ribbonSpecs {
            let ribbon = ribbonSprite(baseY: size.height * spec.y, phase: spec.phase, color: spec.color)
            ribbon.zPosition = -1.5
            ribbon.alpha = 0
            addChild(ribbon)
            // Slow, gentle drift — never a flicker.
            let drift = SKAction.sequence([
                .moveBy(x: 24, y: 6, duration: 7),
                .moveBy(x: -24, y: -6, duration: 7),
            ])
            drift.timingMode = .easeInEaseOut
            ribbon.run(.repeatForever(drift))
            ribbons.append(ribbon)
            ribbonColors.append(spec.color)
        }
    }

    /// Renders one aurora band to a texture once, instead of a live shape.
    private func ribbonSprite(baseY: CGFloat, phase: CGFloat, color: UIColor) -> SKSpriteNode {
        let path = UIBezierPath()
        let w = size.width + 80
        let steps = 32
        func top(_ x: CGFloat) -> CGFloat { baseY + sin(x / w * .pi * 2.2 + phase) * 26 }
        func bottom(_ x: CGFloat) -> CGFloat { top(x) - 34 - sin(x / w * .pi * 3 + phase) * 12 }
        path.move(to: CGPoint(x: -40, y: top(-40)))
        for s in 1...steps { let x = -40 + w * CGFloat(s) / CGFloat(steps); path.addLine(to: CGPoint(x: x, y: top(x))) }
        for s in stride(from: steps, through: 0, by: -1) { let x = -40 + w * CGFloat(s) / CGFloat(steps); path.addLine(to: CGPoint(x: x, y: bottom(x))) }
        path.close()

        let box = path.bounds
        // Shift into the image's own (top-left origin, y-down) space.
        path.apply(CGAffineTransform(translationX: -box.minX, y: -box.minY))
        path.apply(CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -box.height))
        let image = UIGraphicsImageRenderer(size: box.size).image { _ in
            color.withAlphaComponent(0.13).setFill()
            path.fill()
        }
        let sprite = SKSpriteNode(texture: SKTexture(image: image), size: box.size)
        sprite.position = CGPoint(x: box.midX, y: box.midY)
        return sprite
    }

    private func checkMilestone() {
        guard milestoneIndex < Self.milestones.count, scoreValue >= Self.milestones[milestoneIndex].gates else { return }
        let milestone = Self.milestones[milestoneIndex]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            AudioManager.shared.playMilestoneChime()
        }
        if milestoneIndex == Self.milestones.count - 1 {
            stars.forEach { $0.run(.fadeAlpha(to: 1, duration: 3)) }
        }
        shiftSky(to: milestone.sky)
        showBanner(milestone.title)
        milestoneIndex += 1
    }

    // MARK: - Lighting the aurora

    /// The colour of the band currently being lit.
    private var currentAuroraColor: SKColor {
        let band = Self.ribbonThresholds.lastIndex { scoreValue > $0 } ?? 0
        return ribbonColors.isEmpty ? .cyan : ribbonColors[min(band, ribbonColors.count - 1)]
    }

    /// Each arch passed brightens the aurora a little: band 1 fills over the
    /// first 10 arches, band 2 by 25, band 3 by 50, band 4 by 100.
    private func feedAurora(from point: CGPoint) {
        for (i, ribbon) in ribbons.enumerated() where i + 1 < Self.ribbonThresholds.count {
            let start = Self.ribbonThresholds[i], end = Self.ribbonThresholds[i + 1]
            let progress = CGFloat(min(max(scoreValue - start, 0), end - start)) / CGFloat(end - start)
            if abs(ribbon.alpha - progress) > 0.001 {
                ribbon.removeAction(forKey: "light")
                ribbon.run(.fadeAlpha(to: progress, duration: 1.4), withKey: "light")
            }
        }
        // A small mote of light drifts from the arch up into the sky.
        let color = currentAuroraColor
        let mote = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: 18, height: 18))
        mote.color = color
        mote.colorBlendFactor = 1
        mote.blendMode = .add
        mote.alpha = 0.85
        mote.position = point
        mote.zPosition = 8
        addChild(mote)
        let target = CGPoint(x: CGFloat.random(in: size.width * 0.2...size.width * 0.8), y: size.height * 0.78)
        let rise = SKAction.move(to: target, duration: 1.3)
        rise.timingMode = .easeOut
        mote.run(.sequence([
            .group([rise, .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.7)]), .scale(to: 0.5, duration: 1.3)]),
            .removeFromParent(),
        ]))
    }

    /// The arch you passed softly takes on the aurora's colour.
    private func lightArch(_ gate: Gate) {
        let color = currentAuroraColor
        gate.node.enumerateChildNodes(withName: "block") { node, _ in
            node.run(.colorize(with: color, colorBlendFactor: 0.4, duration: 0.6))
        }
        gate.node.enumerateChildNodes(withName: "lantern") { node, _ in
            node.run(.colorize(with: color, colorBlendFactor: 1, duration: 0.6))
        }
    }

    private func shiftSky(to sky: (r: CGFloat, g: CGFloat, b: CGFloat)) {
        let from = currentSky
        currentSky = sky
        let duration: CGFloat = 3
        run(.customAction(withDuration: TimeInterval(duration)) { node, elapsed in
            let t = min(1, elapsed / duration)
            (node as? SKScene)?.backgroundColor = SKColor(red: from.r + (sky.r - from.r) * t,
                                                          green: from.g + (sky.g - from.g) * t,
                                                          blue: from.b + (sky.b - from.b) * t, alpha: 1)
        })
    }

    private func showBanner(_ text: String, at heightFraction: CGFloat = 0.62) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 14
        label.fontColor = SKColor.white.withAlphaComponent(0.8)
        label.position = CGPoint(x: size.width / 2, y: size.height * heightFraction)
        label.zPosition = 20
        label.alpha = 0
        addChild(label)
        label.run(.sequence([.fadeIn(withDuration: 0.8), .wait(forDuration: 1.6), .fadeOut(withDuration: 1.2), .removeFromParent()]))
    }

    // MARK: - Gates

    private func addGate() {
        let margin: CGFloat = 40
        let halfGap = max(48, min(76, size.width * 0.18))
        let center = CGFloat.random(in: (margin + halfGap)...(size.width - margin - halfGap))
        // Keep the gate's geometry local to its moving node.
        let opening = CGRect(x: center - halfGap, y: 0, width: halfGap * 2, height: 58)
        let gateNode = SKNode()
        gateNode.position = CGPoint(x: 0, y: size.height + 28)
        gateNode.zPosition = 5

        // Blocks run off the screen edges (rounded ends hidden) to the opening.
        // A 9-slice sprite keeps the rounded corners crisp at any width.
        let overhang: CGFloat = 12
        let leftWidth = opening.minX + overhang
        let rightX = opening.maxX
        let rightWidth = size.width + overhang - rightX
        let base = Self.blockTextureSize
        for (x, width) in [(-overhang, leftWidth), (rightX, rightWidth)] where width > 0 {
            let block = SKSpriteNode(texture: Self.blockTexture, size: base)
            block.centerRect = CGRect(x: 10 / base.width, y: 0, width: (base.width - 20) / base.width, height: 1)
            block.xScale = width / base.width
            block.name = "block"
            block.position = CGPoint(x: x + width / 2, y: opening.midY)
            gateNode.addChild(block)
        }
        // Soft lanterns mark the edges of the opening, in line with the gate.
        for x in [opening.minX, opening.maxX] {
            let lantern = SKSpriteNode(texture: Self.dotTexture, size: CGSize(width: 7, height: 7))
            lantern.name = "lantern"
            lantern.color = .cyan
            lantern.colorBlendFactor = 1
            lantern.alpha = 0.8
            lantern.position = CGPoint(x: x, y: opening.midY)
            lantern.zPosition = 0.1
            gateNode.addChild(lantern)
        }
        addChild(gateNode)
        gates.append(Gate(node: gateNode, opening: opening))
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard !ended, !gamePaused else { lastUpdate = 0; return }
        let rawDt = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        guard rawDt > 0 else { return }
        logHitchIfNeeded(rawDt)
        // Use the real frame time so positions match what the display shows.
        let dt = min(1.0 / 30.0, rawDt)
        guard !recovering else { return }   // zen: the world holds still

        spawnClock += dt
        if spawnClock >= spawnInterval {
            spawnClock -= spawnInterval
            noteEvent("gateSpawn")
            addGate()
        }

        let bounds = Self.puckRadius + 8
        let dx = targetX - puck.position.x
        puck.position.x += dx * min(1, CGFloat(dt) * 11)
        puck.position.x = min(size.width - bounds, max(bounds, puck.position.x))
        dropTrail(dt)

        let step = gateSpeed * CGFloat(dt)
        // Trail dots ride the same per-frame step as the gates (no separate
        // SKAction clock), so they never drift against the ice.
        for dot in trail {
            dot.position.y -= step
            dot.alpha -= CGFloat(dt / 0.55) * 0.16
            dot.setScale(max(0.3, dot.xScale - CGFloat(dt / 0.55) * 0.7))
        }
        trail.removeAll {
            if $0.alpha <= 0.005 { $0.removeFromParent(); return true }
            return false
        }
        let touchDistance = Self.gateThickness / 2 + Self.puckRadius
        for index in gates.indices {
            gates[index].node.position.y -= step
            let gateY = gates[index].node.position.y + gates[index].opening.midY
            // A hit is when the puck's circle actually touches a block.
            if !gates[index].cleared && abs(gateY - playerY) < touchDistance {
                let opening = gates[index].opening
                if puck.position.x - Self.puckRadius < opening.minX || puck.position.x + Self.puckRadius > opening.maxX {
                    if isZen {
                        beginRecovery()
                    } else {
                        finishRun()
                    }
                    return
                }
            }
            if !gates[index].scored && !gates[index].cleared && gateY < playerY - touchDistance {
                gates[index].scored = true
                noteEvent("gatePass")
                scoreValue += 1
                scoreLabel.text = "\(scoreValue)"
                AudioManager.shared.playGateChime(gate: scoreValue)
                checkMilestone()
                // Gentle acknowledgement instead of a sharp flash: the lantern
                // swells slightly, the arch takes on the aurora's colour, and a
                // mote of light drifts up to strengthen the aurora.
                let swell = SKAction.sequence([.scale(to: 1.06, duration: 0.25), .scale(to: 1, duration: 0.35)])
                swell.timingMode = .easeInEaseOut
                puck.run(swell, withKey: "swell")
                lightArch(gates[index])
                feedAurora(from: CGPoint(x: gates[index].opening.midX, y: gateY))
            }
        }
        gates.removeAll {
            if $0.node.position.y < -80 { $0.node.removeFromParent(); return true }
            return false
        }
    }

    /// Zen crash: everything holds still for a breath, the gates around the
    /// puck melt away, the puck gathers itself, and the glide carries on.
    private func beginRecovery() {
        guard !recovering else { return }
        recovering = true
        let dim = SKAction.fadeAlpha(to: 0.35, duration: 0.45)
        dim.timingMode = .easeOut
        puck.run(dim)
        showBanner("BREATHE", at: 0.30)

        let near = size.height * 0.28
        for index in gates.indices where abs(gates[index].node.position.y + gates[index].opening.midY - playerY) < near {
            gates[index].cleared = true
            gates[index].node.run(.sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.9)]))
        }

        let recover = SKAction.group([
            .fadeAlpha(to: 1, duration: 0.7),
            .sequence([.scale(to: 1.08, duration: 0.35), .scale(to: 1, duration: 0.35)]),
        ])
        recover.timingMode = .easeInEaseOut
        puck.run(.sequence([.wait(forDuration: 1.5), recover]))
        run(.sequence([.wait(forDuration: 1.9), .run { [weak self] in
            self?.recovering = false
            self?.lastUpdate = 0
        }]), withKey: "recovery")
    }

    /// A soft trail of fading puck-coloured dots that drift away with the ice.
    private func dropTrail(_ dt: TimeInterval) {
        trailClock += dt
        guard trailClock >= 0.025 else { return }
        trailClock = 0
        let diameter = Self.puckRadius * 1.1
        let dot = SKSpriteNode(texture: Self.dotTexture, size: CGSize(width: diameter, height: diameter))
        dot.color = puckColor
        dot.colorBlendFactor = 1
        dot.alpha = 0.16
        dot.position = puck.position
        dot.zPosition = 9
        addChild(dot)
        trail.append(dot)
    }

    // MARK: - Hitch logging (launch with -hitchLog to enable)

    private static let hitchLogging = ProcessInfo.processInfo.arguments.contains("-hitchLog")
    private var lastEvent = "none"
    private var lastEventTime: TimeInterval = 0

    private func noteEvent(_ name: String) {
        guard Self.hitchLogging else { return }
        lastEvent = name
        lastEventTime = CACurrentMediaTime()
    }

    private func logHitchIfNeeded(_ frame: TimeInterval) {
        guard Self.hitchLogging else { return }
        let expected = 1.0 / Double(max(1, view?.preferredFramesPerSecond ?? 60))
        guard frame > max(expected * 1.8, 1.0 / 50.0) else { return }
        let since = (CACurrentMediaTime() - lastEventTime) * 1000
        print(String(format: "HITCH frame=%.1fms nodes=%d gates=%d score=%d lastEvent=%@ (%.0fms ago)",
                     frame * 1000, children.count, gates.count, scoreValue, lastEvent, since))
    }

    private func finishRun() {
        guard !ended else { return }
        ended = true
        // Slow dim rather than a strobe-like blink.
        let dim = SKAction.fadeAlpha(to: 0.45, duration: 0.5)
        dim.timingMode = .easeOut
        puck.run(dim)
        [scoreTitle, scoreLabel].forEach { $0.run(.fadeOut(withDuration: 0.5)) }
        onGameOver?(scoreValue)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    private func steer(_ touches: Set<UITouch>) {
        guard !gamePaused, let point = touches.first?.location(in: self) else { return }
        targetX = point.x
    }
}
