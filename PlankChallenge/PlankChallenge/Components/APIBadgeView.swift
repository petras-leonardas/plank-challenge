//
//  BadgeView.swift
//  PlankChallenge
//
//  A unified badge display component that replaces:
//    - `APIBadgeView` (60px, used in ProgressView horizontal scroll)
//    - `BadgesGridBadgeView` (70px, used in BadgesView grid)
//    - `ProfileAPIBadgeView` (56px, used in ProfileView horizontal scroll)
//

import SwiftUI

// MARK: - Badge Size

enum BadgeViewSize {
    /// Small — used in horizontal scroll rows (e.g. ProfileView)
    case small
    /// Medium — used in ProgressView horizontal scroll
    case medium
    /// Large — used in the full BadgesView grid (includes progress bar)
    case large
    
    var circleSize: CGFloat {
        switch self {
        case .small:  return 56
        case .medium: return 60
        case .large:  return 70
        }
    }
    
    var emojiSize: CGFloat {
        switch self {
        case .small:  return 24
        case .medium: return 28
        case .large:  return 32
        }
    }
    
    var frameWidth: CGFloat {
        switch self {
        case .small:  return 70
        case .medium: return 80
        case .large:  return 100
        }
    }
    
    var progressBarWidth: CGFloat {
        switch self {
        case .small:  return 44
        case .medium: return 50
        case .large:  return 60
        }
    }
    
    /// Whether this size shows the progress bar for locked badges
    var showsProgress: Bool {
        switch self {
        case .small:  return false
        case .medium: return true
        case .large:  return true
        }
    }
    
    /// Whether the name label allows wrapping
    var wrapsLabel: Bool {
        self == .large
    }
}

// MARK: - Badge Icon View

/// Renders a badge icon that is either an SF Symbol name or an emoji string.
/// The API returns SF Symbol names (e.g. "timer", "star") — this handles both cases.
struct BadgeIconView: View {
    let icon: String
    let size: CGFloat
    
    /// An emoji is a single Unicode scalar in the supplementary planes or
    /// has an emoji presentation selector. A quick heuristic: if the string
    /// contains only ASCII-printable characters it's an SF Symbol name.
    private var isSFSymbol: Bool {
        icon.unicodeScalars.allSatisfy { $0.value < 128 }
    }
    
    var body: some View {
        if isSFSymbol {
            Image(systemName: icon)
                .font(.system(size: size))
        } else {
            Text(icon)
                .font(.system(size: size))
        }
    }
}

// MARK: - Badge View

/// A unified badge display used in profile, progress, and the full badge catalog.
struct APIBadgeDisplayView: View {
    let badge: APIBadgeWithProgress
    var size: BadgeViewSize = .medium
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(badge.earned
                          ? Color.appAccent.opacity(0.2)
                          : Color.statCardBackground)
                    .frame(width: size.circleSize, height: size.circleSize)
                
                BadgeIconView(icon: badge.icon, size: size.emojiSize)
                    .opacity(badge.earned ? 1.0 : 0.4)
                    .grayscale(badge.earned ? 0 : 1)
                    .foregroundStyle(badge.earned ? Color.appAccent : .secondary)
            }
            
            // Badge name
            Text(badge.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(badge.earned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(size.wrapsLabel ? 2 : 1)
            
            // Progress bar for locked badges
            if !badge.earned && size.showsProgress {
                ProgressView(value: badge.progress, total: 100)
                    .frame(width: size.progressBarWidth)
                    .tint(Color.appAccent)
                
                if size == .large {
                    Text("\(Int(badge.progress))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size.frameWidth)
    }
}

// Preview intentionally omitted — APIBadgeWithProgress requires live service data.
