//
//  CaseModel.swift
//  Gameboxd
//
//  The real retail cases the shelf draws (European editions): their sizes in millimetres,
//  their plastic, and where the room's lamp sits relative to a case on screen.
//

import SwiftUI

/// A retail case's real size, in millimetres.
struct CaseSpec {
    let height: CGFloat
    let width: CGFloat
    /// Thickness: the spine's width.
    let spine: CGFloat
    /// Bare plastic above and below the printed insert (a 160 mm insert in a 170 mm case).
    let cap: CGFloat
    /// Radius of the moulded corners.
    let corner: CGFloat
}

/// The case's own plastic where no insert covers it. Translucent plastic glows where light
/// pipes through it from above and goes deep in shade at the foot.
struct CasePlastic {
    let lit: Color
    let base: Color
    let shade: Color
}

extension PlatformBand.Kind {
    var isSwitch: Bool { self == .switch1 || self == .switch2 }
    /// PC and Mac games come in DVD cases, 20 mm taller than console cases.
    var isDVD: Bool { self == .pc || self == .mac }

    var spec: CaseSpec {
        switch self {
        case .ps5: return CaseSpec(height: 170, width: 135, spine: 14.5, cap: 5, corner: 4)
        case .ps4: return CaseSpec(height: 170, width: 135, spine: 14, cap: 5, corner: 4)
        case .xboxSeries, .xboxOne, .mobile: return CaseSpec(height: 170, width: 135, spine: 12, cap: 5, corner: 4)
        case .switch1, .switch2: return CaseSpec(height: 170, width: 105, spine: 10, cap: 4.5, corner: 3.5)
        case .pc, .mac: return CaseSpec(height: 190, width: 135, spine: 14, cap: 3.5, corner: 5)
        }
    }

    var plastic: CasePlastic {
        switch self {
        case .ps5, .ps4:
            return CasePlastic(lit: Color(hex: "3A78D8"), base: Color(hex: "1E4FA3"), shade: Color(hex: "0F2A63"))
        case .xboxSeries, .xboxOne:
            return CasePlastic(lit: Color(hex: "45B24F"), base: Color(hex: "1F8A34"), shade: Color(hex: "0B4A17"))
        case .switch1:
            // Clear and frosted: over the dark wall it reads pale grey.
            return CasePlastic(lit: Color(hex: "B8BEC6"), base: Color(hex: "8C939C"), shade: Color(hex: "5A6068"))
        case .switch2:
            return CasePlastic(lit: Color(hex: "D21A35"), base: Color(hex: "A8102A"), shade: Color(hex: "6E0A18"))
        case .pc, .mac:
            return CasePlastic(lit: Color(hex: "2A2A2C"), base: Color(hex: "161618"), shade: Color(hex: "0A0A0B"))
        case .mobile:
            return CasePlastic(lit: Color(hex: "4A4F56"), base: Color(hex: "2E3238"), shade: Color(hex: "1A1D21"))
        }
    }

    /// How the insert sits on this case, for cutting a cover's art to it. `banner` is the sRGB
    /// of the header the platform prints across the front, to recognise box scans carrying it.
    var sleeve: SleeveGeometry {
        switch self {
        case .ps5:
            return SleeveGeometry(frontAspect: 160 / 128, spineFraction: 14.5 / 128, banner: SIMD3<Float>(0.957, 0.961, 0.969))
        case .ps4:
            return SleeveGeometry(frontAspect: 160 / 128, spineFraction: 14 / 128, banner: SIMD3<Float>(0.02, 0.30, 0.66))
        case .xboxOne:
            return SleeveGeometry(frontAspect: 160 / 128, spineFraction: 12 / 128, banner: SIMD3<Float>(0.063, 0.486, 0.063))
        case .xboxSeries, .mobile:
            return SleeveGeometry(frontAspect: 160 / 128, spineFraction: 12 / 128, banner: nil)
        case .switch1, .switch2:
            return SleeveGeometry(frontAspect: 161 / 99.5, spineFraction: 10 / 99.5, banner: SIMD3<Float>(0.902, 0, 0.071))
        case .pc, .mac:
            return SleeveGeometry(frontAspect: 183 / 129.5, spineFraction: 14 / 129.5, banner: nil)
        }
    }
}

