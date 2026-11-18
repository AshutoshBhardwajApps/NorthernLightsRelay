import SpriteKit

final class RelayScene: SKScene {
    private struct Gate {
        let node: SKNode
        let opening: CGRect
        var scored = false
    }

    private let puck = SKShapeNode(circleOfRadius: 15)
    private var gates: [Gate] = []
    private var targetX: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private var spawnClock: TimeInterval = 0
    private var runClock: TimeInterval = 0
    private var ended = false
    private var scoreValue = 0
    var score: Int { scoreValue }
    var onGameOver: ((Int) -> Void)?
    var onScoreChanged: ((Int) -> Void)?

    private var playerY: CGFloat { size.height * 0.22 }
    private var gateSpeed: CGFloat { min(500, 255 + CGFloat(scoreValue) * 9) }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = SKColor(red: 0.025, green: 0.07, blue: 0.14, alpha: 1)
        scaleMode = .resizeFill
        drawCanal()
        targetX = size.width / 2
        puck.fillColor = SKColor(red: 0.42, green: 0.94, blue: 1, alpha: 1)
        puck.strokeColor = .white
        puck.lineWidth = 2
        puck.glowWidth = 8
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

    private func drawCanal() {
        let bankWidth = size.width * 0.12
        let leftBank = SKShapeNode(rect: CGRect(x: 0, y: 0, width: bankWidth, height: size.height))
        let rightBank = SKShapeNode(rect: CGRect(x: size.width - bankWidth, y: 0, width: bankWidth, height: size.height))
        [leftBank, rightBank].forEach {
            $0.fillColor = SKColor(red: 0.06, green: 0.20, blue: 0.27, alpha: 1)
            $0.strokeColor = .clear
            $0.zPosition = -2
            addChild($0)
        }
        let leftEdge = SKShapeNode(rect: CGRect(x: bankWidth, y: 0, width: 2, height: size.height))
        let rightEdge = SKShapeNode(rect: CGRect(x: size.width - bankWidth - 2, y: 0, width: 2, height: size.height))
        [leftEdge, rightEdge].forEach {
            $0.fillColor = SKColor.cyan.withAlphaComponent(0.42)
            $0.strokeColor = .clear
            $0.zPosition = 1
            addChild($0)
        }
        let moon = SKShapeNode(circleOfRadius: 24)
        moon.fillColor = SKColor(red: 0.77, green: 0.95, blue: 1, alpha: 0.9)
        moon.strokeColor = .clear
        moon.glowWidth = 15
        moon.position = CGPoint(x: size.width * 0.78, y: size.height * 0.83)
        moon.zPosition = -1
        addChild(moon)
        for i in 0..<20 {
            let star = SKShapeNode(circleOfRadius: i % 5 == 0 ? 1.8 : 1)
            star.fillColor = .white.withAlphaComponent(i % 3 == 0 ? 0.68 : 0.34)
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat((i * 71 + 33) % max(1, Int(size.width))), y: CGFloat((i * 131 + 80) % max(1, Int(size.height))))
            star.zPosition = -1
            addChild(star)
        }
    }

    private func addGate() {
        let margin = size.width * 0.12 + 28
        let halfGap = max(48, min(76, size.width * 0.18))
        let center = CGFloat.random(in: (margin + halfGap)...(size.width - margin - halfGap))
        // Keep the gate's geometry local to its moving node. Mixing scene-space
        // Y coordinates into the children made the cleanup check remove gates
        // as soon as they dipped below the top edge.
        let opening = CGRect(x: center - halfGap, y: 0, width: halfGap * 2, height: 58)
        let gateNode = SKNode()
        gateNode.position = CGPoint(x: 0, y: size.height + 28)
        gateNode.zPosition = 5

        let leftWidth = max(0, opening.minX - margin)
        let rightX = opening.maxX
        let rightWidth = max(0, size.width - margin - rightX)
        let color = SKColor(red: 0.50, green: 0.84, blue: 0.90, alpha: 0.95)
        if leftWidth > 0 {
            let block = SKShapeNode(rectOf: CGSize(width: leftWidth, height: 18), cornerRadius: 8)
            block.fillColor = color
            block.strokeColor = .white.withAlphaComponent(0.42)
            block.lineWidth = 1
            block.position = CGPoint(x: margin + leftWidth / 2, y: opening.midY)
            gateNode.addChild(block)
        }
        if rightWidth > 0 {
            let block = SKShapeNode(rectOf: CGSize(width: rightWidth, height: 18), cornerRadius: 8)
            block.fillColor = color
            block.strokeColor = .white.withAlphaComponent(0.42)
            block.lineWidth = 1
            block.position = CGPoint(x: rightX + rightWidth / 2, y: opening.midY)
            gateNode.addChild(block)
        }
        let glint = SKShapeNode(rectOf: CGSize(width: halfGap * 2, height: 2), cornerRadius: 1)
        glint.fillColor = .cyan.withAlphaComponent(0.75)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: center, y: opening.minY - 15)
        gateNode.addChild(glint)
        addChild(gateNode)
        gates.append(Gate(node: gateNode, opening: opening, scored: false))
    }

    override func update(_ currentTime: TimeInterval) {
        guard !ended else { return }
        let dt = lastUpdate == 0 ? 0 : min(1.0 / 30.0, currentTime - lastUpdate)
        lastUpdate = currentTime
        guard dt > 0 else { return }
        runClock += dt
        spawnClock += dt
        if spawnClock >= max(0.78, 1.38 - Double(scoreValue) * 0.012) {
            spawnClock = 0
            addGate()
        }

        let bounds = size.width * 0.12 + 18
        let dx = targetX - puck.position.x
        puck.position.x += dx * min(1, CGFloat(dt) * 11)
        puck.position.x = min(size.width - bounds, max(bounds, puck.position.x))

        for index in gates.indices {
            gates[index].node.position.y -= gateSpeed * CGFloat(dt)
            let gateY = gates[index].node.position.y + gates[index].opening.midY
            let verticalOverlap = abs(gateY - playerY) < 20
            if verticalOverlap {
                let opening = gates[index].opening
                if puck.position.x < opening.minX + 17 || puck.position.x > opening.maxX - 17 {
                    finishRun()
                    return
                }
            }
            if !gates[index].scored && gateY < playerY - 24 {
                gates[index].scored = true
                scoreValue += 1
                onScoreChanged?(scoreValue)
                let pulse = SKAction.sequence([.scale(to: 1.35, duration: 0.08), .scale(to: 1, duration: 0.13)])
                puck.run(pulse)
            }
        }
        gates.removeAll {
            if $0.node.position.y < -80 { $0.node.removeFromParent(); return true }
            return false
        }
    }

    private func finishRun() {
        guard !ended else { return }
        ended = true
        puck.run(.sequence([.fadeAlpha(to: 0.25, duration: 0.08), .fadeAlpha(to: 1, duration: 0.18)]))
        onGameOver?(scoreValue)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    private func steer(_ touches: Set<UITouch>) {
        guard let point = touches.first?.location(in: self) else { return }
        targetX = point.x
    }
}
