//
//  CasePrint.swift
//  Gameboxd
//
//  The printed insert of a European retail case: platform headers, spine lettering,
//  publisher marks and the PEGI label. Flat print only (no light): the shelf and the 3D box
//  light it themselves, and ImageRenderer draws it for the box. No logo artwork ships:
//  marks are built from type and system shapes.
//

import SwiftUI
import UIKit

// MARK: - Card grain

/// Printed card and painted panels aren't flat colour: one tile of fine grey grain, made once
/// (not a Canvas per case) and laid over every insert and wall.
enum PrintGrain {
    static let tile: Image = {
        let side = 128
        var state: UInt64 = 0x2545_F491_4F6C_DD1D
        var pixels = [UInt8](repeating: 128, count: side * side)
        for index in pixels.indices {
            // xorshift64*: a fixed sequence, so the grain is the same on every launch.
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            pixels[index] = UInt8(truncatingIfNeeded: (state &* 0x2545_F491_4F6C_DD1D) >> 56)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return Image(uiImage: UIImage()) }
        return Image(decorative: image, scale: 3) // one grain per device pixel on @3x
    }()
}

// MARK: - PEGI label

/// The PEGI age label on European cases: portrait (0.82 wide for 1 tall, as the official
/// artwork), the age in white on its colour, and a white strip with www.pegi.info at the foot,
/// inset in the colour. Fixed size: it's printed, so it doesn't follow Dynamic Type.
struct PEGIBadge: View {
    let age: Int
    /// Width of the label; its height follows.
    let size: CGFloat
    /// A white hairline round it, as printers add on a dark ground (spines).
    var keyline = false

    static func height(for size: CGFloat) -> CGFloat { (size / 0.82).rounded() }

    private var color: Color {
        switch age {
        case ..<8: return Color(hex: "7AB829")    // PEGI 3, 7
        case ..<17: return Color(hex: "F7A600")   // PEGI 12, 16
        default: return Color(hex: "E3001B")      // PEGI 18
        }
    }

    var body: some View {
        let height = Self.height(for: size)
        let line: CGFloat = keyline ? 0.5 : 0
        VStack(spacing: 0) {
            Text("\(age)")
                .font(.system(size: size * 0.78, weight: .heavy).width(.condensed))
                .tracking(-size * 0.02)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: size, height: size)
            Text(verbatim: "www.pegi.info")
                .font(.system(size: max(1, size * 0.1), weight: .semibold))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(width: size * 0.88, height: max(1, height - size - size * 0.06))
                .background(Color.white)
            Spacer(minLength: 0)
        }
        .frame(width: size, height: height)
        .background(color, in: RoundedRectangle(cornerRadius: size * 0.04, style: .continuous))
        .padding(line)
        .background(keyline ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: size * 0.04 + line, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("PEGI \(age)")
    }
}

// MARK: - Platform marks

/// The Nintendo Switch icon, two Joy-Con side by side: the left outlined with a dot near the
/// top, the right solid with a hole lower down, in `cutout` (the colour it's printed on).
struct SwitchMark: View {
    /// Width; the icon is a touch taller than wide.
    let size: CGFloat
    let cutout: Color

    var body: some View {
        let height = (size * 1.04).rounded()
        let line = max(0.5, size * 0.085)
        let dot = size * 0.17
        let radius = size * 0.22
        HStack(spacing: size * 0.1) {
            UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius, style: .continuous)
                .stroke(Color.white, lineWidth: line)
                .padding(line / 2)
                .overlay(alignment: .top) {
                    Circle().fill(Color.white).frame(width: dot, height: dot).padding(.top, height * 0.2)
                }
            UnevenRoundedRectangle(bottomTrailingRadius: radius, topTrailingRadius: radius, style: .continuous)
                .fill(Color.white)
                .overlay(alignment: .top) {
                    Circle().fill(cutout).frame(width: dot, height: dot).padding(.top, height * 0.52)
                }
        }
        .frame(width: size, height: height)
        .accessibilityHidden(true)
    }
}

/// The Xbox sphere: a white ball crossed by a curved X in `cut`, the colour it's printed on.
struct XboxSphere: View {
    let size: CGFloat
    let cut: Color
    /// Printed on art (Series fronts), where `cut` isn't the ground: keep the X inside the ball.
    var clipsToBall = false

