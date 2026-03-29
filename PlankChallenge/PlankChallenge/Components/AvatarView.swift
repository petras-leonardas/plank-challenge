//
//  AvatarView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// A unified avatar component used throughout the app.
/// Displays the first letter of a name in a circular container.
/// Supports three image sources (in priority order):
///   1. `imageUrl`  — remote URL loaded via AsyncImage (profile photos)
///   2. `imageName` — local asset catalog name
///   3. Initials fallback — first letter of `text`
struct AvatarView: View {
    let text: String
    let imageName: String?
    let imageUrl: String?
    let size: CGFloat
    var style: AvatarStyle = .standard
    
    /// Avatar style variants
    enum AvatarStyle {
        case standard       // Gray background, secondary text
        case gradient       // Gradient background (for current user)
        case accent         // Accent color background
        
        var background: AnyShapeStyle {
            switch self {
            case .standard:
                return AnyShapeStyle(Color.gray.opacity(0.2))
            case .gradient:
                return AnyShapeStyle(LinearGradient.avatarGradient)
            case .accent:
                return AnyShapeStyle(Color.appAccent.opacity(0.2))
            }
        }
        
        var textColor: Color {
            switch self {
            case .standard:
                return .secondary
            case .gradient:
                return .white
            case .accent:
                return .appAccent
            }
        }
    }
    
    init(
        text: String,
        imageName: String? = nil,
        imageUrl: String? = nil,
        size: CGFloat,
        style: AvatarStyle = .standard
    ) {
        self.text = text
        self.imageName = imageName
        self.imageUrl = imageUrl
        self.size = size
        self.style = style
    }
    
    var body: some View {
        Group {
            if let urlString = imageUrl, let url = URL(string: urlString) {
                // Remote image — cache-aware, shimmer while loading, initials on failure
                CachedAvatarImage(
                    url: url,
                    size: size,
                    onSuccess: { image in
                        AnyView(
                            image
                                .resizable()
                                .scaledToFill()
                        )
                    },
                    onFailure: {
                        AnyView(initialsView)
                    }
                )
            } else if let imageName = imageName, !imageName.isEmpty {
                // Local asset
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Initials fallback
                initialsView
            }
        }
    }
    
    private var initialsView: some View {
        Circle()
            .fill(style.background)
            .frame(width: size, height: size)
            .overlay {
                Text(String(text.prefix(1)).uppercased())
                    .font(fontForSize)
                    .fontWeight(size <= 36 ? .medium : .semibold)
                    .foregroundStyle(style.textColor)
            }
    }
    
    private var fontForSize: Font {
        switch size {
        case ...32:
            return .subheadline
        case 33...44:
            return .title3
        case 45...72:
            return .system(size: 28, weight: .semibold)
        default:
            return .largeTitle
        }
    }
}

// MARK: - Convenience Initializers

extension AvatarView {
    /// Creates a standard avatar with just text (for a name/initial)
    init(_ name: String, size: CGFloat = 44) {
        self.text = name
        self.imageName = nil
        self.imageUrl = nil
        self.size = size
        self.style = .standard
    }
    
    /// Creates a gradient avatar (typically for current user profile)
    static func gradient(name: String, imageUrl: String? = nil, size: CGFloat = 72) -> AvatarView {
        AvatarView(text: name, imageName: nil, imageUrl: imageUrl, size: size, style: .gradient)
    }
    
    /// Creates an accent-colored avatar
    static func accent(name: String, imageUrl: String? = nil, size: CGFloat = 44) -> AvatarView {
        AvatarView(text: name, imageName: nil, imageUrl: imageUrl, size: size, style: .accent)
    }
}

// MARK: - Previews

#Preview("Sizes") {
    HStack(spacing: 20) {
        AvatarView("Leo", size: 32)
        AvatarView("Leo", size: 44)
        AvatarView("Leo", size: 72)
        AvatarView("Leo", size: 80)
    }
    .padding()
}

#Preview("Styles") {
    HStack(spacing: 20) {
        AvatarView(text: "Leo", size: 72, style: .standard)
        AvatarView(text: "Leo", size: 72, style: .gradient)
        AvatarView(text: "Leo", size: 72, style: .accent)
    }
    .padding()
}

#Preview("Convenience") {
    VStack(spacing: 20) {
        AvatarView("Sarah")
        AvatarView.gradient(name: "Leo")
        AvatarView.accent(name: "Marcus")
    }
    .padding()
}
