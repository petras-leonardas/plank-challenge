//
//  ImageCache.swift
//  PlankChallenge
//

import SwiftUI

// MARK: - In-Memory Image Cache

/// A lightweight in-memory cache for decoded remote images.
///
/// Backed by `NSCache`, which the OS automatically evicts under memory pressure.
/// Cache key is the full URL string — stable for Cloudflare R2 URLs.
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100
        c.totalCostLimit = 30 * 1024 * 1024  // ~30 MB
        return c
    }()

    private init() {}

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
}

// MARK: - Cached Avatar Image

/// Wraps AsyncImage with an in-memory cache and a shimmer placeholder.
/// Used inside `AvatarView` for remote profile photos.
/// Shows a shimmer circle while loading; failure falls through to caller.
struct CachedAvatarImage: View {
    let url: URL
    let size: CGFloat
    /// Called when the image loads successfully.
    let onSuccess: (Image) -> AnyView
    /// Called when the image fails to load or URL is nil.
    let onFailure: () -> AnyView

    var body: some View {
        if let cached = ImageCache.shared.image(for: url) {
            onSuccess(Image(uiImage: cached))
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    let _ = cacheImage(image)
                    onSuccess(image)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    onFailure()
                        .frame(width: size, height: size)
                case .empty:
                    Circle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: size, height: size)
                        .shimmer()
                @unknown default:
                    Circle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: size, height: size)
                        .shimmer()
                }
            }
        }
    }

    @discardableResult
    private func cacheImage(_ image: Image) -> Bool {
        let renderer = ImageRenderer(
            content: image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        )
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            ImageCache.shared.store(uiImage, for: url)
        }
        return true
    }
}

// MARK: - Cached Group Image

/// Wraps AsyncImage with an in-memory cache and a shimmer placeholder.
/// Used for group thumbnails in group rows and the group detail header.
struct CachedGroupImage: View {
    let url: URL
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        if let cached = ImageCache.shared.image(for: url) {
            Image(uiImage: cached)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    let _ = cacheImage(image)
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                case .failure:
                    // Show nothing on failure — the parent ZStack's fallback icon shows through
                    Color.clear
                        .frame(width: size, height: size)
                case .empty:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: size, height: size)
                        .shimmer()
                @unknown default:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: size, height: size)
                        .shimmer()
                }
            }
        }
    }

    @discardableResult
    private func cacheImage(_ image: Image) -> Bool {
        let renderer = ImageRenderer(
            content: image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            ImageCache.shared.store(uiImage, for: url)
        }
        return true
    }
}
