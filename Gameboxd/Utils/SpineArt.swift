//
//  SpineArt.swift
//  Gameboxd
//
//  What a case's printed insert takes from a cover: the strip of art that wraps round onto
//  the spine, its colour, and whether the cover is a box scan already carrying the platform's
//  header. Cut once per cover and platform, off the main thread; spines keep only the strip
//  (~50 × 480 px), never the whole decoded cover.
//

import UIKit
import CoreImage
// swiftlint:disable:next duplicate_imports
import CoreImage.CIFilterBuiltins // CIFilter.lanczosScaleTransform()

/// How a platform's insert sits on its case, for cutting a cover's art to it.
nonisolated struct SleeveGeometry: Sendable {
    /// Height over width of the printed front: 160/128 PS and Xbox, 161/99.5 Switch, 183/129.5 PC DVD.
    let frontAspect: CGFloat
    /// Spine thickness over front width: how much of the art's left edge wraps onto the spine.
    let spineFraction: CGFloat
    /// sRGB of the header the platform prints across the front; nil where none is worth looking for.
    let banner: SIMD3<Float>?
}

/// A cut, as it leaves the background thread.
nonisolated struct SpineCut: @unchecked Sendable { // UIImage and UIColor are immutable
    let strip: UIImage
    let average: UIColor
    /// Height of a platform header printed in the art itself, as a share of the front; 0 if none.
    let banner: CGFloat
}

nonisolated enum SpineCutter {
    /// A 192 pt spine at @3x is 576 px, and its art sits under a plate: 480 px is plenty.
    static let pixelHeight: CGFloat = 480

    /// The cover's left edge as the front shows it (centred and scaled to fill, exactly as
    /// FaceOutCase draws its panel), below any header the art already carries. Not mirrored:
    /// the art wraps round, it isn't reflected (a mirror would reverse any lettering).
    static func cut(_ cover: UIImage, sleeve: SleeveGeometry) -> SpineCut? {
        guard let image = cover.cgImage, image.width >= 16, image.height >= 16 else { return nil }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        var front = CGRect(x: 0, y: 0, width: width, height: height)
        if height / width > sleeve.frontAspect {
            front.size.height = (width * sleeve.frontAspect).rounded()
            front.origin.y = ((height - front.height) / 2).rounded()
        } else {
            front.size.width = (height / sleeve.frontAspect).rounded()
            front.origin.x = ((width - front.width) / 2).rounded()
        }
        let banner = sleeve.banner.map { bannerFraction(in: image, front: front, color: $0) } ?? 0
        let skip = (front.height * banner).rounded()
        let wrap = CGRect(x: front.minX, y: front.minY + skip,
                          width: max(2, (front.width * sleeve.spineFraction).rounded()),
                          height: front.height - skip)
        let scale = min(1, pixelHeight / wrap.height)
        let size = CGSize(width: max(1, (wrap.width * scale).rounded()), height: max(1, (wrap.height * scale).rounded()))
        guard let pixels = resample(image, crop: wrap, to: size) else { return nil }
        let strip = UIImage(cgImage: pixels)
        guard let average = ImageCache.averageColor(of: strip) else { return nil }
        return SpineCut(strip: strip, average: average, banner: banner)
    }

    /// Box scans carry the platform's header: rows of its colour across the top of the front,
    /// ending in a clean edge. Only the middle columns are tested for the colour: the logo sits
    /// at the band's left and "Only on PlayStation" at its right.
    private static func bannerFraction(in image: CGImage, front: CGRect, color: SIMD3<Float>) -> CGFloat {
        let depth: CGFloat = 0.2
        let rows = 40
        let columns = 16
        let region = CGRect(x: front.minX, y: front.minY, width: front.width, height: (front.height * depth).rounded())
        guard let cells = samples(of: image, rect: region, columns: columns, rows: rows) else { return 0 }
        func distance(_ row: Int, _ column: Int) -> Float {
            let difference = cells[row * columns + column] - color
            return (difference * difference).sum().squareRoot()
        }
        func isBand(_ row: Int) -> Bool {
            (7...11).filter { distance(row, $0) < 0.25 }.count >= 4
        }
        var bandRows = 0
        while bandRows < rows, isBand(bandRows) { bandRows += 1 }
        let fraction = (CGFloat(bandRows) + 0.5) / CGFloat(rows) * depth
        // A real header ends in a clean edge well inside the top fifth.
        guard bandRows < rows, (0.035...0.17).contains(fraction) else { return 0 }
        // And it carries the platform's mark at its left (the PS logotype, the Xbox sphere, the
        // Switch icon): a plain sky or a red top in the art has nothing there.
        let marked = (0..<bandRows).contains { row in (1...4).contains { distance(row, $0) > 0.4 } }
        return marked ? fraction : 0
    }

    /// RGB 0–1 of a columns × rows grid over `rect`, top row first, each cell filtered down
    /// from its area.
    private static func samples(of image: CGImage, rect: CGRect, columns: Int, rows: Int) -> [SIMD3<Float>]? {
        guard let grid = resample(image, crop: rect, to: CGSize(width: columns, height: rows)),
              grid.width == columns, grid.height == rows, grid.bitsPerPixel == 32,
              let data = grid.dataProvider?.data,
              CFDataGetLength(data) >= grid.bytesPerRow * rows,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        // RGBA8, as asked of Core Image; a CGImage's first row is the top of the picture.
        let stride = grid.bytesPerRow
        var cells: [SIMD3<Float>] = []
        cells.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * stride + column * 4
                cells.append(SIMD3<Float>(Float(bytes[index]), Float(bytes[index + 1]), Float(bytes[index + 2])) / 255)
            }
        }
        return cells
    }

    /// `crop` (pixels, from the top left) resampled to `size` pixels into a bitmap of its own:
    /// a plain `cropping(to:)` would share, and so keep alive, the whole decoded cover.
    private static func resample(_ image: CGImage, crop: CGRect, to size: CGSize) -> CGImage? {
        // Core Image counts from the bottom.
        let region = CGRect(x: crop.minX, y: CGFloat(image.height) - crop.maxY, width: crop.width, height: crop.height).integral
        guard region.width >= 1, region.height >= 1, size.width >= 1, size.height >= 1 else { return nil }
        let source = CIImage(cgImage: image)
            .cropped(to: region)
            .transformed(by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
            .clampedToExtent() // edges filter against themselves, not against transparency
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = source
        filter.scale = Float(size.height / region.height)
        filter.aspectRatio = Float((size.width / region.width) / (size.height / region.height))
        guard let output = filter.outputImage else { return nil }
        return sharedCIContext.createCGImage(output, from: CGRect(origin: .zero, size: size),
                                             format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
}

/// What a spine and a case front use of a cover. A class, so NSCache can hold it.
final class SpineArt {
    let strip: UIImage
    /// The strip's average pushed towards a printed-ink colour: a spine's ground.
    let ground: UIColor
    /// Height of a platform header already in the art (a box scan), as a share of the front.
    let banner: CGFloat

    init(strip: UIImage, ground: UIColor, banner: CGFloat) {
        self.strip = strip
        self.ground = ground
        self.banner = banner
    }

    var cost: Int { strip.cgImage.map { $0.width * $0.height * 4 } ?? 1024 }
}
