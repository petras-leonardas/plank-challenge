//
//  ManualEntryView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var mockData: MockDataService { MockDataService.shared }
    
    private var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }
    
    private var isValidDuration: Bool {
        totalSeconds >= Constants.Plank.minimumDurationSeconds &&
        totalSeconds <= Constants.Plank.maximumDurationSeconds
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    durationPicker
                } header: {
                    Text("Duration")
                } footer: {
                    Text("Minimum: 10 seconds • Maximum: 1 hour")
                        .font(.caption)
                }
                
                Section("Plank Type") {
                    Picker("Type", selection: $selectedPlankType) {
                        ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section {
                    Button {
                        submitEntry()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Submit Plank")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValidDuration)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual entries can only be submitted for today.")
                        Text("You can delete and re-enter until the end of the day.")
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var durationPicker: some View {
        HStack {
            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60, id: \.self) { minute in
                    Text("\(minute) min").tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 120)
            
            Picker("Seconds", selection: $seconds) {
                ForEach(0..<60, id: \.self) { second in
                    Text("\(second) sec").tag(second)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 120)
        }
        .frame(height: 150)
    }
    
    private func submitEntry() {
        guard isValidDuration else {
            errorMessage = "Please enter a valid duration between 10 seconds and 1 hour."
            showingError = true
            return
        }
        
        let session = PlankSession(
            durationSeconds: totalSeconds,
            plankType: selectedPlankType,
            inputMethod: .manual
        )
        mockData.addPlankSession(session)
        dismiss()
    }
}

#Preview {
    ManualEntryView()
}
