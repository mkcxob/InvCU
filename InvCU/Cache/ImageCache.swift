//
//  ImageCache.swift
//  InvCU
//
//  Image caching system for both disk and memory

import UIKit
import Foundation

// Private actor to manage download tasks safely in a concurrent context
private actor DownloadTracker {
    private var ongoingDownloads: [String: Task<UIImage?, Never>] = [:]
    
    func get(for url: String) -> Task<UIImage?, Never>? {
        ongoingDownloads[url]
    }
    
    func set(_ task: Task<UIImage?, Never>, for url: String) {
        ongoingDownloads[url] = task
    }
    
    func remove(for url: String) {
        ongoingDownloads.removeValue(forKey: url)
    }
}

// Manages image caching with both memory and disk storage
final class ImageCache {
    static let shared = ImageCache()
    
    // Memory cache for fast access during app session
    // Automatically evicts old images when memory is low
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Disk cache directory for persistent storage
    private let diskCacheURL:  URL
    private let fileManager = FileManager.default
    
    // Background queue for disk operations to avoid blocking main thread
    private let diskQueue = DispatchQueue(label: "com.invcu.imagecache.disk", qos: .utility)
    
    // Actor for tracking ongoing downloads
    private let downloadTracker = DownloadTracker()
    
    private init() {
        // Configure memory cache limits to prevent excessive memory usage
        memoryCache.countLimit = 200 // Increased to 200 images in memory
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // Increased to 100 MB in memory
        
        // Setup disk cache directory in app's cache folder
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        print("ImageCache initialized")
        print("Memory limit: \(memoryCache.countLimit) images")
        print("Disk location: \(diskCacheURL.path)")
        
        // Register for memory warnings to clear cache when needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Public API
    
    // Retrieves an image from cache if available
    // Checks memory cache first (fastest), then disk cache
    // Returns nil if image is not cached
    func getImage(for url: String) -> UIImage? {
        let key = cacheKey(for: url)
        
        // Check memory cache first - this is the fastest lookup
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }
        
        // If not in memory, check disk cache synchronously
        // This is still very fast (reading from disk)
        if let image = loadImageFromDisk(key: key) {
            // Store in memory cache for faster access next time
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    // Saves an image to both memory and disk cache
    // Memory cache is updated immediately for instant access
    // Disk cache is updated asynchronously to avoid blocking
    func setImage(_ image: UIImage, for url: String) {
        let key = cacheKey(for: url)
        
        // Save to memory cache immediately for instant access
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Save to disk asynchronously on background queue
        diskQueue.async { [weak self] in
            self?.saveImageToDisk(image, key: key)
        }
    }
    
    // Async method to download and cache an image
    // Returns the cached or downloaded image
    // Prevents duplicate downloads for the same URL
    func fetchImage(for url: String) async -> UIImage? {
        print("fetchImage called for: \(url.suffix(40))")
        
        // Check if already cached
        if let cached = getImage(for: url) {
            print("    Found in cache (memory or disk)")
            return cached
        }
        
        print(" Not in cache, will download...")
        
        // Use the downloadTracker actor instead of DispatchQueue sync
        if let existingTask = await downloadTracker.get(for: url) {
            print("   ⏳ Download already in progress, waiting...")
            // Download already in progress, wait for it
            return await existingTask.value
        }
        
        // Start new download
        let task = Task<UIImage?, Never> {
            await downloadImage(from: url)
        }
        await downloadTracker.set(task, for: url)
        
        let image = await task.value
        
        // Remove from ongoing downloads
        await downloadTracker.remove(for: url)
        
        return image
    }
    
    // Preload multiple images in the background
    func preloadImages(urls: [String]) async {
        print("preloadImages called with \(urls.count) URLs")
        await withTaskGroup(of:  Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await self.fetchImage(for: url)
                }
            }
        }
        print("preloadImages completed")
    }
    
    // Clears all cached images from both memory and disk
    // Useful when user signs out or to free up space
    func clearCache() {
        memoryCache.removeAllObjects()
        
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        }
        
        print("Cache cleared")
    }
    
    // Calculates total size of disk cache in bytes
    // Useful for showing cache size to user in settings
    func getCacheSize() -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        return size
    }
    
    // MARK: - Private Helpers
    
    // Downloads an image from URL and caches it
    private func downloadImage(from urlString: String) async -> UIImage? {
        print("  Attempting to download:  \(urlString.suffix(50))")
        
        guard let url = URL(string: urlString) else {
            print("    Invalid URL: \(urlString)")
            return nil
        }
        
        do {
            print("  Connecting to server...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("  HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("   Non-200 status code received")
                    return nil
                }
            }
            
            print("  Downloaded \(data.count) bytes")
            
            if let image = UIImage(data: data) {
                // Cache the downloaded image
                setImage(image, for: urlString)
                print("  Successfully converted to UIImage and cached")
                print("    Image size: \(image.size)")
                return image
            } else {
                print("  Failed to convert data to UIImage")
                return nil
            }
        } catch {
            print("  Download failed: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                print("   URLError code: \(urlError.code.rawValue)")
            }
            return nil
        }
    }
    
    // Generates a safe filename from a URL string
    // Uses percent encoding to remove special characters
    private func cacheKey(for url: String) -> String {
        return url.addingPercentEncoding(withAllowedCharacters:  .alphanumerics) ?? UUID().uuidString
    }
    
    // Loads an image from disk cache
    // Returns nil if file doesn't exist or is corrupted
    private func loadImageFromDisk(key: String) -> UIImage? {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    // Saves an image to disk cache
    // Compresses image as JPEG to save space
    private func saveImageToDisk(_ image: UIImage, key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        // Compress image to JPEG with 90% quality (increased from 85%)
        // Higher quality for better image appearance
        guard let data = image.jpegData(compressionQuality: 0.90) else {
            print("Failed to compress image")
            return
        }
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Failed to save image to disk: \(error)")
        }
    }
    
    // Handles memory warnings by clearing memory cache
    // Disk cache is preserved so images can be reloaded quickly
    @objc private func handleMemoryWarning() {
        print("Memory warning - clearing memory cache")
        memoryCache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

