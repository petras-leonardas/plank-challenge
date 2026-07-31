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
    
    @State private var notificationsEnabled = false
    @State private var reminderTime = NotificationService.defaultReminderTime
    @State private var showingTimePicker = false
    @State private var didLoadNotificationPrefs = false
    @State private var showingDeletePlankConfirm = false
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
    
    /// Format today's total plank time (kept for potential future use)
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
                        .onChange(of: notificationsEnabled) { _, enabled in
                            guard didLoadNotificationPrefs else { return }
                            let service = NotificationService.shared
                            if enabled {
                                Task {
                                    let granted = await service.requestAuthorization()
                                    if granted {
                                        service.scheduleDailyReminder(at: reminderTime)
                                    } else {
                                        notificationsEnabled = false
                                    }
                                }
                            } else {
                                service.cancelDailyReminder()
                            }
                        }
                    
                    if notificationsEnabled {
                        Button {
                            showingTimePicker = true
                        } label: {
                            HStack {
                                Text("Reminder time")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(reminderTime, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                
                // Today's Plank — one plank per day
                Section {
                    if let todaysPlank = plankService.todaysPlank {
                        HStack {
                            Text(todaysPlank.durationSeconds.formattedPlankTime)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Today's plank: \(todaysPlank.durationSeconds.formattedPlankTime)")
                        .accessibilityHint("Swipe left to delete")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                showingDeletePlankConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(isDeleting)
                        }
                    } else {
                        Text("Nothing yet today — go hold a plank")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("No plank recorded today")
                    }
                } header: {
                    Text("Today's Plank")
                } footer: {
                    if plankService.hasPlankToday {
                        Text("Swipe left to delete today's plank. You can re-submit after deleting.")
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
            .onAppear {
                let service = NotificationService.shared
                notificationsEnabled = service.isReminderEnabled
                reminderTime = service.reminderTime
                didLoadNotificationPrefs = true
            }
            .sheet(isPresented: $showingTimePicker) {
                ReminderTimePickerSheet(
                    selectedTime: reminderTime,
                    onSave: { newTime in
                        reminderTime = newTime
                        NotificationService.shared.scheduleDailyReminder(at: newTime)
                    }
                )
                .presentationDetents([.medium])
            }
            // Confirm delete today's plank
            .alert("Delete today's plank?", isPresented: $showingDeletePlankConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteTodaysPlank() }
                }
            } message: {
                if let plank = plankService.todaysPlank {
                    Text("Removes your \(plank.durationSeconds.formattedPlankTime) plank from today. You can re-submit after deleting.")
                } else {
                    Text("Removes today's plank. You can re-submit after deleting.")
                }
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
    
    /// Delete today's single plank from the backend and clear local state.
    /// After deletion the PlankTimerView will transition back to .ready
    /// automatically via its onChange(of: todayPlankCount) observer.
    private func deleteTodaysPlank() async {
        guard let plank = plankService.todaysPlank else { return }
        
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            let response = try await plankService.deletePlank(plank.id)
            
            // Apply inline streak update returned by the delete endpoint
            let streak = response.streak
            streakService.applyInlineStreakUpdate(
                current: streak.current,
                longest: streak.longest
            )
            Task { try? await streakService.fetchStreak() }
            
            // Mark leaderboard stale — rank may have changed
            leaderboardService.markStale()
            
            // Clear all local AppStorage plank state.
            // PlankTimerView observes todayPlankCount and will transition
            // back to .ready state automatically when it hits 0.
            todayPlankTotalTime = 0
            todayPlankCount = 0
            todayPlankTimesJSON = "[]"
            
        } catch {
            deleteError = error.localizedDescription
            showingDeleteError = true
        }
    }
    
}

// MARK: - Reminder Time Picker Sheet

/// A half-sheet with a wheel time picker and Save/Cancel buttons.
private struct ReminderTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let selectedTime: Date
    let onSave: (Date) -> Void
    
    @State private var pickerTime: Date = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Reminder time",
                    selection: $pickerTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.top, 8)
                
                Spacer()
            }
            .navigationTitle("Reminder time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(pickerTime)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            pickerTime = selectedTime
        }
    }
}

#Preview {
    SettingsView()
        .withMockServices()
}
