//
//  GameBox3DView.swift
//  Gameboxd
//
//  The game's case in real 3D (RealityKit), built like the retail case: a moulded plastic shell in
//  the platform's colour, and the printed insert wrapped round it, the back with screenshots, the
//  blurb, the PEGI label and a barcode, the spine as on the shelf, the cover on the front. Lit as in
//  a photo studio, so the film catches the softboxes as it turns. Drag to turn it; let go and it
//  keeps its momentum, then settles on the front or the back. Tilting the phone leans it a little.
//

import SwiftUI
import RealityKit

struct GameBox3DView: View {
    let game: Game
    var height: CGFloat = 360

    @State private var spin = SpinState()
    @State private var settleCount = 0
    @State private var leaning = false
    /// Resets when the drag ends or is cancelled (the scroll view takes the touch, the page closes):
    /// either way the box is let go, so it never stays stuck mid-turn.
    @GestureState private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Read (and so observed) only while the phone's tilt is followed.
        let tilt = leaning ? SIMD2(TiltMotion.shared.x, TiltMotion.shared.y) : .zero
        RealityView { content in
            content.camera = .virtual

            // A long lens from further back, as product shots are taken: little perspective.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 24
            camera.position = [0, 0, 0.56]
            content.add(camera)

            let pivot = Entity()
            pivot.orientation = SpinState.orientation(yaw: spin.yaw, pitch: spin.pitch)
            content.add(pivot)
            spin.pivot = pivot

            for light in GameBoxFactory.studioLights() {
                content.add(light)
            }
            let studio = await GameBoxFactory.studio()
            if let studio {
                content.add(studio)
            }

            if let model = await GameBoxFactory.makeCase(for: game, studio: studio) {
                pivot.addChild(model)
            }

            spin.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                MainActor.assumeIsolated {
                    if spin.step(Float(event.deltaTime)) {
                        settleCount += 1
                    }
                }
            }
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragging) { _, state, _ in state = true }
                .onChanged { spin.drag(by: $0.translation) }
        )
        .onChange(of: dragging) { _, now in
            if !now { spin.release() }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: settleCount)
        .onChange(of: tilt) { _, tilt in spin.lean(toward: tilt) }
        .onAppear {
            guard !reduceMotion, !leaning else { return }
            TiltMotion.shared.start()
            leaning = true
        }
        .onDisappear {
            if leaning {
                TiltMotion.shared.stop()
                leaning = false
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Boîte de \(game.title)")
        .accessibilityHint("Fais glisser pour tourner la boîte et voir le dos.")
    }
}

// MARK: - Rotation physics

/// Drag sets the angles directly; on release a spring pulls the box to the
/// nearest face (front or back), carrying the finger's velocity as momentum.
@MainActor
final class SpinState {
    static let restYaw: Float = 0.42    // turned so the spine (left edge) faces you
    static let restPitch: Float = 0.07

    var yaw: Float
    var pitch: Float = restPitch
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private var targetYaw: Float
    /// The phone's tilt, as a small turn of the case: the studio's light slides over its film, as
    /// it would over a case held in the hand.
    private var lean = SIMD2<Float>(0, 0)
    private var isDragging = false
    /// Let go after a drag: the settle that follows gets a tap of haptics; a lean's doesn't.
    private var flung = false
    private var dragStart: (yaw: Float, pitch: Float)?
    private var lastDragYaw: Float = 0
    private var lastDragTime = Date()
    private var isSettled = true

    weak var pivot: Entity?
    var subscription: EventSubscription?

    init() {
        var rest = Self.restYaw
        #if DEBUG
        // Launch argument `-box3DYaw <radians>`: start rotated, for simulator screenshots.
        if let debugYaw = UserDefaults.standard.object(forKey: "box3DYaw") as? String, let value = Float(debugYaw) {
            rest = value
        }
        #endif
        yaw = rest
        targetYaw = rest
    }

