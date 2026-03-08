# Phase 2: Mock Data & Individual Screens

**Goal:** Create all mock data needed to visualize the app, and build each screen/page as a standalone component. Focus on visual design and layout following Apple Health-inspired aesthetics.

**Outcome:** All UI screens built in isolation with mock data, ready to be connected with navigation in Phase 3.

**Prerequisites:** Phase 1 complete — project structure, models, services, and base components in place.

---

## Step 1: Create Mock Data Service

### 1.1 Create MockDataService
- [ ] Create `MockDataService.swift` in **MockData/**:

```swift
import Foundation

/// Service providing mock data for development and testing
class MockDataService {
    static let shared = MockDataService()
    
    private init() {}
    
    // MARK: - Mock Users
    
    lazy var mockUsers: [MockUser] = [
        MockUser(
            displayName: "Sarah Chen",
            profileImageName: "person.circle.fill",
            currentStreak: 127,
            longestPlankSeconds: 312, // 5:12
            totalPlanks: 245,
            badges: [.streak7, .streak14, .streak30, .streak60, .streak90]
        ),
        MockUser(
            displayName: "Marcus Johnson",
            profileImageName: "person.circle.fill",
            currentStreak: 89,
            longestPlankSeconds: 285, // 4:45
            totalPlanks: 156,
            badges: [.streak7, .streak14, .streak30, .streak60]
        ),
        MockUser(
            displayName: "Emma Wilson",
            profileImageName: "person.circle.fill",
            currentStreak: 73,
            longestPlankSeconds: 248, // 4:08
            totalPlanks: 198,
            badges: [.streak7, .streak14, .streak30, .streak60]
        ),
        MockUser(
            displayName: "David Park",
            profileImageName: "person.circle.fill",
            currentStreak: 56,
            longestPlankSeconds: 421, // 7:01 - longest plank!
            totalPlanks: 89,
            badges: [.streak7, .streak14, .streak30]
        ),
        MockUser(
            displayName: "Lisa Martinez",
            profileImageName: "person.circle.fill",
            currentStreak: 45,
            longestPlankSeconds: 195, // 3:15
            totalPlanks: 112,
            badges: [.streak7, .streak14, .streak30]
        ),
        MockUser(
            displayName: "James Thompson",
            profileImageName: "person.circle.fill",
            currentStreak: 34,
            longestPlankSeconds: 267, // 4:27
            totalPlanks: 78,
            badges: [.streak7, .streak14, .streak30]
        ),
        MockUser(
            displayName: "Nina Patel",
            profileImageName: "person.circle.fill",
            currentStreak: 28,
            longestPlankSeconds: 183, // 3:03
            totalPlanks: 65,
            badges: [.streak7, .streak14]
        ),
        MockUser(
            displayName: "Chris Anderson",
            profileImageName: "person.circle.fill",
            currentStreak: 21,
            longestPlankSeconds: 156, // 2:36
            totalPlanks: 43,
            badges: [.streak7, .streak14]
        ),
        MockUser(
            displayName: "Amy Zhang",
            profileImageName: "person.circle.fill",
            currentStreak: 18,
            longestPlankSeconds: 201, // 3:21
            totalPlanks: 52,
            badges: [.streak7, .streak14]
        ),
        MockUser(
            displayName: "Robert Kim",
            profileImageName: "person.circle.fill",
            currentStreak: 14,
            longestPlankSeconds: 142, // 2:22
            totalPlanks: 31,
            badges: [.streak7, .streak14]
        ),
        MockUser(
            displayName: "Michelle Brown",
            profileImageName: "person.circle.fill",
            currentStreak: 11,
            longestPlankSeconds: 178, // 2:58
            totalPlanks: 27,
            badges: [.streak7]
        ),
        MockUser(
            displayName: "Kevin Lee",
            profileImageName: "person.circle.fill",
            currentStreak: 9,
            longestPlankSeconds: 124, // 2:04
            totalPlanks: 19,
            badges: [.streak7]
        ),
        MockUser(
            displayName: "Jennifer Davis",
            profileImageName: "person.circle.fill",
            currentStreak: 7,
            longestPlankSeconds: 98, // 1:38
            totalPlanks: 14,
            badges: [.streak7]
        ),
        MockUser(
            displayName: "Michael Scott",
            profileImageName: "person.circle.fill",
            currentStreak: 5,
            longestPlankSeconds: 67, // 1:07
            totalPlanks: 8,
            badges: []
        ),
        MockUser(
            displayName: "Rachel Green",
            profileImageName: "person.circle.fill",
            currentStreak: 3,
            longestPlankSeconds: 45, // 0:45
            totalPlanks: 5,
            badges: []
        )
    ]
    
    // MARK: - Leaderboard Data
    
    /// Users sorted by current streak (Active Streak leaderboard)
    var streakLeaderboard: [MockUser] {
        mockUsers
            .filter { $0.currentStreak > 0 }
            .sorted { $0.currentStreak > $1.currentStreak }
    }
    
    /// Users sorted by longest plank (Longest Plank leaderboard)
    var longestPlankLeaderboard: [MockUser] {
        mockUsers
            .filter { $0.currentStreak > 0 } // Must have active streak
            .sorted { $0.longestPlankSeconds > $1.longestPlankSeconds }
    }
    
    // MARK: - Mock Groups
    
    lazy var mockGroups: [MockGroup] = [
        MockGroup(
            name: "Cloudflare Plankers",
            description: "Official Cloudflare employee plank challenge. Let's build core strength together!",
            groupType: .privateInvite,
            joinMode: .open,
            memberCount: 47,
            isCurrentUserMember: true,
            isCurrentUserAdmin: true,
            members: Array(mockUsers.prefix(10))
        ),
        MockGroup(
            name: "Weekend Warriors",
            description: "Friends challenging each other to stay consistent. No excuses!",
            groupType: .privateInvite,
            joinMode: .open,
            memberCount: 8,
            isCurrentUserMember: true,
            isCurrentUserAdmin: false,
            members: Array(mockUsers.prefix(8))
        ),
        MockGroup(
            name: "NYC Fitness Club",
            description: "New York City fitness enthusiasts. Open to all NYC plankers!",
            groupType: .publicOpen,
            joinMode: .open,
            memberCount: 234,
            isCurrentUserMember: false,
            isCurrentUserAdmin: false,
            members: Array(mockUsers.shuffled().prefix(15))
        ),
        MockGroup(
            name: "Morning Plankers",
            description: "We plank before 7am. Early bird gets the strong core!",
            groupType: .publicOpen,
            joinMode: .requestToJoin,
            memberCount: 89,
            isCurrentUserMember: false,
            isCurrentUserAdmin: false,
            members: Array(mockUsers.shuffled().prefix(12))
        ),
        MockGroup(
            name: "Tech Industry Plank Off",
            description: "Engineers, designers, and PMs competing for plank supremacy.",
            groupType: .publicOpen,
            joinMode: .open,
            memberCount: 312,
            isCurrentUserMember: false,
            isCurrentUserAdmin: false,
            members: Array(mockUsers.shuffled().prefix(15))
        ),
        MockGroup(
            name: "Beginner Plankers",
            description: "Just starting out? This is a supportive group for beginners!",
            groupType: .publicOpen,
            joinMode: .open,
            memberCount: 156,
            isCurrentUserMember: false,
            isCurrentUserAdmin: false,
            members: Array(mockUsers.suffix(10))
        ),
        MockGroup(
            name: "5-Minute Club",
            description: "Our goal: everyone hits a 5-minute plank. Elite plankers only.",
            groupType: .publicOpen,
            joinMode: .requestToJoin,
            memberCount: 23,
            isCurrentUserMember: false,
            isCurrentUserAdmin: false,
            members: Array(mockUsers.prefix(5))
        )
    ]
    
    /// Groups the current user is a member of
    var myGroups: [MockGroup] {
        mockGroups.filter { $0.isCurrentUserMember }
    }
    
    /// Public groups available to discover
    var discoverGroups: [MockGroup] {
        mockGroups.filter { $0.groupType == .publicOpen && !$0.isCurrentUserMember }
    }
    
    // MARK: - Mock Plank History
    
    func generateMockPlankHistory(days: Int = 30) -> [MockPlankSession] {
        var sessions: [MockPlankSession] = []
        let calendar = Calendar.current
        
        for dayOffset in 0..<days {
            // Skip some days randomly to simulate missed days
            if dayOffset > 0 && Int.random(in: 0...10) < 2 {
                continue
            }
            
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else {
                continue
            }
            
            // Duration increases over time with some variation
            let baseDuration: TimeInterval = 60 + Double(days - dayOffset) * 3
            let variation = Double.random(in: -15...15)
            let duration = max(30, baseDuration + variation)
            
            let plankType = Constants.Plank.PlankType.allCases.randomElement() ?? .elbow
            let inputMethod: PlankSession.InputMethod = Int.random(in: 0...10) < 8 ? .timer : .manual
            
            sessions.append(MockPlankSession(
                date: date,
                durationSeconds: duration,
                plankType: plankType,
                inputMethod: inputMethod
            ))
        }
        
        return sessions.sorted { $0.date > $1.date }
    }
    
    // MARK: - Mock Notifications
    
    lazy var mockNotifications: [MockNotification] = [
        MockNotification(
            type: .badgeEarned,
            title: "New Badge Earned!",
            message: "Congratulations! You've earned the '2 Week Champion' badge for your 14-day streak!",
            isRead: false,
            createdAt: Date().addingTimeInterval(-3600) // 1 hour ago
        ),
        MockNotification(
            type: .groupJoined,
            title: "Welcome to Cloudflare Plankers!",
            message: "You've successfully joined the group. Start planking to appear on the leaderboard!",
            isRead: true,
            createdAt: Date().addingTimeInterval(-86400 * 2) // 2 days ago
        ),
        MockNotification(
            type: .tokenEarned,
            title: "Freeze Token Earned!",
            message: "Amazing! You've reached a 20-day streak and earned a freeze token.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-86400 * 5) // 5 days ago
        ),
        MockNotification(
            type: .streakFreezeUsed,
            title: "Streak Saved!",
            message: "Your streak freeze token was used yesterday. You have 1 token remaining. Don't forget to plank today!",
            isRead: true,
            createdAt: Date().addingTimeInterval(-86400 * 10) // 10 days ago
        ),
        MockNotification(
            type: .promotedToAdmin,
            title: "You're Now an Admin",
            message: "You've been promoted to admin in 'Weekend Warriors'. You can now manage group settings.",
            isRead: true,
            createdAt: Date().addingTimeInterval(-86400 * 15) // 15 days ago
        )
    ]
    
    // MARK: - Mock Following/Followers
    
    var mockFollowing: [MockUser] {
        Array(mockUsers.prefix(6))
    }
    
    var mockFollowers: [MockUser] {
        Array(mockUsers.shuffled().prefix(8))
    }
    
    // MARK: - Current User Mock Data
    
    var currentUserStats: CurrentUserStats {
        CurrentUserStats(
            currentStreak: 14,
            longestStreak: 21,
            longestPlankSeconds: 185, // 3:05
            totalPlanks: 42,
            freezeTokens: 1,
            preferredPlankType: .elbow
        )
    }
}

// MARK: - Supporting Mock Models

struct MockGroup: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let groupType: PlankGroup.GroupType
    let joinMode: PlankGroup.JoinMode
    let memberCount: Int
    let isCurrentUserMember: Bool
    let isCurrentUserAdmin: Bool
    let members: [MockUser]
    
    var streakLeaderboard: [MockUser] {
        members.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var longestPlankLeaderboard: [MockUser] {
        members.sorted { $0.longestPlankSeconds > $1.longestPlankSeconds }
    }
}

struct MockPlankSession: Identifiable {
    let id = UUID()
    let date: Date
    let durationSeconds: TimeInterval
    let plankType: Constants.Plank.PlankType
    let inputMethod: PlankSession.InputMethod
    
    var formattedDuration: String {
        durationSeconds.formattedDuration
    }
}

struct MockNotification: Identifiable {
    let id = UUID()
    let type: AppNotification.NotificationType
    let title: String
    let message: String
    var isRead: Bool
    let createdAt: Date
}

struct CurrentUserStats {
    let currentStreak: Int
    let longestStreak: Int
    let longestPlankSeconds: TimeInterval
    let totalPlanks: Int
    let freezeTokens: Int
    let preferredPlankType: Constants.Plank.PlankType
    
    var longestPlankFormatted: String {
        longestPlankSeconds.formattedDuration
    }
}
```

### 1.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add MockDataService with comprehensive mock data"`

---

## Step 2: Build Plank Timer Screen

### 2.1 Create PlankTimerView
- [ ] Create `PlankTimerView.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct PlankTimerView: View {
    @StateObject private var timerService = TimerService()
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    @State private var showingPlankTypeSelector = false
    @State private var showingCompletionSheet = false
    @State private var completedDuration: TimeInterval = 0
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if timerService.isRunning {
                    // Active plank view
                    activePlankView
                } else {
                    // Pre-plank view
                    prePlankView
                }
            }
        }
        .sheet(isPresented: $showingPlankTypeSelector) {
            PlankTypeSelectorSheet(selectedType: $selectedPlankType)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingCompletionSheet) {
            PlankCompletionSheet(
                duration: completedDuration,
                plankType: selectedPlankType
            )
            .presentationDetents([.medium])
        }
        .keepScreenAwake(timerService.isRunning)
    }
    
    // MARK: - Pre-Plank View
    
    private var prePlankView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Plank type indicator
            plankTypeButton
            
            // Large start button
            startButton
            
            // Instructions
            Text("Tap to start your daily plank")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Manual entry option
            manualEntryLink
        }
        .padding()
    }
    
    private var plankTypeButton: some View {
        Button {
            showingPlankTypeSelector = true
        } label: {
            HStack {
                Image(systemName: "figure.core.training")
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(selectedPlankType.rawValue)
                        .font(.headline)
                    Text(selectedPlankType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private var startButton: some View {
        Button {
            timerService.start()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 200, height: 200)
                    .shadow(color: .appAccent.opacity(0.3), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 50))
                    Text("START")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var manualEntryLink: some View {
        NavigationLink {
            ManualEntryView()
        } label: {
            Text("Add time manually")
                .font(.subheadline)
                .foregroundStyle(.appAccent)
        }
    }
    
    // MARK: - Active Plank View
    
    private var activePlankView: some View {
        VStack(spacing: 0) {
            // Plank form image area
            plankFormImage
            
            Spacer()
            
            // Timer display
            timerDisplay
            
            Spacer()
            
            // Stop button
            stopButton
                .padding(.bottom, 50)
        }
    }
    
    private var plankFormImage: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
            
            // Placeholder for actual plank form image
            VStack {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                
                Text(selectedPlankType.rawValue)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 250)
    }
    
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(timerService.formattedTime)
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(timerColor)
            
            if !timerService.isAtMinimumDuration {
                Text("Keep going! Minimum 10 seconds")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Great job! Keep it up!")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var timerColor: Color {
        if timerService.isAtMinimumDuration {
            return .green
        } else {
            return .primary
        }
    }
    
    private var stopButton: some View {
        Button {
            completedDuration = timerService.elapsedTime
            timerService.stop()
            
            if completedDuration >= Constants.Plank.minimumDurationSeconds {
                showingCompletionSheet = true
            }
            
            timerService.reset()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 100, height: 100)
                    .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 30))
                    Text("STOP")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PlankTimerView()
    }
}
```

### 2.2 Create PlankTypeSelectorSheet
- [ ] Create `PlankTypeSelectorSheet.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct PlankTypeSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: Constants.Plank.PlankType
    
    var body: some View {
        NavigationStack {
            List {
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
                                    .foregroundStyle(.appAccent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plank Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
```

### 2.3 Create PlankCompletionSheet
- [ ] Create `PlankCompletionSheet.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct PlankCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let duration: TimeInterval
    let plankType: Constants.Plank.PlankType
    
    // Mock data for demonstration
    let isNewPersonalBest: Bool = false
    let newStreak: Int = 15
    let badgeEarned: Badge.BadgeType? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Celebration icon
                celebrationHeader
                
                // Duration display
                durationDisplay
                
                // Stats
                statsSection
                
                Spacer()
                
                // Done button
                doneButton
            }
            .padding()
            .navigationTitle("Plank Complete!")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var celebrationHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }
            
            if isNewPersonalBest {
                Label("New Personal Best!", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }
        }
    }
    
    private var durationDisplay: some View {
        VStack(spacing: 8) {
            Text(duration.formattedDurationWithMilliseconds)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
            
            HStack {
                Image(systemName: "figure.core.training")
                Text(plankType.rawValue)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                StatMini(title: "Streak", value: "\(newStreak)", icon: "flame.fill", color: .orange)
                StatMini(title: "Today", value: "Done", icon: "checkmark.circle.fill", color: .green)
            }
            
            if let badge = badgeEarned {
                HStack {
                    Image(systemName: "medal.fill")
                        .foregroundStyle(.yellow)
                    Text("Badge earned: \(badge.displayName)")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct StatMini: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
    }
}

#Preview {
    PlankCompletionSheet(
        duration: 125.45,
        plankType: .elbow
    )
}
```

### 2.4 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add plank timer screens: PlankTimerView, PlankTypeSelectorSheet, PlankCompletionSheet"`

---

## Step 3: Build Manual Entry Screen

### 3.1 Create ManualEntryView
- [ ] Create `ManualEntryView.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }
    
    private var isValidDuration: Bool {
        totalSeconds >= Constants.Plank.minimumDurationSeconds &&
        totalSeconds <= Constants.Plank.maximumDurationSeconds
    }
    
    var body: some View {
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
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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
        
        // In Phase 3, this will actually save the data
        // For now, just dismiss
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ManualEntryView()
    }
}
```

### 3.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add ManualEntryView for manual plank entry"`

---

## Step 4: Build Progress & History Screens

### 4.1 Create ProgressView (Main Progress Tab)
- [ ] Create `ProgressView.swift` in **Views/Progress/**:

```swift
import SwiftUI

struct ProgressView: View {
    private let mockData = MockDataService.shared
    private let mockHistory = MockDataService.shared.generateMockPlankHistory(days: 30)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Streak section
                streakSection
                
                // Stats cards
                statsSection
                
                // Progress chart
                chartSection
                
                // Recent history
                historySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
    }
    
    // MARK: - Streak Section
    
    private var streakSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(mockData.currentUserStats.currentStreak)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        
                        Text("days")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
            }
            
            // Freeze tokens
            HStack {
                TokenIndicator(tokensRemaining: mockData.currentUserStats.freezeTokens)
                Spacer()
                Text("Freeze tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Longest Plank",
                value: mockData.currentUserStats.longestPlankFormatted,
                subtitle: "personal best",
                icon: "trophy.fill",
                color: .yellow
            )
            
            StatCard(
                title: "Total Planks",
                value: "\(mockData.currentUserStats.totalPlanks)",
                subtitle: "all time",
                icon: "number",
                color: .blue
            )
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration Over Time")
                .font(.headline)
            
            // Placeholder chart
            ChartPlaceholder(data: mockHistory)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Planks")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink("See All") {
                    PlankHistoryListView()
                }
                .font(.subheadline)
            }
            
            ForEach(mockHistory.prefix(5)) { session in
                PlankHistoryRow(session: session)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Chart Placeholder

struct ChartPlaceholder: View {
    let data: [MockPlankSession]
    
    var body: some View {
        // Simple bar chart placeholder
        // Will be replaced with Swift Charts in Phase 4
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(data.prefix(14).reversed()) { session in
                let height = min(session.durationSeconds / 300 * 100, 100)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.appAccent.opacity(0.7))
                    .frame(width: 16, height: max(height, 10))
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Plank History Row

struct PlankHistoryRow: View {
    let session: MockPlankSession
    
    var body: some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.relativeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.plankType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Duration
            Text(session.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.colorForPlankType(session.plankType))
            
            // Input method indicator
            Image(systemName: session.inputMethod == .timer ? "timer" : "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        ProgressView()
    }
}
```

### 4.2 Create PlankHistoryListView
- [ ] Create `PlankHistoryListView.swift` in **Views/Progress/**:

```swift
import SwiftUI

struct PlankHistoryListView: View {
    private let mockHistory = MockDataService.shared.generateMockPlankHistory(days: 60)
    
    var body: some View {
        List {
            ForEach(groupedByMonth, id: \.key) { month, sessions in
                Section(month) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            PlankDetailView(session: session)
                        } label: {
                            PlankHistoryRow(session: session)
                        }
                    }
                }
            }
        }
        .navigationTitle("Plank History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var groupedByMonth: [(key: String, value: [MockPlankSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let grouped = Dictionary(grouping: mockHistory) { session in
            formatter.string(from: session.date)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
}

#Preview {
    NavigationStack {
        PlankHistoryListView()
    }
}
```

### 4.3 Create PlankDetailView
- [ ] Create `PlankDetailView.swift` in **Views/Progress/**:

```swift
import SwiftUI

struct PlankDetailView: View {
    let session: MockPlankSession
    @State private var selectedPlankType: Constants.Plank.PlankType
    @State private var hasChanges = false
    @State private var showingDeleteConfirmation = false
    
    init(session: MockPlankSession) {
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
                        // Save changes in Phase 3
                        hasChanges = false
                    }
                }
            }
        }
        .alert("Delete Plank?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete in Phase 3
            }
        } message: {
            Text("This will remove your plank entry for today. You can enter a new one before midnight.")
        }
    }
}

#Preview {
    NavigationStack {
        PlankDetailView(
            session: MockPlankSession(
                date: Date(),
                durationSeconds: 125.5,
                plankType: .elbow,
                inputMethod: .timer
            )
        )
    }
}
```

### 4.4 Create BadgesView
- [ ] Create `BadgesView.swift` in **Views/Progress/**:

```swift
import SwiftUI

struct BadgesView: View {
    private let earnedBadges: [Badge.BadgeType] = [.streak7, .streak14]
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Badge.BadgeType.allCases, id: \.self) { badgeType in
                    BadgeView(
                        badgeType: badgeType,
                        isEarned: earnedBadges.contains(badgeType),
                        dateEarned: earnedBadges.contains(badgeType) ? Date().addingTimeInterval(-86400 * Double(badgeType.streakDays)) : nil
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Badges")
    }
}

#Preview {
    NavigationStack {
        BadgesView()
    }
}
```

### 4.5 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add progress screens: ProgressView, PlankHistoryListView, PlankDetailView, BadgesView"`

---

## Step 5: Build Leaderboards Screens

### 5.1 Create LeaderboardsView
- [ ] Create `LeaderboardsView.swift` in **Views/Leaderboards/**:

```swift
import SwiftUI

struct LeaderboardsView: View {
    @State private var selectedTab: LeaderboardTab = .streak
    private let mockData = MockDataService.shared
    
    enum LeaderboardTab: String, CaseIterable {
        case streak = "Active Streak"
        case longestPlank = "Longest Plank"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Leaderboard", selection: $selectedTab) {
                ForEach(LeaderboardTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Leaderboard list
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Current user position
                    currentUserPosition
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Leaderboard
                    ForEach(Array(leaderboardData.enumerated()), id: \.element.id) { index, user in
                        LeaderboardRow(
                            rank: index + 1,
                            user: user,
                            value: valueForUser(user),
                            isCurrentUser: false
                        )
                        
                        if index < leaderboardData.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Leaderboards")
    }
    
    private var leaderboardData: [MockUser] {
        switch selectedTab {
        case .streak:
            return mockData.streakLeaderboard
        case .longestPlank:
            return mockData.longestPlankLeaderboard
        }
    }
    
    private func valueForUser(_ user: MockUser) -> String {
        switch selectedTab {
        case .streak:
            return "\(user.currentStreak) days"
        case .longestPlank:
            return user.longestPlankFormatted
        }
    }
    
    private var currentUserPosition: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Position")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            LeaderboardRow(
                rank: 8, // Mock position
                user: MockUser(
                    displayName: "You",
                    profileImageName: "person.circle.fill",
                    currentStreak: mockData.currentUserStats.currentStreak,
                    longestPlankSeconds: mockData.currentUserStats.longestPlankSeconds,
                    totalPlanks: mockData.currentUserStats.totalPlanks,
                    badges: []
                ),
                value: selectedTab == .streak
                    ? "\(mockData.currentUserStats.currentStreak) days"
                    : mockData.currentUserStats.longestPlankFormatted,
                isCurrentUser: true
            )
        }
        .padding()
        .background(Color.appAccent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let user: MockUser
    let value: String
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                }
                
                Text("\(rank)")
                    .font(.headline)
                    .foregroundStyle(rank <= 3 ? .white : .primary)
            }
            .frame(width: 40)
            
            // Avatar
            Image(systemName: user.profileImageName ?? "person.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                
                // Badges preview
                if !user.badges.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(user.badges.prefix(3), id: \.self) { badge in
                            Image(systemName: "medal.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Value
            Text(value)
                .font(.headline)
                .foregroundStyle(isCurrentUser ? .appAccent : .primary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
}

#Preview {
    NavigationStack {
        LeaderboardsView()
    }
}
```

### 5.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add LeaderboardsView with streak and longest plank rankings"`

---

## Step 6: Build Groups Screens

### 6.1 Create GroupsListView
- [ ] Create `GroupsListView.swift` in **Views/Groups/**:

```swift
import SwiftUI

struct GroupsListView: View {
    private let mockData = MockDataService.shared
    @State private var searchText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // My Groups
                myGroupsSection
                
                // Discover Groups
                discoverSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Groups")
        .searchable(text: $searchText, prompt: "Search groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CreateGroupView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
    
    // MARK: - My Groups Section
    
    private var myGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Groups")
                .font(.headline)
            
            if mockData.myGroups.isEmpty {
                emptyGroupsView
            } else {
                ForEach(mockData.myGroups) { group in
                    NavigationLink {
                        GroupDetailView(group: group)
                    } label: {
                        GroupRowCard(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var emptyGroupsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No groups yet")
                .font(.headline)
            
            Text("Join a group or create your own to compete with others!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Discover Section
    
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discover")
                .font(.headline)
            
            ForEach(filteredDiscoverGroups) { group in
                NavigationLink {
                    GroupDetailView(group: group)
                } label: {
                    GroupRowCard(group: group)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var filteredDiscoverGroups: [MockGroup] {
        if searchText.isEmpty {
            return mockData.discoverGroups
        }
        return mockData.discoverGroups.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Group Row Card

struct GroupRowCard: View {
    let group: MockGroup
    
    var body: some View {
        HStack(spacing: 12) {
            // Group image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(.appAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if group.groupType == .privateInvite {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if group.isCurrentUserAdmin {
                    Text("Admin")
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        GroupsListView()
    }
}
```

### 6.2 Create GroupDetailView
- [ ] Create `GroupDetailView.swift` in **Views/Groups/**:

```swift
import SwiftUI

struct GroupDetailView: View {
    let group: MockGroup
    @State private var selectedLeaderboard: LeaderboardType = .streak
    @State private var selectedTimeFilter: TimeFilter = .allTime
    @State private var showingLeaveConfirmation = false
    
    enum LeaderboardType: String, CaseIterable {
        case streak = "Streak"
        case longestPlank = "Longest"
    }
    
    enum TimeFilter: String, CaseIterable {
        case allTime = "All Time"
        case last7Days = "7 Days"
        case last30Days = "30 Days"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                groupHeader
                
                // Leaderboard section
                leaderboardSection
                
                // Members section
                membersSection
                
                // Actions
                if group.isCurrentUserMember {
                    actionsSection
                } else {
                    joinSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if group.isCurrentUserAdmin {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        GroupSettingsView(group: group)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .alert("Leave Group?", isPresented: $showingLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                // Leave group in Phase 5
            }
        } message: {
            Text("You will be removed from this group's leaderboards. If you rejoin, you'll start fresh.")
        }
    }
    
    // MARK: - Header
    
    private var groupHeader: some View {
        VStack(spacing: 12) {
            // Group image
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.3.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.appAccent)
            }
            
            // Group info
            VStack(spacing: 4) {
                HStack {
                    Text(group.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if group.groupType == .privateInvite {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("\(group.memberCount) members")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            if !group.description.isEmpty {
                Text(group.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Leaderboard Section
    
    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            // Leaderboard type picker
            Picker("Leaderboard", selection: $selectedLeaderboard) {
                ForEach(LeaderboardType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Time filter
            Picker("Time", selection: $selectedTimeFilter) {
                ForEach(TimeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            
            // Leaderboard list
            VStack(spacing: 0) {
                ForEach(Array(leaderboardData.prefix(10).enumerated()), id: \.element.id) { index, user in
                    LeaderboardRow(
                        rank: index + 1,
                        user: user,
                        value: valueForUser(user),
                        isCurrentUser: false
                    )
                    
                    if index < min(leaderboardData.count - 1, 9) {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var leaderboardData: [MockUser] {
        switch selectedLeaderboard {
        case .streak:
            return group.streakLeaderboard
        case .longestPlank:
            return group.longestPlankLeaderboard
        }
    }
    
    private func valueForUser(_ user: MockUser) -> String {
        switch selectedLeaderboard {
        case .streak:
            return "\(user.currentStreak) days"
        case .longestPlank:
            return user.longestPlankFormatted
        }
    }
    
    // MARK: - Members Section
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink {
                    GroupMembersListView(group: group)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
            }
            
            // Preview of members
            HStack(spacing: -10) {
                ForEach(group.members.prefix(5)) { member in
                    Image(systemName: member.profileImageName ?? "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
                
                if group.memberCount > 5 {
                    Text("+\(group.memberCount - 5)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Button(role: .destructive) {
            showingLeaveConfirmation = true
        } label: {
            HStack {
                Spacer()
                Text("Leave Group")
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Join Section
    
    private var joinSection: some View {
        Button {
            // Join group in Phase 5
        } label: {
            HStack {
                Spacer()
                Text(group.joinMode == .requestToJoin ? "Request to Join" : "Join Group")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color.appAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: MockDataService.shared.mockGroups[0])
    }
}
```

### 6.3 Create GroupMembersListView
- [ ] Create `GroupMembersListView.swift` in **Views/Groups/**:

```swift
import SwiftUI

struct GroupMembersListView: View {
    let group: MockGroup
    @State private var searchText = ""
    
    var body: some View {
        List {
            ForEach(filteredMembers) { member in
                NavigationLink {
                    UserProfileView(user: member)
                } label: {
                    MemberRow(member: member, isAdmin: group.members.first?.id == member.id)
                }
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search members")
    }
    
    private var filteredMembers: [MockUser] {
        if searchText.isEmpty {
            return group.members
        }
        return group.members.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct MemberRow: View {
    let member: MockUser
    let isAdmin: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: member.profileImageName ?? "person.circle.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.displayName)
                        .font(.body)
                    
                    if isAdmin {
                        Text("Admin")
                            .font(.caption)
                            .foregroundStyle(.appAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appAccent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(member.currentStreak) day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupMembersListView(group: MockDataService.shared.mockGroups[0])
    }
}
```

### 6.4 Create CreateGroupView
- [ ] Create `CreateGroupView.swift` in **Views/Groups/**:

```swift
import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isPrivate = false
    @State private var requiresApproval = false
    @State private var showingImagePicker = false
    
    private var isValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        Form {
            Section("Group Info") {
                // Group image
                HStack {
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundStyle(.appAccent)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                TextField("Group Name", text: $groupName)
                
                TextField("Description (optional)", text: $groupDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Privacy") {
                Toggle("Private Group", isOn: $isPrivate)
                
                if !isPrivate {
                    Toggle("Require Approval to Join", isOn: $requiresApproval)
                }
            } footer: {
                if isPrivate {
                    Text("Private groups are not searchable. You'll need to invite members.")
                } else if requiresApproval {
                    Text("You'll need to approve each join request.")
                } else {
                    Text("Anyone can find and join this group.")
                }
            }
            
            Section {
                Button {
                    createGroup()
                } label: {
                    HStack {
                        Spacer()
                        Text("Create Group")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle("Create Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func createGroup() {
        // Create group in Phase 5
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CreateGroupView()
    }
}
```

### 6.5 Create GroupSettingsView
- [ ] Create `GroupSettingsView.swift` in **Views/Groups/**:

```swift
import SwiftUI

struct GroupSettingsView: View {
    let group: MockGroup
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String
    @State private var groupDescription: String
    @State private var requiresApproval: Bool
    @State private var showingDeleteConfirmation = false
    
    init(group: MockGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _groupDescription = State(initialValue: group.description)
        _requiresApproval = State(initialValue: group.joinMode == .requestToJoin)
    }
    
    var body: some View {
        Form {
            Section("Group Info") {
                TextField("Group Name", text: $groupName)
                TextField("Description", text: $groupDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            if group.groupType == .publicOpen {
                Section("Join Settings") {
                    Toggle("Require Approval", isOn: $requiresApproval)
                }
            }
            
            Section("Members") {
                NavigationLink {
                    GroupMembersListView(group: group)
                } label: {
                    HStack {
                        Text("Manage Members")
                        Spacer()
                        Text("\(group.memberCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Group")
                        Spacer()
                    }
                }
            } footer: {
                Text("This will permanently delete the group and remove all members.")
            }
        }
        .navigationTitle("Group Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Save in Phase 5
                    dismiss()
                }
            }
        }
        .alert("Delete Group?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete in Phase 5
                dismiss()
            }
        } message: {
            Text("All \(group.memberCount) members will be removed and notified. This cannot be undone.")
        }
    }
}

#Preview {
    NavigationStack {
        GroupSettingsView(group: MockDataService.shared.mockGroups[0])
    }
}
```

### 6.6 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add groups screens: GroupsListView, GroupDetailView, GroupMembersListView, CreateGroupView, GroupSettingsView"`

---

## Step 7: Build Profile Screens

### 7.1 Create ProfileView (Current User)
- [ ] Create `ProfileView.swift` in **Views/Profile/**:

```swift
import SwiftUI

struct ProfileView: View {
    private let mockData = MockDataService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                profileHeader
                
                // Stats
                statsSection
                
                // Badges
                badgesSection
                
                // Social links
                socialSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.secondary)
                
                NavigationLink {
                    EditProfileView()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title)
                        .foregroundStyle(.appAccent)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
            
            // Name
            Text("Leo") // Would come from user profile
                .font(.title)
                .fontWeight(.bold)
            
            // Bio
            Text("Plank enthusiast. Building core strength one day at a time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Follow stats
            HStack(spacing: 32) {
                NavigationLink {
                    FollowListView(type: .following)
                } label: {
                    VStack {
                        Text("\(mockData.mockFollowing.count)")
                            .font(.headline)
                        Text("Following")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                NavigationLink {
                    FollowListView(type: .followers)
                } label: {
                    VStack {
                        Text("\(mockData.mockFollowers.count)")
                            .font(.headline)
                        Text("Followers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(
                    title: "Current Streak",
                    value: "\(mockData.currentUserStats.currentStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Longest Streak",
                    value: "\(mockData.currentUserStats.longestStreak)",
                    subtitle: "days",
                    icon: "trophy.fill",
                    color: .yellow
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Longest Plank",
                    value: mockData.currentUserStats.longestPlankFormatted,
                    subtitle: "personal best",
                    icon: "timer",
                    color: .green
                )
                
                StatCard(
                    title: "Total Planks",
                    value: "\(mockData.currentUserStats.totalPlanks)",
                    subtitle: "all time",
                    icon: "number",
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Badges")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink {
                    BadgesView()
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach([Badge.BadgeType.streak7, .streak14], id: \.self) { badge in
                        BadgeView(
                            badgeType: badge,
                            isEarned: true,
                            dateEarned: Date()
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Social Section
    
    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Links")
                .font(.headline)
            
            HStack(spacing: 16) {
                Link(destination: URL(string: "https://linkedin.com")!) {
                    Label("LinkedIn", systemImage: "link")
                        .font(.subheadline)
                }
                
                Link(destination: URL(string: "https://twitter.com")!) {
                    Label("Twitter", systemImage: "link")
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
```

### 7.2 Create UserProfileView (Other Users)
- [ ] Create `UserProfileView.swift` in **Views/Profile/**:

```swift
import SwiftUI

struct UserProfileView: View {
    let user: MockUser
    @State private var isFollowing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile header
                profileHeader
                
                // Stats
                statsSection
                
                // Badges
                if !user.badges.isEmpty {
                    badgesSection
                }
                
                // Plank history preview
                historySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            Image(systemName: user.profileImageName ?? "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            // Name
            Text(user.displayName)
                .font(.title2)
                .fontWeight(.bold)
            
            // Follow button
            Button {
                isFollowing.toggle()
            } label: {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color(.secondarySystemGroupedBackground) : Color.appAccent)
                    .foregroundStyle(isFollowing ? .primary : .white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Current Streak",
                value: "\(user.currentStreak)",
                subtitle: "days",
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Longest Plank",
                value: user.longestPlankFormatted,
                icon: "timer",
                color: .green
            )
        }
    }
    
    // MARK: - Badges Section
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(user.badges, id: \.self) { badge in
                        BadgeView(
                            badgeType: badge,
                            isEarned: true,
                            dateEarned: nil
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Planks")
                .font(.headline)
            
            Text("Plank history would appear here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        UserProfileView(user: MockDataService.shared.mockUsers[0])
    }
}
```

### 7.3 Create EditProfileView
- [ ] Create `EditProfileView.swift` in **Views/Profile/**:

```swift
import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = "Leo"
    @State private var bio = "Plank enthusiast. Building core strength one day at a time."
    @State private var linkedInLink = ""
    @State private var socialLink = ""
    @State private var showingImagePicker = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                            
                            Image(systemName: "camera.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.appAccent)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            Section("Profile") {
                TextField("Display Name", text: $displayName)
                
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Social Links") {
                TextField("LinkedIn URL", text: $linkedInLink)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                
                TextField("Other Social URL", text: $socialLink)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Save in Phase 5
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
    }
}
```

### 7.4 Create FollowListView
- [ ] Create `FollowListView.swift` in **Views/Profile/**:

```swift
import SwiftUI

struct FollowListView: View {
    let type: FollowType
    private let mockData = MockDataService.shared
    @State private var searchText = ""
    
    enum FollowType {
        case following
        case followers
        
        var title: String {
            switch self {
            case .following: return "Following"
            case .followers: return "Followers"
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredUsers) { user in
                NavigationLink {
                    UserProfileView(user: user)
                } label: {
                    FollowUserRow(user: user)
                }
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search")
    }
    
    private var users: [MockUser] {
        switch type {
        case .following:
            return mockData.mockFollowing
        case .followers:
            return mockData.mockFollowers
        }
    }
    
    private var filteredUsers: [MockUser] {
        if searchText.isEmpty {
            return users
        }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct FollowUserRow: View {
    let user: MockUser
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: user.profileImageName ?? "person.circle.fill")
                .font(.title)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body)
                
                Text("\(user.currentStreak) day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FollowListView(type: .following)
    }
}
```

### 7.5 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add profile screens: ProfileView, UserProfileView, EditProfileView, FollowListView"`

---

## Step 8: Build Settings Screen

### 8.1 Create SettingsView
- [ ] Create `SettingsView.swift` in **Views/Settings/**:

```swift
import SwiftUI

struct SettingsView: View {
    @State private var preferredPlankType: Constants.Plank.PlankType = .elbow
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()
    
    var body: some View {
        Form {
            Section("Plank Preferences") {
                Picker("Preferred Plank Type", selection: $preferredPlankType) {
                    ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            
            Section("Notifications") {
                Toggle("Daily Reminder", isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                }
            } footer: {
                Text("We'll remind you to complete your daily plank.")
            }
            
            Section("About") {
                LabeledContent("Version", value: AppConfig.AppInfo.appVersion)
                LabeledContent("Build", value: AppConfig.AppInfo.buildNumber)
                
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    Text("Privacy Policy")
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    Text("Terms of Service")
                }
            }
            
            Section {
                // Honesty disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Label("Honor System", systemImage: "hand.raised.fill")
                        .font(.headline)
                    
                    Text("All statistics and leaderboards are based on users being honest with themselves about their planks. Let's keep it fair!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                Button(role: .destructive) {
                    // Sign out in Phase 5
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
```

### 8.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add SettingsView"`

---

## Step 9: Build Notifications Screen

### 9.1 Create NotificationsView
- [ ] Create `NotificationsView.swift` in **Views/Notifications/**:

```swift
import SwiftUI

struct NotificationsView: View {
    private let mockData = MockDataService.shared
    
    var body: some View {
        List {
            if mockData.mockNotifications.isEmpty {
                emptyState
            } else {
                ForEach(mockData.mockNotifications) { notification in
                    NotificationRow(notification: notification)
                }
            }
        }
        .navigationTitle("Notifications")
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No notifications")
                .font(.headline)
            
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
}

struct NotificationRow: View {
    let notification: MockNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: notification.type.iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Text(notification.createdAt.relativeFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .badgeEarned, .tokenEarned:
            return .yellow
        case .streakFreezeUsed:
            return .cyan
        case .groupJoined, .joinRequestApproved, .promotedToAdmin:
            return .green
        case .groupRemoved, .groupDeleted, .joinRequestDenied:
            return .red
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
```

### 9.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add NotificationsView"`

---

## Step 10: Final Verification

### 10.1 Preview All Screens
- [ ] Open each screen file and verify Preview works
- [ ] Check for any compile errors
- [ ] Ensure mock data displays correctly

### 10.2 Visual Consistency Check
- [ ] Verify Apple Health-inspired design is consistent
- [ ] Check color usage across screens
- [ ] Verify typography is consistent
- [ ] Test in both light and dark mode

### 10.3 Final Commit
- [ ] `git add .`
- [ ] `git commit -m "Phase 2 complete: All screens built with mock data"`
- [ ] Consider creating a tag: `git tag v0.2-screens`

---

## Phase 2 Completion Checklist

- [ ] MockDataService created with comprehensive mock data
- [ ] Plank Timer screens (PlankTimerView, PlankTypeSelectorSheet, PlankCompletionSheet)
- [ ] Manual Entry screen (ManualEntryView)
- [ ] Progress screens (ProgressView, PlankHistoryListView, PlankDetailView, BadgesView)
- [ ] Leaderboards screen (LeaderboardsView)
- [ ] Groups screens (GroupsListView, GroupDetailView, GroupMembersListView, CreateGroupView, GroupSettingsView)
- [ ] Profile screens (ProfileView, UserProfileView, EditProfileView, FollowListView)
- [ ] Settings screen (SettingsView)
- [ ] Notifications screen (NotificationsView)
- [ ] All screens use mock data correctly
- [ ] Visual design follows Apple Health inspiration
- [ ] All previews working
- [ ] All changes committed to Git

---

## Next Steps

With Phase 2 complete, you're ready to move to **Phase 3: Connect Screens & Navigation**, where you'll:
1. Set up the main tab bar navigation
2. Wire all screens together with navigation flows
3. Connect mock data to views throughout the app
4. Implement local data storage for user's own data
5. Implement streak and badge logic

Proceed to `PHASE_3_CONNECT_NAVIGATION.md` when ready.
