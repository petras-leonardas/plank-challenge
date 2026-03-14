//
//  ComponentShowcase.swift
//  PlankChallenge
//
//  Design System - Helper view for showcasing components
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Component Showcase Wrapper

/// A container for displaying a component with its title, description, and code snippet
struct ComponentShowcase<Content: View>: View {
    let title: String
    let description: String?
    let code: String?
    let content: Content
    
    @State private var showCode = false
    
    init(
        _ title: String,
        description: String? = nil,
        code: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.code = code
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Code toggle button
                if code != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCode.toggle()
                        }
                    } label: {
                        Image(systemName: showCode ? "eye.slash" : "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Component preview
            content
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            
            // Code snippet (expandable)
            if showCode, let code {
                CodeSnippetView(code: code)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Code Snippet View

struct CodeSnippetView: View {
    let code: String
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Usage")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(.caption2)
                    .foregroundStyle(copied ? .green : .secondary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Section Divider

struct ShowcaseSectionHeader: View {
    let title: String
    let icon: String?
    
    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let name: String
    let color: Color
    let hexValue: String?
    
    init(_ name: String, color: Color, hex: String? = nil) {
        self.name = name
        self.color = color
        self.hexValue = hex
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            
            if let hexValue {
                Text(hexValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
        }
    }
}

// MARK: - Typography Sample

struct TypographySample: View {
    let name: String
    let font: Font
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The quick brown fox")
                .font(font)
            
            HStack {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            ShowcaseSectionHeader("Example Section", icon: "star")
            
            ComponentShowcase(
                "Example Component",
                description: "This is a sample component showcase",
                code: """
                Text("Hello, World!")
                    .font(.headline)
                """
            ) {
                Text("Hello, World!")
                    .font(.headline)
            }
            
            ComponentShowcase(
                "Color Swatches",
                description: "Example color display"
            ) {
                HStack(spacing: 12) {
                    ColorSwatch("Blue", color: .blue, hex: "#007AFF")
                    ColorSwatch("Green", color: .green, hex: "#34C759")
                    ColorSwatch("Orange", color: .orange, hex: "#FF9500")
                }
            }
        }
    }
}
