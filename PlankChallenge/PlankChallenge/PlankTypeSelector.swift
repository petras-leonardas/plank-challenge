//
//  PlankTypeSelector.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

/// Selector for choosing plank type with detailed rows
struct PlankTypeSelector: View {
    @Binding var selectedType: Constants.Plank.PlankType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plank Type")
                .font(.headline)
            
            ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                PlankTypeRow(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    selectedType = type
                }
            }
        }
    }
}

struct PlankTypeRow: View {
    let type: Constants.Plank.PlankType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.appAccent : .secondary)
                
                VStack(alignment: .leading) {
                    Text(type.rawValue)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.appAccent.opacity(0.1) : Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlankTypeSelector(selectedType: .constant(.elbow))
        .padding()
}
