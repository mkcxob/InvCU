
//  OptimizedCachedImage.swift
//  InvCU
//
//  Instantly shows cached images with no delay

import SwiftUI

struct OptimizedCachedImage<Content: View, Placeholder: View>: View {
    let url: String
    let content: (Image) -> Content
    let placeholder:  () -> Placeholder
    
    @State private var image: UIImage?
    
    init(
        url: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        
        // CRITICAL: Check cache IMMEDIATELY in init
        // This prevents any delay or re-rendering
        let cached = ImageCache.shared.getImage(for: url)
        _image = State(initialValue: cached)
    }
    
    var body:  some View {
        Group {
            if let uiImage = image {
                // Show cached image instantly
                content(Image(uiImage: uiImage))
            } else {
                // Only show placeholder if truly not cached
                placeholder()
                    .task {
                        // Download in background if needed
                        if let downloaded = await ImageCache.shared.fetchImage(for: url) {
                            image = downloaded
                        }
                    }
            }
        }
    }
}
