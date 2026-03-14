//
//  PlankDetailView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct PlankDetailView: View {
    let session: PlankSession
    @State private var selectedPlankType: Constants.Plank.PlankType
    @State private var hasChanges = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    init(session: PlankSession) {
        self.session = session
        _selectedPlankType = State(initialValue: session.plankType)
    }
    
    private var canDelete: Bool {
        session.date.isToday
    }
    
    var body: some View {
        List {
            Section("Duration") {
                HStack {
                    Text(session.durationSeconds.formattedDurationWithMilliseconds)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                    
                    Spacer()
                    
                    Image(systemName: session.inputMethod == .timer ? "timer" : "hand.tap")
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Date & Time") {
                LabeledContent("Date", value: session.date.formattedDate)
                LabeledContent("Time", value: session.date.formattedTime)
            }
            
            Section("Plank Type") {
                Picker("Type", selection: $selectedPlankType) {
                    ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPlankType) { _, _ in
                    hasChanges = true
                }
            }
            
            if canDelete {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Plank")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("You can only delete today's plank. After midnight, this entry will be locked.")
                }
            }
        }
        .navigationTitle("Plank Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Save changes - will be implemented in Phase 3
                        hasChanges = false
                    }
                }
            }
        }
        .alert("Delete Plank?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete in Phase 3
                dismiss()
            }
        } message: {
            Text("This will remove your plank entry for today. You can enter a new one before midnight.")
        }
    }
}

#Preview {
    NavigationStack {
        PlankDetailView(
            session: PlankSession(
                date: Date(),
                durationSeconds: 125.5,
                plankType: .elbow,
                inputMethod: .timer
            )
        )
    }
}
