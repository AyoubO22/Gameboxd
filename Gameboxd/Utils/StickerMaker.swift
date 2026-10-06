//
//  StickerMaker.swift
//  Gameboxd
//
//  Turns game art into die-cut stickers: Vision lifts the subjects, Core Image adds the
//  white border. Runs on device only; the simulator has no Vision support for this
//  request (com.apple.Vision code 9), so it simply returns nothing there.
//

import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

nonisolated enum StickerMaker {
    struct Cutout {
        let png: Data
        /// A person (or at least an upper body) was found in the cut-out: these make the
        /// best stickers, scenery and props the weakest.
        let hasPerson: Bool
        /// 8×8 average hash, to drop near-duplicates across images (the same emblem in
        /// several artworks). Two cut-outs within 10 bits are the same sticker.
        let hash: UInt64
        let print: Print?

        /// Same picture: nearly the same pixels, or the same content (Vision feature print).
        /// 0.35 is under the closest pair of distinct characters drawn in one style (0.43).
        func isDuplicate(of other: Cutout) -> Bool {
            if (hash ^ other.hash).nonzeroBitCount <= 10 { return true }
            guard let print, let otherPrint = other.print else { return false }
            return print.distance(to: otherPrint) < 0.35
        }
    }

    /// Vision feature print, wrapped so it can come back from a background task.
    struct Print: @unchecked Sendable {
        let observation: VNFeaturePrintObservation

        func distance(to other: Print) -> Float {
            var distance = Float.greatestFiniteMagnitude
            try? observation.computeDistance(&distance, to: other.observation)
            return distance
        }
    }

    /// Two source images closer than this are the same art in another crop or format
    /// (with or without the logo). Measured on 1200 px prints: variants of one key art
    /// 0.31–0.50 (Marvel's Wolverine), distinct artworks 0.53 and up (RDR2, Witcher 3, BioShock).
    /// ponytail: tight margin on both sides; retune on more games if repeats or losses show up.
    static let sameSourceDistance: Float = 0.515

    /// Feature print of a whole image, to skip sources that repeat art already used.
    static func print(of data: Data) -> Print? {
        guard let image = downsized(data, maxPixelSize: 1200) else { return nil }
        return print(of: image)
    }

    private static func print(of image: CGImage) -> Print? {
        let request = VNGenerateImageFeaturePrintRequest()
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil,
              let observation = request.results?.first else { return nil }
        return Print(observation: observation)
    }

    private static let context = CIContext()

    /// Every usable subject in the image, people first. Empty on failure.
    static func cutouts(from data: Data) -> [Cutout] {
        guard let image = downsized(data, maxPixelSize: 1200) else { return [] }
        let handler = VNImageRequestHandler(cgImage: image)
        let request = VNGenerateForegroundInstanceMaskRequest()
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { return [] }

        let total = CGFloat(image.width * image.height)
        let cutouts: [Cutout] = observation.allInstances.compactMap { instance in
            guard let buffer = try? observation.generateMaskedImage(ofInstances: [instance], from: handler, croppedToInstancesExtent: true) else { return nil }
            let cut = CIImage(cvPixelBuffer: buffer)
            let extent = cut.extent
            // Quality gate: big enough, not a sliver, not a fragmented cut.
            guard extent.width * extent.height / total >= 0.12,
                  (0.33...3.0).contains(extent.width / extent.height),
                  coverage(of: cut) >= 0.35 else { return nil }
            let sticker = outlined(cut, border: max(6, min(extent.width, extent.height) * 0.03))
            guard let cg = context.createCGImage(sticker, from: sticker.extent), let png = pngData(cg) else { return nil }
            return Cutout(png: png, hasPerson: containsPerson(cg), hash: averageHash(cut), print: print(of: cg))
        }
        return cutouts.sorted { $0.hasPerson && !$1.hasPerson }
    }

    // MARK: - Steps

    private static func downsized(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary)
    }

    /// Share of the crop covered by the subject (low = stringy or fragmented cut).
    private static func coverage(of cut: CIImage) -> Double {
        let average = cut.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: cut.extent)])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return Double(pixel[3]) / 255
    }

    /// White die-cut border: the subject's alpha, grown by `border`, filled white, under the subject.
    private static func outlined(_ cut: CIImage, border: CGFloat) -> CIImage {
        let canvas = CGRect(x: 0, y: 0, width: cut.extent.width + border * 4, height: cut.extent.height + border * 4)
        let subject = cut.transformed(by: .init(translationX: border * 2 - cut.extent.minX, y: border * 2 - cut.extent.minY))
        let alpha = subject.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ]).composited(over: CIImage(color: .black).cropped(to: canvas))
        let grown = alpha
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": border])
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.2])
            .cropped(to: canvas)
        let backing = CIImage(color: .white).cropped(to: canvas).applyingFilter("CIBlendWithMask", parameters: [
            "inputBackgroundImage": CIImage(color: .clear).cropped(to: canvas),
            "inputMaskImage": grown,
        ])
        return subject.composited(over: backing).cropped(to: canvas)
    }

    private static func averageHash(_ image: CIImage) -> UInt64 {
        let small = image.transformed(by: .init(scaleX: 8 / image.extent.width, y: 8 / image.extent.height))
        var pixels = [UInt8](repeating: 0, count: 8 * 8 * 4)
        context.render(small, toBitmap: &pixels, rowBytes: 32, bounds: CGRect(x: 0, y: 0, width: 8, height: 8), format: .RGBA8, colorSpace: nil)
        let luma = stride(from: 0, to: pixels.count, by: 4).map { (Int(pixels[$0]) + Int(pixels[$0 + 1]) + Int(pixels[$0 + 2])) / 3 }
        let mean = luma.reduce(0, +) / luma.count
        return luma.enumerated().reduce(UInt64(0)) { $1.element > mean ? $0 | (1 << UInt64($1.offset)) : $0 }
    }

    private static func containsPerson(_ image: CGImage) -> Bool {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = true
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return false }
        return !(request.results ?? []).isEmpty
    }

    private static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