    static func orientation(yaw: Float, pitch: Float) -> simd_quatf {
        simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    func drag(by translation: CGSize) {
        if dragStart == nil {
            dragStart = (yaw, pitch)
            lastDragYaw = yaw
            lastDragTime = Date()
            yawVelocity = 0     // a drag catching a settle starts from still
            pitchVelocity = 0
        }
        guard let start = dragStart else { return }
        isDragging = true
        isSettled = false
        yaw = start.yaw + Float(translation.width) * 0.012
        pitch = min(max(start.pitch + Float(translation.height) * 0.006, -0.5), 0.5)

        let now = Date()
        let dt = Float(now.timeIntervalSince(lastDragTime))
        if dt > 0.004 {
            yawVelocity = (yaw - lastDragYaw) / dt
            lastDragYaw = yaw
            lastDragTime = now
        }
        pivot?.orientation = Self.orientation(yaw: yaw, pitch: pitch)
    }

    func release() {
        guard isDragging else { return }
        isDragging = false
        dragStart = nil
        flung = true
        // A finger held still before lifting throws nothing.
        if Date().timeIntervalSince(lastDragTime) > 0.08 { yawVelocity = 0 }
        // Project where the flick would carry the box, then snap to the nearest face.
        let projected = yaw - lean.x + yawVelocity * 0.22
        let face = ((projected - Self.restYaw) / .pi).rounded()
        targetYaw = Self.restYaw + face * .pi
    }

    /// Follows the phone's tilt (-1…1 each way): up to about 7° of turn and 3° of nod.
    func lean(toward tilt: SIMD2<Double>) {
        let next = SIMD2<Float>(Float(tilt.x) * 0.12, Float(tilt.y) * 0.05)
        // A hand's tremor is ignored: each change restarts the spring, and the scene redraws
        // every frame while it runs.
        guard abs(next.x - lean.x) > 0.006 || abs(next.y - lean.y) > 0.004 else { return }
        lean = next
        if !isDragging { isSettled = false }
    }

    /// Advances one frame. Returns true on the frame the box comes to rest after a fling.
    func step(_ dt: Float) -> Bool {
        // At rest nothing moves, so nothing is touched: the scene stops re-rendering
        // (a perpetual idle animation kept the page at ~40 % CPU).
        guard let pivot, !isDragging, !isSettled else { return false }
        let dt = min(dt, 1.0 / 30.0)
        let goalYaw = targetYaw + lean.x
        let goalPitch = Self.restPitch + lean.y

        // Slightly under-damped spring: settles with a small, physical overshoot.
        let stiffness: Float = 55
        let damping: Float = 2 * stiffness.squareRoot() * 0.72
        yawVelocity += (stiffness * (goalYaw - yaw) - damping * yawVelocity) * dt
        yaw += yawVelocity * dt
        pitchVelocity += (stiffness * (goalPitch - pitch) - damping * pitchVelocity) * dt
        pitch += pitchVelocity * dt

        pivot.orientation = Self.orientation(yaw: yaw, pitch: pitch)

        let resting = abs(goalYaw - yaw) < 0.004 && abs(yawVelocity) < 0.02
            && abs(goalPitch - pitch) < 0.004 && abs(pitchVelocity) < 0.02
        guard resting else { return false }
        isSettled = true
        defer { flung = false }
        return flung
    }
}

// MARK: - Case construction

@MainActor
enum GameBoxFactory {
    /// The insert is laid out at 2 points per millimetre and rendered at 4×: 8 pixels a millimetre.
    private static let printScale: CGFloat = 2

    /// Direct light on top of the studio's reflections: a key from the upper left, which gives the
    /// faces their shading, and a rim from behind that outlines the edges.
    static func studioLights() -> [Entity] {
        let key = DirectionalLight()
        key.light.intensity = 1800
        key.look(at: .zero, from: [-0.35, 0.45, 0.6], relativeTo: nil)

        let fill = DirectionalLight()
        fill.light.intensity = 350
        fill.look(at: .zero, from: [0.5, 0.05, 0.4], relativeTo: nil)

        let rim = DirectionalLight()
        rim.light.intensity = 1100
        rim.look(at: .zero, from: [0.2, 0.3, -0.6], relativeTo: nil)
        return [key, fill, rim]
    }

