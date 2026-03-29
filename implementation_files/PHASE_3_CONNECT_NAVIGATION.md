# Phase 3: Connect Screens & Navigation

**Goal:** Wire all screens together with navigation, connect mock data to views, implement local data storage for user's own plank data, and create a fully navigable prototype.

**Outcome:** A complete, navigable app prototype where users can perform planks (saved locally), view their real progress, and browse mock social features.

**Prerequisites:** Phase 2 complete — all individual screens built with mock data.

---

## Step 1: Create Main Tab Bar Navigation

### 1.1 Create MainTabView
- [ ] Create `MainTabView.swift` in **Views/**:

```swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .plank
    
    enum Tab: String, CaseIterable {
        case plank = "Plank"
        case progress = "Progress"
        case leaderboards = "Leaderboards"
        case groups = "Groups"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .plank: return "figure.core.training"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .leaderboards: return "trophy"
            case .groups: return "person.3"
            case .profile: return "person.circle"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Plank Tab
            NavigationStack {
                PlankTimerView()
            }
            .tabItem {
                Label(Tab.plank.rawValue, systemImage: Tab.plank.icon)
            }
            .tag(Tab.plank)
            
            // Progress Tab
            NavigationStack {
                ProgressView()
            }
            .tabItem {
                Label(Tab.progress.rawValue, systemImage: Tab.progress.icon)
            }
            .tag(Tab.progress)
            
            // Leaderboards Tab
            NavigationStack {
                LeaderboardsView()
            }
            .tabItem {
                Label(Tab.leaderboards.rawValue, systemImage: Tab.leaderboards.icon)
            }
            .tag(Tab.leaderboards)
            
            // Groups Tab
            NavigationStack {
                GroupsListView()
            }
            .tabItem {
                Label(Tab.groups.rawValue, systemImage: Tab.groups.icon)
            }
            .tag(Tab.groups)
            
            // Profile Tab
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
            }
            .tag(Tab.profile)
        }
    }
}

#Preview {
    MainTabView()
}
```

### 1.2 Update App Entry Point
- [ ] Update `ContentView.swift` in **App/**:

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataService: DataService
    
    init() {
        // DataService will be properly initialized in onAppear
        _dataService = StateObject(wrappedValue: DataService(modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self, Badge.self, AppNotification.self, PlankGroup.self))))
    }
    
    var body: some View {
        MainTabView()
            .environmentObject(dataService)
            .onAppear {
                // Ensure user profile exists
                _ = dataService.getOrCreateUserProfile()
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PlankSession.self, UserProfile.self, Badge.self, AppNotification.self, PlankGroup.self], inMemory: true)
}
```

### 1.3 Update PlankChallengeApp
- [ ] Update `PlankChallengeApp.swift` in **App/** to pass model context properly:

```swift
import SwiftUI
import SwiftData

@main
struct PlankChallengeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlankSession.self,
            UserProfile.self,
            Badge.self,
            AppNotification.self,
            PlankGroup.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.modelContext, sharedModelContainer.mainContext)
                .onAppear {
                    setupInitialData()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupInitialData() {
        let context = sharedModelContainer.mainContext
        
        // Check if user profile exists, create if not
        let descriptor = FetchDescriptor<UserProfile>()
        let existingProfiles = try? context.fetch(descriptor)
        
        if existingProfiles?.isEmpty ?? true {
            let profile = UserProfile()
            context.insert(profile)
            try? context.save()
        }
    }
}
```

### 1.4 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add MainTabView and configure app entry point"`

---

## Step 2: Create View Models

### 2.1 Create PlankViewModel
- [ ] Create `PlankViewModel.swift` in **ViewModels/**:

```swift
import Foundation
import SwiftData
import Combine

@MainActor
class PlankViewModel: ObservableObject {
    @Published var selectedPlankType: Constants.Plank.PlankType = .elbow
    @Published var todaysPlank: PlankSession?
    @Published var hasPlankToday: Bool = false
    @Published var canDeleteTodaysPlank: Bool = false
    
    private var modelContext: ModelContext
    private let calendar = Calendar.current
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadTodaysPlank()
        loadPreferredPlankType()
    }
    
    // MARK: - Load Data
    
    func loadTodaysPlank() {
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<PlankSession> { session in
            session.date >= startOfDay && session.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<PlankSession>(predicate: predicate)
        
        if let sessions = try? modelContext.fetch(descriptor) {
            todaysPlank = sessions.first
            hasPlankToday = todaysPlank != nil
            canDeleteTodaysPlank = hasPlankToday
        }
    }
    
    private func loadPreferredPlankType() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            selectedPlankType = profile.preferredPlankType
        }
    }
    
    // MARK: - Save Plank
    
    func savePlank(duration: TimeInterval, inputMethod: PlankSession.InputMethod) -> Bool {
        // Validate duration
        guard duration >= Constants.Plank.minimumDurationSeconds else {
            return false
        }
        
        guard duration <= Constants.Plank.maximumDurationSeconds else {
            return false
        }
        
        // Check if already planked today
        guard !hasPlankToday else {
            return false
        }
        
        // Create and save session
        let session = PlankSession(
            date: Date(),
            durationSeconds: duration,
            plankType: selectedPlankType,
            inputMethod: inputMethod
        )
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            todaysPlank = session
            hasPlankToday = true
            canDeleteTodaysPlank = true
            
            // Update streak
            updateStreak()
            
            // Check for badges
            checkAndAwardBadges()
            
            return true
        } catch {
            print("Error saving plank: \(error)")
            return false
        }
    }
    
    // MARK: - Delete Plank
    
    func deleteTodaysPlank() -> Bool {
        guard let plank = todaysPlank else { return false }
        guard canDeleteTodaysPlank else { return false }
        
        modelContext.delete(plank)
        
        do {
            try modelContext.save()
            todaysPlank = nil
            hasPlankToday = false
            canDeleteTodaysPlank = false
            return true
        } catch {
            print("Error deleting plank: \(error)")
            return false
        }
    }
    
    // MARK: - Streak Management
    
    private func updateStreak() {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else { return }
        
        // Calculate streak
        let newStreak = calculateCurrentStreak()
        
        profile.currentStreak = newStreak
        profile.lastPlankDate = Date()
        
        // Update longest streak if needed
        if newStreak > profile.longestStreak {
            profile.longestStreak = newStreak
        }
        
        // Check if earned a token (20-day streak)
        if newStreak == Constants.Streak.streakForBonusToken &&
           profile.freezeTokens < Constants.Streak.maxFreezeTokens {
            profile.freezeTokens += 1
            createNotification(
                type: .tokenEarned,
                title: "Freeze Token Earned!",
                message: "Amazing! You've reached a \(Constants.Streak.streakForBonusToken)-day streak and earned a freeze token."
            )
        }
        
        profile.modifiedAt = Date()
        try? modelContext.save()
    }
    
    private func calculateCurrentStreak() -> Int {
        let descriptor = FetchDescriptor<PlankSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else { return 0 }
        
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())
        
        for session in sessions {
            let sessionDate = calendar.startOfDay(for: session.date)
            
            if sessionDate == expectedDate {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if sessionDate < expectedDate {
                // Check if we need to use a freeze token (handled elsewhere)
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Badges
    
    private func checkAndAwardBadges() {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else { return }
        
        let currentStreak = profile.currentStreak
        
        // Check each badge milestone
        for milestone in Constants.Streak.badgeMilestones {
            if currentStreak >= milestone {
                if let badgeType = Badge.BadgeType.allCases.first(where: { $0.streakDays == milestone }) {
                    awardBadgeIfNotEarned(badgeType)
                }
            }
        }
    }
    
    private func awardBadgeIfNotEarned(_ badgeType: Badge.BadgeType) {
        // Check if already earned
        let predicate = #Predicate<Badge> { badge in
            badge.badgeTypeRaw == badgeType.rawValue
        }
        let descriptor = FetchDescriptor<Badge>(predicate: predicate)
        
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            return // Already earned
        }
        
        // Award badge
        let badge = Badge(badgeType: badgeType)
        modelContext.insert(badge)
        
        // Create notification
        createNotification(
            type: .badgeEarned,
            title: "New Badge Earned!",
            message: "Congratulations! You've earned the '\(badgeType.displayName)' badge!"
        )
        
        try? modelContext.save()
    }
    
    private func createNotification(type: AppNotification.NotificationType, title: String, message: String) {
        let notification = AppNotification(type: type, title: title, message: message)
        modelContext.insert(notification)
    }
}
```

### 2.2 Create ProgressViewModel
- [ ] Create `ProgressViewModel.swift` in **ViewModels/**:

```swift
import Foundation
import SwiftData

@MainActor
class ProgressViewModel: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var longestPlankSeconds: TimeInterval = 0
    @Published var totalPlanks: Int = 0
    @Published var freezeTokens: Int = 2
    @Published var plankHistory: [PlankSession] = []
    @Published var earnedBadges: [Badge] = []
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
    }
    
    func loadData() {
        loadProfile()
        loadPlankHistory()
        loadBadges()
    }
    
    private func loadProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            currentStreak = profile.currentStreak
            longestStreak = profile.longestStreak
            freezeTokens = profile.freezeTokens
        }
    }
    
    private func loadPlankHistory() {
        let descriptor = FetchDescriptor<PlankSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        if let sessions = try? modelContext.fetch(descriptor) {
            plankHistory = sessions
            totalPlanks = sessions.count
            longestPlankSeconds = sessions.map { $0.durationSeconds }.max() ?? 0
        }
    }
    
    private func loadBadges() {
        let descriptor = FetchDescriptor<Badge>(
            sortBy: [SortDescriptor(\.dateEarned, order: .reverse)]
        )
        
        if let badges = try? modelContext.fetch(descriptor) {
            earnedBadges = badges
        }
    }
    
    // MARK: - Computed Properties
    
    var longestPlankFormatted: String {
        longestPlankSeconds.formattedDuration
    }
    
    var recentPlanks: [PlankSession] {
        Array(plankHistory.prefix(5))
    }
    
    var planksByMonth: [(key: String, value: [PlankSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let grouped = Dictionary(grouping: plankHistory) { session in
            formatter.string(from: session.date)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    // MARK: - Chart Data
    
    var last14DaysData: [(date: Date, duration: TimeInterval)] {
        let calendar = Calendar.current
        var data: [(Date, TimeInterval)] = []
        
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            
            let duration = plankHistory.first { session in
                calendar.isDate(session.date, inSameDayAs: startOfDay)
            }?.durationSeconds ?? 0
            
            data.append((startOfDay, duration))
        }
        
        return data.reversed()
    }
    
    // MARK: - Progress Trend
    
    enum Trend {
        case improving
        case declining
        case stable
        case noData
    }
    
    var progressTrend: Trend {
        guard plankHistory.count >= 7 else { return .noData }
        
        let recent = Array(plankHistory.prefix(7))
        let older = Array(plankHistory.dropFirst(7).prefix(7))
        
        guard !older.isEmpty else { return .noData }
        
        let recentAvg = recent.map { $0.durationSeconds }.reduce(0, +) / Double(recent.count)
        let olderAvg = older.map { $0.durationSeconds }.reduce(0, +) / Double(older.count)
        
        let difference = recentAvg - olderAvg
        let threshold: TimeInterval = 5 // 5 seconds threshold
        
        if difference > threshold {
            return .improving
        } else if difference < -threshold {
            return .declining
        } else {
            return .stable
        }
    }
    
    // MARK: - Edit Plank
    
    func updatePlankType(for session: PlankSession, to newType: Constants.Plank.PlankType) {
        session.plankType = newType
        session.modifiedAt = Date()
        try? modelContext.save()
        loadPlankHistory()
    }
    
    func deletePlank(_ session: PlankSession) -> Bool {
        // Can only delete today's plank
        guard session.date.isToday else { return false }
        
        modelContext.delete(session)
        
        do {
            try modelContext.save()
            loadData()
            return true
        } catch {
            return false
        }
    }
}
```

### 2.3 Create ProfileViewModel
- [ ] Create `ProfileViewModel.swift` in **ViewModels/**:

```swift
import Foundation
import SwiftData

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var bio: String = ""
    @Published var linkedInLink: String = ""
    @Published var socialLink: String = ""
    @Published var preferredPlankType: Constants.Plank.PlankType = .elbow
    @Published var profileImageData: Data?
    
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var longestPlankSeconds: TimeInterval = 0
    @Published var totalPlanks: Int = 0
    @Published var earnedBadges: [Badge] = []
    
    private var modelContext: ModelContext
    private var userProfile: UserProfile?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadProfile()
    }
    
    func loadProfile() {
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            self.userProfile = profile
            self.displayName = profile.displayName
            self.bio = profile.bio
            self.linkedInLink = profile.linkedInLink ?? ""
            self.socialLink = profile.socialLink ?? ""
            self.preferredPlankType = profile.preferredPlankType
            self.profileImageData = profile.profileImageData
            self.currentStreak = profile.currentStreak
            self.longestStreak = profile.longestStreak
            self.loadStats()
            self.loadBadges()
        }
    }
    
    private func loadStats() {
        let descriptor = FetchDescriptor<PlankSession>()
        if let sessions = try? modelContext.fetch(descriptor) {
            totalPlanks = sessions.count
            longestPlankSeconds = sessions.map { $0.durationSeconds }.max() ?? 0
        }
    }
    
    private func loadBadges() {
        let descriptor = FetchDescriptor<Badge>(
            sortBy: [SortDescriptor(\.dateEarned, order: .reverse)]
        )
        if let badges = try? modelContext.fetch(descriptor) {
            earnedBadges = badges
        }
    }
    
    // MARK: - Save Profile
    
    func saveProfile() {
        guard let profile = userProfile else { return }
        
        profile.displayName = displayName
        profile.bio = bio
        profile.linkedInLink = linkedInLink.isEmpty ? nil : linkedInLink
        profile.socialLink = socialLink.isEmpty ? nil : socialLink
        profile.preferredPlankType = preferredPlankType
        profile.profileImageData = profileImageData
        profile.modifiedAt = Date()
        
        try? modelContext.save()
    }
    
    // MARK: - Computed
    
    var longestPlankFormatted: String {
        longestPlankSeconds.formattedDuration
    }
}
```

### 2.4 Create NotificationsViewModel
- [ ] Create `NotificationsViewModel.swift` in **ViewModels/**:

```swift
import Foundation
import SwiftData

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadNotifications()
    }
    
    func loadNotifications() {
        let descriptor = FetchDescriptor<AppNotification>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let results = try? modelContext.fetch(descriptor) {
            notifications = results
            unreadCount = results.filter { !$0.isRead }.count
        }
    }
    
    func markAsRead(_ notification: AppNotification) {
        notification.isRead = true
        try? modelContext.save()
        loadNotifications()
    }
    
    func markAllAsRead() {
        for notification in notifications where !notification.isRead {
            notification.isRead = true
        }
        try? modelContext.save()
        loadNotifications()
    }
}
```

### 2.5 Create LeaderboardViewModel
- [ ] Create `LeaderboardViewModel.swift` in **ViewModels/**:

```swift
import Foundation
import SwiftData

@MainActor
class LeaderboardViewModel: ObservableObject {
    @Published var streakLeaderboard: [LeaderboardEntry] = []
    @Published var longestPlankLeaderboard: [LeaderboardEntry] = []
    @Published var currentUserStreakRank: Int?
    @Published var currentUserPlankRank: Int?
    
    private var modelContext: ModelContext
    private let mockData = MockDataService.shared
    
    struct LeaderboardEntry: Identifiable {
        let id = UUID()
        let rank: Int
        let displayName: String
        let profileImageName: String?
        let value: String
        let isCurrentUser: Bool
        let badges: [Badge.BadgeType]
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadLeaderboards()
    }
    
    func loadLeaderboards() {
        loadStreakLeaderboard()
        loadLongestPlankLeaderboard()
    }
    
    private func loadStreakLeaderboard() {
        // Get current user data
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let currentUser = try? modelContext.fetch(profileDescriptor).first
        let currentUserStreak = currentUser?.currentStreak ?? 0
        
        // Combine mock users with current user
        var entries: [(name: String, streak: Int, isCurrentUser: Bool, badges: [Badge.BadgeType])] = []
        
        // Add mock users
        for user in mockData.streakLeaderboard {
            entries.append((user.displayName, user.currentStreak, false, user.badges))
        }
        
        // Add current user if they have an active streak
        if currentUserStreak > 0 {
            entries.append(("You", currentUserStreak, true, []))
        }
        
        // Sort and create leaderboard
        entries.sort { $0.streak > $1.streak }
        
        streakLeaderboard = entries.enumerated().map { index, entry in
            LeaderboardEntry(
                rank: index + 1,
                displayName: entry.name,
                profileImageName: entry.isCurrentUser ? nil : "person.circle.fill",
                value: "\(entry.streak) days",
                isCurrentUser: entry.isCurrentUser,
                badges: entry.badges
            )
        }
        
        currentUserStreakRank = streakLeaderboard.first { $0.isCurrentUser }?.rank
    }
    
    private func loadLongestPlankLeaderboard() {
        // Get current user data
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let currentUser = try? modelContext.fetch(profileDescriptor).first
        let currentUserStreak = currentUser?.currentStreak ?? 0
        
        let sessionsDescriptor = FetchDescriptor<PlankSession>()
        let sessions = try? modelContext.fetch(sessionsDescriptor)
        let longestPlank = sessions?.map { $0.durationSeconds }.max() ?? 0
        
        // Combine mock users with current user
        var entries: [(name: String, plankSeconds: TimeInterval, isCurrentUser: Bool, badges: [Badge.BadgeType])] = []
        
        // Add mock users (only those with active streak)
        for user in mockData.longestPlankLeaderboard {
            entries.append((user.displayName, user.longestPlankSeconds, false, user.badges))
        }
        
        // Add current user if they have an active streak
        if currentUserStreak > 0 && longestPlank > 0 {
            entries.append(("You", longestPlank, true, []))
        }
        
        // Sort and create leaderboard
        entries.sort { $0.plankSeconds > $1.plankSeconds }
        
        longestPlankLeaderboard = entries.enumerated().map { index, entry in
            LeaderboardEntry(
                rank: index + 1,
                displayName: entry.name,
                profileImageName: entry.isCurrentUser ? nil : "person.circle.fill",
                value: entry.plankSeconds.formattedDuration,
                isCurrentUser: entry.isCurrentUser,
                badges: entry.badges
            )
        }
        
        currentUserPlankRank = longestPlankLeaderboard.first { $0.isCurrentUser }?.rank
    }
}
```

### 2.6 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add ViewModels: PlankViewModel, ProgressViewModel, ProfileViewModel, NotificationsViewModel, LeaderboardViewModel"`

---

## Step 3: Update Plank Timer View with ViewModel

### 3.1 Update PlankTimerView
- [ ] Update `PlankTimerView.swift` in **Views/Plank/**:

```swift
import SwiftUI
import SwiftData

struct PlankTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var timerService = TimerService()
    @StateObject private var viewModel: PlankViewModel
    
    @State private var showingPlankTypeSelector = false
    @State private var showingCompletionSheet = false
    @State private var showingAlreadyPlankedAlert = false
    @State private var completedDuration: TimeInterval = 0
    @State private var showingManualEntry = false
    
    init() {
        // ViewModel will be properly initialized with modelContext
        _viewModel = StateObject(wrappedValue: PlankViewModel(
            modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self, Badge.self, AppNotification.self))
        ))
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if timerService.isRunning {
                    activePlankView
                } else {
                    prePlankView
                }
            }
        }
        .navigationTitle("Plank")
        .sheet(isPresented: $showingPlankTypeSelector) {
            PlankTypeSelectorSheet(selectedType: $viewModel.selectedPlankType)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingCompletionSheet) {
            PlankCompletionSheet(
                duration: completedDuration,
                plankType: viewModel.selectedPlankType,
                onDismiss: {
                    viewModel.loadTodaysPlank()
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                ManualEntryView(viewModel: viewModel)
            }
        }
        .alert("Already Planked Today", isPresented: $showingAlreadyPlankedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've already completed your plank for today. Come back tomorrow!")
        }
        .keepScreenAwake(timerService.isRunning)
        .onAppear {
            // Re-initialize viewModel with correct context
            viewModel.loadTodaysPlank()
        }
    }
    
    // MARK: - Pre-Plank View
    
    private var prePlankView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            if viewModel.hasPlankToday {
                // Already planked today view
                alreadyPlankedView
            } else {
                // Ready to plank view
                plankTypeButton
                startButton
                
                Text("Tap to start your daily plank")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !viewModel.hasPlankToday {
                manualEntryButton
            }
        }
        .padding()
    }
    
    private var alreadyPlankedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 8) {
                Text("Today's Plank Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let plank = viewModel.todaysPlank {
                    Text(plank.durationSeconds.formattedDuration)
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Come back tomorrow to continue your streak")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var plankTypeButton: some View {
        Button {
            showingPlankTypeSelector = true
        } label: {
            HStack {
                Image(systemName: "figure.core.training")
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(viewModel.selectedPlankType.rawValue)
                        .font(.headline)
                    Text(viewModel.selectedPlankType.description)
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
            if viewModel.hasPlankToday {
                showingAlreadyPlankedAlert = true
            } else {
                timerService.start()
            }
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
    
    private var manualEntryButton: some View {
        Button {
            showingManualEntry = true
        } label: {
            Text("Add time manually")
                .font(.subheadline)
                .foregroundStyle(.appAccent)
        }
    }
    
    // MARK: - Active Plank View
    
    private var activePlankView: some View {
        VStack(spacing: 0) {
            plankFormImage
            
            Spacer()
            
            timerDisplay
            
            Spacer()
            
            stopButton
                .padding(.bottom, 50)
        }
    }
    
    private var plankFormImage: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
            
            VStack {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                
                Text(viewModel.selectedPlankType.rawValue)
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
        timerService.isAtMinimumDuration ? .green : .primary
    }
    
    private var stopButton: some View {
        Button {
            completedDuration = timerService.elapsedTime
            timerService.stop()
            
            if completedDuration >= Constants.Plank.minimumDurationSeconds {
                // Save the plank
                if viewModel.savePlank(duration: completedDuration, inputMethod: .timer) {
                    showingCompletionSheet = true
                }
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
    .modelContainer(for: [PlankSession.self, UserProfile.self, Badge.self, AppNotification.self], inMemory: true)
}
```

### 3.2 Update ManualEntryView
- [ ] Update `ManualEntryView.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PlankViewModel
    
    @State private var minutes: Int = 1
    @State private var seconds: Int = 0
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    
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
                Picker("Type", selection: $viewModel.selectedPlankType) {
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
                .disabled(!isValidDuration || viewModel.hasPlankToday)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.hasPlankToday {
                        Text("You've already logged a plank today.")
                            .foregroundStyle(.orange)
                    }
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
        .alert("Plank Saved!", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your plank has been recorded.")
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
        
        if viewModel.savePlank(duration: totalSeconds, inputMethod: .manual) {
            showingSuccess = true
        } else {
            errorMessage = "Failed to save plank. Please try again."
            showingError = true
        }
    }
}

#Preview {
    NavigationStack {
        ManualEntryView(viewModel: PlankViewModel(
            modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self, Badge.self, AppNotification.self))
        ))
    }
}
```

### 3.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update PlankTimerView and ManualEntryView with ViewModel integration"`

---

## Step 4: Update Progress Views with ViewModel

### 4.1 Update ProgressView
- [ ] Update `ProgressView.swift` in **Views/Progress/**:

```swift
import SwiftUI
import SwiftData
import Charts

struct ProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ProgressViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: ProgressViewModel(
            modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self, Badge.self))
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                streakSection
                statsSection
                chartSection
                historySection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress")
        .onAppear {
            viewModel.loadData()
        }
        .refreshable {
            viewModel.loadData()
        }
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
                        Text("\(viewModel.currentStreak)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        
                        Text("days")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
            }
            
            HStack {
                TokenIndicator(tokensRemaining: viewModel.freezeTokens)
                Spacer()
                Text("Freeze tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Trend indicator
            if viewModel.plankHistory.count >= 7 {
                HStack {
                    trendIndicator
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private var trendIndicator: some View {
        let trend = viewModel.progressTrend
        HStack(spacing: 4) {
            switch trend {
            case .improving:
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.green)
                Text("Improving")
                    .foregroundStyle(.green)
            case .declining:
                Image(systemName: "arrow.down.right")
                    .foregroundStyle(.orange)
                Text("Declining")
                    .foregroundStyle(.orange)
            case .stable:
                Image(systemName: "arrow.right")
                    .foregroundStyle(.blue)
                Text("Stable")
                    .foregroundStyle(.blue)
            case .noData:
                EmptyView()
            }
        }
        .font(.caption)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Longest Plank",
                value: viewModel.longestPlankFormatted,
                subtitle: "personal best",
                icon: "trophy.fill",
                color: .yellow
            )
            
            StatCard(
                title: "Total Planks",
                value: "\(viewModel.totalPlanks)",
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
            
            if viewModel.plankHistory.isEmpty {
                Text("No plank data yet. Complete your first plank!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.last14DaysData, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Duration", item.duration)
                    )
                    .foregroundStyle(Color.appAccent.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day())
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let seconds = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(seconds))s")
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
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
                
                if !viewModel.plankHistory.isEmpty {
                    NavigationLink("See All") {
                        PlankHistoryListView(viewModel: viewModel)
                    }
                    .font(.subheadline)
                }
            }
            
            if viewModel.recentPlanks.isEmpty {
                Text("No planks recorded yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.recentPlanks) { session in
                    NavigationLink {
                        PlankDetailView(session: session, viewModel: viewModel)
                    } label: {
                        PlankHistoryRowReal(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Real Plank History Row

struct PlankHistoryRowReal: View {
    let session: PlankSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.relativeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.plankType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(session.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.colorForPlankType(session.plankType))
            
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
    .modelContainer(for: [PlankSession.self, UserProfile.self, Badge.self], inMemory: true)
}
```

### 4.2 Update PlankHistoryListView
- [ ] Update `PlankHistoryListView.swift` in **Views/Progress/**:

```swift
import SwiftUI

struct PlankHistoryListView: View {
    @ObservedObject var viewModel: ProgressViewModel
    
    var body: some View {
        List {
            if viewModel.plankHistory.isEmpty {
                Text("No planks recorded yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.planksByMonth, id: \.key) { month, sessions in
                    Section(month) {
                        ForEach(sessions) { session in
                            NavigationLink {
                                PlankDetailView(session: session, viewModel: viewModel)
                            } label: {
                                PlankHistoryRowReal(session: session)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Plank History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PlankHistoryListView(viewModel: ProgressViewModel(
            modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self, Badge.self))
        ))
    }
}
```

### 4.3 Update PlankDetailView
- [ ] Update `PlankDetailView.swift` in **Views/Progress/**:

```swift
import SwiftUI

struct PlankDetailView: View {
    let session: PlankSession
    @ObservedObject var viewModel: ProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlankType: Constants.Plank.PlankType
    @State private var hasChanges = false
    @State private var showingDeleteConfirmation = false
    
    init(session: PlankSession, viewModel: ProgressViewModel) {
        self.session = session
        self.viewModel = viewModel
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
                .onChange(of: selectedPlankType) { oldValue, newValue in
                    if oldValue != newValue {
                        hasChanges = true
                    }
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
                        viewModel.updatePlankType(for: session, to: selectedPlankType)
                        hasChanges = false
                    }
                }
            }
        }
        .alert("Delete Plank?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if viewModel.deletePlank(session) {
                    dismiss()
                }
            }
        } message: {
            Text("This will remove your plank entry for today. You can enter a new one before midnight.")
        }
    }
}

#Preview {
    NavigationStack {
        PlankDetailView(
            session: PlankSession(durationSeconds: 125.5, plankType: .elbow),
            viewModel: ProgressViewModel(
                modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self, Badge.self))
            )
        )
    }
}
```

### 4.4 Update BadgesView
- [ ] Update `BadgesView.swift` in **Views/Progress/**:

```swift
import SwiftUI
import SwiftData

struct BadgesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Badge.dateEarned, order: .reverse) private var earnedBadges: [Badge]
    
    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 16)
    ]
    
    private var earnedBadgeTypes: [Badge.BadgeType] {
        earnedBadges.compactMap { $0.badgeType }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Badge.BadgeType.allCases, id: \.self) { badgeType in
                    let earned = earnedBadges.first { $0.badgeType == badgeType }
                    BadgeView(
                        badgeType: badgeType,
                        isEarned: earned != nil,
                        dateEarned: earned?.dateEarned
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
    .modelContainer(for: Badge.self, inMemory: true)
}
```

### 4.5 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update Progress views with ViewModel and real data integration"`

---

## Step 5: Update Leaderboards View with ViewModel

### 5.1 Update LeaderboardsView
- [ ] Update `LeaderboardsView.swift` in **Views/Leaderboards/**:

```swift
import SwiftUI
import SwiftData

struct LeaderboardsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: LeaderboardViewModel
    @State private var selectedTab: LeaderboardTab = .streak
    
    enum LeaderboardTab: String, CaseIterable {
        case streak = "Active Streak"
        case longestPlank = "Longest Plank"
    }
    
    init() {
        _viewModel = StateObject(wrappedValue: LeaderboardViewModel(
            modelContext: ModelContext(try! ModelContainer(for: PlankSession.self, UserProfile.self))
        ))
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
            
            // Active streak required notice
            HStack {
                Image(systemName: "info.circle")
                Text("Active streak required to appear on leaderboards")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Leaderboard list
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Current user position (if ranked)
                    if let rank = currentUserRank {
                        currentUserPosition(rank: rank)
                        
                        Divider()
                            .padding(.vertical, 8)
                    }
                    
                    // Leaderboard
                    ForEach(Array(leaderboardData.enumerated()), id: \.element.id) { index, entry in
                        LeaderboardRowView(entry: entry)
                        
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
        .onAppear {
            viewModel.loadLeaderboards()
        }
        .refreshable {
            viewModel.loadLeaderboards()
        }
    }
    
    private var leaderboardData: [LeaderboardViewModel.LeaderboardEntry] {
        switch selectedTab {
        case .streak:
            return viewModel.streakLeaderboard
        case .longestPlank:
            return viewModel.longestPlankLeaderboard
        }
    }
    
    private var currentUserRank: Int? {
        switch selectedTab {
        case .streak:
            return viewModel.currentUserStreakRank
        case .longestPlank:
            return viewModel.currentUserPlankRank
        }
    }
    
    private func currentUserPosition(rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Position")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let entry = leaderboardData.first(where: { $0.isCurrentUser }) {
                LeaderboardRowView(entry: entry)
            }
        }
        .padding()
        .background(Color.appAccent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Leaderboard Row View

struct LeaderboardRowView: View {
    let entry: LeaderboardViewModel.LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                }
                
                Text("\(entry.rank)")
                    .font(.headline)
                    .foregroundStyle(entry.rank <= 3 ? .white : .primary)
            }
            .frame(width: 40)
            
            // Avatar
            Image(systemName: entry.profileImageName ?? "person.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(entry.isCurrentUser ? .appAccent : .secondary)
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.body)
                    .fontWeight(entry.isCurrentUser ? .semibold : .regular)
                    .foregroundStyle(entry.isCurrentUser ? .appAccent : .primary)
                
                if !entry.badges.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(entry.badges.prefix(3), id: \.self) { badge in
                            Image(systemName: "medal.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Value
            Text(entry.value)
                .font(.headline)
                .foregroundStyle(entry.isCurrentUser ? .appAccent : .primary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var rankColor: Color {
        switch entry.rank {
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
    .modelContainer(for: [PlankSession.self, UserProfile.self], inMemory: true)
}
```

### 5.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update LeaderboardsView with ViewModel and mixed mock/real data"`

---

## Step 6: Update Profile Views with ViewModel

### 6.1 Update ProfileView
- [ ] Update `ProfileView.swift` in **Views/Profile/**:

```swift
import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ProfileViewModel
    private let mockData = MockDataService.shared
    
    init() {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            modelContext: ModelContext(try! ModelContainer(for: UserProfile.self, PlankSession.self, Badge.self))
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsSection
                badgesSection
                
                if !viewModel.linkedInLink.isEmpty || !viewModel.socialLink.isEmpty {
                    socialSection
                }
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
            
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    NotificationsView()
                } label: {
                    Image(systemName: "bell")
                }
            }
        }
        .onAppear {
            viewModel.loadProfile()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                if let imageData = viewModel.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.secondary)
                }
                
                NavigationLink {
                    EditProfileView(viewModel: viewModel)
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title)
                        .foregroundStyle(.appAccent)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }
            
            // Name
            Text(viewModel.displayName.isEmpty ? "Planker" : viewModel.displayName)
                .font(.title)
                .fontWeight(.bold)
            
            // Bio
            if !viewModel.bio.isEmpty {
                Text(viewModel.bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Follow stats (mock for now)
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
                    value: "\(viewModel.currentStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Longest Streak",
                    value: "\(viewModel.longestStreak)",
                    subtitle: "days",
                    icon: "trophy.fill",
                    color: .yellow
                )
            }
            
            HStack(spacing: 12) {
                StatCard(
                    title: "Longest Plank",
                    value: viewModel.longestPlankFormatted,
                    subtitle: "personal best",
                    icon: "timer",
                    color: .green
                )
                
                StatCard(
                    title: "Total Planks",
                    value: "\(viewModel.totalPlanks)",
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
            
            if viewModel.earnedBadges.isEmpty {
                Text("No badges earned yet. Keep up your streak!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.earnedBadges) { badge in
                            if let badgeType = badge.badgeType {
                                BadgeView(
                                    badgeType: badgeType,
                                    isEarned: true,
                                    dateEarned: badge.dateEarned
                                )
                            }
                        }
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
                if !viewModel.linkedInLink.isEmpty, let url = URL(string: viewModel.linkedInLink) {
                    Link(destination: url) {
                        Label("LinkedIn", systemImage: "link")
                            .font(.subheadline)
                    }
                }
                
                if !viewModel.socialLink.isEmpty, let url = URL(string: viewModel.socialLink) {
                    Link(destination: url) {
                        Label("Social", systemImage: "link")
                            .font(.subheadline)
                    }
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
    .modelContainer(for: [UserProfile.self, PlankSession.self, Badge.self], inMemory: true)
}
```

### 6.2 Update EditProfileView
- [ ] Update `EditProfileView.swift` in **Views/Profile/**:

```swift
import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var linkedInLink: String = ""
    @State private var socialLink: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        _displayName = State(initialValue: viewModel.displayName)
        _bio = State(initialValue: viewModel.bio)
        _linkedInLink = State(initialValue: viewModel.linkedInLink)
        _socialLink = State(initialValue: viewModel.socialLink)
        _selectedImageData = State(initialValue: viewModel.profileImageData)
    }
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if let data = selectedImageData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.secondary)
                            }
                            
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
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
            
            Section("Profile") {
                TextField("Display Name", text: $displayName)
                
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Preferred Plank Type") {
                Picker("Type", selection: $viewModel.preferredPlankType) {
                    ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
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
                    saveProfile()
                    dismiss()
                }
            }
        }
    }
    
    private func saveProfile() {
        viewModel.displayName = displayName
        viewModel.bio = bio
        viewModel.linkedInLink = linkedInLink
        viewModel.socialLink = socialLink
        viewModel.profileImageData = selectedImageData
        viewModel.saveProfile()
    }
}

#Preview {
    NavigationStack {
        EditProfileView(viewModel: ProfileViewModel(
            modelContext: ModelContext(try! ModelContainer(for: UserProfile.self, PlankSession.self, Badge.self))
        ))
    }
}
```

### 6.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update Profile views with ViewModel and real data integration"`

---

## Step 7: Update Notifications View with ViewModel

### 7.1 Update NotificationsView
- [ ] Update `NotificationsView.swift` in **Views/Notifications/**:

```swift
import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: NotificationsViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: NotificationsViewModel(
            modelContext: ModelContext(try! ModelContainer(for: AppNotification.self))
        ))
    }
    
    var body: some View {
        List {
            if viewModel.notifications.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.notifications) { notification in
                    NotificationRowReal(notification: notification)
                        .onTapGesture {
                            viewModel.markAsRead(notification)
                        }
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark All Read") {
                        viewModel.markAllAsRead()
                    }
                    .font(.subheadline)
                }
            }
        }
        .onAppear {
            viewModel.loadNotifications()
        }
        .refreshable {
            viewModel.loadNotifications()
        }
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

struct NotificationRowReal: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            if let type = notification.notificationType {
                Image(systemName: type.iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor(for: type))
                    .frame(width: 32)
            }
            
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
    
    private func iconColor(for type: AppNotification.NotificationType) -> Color {
        switch type {
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
    .modelContainer(for: AppNotification.self, inMemory: true)
}
```

### 7.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update NotificationsView with ViewModel and real notifications"`

---

## Step 8: Update Settings View

### 8.1 Update SettingsView
- [ ] Update `SettingsView.swift` in **Views/Settings/**:

```swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var preferredPlankType: Constants.Plank.PlankType = .elbow
    @State private var notificationsEnabled = true
    @State private var reminderTime = Date()
    
    private var profile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        Form {
            Section("Plank Preferences") {
                Picker("Preferred Plank Type", selection: $preferredPlankType) {
                    ForEach(Constants.Plank.PlankType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .onChange(of: preferredPlankType) { oldValue, newValue in
                    profile?.preferredPlankType = newValue
                    try? modelContext.save()
                }
            }
            
            Section("Notifications") {
                Toggle("Daily Reminder", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { oldValue, newValue in
                        if newValue {
                            let hour = Calendar.current.component(.hour, from: reminderTime)
                            let minute = Calendar.current.component(.minute, from: reminderTime)
                            NotificationService.shared.scheduleDailyReminder(hour: hour, minute: minute)
                        } else {
                            NotificationService.shared.cancelDailyReminder()
                        }
                        UserDefaults.standard.set(newValue, forKey: Constants.StorageKeys.notificationsEnabled)
                    }
                
                if notificationsEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderTime) { oldValue, newValue in
                        let hour = Calendar.current.component(.hour, from: newValue)
                        let minute = Calendar.current.component(.minute, from: newValue)
                        NotificationService.shared.scheduleDailyReminder(hour: hour, minute: minute)
                        UserDefaults.standard.set(hour, forKey: Constants.StorageKeys.notificationHour)
                        UserDefaults.standard.set(minute, forKey: Constants.StorageKeys.notificationMinute)
                    }
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
                VStack(alignment: .leading, spacing: 8) {
                    Label("Honor System", systemImage: "hand.raised.fill")
                        .font(.headline)
                    
                    Text("All statistics and leaderboards are based on users being honest with themselves about their planks. Let's keep it fair!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        if let profile = profile {
            preferredPlankType = profile.preferredPlankType
        }
        
        notificationsEnabled = UserDefaults.standard.bool(forKey: Constants.StorageKeys.notificationsEnabled)
        
        let hour = UserDefaults.standard.integer(forKey: Constants.StorageKeys.notificationHour)
        let minute = UserDefaults.standard.integer(forKey: Constants.StorageKeys.notificationMinute)
        
        if hour > 0 || minute > 0 {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            if let date = Calendar.current.date(from: components) {
                reminderTime = date
            }
        } else {
            // Default to 3 PM
            var components = DateComponents()
            components.hour = Constants.Notifications.defaultReminderHour
            components.minute = Constants.Notifications.defaultReminderMinute
            if let date = Calendar.current.date(from: components) {
                reminderTime = date
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
```

### 8.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Update SettingsView with persistent settings and notification scheduling"`

---

## Step 9: Request Notification Permissions

### 9.1 Create OnboardingView (Optional)
- [ ] Create `OnboardingView.swift` in **Views/**:

```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Welcome page
                OnboardingPage(
                    imageName: "figure.core.training",
                    title: "Welcome to Plank Challenge",
                    description: "Build core strength with daily planks. Track your progress and compete with others."
                )
                .tag(0)
                
                // Streak page
                OnboardingPage(
                    imageName: "flame.fill",
                    title: "Build Your Streak",
                    description: "Complete one plank per day to build your streak. Don't worry — you have freeze tokens to protect against missed days."
                )
                .tag(1)
                
                // Notifications page
                OnboardingPage(
                    imageName: "bell.fill",
                    title: "Stay on Track",
                    description: "Get daily reminders so you never miss a plank.",
                    showNotificationButton: true,
                    onComplete: {
                        completeOnboarding()
                    }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            // Skip / Continue buttons
            HStack {
                if currentPage < 2 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding()
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Constants.StorageKeys.hasCompletedOnboarding)
        hasCompletedOnboarding = true
    }
}

struct OnboardingPage: View {
    let imageName: String
    let title: String
    let description: String
    var showNotificationButton: Bool = false
    var onComplete: (() -> Void)?
    
    @State private var notificationRequested = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: imageName)
                .font(.system(size: 80))
                .foregroundStyle(.appAccent)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            if showNotificationButton {
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await requestNotifications()
                        }
                    } label: {
                        Text(notificationRequested ? "Notifications Enabled" : "Enable Notifications")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(notificationRequested ? Color.green : Color.appAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(notificationRequested)
                    
                    Button {
                        onComplete?()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    private func requestNotifications() async {
        let granted = await NotificationService.shared.requestAuthorization()
        if granted {
            notificationRequested = true
            // Schedule default reminder
            NotificationService.shared.scheduleDailyReminder(
                hour: Constants.Notifications.defaultReminderHour,
                minute: Constants.Notifications.defaultReminderMinute
            )
            UserDefaults.standard.set(true, forKey: Constants.StorageKeys.notificationsEnabled)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
```

### 9.2 Update MainTabView to Show Onboarding
- [ ] Update `MainTabView.swift`:

```swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .plank
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Constants.StorageKeys.hasCompletedOnboarding)
    
    enum Tab: String, CaseIterable {
        case plank = "Plank"
        case progress = "Progress"
        case leaderboards = "Leaderboards"
        case groups = "Groups"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .plank: return "figure.core.training"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .leaderboards: return "trophy"
            case .groups: return "person.3"
            case .profile: return "person.circle"
            }
        }
    }
    
    var body: some View {
        if hasCompletedOnboarding {
            tabView
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
    
    private var tabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PlankTimerView()
            }
            .tabItem {
                Label(Tab.plank.rawValue, systemImage: Tab.plank.icon)
            }
            .tag(Tab.plank)
            
            NavigationStack {
                ProgressView()
            }
            .tabItem {
                Label(Tab.progress.rawValue, systemImage: Tab.progress.icon)
            }
            .tag(Tab.progress)
            
            NavigationStack {
                LeaderboardsView()
            }
            .tabItem {
                Label(Tab.leaderboards.rawValue, systemImage: Tab.leaderboards.icon)
            }
            .tag(Tab.leaderboards)
            
            NavigationStack {
                GroupsListView()
            }
            .tabItem {
                Label(Tab.groups.rawValue, systemImage: Tab.groups.icon)
            }
            .tag(Tab.groups)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
            }
            .tag(Tab.profile)
        }
    }
}

#Preview {
    MainTabView()
}
```

### 9.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add OnboardingView and notification permission request"`

---

## Step 10: Final Integration Testing

### 10.1 Test All Navigation Flows
- [ ] Plank Tab:
  - [ ] Start plank → Timer runs → Stop → Completion sheet → Saved
  - [ ] Already planked today → Shows completion state
  - [ ] Manual entry → Submit → Saved
  - [ ] Delete today's plank → Can plank again

- [ ] Progress Tab:
  - [ ] View stats (real data)
  - [ ] View history → Tap entry → Detail view
  - [ ] Edit plank type → Save
  - [ ] Delete today's plank
  - [ ] View badges

- [ ] Leaderboards Tab:
  - [ ] View streak leaderboard (mixed mock + real)
  - [ ] View longest plank leaderboard
  - [ ] Current user position shown correctly

- [ ] Groups Tab:
  - [ ] View my groups (mock)
  - [ ] View discover groups (mock)
  - [ ] View group detail → Leaderboard → Members
  - [ ] Create group flow

- [ ] Profile Tab:
  - [ ] View profile (real stats + mock social)
  - [ ] Edit profile → Save
  - [ ] View badges
  - [ ] Settings → Change preferences
  - [ ] Notifications

### 10.2 Test Streak Logic
- [ ] Complete first plank → Streak = 1
- [ ] Delete and re-do plank → Works correctly
- [ ] Verify badges awarded at milestones (test with mock dates if needed)

### 10.3 Test Notifications
- [ ] Enable notifications in onboarding
- [ ] Verify reminder scheduled
- [ ] Change reminder time in settings
- [ ] Disable notifications

### 10.4 Test Persistence
- [ ] Close and reopen app
- [ ] Verify all data persisted (planks, profile, settings)

### 10.5 Final Commit
- [ ] `git add .`
- [ ] `git commit -m "Phase 3 complete: Full navigation and local data integration"`
- [ ] Consider creating a tag: `git tag v0.3-connected`

---

## Phase 3 Completion Checklist

- [ ] MainTabView with 5 tabs
- [ ] All ViewModels created and integrated
- [ ] Plank timer saves real data locally
- [ ] Manual entry saves real data locally
- [ ] Progress shows real user data
- [ ] Leaderboards show mixed mock + real data
- [ ] Groups show mock data with navigation
- [ ] Profile shows real stats + mock social
- [ ] Settings persist and work correctly
- [ ] Notifications can be enabled/scheduled
- [ ] Onboarding flow works
- [ ] All navigation flows tested
- [ ] Data persists across app restarts
- [ ] All changes committed to Git

---

## Next Steps

With Phase 3 complete, you have a fully navigable prototype with real local data for plank tracking. Move to **Phase 4: Perfect the Core Plank Experience** to:
1. Polish timer UX (animations, haptics)
2. Perfect the completion flow
3. Handle edge cases
4. Apply Apple Health-inspired design polish
5. Add accessibility support

Proceed to `PHASE_4_CORE_EXPERIENCE.md` when ready.
