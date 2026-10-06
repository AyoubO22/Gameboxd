//
//  GameBox3DView.swift
//  Gameboxd
//
//  The game's case in real 3D (RealityKit): cover on the front, a spine in the
//  cover's colour, your notes on the back. Drag to turn it; let go and it keeps
//  its momentum, then settles on the front or the back.
//

import SwiftUI
import RealityKit

struct GameBox3DView: View {
    let game: Game
    var height: CGFloat = 360

    @State private var spin = SpinState()
    @State private var settleCount = 0

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 30
            camera.position = [0, 0, 0.5]
            content.add(camera)

            let pivot = Entity()
            pivot.orientation = SpinState.orientation(yaw: spin.yaw, pitch: spin.pitch)
            content.add(pivot)
            spin.pivot = pivot

            for light in GameBoxFactory.studioLights() {
                content.add(light)
            }

            if let model = await GameBoxFactory.makeBox(for: game) {
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
                .onChanged { spin.drag(by: $0.translation) }
                .onEnded { _ in spin.release() }
        )
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: settleCount)
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
    private var isDragging = false
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
        isDragging = false
        dragStart = nil
        // Project where the flick would carry the box, then snap to the nearest face.
        let projected = yaw + yawVelocity * 0.22
        let face = ((projected - Self.restYaw) / .pi).rounded()
        targetYaw = Self.restYaw + face * .pi
    }

    /// Advances one frame. Returns true on the frame the box comes to rest.
    func step(_ dt: Float) -> Bool {
        // At rest nothing moves, so nothing is touched: the scene stops re-rendering
        // (a perpetual idle animation kept the page at ~40 % CPU).
        guard let pivot, !isDragging, !isSettled else { return false }
        let dt = min(dt, 1.0 / 30.0)

        // Slightly under-damped spring: settles with a small, physical overshoot.
        let stiffness: Float = 55
        let damping: Float = 2 * stiffness.squareRoot() * 0.72
        yawVelocity += (stiffness * (targetYaw - yaw) - damping * yawVelocity) * dt
        yaw += yawVelocity * dt
        pitchVelocity += (stiffness * (Self.restPitch - pitch) - damping * pitchVelocity) * dt
        pitch += pitchVelocity * dt

        pivot.orientation = Self.orientation(yaw: yaw, pitch: pitch)

        let resting = abs(targetYaw - yaw) < 0.004 && abs(yawVelocity) < 0.02
        if resting && !isSettled {
            isSettled = true
            return true
        }
        return false
    }
}

// MARK: - Box construction

@MainActor
enum GameBoxFactory {
    // A DVD-style case, 13.5 × 19.1 × 1.4 cm: the same proportions as IGDB cover art,
    // so the front shows the whole cover, uncropped.
    private static let width: Float = 0.135
    private static let height: Float = 0.191
    private static let depth: Float = 0.014

    static func studioLights() -> [Entity] {
        let key = DirectionalLight()
        key.light.intensity = 2600
        key.look(at: .zero, from: [-0.35, 0.45, 0.6], relativeTo: nil)

        let fill = DirectionalLight()
        fill.light.intensity = 700
        fill.look(at: .zero, from: [0.5, 0.05, 0.4], relativeTo: nil)

        let rim = DirectionalLight()
        rim.light.intensity = 1400
        rim.look(at: .zero, from: [0.2, 0.3, -0.6], relativeTo: nil)
        return [key, fill, rim]
    }

    static func makeBox(for game: Game) async -> ModelEntity? {
        var artURL = game.artURL
        if game.boxArtURL == nil, let found = try? await IGDBService.shared.boxArtURL(title: game.title, year: game.releaseYear) {
            artURL = found // a Discover/Search game: not in the library, so not looked up yet
        }
        var cover: UIImage?
        if let artURL {
            cover = await ImageCache.shared.load(artURL)
        }
        let spineColor = cover.flatMap { ImageCache.averageColor(of: $0)?.printed() } ?? UIColor(game.coverColor)
        let platform = PlatformBand(platform: game.platform)
        var screenshots: [UIImage] = []
        for string in game.screenshotURLs.prefix(2) {
            if let url = URL(string: string), let image = await ImageCache.shared.load(url) {
                screenshots.append(image)
            }
        }

        guard let front = render(BoxFront(cover: cover, fallback: game.coverColor, band: platform)),
              let back = render(BoxBack(game: game, cover: cover, screenshots: screenshots,
                                        band: platform, background: Color(spineColor.darker(0.42)))),
              let spine = render(SpineFace(title: game.title, band: platform, cover: cover, tint: spineColor,
                                           pegi: game.pegi, width: 28, height: faceSize.height)),
              let edge = render(Rectangle().fill(Color(spineColor.darker(0.25))).frame(width: 60, height: 60)) else {
            return nil
        }

        do {
            let frontMat = try await plastic(front)
            let backMat = try await plastic(back)
            let spineMat = try await plastic(spine)
            let edgeMat = try await plastic(edge)
            let mesh = MeshResource.generateBox(width: width, height: height, depth: depth, cornerRadius: 0.0025, splitFaces: true)
            // splitFaces order: front, top, back, bottom, right, left.
            // The left edge is the spine: it faces the camera at the resting angle.
            return ModelEntity(mesh: mesh, materials: [frontMat, edgeMat, backMat, edgeMat, edgeMat, spineMat])
        } catch {
            print("GameBox3D: failed to build materials: \(error)")
            return nil
        }
    }