extension PlatformBand {
    /// Spine width on the shelf: drawn 1.2× thicker than life so a title stays readable.
    var spineWidth: CGFloat { (kind.spec.spine * Shelf.mm * Shelf.spineBoost).rounded() }
    var caseHeight: CGFloat { (kind.spec.height * Shelf.mm).rounded() }
    /// The case's plastic showing above and below the insert on a spine.
    var capHeight: CGFloat { (kind.spec.cap * Shelf.mm).rounded() }
    /// The rimwall's quarter-spherical corners seen end on, kept inside the plastic cap
    /// (a larger radius would let the print's square corner poke out of the silhouette).
    var spineCorner: CGFloat { min(3.5 * Shelf.mm, spineWidth * 0.3, capHeight) }
}

/// A case seen from the front, in points: its real measurements (mm) times `mm`.
struct CaseFront {
    let mm: CGFloat
    let size: CGSize
    /// Bare plastic above and below the insert.
    let cap: CGFloat
    /// The insert rolling round the spine, on the left: no bare plastic there.
    let fold: CGFloat
    /// Bare plastic along the opening edge, on the right.
    let rim: CGFloat
    let corner: CGFloat

    init(kind: PlatformBand.Kind, mm: CGFloat) {
        let spec = kind.spec
        let foldMillimetres: CGFloat = kind.isSwitch || kind.isDVD ? 2.5 : 3
        let rimMillimetres: CGFloat = kind.isSwitch ? 3 : 3.5
        self.mm = mm
        size = CGSize(width: (spec.width * mm).rounded(), height: (spec.height * mm).rounded())
        cap = max(1, (spec.cap * mm).rounded())
        fold = max(1, (foldMillimetres * mm).rounded())
        rim = max(1, (rimMillimetres * mm).rounded())
        corner = max(1.5, spec.corner * mm)
    }

    /// The printed insert: from the hinge to the opening-edge rim, between the caps.
    var insert: CGSize { CGSize(width: size.width - rim, height: size.height - cap * 2) }
    /// The flat front panel, where the cover art is.
    var panel: CGSize { CGSize(width: insert.width - fold, height: insert.height) }
}

/// Where a case sits relative to the room's lamp. Called inside `visualEffect`, which runs off
/// the main actor, so it only does arithmetic on what it's given.
nonisolated enum CaseOptics {
    /// −1 at the left edge of the visible shelf, 1 at the right; 0 outside a horizontal scroll
    /// view. Uses the scroll view's visible bounds in the view's own space, so content offsets
    /// can't skew it.
    static func across(_ proxy: GeometryProxy) -> CGFloat {
        guard let visible = proxy.bounds(of: .scrollView(axis: .horizontal)), visible.width > 0 else { return 0 }
        let value = (proxy.size.width / 2 - visible.minX) / visible.width * 2 - 1
        return min(1.5, max(-1.5, value))
    }

    /// The lamp's broad reflection on a spine's film: strongest a little left of the middle,
    /// under the lamp, a faint glaze elsewhere.
    static func sheen(_ across: CGFloat) -> Double {
        let distance = Double((across + 0.55) / 0.7)
        return 0.015 + 0.085 * exp(-distance * distance)
    }

    /// How far the lamp's reflection sits from the middle of a case front, in points. It is
    /// fixed in the room a quarter of the way across the screen, so the case slides under it.
    static func lampOffset(_ proxy: GeometryProxy, tilt: CGFloat) -> CGFloat {
        let limit = proxy.size.width * 0.5
        guard let visible = proxy.bounds(of: .scrollView(axis: .horizontal)), visible.width > 0 else {
            return proxy.size.width * (-0.1 + tilt * 0.15) // not in a scroll view: the vitrine
        }
        let lamp = visible.width * (0.225 + tilt * 0.3)
        let centre = proxy.size.width / 2 - visible.minX
        return min(limit, max(-limit, lamp - centre))
    }
}
