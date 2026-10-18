//
//  CaseMesh.swift
//  Gameboxd
//
//  The game page's case as a solid: a moulded plastic shell with rounded edges, and the printed
//  insert wrapped round it from the back, over the spine, to the front, as on a real retail case.
//  Built round its centre, in metres: the front faces +z, the spine -x.
//

import RealityKit
import UIKit

/// A retail case's shape, in millimetres, as the 3D box builds it.
struct CaseSolid {
    let width: CGFloat
    let height: CGFloat
    /// Thickness: the spine.
    let depth: CGFloat
    /// Radius of the corners seen from the front. Kept inside the caps, so the insert wraps
    /// round a straight hinge.
    let corner: CGFloat
    /// Radius where the faces roll over into the walls.
    let edge: CGFloat
    /// Bare plastic above and below the insert.
    let cap: CGFloat
    /// Bare plastic along the opening edge, front and back.
    let rim: CGFloat

    init(kind: PlatformBand.Kind) {
        let spec = kind.spec
        width = spec.width
        height = spec.height
        depth = spec.spine
        corner = min(spec.corner, spec.cap - 0.5)
        edge = 1.5
        cap = spec.cap
        rim = kind.isSwitch ? 3 : 3.5
    }

    /// A flat panel of the insert, front or back: from where the hinge rolls over to the rim.
    var panel: CGFloat { width - rim - edge }
    var insertHeight: CGFloat { height - cap * 2 }
    /// The insert and its film stand this far off the plastic, clear of it at any angle.
    static let lift: CGFloat = 0.3
    /// The spine's print, measured round the case: both rolled edges and the flat between.
    var spineRun: CGFloat { depth - edge * 2 + .pi * (edge + Self.lift) }
}

/// The meshes, made from a CaseSolid. Normals are given, so the rounded edges shade smoothly.
@MainActor
enum CaseMesh {
    private static let metre: Float = 0.001
    private static let lift = Float(CaseSolid.lift) * metre

    /// The walls all round, with the edges rolling into the faces. Texture coordinates: v runs
    /// across the wall, back (0) to front (1); u picks the seam (0.25) or, on the hinge, which is
    /// one piece, plain plastic (0.75).
    static func walls(_ solid: CaseSolid) throws -> MeshResource {
        let ring = outline(solid)
        let across = profile(solid)
        let depth = Float(solid.depth) * metre
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var coordinates: [SIMD2<Float>] = []
        for (point, outward) in ring {
            let column: Float = outward.x < -0.7 ? 0.75 : 0.25
            for step in across {
                let flat = point - outward * step.inset
                positions.append([flat.x, flat.y, step.z])
                normals.append(simd_normalize(SIMD3<Float>(outward.x * step.out, outward.y * step.out, step.forward)))
                coordinates.append([column, step.z / depth + 0.5])
            }
        }
        var indices: [UInt32] = []
        let rows = across.count
        for index in ring.indices {
            let next = (index + 1) % ring.count
            for row in 0..<(rows - 1) {
                let a = UInt32(index * rows + row), b = a + 1
                let d = UInt32(next * rows + row), c = d + 1
                indices += [a, b, c, a, c, d]
            }
        }
        return try mesh("walls", positions, normals, coordinates, indices)
    }

    /// The flat front and back, inside the rolled edges: the plastic under the film, seen in the
    /// caps and along the rim.
    static func faces(_ solid: CaseSolid) throws -> MeshResource {
        let edge = Float(solid.edge) * metre
        let half = Float(solid.depth) * metre / 2
        let ring = outline(solid).map { $0.point - $0.normal * edge }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for side: Float in [1, -1] {
            let centre = UInt32(positions.count)
            positions.append([0, 0, half * side])
            positions += ring.map { SIMD3<Float>($0.x, $0.y, half * side) }
            normals += Array(repeating: SIMD3<Float>(0, 0, side), count: ring.count + 1)
            for index in ring.indices {
                let a = centre + 1 + UInt32(index)
                let b = centre + 1 + UInt32((index + 1) % ring.count)
                indices += side > 0 ? [centre, a, b] : [centre, b, a]
            }
        }
        let coordinates = Array(repeating: SIMD2<Float>(0.75, 0.5), count: positions.count)
        return try mesh("faces", positions, normals, coordinates, indices)
    }

