import SpriteKit
import SwiftUI

/// Today's energy as food falling into a bowl: chips, fries, baursaks or burgers, each one a
/// physics body that tumbles, piles up and lands with a soft tap in the hand.
struct FoodDropView: View {
    let thing: EnergyThings.Thing
    /// How many to drop: the real count, capped so the pile stays readable.
    let count: Int

    @State private var scene: FoodDropScene?

    var body: some View {
        GeometryReader { proxy in
            // A ZStack with something always in it: an empty Group would never appear.
            ZStack {
                Color.clear
                if let scene {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                }
            }
            .onAppear { remake(size: proxy.size) }
            .onChange(of: thing) { _, _ in remake(size: proxy.size) }
            .onChange(of: count) { _, _ in remake(size: proxy.size) }
        }
        .accessibilityHidden(true)
    }

    private func remake(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        scene = FoodDropScene(size: size, thing: thing, count: min(count, FoodDropScene.maximum))
    }
}

final class FoodDropScene: SKScene, SKPhysicsContactDelegate {
    static let maximum = 70

    private let thing: EnergyThings.Thing
    private let total: Int
    private var lastLanding = Date.distantPast

    private enum Category {
        static let bowl: UInt32 = 1
        static let food: UInt32 = 2
    }

    init(size: CGSize, thing: EnergyThings.Thing, count: Int) {
        self.thing = thing
        self.total = max(1, count)
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)
        physicsWorld.contactDelegate = self

        // A bowl open at the top: the walls go up past the top so nothing escapes.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 4, y: size.height + 400))
        path.addLine(to: CGPoint(x: 4, y: 26))
        path.addQuadCurve(to: CGPoint(x: size.width - 4, y: 26), control: CGPoint(x: size.width / 2, y: -6))
        path.addLine(to: CGPoint(x: size.width - 4, y: size.height + 400))
        let bowl = SKNode()
        bowl.physicsBody = SKPhysicsBody(edgeChainFrom: path)
        bowl.physicsBody?.categoryBitMask = Category.bowl
        bowl.physicsBody?.friction = 0.8
        addChild(bowl)

        // Faster and faster, like pouring: the first ones fall one by one.
        var actions: [SKAction] = []
        for index in 0..<total {
            actions.append(.run { [weak self] in self?.drop() })
            let wait = max(0.03, 0.22 * pow(0.93, Double(index)))
            actions.append(.wait(forDuration: wait))
        }
        run(.sequence(actions))
    }

    private func drop() {
        let node = SKSpriteNode(texture: FoodTextures.texture(for: thing))
        node.setScale(thing.id == EnergyThings.burger.id ? 1 : 1.35)
        let margin = max(node.size.width, node.size.height) / 2 + 6
        node.position = CGPoint(x: .random(in: margin...(size.width - margin)), y: size.height + node.size.height)
        node.zRotation = .random(in: -.pi...(.pi))
        let body: SKPhysicsBody = switch thing.id {
        case EnergyThings.fry.id: SKPhysicsBody(rectangleOf: CGSize(width: node.size.width * 0.8, height: node.size.height * 0.95))
        default: SKPhysicsBody(circleOfRadius: min(node.size.width, node.size.height) * 0.46)
        }
        body.restitution = 0.18
        body.friction = 0.7
        body.angularDamping = 0.6
        body.density = 0.8
        body.angularVelocity = .random(in: -6...6)
        body.categoryBitMask = Category.food
        body.contactTestBitMask = Category.bowl | Category.food
        node.physicsBody = body
        addChild(node)
    }

    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        let impulse = contact.collisionImpulse
        MainActor.assumeIsolated {
            // A soft tap for anything that lands hard enough to feel, not for every nudge.
            guard impulse > 1.5, Date().timeIntervalSince(lastLanding) > 0.06 else { return }
            lastLanding = Date()
            HapticPlayer.land(min(1, 0.25 + impulse / 40))
        }
    }
}

/// The food, drawn in code: a chip, a fry, a baursak; burgers are the emoji.
@MainActor
enum FoodTextures {
    private static var cache: [String: SKTexture] = [:]

    static func texture(for thing: EnergyThings.Thing) -> SKTexture {
        if let texture = cache[thing.id] { return texture }
        let image: UIImage = switch thing.id {
        case EnergyThings.chip.id: chip()
        case EnergyThings.fry.id: fry()
        case EnergyThings.baursak.id: baursak()
        default: emoji("🍔", size: 40)
        }
        let texture = SKTexture(image: image)
        cache[thing.id] = texture
        return texture
    }

    private static func chip() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 28, height: 22)).image { context in
            let rect = CGRect(x: 1, y: 1, width: 26, height: 20)
            let cg = context.cgContext
            cg.setFillColor(UIColor(red: 0.95, green: 0.74, blue: 0.27, alpha: 1).cgColor)
            cg.fillEllipse(in: rect)
            cg.setFillColor(UIColor(red: 1, green: 0.88, blue: 0.5, alpha: 0.9).cgColor)
            cg.fillEllipse(in: rect.insetBy(dx: 5, dy: 4).offsetBy(dx: -2, dy: -2))
            cg.setFillColor(UIColor(red: 0.78, green: 0.5, blue: 0.16, alpha: 0.6).cgColor)
            for spot in [CGPoint(x: 18, y: 13), CGPoint(x: 9, y: 15), CGPoint(x: 15, y: 6)] {
                cg.fillEllipse(in: CGRect(x: spot.x, y: spot.y, width: 2.4, height: 2))
            }
        }
    }

    private static func fry() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 9, height: 46)).image { context in
            let rect = CGRect(x: 0.5, y: 0.5, width: 8, height: 45)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 2.5)
            UIColor(red: 0.97, green: 0.79, blue: 0.29, alpha: 1).setFill()
            path.fill()
            UIColor(red: 1, green: 0.93, blue: 0.62, alpha: 0.9).setFill()
            UIBezierPath(roundedRect: CGRect(x: 2, y: 3, width: 2.2, height: 39), cornerRadius: 1).fill()
            context.cgContext.setFillColor(UIColor(red: 0.85, green: 0.58, blue: 0.18, alpha: 0.8).cgColor)
            context.cgContext.fill(CGRect(x: 0.5, y: 0.5, width: 8, height: 3))
        }
    }

    private static func baursak() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 30, height: 27)).image { context in
            let rect = CGRect(x: 1, y: 1, width: 28, height: 25)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 9)
            UIColor(red: 0.84, green: 0.55, blue: 0.24, alpha: 1).setFill()
            path.fill()
            UIColor(red: 0.96, green: 0.76, blue: 0.45, alpha: 0.95).setFill()
            UIBezierPath(roundedRect: rect.insetBy(dx: 5, dy: 5).offsetBy(dx: -1.5, dy: -2), cornerRadius: 6).fill()
        }
    }

    private static func emoji(_ text: String, size: CGFloat) -> UIImage {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size)]
        let bounds = (text as NSString).size(withAttributes: attributes)
        return UIGraphicsImageRenderer(size: bounds).image { _ in
            (text as NSString).draw(at: .zero, withAttributes: attributes)
        }
    }
}
