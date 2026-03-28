//
//  SettingsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.authService) private var authService
    @Environment(\.plankService) private var plankService
    @Environment(\.streakService) private var streakService
    @Environment(\.leaderboardService) private var leaderboardService
    
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()
    @State private var showingDiscardAllAlert = false
    @State private var plankIndexToDelete: Int? = nil
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false
    @State private var showingSignOutAlert = false
    @State private var isSigningOut = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    
    // Sound settings (synced with PlankTimerView via AppStorage)
    @AppStorage("soundEnabled") private var soundEnabled = true
    
    // Today's plank data (shared with PlankTimerView)
    @AppStorage("todayPlankDate") private var todayPlankDateString = ""
    @AppStorage("todayPlankTotalTime") private var todayPlankTotalTime: Double = 0
    @AppStorage("todayPlankCount") private var todayPlankCount: Int = 0
    @AppStorage("todayPlankTimesJSON") private var todayPlankTimesJSON: String = "[]"
    
    // MARK: - App Information
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Get today's plank times as an array (most recent last in storage)
    private var todayPlankTimes: [Double] {
        guard let data = todayPlankTimesJSON.data(using: .utf8),
              let times = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return times
    }
    
    /// Format today's total plank time
    private var formattedTodayTime: String {
        let totalSeconds = Int(todayPlankTotalTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    
    var body: some View {
        NavigationStack {
            Form {
                // Notifications Section
                Section("Notifications") {
                    Toggle("Daily reminder", isOn: $notificationsEnabled)
                        .accessibilityHint("Enable or disable daily plank reminders")
                    
                    if notificationsEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .accessibilityLabel("Set reminder time")
                    }
                }
                
                // Timer Section
                Section {
                    Toggle("Timer sounds", isOn: $soundEnabled)
                        .accessibilityHint("Enable or disable countdown sounds during planks")
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Plays countdown beeps and a chime when your plank ends")
                }
                
                // Data Management Section - Today's Planks
                Section {
                    if todayPlankTimes.isEmpty {
                        HStack {
                            Text("Nothing yet today — go hold a plank")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("No planks recorded today")
                    } else {
                        // List of planks - most recent first (reversed from storage order)
                        ForEach(Array(todayPlankTimes.reversed().enumerated()), id: \.offset) { index, duration in
                            HStack {
                                Text(duration.formattedPlankTime)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                if index == 0 {
                                    Text("Latest")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityLabel("Plank duration \(duration.formattedPlankTime)\(index == 0 ? ", latest" : "")")
                            .accessibilityHint("Swipe left to delete, or use context menu")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    // Convert display index back to storage index
                                    let storageIndex = todayPlankTimes.count - 1 - index
                                    plankIndexToDelete = storageIndex
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    let storageIndex = todayPlankTimes.count - 1 - index
                                    plankIndexToDelete = storageIndex
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        // Discard All button
                        Button(role: .destructive) {
                            showingDiscardAllAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Discard All")
                                }
                                Spacer()
                            }
                        }
                        .disabled(isDeleting)
                        .accessibilityLabel("Discard all planks")
                        .accessibilityHint("Remove all planks recorded today")
                    }
                } header: {
                    Text("Today's Planks")
                } footer: {
                    if !todayPlankTimes.isEmpty {
                        Text("Swipe left on a plank to delete it")
                    }
                }
                
                // Account Section
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            if isSigningOut {
                                ProgressView()
                                    .tint(.red)
                                Text("Signing out...")
                                    .foregroundStyle(.red)
                            } else {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(isSigningOut || isDeletingAccount)
                    .accessibilityHint("Signs you out of your account")
                }
                
                // Delete Account Section (required for App Store — Guideline 5.1.1)
                Section {
                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(.red)
                                Text("Deleting your account...")
                                    .foregroundStyle(.red)
                            } else {
                                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .disabled(isSigningOut || isDeletingAccount)
                    .accessibilityHint("Permanently deletes your account and all data")
                } footer: {
                    Text("Permanently deletes your account, all your planks, streaks, and badges. This can't be undone.")
                        .font(.caption)
                }
                
                // Version Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Version \(appVersion), build \(buildNumber)")
                }
            }
            .navigationTitle("Settings")
            // Alert for deleting individual plank
            .alert("Delete this plank?", isPresented: .init(
                get: { plankIndexToDelete != nil },
                set: { if !$0 { plankIndexToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    plankIndexToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let index = plankIndexToDelete {
                        deletePlank(at: index)
                    }
                    plankIndexToDelete = nil
                }
            } message: {
                if let index = plankIndexToDelete, index < todayPlankTimes.count {
                    Text("Removes your \(todayPlankTimes[index].formattedPlankTime) plank. It can't be undone.")
                } else {
                    Text("Removes this plank. It can't be undone.")
                }
            }
            // Alert for discarding all planks
            .alert("Discard all today's planks?", isPresented: $showingDiscardAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Discard All", role: .destructive) {
                    Task {
                        await discardAllPlanks()
                    }
                }
            } message: {
                Text("This removes all \(todayPlankCount) plank\(todayPlankCount == 1 ? "" : "s") from today (\(formattedTodayTime) total). It can't be undone.")
            }
            // Error alert for delete failures
            .alert("Delete failed", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) {
                    deleteError = nil
                }
            } message: {
                Text(deleteError ?? "Something went wrong. Try again.")
            }
            // Sign out confirmation
            .alert("Sign out?", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
            // Delete account confirmation — two-step to prevent accidental deletion
            .alert("Delete your account?", isPresented: $showingDeleteAccountAlert) {
                Button("Keep my account", role: .cancel) { }
                Button("Yes, delete everything", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("Everything goes — your planks, streak, badges, and groups. This can't be undone.")
            }
        }
    }
    
    // MARK: - Sign Out
    
    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        await authService.signOut()
    }
    
    // MARK: - Delete Account
    
    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        
        do {
            try await authService.deleteAccount()
            // authService.deleteAccount() clears tokens and sets state to .unauthenticated
            // RootView observes this and navigates back to the auth screen automatically
        } catch let authError as AuthError {
            deleteError = authError.localizedDescription
            showingDeleteError = true
        } catch {
            deleteError = error.localizedDescription
            showingDeleteError = true
        }
    }
    
    // MARK: - Actions
    
    /// Delete a single plank at the given index (in storage order)
    private func deletePlank(at index: Int) {
        var times = todayPlankTimes
        guard index >= 0 && index < times.count else { return }
        
        // Get the duration to subtract from total
        let duration = times[index]
        
        // Remove from array
        times.remove(at: index)
        
        // Update storage
        if let data = try? JSONEncoder().encode(times),
           let json = String(data: data, encoding: .utf8) {
            todayPlankTimesJSON = json
        }
        
        // Update counts
        todayPlankTotalTime -= duration
        todayPlankCount -= 1
        
        // Ensure we don't go negative due to floating point issues
        if todayPlankTotalTime < 0 { todayPlankTotalTime = 0 }
        if todayPlankCount < 0 { todayPlankCount = 0 }
        
        // Note: We only clear local storage here. The planks are already synced to the backend
        // via PlankService when they were created. If you need to delete from backend,
        // you would call plankService.deletePlank(id:) - but for "today's planks" management,
        // we're managing local state since these may not have been synced yet.
    }
    
    /// Discard all of today's planks
    private func discardAllPlanks() async {
        isDeleting = true
        defer { isDeleting = false }
        
        // Get today's planks from the service that might need backend deletion
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // YYYY-MM-DD
        let todaysAPIplanks = plankService.planks.filter { plank in
            plank.performedAt.hasPrefix(String(today))
        }
        
        // Delete from backend if there are synced planks.
        // Capture the last successful delete response — it contains the most
        // up-to-date recalculated streak after all deletions have been applied.
        var failedCount = 0
        var lastDeleteResponse: PlankDeleteResponse? = nil
        for plank in todaysAPIplanks {
            do {
                lastDeleteResponse = try await plankService.deletePlank(plank.id)
            } catch {
                failedCount += 1
                #if DEBUG
                print("[Settings] Failed to delete plank \(plank.id) from backend: \(error)")
                #endif
            }
        }
        
        // Apply the inline streak update from the last delete response
        if let streak = lastDeleteResponse?.streak {
            streakService.applyInlineStreakUpdate(
                current: streak.current,
                longest: streak.longest
            )
            // Schedule a background full streak refresh
            Task {
                try? await streakService.fetchStreak()
            }
        }
        
        // Mark leaderboard stale — deleting planks may affect the user's rank
        if lastDeleteResponse != nil {
            leaderboardService.markStale()
        }
        
        // Clear local storage regardless of backend success
        todayPlankTotalTime = 0
        todayPlankCount = 0
        todayPlankTimesJSON = "[]"
        
        // Inform the user if any backend deletions failed
        if failedCount > 0 {
            deleteError = "\(failedCount) plank\(failedCount == 1 ? "" : "s") could not be removed from the server. Your local data has been cleared, but they may reappear after the next sync."
            showingDeleteError = true
        }
    }
    
}

#Preview {
    SettingsView()
        .withMockServices()
}