    var body: some View {
        let ball = Circle()
            .fill(Color.white)
            .overlay { cross }
            .frame(width: size, height: size)
        if clipsToBall {
            ball.clipShape(Circle())
        } else {
            ball
        }
    }

    private var cross: some View {
        Path { path in
            path.move(to: CGPoint(x: size * 0.2, y: size * 0.1))
            path.addQuadCurve(to: CGPoint(x: size * 0.8, y: size * 0.9), control: CGPoint(x: size * 0.64, y: size * 0.42))
            path.move(to: CGPoint(x: size * 0.8, y: size * 0.1))
            path.addQuadCurve(to: CGPoint(x: size * 0.2, y: size * 0.9), control: CGPoint(x: size * 0.36, y: size * 0.42))
        }
        .stroke(cut, style: StrokeStyle(lineWidth: size * 0.15, lineCap: .butt))
    }
}

// MARK: - Publisher mark (spines only)

/// The publisher's mark near the foot of a spine. Logos can't ship, so each is set in type
/// the way it reads at a glance. Keyed on the developer (Game has no publisher field).
struct StudioMark: View {
    enum Style: Equatable { case nintendo, playstationStudios, xboxGameStudios, name(String) }

    let style: Style
    let ink: Color
    /// The spine's width.
    let width: CGFloat

    static func style(studio: String, kind: PlatformBand.Kind) -> Style? {
        let name = studio.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != "Unknown", name != "—" else { return nil }
        let lower = name.lowercased()
        if lower.contains("nintendo") || (kind.isSwitch && nintendoTeams.contains(where: { lower.contains($0) })) { return .nintendo }
        if sonyTeams.contains(where: { lower.contains($0) }) { return .playstationStudios }
        if lower == "rare" || xboxTeams.contains(where: { lower.contains($0) }) { return .xboxGameStudios }
        var short = name
        for suffix in [" Studios", " Studio", " Games", " Entertainment", " Productions", " Interactive", " Software", ", Inc.", " Inc.", " Ltd."] where short.hasSuffix(suffix) {
            short = String(short.dropLast(suffix.count))
        }
        if short.count > 14, let first = short.split(separator: " ").first { short = String(first) }
        return .name(short.uppercased())
    }

    private static let sonyTeams = ["santa monica", "naughty dog", "insomniac", "sucker punch", "guerrilla", "team asobi",
                                    "polyphony", "bluepoint", "media molecule", "housemarque", "bend studio", "firesprite",
                                    "sony interactive", "playstation studios"]
    private static let xboxTeams = ["343 industries", "halo studios", "playground games", "turn 10", "mojang", "the coalition",
                                    "obsidian", "inxile", "ninja theory", "compulsion", "double fine", "bethesda",
                                    "id software", "arkane", "machinegames", "xbox game studios"]
    private static let nintendoTeams = ["retro studios", "intelligent systems", "hal laboratory", "monolith soft",
                                        "mercurysteam", "next level games", "good-feel"]

    var body: some View {
        switch style {
        case .nintendo:
            nintendo
        case .playstationStudios:
            stacked("PlayStation", "STUDIOS", topSize: 0.2, bottomSize: 0.12)
        case .xboxGameStudios:
            stacked("XBOX", "GAME STUDIOS", topSize: 0.22, bottomSize: 0.1)
        case .name(let name):
            // One Text per line: given two lines, SwiftUI splits a long word ("ROCKS/TAR")
            // rather than shrink it. A single word shrinks to fit instead.
            VStack(spacing: 0) {
                ForEach(Array(Self.lines(name).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                }
            }
            .font(.system(size: width * 0.26, weight: .heavy).width(.condensed))
            .foregroundStyle(ink.opacity(0.9))
            .frame(width: width * 0.82)
        }
    }

    /// One or two lines, broken between words only, where they come out most even
    /// ("CD PROJEKT" over "RED").
    private static func lines(_ name: String) -> [String] {
        let words = name.split(separator: " ").map(String.init)
        guard words.count > 2 else { return words }
        let breaks = (1..<words.count).map { index in
            [words[..<index].joined(separator: " "), words[index...].joined(separator: " ")]
        }
        return breaks.min { max($0[0].count, $0[1].count) < max($1[0].count, $1[1].count) } ?? [name]
    }

    /// Nintendo's racetrack: the name in a stadium outline, run along the spine.
    private var nintendo: some View {
        Text(verbatim: "Nintendo")
            .font(.system(size: width * 0.3, weight: .heavy))
            .foregroundStyle(ink)
            .lineLimit(1)
            .padding(.horizontal, width * 0.1)
            .padding(.vertical, width * 0.04)
            .overlay { Capsule().stroke(ink, lineWidth: max(0.5, width * 0.035)) }
            .fixedSize()
            .rotationEffect(.degrees(Shelf.titleAngle))
    }

    private func stacked(_ top: String, _ bottom: String, topSize: CGFloat, bottomSize: CGFloat) -> some View {
        VStack(spacing: width * 0.02) {
            Text(top).font(.system(size: width * topSize, weight: .semibold))
            Text(bottom)
                .font(.system(size: width * bottomSize, weight: .semibold).width(.expanded))
                .tracking(width * 0.015)
        }
        .foregroundStyle(ink.opacity(0.92))
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .frame(width: width * 0.82)
    }
}

// MARK: - Spine lettering

/// The type a spine's title is set in. Publishers each use their own, so a stable pick per
/// title keeps the shelf from looking typeset by one hand; PAL Nintendo spines share one
/// condensed sans (the template's Roboto Condensed Bold; SF Condensed Bold stands in).
enum SpineFont: Equatable {
    case bigShoulders, compressed, futura, helvetica, nintendo