    /// The insert: one printed sheet, laid flat as [back | spine | front] (u from 0 to 1, read with
    /// the printed side facing you), wrapped from the back's rim round the hinge to the front's.
    static func insert(_ solid: CaseSolid) throws -> MeshResource {
        let halfWidth = Float(solid.width) * metre / 2
        let edge = Float(solid.edge) * metre
        let flat = Float(solid.depth) * metre / 2 - edge
        let free = halfWidth - Float(solid.rim) * metre   // where the sheet stops, by the rim
        let hinge = -halfWidth + edge                     // where the faces start to roll over
        let radius = edge + lift

        // The path round the case, from the back's rim to the front's.
        var path: [Stop] = []
        let panel = Float(solid.panel)
        let spine = Float(solid.spineRun)   // one millimetre of print per millimetre of path
        path.append(Stop(point: SIMD2(free, -flat - edge - lift), normal: SIMD2(0, -1), print: 0))
        let steps = 8
        // The spine's print covers both rolled edges and the flat between them.
        let arc = Float.pi / 2 * radius
        let spineRun = arc * 2 + flat * 2
        for step in 0...steps {   // back edge, rolling from the back onto the spine
            let angle = Float(step) / Float(steps) * .pi / 2
            let normal = SIMD2<Float>(-sin(angle), -cos(angle))
            let run = arc * Float(step) / Float(steps)
            path.append(Stop(point: SIMD2(hinge, -flat) + normal * radius, normal: normal, print: panel + spine * run / spineRun))
        }
        for step in 0...steps {   // front edge, rolling from the spine onto the front
            let angle = Float(step) / Float(steps) * .pi / 2
            let normal = SIMD2<Float>(-cos(angle), sin(angle))
            let run = arc + flat * 2 + arc * Float(step) / Float(steps)
            path.append(Stop(point: SIMD2(hinge, flat) + normal * radius, normal: normal, print: panel + spine * run / spineRun))
        }
        path.append(Stop(point: SIMD2(free, flat + edge + lift), normal: SIMD2(0, 1), print: panel * 2 + spine))

        let total = panel * 2 + spine
        let top = Float(solid.insertHeight) * metre / 2
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var coordinates: [SIMD2<Float>] = []
        for stop in path {
            for (y, v) in [(-top, Float(0)), (top, Float(1))] {
                positions.append([stop.point.x, y, stop.point.y])
                normals.append([stop.normal.x, 0, stop.normal.y])
                coordinates.append([stop.print / total, v])
            }
        }
        var indices: [UInt32] = []
        for index in 0..<(path.count - 1) {
            let a = UInt32(index * 2), d = a + 1   // bottom and top here
            let b = a + 2, c = a + 3               // bottom and top at the next stop
            indices += [a, b, c, a, c, d]
        }
        return try mesh("insert", positions, normals, coordinates, indices)
    }

    // MARK: - Shape

    /// A point across a wall: how far in from the outline, its depth, and its normal's outward
    /// and forward parts.
    private struct ProfileStep {
        let inset: Float
        let z: Float
        let out: Float
        let forward: Float
    }

    /// A point on the insert's path round the case, seen from above (x, z): its outward normal,
    /// and how far along the print it is, in millimetres.
    private struct Stop {
        let point: SIMD2<Float>
        let normal: SIMD2<Float>
        let print: Float
    }

    /// The outline seen from the front, anticlockwise from the right-hand edge, with each
    /// point's outward normal.
    private static func outline(_ solid: CaseSolid) -> [(point: SIMD2<Float>, normal: SIMD2<Float>)] {
        let radius = Float(solid.corner) * metre
        let a = Float(solid.width) * metre / 2 - radius
        let b = Float(solid.height) * metre / 2 - radius
        let centres: [SIMD2<Float>] = [[a, b], [-a, b], [-a, -b], [a, -b]]
        let steps = 8
        var ring: [(point: SIMD2<Float>, normal: SIMD2<Float>)] = []
        for (corner, centre) in centres.enumerated() {
            for step in 0...steps {
                let angle = (Float(corner) + Float(step) / Float(steps)) * .pi / 2
                let normal = SIMD2<Float>(cos(angle), sin(angle))
                ring.append((point: centre + normal * radius, normal: normal))
            }
        }
        return ring
    }

    /// Across a wall, from the front face to the back one.
    private static func profile(_ solid: CaseSolid) -> [ProfileStep] {
        let edge = Float(solid.edge) * metre
        let flat = Float(solid.depth) * metre / 2 - edge
        let steps = 5
        var rows: [ProfileStep] = []
        for (centre, start) in [(flat, Float(0)), (-flat, Float.pi / 2)] {
            for step in 0...steps {
                let angle = start + Float(step) / Float(steps) * .pi / 2
                rows.append(ProfileStep(inset: edge - edge * sin(angle), z: centre + edge * cos(angle), out: sin(angle), forward: cos(angle)))
            }
        }
        return rows
    }

    private static func mesh(_ name: String, _ positions: [SIMD3<Float>], _ normals: [SIMD3<Float>],
                             _ coordinates: [SIMD2<Float>], _ indices: [UInt32]) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(coordinates)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
