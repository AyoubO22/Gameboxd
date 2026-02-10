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
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
        
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
    
    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        
        // Check memory cache
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // Check disk cache
        let path = diskPath(for: url)
        if let data = try? Data(contentsOf: path),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: key, cost: data.count)
            return image
        }
        
        return nil
    }
    
    func store(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        let data = image.jpegData(compressionQuality: 0.9)
        let cost = data?.count ?? 0
        
        // Memory cache
        cache.setObject(image, forKey: key, cost: cost)
        
        // Disk cache
        if let data = data {
            let path = diskPath(for: url)
            try? data.write(to: path, options: .atomic)
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
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        if !isLoading {
                            loadImage()
                        }
                    }
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
        
        // Check cache first
        if let cached = ImageCache.shared.image(for: url) {
            loadedImage = cached
            return
        }
        
        guard !isLoading else { return }
        isLoading = true
        
        Task {
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