    static func pick(seed: UInt64, kind: PlatformBand.Kind) -> SpineFont {
        if kind.isSwitch { return .nintendo }
        switch (seed >> 8) % 4 {
        case 0: return .bigShoulders
        case 1: return .compressed
        case 2: return .futura
        default: return .helvetica
        }
    }

    /// Point size against the spine's width.
    func size(for width: CGFloat) -> CGFloat {
        switch self {
        // Big Shoulders' capitals stand 0.80 em against about 0.71 for the others: the same
        // cap height takes a smaller size. It still gains along the spine, being narrower.
        case .bigShoulders: return width * 0.47
        case .nintendo: return width * 0.5
        default: return width * 0.52
        }
    }

    /// Letter spacing, in ems.
    var tracking: CGFloat { self == .nintendo ? 0 : 0.02 }

    func cased(_ text: String) -> String { self == .nintendo ? text : text.uppercased() }

    func font(size: CGFloat) -> Font {
        switch self {
        case .bigShoulders: return DS.Typography.spinePrint(size)
        case .compressed: return .system(size: size, weight: .black).width(.compressed)
        case .futura: return .custom("Futura-CondensedExtraBold", fixedSize: size)
        case .helvetica: return .custom("HelveticaNeue-CondensedBlack", fixedSize: size)
        case .nintendo: return .system(size: size, weight: .bold).width(.condensed)
        }
    }

    /// How a title is set down the spine: one line, or a main line with a smaller one.
    struct Lines {
        let main: String
        let small: String?
        /// The small line reads first (a brand over the name), else after the main one.
        let smallLeads: Bool
    }

    /// Long titles are set as their logos are. A brand's possessive is always small, over the
    /// name ("MARVEL'S" over "SPIDER-MAN 2"). A franchise and its subtitle share one line when it
    /// `fits`; if not, the franchise stays big with the subtitle small under it ("UNCHARTED 4"
    /// over "A THIEF'S END", "THE LEGEND OF ZELDA" over "TEARS OF THE KINGDOM").
    static func lines(_ title: String, fits: Bool) -> Lines {
        let single = Lines(main: title, small: nil, smallLeads: false)
        guard title.count > 16 else { return single }
        for prefix in ["Marvel's ", "Tom Clancy's ", "Sid Meier's ", "Tony Hawk's ", "LEGO ", "Disney "] where title.hasPrefix(prefix) {
            return Lines(main: String(title.dropFirst(prefix.count)), small: prefix.trimmingCharacters(in: .whitespaces), smallLeads: true)
        }
        guard !fits else { return single }
        for separator in [": ", " - ", " – "] {
            if let range = title.range(of: separator) {
                let franchise = String(title[..<range.lowerBound])
                let subtitle = String(title[range.upperBound...])
                if franchise.count >= 3, subtitle.count >= 3 { return Lines(main: franchise, small: subtitle, smallLeads: false) }
            }
        }
        return single
    }
}

/// The title down a spine, rotated by Shelf.titleAngle (top to bottom).
struct SpineTitle: View {
    let title: String
    let face: SpineFont
    let ink: Color
    let width: CGFloat
    /// Room along the spine.
    let length: CGFloat

