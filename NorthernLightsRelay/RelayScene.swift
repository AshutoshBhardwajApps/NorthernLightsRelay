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

    private static let puckRadius: CGFloat = 13   // a little inside the fox, so near misses are fair
    private static let gateThickness: CGFloat = 18
    private static let baseSky: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.025, 0.07, 0.14)
    private static let milestones: [Milestone] = [
        Milestone(gates: 10, title: "THE FIRE CATCHES", sky: (0.03, 0.09, 0.16)),
        Milestone(gates: 20, title: "FOX FIRES RISING", sky: (0.03, 0.11, 0.17)),
        Milestone(gates: 35, title: "VIOLET SKY", sky: (0.05, 0.07, 0.18)),
        Milestone(gates: 50, title: "THE WHOLE SKY BURNS BRIGHT", sky: (0.06, 0.05, 0.16)),
        Milestone(gates: 55, title: "FIRST LIGHT", sky: (0.10, 0.09, 0.21)),
    ]
    /// A run is one night: reach this many arches and dawn breaks.
    static let dawnArches = 60
    private static let dawnSky: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.19, 0.15, 0.28)

    // MARK: Pre-rendered textures
    // SKShapeNodes are re-tessellated and drawn one by one every frame, which
    // made scrolling stutter once gates, ~40 trail dots/sec and aurora bands
    // were on screen. Everything that moves or repeats now uses a texture that
    // is drawn once and batched by SpriteKit.

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
    private let puck = SKSpriteNode(texture: FoxArt.foxTextures[0])   // the fox
    private var gates: [Gate] = []
    private var ribbons: [SKNode] = []
    private var ribbonColors: [SKColor] = []
    /// Arches passed that are needed to fully light each aurora band in turn.
    private static let ribbonThresholds = [0, 10, 20, 35, 50]
    private var stars: [SKNode] = []
    private var targetX: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private let tail = SKSpriteNode(texture: FoxArt.tailTexture)
    private var tailPath: [(x: CGFloat, travelled: CGFloat)] = []
    private var travelled: CGFloat = 0
    private var tailFlare: CGFloat = 0
    private static let tailRows = 32
    private var spawnClock: TimeInterval = 0
    private var ended = false
    private var recovering = false
    private var scoreValue = 0
    private var milestoneIndex = 0
    private var currentSky = RelayScene.baseSky
    var score: Int { scoreValue }
    var onGameOver: ((RunResult) -> Void)?
    var hapticsEnabled = true

    // Run stats
    private var perfects = 0
    private var perfectStreak = 0
    private var bestPerfectStreak = 0
    private var motesGathered = 0
    private var reachedDawn = false
    private var pickups: [SKSpriteNode] = []
    private var pickupSpawnedThisCycle = false
    private var bonusStars = 0            // earned, waiting for a clear gap between clouds
    private static let bonusValue = 3
    private let moteLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let crashHaptic = UIImpactFeedbackGenerator(style: .rigid)

    /// Everything this run produced so far (also used when leaving mid-run).
    var result: RunResult {
        RunResult(arches: scoreValue, perfects: perfects, bestPerfectStreak: bestPerfectStreak,
                  motes: motesGathered,
                  auroraBands: Self.ribbonThresholds.dropFirst().filter { scoreValue >= $0 }.count,
                  reachedDawn: reachedDawn, isZen: isZen)
    }

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
        puck.size = FoxArt.foxSize
        puck.color = puckColor
        puck.colorBlendFactor = 0.3
        puck.run(.repeatForever(.animate(with: FoxArt.foxTextures, timePerFrame: 0.11)), withKey: "run")
        puck.position = CGPoint(x: targetX, y: playerY)
        puck.zPosition = 10
        addChild(puck)
        // A soft, slowly breathing glow keeps the fox readable on the dark sky.
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
        tail.anchorPoint = .zero
        tail.position = .zero
        tail.size = size
        tail.color = puckColor
        tail.colorBlendFactor = 1
        tail.blendMode = .add
        tail.zPosition = 9
        tail.subdivisionLevels = 2
        addChild(tail)
        updateTail(step: 0, dt: 0)
        if !isZen { addScoreHUD() }
        addMoteHUD()
        [softHaptic, lightHaptic, crashHaptic].forEach { $0.prepare() }
        addGate()
    }

    // The live score is drawn by SpriteKit, not SwiftUI, so clearing a gate
    // never triggers a SwiftUI layout pass over the game view mid-run.
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-UltraLight")
    private let scoreTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")

    private func addScoreHUD() {
        let right = size.width - 30
        scoreTitle.text = "C L O U D S"
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

    private func addMoteHUD() {
        moteLabel.text = "✦ 0"
        moteLabel.fontSize = 14
        moteLabel.fontColor = SKColor(red: 1, green: 0.93, blue: 0.72, alpha: 0.85)
        moteLabel.horizontalAlignmentMode = .right
        moteLabel.position = CGPoint(x: size.width - 30, y: size.height - (isZen ? 96 : 140))
        moteLabel.zPosition = 30
        addChild(moteLabel)
    }

    private func haptic(_ generator: UIImpactFeedbackGenerator, _ intensity: CGFloat) {
        guard hapticsEnabled else { return }
        generator.impactOccurred(intensity: intensity)
    }

    // MARK: - Sky

    private func drawSky() {
        // No side banks: the whole screen is one open stretch of ice. The moon is
        // a faint, distant backdrop so gates passing in front of it read as depth.
        let moon = SKSpriteNode(imageNamed: "Moon")
        moon.size = CGSize(width: 92, height: 92)
        // Solid, so no stars show through, but tinted toward the night sky.
        moon.color = SKColor(red: 0.16, green: 0.25, blue: 0.40, alpha: 1)
        moon.colorBlendFactor = 0.62
        moon.position = CGPoint(x: size.width * 0.22, y: size.height * 0.70)
        moon.zPosition = -0.75   // over the stars, under the aurora
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
            ribbon.zPosition = -0.7
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

    /// One curtain of aurora light, rendered to a texture once.
    private func ribbonSprite(baseY: CGFloat, phase: CGFloat, color: UIColor) -> SKSpriteNode {
        let image = FoxArt.curtain(width: size.width + 80, phase: phase, color: color)
        let sprite = SKSpriteNode(texture: SKTexture(image: image), size: image.size)
        sprite.blendMode = .add
        sprite.position = CGPoint(x: size.width / 2, y: baseY)
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
        haptic(softHaptic, 0.5)
        milestoneIndex += 1
    }

    // MARK: - Lighting the aurora

    /// The colour of the band currently being lit.
    private var currentAuroraColor: SKColor {
        let band = Self.ribbonThresholds.lastIndex { scoreValue > $0 } ?? 0
        return ribbonColors.isEmpty ? .cyan : ribbonColors[min(band, ribbonColors.count - 1)]
    }

    /// Each arch passed brightens the aurora a little: band 1 fills over the
    /// first 10 arches, band 2 by 20, band 3 by 35, band 4 by 50.
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

    /// The cloud bank you passed takes on the aurora's colour, drifts apart
    /// and leaves a few stars behind it.
    private func partClouds(_ gate: Gate) {
        let color = currentAuroraColor
        gate.node.enumerateChildNodes(withName: "block") { node, _ in
            let side: CGFloat = node.xScale > 0 ? -1 : 1
            let drift = SKAction.moveBy(x: side * 70, y: 0, duration: 0.9)
            drift.timingMode = .easeOut
            node.run(.group([.colorize(with: color, colorBlendFactor: 0.5, duration: 0.4), drift,
                             .sequence([.wait(forDuration: 0.25), .fadeAlpha(to: 0.12, duration: 0.65)])]))
        }
        for _ in 0..<4 {
            let star = SKSpriteNode(texture: FoxArt.starTexture, size: CGSize(width: 7, height: 7))
            star.alpha = 0
            star.position = CGPoint(x: CGFloat.random(in: 20...(size.width - 20)),
                                    y: gate.opening.midY + CGFloat.random(in: -14...14))
            star.zPosition = -0.2
            gate.node.addChild(star)
            star.run(.sequence([.wait(forDuration: Double.random(in: 0.2...0.5)), .fadeAlpha(to: 0.7, duration: 0.5)]))
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

        // One wide cloud picture per side, slid to the gap edge. Nothing is
        // stretched, so the puffs keep their shape; the far end is off screen.
        let cloudSize = CGSize(width: max(460, size.width), height: FoxArt.cloudHeight)
        for (edge, mirrored) in [(opening.minX, false), (opening.maxX, true)] {
            let bank = SKSpriteNode(texture: FoxArt.cloudTexture, size: cloudSize)
            bank.name = "block"
            bank.anchorPoint = CGPoint(x: 1, y: 0.5)
            bank.xScale = mirrored ? -1 : 1
            bank.position = CGPoint(x: edge, y: opening.midY)
            gateNode.addChild(bank)
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
            pickupSpawnedThisCycle = false
            noteEvent("gateSpawn")
            addGate()
        }
        if !pickupSpawnedThisCycle && spawnClock >= spawnInterval * 0.5 {
            pickupSpawnedThisCycle = true
            if bonusStars > 0 {
                bonusStars -= 1
                addPickup(bonus: true)
            } else if Double.random(in: 0...1) < 0.55 {
                addPickup()
            }
        }

        if Self.autopilot, let next = gates.first(where: { !$0.scored && !$0.cleared }) {
            targetX = next.opening.midX   // test-only: steer through arch centres
        }
        let bounds = Self.puckRadius + 8
        let dx = targetX - puck.position.x
        puck.position.x += dx * min(1, CGFloat(dt) * 11)
        puck.position.x = min(size.width - bounds, max(bounds, puck.position.x))
        puck.zRotation = max(-0.4, min(0.4, -dx * 0.006))   // lean into the turn

        let step = gateSpeed * CGFloat(dt)
        updateTail(step: step, dt: CGFloat(dt))
        for mote in pickups where mote.name != "taken" {
            mote.position.y -= step
            let d = hypot(mote.position.x - puck.position.x, mote.position.y - puck.position.y)
            if d < Self.puckRadius + 12 { collect(mote) }
        }
        pickups.removeAll {
            if $0.position.y < -40 || $0.parent == nil { $0.removeFromParent(); return true }
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
                let opening = gates[index].opening
                if abs(puck.position.x - opening.midX) <= opening.width * 0.16 {
                    perfectPass()
                } else {
                    perfectStreak = 0
                }
                checkMilestone()
                if scoreValue == Self.dawnArches && !reachedDawn {
                    reachDawn()
                    if !isZen { return }
                }
                // Gentle acknowledgement instead of a sharp flash: the fox
                // swells slightly, the clouds drift apart in the aurora's colour,
                // and a spark drifts up to strengthen the aurora.
                let swell = SKAction.sequence([.scale(to: 1.06, duration: 0.25), .scale(to: 1, duration: 0.35)])
                swell.timingMode = .easeInEaseOut
                puck.run(swell, withKey: "swell")
                partClouds(gates[index])
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
        puck.run(.fadeOut(withDuration: 0.35))
        tail.run(.sequence([.fadeAlpha(to: 0.15, duration: 0.4), .wait(forDuration: 1.1), .fadeIn(withDuration: 0.4)]))
        burst(gathering: true)
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

    // MARK: - Tail and sparks

    /// The tail is one strip of light bent along the path the fox has run, so
    /// it costs a single draw however long it is.
    private func updateTail(step: CGFloat, dt: CGFloat) {
        travelled += step
        tailFlare = max(0, tailFlare - dt * 1.1)
        tailPath.append((puck.position.x, travelled))
        let length = playerY + 10
        while tailPath.count > 2, tailPath[1].travelled < travelled - length - 20 { tailPath.removeFirst() }

        let rows = Self.tailRows
        // Where the path was at each depth, from the tip (row 0) up to the fox.
        var xs: [CGFloat] = []
        xs.reserveCapacity(rows + 1)
        var sample = 0
        for row in 0...rows {
            let depth = length * (1 - CGFloat(row) / CGFloat(rows))
            let at = travelled - depth
            while sample + 1 < tailPath.count - 1, tailPath[sample + 1].travelled < at { sample += 1 }
            let a = tailPath[sample], b = tailPath[min(sample + 1, tailPath.count - 1)]
            let span = b.travelled - a.travelled
            let t = span > 0 ? max(0, min(1, (at - a.travelled) / span)) : 0
            xs.append(a.x + (b.x - a.x) * t + sin(depth * 0.035 - travelled * 0.012) * 9 * depth / length)
        }
        // Round off sharp turns; the end at the fox stays put.
        for _ in 0..<20 {
            var previous = xs[0]
            for row in 1..<rows {
                let here = xs[row]
                xs[row] = (previous + here * 2 + xs[row + 1]) / 4
                previous = here
            }
        }
        // Width is measured across the path, so slanted parts don't pinch.
        var points: [vector_float2] = []
        points.reserveCapacity((rows + 1) * 2)
        let rowHeight = length / CGFloat(rows)
        for row in 0...rows {
            let far = 1 - CGFloat(row) / CGFloat(rows)
            let up = min(row + 1, rows), down = max(row - 1, 0)
            let slopeX = xs[up] - xs[down], slopeY = CGFloat(up - down) * rowHeight
            let run = max(0.001, hypot(slopeX, slopeY))
            let half = (9 + 20 * far) * (1 + tailFlare * 0.7)
            let acrossX = slopeY / run * half, acrossY = -slopeX / run * half
            let y = playerY - 16 - length * far
            points.append(vector_float2(Float((xs[row] - acrossX) / size.width), Float((y - acrossY) / size.height)))
            points.append(vector_float2(Float((xs[row] + acrossX) / size.width), Float((y + acrossY) / size.height)))
        }
        tail.warpGeometry = SKWarpGeometryGrid(columns: 1, rows: rows).replacingByDestinationPositions(positions: points)
    }

    /// The fox bursts softly into sparks; in Zen they gather back into it.
    private func burst(gathering: Bool) {
        let home = puck.position
        for i in 0..<22 {
            let spark = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: 16, height: 16))
            spark.color = i % 3 == 0 ? .white : puckColor
            spark.colorBlendFactor = 1
            spark.blendMode = .add
            spark.position = home
            spark.alpha = 0   // brighten only once spread out, so nothing flashes
            spark.zPosition = 11
            addChild(spark)
            let angle = CGFloat(i) / 22 * .pi * 2 + CGFloat.random(in: -0.15...0.15)
            let reach = CGFloat.random(in: 34...95)
            let out = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach, duration: 0.8)
            out.timingMode = .easeOut
            if gathering {
                let back = SKAction.move(to: home, duration: 0.7)
                back.timingMode = .easeIn
                spark.run(.sequence([.group([out, .fadeAlpha(to: 0.8, duration: 0.6)]), .wait(forDuration: 0.1),
                                     .group([back, .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
            } else {
                spark.run(.sequence([.group([out, .fadeAlpha(to: 0.8, duration: 0.45)]), .fadeOut(withDuration: 0.7), .removeFromParent()]))
            }
        }
    }

    // MARK: - Hitch logging (launch with -hitchLog to enable)

    private static let hitchLogging = ProcessInfo.processInfo.arguments.contains("-hitchLog")
    /// Test-only: launch with -autopilot to steer through every arch centre.
    private static let autopilot = ProcessInfo.processInfo.arguments.contains("-autopilot")
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

    private func finishRun(victory: Bool = false) {
        guard !ended else { return }
        ended = true
        if !victory {
            puck.run(.fadeOut(withDuration: 0.35))
            tail.run(.fadeOut(withDuration: 0.8))
            burst(gathering: false)
            haptic(crashHaptic, 0.55)
        }
        [scoreTitle, scoreLabel, moteLabel].forEach { $0.run(.fadeOut(withDuration: 0.5)) }
        if victory {
            passTheFire()
        } else {
            onGameOver?(result)
        }
    }

    /// Dawn: the clouds clear, the next fox runs up alongside, takes the fire
    /// and carries it on; then the run ends. Driven by actions, so pausing or
    /// leaving stops it (leaving records the run instead).
    private func passTheFire() {
        for gate in gates { gate.node.run(.fadeOut(withDuration: 0.8)) }
        for star in pickups { star.run(.fadeOut(withDuration: 0.5)) }
        puck.zRotation = 0
        let side: CGFloat = puck.position.x > size.width / 2 ? -1 : 1
        let next = SKSpriteNode(texture: FoxArt.foxTextures[0], size: FoxArt.foxSize)
        next.color = currentAuroraColor
        next.colorBlendFactor = 0.3
        next.position = CGPoint(x: puck.position.x + side * 64, y: -60)
        next.zPosition = 10
        addChild(next)
        next.run(.repeatForever(.animate(with: FoxArt.foxTextures, timePerFrame: 0.11)))

        let arrive = SKAction.moveTo(y: playerY, duration: 1.1)
        arrive.timingMode = .easeOut
        let leave = SKAction.moveTo(y: size.height + 80, duration: 1.5)
        leave.timingMode = .easeIn
        next.run(.sequence([arrive, .wait(forDuration: 0.7), leave]))

        let fire = SKSpriteNode(texture: Self.glowTexture, size: CGSize(width: 120, height: 120))
        fire.color = currentAuroraColor
        fire.colorBlendFactor = 1
        fire.blendMode = .add
        fire.alpha = 0
        fire.position = puck.position
        fire.zPosition = 12
        addChild(fire)
        let across = SKAction.moveBy(x: side * 64, y: 0, duration: 0.6)
        across.timingMode = .easeInEaseOut
        let rise = SKAction.moveTo(y: size.height + 80, duration: 1.5)
        rise.timingMode = .easeIn
        fire.run(.sequence([.wait(forDuration: 0.9), .fadeIn(withDuration: 0.3), across, rise]))
        tail.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 1.2)]))
        puck.run(.sequence([.wait(forDuration: 2.1), .fadeOut(withDuration: 1.2)]))   // its night is done
        run(.sequence([.wait(forDuration: 3.5), .run { [weak self] in
            guard let self else { return }
            self.onGameOver?(self.result)
        }]))
    }

    // MARK: - Perfect passes, motes, dawn

    /// Through the centre of the arch: a soft ripple, a gentle haptic, a bonus
    /// mote, and a quiet streak count above the lantern.
    private func perfectPass() {
        perfects += 1
        perfectStreak += 1
        bestPerfectStreak = max(bestPerfectStreak, perfectStreak)
        // Stars are only ever counted when caught: five perfects in a row send
        // a bigger star down the sky to catch.
        if perfectStreak % 5 == 0 { bonusStars += 1 }
        haptic(softHaptic, 0.7)
        tailFlare = 1

        let ring = SKSpriteNode(texture: Self.ringTexture, size: CGSize(width: 40, height: 40))
        ring.color = currentAuroraColor
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.alpha = 0.55
        ring.position = puck.position
        ring.zPosition = 9.5
        addChild(ring)
        let ripple = SKAction.group([.scale(to: 2.4, duration: 0.6), .fadeOut(withDuration: 0.6)])
        ripple.timingMode = .easeOut
        ring.run(.sequence([ripple, .removeFromParent()]))

        if perfectStreak >= 2 { showTag("PERFECT ×\(perfectStreak)") }
    }

    /// A small note that rises from the fox and fades.
    private func showTag(_ text: String) {
        let tag = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        tag.text = text
        tag.fontSize = 12
        tag.fontColor = SKColor.white.withAlphaComponent(0.75)
        tag.position = CGPoint(x: puck.position.x, y: puck.position.y + 40)
        tag.zPosition = 20
        tag.alpha = 0
        addChild(tag)
        tag.run(.sequence([.group([.fadeIn(withDuration: 0.2), .moveBy(x: 0, y: 10, duration: 0.9)]),
                           .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    /// A mote of light floating between arches. Some sit off the safe line.
    private func addPickup(bonus: Bool = false) {
        let mote = SKSpriteNode(texture: Self.glowTexture, size: bonus ? CGSize(width: 58, height: 58) : CGSize(width: 34, height: 34))
        mote.name = bonus ? "bonus" : "star"
        mote.color = SKColor(red: 1, green: 0.93, blue: 0.72, alpha: 1)
        mote.colorBlendFactor = 1
        mote.blendMode = .add
        mote.alpha = 0.9
        mote.position = CGPoint(x: CGFloat.random(in: 40...(size.width - 40)), y: size.height + 30)
        mote.zPosition = 7
        let core = SKSpriteNode(texture: FoxArt.starTexture, size: bonus ? CGSize(width: 30, height: 30) : CGSize(width: 18, height: 18))
        core.color = SKColor(red: 1, green: 0.93, blue: 0.72, alpha: 1)
        core.colorBlendFactor = 1
        core.zPosition = 0.1
        core.alpha = 0.9
        mote.addChild(core)
        let pulse = SKAction.sequence([.scale(to: 1.15, duration: 0.9), .scale(to: 0.9, duration: 0.9)])
        pulse.timingMode = .easeInEaseOut
        mote.run(.repeatForever(pulse))
        addChild(mote)
        pickups.append(mote)
    }

    private func collect(_ mote: SKSpriteNode) {
        let bonus = mote.name == "bonus"
        mote.name = "taken"
        motesGathered += bonus ? Self.bonusValue : 1
        if bonus { showTag("+\(Self.bonusValue)") }
        moteLabel.text = "✦ \(motesGathered)"
        haptic(lightHaptic, 0.4)
        mote.removeAllActions()
        let fly = SKAction.move(to: moteLabel.position, duration: 0.5)
        fly.timingMode = .easeIn
        mote.run(.sequence([.group([fly, .scale(to: 0.4, duration: 0.5), .fadeAlpha(to: 0.3, duration: 0.5)]),
                            .removeFromParent()]))
    }

    /// Dawn: the sky warms, the night's relay is carried. Ends a normal run
    /// as a victory; Zen just greets the morning and glides on.
    private func reachDawn() {
        reachedDawn = true
        shiftSky(to: Self.dawnSky)
        stars.forEach { $0.run(.fadeAlpha(to: 0.15, duration: 3)) }
        haptic(softHaptic, 1)
        if isZen {
            showBanner("DAWN · THE FIRE IS PASSED ON", at: 0.55)
        } else {
            finishRun(victory: true)   // the end screen shows the dawn title
        }
    }

    /// A thin soft ring for the perfect-pass ripple.
    private static let ringTexture: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let path = UIBezierPath(ovalIn: CGRect(x: 4, y: 4, width: 56, height: 56))
            path.lineWidth = 3
            UIColor.white.setStroke()
            path.stroke()
        }
        return SKTexture(image: image)
    }()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { steer(touches) }
    private func steer(_ touches: Set<UITouch>) {
        guard !gamePaused, let point = touches.first?.location(in: self) else { return }
        targetX = point.x
    }
}
