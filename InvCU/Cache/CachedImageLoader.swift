//
//  ImageCache.swift
//  InvCU
//
//  Image caching system for both disk and memory

import UIKit
import Foundation

/// Manages image caching with both memory and disk storage
final class ImageCache {
    static let shared = ImageCache()
    
    // Memory cache for fast access during app session
    // Automatically evicts old images when memory is low
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // Disk cache directory for persistent storage
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    
    // Background queue for disk operations to avoid blocking main thread
    private let diskQueue = DispatchQueue(label: "com.invcu.imagecache.disk", qos: .utility)
    
    private init() {
        // Configure memory cache limits to prevent excessive memory usage
        memoryCache.countLimit = 100 // Maximum 100 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // Maximum 50 MB in memory
        
        // Setup disk cache directory in app's cache folder
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: . userDomainMask)[0]
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
    //
    // Retrieves an image from cache if available
    // Checks memory cache first (fastest), then disk cache
    // Returns nil if image is not cached
    func getImage(for url: String) -> UIImage? {
        let key = cacheKey(for: url)
        
        // Check memory cache first - this is the fastest lookup
        if let image = memoryCache.object(forKey: key as NSString) {
            print("Cache HIT (memory): \(url.suffix(30))")
            return image
        }
        
        // If not in memory, check disk cache
        if let image = loadImageFromDisk(key: key) {
            print("Cache HIT (disk): \(url.suffix(30))")
            // Store in memory cache for faster access next time
            memoryCache.setObject(image, forKey: key as NSString)
            return image
        }
        
        print("Cache MISS:  \(url.suffix(30))")
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
        
        print("Cached image: \(url.suffix(30))")
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
        
        if let enumerator = fileManager.enumerator(at: diskCacheURL, includingPropertiesForKeys:  [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        return size
    }
    
    // MARK:  - Private Helpers
    
    // Generates a safe filename from a URL string
    // Uses percent encoding to remove special characters
    private func cacheKey(for url: String) -> String {
        return url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
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
        
        // Compress image to JPEG with 85% quality
        // This is a good balance between quality and file size
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            print("Failed to compress image")
            return
        }
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Failed to save image to disk: \(error)")
        }
    }
    
    //Handles memory warnings by clearing memory cache
    // Disk cache is preserved so images can be reloaded quickly
    @objc private func handleMemoryWarning() {
        print("Memory warning - clearing memory cache")
        memoryCache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
