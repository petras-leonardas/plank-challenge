//
//  MediaGalleryView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import SwiftUI

/// A horizontal scrolling gallery of fitness photos, inspired by Strava's media gallery
struct MediaGalleryView: View {
    let images: [MediaItem]
    let personalBestTime: String?
    let personalBestDate: Date?
    var onAllMediaTapped: (() -> Void)? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Photo thumbnails
                ForEach(images) { item in
                    MediaThumbnail(item: item)
                }
                
                // Results card (Personal Best)
                if let bestTime = personalBestTime {
                    ResultsCard(
                        title: "Personal Best",
                        value: bestTime,
                        subtitle: personalBestDate?.shortFormatted
                    )
                    .frame(width: 100, height: 100)
                }
                
                // "All media" link
                if images.count > 0 {
                    AllMediaButton(count: images.count, onTap: onAllMediaTapped)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Media Item Model

struct MediaItem: Identifiable {
    let id = UUID()
    let imageName: String  // SF Symbol or asset name for mock
    let isSystemImage: Bool
    let date: Date?
    
    init(imageName: String, isSystemImage: Bool = true, date: Date? = nil) {
        self.imageName = imageName
        self.isSystemImage = isSystemImage
        self.date = date
    }
}

// MARK: - Media Thumbnail

struct MediaThumbnail: View {
    let item: MediaItem
    
    var body: some View {
        ZStack {
            // Background placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Placeholder image icon
            if item.isSystemImage {
                Image(systemName: item.imageName)
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            } else {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - All Media Button

struct AllMediaButton: View {
    let count: Int
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                
                Text("All media")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Extension

extension Date {
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
}

// MARK: - Mock Data

extension MediaItem {
    static let mockItems: [MediaItem] = [
        MediaItem(imageName: "figure.core.training", date: Date().addingTimeInterval(-86400 * 2)),
        MediaItem(imageName: "figure.strengthtraining.traditional", date: Date().addingTimeInterval(-86400 * 5)),
        MediaItem(imageName: "figure.mixed.cardio", date: Date().addingTimeInterval(-86400 * 10)),
        MediaItem(imageName: "figure.highintensity.intervaltraining", date: Date().addingTimeInterval(-86400 * 15))
    ]
}

#Preview {
    VStack {
        MediaGalleryView(
            images: MediaItem.mockItems,
            personalBestTime: "2:45",
            personalBestDate: Date().addingTimeInterval(-86400 * 3)
        )
    }
    .padding(.vertical)
}
