import Foundation
import UIKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxDiskBytes: Int = 200 * 1024 * 1024 // 200 MB

    private var memoryCache = NSCache<NSString, UIImage>()

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("rev_persistent_images", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 80 * 1024 * 1024
    }

    // MARK: - Public API

    func image(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        if let mem = memoryCache.object(forKey: key as NSString) { return mem }
        guard let data = try? Data(contentsOf: filePath(for: key)),
              let img = UIImage(data: data) else { return nil }
        memoryCache.setObject(img, forKey: key as NSString, cost: data.count)
        return img
    }

    func loadImage(for url: URL) async -> UIImage? {
        if let cached = image(for: url) { return cached }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let img = UIImage(data: data) else { return nil }
            store(data: data, key: cacheKey(for: url), image: img)
            return img
        } catch {
            return nil
        }
    }

    func preload(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { [weak self] in
                    _ = await self?.loadImage(for: url)
                }
            }
        }
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Internal

    private func store(data: Data, key: String, image: UIImage) {
        memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
        let path = filePath(for: key)
        try? data.write(to: path, options: .atomic)
    }

    private func cacheKey(for url: URL) -> String {
        let str = url.absoluteString
        var hash: UInt64 = 5381
        for byte in str.utf8 { hash = 127 &* hash &+ UInt64(byte) }
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return "\(hash).\(ext)"
    }

    private func filePath(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key)
    }
}
