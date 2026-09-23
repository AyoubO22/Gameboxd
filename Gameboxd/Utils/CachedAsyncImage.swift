//
//  CachedAsyncImage.swift
//  Gameboxd
//
//  Cached image loader to avoid re-downloading images across views
//

import SwiftUI
import CryptoKit
import ImageIO
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Image Cache
final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("GameboxdImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func cacheKey(for url: URL) -> NSString {
        url.absoluteString as NSString
    }
    
    private func diskPath(for url: URL) -> URL {
        // Full-URL hash: truncated base64 made long URLs sharing a prefix collide.
        let filename = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func memoryImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        return cache.object(forKey: key)
    }

    func diskImage(for url: URL) async -> UIImage? {
        let path = diskPath(for: url)
        let key = cacheKey(for: url)
        let result: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: path) else { return nil as UIImage? }
            return ImageCache.decode(data)
        }.value
        if let image = result {
            cache.setObject(image, forKey: key)
        }
        return result
    }

    // Synchronous combined lookup (memory only)
    func image(for url: URL) -> UIImage? {
        return memoryImage(for: url)
    }

    /// Memory, then disk, then network (with two retries). Nil if every attempt fails or the task is cancelled.
    func load(_ url: URL, maxRetries: Int = 2) async -> UIImage? {
        if let cached = memoryImage(for: url) { return cached }
        if let cached = await diskImage(for: url) { return cached }
        for attempt in 0...maxRetries {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * attempt))
            }
            guard !Task.isCancelled else { return nil }
            if let (data, response) = try? await URLSession.shared.data(from: Self.downloadURL(for: url)),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let image = await Task.detached(priority: .userInitiated, operation: { ImageCache.decode(data) }).value {
                store(image, for: url)
                return image
            }
        }
        return nil
    }

    // MARK: - Decoding (off the main thread)

    /// Decodes and downsizes in one pass. `UIImage(data:)` is lazy: it would decode
    /// full-size on the main thread the first time SwiftUI draws it, stalling scrolling.
    nonisolated static func decode(_ data: Data, maxPixelSize: Int = 1100) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// RAWG serves originals of several megabytes; its resize endpoint returns a
    /// 1280 px wide version of the same picture. Other hosts are fetched as they are.
    nonisolated static func downloadURL(for url: URL) -> URL {
        let string = url.absoluteString
        guard string.contains("media.rawg.io/media/games/") else { return url }
        return URL(string: string.replacingOccurrences(of: "media.rawg.io/media/games/", with: "media.rawg.io/media/resize/1280/-/games/")) ?? url
    }

    // MARK: - Dominant colour (spines, 3D box)

    private var dominantColors: [URL: UIColor] = [:]

    /// Average colour of the cover, cached per URL.
    func dominantColor(for url: URL) async -> UIColor? {
        if let cached = dominantColors[url] { return cached }
        guard let image = await load(url),
              let average = await Task.detached(priority: .utility, operation: { ImageCache.averageColor(of: image) }).value else { return nil }
        let color = average.printed()
        dominantColors[url] = color
        return color
    }

    /// Averaging a cover lands on a muddy mid-tone; push it towards a printed-ink colour.
    nonisolated static func averageColor(of image: UIImage) -> UIColor? {
        let context = sharedCIContext
        guard let input = CIImage(image: image) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent
        guard let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }

    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        // Memory cache immediately (estimate cost)
        let estimatedCost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key, cost: estimatedCost)

        // Disk cache on background thread
        let path = diskPath(for: url)
        Task.detached(priority: .utility) {
            if let data = image.jpegData(compressionQuality: 0.9) {
                try? data.write(to: path, options: .atomic)
            }
        }
    }
}

nonisolated private let sharedCIContext = CIContext() // CIContext is thread-safe

// MARK: - Cached Async Image View
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    private let maxRetries = 2
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        // Synchronous memory hit, so snapshot renderers (ImageRenderer), which never
        // run .task, still draw an already-loaded cover.
        _loadedImage = State(initialValue: url.flatMap { ImageCache.shared.memoryImage(for: $0) })
    }
    
    var body: some View {
        // Use placeholder as layout anchor, overlay content on top.
        // This ensures the layout size is always determined by the placeholder
        // (which has proper sizing constraints), while the loaded image
        // is clipped to fit within those bounds — matching AsyncImage behavior.
        placeholder()
            .opacity(loadedImage == nil ? 1 : 0)
            .overlay {
                if let image = loadedImage {
                    content(Image(uiImage: image))
                }
            }
            .clipped()
            // Keyed on url: a URL change cancels the old load, so a slow stale
            // response can never overwrite the new image.
            .task(id: url) {
                await loadImage(url)
            }
    }
    
    private func loadImage(_ url: URL?) async {
        guard let url else { loadedImage = nil; return }
        if let cached = ImageCache.shared.memoryImage(for: url) {
            loadedImage = cached
            return
        }
        loadedImage = nil
        let image = await ImageCache.shared.load(url, maxRetries: maxRetries)
        if !Task.isCancelled { loadedImage = image }
    }
}

extension UIColor {
    /// A cover's average colour, saturated and kept away from pure black or white,
    /// so spines read like printed card rather than grey plastic.
    func printed() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(s * 1.6 + 0.08, 0.85), brightness: min(max(b * 1.15, 0.32), 0.82), alpha: 1)
    }
}
