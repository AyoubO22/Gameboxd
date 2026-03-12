//
//  CachedAsyncImage.swift
//  Gameboxd
//
//  Cached image loader to avoid re-downloading images across views
//

import SwiftUI

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
        let filename = url.absoluteString.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(200)
        return cacheDirectory.appendingPathComponent(String(filename))
    }
    
    func memoryImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        return cache.object(forKey: key)
    }

    func diskImage(for url: URL) async -> UIImage? {
        let path = diskPath(for: url)
        let key = cacheKey(for: url)
        let result: UIImage? = await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: path),
                  let image = UIImage(data: data) else { return nil as UIImage? }
            return image
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

// MARK: - Cached Async Image View
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    @State private var retryCount = 0
    private let maxRetries = 2
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
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
            .onAppear {
                if !isLoading && loadedImage == nil {
                    loadImage()
                }
            }
            .onChange(of: url) { oldURL, newURL in
                if newURL != oldURL {
                    loadedImage = nil
                    retryCount = 0
                    hasFailed = false
                    isLoading = false
                    loadImage()
                }
            }
    }
    
    private func loadImage() {
        guard let url = url else { return }

        // Check memory cache synchronously
        if let cached = ImageCache.shared.memoryImage(for: url) {
            loadedImage = cached
            return
        }

        guard !isLoading else { return }
        isLoading = true

        Task {
            // Check disk cache asynchronously
            if let diskCached = await ImageCache.shared.diskImage(for: url) {
                loadedImage = diskCached
                isLoading = false
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    throw URLError(.badServerResponse)
                }
                
                // Cache the image
                ImageCache.shared.store(image, for: url)
                
                await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if retryCount < maxRetries {
                        retryCount += 1
                        // Retry after a short delay
                        Task {
                            try? await Task.sleep(nanoseconds: UInt64(500_000_000 * retryCount))
                            loadImage()
                        }
                    } else {
                        hasFailed = true
                    }
                }
            }
        }
    }
}
