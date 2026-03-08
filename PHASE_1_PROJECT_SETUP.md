# Phase 1: Project Setup & Foundation

**Goal:** Set up the complete project structure, install all necessary dependencies, configure the development environment, and establish a solid foundation for the Plank Challenge app.

**Outcome:** A fully configured Xcode project with proper structure, data models, base UI components, and all configuration in place — ready for Phase 2 screen development.

---

## Prerequisites

Before starting, ensure you have:
- [ ] macOS with latest stable version
- [ ] Xcode 15+ installed (for iOS 16+ and SwiftUI/SwiftData support)
- [ ] Apple Developer account (free tier is fine for development)
- [ ] Git installed for version control

---

## Step 1: Create Xcode Project

### 1.1 Create New Project
- [ ] Open Xcode
- [ ] File → New → Project
- [ ] Select "App" under iOS
- [ ] Configure project:
  - **Product Name:** PlankChallenge
  - **Team:** Select your development team (or Personal Team)
  - **Organization Identifier:** com.yourname (e.g., com.leo.plankchallenge)
  - **Interface:** SwiftUI
  - **Language:** Swift
  - **Storage:** SwiftData (check this option)
  - **Include Tests:** Yes (both Unit and UI tests)
- [ ] Choose location: `/Users/lbaceviciuscloudflare.com/Developer/Personal projects/plank-challenge`
- [ ] Create the project

### 1.2 Configure Project Settings
- [ ] Select project in navigator → Select target "PlankChallenge"
- [ ] **General tab:**
  - [ ] Set "Minimum Deployments" to iOS 16.0
  - [ ] Set "Display Name" to "Plank Challenge"
  - [ ] Verify Bundle Identifier is correct
- [ ] **Signing & Capabilities tab:**
  - [ ] Ensure "Automatically manage signing" is checked
  - [ ] Select your Team
- [ ] **Build Settings tab:**
  - [ ] Search for "Swift Language Version" → Ensure Swift 5 or later

### 1.3 Add Required Capabilities
- [ ] Select target → Signing & Capabilities tab
- [ ] Click "+ Capability" and add:
  - [ ] **Push Notifications** (for daily reminders)
  - [ ] **Background Modes** (optional, for future background sync)

### 1.4 Configure Info.plist
- [ ] Add the following keys (if not already present):
  - [ ] `NSPhotoLibraryUsageDescription` — "Plank Challenge needs access to your photos to set your profile picture."
  - [ ] `NSCameraUsageDescription` — "Plank Challenge needs camera access to take a profile picture." (optional)
  - [ ] `UIUserInterfaceStyle` — Leave unset to support both light and dark mode

---

## Step 2: Initialize Git Repository

### 2.1 Create Git Repository
- [ ] Open Terminal in project directory
- [ ] Run: `git init`
- [ ] Create `.gitignore` file with standard Xcode ignores:
  ```
  # Xcode
  *.xcodeproj/*
  !*.xcodeproj/project.pbxproj
  !*.xcodeproj/xcshareddata/
  *.xcworkspace/*
  !*.xcworkspace/contents.xcworkspacedata
  *.xcuserdata/
  
  # Build
  build/
  DerivedData/
  
  # CocoaPods (if used)
  Pods/
  
  # Swift Package Manager
  .swiftpm/
  .build/
  
  # macOS
  .DS_Store
  *.swp
  *~
  
  # Secrets (never commit)
  *.xcconfig
  Secrets/
  ```

### 2.2 Initial Commit
- [ ] Run: `git add .`
- [ ] Run: `git commit -m "Initial project setup: Xcode project with SwiftUI and SwiftData"`

---

## Step 3: Create Folder Structure

### 3.1 Create Group/Folder Hierarchy
In Xcode, create the following group structure under the main "PlankChallenge" folder:

- [ ] **App/** — App entry point and configuration
  - [ ] Move `PlankChallengeApp.swift` here
  - [ ] Move `ContentView.swift` here (will be refactored later)

- [ ] **Models/** — Data models
  - [ ] Create folder

- [ ] **Views/** — All SwiftUI views organized by feature
  - [ ] Create folder
  - [ ] Create subfolders:
    - [ ] **Plank/** — Timer, manual entry screens
    - [ ] **Progress/** — History, stats, charts
    - [ ] **Leaderboards/** — Global and group leaderboards
    - [ ] **Groups/** — Group list, detail, creation
    - [ ] **Profile/** — User profile, other user profiles
    - [ ] **Settings/** — App settings
    - [ ] **Notifications/** — Notification center
    - [ ] **Components/** — Reusable UI components

- [ ] **ViewModels/** — View models for MVVM pattern
  - [ ] Create folder

- [ ] **Services/** — Business logic and services
  - [ ] Create folder

- [ ] **Utilities/** — Helper functions, extensions, constants
  - [ ] Create folder
  - [ ] Create subfolder: **Extensions/**

- [ ] **Resources/** — Assets, fonts, images
  - [ ] Move `Assets.xcassets` here (or reference it)
  - [ ] Create subfolder: **Images/** (for plank form images)

- [ ] **MockData/** — Mock data for development
  - [ ] Create folder

### 3.2 Verify Structure
- [ ] Ensure all folders are properly linked in Xcode (yellow folders, not blue)
- [ ] Build project to ensure no file reference issues (Cmd+B)

### 3.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add folder structure for app organization"`

---

## Step 4: Create Constants & Configuration

### 4.1 Create Constants File
- [ ] Create `Constants.swift` in **Utilities/**
- [ ] Add the following content:

```swift
import Foundation

enum Constants {
    
    // MARK: - Plank Rules
    enum Plank {
        /// Minimum valid plank duration in seconds
        static let minimumDurationSeconds: TimeInterval = 10
        
        /// Maximum plank duration in seconds (1 hour)
        static let maximumDurationSeconds: TimeInterval = 3600
        
        /// Available plank types
        enum PlankType: String, CaseIterable, Codable {
            case elbow = "Elbow Plank"
            case straightArm = "Straight Arm Plank"
            case parallettes = "Parallettes Plank"
            
            var imageName: String {
                switch self {
                case .elbow: return "plank_elbow"
                case .straightArm: return "plank_straight_arm"
                case .parallettes: return "plank_parallettes"
                }
            }
            
            var description: String {
                switch self {
                case .elbow: return "Forearms on ground"
                case .straightArm: return "Hands on ground, arms extended"
                case .parallettes: return "Using parallettes"
                }
            }
        }
    }
    
    // MARK: - Streak System
    enum Streak {
        /// Maximum number of freeze tokens a user can have
        static let maxFreezeTokens: Int = 2
        
        /// Initial freeze tokens for new users
        static let initialFreezeTokens: Int = 2
        
        /// Streak length required to earn a bonus token
        static let streakForBonusToken: Int = 20
        
        /// Badge milestone days
        static let badgeMilestones: [Int] = [7, 14, 30, 60, 90, 180, 365]
    }
    
    // MARK: - Groups
    enum Groups {
        /// Maximum number of groups a user can join
        static let maxGroupsPerUser: Int = 50
        
        /// Maximum members per group
        static let maxMembersPerGroup: Int = 1000
    }
    
    // MARK: - Notifications
    enum Notifications {
        /// Default reminder hour (24-hour format)
        static let defaultReminderHour: Int = 15 // 3:00 PM
        
        /// Default reminder minute
        static let defaultReminderMinute: Int = 0
    }
    
    // MARK: - UI
    enum UI {
        /// Timer update interval in seconds
        static let timerUpdateInterval: TimeInterval = 0.01 // 10ms for smooth milliseconds
    }
    
    // MARK: - Storage Keys
    enum StorageKeys {
        static let preferredPlankType = "preferredPlankType"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
}
```

### 4.2 Create App Configuration
- [ ] Create `AppConfig.swift` in **Utilities/**
- [ ] Add environment and feature flags:

```swift
import Foundation

enum AppConfig {
    /// Current app environment
    enum Environment {
        case development
        case staging
        case production
    }
    
    static let currentEnvironment: Environment = .development
    
    /// Feature flags
    enum Features {
        /// Whether to use mock data (Phase 1-4: true, Phase 5: false)
        static let useMockData: Bool = true
        
        /// Whether backend sync is enabled
        static let syncEnabled: Bool = false
        
        /// Whether analytics are enabled
        static let analyticsEnabled: Bool = false
    }
    
    /// App information
    enum AppInfo {
        static let appName = "Plank Challenge"
        static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
```

### 4.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add constants and app configuration"`

---

## Step 5: Create Data Models

### 5.1 Create PlankSession Model
- [ ] Create `PlankSession.swift` in **Models/**

```swift
import Foundation
import SwiftData

@Model
final class PlankSession {
    /// Unique identifier
    var id: UUID
    
    /// Date and time when the plank was performed
    var date: Date
    
    /// Duration of the plank in seconds
    var durationSeconds: TimeInterval
    
    /// Type of plank performed
    var plankTypeRaw: String
    
    /// How the plank was recorded
    var inputMethodRaw: String
    
    /// User's timezone identifier when plank was recorded
    var timezoneIdentifier: String
    
    /// Date the record was created
    var createdAt: Date
    
    /// Date the record was last modified
    var modifiedAt: Date
    
    // MARK: - Computed Properties
    
    var plankType: Constants.Plank.PlankType {
        get { Constants.Plank.PlankType(rawValue: plankTypeRaw) ?? .elbow }
        set { plankTypeRaw = newValue.rawValue }
    }
    
    var inputMethod: InputMethod {
        get { InputMethod(rawValue: inputMethodRaw) ?? .timer }
        set { inputMethodRaw = newValue.rawValue }
    }
    
    var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        let milliseconds = Int((durationSeconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    var localDate: Date {
        // Return date adjusted for the timezone it was recorded in
        guard let timezone = TimeZone(identifier: timezoneIdentifier) else { return date }
        let calendar = Calendar.current
        return calendar.date(bySettingHour: calendar.component(.hour, from: date),
                            minute: calendar.component(.minute, from: date),
                            second: calendar.component(.second, from: date),
                            of: date) ?? date
    }
    
    // MARK: - Enums
    
    enum InputMethod: String, Codable {
        case timer = "timer"
        case manual = "manual"
    }
    
    // MARK: - Initializer
    
    init(
        date: Date = Date(),
        durationSeconds: TimeInterval,
        plankType: Constants.Plank.PlankType,
        inputMethod: InputMethod = .timer
    ) {
        self.id = UUID()
        self.date = date
        self.durationSeconds = durationSeconds
        self.plankTypeRaw = plankType.rawValue
        self.inputMethodRaw = inputMethod.rawValue
        self.timezoneIdentifier = TimeZone.current.identifier
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
```

### 5.2 Create UserProfile Model
- [ ] Create `UserProfile.swift` in **Models/**

```swift
import Foundation
import SwiftData

@Model
final class UserProfile {
    /// Unique identifier
    var id: UUID
    
    /// User's display name
    var displayName: String
    
    /// User's bio/description
    var bio: String
    
    /// Preferred plank type
    var preferredPlankTypeRaw: String
    
    /// Profile image data (local storage)
    @Attribute(.externalStorage)
    var profileImageData: Data?
    
    /// Social link (optional)
    var socialLink: String?
    
    /// LinkedIn link (optional)
    var linkedInLink: String?
    
    /// Current streak count
    var currentStreak: Int
    
    /// Longest streak ever achieved
    var longestStreak: Int
    
    /// Number of freeze tokens remaining
    var freezeTokens: Int
    
    /// Date of last plank (for streak calculation)
    var lastPlankDate: Date?
    
    /// Date profile was created
    var createdAt: Date
    
    /// Date profile was last modified
    var modifiedAt: Date
    
    // MARK: - Computed Properties
    
    var preferredPlankType: Constants.Plank.PlankType {
        get { Constants.Plank.PlankType(rawValue: preferredPlankTypeRaw) ?? .elbow }
        set { preferredPlankTypeRaw = newValue.rawValue }
    }
    
    // MARK: - Initializer
    
    init(displayName: String = "Planker") {
        self.id = UUID()
        self.displayName = displayName
        self.bio = ""
        self.preferredPlankTypeRaw = Constants.Plank.PlankType.elbow.rawValue
        self.profileImageData = nil
        self.socialLink = nil
        self.linkedInLink = nil
        self.currentStreak = 0
        self.longestStreak = 0
        self.freezeTokens = Constants.Streak.initialFreezeTokens
        self.lastPlankDate = nil
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
```

### 5.3 Create Badge Model
- [ ] Create `Badge.swift` in **Models/**

```swift
import Foundation
import SwiftData

@Model
final class Badge {
    /// Unique identifier
    var id: UUID
    
    /// Badge type
    var badgeTypeRaw: String
    
    /// Date the badge was earned
    var dateEarned: Date
    
    // MARK: - Computed Properties
    
    var badgeType: BadgeType? {
        BadgeType(rawValue: badgeTypeRaw)
    }
    
    // MARK: - Badge Types
    
    enum BadgeType: String, CaseIterable, Codable {
        case streak7 = "streak_7"
        case streak14 = "streak_14"
        case streak30 = "streak_30"
        case streak60 = "streak_60"
        case streak90 = "streak_90"
        case streak180 = "streak_180"
        case streak365 = "streak_365"
        
        var streakDays: Int {
            switch self {
            case .streak7: return 7
            case .streak14: return 14
            case .streak30: return 30
            case .streak60: return 60
            case .streak90: return 90
            case .streak180: return 180
            case .streak365: return 365
            }
        }
        
        var displayName: String {
            switch self {
            case .streak7: return "1 Week Warrior"
            case .streak14: return "2 Week Champion"
            case .streak30: return "Monthly Master"
            case .streak60: return "60 Day Dedication"
            case .streak90: return "Quarter Year Quest"
            case .streak180: return "Half Year Hero"
            case .streak365: return "Year of Planking"
            }
        }
        
        var description: String {
            "\(streakDays) day streak achieved"
        }
        
        var iconName: String {
            "medal.fill" // SF Symbol
        }
        
        static func badgeFor(streakDays: Int) -> BadgeType? {
            // Return the highest badge earned for given streak
            let sortedTypes = BadgeType.allCases.sorted { $0.streakDays > $1.streakDays }
            return sortedTypes.first { streakDays >= $0.streakDays }
        }
    }
    
    // MARK: - Initializer
    
    init(badgeType: BadgeType) {
        self.id = UUID()
        self.badgeTypeRaw = badgeType.rawValue
        self.dateEarned = Date()
    }
}
```

### 5.4 Create AppNotification Model
- [ ] Create `AppNotification.swift` in **Models/**

```swift
import Foundation
import SwiftData

@Model
final class AppNotification {
    /// Unique identifier
    var id: UUID
    
    /// Notification type
    var notificationTypeRaw: String
    
    /// Notification title
    var title: String
    
    /// Notification message
    var message: String
    
    /// Whether the notification has been read
    var isRead: Bool
    
    /// Date the notification was created
    var createdAt: Date
    
    /// Related entity ID (e.g., group ID)
    var relatedEntityId: String?
    
    // MARK: - Computed Properties
    
    var notificationType: NotificationType? {
        NotificationType(rawValue: notificationTypeRaw)
    }
    
    // MARK: - Notification Types
    
    enum NotificationType: String, Codable {
        case streakFreezeUsed = "streak_freeze_used"
        case badgeEarned = "badge_earned"
        case groupJoined = "group_joined"
        case groupRemoved = "group_removed"
        case groupDeleted = "group_deleted"
        case joinRequestApproved = "join_request_approved"
        case joinRequestDenied = "join_request_denied"
        case promotedToAdmin = "promoted_to_admin"
        case tokenEarned = "token_earned"
        
        var iconName: String {
            switch self {
            case .streakFreezeUsed: return "snowflake"
            case .badgeEarned: return "medal.fill"
            case .groupJoined: return "person.3.fill"
            case .groupRemoved: return "person.fill.xmark"
            case .groupDeleted: return "trash.fill"
            case .joinRequestApproved: return "checkmark.circle.fill"
            case .joinRequestDenied: return "xmark.circle.fill"
            case .promotedToAdmin: return "star.fill"
            case .tokenEarned: return "snowflake.circle.fill"
            }
        }
    }
    
    // MARK: - Initializer
    
    init(
        type: NotificationType,
        title: String,
        message: String,
        relatedEntityId: String? = nil
    ) {
        self.id = UUID()
        self.notificationTypeRaw = type.rawValue
        self.title = title
        self.message = message
        self.isRead = false
        self.createdAt = Date()
        self.relatedEntityId = relatedEntityId
    }
}
```

### 5.5 Create Group Model (for Mock Data Structure)
- [ ] Create `Group.swift` in **Models/**

```swift
import Foundation
import SwiftData

@Model
final class PlankGroup {
    /// Unique identifier
    var id: UUID
    
    /// Group name
    var name: String
    
    /// Group description
    var descriptionText: String
    
    /// Group type
    var groupTypeRaw: String
    
    /// Join mode (for public groups)
    var joinModeRaw: String
    
    /// Group image data
    @Attribute(.externalStorage)
    var imageData: Data?
    
    /// Member count (for display)
    var memberCount: Int
    
    /// Whether current user is admin
    var isCurrentUserAdmin: Bool
    
    /// Whether current user is member
    var isCurrentUserMember: Bool
    
    /// Date group was created
    var createdAt: Date
    
    // MARK: - Computed Properties
    
    var groupType: GroupType {
        get { GroupType(rawValue: groupTypeRaw) ?? .publicOpen }
        set { groupTypeRaw = newValue.rawValue }
    }
    
    var joinMode: JoinMode {
        get { JoinMode(rawValue: joinModeRaw) ?? .open }
        set { joinModeRaw = newValue.rawValue }
    }
    
    // MARK: - Enums
    
    enum GroupType: String, Codable {
        case publicOpen = "public"
        case privateInvite = "private"
    }
    
    enum JoinMode: String, Codable {
        case open = "open"
        case requestToJoin = "request"
    }
    
    // MARK: - Initializer
    
    init(
        name: String,
        description: String = "",
        groupType: GroupType = .publicOpen,
        joinMode: JoinMode = .open
    ) {
        self.id = UUID()
        self.name = name
        self.descriptionText = description
        self.groupTypeRaw = groupType.rawValue
        self.joinModeRaw = joinMode.rawValue
        self.imageData = nil
        self.memberCount = 1
        self.isCurrentUserAdmin = true
        self.isCurrentUserMember = true
        self.createdAt = Date()
    }
}
```

### 5.6 Create MockUser Model (for Leaderboards/Social)
- [ ] Create `MockUser.swift` in **Models/**

```swift
import Foundation

/// Model for mock users in leaderboards and social features
/// Not persisted with SwiftData - loaded from mock data
struct MockUser: Identifiable, Codable {
    let id: UUID
    let displayName: String
    let profileImageName: String? // Asset name or SF Symbol
    let currentStreak: Int
    let longestPlankSeconds: TimeInterval
    let totalPlanks: Int
    let badges: [Badge.BadgeType]
    
    var longestPlankFormatted: String {
        let minutes = Int(longestPlankSeconds) / 60
        let seconds = Int(longestPlankSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(
        id: UUID = UUID(),
        displayName: String,
        profileImageName: String? = nil,
        currentStreak: Int,
        longestPlankSeconds: TimeInterval,
        totalPlanks: Int,
        badges: [Badge.BadgeType] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.profileImageName = profileImageName
        self.currentStreak = currentStreak
        self.longestPlankSeconds = longestPlankSeconds
        self.totalPlanks = totalPlanks
        self.badges = badges
    }
}
```

### 5.7 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add data models: PlankSession, UserProfile, Badge, AppNotification, Group, MockUser"`

---

## Step 6: Configure SwiftData Container

### 6.1 Update App Entry Point
- [ ] Update `PlankChallengeApp.swift` in **App/**:

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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### 6.2 Update ContentView (Placeholder)
- [ ] Update `ContentView.swift` in **App/**:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        // Placeholder - will be replaced with TabView in Phase 3
        VStack(spacing: 20) {
            Image(systemName: "figure.core.training")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Plank Challenge")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Ready to build your foundation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

### 6.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Configure SwiftData container and update app entry point"`

---

## Step 7: Create Base Services

### 7.1 Create DataService
- [ ] Create `DataService.swift` in **Services/**:

```swift
import Foundation
import SwiftData

/// Service for managing local data operations
@MainActor
class DataService: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - User Profile
    
    func getOrCreateUserProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        
        if let existingProfile = try? modelContext.fetch(descriptor).first {
            return existingProfile
        }
        
        // Create new profile
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }
    
    // MARK: - Plank Sessions
    
    func savePlankSession(_ session: PlankSession) {
        modelContext.insert(session)
        try? modelContext.save()
    }
    
    func getPlankSessions() -> [PlankSession] {
        let descriptor = FetchDescriptor<PlankSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func getTodaysPlank() -> PlankSession? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<PlankSession> { session in
            session.date >= startOfDay && session.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<PlankSession>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
    
    func hasPlankToday() -> Bool {
        getTodaysPlank() != nil
    }
    
    func deletePlankSession(_ session: PlankSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
    
    // MARK: - Badges
    
    func awardBadge(_ badgeType: Badge.BadgeType) {
        // Check if already earned
        let descriptor = FetchDescriptor<Badge>()
        let existingBadges = (try? modelContext.fetch(descriptor)) ?? []
        
        guard !existingBadges.contains(where: { $0.badgeTypeRaw == badgeType.rawValue }) else {
            return
        }
        
        let badge = Badge(badgeType: badgeType)
        modelContext.insert(badge)
        try? modelContext.save()
    }
    
    func getEarnedBadges() -> [Badge] {
        let descriptor = FetchDescriptor<Badge>(
            sortBy: [SortDescriptor(\.dateEarned, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Notifications
    
    func addNotification(_ notification: AppNotification) {
        modelContext.insert(notification)
        try? modelContext.save()
    }
    
    func getNotifications() -> [AppNotification] {
        let descriptor = FetchDescriptor<AppNotification>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func markNotificationAsRead(_ notification: AppNotification) {
        notification.isRead = true
        try? modelContext.save()
    }
    
    func getUnreadNotificationCount() -> Int {
        let predicate = #Predicate<AppNotification> { notification in
            notification.isRead == false
        }
        let descriptor = FetchDescriptor<AppNotification>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).count) ?? 0
    }
}
```

### 7.2 Create TimerService
- [ ] Create `TimerService.swift` in **Services/**:

```swift
import Foundation
import Combine

/// Service for managing the plank timer
class TimerService: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    
    private var timer: Timer?
    private var startTime: Date?
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    var isAtMinimumDuration: Bool {
        elapsedTime >= Constants.Plank.minimumDurationSeconds
    }
    
    var isAtMaximumDuration: Bool {
        elapsedTime >= Constants.Plank.maximumDurationSeconds
    }
    
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        startTime = Date()
        elapsedTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: Constants.UI.timerUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            
            self.elapsedTime = Date().timeIntervalSince(startTime)
            
            // Auto-stop at maximum duration
            if self.isAtMaximumDuration {
                self.stop()
            }
        }
        
        // Ensure timer runs even when scrolling
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func reset() {
        stop()
        elapsedTime = 0
        startTime = nil
    }
}
```

### 7.3 Create NotificationService
- [ ] Create `NotificationService.swift` in **Services/**:

```swift
import Foundation
import UserNotifications

/// Service for managing push notifications
class NotificationService: ObservableObject {
    @Published var isAuthorized: Bool = false
    
    static let shared = NotificationService()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    func scheduleDailyReminder(hour: Int, minute: Int) {
        // Remove existing reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_plank_reminder"]
        )
        
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Plank!"
        content.body = "Don't break your streak. Complete your daily plank now."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily_plank_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_plank_reminder"]
        )
    }
    
    func sendStreakFreezeNotification(tokensRemaining: Int) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Streak Saved!"
        content.body = "Your streak freeze token was used. You have \(tokensRemaining) remaining. Don't forget to plank today!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "streak_freeze_\(UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
```

### 7.4 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add base services: DataService, TimerService, NotificationService"`

---

## Step 8: Create Utility Extensions

### 8.1 Create Date Extensions
- [ ] Create `Date+Extensions.swift` in **Utilities/Extensions/**:

```swift
import Foundation

extension Date {
    /// Returns true if date is today in the current timezone
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if date is yesterday in the current timezone
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns the start of the day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the day for this date
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
    }
    
    /// Returns formatted date string (e.g., "Mar 8, 2026")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Returns formatted time string (e.g., "3:45 PM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Returns relative date string (e.g., "Today", "Yesterday", "Mar 5")
    var relativeFormatted: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return formattedDate
        }
    }
    
    /// Number of days between this date and another
    func daysBetween(_ other: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startOfDay, to: other.startOfDay)
        return abs(components.day ?? 0)
    }
}
```

### 8.2 Create TimeInterval Extensions
- [ ] Create `TimeInterval+Extensions.swift` in **Utilities/Extensions/**:

```swift
import Foundation

extension TimeInterval {
    /// Returns formatted duration string (e.g., "2:35")
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Returns formatted duration with milliseconds (e.g., "02:35.42")
    var formattedDurationWithMilliseconds: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let milliseconds = Int((self.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    /// Returns verbose duration string (e.g., "2 min 35 sec")
    var verboseDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        
        if minutes > 0 {
            return "\(minutes) min \(seconds) sec"
        } else {
            return "\(seconds) sec"
        }
    }
}
```

### 8.3 Create View Extensions
- [ ] Create `View+Extensions.swift` in **Utilities/Extensions/**:

```swift
import SwiftUI

extension View {
    /// Keeps the screen awake while this view is displayed
    func keepScreenAwake(_ isActive: Bool = true) -> some View {
        self.onAppear {
            UIApplication.shared.isIdleTimerDisabled = isActive
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    /// Applies a card-style background (Apple Health-inspired)
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
```

### 8.4 Create Color Extensions
- [ ] Create `Color+Extensions.swift` in **Utilities/Extensions/**:

```swift
import SwiftUI

extension Color {
    // MARK: - App Colors (Apple Health-inspired)
    
    /// Primary accent color
    static let appAccent = Color.blue
    
    /// Streak color (orange/red gradient would be nice)
    static let streakColor = Color.orange
    
    /// Success color
    static let successColor = Color.green
    
    /// Warning color
    static let warningColor = Color.yellow
    
    /// Error color
    static let errorColor = Color.red
    
    // MARK: - Plank Type Colors
    
    static func colorForPlankType(_ type: Constants.Plank.PlankType) -> Color {
        switch type {
        case .elbow:
            return .blue
        case .straightArm:
            return .green
        case .parallettes:
            return .purple
        }
    }
}
```

### 8.5 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add utility extensions: Date, TimeInterval, View, Color"`

---

## Step 9: Create Reusable UI Components

### 9.1 Create StatCard Component
- [ ] Create `StatCard.swift` in **Views/Components/**:

```swift
import SwiftUI

/// A card displaying a single statistic (Apple Health-inspired)
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        color: Color = .blue
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    VStack {
        StatCard(
            title: "Current Streak",
            value: "14",
            subtitle: "days",
            icon: "flame.fill",
            color: .orange
        )
        
        StatCard(
            title: "Longest Plank",
            value: "3:45",
            subtitle: "personal best",
            icon: "trophy.fill",
            color: .yellow
        )
    }
    .padding()
}
```

### 9.2 Create PlankTypeSelector Component
- [ ] Create `PlankTypeSelector.swift` in **Views/Components/**:

```swift
import SwiftUI

/// Selector for choosing plank type
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
            .background(isSelected ? Color.appAccent.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlankTypeSelector(selectedType: .constant(.elbow))
        .padding()
}
```

### 9.3 Create BadgeView Component
- [ ] Create `BadgeView.swift` in **Views/Components/**:

```swift
import SwiftUI

/// Displays a single badge (earned or locked)
struct BadgeView: View {
    let badgeType: Badge.BadgeType
    let isEarned: Bool
    let dateEarned: Date?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Image(systemName: badgeType.iconName)
                    .font(.system(size: 30))
                    .foregroundStyle(isEarned ? .yellow : .gray.opacity(0.5))
            }
            
            Text(badgeType.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? .primary : .secondary)
            
            if isEarned, let date = dateEarned {
                Text(date.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(badgeType.streakDays) days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100)
        .opacity(isEarned ? 1.0 : 0.6)
    }
}

#Preview {
    HStack {
        BadgeView(
            badgeType: .streak7,
            isEarned: true,
            dateEarned: Date()
        )
        
        BadgeView(
            badgeType: .streak30,
            isEarned: false,
            dateEarned: nil
        )
    }
}
```

### 9.4 Create TokenIndicator Component
- [ ] Create `TokenIndicator.swift` in **Views/Components/**:

```swift
import SwiftUI

/// Displays streak freeze tokens
struct TokenIndicator: View {
    let tokensRemaining: Int
    let maxTokens: Int
    
    init(tokensRemaining: Int, maxTokens: Int = Constants.Streak.maxFreezeTokens) {
        self.tokensRemaining = tokensRemaining
        self.maxTokens = maxTokens
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "snowflake")
                .foregroundStyle(.cyan)
            
            HStack(spacing: 2) {
                ForEach(0..<maxTokens, id: \.self) { index in
                    Image(systemName: index < tokensRemaining ? "circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(index < tokensRemaining ? .cyan : .gray.opacity(0.3))
                }
            }
        }
    }
}

#Preview {
    VStack {
        TokenIndicator(tokensRemaining: 2)
        TokenIndicator(tokensRemaining: 1)
        TokenIndicator(tokensRemaining: 0)
    }
}
```

### 9.5 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add reusable UI components: StatCard, PlankTypeSelector, BadgeView, TokenIndicator"`

---

## Step 10: Set Up Asset Catalog

### 10.1 Configure App Icon
- [ ] Open `Assets.xcassets`
- [ ] Select `AppIcon`
- [ ] Add placeholder icons (can be updated later with real design)
  - For now, create a simple icon or leave empty

### 10.2 Add Color Sets
- [ ] In `Assets.xcassets`, create color sets:
  - [ ] `AccentColor` (already exists, set to blue)
  
### 10.3 Create Image Placeholders
- [ ] Create `Images` folder in `Assets.xcassets`
- [ ] Add placeholder image sets for:
  - [ ] `plank_elbow` — placeholder for elbow plank form
  - [ ] `plank_straight_arm` — placeholder for straight arm plank form
  - [ ] `plank_parallettes` — placeholder for parallettes plank form
  - [ ] `profile_placeholder` — default avatar image

### 10.4 Commit
- [ ] `git add .`
- [ ] `git commit -m "Set up asset catalog with placeholders"`

---

## Step 11: Final Verification

### 11.1 Build and Run
- [ ] Build the project (Cmd+B) — should succeed with no errors
- [ ] Run on simulator (Cmd+R) — should show placeholder ContentView
- [ ] Verify no warnings or deprecation notices

### 11.2 Test SwiftData
- [ ] Temporarily add test code to verify data persistence works:
  - Create a test PlankSession
  - Save it
  - Fetch and verify it exists
- [ ] Remove test code after verification

### 11.3 Review Project Structure
- [ ] Verify all folders are properly organized
- [ ] Ensure no orphaned files
- [ ] Check all imports are correct

### 11.4 Final Commit
- [ ] `git add .`
- [ ] `git commit -m "Phase 1 complete: Project foundation ready"`
- [ ] Consider creating a tag: `git tag v0.1-foundation`

---

## Phase 1 Completion Checklist

- [ ] Xcode project created with SwiftUI and SwiftData
- [ ] iOS 16+ minimum deployment configured
- [ ] Git repository initialized with proper .gitignore
- [ ] Folder structure created and organized
- [ ] Constants and configuration files created
- [ ] All data models created (PlankSession, UserProfile, Badge, AppNotification, Group, MockUser)
- [ ] SwiftData container configured
- [ ] Base services created (DataService, TimerService, NotificationService)
- [ ] Utility extensions created (Date, TimeInterval, View, Color)
- [ ] Reusable UI components created (StatCard, PlankTypeSelector, BadgeView, TokenIndicator)
- [ ] Asset catalog set up with placeholders
- [ ] Project builds and runs successfully
- [ ] All changes committed to Git

---

## Next Steps

With Phase 1 complete, you're ready to move to **Phase 2: Mock Data & Individual Screens**, where you'll:
1. Create comprehensive mock data
2. Build each screen as a standalone component
3. Focus on visual design and layout

Proceed to `PHASE_2_MOCK_DATA_SCREENS.md` when ready.