    /// The photographer's studio the film and plastic reflect (image-based light); nil if it
    /// can't be built, and the direct lights carry on alone.
    static func studio() async -> Entity? {
        guard let backdrop = render(StudioBackdrop(), scale: 1) else { return nil }
        do {
            let environment = try await EnvironmentResource(equirectangular: backdrop, withName: "studio")
            let studio = Entity()
            studio.components.set(ImageBasedLightComponent(source: .single(environment), intensityExponent: 0.4))
            return studio
        } catch {
            print("GameBox3D: no studio light: \(error)")
            return nil
        }
    }

    static func makeCase(for game: Game, studio: Entity?) async -> Entity? {
        var artURL = game.artURL
        if game.boxArtURL == nil, let found = try? await IGDBService.shared.boxArtURL(title: game.title, year: game.releaseYear) {
            artURL = found // a Discover/Search game: not in the library, so not looked up yet
        }
        let band = PlatformBand(platform: game.platform)
        var cover: UIImage?
        var art: SpineArt?
        if let artURL {
            cover = await ImageCache.shared.load(artURL)
            // The same cut as the shelf: the colour its spine is printed on, and whether the
            // cover is a box scan already carrying the header and the PEGI label.
            art = await ImageCache.shared.spineArt(for: artURL, kind: band.kind)
        }
        let tint = art?.ground ?? cover.flatMap { ImageCache.averageColor(of: $0)?.printed() } ?? UIColor(game.coverColor)
        var screenshots: [UIImage] = []
        for string in game.screenshotURLs.prefix(3) {
            if let url = URL(string: string), let image = await ImageCache.shared.load(url) {
                screenshots.append(image)
            }
        }

        let solid = CaseSolid(kind: band.kind)
        let sleeve = CaseSleeve(game: game, band: band, solid: solid, cover: cover, tint: tint,
                                scanned: (art?.banner ?? 0) > 0, screenshots: screenshots, mm: printScale)
        guard let sheet = render(sleeve, scale: 4),
              let seam = render(SeamStrip(), scale: 1),
              let shade = render(ContactShadow(solid: solid), scale: 1) else {
            return nil
        }

        do {
            let plastic = band.kind.plastic
            let wallMaterial = try await moulding(seam, plastic: plastic)
            let filmMaterial = try await film(over: sheet)
            let walls = ModelEntity(mesh: try CaseMesh.walls(solid), materials: [wallMaterial])
            let faces = ModelEntity(mesh: try CaseMesh.faces(solid), materials: [shell(plastic)])
            let insert = ModelEntity(mesh: try CaseMesh.insert(solid), materials: [filmMaterial])
            let shadow = try await contactShadow(shade, solid: solid)
            let root = Entity()
            for part in [walls, faces, insert] {
                if let studio {
                    part.components.set(ImageBasedLightReceiverComponent(imageBasedLight: studio))
                }
                root.addChild(part)
            }
            root.addChild(shadow)
            return root
        } catch {
            print("GameBox3D: failed to build the case: \(error)")
            return nil
        }
    }

    /// The insert under its clear film: printed card, with a glossy coat over it.
    private static func film(over sheet: CGImage) async throws -> PhysicallyBasedMaterial {
        let texture = try await TextureResource(image: sheet, options: .init(semantic: .color))
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(texture: .init(texture))
        material.roughness = 0.55
        material.metallic = 0.0
        material.clearcoat = 1.0
        material.clearcoatRoughness = 0.04
        material.faceCulling = .none
        return material
    }

    /// The faces' plastic, seen through the film above and below the insert and along the rim.
    private static func shell(_ plastic: CasePlastic) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(plastic.base))
        material.roughness = 0.35
        material.metallic = 0.0
        material.clearcoat = 1.0
        material.clearcoatRoughness = 0.05
        material.faceCulling = .none
        return material
    }

    /// The walls: satin moulded plastic, with the groove where the two halves close.
    private static func moulding(_ seam: CGImage, plastic: CasePlastic) async throws -> PhysicallyBasedMaterial {
        let texture = try await TextureResource(image: seam, options: .init(semantic: .color))
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(plastic.base), texture: .init(texture))
        material.roughness = 0.42
        material.metallic = 0.0
        material.clearcoat = 0.4
        material.clearcoatRoughness = 0.2
        material.faceCulling = .none
        return material
    }

    /// A soft shadow on the surface the case stands on, turning with it.
    private static func contactShadow(_ image: CGImage, solid: CaseSolid) async throws -> ModelEntity {
        let texture = try await TextureResource(image: image, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.blending = .transparent(opacity: 0.75)
        let reach = ContactShadow.spread * 2
        let plane = ModelEntity(mesh: .generatePlane(width: Float(solid.width + reach) / 1000, depth: Float(solid.depth + reach) / 1000),
                                materials: [material])
        plane.position.y = -Float(solid.height) / 2000 - 0.0004
        return plane
    }

    private static func render<V: View>(_ view: V, scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }
}

