//
//  SettingsView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()
    @State private var showingAbout = false
    @State private var showingDiscardAllAlert = false
    @State private var plankIndexToDelete: Int? = nil
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    
    // Sound settings (synced with PlankTimerView via AppStorage)
    @AppStorage("soundEnabled") private var soundEnabled = true
    
    // Today's plank data (shared with PlankTimerView)
    @AppStorage("todayPlankDate") private var todayPlankDateString = ""
    @AppStorage("todayPlankTotalTime") private var todayPlankTotalTime: Double = 0
    @AppStorage("todayPlankCount") private var todayPlankCount: Int = 0
    @AppStorage("todayPlankTimesJSON") private var todayPlankTimesJSON: String = "[]"
    
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
    
    /// Format a plank duration
    private func formatPlankTime(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Notifications Section
                Section("Notifications") {
                    Toggle("Daily Reminder", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
                
                // Timer Section
                Section {
                    Toggle("Timer Sounds", isOn: $soundEnabled)
                } header: {
                    Text("Timer")
                } footer: {
                    Text("Play countdown beeps and completion sounds during planks")
                }
                
                // Preferences Section
                Section("Preferences") {
                    Picker("Default Plank Type", selection: $selectedPlankType) {
                        ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                // Data Management Section - Today's Planks
                Section {
                    if todayPlankTimes.isEmpty {
                        HStack {
                            Text("No planks today")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // List of planks - most recent first (reversed from storage order)
                        ForEach(Array(todayPlankTimes.reversed().enumerated()), id: \.offset) { index, duration in
                            HStack {
                                Text(formatPlankTime(duration))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                if index == 0 {
                                    Text("Latest")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    // Convert display index back to storage index
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
                                Text("Discard All")
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Today's Planks")
                } footer: {
                    if !todayPlankTimes.isEmpty {
                        Text("Swipe left on a plank to delete it.")
                    }
                }
                
                // Account Section
                Section("Account") {
                    NavigationLink {
                        Text("Account settings coming soon")
                    } label: {
                        Label("Account", systemImage: "person.circle")
                    }
                    
                    NavigationLink {
                        Text("Privacy settings coming soon")
                    } label: {
                        Label("Privacy", systemImage: "lock.shield")
                    }
                }
                
                // Support Section
                Section("Support") {
                    Button {
                        // Open email or feedback form
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    
                    Button {
                        // Open app store for rating
                    } label: {
                        Label("Rate App", systemImage: "star")
                    }
                    
                    Button {
                        showingAbout = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
                
                // Version Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            // Alert for deleting individual plank
            .alert("Delete Plank?", isPresented: .init(
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
                    Text("Delete this \(formatPlankTime(todayPlankTimes[index])) plank? This cannot be undone.")
                } else {
                    Text("Delete this plank? This cannot be undone.")
                }
            }
            // Alert for discarding all planks
            .alert("Discard All Planks?", isPresented: $showingDiscardAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Discard All", role: .destructive) {
                    discardAllPlanks()
                }
            } message: {
                Text("This will remove all \(todayPlankCount) plank\(todayPlankCount == 1 ? "" : "s") you did today (\(formattedTodayTime) total). This cannot be undone.")
            }
        }
    }
    
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
    }
    
    /// Discard all of today's planks
    private func discardAllPlanks() {
        // Reset today's plank data
        todayPlankTotalTime = 0
        todayPlankCount = 0
        todayPlankTimesJSON = "[]"
        
        // TODO: Also remove from MockDataService if needed
        // For now, only clearing the AppStorage values
        // which will reset the timer view to ready state
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon & Name
                    VStack(spacing: 12) {
                        Image(systemName: "figure.core.training")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.appAccent)
                        
                        Text("Plank Challenge")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Description
                    Text("Build your core strength one plank at a time. Track your progress, maintain streaks, and compete with friends.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Links
                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://example.com/privacy")!) {
                            Text("Privacy Policy")
                                .font(.subheadline)
                        }
                        
                        Link(destination: URL(string: "https://example.com/terms")!) {
                            Text("Terms of Service")
                                .font(.subheadline)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
