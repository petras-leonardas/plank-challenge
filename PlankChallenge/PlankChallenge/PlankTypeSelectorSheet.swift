//
//  PlankTypeSelectorSheet.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct PlankTypeSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: Constants.Plank.PlankType
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Plank Type") {
                    ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.rawValue)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plank Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PlankTypeSelectorSheet(selectedType: .constant(.elbow))
}
