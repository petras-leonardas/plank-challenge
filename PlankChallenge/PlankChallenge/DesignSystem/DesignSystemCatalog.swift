//
//  DesignSystemCatalog.swift
//  PlankChallenge
//
//  Design System - Main catalog entry point
//

import SwiftUI

// MARK: - Design System Category

enum DesignSystemCategory: String, CaseIterable, Identifiable {
    case colors = "Colors"
    case typography = "Typography"
    case buttons = "Buttons"
    case cards = "Cards"
    case avatars = "Avatars"
    case badges = "Badges & Pills"
    case listRows = "List Rows"
    case animations = "Animations"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .colors: return "paintpalette"
        case .typography: return "textformat"
        case .buttons: return "rectangle.and.hand.point.up.left"
        case .cards: return "rectangle.portrait"
        case .avatars: return "person.circle"
        case .badges: return "seal"
        case .listRows: return "list.bullet"
        case .animations: return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .colors: return "Color palette and gradients"
        case .typography: return "Font styles and text hierarchy"
        case .buttons: return "Button styles and states"
        case .cards: return "Card components and layouts"
        case .avatars: return "Avatar styles and sizes"
        case .badges: return "Badges, pills, and indicators"
        case .listRows: return "User rows and leaderboard items"
        case .animations: return "Animated components and effects"
        }
    }
}

// MARK: - Design System Catalog

struct DesignSystemCatalog: View {
    @State private var searchText = ""
    
    var filteredCategories: [DesignSystemCategory] {
        if searchText.isEmpty {
            return DesignSystemCategory.allCases
        }
        return DesignSystemCategory.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Header section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "swiftui")
                                .font(.largeTitle)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Plank Challenge")
                                    .font(.headline)
                                Text("Design System")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Text("Interactive component catalog for development reference")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // Categories
                Section("Components") {
                    ForEach(filteredCategories) { category in
                        NavigationLink {
                            categoryDestination(for: category)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.rawValue)
                                        .font(.body)
                                    Text(category.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Info section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Components")
                        Spacer()
                        Text("\(DesignSystemCategory.allCases.count) categories")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://developer.apple.com/design/human-interface-guidelines/")!) {
                        HStack {
                            Text("Apple HIG Reference")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Design System")
            .searchable(text: $searchText, prompt: "Search components")
        }
    }
    
    @ViewBuilder
    private func categoryDestination(for category: DesignSystemCategory) -> some View {
        switch category {
        case .colors:
            ColorsShowcase()
        case .typography:
            TypographyShowcase()
        case .buttons:
            ButtonsShowcase()
        case .cards:
            CardsShowcase()
        case .avatars:
            AvatarsShowcase()
        case .badges:
            BadgesShowcase()
        case .listRows:
            ListRowsShowcase()
        case .animations:
            AnimationsShowcase()
        }
    }
}

// MARK: - Preview

#Preview {
    DesignSystemCatalog()
}
