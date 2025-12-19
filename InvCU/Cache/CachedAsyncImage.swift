//
//  CachedAsyncImage.swift
//  InvCU
//
//  Created by work on 12/17/25.
//

//  SwiftUI view component for loading and displaying images with automatic caching.
//  Checks cache first before downloading, providing instant loading for cached images.
//  Supports custom content and placeholder views for flexibility.
//

import SwiftUI

/// A SwiftUI view that loads images asynchronously with automatic caching
/// Usage: CachedAsyncImage(url:  imageURL) { image in image. resizable() } placeholder: { ProgressView() }
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    let content:  (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError = false
    
    /// Creates a cached async image loader
    /// - Parameters:
    ///   - url: The URL string of the image to load
    ///   - content: A view builder that creates the view for the loaded image
    ///   - placeholder: A view builder that creates the view shown while loading or on error
    init(
        url: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                // Image loaded successfully - display it
                content(Image(uiImage: image))
            } else if loadError {
                // Error occurred while loading - show placeholder with error indicator
                placeholder()
                    . overlay(
                        Image(systemName: "exclamationmark.triangle")
                            . foregroundColor(.red)
                            .opacity(0.5)
                    )
            } else {
                // Loading state - show placeholder and start loading
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    // Loads the image from cache or downloads it if not cached
    // Prevents multiple simultaneous loads of the same image
    private func loadImage() {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        
        // Check cache first before attempting download
        if let cachedImage = ImageCache.shared.getImage(for: url) {
            self.image = cachedImage
            return
        }
        
        // Image not in cache - download it
        isLoading = true
        loadError = false
        
        Task {
            do {
                let downloadedImage = try await downloadImage(from: url)
                
                // Save downloaded image to cache for future use
                ImageCache.shared.setImage(downloadedImage, for: url)
                
                // Update UI on main thread
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
                
            } catch {
                print("Failed to load image: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.loadError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    // Downloads an image from the given URL string
    //Validates response and data before creating UIImage
    private func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Validate HTTP response status
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Attempt to create image from downloaded data
        guard let image = UIImage(data:  data) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return image
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage where Placeholder == Color {
    // Convenience initializer with a simple gray color placeholder
    init(url: String, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(
            url: url,
            content: content,
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    // Simplest initializer - just provide URL, uses default resizable image and progress view
    init(url: String) {
        self.init(
            url: url,
            content: { $0.resizable() },
            placeholder: { ProgressView() }
        )
    }
}