    var body: some View {
        let size = face.size(for: width)
        let room = max(0, length - width * 0.4)
        // Condensed capitals run about half an em: past that, one line would have to shrink.
        let lines = SpineFont.lines(title, fits: CGFloat(title.count) * size * 0.5 <= room)
        let smallSize = min(size * 0.82, max(size * 0.6, 4.5)) // never a smudge
        Group {
            if let small = lines.small {
                // Rotated, the VStack's top reads first: the second line lands under the first.
                VStack(spacing: -size * 0.1) {
                    if lines.smallLeads {
                        line(small, size: smallSize, extraTracking: 0.08)
                    }
                    line(lines.main, size: size * 0.82, extraTracking: 0)
                    if !lines.smallLeads {
                        line(small, size: smallSize, extraTracking: 0.08)
                    }
                }
            } else {
                line(title, size: size, extraTracking: 0)
            }
        }
        .frame(width: room)
        .rotationEffect(.degrees(Shelf.titleAngle))
        .frame(width: width, height: length)
    }

    private func line(_ text: String, size: CGFloat, extraTracking: CGFloat) -> some View {
        Text(face.cased(text))
            .font(face.font(size: size))
            .tracking(size * (face.tracking + extraTracking))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}

// MARK: - Headers

/// The platform's zone at the top of a spine, as each platform holder prints it.
struct SpineHeader: View {
    let band: PlatformBand
    let width: CGFloat
    let height: CGFloat

    static func height(for kind: PlatformBand.Kind, width: CGFloat, printHeight: CGFloat) -> CGFloat {
        switch kind {
        case .ps5, .ps4: return (printHeight * 0.135).rounded()
        case .xboxOne: return (printHeight * 0.13).rounded()
        case .switch2: return (printHeight * 0.14).rounded()
        case .pc, .mac, .mobile: return (printHeight * 0.1).rounded()
        case .xboxSeries: return (width * 1.3).rounded()
        case .switch1: return (width * 1.25).rounded()
        }
    }

    var body: some View {
        switch band.kind {
        case .ps5:
            logotype("PS5", ink: Color(hex: "0B0B0C"))
                .frame(width: width, height: height)
                .background(Color(hex: "F4F5F7"))
        case .ps4:
            logotype("PS4", ink: .white)
                .frame(width: width, height: height)
                .background(LinearGradient(colors: [Color(hex: "0A63C0"), Color(hex: "003791")], startPoint: .top, endPoint: .bottom))
        case .xboxOne:
            XboxSphere(size: (width * 0.62).rounded(), cut: Color(hex: "107C10"))
                .frame(width: width, height: height)
                .background(Color(hex: "107C10"))
        case .xboxSeries:
            // No green since 2021: a dark zone with the sphere (layout unverified).
            XboxSphere(size: (width * 0.62).rounded(), cut: Color(hex: "121314"))
                .frame(width: width, height: height)
                .background(Color(hex: "121314"))
        case .switch1:
            // No band: the whole spine is Nintendo red, the icon at its top.
            SwitchMark(size: (width * 0.56).rounded(), cutout: Color(hex: "E60012"))
                .frame(width: width, height: height)
        case .switch2:
            VStack(spacing: width * 0.12) {
                SwitchMark(size: (width * 0.56).rounded(), cutout: Color(hex: "E60012"))
                Text(verbatim: "2")
                    .font(.system(size: width * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: width, height: height)
            .background(Color(hex: "E60012"))
        case .pc, .mac, .mobile:
            logotype(band.label, ink: .white)
                .frame(width: width, height: height)
                .background(band.kind == .mobile ? Color(hex: "5C6167") : Color(hex: "111111"))
        }
    }

    /// Platform logotypes are wide and geometric, set across the spine.
    private func logotype(_ text: String, ink: Color) -> some View {
        Text(text)
            .font(.system(size: width * 0.3, weight: .semibold).width(.expanded))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: width * 0.74)
    }
}

/// The platform's header across the top of a case front, as European sleeves print it.
struct CaseHeader: View {
    let band: PlatformBand
    /// Points per millimetre of the case it's printed on.
    let mm: CGFloat
    /// Small cases get the band's colour without lettering, which would only be a smudge.
    var showsMarks = true
    /// The developer: first-party PS4 games print "ONLY ON PLAYSTATION" on the right.
    var studio = ""