/// Across a wall, back to front: the plastic, and the groove where the two halves of the case
/// close (left half); plain plastic for the hinge, which is one piece (right half).
private struct SeamStrip: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.white
                Color(white: 0.7).frame(height: 1)
                Color(white: 0.3).frame(height: 2)
                Color(white: 1).frame(height: 1)
                Color.white
            }
            Color.white
        }
        .frame(width: 8, height: 64)
    }
}

/// The shadow under the case, seen from above: dark where it stands, fading out round it.
private struct ContactShadow: View {
    let solid: CaseSolid
    /// How far it reaches past the case, in millimetres.
    static let spread: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.black)
            .frame(width: solid.width, height: solid.depth)
            .blur(radius: 5)
            .frame(width: solid.width + Self.spread * 2, height: solid.depth + Self.spread * 2)
    }
}

// MARK: - Platforms

/// The platform's retail case and the header its sleeve carries (European editions).
struct PlatformBand {
    /// Which retail case it is: its size, its plastic and how its sleeve is printed (CaseModel.swift).
    enum Kind: String {
        case ps5, ps4, xboxSeries, xboxOne, switch1, switch2, pc, mac, mobile
    }

    let kind: Kind
    let label: String
    /// The platform's colour: the header printed on the sleeve, and the platform chip.
    let color: Color
    /// Text printed on the band.
    let ink: Color

    /// Platforms offered on the game page. RAWG's list is often incomplete (a PS5 release
    /// added after launch is missing), so the choice is never limited to it.
    static let choices = ["PlayStation 5", "PlayStation 4", "Xbox Series X|S", "Xbox One",
                          "Nintendo Switch", "Nintendo Switch 2", "PC", "Mac", "iOS", "Android"]

    init(platform: String) {
        let p = platform.lowercased()
        if p.contains("playstation") || p.hasPrefix("ps") {
            if p.contains("4") {
                // PS4: blue band, white logo.
                kind = .ps4; label = "PS4"; color = Color(hex: "003791"); ink = .white
            } else {
                // PS5: white band, black logo; the case is the PS4's blue plastic.
                kind = .ps5; label = "PS5"; color = Color(hex: "F4F5F7"); ink = Color(hex: "0B0B0C")
            }
        } else if p.contains("xbox") {
            // Series X|S sleeves dropped the green band in 2021; the chip stays Xbox green.
            kind = p.contains("series") ? .xboxSeries : .xboxOne
            label = "XBOX"; color = Color(hex: "107C10"); ink = .white
        } else if p.contains("switch") || p.contains("nintendo") {
            // Switch 1 cases are clear plastic (the red is the printed spine); Switch 2 cases are red.
            let second = p.contains("switch 2") || p.contains("switch2")
            kind = second ? .switch2 : .switch1
            label = second ? "SWITCH 2" : "SWITCH"; color = Color(hex: "E60012"); ink = .white
        } else if p.contains("ios") || p.contains("android") || p.contains("mobile") {
            kind = .mobile; label = "MOBILE"; color = Color(hex: "5C6167"); ink = .white
        } else if p.contains("mac") {
            kind = .mac; label = "MAC"; color = Color(hex: "8E8E93"); ink = .white
        } else {
            kind = .pc; label = "PC"; color = Color(hex: "121212"); ink = .white
        }
    }
}

extension UIColor {
    /// Relative luminance above the midpoint: dark text reads better on it.
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.6
    }

    /// WCAG relative luminance, from linearised channels: 0 for black, 1 for white.
    var relativeLuminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(b - amount, 0), alpha: a)
    }
}
