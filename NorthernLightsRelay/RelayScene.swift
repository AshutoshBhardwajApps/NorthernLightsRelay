import SpriteKit

final class RelayScene: SKScene {
    private struct Gate {
        let node: SKNode
        let opening: CGRect
        var scored = false
        var brushed = false   // zen mode: already softened after a touch
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

    let isZen: Bool
    private let puckColor: SKColor
    private let puck = SKSpriteNode(imageNamed: "Puck")
    private var gates: [Gate] = []
    private var ribbons: [SKShapeNode] = []
    private var stars: [SKShapeNode] = []
    private var targetX: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private var spawnClock: TimeInterval = 0
    private var trailClock: TimeInterval = 0
    private var ended = false
    private var scoreValue = 0
    private var milestoneIndex = 0
    private var currentSky = RelayScene.baseSky
    var score: Int { scoreValue }
    var onGameOver: ((Int) -> Void)?
    var onScoreChanged: ((Int) -> Void)?

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
        drawSky()
        targetX = size.width / 2
        puck.size = CGSize(width: Self.puckRadius * 2.2, height: Self.puckRadius * 2.2)
        puck.color = puckColor
        puck.colorBlendFactor = 0.52
        puck.position = CGPoint(x: targetX, y: playerY)
        puck.zPosition = 10
        addChild(puck)
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 12))
        shadow.fillColor = .black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -19)
        puck.addChild(shadow)
        addGate()
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
            let star = SKShapeNode(circleOfRadius: i % 5 == 0 ? 1.8 : 1)
            star.fillColor = .white.withAlphaComponent(i % 3 == 0 ? 0.68 : 0.34)
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat((i * 71 + 33) % max(1, Int(size.width))), y: CGFloat((i * 131 + 80) % max(1, Int(size.height))))
            star.zPosition = -0.8
            addChild(star)
            stars.append(star)
        }

        // Aurora ribbons start invisible; each milestone wakes the next one.
        let ribbonSpecs: [(y: CGFloat, color: SKColor, phase: CGFloat)] = [
            (0.80, SKColor(red: 0.35, green: 1.0, blue: 0.62, alpha: 1), 0),
            (0.68, SKColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1), 1.7),
            (0.88, SKColor(red: 0.70, green: 0.50, blue: 1.0, alpha: 1), 3.1),
            (0.58, SKColor(red: 0.45, green: 1.0, blue: 0.80, alpha: 1), 4.4),
        ]
        for spec in ribbonSpecs {
            let ribbon = SKShapeNode(path: ribbonPath(baseY: size.height * spec.y, phase: spec.phase))
            ribbon.fillColor = spec.color.withAlphaComponent(0.13)
            ribbon.strokeColor = .clear
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
        }
    }

    private func ribbonPath(baseY: CGFloat, phase: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let w = size.width + 80
        let steps = 24
        func top(_ x: CGFloat) -> CGFloat { baseY + sin(x / w * .pi * 2.2 + phase) * 26 }
        func bottom(_ x: CGFloat) -> CGFloat { top(x) - 34 - sin(x / w * .pi * 3 + phase) * 12 }
        path.move(to: CGPoint(x: -40, y: top(-40)))
        for s in 1...steps { let x = -40 + w * CGFloat(s) / CGFloat(steps); path.addLine(to: CGPoint(x: x, y: top(x))) }
        for s in stride(from: steps, through: 0, by: -1) { let x = -40 + w * CGFloat(s) / CGFloat(steps); path.addLine(to: CGPoint(x: x, y: bottom(x))) }
        path.closeSubpath()
        return path
    }

    private func checkMilestone() {
        guard milestoneIndex < Self.milestones.count, scoreValue >= Self.milestones[milestoneIndex].gates else { return }
        let milestone = Self.milestones[milestoneIndex]
        if milestoneIndex < ribbons.count {
            ribbons[milestoneIndex].run(.fadeIn(withDuration: 3))
        }
        AudioManager.shared.playMilestoneChime()
        if milestoneIndex == Self.milestones.count - 1 {
            stars.forEach { $0.run(.fadeAlpha(to: 1, duration: 3)) }
        }
        shiftSky(to: milestone.sky)
        showBanner(milestone.title)
        milestoneIndex += 1
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

    private func showBanner(_ text: String) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 14
        label.fontColor = SKColor.white.withAlphaComponent(0.8)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
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
        // Keep the gate's geometry local to its moving node. Mixing scene-space
        // Y coordinates into the children made the cleanup check remove gates
        // as soon as they dipped below the top edge.
        let opening = CGRect(x: center - halfGap, y: 0, width: halfGap * 2, height: 58)
        let gateNode = SKNode()
        gateNode.position = CGPoint(x: 0, y: size.height + 28)
        gateNode.zPosition = 5

        // Blocks run off the screen edges (rounded ends hidden) to the opening, so
        // there are no gaps beside them and each side is at least `margin` wide.
        let overhang: CGFloat = 12
        let leftWidth = opening.minX + overhang
        let rightX = opening.maxX
        let rightWidth = size.width + overhang - rightX
        let color = SKColor(red: 0.50, green: 0.84, blue: 0.90, alpha: 0.95)
        for (x, width) in [(-overhang, leftWidth), (rightX, rightWidth)] where width > 0 {
            let block = SKShapeNode(rectOf: CGSize(width: width, height: Self.gateThickness), cornerRadius: 8)
            block.name = "block"
            block.fillColor = color
            block.strokeColor = .white.withAlphaComponent(0.42)
            block.lineWidth = 1
            block.position = CGPoint(x: x + width / 2, y: opening.midY)
            gateNode.addChild(block)
        }
        // Soft lanterns mark the edges of the opening, in line with the gate.
        for x in [opening.minX, opening.maxX] {
            let lantern = SKShapeNode(circleOfRadius: 3.5)
            lantern.name = "lantern"
            lantern.fillColor = SKColor.cyan.withAlphaComponent(0.8)
            lantern.strokeColor = .clear
            lantern.position = CGPoint(x: x, y: opening.midY)
            gateNode.addChild(lantern)
        }
        addChild(gateNode)
        gates.append(Gate(node: gateNode, opening: opening))
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard !ended else { return }
        let dt = lastUpdate == 0 ? 0 : min(1.0 / 30.0, currentTime - lastUpdate)
        lastUpdate = currentTime
        guard dt > 0 else { return }
        spawnClock += dt
        if spawnClock >= spawnInterval {
            spawnClock = 0
            addGate()
        }

        let bounds = Self.puckRadius + 8
        let dx = targetX - puck.position.x
        puck.position.x += dx * min(1, CGFloat(dt) * 11)
        puck.position.x = min(size.width - bounds, max(bounds, puck.position.x))
        dropTrail(dt)

        for index in gates.indices {
            gates[index].node.position.y -= gateSpeed * CGFloat(dt)
            let gateY = gates[index].node.position.y + gates[index].opening.midY
            // A hit is when the puck's circle actually touches a block.
            let touchDistance = Self.gateThickness / 2 + Self.puckRadius
            if abs(gateY - playerY) < touchDistance {
                let opening = gates[index].opening
                if puck.position.x - Self.puckRadius < opening.minX || puck.position.x + Self.puckRadius > opening.maxX {
                    if isZen {
                        // Zen: no crashes. The gate just softens and lets you through.
                        if !gates[index].brushed {
                            gates[index].brushed = true
                            gates[index].node.run(.fadeAlpha(to: 0.3, duration: 0.4))
                        }
                    } else {
                        finishRun()
                        return
                    }
                }
            }
            if !gates[index].scored && gateY < playerY - touchDistance {
                gates[index].scored = true
                // Zen counts every gate (so the aurora still wakes); normal runs
                // only reach here on a clean pass anyway.
                do {
                    scoreValue += 1
                    onScoreChanged?(scoreValue)
                    AudioManager.shared.playGateChime(gate: scoreValue)
                    checkMilestone()
                }
                // Gentle acknowledgement instead of a sharp flash: the puck
                // swells slightly and the gate's lanterns fade out slowly.
                let swell = SKAction.sequence([.scale(to: 1.06, duration: 0.25), .scale(to: 1, duration: 0.35)])
                swell.timingMode = .easeInEaseOut
                puck.run(swell, withKey: "swell")
                gates[index].node.enumerateChildNodes(withName: "lantern") { node, _ in
                    node.run(.fadeOut(withDuration: 0.6))
                }
            }
        }
        gates.removeAll {
            if $0.node.position.y < -80 { $0.node.removeFromParent(); return true }
            return false
        }
    }

    /// A soft trail of fading puck-coloured dots that drift away with the ice.
    private func dropTrail(_ dt: TimeInterval) {
        trailClock += dt
        guard trailClock >= 0.025 else { return }
        trailClock = 0
        let dot = SKShapeNode(circleOfRadius: Self.puckRadius * 0.55)
        dot.fillColor = puckColor.withAlphaComponent(0.16)
        dot.strokeColor = .clear
        dot.position = puck.position
        dot.zPosition = 9
        addChild(dot)
        let life: TimeInterval = 0.55
        dot.run(.sequence([
            .group([.moveBy(x: 0, y: -gateSpeed * CGFloat(life), duration: life),
                    .fadeOut(withDuration: life),
                    .scale(to: 0.3, duration: life)]),
            .removeFromParent(),
        ]))
    }

    private func finishRun() {
        guard !ended else { return }
        ended = true
        // Slow dim rather than a strobe-like blink.
        let dim = SKAction.fadeAlpha(to: 0.45, duration: 0.5)
        dim.timingMode = .easeOut
        puck.run(dim)
        onGameOver?(scoreValue)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    private func steer(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self) else { return }
        targetX = point.x
    }
}