    /// The header's height, for things placed below it.
    static func height(for kind: PlatformBand.Kind, mm: CGFloat) -> CGFloat {
        let millimetres: CGFloat
        switch kind {
        case .ps5, .xboxOne, .xboxSeries: millimetres = 12
        case .ps4: millimetres = 11
        case .switch1: millimetres = 9.5
        case .switch2: millimetres = 22
        case .pc, .mac, .mobile: millimetres = 10
        }
        return (millimetres * mm).rounded()
    }

    var body: some View {
        let height = Self.height(for: band.kind, mm: mm)
        switch band.kind {
        case .ps5:
            strip(height: height, inset: 5) { logotype("PS5", size: 7.2, ink: Color(hex: "0B0B0C")) }
                .background(Color(hex: "F4F5F7"))
        case .ps4:
            strip(height: height, inset: 5) {
                logotype("PS4", size: 6.8, ink: .white)
                Spacer(minLength: 0)
                if StudioMark.style(studio: studio, kind: band.kind) == .playstationStudios {
                    Text(verbatim: "ONLY ON PLAYSTATION")
                        .font(.system(size: 2.6 * mm, weight: .semibold).width(.expanded))
                        .tracking(0.3 * mm)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .background(LinearGradient(colors: [Color(hex: "1F7BD8"), Color(hex: "0A63C0"), Color(hex: "003791")],
                                       startPoint: .top, endPoint: .bottom))
        case .xboxOne:
            strip(height: height, inset: 4.5) {
                XboxSphere(size: (7 * mm).rounded(), cut: Color(hex: "107C10"))
                Text(verbatim: "XBOX ONE")
                    .font(.system(size: 4.6 * mm, weight: .semibold).width(.expanded))
                    .tracking(0.5 * mm)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .background(Color(hex: "107C10"))
        case .xboxSeries:
            // Since 2021: no band. The sphere and a white ribbon sit on the art.
            HStack(spacing: 2 * mm) {
                XboxSphere(size: (8 * mm).rounded(), cut: Color(hex: "0B0B0C"), clipsToBall: true)
                if showsMarks {
                    Text(verbatim: "XBOX SERIES X")
                        .font(.system(size: 3.2 * mm, weight: .bold).width(.expanded))
                        .tracking(0.2 * mm)
                        .foregroundStyle(Color(hex: "0B0B0C"))
                        .lineLimit(1)
                        .padding(.horizontal, 2 * mm)
                        .frame(height: 5.5 * mm)
                        .background(Color.white)
                }
            }
            .padding(.leading, 4 * mm)
            .padding(.top, 4 * mm)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .switch1:
            strip(height: height, inset: 4) {
                SwitchMark(size: (5.4 * mm).rounded(), cutout: Color(hex: "E60012"))
                Text(verbatim: "NINTENDO SWITCH")
                    .font(.system(size: 3.6 * mm, weight: .bold, design: .rounded))
                    .tracking(0.15 * mm)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .background(Color(hex: "E60012"))
        case .switch2:
            HStack(spacing: 1.5 * mm) {
                if showsMarks {
                    SwitchMark(size: (8 * mm).rounded(), cutout: Color(hex: "E60012"))
                    Text(verbatim: "NINTENDO SWITCH 2")
                        .font(.system(size: 4.4 * mm, weight: .bold, design: .rounded))
                        .tracking(0.2 * mm)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color(hex: "E60012"))
        case .pc, .mac, .mobile:
            strip(height: height, inset: 5) { logotype(band.label, size: 5.6, ink: .white) }
                .background(band.kind == .mobile ? Color(hex: "5C6167") : Color(hex: "111111"))
        }
    }

    private func strip<Content: View>(height: CGFloat, inset: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 2 * mm) {
            if showsMarks { content() }
        }
        .padding(.horizontal, inset * mm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
    }

    private func logotype(_ text: String, size: CGFloat, ink: Color) -> some View {
        Text(text)
            .font(.system(size: size * mm, weight: .semibold).width(.expanded))
            .tracking(0.3 * mm)
            .foregroundStyle(ink)
            .lineLimit(1)
    }
}
