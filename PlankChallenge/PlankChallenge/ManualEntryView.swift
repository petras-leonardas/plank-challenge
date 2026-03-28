//
//  ManualEntryView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.plankService) private var plankService
    @Environment(\.streakService) private var streakService
    @Environment(\.badgeService) private var badgeService
    @Environment(\.leaderboardService) private var leaderboardService
    
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    
    /// Minimum duration for manual entry (10 seconds)
    private static let minimumManualDurationSeconds: TimeInterval = 10
    
    private var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }
    
    private var isValidDuration: Bool {
        totalSeconds >= Self.minimumManualDurationSeconds &&
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
                    Text("Min: 10 seconds · Max: 60 minutes")
                        .font(.caption)
                }
                
                Section {
                    Button {
                        Task {
                            await submitEntry()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Text("Add Plank")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValidDuration || isSubmitting || plankService.hasPlankToday)
                } footer: {
                    if plankService.hasPlankToday {
                        Text("You've already submitted a plank today. Delete it from Settings to re-submit.")
                            .font(.caption)
                    } else {
                        Text("One plank per day. Your time will be saved to today's record.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Plank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("Couldn't add plank", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(isSubmitting)
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
            .disabled(isSubmitting)
            
            Picker("Seconds", selection: $seconds) {
                ForEach(0..<60, id: \.self) { second in
                    Text("\(second) sec").tag(second)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 120)
            .disabled(isSubmitting)
        }
        .frame(height: 150)
    }
    
    private func submitEntry() async {
        guard isValidDuration else {
            errorMessage = "Duration must be between 10 seconds and 60 minutes."
            showingError = true
            return
        }
        
        // Belt-and-suspenders guard — the button should already be disabled
        guard !plankService.hasPlankToday else {
            errorMessage = "You've already submitted a plank today. Delete it from Settings to re-submit."
            showingError = true
            return
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            let response = try await plankService.createPlank(
                durationSeconds: totalSeconds,
                inputMethod: .manual
            )
            
            // Apply streak data returned inline — no extra network round-trip needed
            if let streak = response.streak {
                streakService.applyInlineStreakUpdate(
                    current: streak.current,
                    longest: streak.longest
                )
            }
            
            // If new badges were earned, fetch the full badge list
            if let badges = response.badges, !badges.newlyEarned.isEmpty {
                try? await badgeService.fetchAvailableBadges()
            }
            
            // Mark leaderboard stale — user's rank may have changed after this plank
            leaderboardService.markStale()
            
            // Schedule a background full streak refresh to pick up calendar
            // activity, freeze tokens, and other fields not in the inline response
            Task {
                try? await streakService.fetchStreak()
            }
            
            dismiss()
            
        } catch let error as PlankServiceError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Something went wrong. Try again."
            showingError = true
        }
    }
}

#Preview {
    ManualEntryView()
        .withMockServices()
}