    /// Glossy plastic sleeve: a clear coat over a printed, slightly rough base.
    private static func plastic(_ image: CGImage) async throws -> PhysicallyBasedMaterial {
        let texture = try await TextureResource(image: image, options: .init(semantic: .color))
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(texture: .init(texture))
        material.roughness = 0.45
        material.metallic = 0.0
        material.clearcoat = 1.0
        material.clearcoatRoughness = 0.06
        return material
    }

    private static func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.cgImage
    }
}

// MARK: - Printed faces (rendered to textures)

/// The coloured band console cases carry on top.
struct PlatformBand {
    let label: String
    let color: Color

    /// Platforms offered on the game page. RAWG's list is often incomplete (a PS5 release
    /// added after launch is missing), so the choice is never limited to it.
    static let choices = ["PlayStation 5", "PlayStation 4", "Xbox Series X|S", "Xbox One",
                          "Nintendo Switch", "PC", "Mac", "iOS", "Android"]

    init(platform: String) {
        let p = platform.lowercased()
        if p.contains("playstation") || p.hasPrefix("ps") {
            label = p.contains("4") ? "PS4" : "PS5"
            color = Color(hex: "1F4FD8")
        } else if p.contains("xbox") {
            label = "XBOX"
            color = Color(hex: "107C10")
        } else if p.contains("switch") || p.contains("nintendo") {
            label = "SWITCH"
            color = Color(hex: "E60012")
        } else if p.contains("ios") || p.contains("android") || p.contains("mobile") {
            label = "MOBILE"
            color = Color(hex: "5C6167")
        } else if p.contains("mac") {
            label = "MAC"
            color = Color(hex: "8E8E93")
        } else {
            label = "PC"
            color = Color(hex: "3A3A3A")
        }
    }
}

// Faces are drawn at 2 px per millimetre (×3 when rendered): 270 × 382 for the front and back.
let faceSize = CGSize(width: 270, height: 382)

private struct BoxFront: View {
    let cover: UIImage?
    let fallback: Color
    let band: PlatformBand

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    fallback
                }
            }
            .frame(width: faceSize.width, height: faceSize.height)
            .clipped()

            // Printed over the top of the art, as on a real case.
            Text(band.label)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .frame(height: 22)
                .background(band.color)
        }
        .frame(width: faceSize.width, height: faceSize.height)
    }
}

/// The back of the case, as a publisher prints it: screenshots and a blurb about the game.
private struct BoxBack: View {
    let game: Game
    let cover: UIImage?
    let screenshots: [UIImage]
    let band: PlatformBand
    let background: Color

    /// As much of the description as the back holds (~520 characters), cut on the last
    /// sentence end before the limit so it never stops mid-word.
    private var blurb: String? {
        guard let text = game.description?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let joined = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard joined.count > 520 else { return joined }
        let cut = joined.prefix(520)
        if let end = cut.lastIndex(where: { ".!?".contains($0) }) { return String(cut[...end]) }
        return cut + "…"
    }

    private var credits: String {
        [game.developer, game.releaseYear]
            .filter { !$0.isEmpty && $0 != "Unknown" && $0 != "—" && $0 != "TBA" }
            .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(band.label)
                .font(.system(size: 13, weight: .heavy).width(.condensed))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
                .frame(height: 22)
                .background(band.color)

            VStack(alignment: .leading, spacing: 9) {
                Text(game.title)
                    .font(.system(size: 18, weight: .black).width(.condensed))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                // Screenshots, or the cover art when RAWG has none.
                HStack(spacing: 6) {
                    let pictures = screenshots.isEmpty ? [cover].compactMap { $0 } : screenshots
                    ForEach(pictures.indices, id: \.self) { index in
                        Image(uiImage: pictures[index]).resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                if let blurb {
                    Text(blurb)
                        .font(.system(size: 9.5))
                        .lineSpacing(1.5)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(18)
                }

                Spacer(minLength: 0)

                HStack(alignment: .lastTextBaseline) {
                    Text(credits)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Text("Gameboxd")
                        .font(.system(size: 11, weight: .heavy).width(.condensed))
                        .foregroundStyle(DS.Colors.warning)
                }
            }
            .padding(12)
        }
        .frame(width: faceSize.width, height: faceSize.height, alignment: .topLeading)
        .background(background)
    }
}

extension UIColor {
    /// Relative luminance above the midpoint: dark text reads better on it.
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.6
    }

    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(b - amount, 0), alpha: a)
    }
}
