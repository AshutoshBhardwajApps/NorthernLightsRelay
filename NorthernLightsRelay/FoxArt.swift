import SpriteKit
import UIKit

/// Art for the Fox Fires theme. Each piece uses the asset catalog when the
/// image has been added (see ASSET_BRIEF.md) and a code-drawn placeholder
/// until then. Everything is rendered once and reused.
enum FoxArt {
    /// Large enough that the painted body covers the scene's hit circle.
    static let foxSize = CGSize(width: 66, height: 88)
    static let cloudHeight: CGFloat = 54

    // MARK: Fox

    /// Running frames, seen from above with the nose at the top. Near-white,
    /// so the game can tint them per fox.
    static let foxImages: [UIImage] = {
        let supplied = (1...6).compactMap { UIImage(named: "Fox\($0)") }
        return supplied.isEmpty ? (0..<4).map(drawFox) : supplied
    }()
    static let foxTextures: [SKTexture] = foxImages.map { SKTexture(image: $0) }

    /// The fox with its full bushy tail, for menus and the story.
    static let portrait: UIImage = {
        if let image = UIImage(named: "FoxPortrait") { return image }
        return UIGraphicsImageRenderer(size: CGSize(width: 80, height: 116)).image { _ in
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: 35, y: 54))
            tail.addCurve(to: CGPoint(x: 56, y: 113), controlPoint1: CGPoint(x: 18, y: 84), controlPoint2: CGPoint(x: 30, y: 112))
            tail.addCurve(to: CGPoint(x: 43, y: 56), controlPoint1: CGPoint(x: 66, y: 94), controlPoint2: CGPoint(x: 44, y: 82))
            tail.close()
            UIColor(red: 0.74, green: 0.83, blue: 0.93, alpha: 1).setFill()
            tail.fill()
            let tip = UIBezierPath()
            tip.move(to: CGPoint(x: 56, y: 113))
            tip.addCurve(to: CGPoint(x: 37, y: 99), controlPoint1: CGPoint(x: 46, y: 113), controlPoint2: CGPoint(x: 40, y: 106))
            tip.addQuadCurve(to: CGPoint(x: 57, y: 98), controlPoint: CGPoint(x: 48, y: 104))
            tip.addQuadCurve(to: CGPoint(x: 56, y: 113), controlPoint: CGPoint(x: 60, y: 105))
            UIColor.white.setFill()
            tip.fill()
            foxImages[0].draw(in: CGRect(x: 15, y: 0, width: 48, height: 64))
        }
    }()

    /// From above, nose at the top.
    private static func drawFox(frame: Int) -> UIImage {
        let s: CGFloat = [1, 0, -1, 0][frame]
        return UIGraphicsImageRenderer(size: CGSize(width: 48, height: 64)).image { _ in
            let light = UIColor.white
            let shade = UIColor(red: 0.74, green: 0.83, blue: 0.93, alpha: 1)
            let dark = UIColor(red: 0.30, green: 0.40, blue: 0.54, alpha: 1)

            func leg(_ a: CGPoint, _ b: CGPoint) {
                let p = UIBezierPath()
                p.move(to: a); p.addLine(to: b)
                p.lineWidth = 4.5
                p.lineCapStyle = .round
                shade.setStroke()
                p.stroke()
            }
            func shape(_ color: UIColor, _ build: (UIBezierPath) -> Void) {
                let p = UIBezierPath()
                build(p)
                p.close()
                color.setFill()
                p.fill()
            }
            // Legs: opposite pairs reach and gather.
            leg(CGPoint(x: 19, y: 32), CGPoint(x: 13, y: 26 - s * 5))
            leg(CGPoint(x: 29, y: 32), CGPoint(x: 35, y: 26 + s * 5))
            leg(CGPoint(x: 18, y: 52), CGPoint(x: 13, y: 56 + s * 4))
            leg(CGPoint(x: 30, y: 52), CGPoint(x: 35, y: 56 - s * 4))
            // Slim body, rounder haunches.
            shape(light) { p in
                p.move(to: CGPoint(x: 24, y: 20))
                p.addCurve(to: CGPoint(x: 32, y: 50), controlPoint1: CGPoint(x: 33, y: 26), controlPoint2: CGPoint(x: 28, y: 40))
                p.addCurve(to: CGPoint(x: 24, y: 62), controlPoint1: CGPoint(x: 34, y: 57), controlPoint2: CGPoint(x: 29, y: 62))
                p.addCurve(to: CGPoint(x: 16, y: 50), controlPoint1: CGPoint(x: 19, y: 62), controlPoint2: CGPoint(x: 14, y: 57))
                p.addCurve(to: CGPoint(x: 24, y: 20), controlPoint1: CGPoint(x: 20, y: 40), controlPoint2: CGPoint(x: 15, y: 26))
            }
            // Wide-set pointed ears, swept back.
            for m: CGFloat in [1, -1] {
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 24 + m * x, y: y) }
                shape(light) { p in p.move(to: pt(3, 13)); p.addLine(to: pt(15, 12)); p.addLine(to: pt(9, 25)) }
                shape(dark) { p in p.move(to: pt(7, 15)); p.addLine(to: pt(13, 13.5)); p.addLine(to: pt(9.5, 20)) }
            }
            // Wedge head, long snout, dark nose.
            shape(light) { p in
                p.move(to: CGPoint(x: 24, y: 1))
                p.addCurve(to: CGPoint(x: 33, y: 21), controlPoint1: CGPoint(x: 27, y: 4), controlPoint2: CGPoint(x: 32, y: 13))
                p.addQuadCurve(to: CGPoint(x: 15, y: 21), controlPoint: CGPoint(x: 24, y: 31))
                p.addCurve(to: CGPoint(x: 24, y: 1), controlPoint1: CGPoint(x: 16, y: 13), controlPoint2: CGPoint(x: 21, y: 4))
            }
            dark.setFill()
            UIBezierPath(ovalIn: CGRect(x: 22, y: 1, width: 4, height: 4)).fill()
            let nape = UIBezierPath()
            nape.move(to: CGPoint(x: 17, y: 24))
            nape.addQuadCurve(to: CGPoint(x: 31, y: 24), controlPoint: CGPoint(x: 24, y: 30))
            nape.lineWidth = 1.3
            shade.setStroke()
            nape.stroke()
        }
    }

    // MARK: Tail ribbon

    /// A strip that fades in under the fox (top), is brightest just behind it and clear at its end (bottom),
    /// soft on both sides. Bent by the scene with a warp grid.
    static let tailTexture: SKTexture = {
        let size = CGSize(width: 48, height: 128)
        let space = CGColorSpaceCreateDeviceRGB()
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let down = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.95).cgColor, UIColor(white: 1, alpha: 0.45).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            cg.drawLinearGradient(CGGradient(colorsSpace: space, colors: down, locations: [0, 0.07, 0.45, 1])!,
                                  start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            cg.setBlendMode(.destinationIn)
            let across = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            cg.drawLinearGradient(CGGradient(colorsSpace: space, colors: across, locations: [0, 0.5, 1])!,
                                  start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
        }
        return SKTexture(image: image)
    }()

    // MARK: Cloud bank

    /// The left-hand bank. Its right end is the edge of the gap; the scene
    /// mirrors it for the right-hand side.
    static let cloudTexture: SKTexture = {
        if let image = UIImage(named: "CloudBank") { return SKTexture(image: softUnderside(image)) }
        let size = CGSize(width: 460, height: cloudHeight)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let puffs = UIBezierPath()
            puffs.append(UIBezierPath(roundedRect: CGRect(x: -30, y: 15, width: size.width + 29.5, height: 26), cornerRadius: 13))
            var x: CGFloat = -10
            var i = 0
            while x < size.width - 46 {
                let w: CGFloat = [58, 44, 66, 50][i % 4]
                let top: CGFloat = [4, 9, 2, 7][i % 4]
                puffs.append(UIBezierPath(ovalIn: CGRect(x: x, y: top, width: min(w, size.width - 4 - x), height: 34)))
                let lower = min(w * 0.9, size.width - 1 - (x + 14))
                puffs.append(UIBezierPath(ovalIn: CGRect(x: x + 14, y: 20, width: lower, height: 28)))
                x += w * 0.62
                i += 1
            }
            // Moonlit rim: the same shape, slightly raised, behind the dark body.
            UIColor(red: 0.60, green: 0.71, blue: 0.86, alpha: 1).setFill()
            let rim = puffs.copy() as! UIBezierPath
            rim.apply(CGAffineTransform(translationX: 0, y: -1.8))
            rim.fill()
            UIColor(red: 0.25, green: 0.32, blue: 0.46, alpha: 1).setFill()
            puffs.fill()
        }
        return SKTexture(image: image)
    }()

    /// Melts the bottom of the painted bank into the night, so it never ends
    /// in a straight cut.
    private static func softUnderside(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            image.draw(at: .zero)
            let cg = ctx.cgContext
            cg.setBlendMode(.destinationIn)
            let colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0.75).cgColor,
                          UIColor(white: 1, alpha: 0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 0.78, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: image.size.height), options: .drawsBeforeStartLocation)
        }
    }

    // MARK: Fallen star

    static let starTexture: SKTexture = {
        if let image = UIImage(named: "FallenStar") { return SKTexture(image: image) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { _ in
            let c = CGPoint(x: 16, y: 16)
            let p = UIBezierPath()
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4 - .pi / 2
                let r: CGFloat = i % 2 == 0 ? 15 : 4.5
                let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.close()
            UIColor.white.setFill()
            p.fill()
        }
        return SKTexture(image: image)
    }()

    // MARK: Aurora curtain

    private static var curtainCache: [String: UIImage] = [:]

    /// A curtain of light: bright along a waving lower edge, fading upward.
    static func curtain(width: CGFloat, phase: CGFloat, color: UIColor) -> UIImage {
        let key = "\(Int(width))-\(phase)"
        if let cached = curtainCache[key] { return cached }
        let size = CGSize(width: width, height: 170)
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [color.withAlphaComponent(0).cgColor, color.withAlphaComponent(0.12).cgColor,
                      color.withAlphaComponent(0.34).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 0.88, 1])!
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            var x: CGFloat = 0
            while x < width {
                let t = x / width
                let edge = 128 + sin(t * .pi * 2.2 + phase) * 26 + sin(t * .pi * 5 + phase * 2) * 7
                let tall = 92 + sin(t * .pi * 9 + phase) * 20
                cg.saveGState()
                cg.clip(to: CGRect(x: x, y: 0, width: 1, height: size.height))
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: edge - tall), end: CGPoint(x: 0, y: edge + 12), options: [])
                cg.restoreGState()
                x += 1
            }
        }
        curtainCache[key] = image
        return image
    }
}
