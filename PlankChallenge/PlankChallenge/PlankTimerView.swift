//
//  PlankTimerView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

// MARK: - Timer Mode

enum TimerMode: String, CaseIterable {
    case free = "Stopwatch"
    case goal = "Countdown"
}

// MARK: - Plank Timer State Machine

enum PlankTimerState: Equatable {
    case ready
    case countdown(Int)  // 3, 2, 1
    case active
    case celebration
    case completedToday  // Plank done for today - shows celebration bubbles
    
    var isCountingDown: Bool {
        if case .countdown = self { return true }
        return false
    }
    
    var countdownValue: Int? {
        if case .countdown(let value) = self { return value }
        return nil
    }
    
    var showsCelebrationBubbles: Bool {
        self == .celebration || self == .completedToday
    }
}

struct PlankTimerView: View {
    @State private var timerService = TimerService()
    @Environment(\.plankService) private var plankService
    @Environment(\.streakService) private var streakService
    @Environment(\.badgeService) private var badgeService
    @Environment(\.leaderboardService) private var leaderboardService
    @Environment(\.userService) private var userService
    
    @State private var saveError: String?
    @State private var showingManualEntry = false
    @State private var buttonScale: CGFloat = 1.0
    
    // Enhanced timer state
    // Note: double-tap protection during save is handled by the state machine —
    // the .celebration case returns `break` in handleButtonTap(), so the button
    // is a no-op while the save is in flight. No separate isSaving flag is needed.
    @State private var timerState: PlankTimerState = .ready
    @State private var countdownTimer: Timer?
    @State private var celebrationTimer: Timer?
    @State private var saveTask: Task<Void, Never>?
    @State private var goalSyncTask: Task<Void, Never>?
    
    // Timer mode: free (count up) or goal (countdown from a target)
    @State private var timerMode: TimerMode = .free
    
    // MARK: - Shifting background gradient
    // Cycles through Color.plankPhaseBottomColors every 40s (10s hold + 30s transition).
    @State private var gradientPhase: Int = 0
    @State private var currentBottomColor: Color = Color.plankPhaseBottomColors[0]
    @State private var currentGlowColor: Color = Color.plankPhaseGlowColors[0]
    @State private var gradientCycleTimer: Timer?
    
    // Goal duration stored locally and synced to backend
    @AppStorage("plankGoalSeconds") private var storedGoalSeconds: Int = 60
    // Wheel picker state — kept in sync with storedGoalSeconds
    @State private var selectedMinutes: Int = 1
    @State private var selectedSeconds: Int = 0
    
    // Settings
    @AppStorage("soundEnabled") private var soundEnabled = true
    
    // Today's plank data (persisted)
    @AppStorage("todayPlankDate") private var todayPlankDateString = ""
    @AppStorage("todayPlankTotalTime") private var todayPlankTotalTime: Double = 0
    @AppStorage("todayPlankCount") private var todayPlankCount: Int = 0
    @AppStorage("todayPlankTimesJSON") private var todayPlankTimesJSON: String = "[]"
    
    /// Get today's plank times as an array (most recent last)
    private var todayPlankTimes: [Double] {
        guard let data = todayPlankTimesJSON.data(using: .utf8),
              let times = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return times
    }
    
    /// Add a plank time to today's list
    private func addPlankTime(_ time: Double) {
        var times = todayPlankTimes
        times.append(time)
        if let data = try? JSONEncoder().encode(times),
           let json = String(data: data, encoding: .utf8) {
            todayPlankTimesJSON = json
        }
    }
    
    /// Clear today's plank times
    private func clearPlankTimes() {
        todayPlankTimesJSON = "[]"
    }
    
    private let baseButtonSize: CGFloat = 220
    
    /// Calculate expanded button size based on screen width (with small padding from edges)
    private func expandedButtonSize(for screenWidth: CGFloat) -> CGFloat {
        screenWidth - 40 // 20pt padding on each side
    }
    
    /// Button size changes based on state - expands during active plank
    private func buttonSize(for screenWidth: CGFloat) -> CGFloat {
        timerState == .active ? expandedButtonSize(for: screenWidth) : baseButtonSize
    }
    
    private var countdownDuration: Int { Constants.Timer.countdownDuration }
    private var celebrationDuration: TimeInterval { Constants.Timer.celebrationDuration }
    
    /// Whether to hide navigation (tab bar and top bar) during active plank states
    private var shouldHideNavigation: Bool {
        switch timerState {
        case .countdown, .active, .celebration:
            return true
        case .ready, .completedToday:
            return false
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let currentButtonSize = buttonSize(for: geometry.size.width)
            let maxButtonSize = expandedButtonSize(for: geometry.size.width)
            
            // Calculate true screen center accounting for safe areas
            // This prevents the button from shifting when tab bar hides/shows
            let safeAreaTop = geometry.safeAreaInsets.top
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            let fullHeight = geometry.size.height + safeAreaTop + safeAreaBottom
            let centerY = fullHeight / 2 - safeAreaTop
            
            ZStack {
                // Full screen gradient background — animates between phase colors
                LinearGradient(
                    colors: [Color.plankGradientStart, currentBottomColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Celebration/CompletedToday: Lava lamp bubbles + overlay effects
                if timerState.showsCelebrationBubbles {
                    LavaBubblesView(
                        isCountdown: false,
                        isActive: true
                    )
                    
                    // Only show celebration overlay during actual celebration
                    if timerState == .celebration {
                        CelebrationOverlayView(isActive: true)
                    }
                }
                
                // FIXED CENTER: Button is absolutely positioned in true screen center
                // Uses calculated centerY to prevent shifting when tab bar hides/shows
                ZStack {
                    // Countdown ring animation
                    if let countdownValue = timerState.countdownValue {
                        CountdownOverlayView(
                            countdownValue: countdownValue,
                            buttonSize: currentButtonSize
                        )
                    }
                    
                    plankButton(size: currentButtonSize)
                }
                .position(x: geometry.size.width / 2, y: centerY)
                
                // Instruction text - positioned just above the button
                instructionText
                    .position(x: geometry.size.width / 2, y: centerY - (maxButtonSize / 2) - 50)
                
                // Mode selector + wheel picker — pinned below the button, only in .ready.
                // Anchored at the top of the pill so the pill Y never shifts when the
                // wheel expands downward. We use .frame(maxHeight:.infinity, alignment:.top)
                // inside a container placed at a fixed Y so .position() centres the
                // container — but the container is tall enough that the pill stays put.
                // .transition(.opacity) is required for animated removal from ZStack.
                if timerState == .ready {
                    timerModeSelector
                        // The view has a fixed height of 168pt (set inside timerModeSelector).
                        // .position() places the centre of the view at this coordinate.
                        // Centre = button bottom edge + 20pt gap + 84pt (half of 168) = +104pt.
                        // This is stable: the container height never changes, so the pill
                        // top never jumps when the wheel appears or disappears.
                        .position(
                            x: geometry.size.width / 2,
                            y: centerY + (baseButtonSize / 2) + 104
                        )
                        .transition(.opacity)
                }
                
                // Top bar overlay - fixed at top
                // Only shown in .ready state — in .completedToday the day is done,
                // so the manual entry button is hidden (one plank per day).
                VStack {
                    if timerState == .ready {
                        topBar
                    }
                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: timerState)
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .toolbar(shouldHideNavigation ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: shouldHideNavigation)
        .alert("Plank not saved", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Your plank couldn't be saved. Check your connection and try again.")
        }
        .onAppear {
            checkForNewDayOrExistingPlanks()
            // Seed wheel picker from stored goal, snapping seconds to nearest 5-second step
            selectedMinutes = storedGoalSeconds / 60
            selectedSeconds = ((storedGoalSeconds % 60) / 5) * 5
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: timerService.hasReachedGoal) { _, reached in
            // Auto-submit when the goal countdown hits zero.
            // The timerState guard is load-bearing: hasReachedGoal can remain true
            // briefly after stopPlank() moves state to .celebration, due to the
            // Timer tick Task executing after stop() is called. Without this guard,
            // stopPlank() would fire twice.
            guard reached, timerState == .active else { return }
            stopPlank()
        }
        .onChange(of: todayPlankCount) { oldValue, newValue in
            // If all planks were deleted (from Settings), transition back to ready state
            if newValue == 0 && timerState == .completedToday {
                withAnimation(.easeInOut(duration: 0.3)) {
                    timerState = .ready
                }
            }
        }
        .onChange(of: plankService.hasLoaded) { _, isLoaded in
            // Once PlankService has completed its initial sync with the server,
            // reconcile @AppStorage today-count against the authoritative server count.
            // This handles cases like: planks logged on another device today, or a
            // fresh install where @AppStorage defaults to 0 despite existing server data.
            guard isLoaded else { return }
            let serverCount = plankService.todayPlankCountFromServer
            let today = todayDateString()
            
            // Only reconcile if we're looking at today's data (not a stale date)
            if todayPlankDateString == today && serverCount != todayPlankCount {
                todayPlankCount = serverCount
                // Update timer state to match reconciled count
                if serverCount > 0 && timerState == .ready {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        timerState = .completedToday
                    }
                } else if serverCount == 0 && timerState == .completedToday {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        timerState = .ready
                    }
                }
            }
            
            // Also reconcile todayPlankTimesJSON from the server-synced planks list.
            // SettingsView reads exclusively from todayPlankTimesJSON to display
            // "Today's Planks" — if this is empty (e.g. fresh install, different device,
            // logout/login) it shows "Nothing yet today" even when the plank tab correctly
            // shows the streak and checkmark. Only populate when the local list is empty
            // to avoid overwriting a valid in-progress session.
            if todayPlankTimes.isEmpty && serverCount > 0 {
                let todayStr = todayDateString()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                // No explicit timeZone → matches device local time, consistent with todayDateString()
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let todayDurations: [Double] = plankService.planks.compactMap { plank in
                    // Try full ISO8601 with fractional seconds first, then without
                    let date = isoFormatter.date(from: plank.performedAt)
                        ?? ISO8601DateFormatter().date(from: plank.performedAt)
                    guard let date, dateFormatter.string(from: date) == todayStr else { return nil }
                    return plank.durationSeconds
                }
                
                if !todayDurations.isEmpty,
                   let encoded = try? JSONEncoder().encode(todayDurations),
                   let json = String(data: encoded, encoding: .utf8) {
                    todayPlankTimesJSON = json
                }
            }
        }
        .onChange(of: userService.currentUserProfile) { _, profile in
            // When the user profile loads (or is refreshed), apply the server's goal value.
            // Server is authoritative — it may differ from local AppStorage if the user
            // updated their goal on another device or after a reinstall.
            guard let serverGoal = profile?.plankGoalSeconds, serverGoal > 0 else { return }
            storedGoalSeconds = serverGoal
            selectedMinutes = serverGoal / 60
            selectedSeconds = ((serverGoal % 60) / 5) * 5
        }
        .onChange(of: plankService.hasPlankToday) { _, hasPlank in
            // React to plank state changes driven by PlankService rather than the
            // in-app timer. This covers two cases:
            //
            // 1. Manual entry: the user submits via the + sheet. createPlank() inserts
            //    the plank into planks[], hasPlankToday flips true → false, but
            //    hasLoaded never changes so the hasLoaded observer doesn't fire.
            //
            // 2. Delete from Settings: plankService.deletePlank() removes the plank,
            //    hasPlankToday flips true → false, and the timer should reset to .ready.
            let today = todayDateString()
            
            if hasPlank && timerState == .ready {
                // Plank was submitted externally (manual entry) — update AppStorage
                // and transition to the completed state.
                todayPlankCount = 1
                todayPlankDateString = today
                
                if let duration = plankService.todaysPlank?.durationSeconds,
                   let encoded = try? JSONEncoder().encode([duration]),
                   let json = String(data: encoded, encoding: .utf8) {
                    todayPlankTimesJSON = json
                    todayPlankTotalTime = duration
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    timerState = .completedToday
                }
                
            } else if !hasPlank && timerState == .completedToday {
                // Plank was deleted from Settings — reset AppStorage and go back to ready.
                todayPlankCount = 0
                todayPlankTimesJSON = "[]"
                todayPlankTotalTime = 0
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    timerState = .ready
                }
            }
        }
    }
    
    /// Check if it's a new day (reset state) or if we already have planks today (show completedToday)
    private func checkForNewDayOrExistingPlanks() {
        let today = todayDateString()
        
        if todayPlankDateString != today {
            // New day - reset to ready state
            todayPlankDateString = today
            todayPlankTotalTime = 0
            todayPlankCount = 0
            clearPlankTimes()
            timerState = .ready
        } else if todayPlankCount > 0 && timerState == .ready {
            // Same day and we already have planks - show completedToday state
            timerState = .completedToday
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        // Top button row: Manual entry (right only now that plank type is removed)
        HStack {
            Spacer()
            
            Spacer()
            
            // Manual entry button (right) - plus icon
            Button {
                showingManualEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(12)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Instruction Text
    
    /// Unique key for the current instruction state (for smooth transitions)
    private var instructionKey: String {
        switch timerState {
        case .ready:
            return "ready"
        case .countdown:
            return "countdown"
        case .active:
            return "plank"
        case .celebration:
            return "celebration"
        case .completedToday:
            return "completed"
        }
    }
    
    /// Main instruction title for current state
    private var instructionTitle: String? {
        switch timerState {
        case .ready:
            return nil  // No heading - streak message is in top bar
        case .countdown:
            return nil  // No heading - countdown number speaks for itself
        case .active:
            return nil  // No heading - timer is the focus
        case .celebration:
            return "Well done"
        case .completedToday:
            return nil  // No heading - button content is sufficient
        }
    }
    
    /// Secondary instruction text for current state
    private var instructionSubtitle: String? {
        switch timerState {
        case .ready:
            return nil  // No subtitle - streak message is in top bar
        case .countdown:
            return "Get into position"
        case .active:
            return "Tap to stop"
        case .celebration:
            return nil
        case .completedToday:
            return nil  // No subtitle - "Tap to plank again" is in button
        }
    }
    
    /// Primary text color (white works on both dark and colorful backgrounds)
    private var primaryTextColor: Color {
        .white
    }
    
    /// Secondary text color
    private var secondaryTextColor: Color {
        .white.opacity(0.8)
    }
    
    private var instructionText: some View {
        VStack(spacing: 8) {
            // Streak info for ready and completedToday states - positioned just above button
            if timerState == .ready || timerState == .completedToday {
                HStack(spacing: 8) {
                    // Animated flame when streak is protected (completedToday)
                    AnimatedFlameIcon(isAnimating: timerState == .completedToday)
                        .font(.title2)
                    if timerState == .ready {
                        if streakService.currentStreak > 0 {
                            Text("Protect your \(streakService.currentStreak)-day streak")
                        } else {
                            Text("Start your streak today")
                        }
                    } else {
                        Text("\(streakService.currentStreak)-day streak")
                    }
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .id(instructionKey)
                .transition(.opacity)
            }
            
            // Main title with slide transition (only shown when not nil)
            if let title = instructionTitle {
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryTextColor)
                    .id(instructionKey) // Triggers transition when key changes
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            
            // Secondary text with fade transition
            if let subtitle = instructionSubtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .animation(.easeInOut(duration: 0.3), value: instructionSubtitle)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: instructionKey)
    }
    
    // MARK: - Giant Plank Button
    
    @ViewBuilder
    private func plankButton(size: CGFloat) -> some View {
        // Calculate scale factor for smooth center-based expansion
        let scale = size / baseButtonSize
        
        Button(action: handleButtonTap) {
            ZStack {
                // Background layers that scale with the button
                ZStack {
                    // Animated outer ring during active plank
                    if timerState == .active {
                        ActivePlankRing(buttonSize: baseButtonSize)
                    } else {
                        // Static outer glow ring
                        Circle()
                            .stroke(Color.plankButtonGlow.opacity(0.3), lineWidth: 2)
                            .frame(width: baseButtonSize + 30, height: baseButtonSize + 30)
                    }
                    
                    // Main button circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.plankButtonInner, Color.plankButtonGlow],
                                center: .center,
                                startRadius: 0,
                                endRadius: baseButtonSize / 2
                            )
                        )
                        .frame(width: baseButtonSize, height: baseButtonSize)
                }
                .scaleEffect(scale)
                
                // Inner content - does NOT scale with the button
                // Uses the actual target size for proper font sizing
                buttonContent(for: size)
            }
            .animation(.easeInOut(duration: 0.5), value: scale)
            .pulsingGlow(color: Color.plankButtonGlow, isAnimating: timerState == .ready)
        }
        .buttonStyle(PlankButtonStyle())
        .scaleEffect(buttonScale)
    }
    
    // MARK: - Button Content
    
    @ViewBuilder
    private func buttonContent(for size: CGFloat) -> some View {
        switch timerState {
        case .ready:
            // Show logo and "Tap to plank" text
            VStack(spacing: 12) {
                Image("AppLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                
                Text("Tap to plank")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            
        case .countdown(let count):
            // Large countdown number with scale animation
            Text("\(count)")
                .font(.system(size: 100, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .transaction { transaction in
                    transaction.animation = .spring(response: 0.3, dampingFraction: 0.6)
                }
            
        case .active:
            // Show small logo above timer - scale based on button size
            let timerFontSize: CGFloat = size * 0.16 // ~56pt for 350pt button (20% smaller)
            let iconSize: CGFloat = size * 0.07      // ~24pt for 350pt button
            
            VStack(spacing: 12) {
                Image("AppLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize * 2, height: iconSize * 2)
                    .opacity(0.8)
                
                Text(timerService.formattedTime)
                    .font(.system(size: timerFontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("STOP")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(2)
            }
            
        case .celebration:
            // Checkmark icon - scale based on button size
            let checkmarkSize: CGFloat = size * 0.35
            
            Image(systemName: "checkmark")
                .font(.system(size: checkmarkSize, weight: .bold))
                .foregroundStyle(.white)
            
        case .completedToday:
            // Show checkmark and today's plank time — one plank per day
            VStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Text(formattedLastPlank)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
    
    /// Format today's total plank time
    private var formattedTodayTime: String {
        let totalSeconds = Int(todayPlankTotalTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Format the last (most recent) plank time
    private var formattedLastPlank: String {
        guard let lastPlank = todayPlankTimes.last else {
            return "00:00"
        }
        let totalSeconds = Int(lastPlank)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    // MARK: - Mode Selector
    
    /// Segmented control + wheel duration picker shown below the button in .ready state.
    ///
    /// The container has a fixed height of 168pt (32pt pill + 16pt gap + 120pt wheel)
    /// and is always top-aligned. This means .position() always centres the same
    /// fixed-height box, so the pill never jumps when the wheel appears or disappears.
    private var timerModeSelector: some View {
        VStack(spacing: 0) {
            // Stopwatch / Countdown segmented pill
            Picker("Mode", selection: $timerMode) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .colorMultiply(.white)
            
            // Wheel duration picker — only in Countdown mode, expands downward
            if timerMode == .goal {
                HStack(spacing: 0) {
                    // Minutes wheel: 0–59
                    Picker("Minutes", selection: $selectedMinutes) {
                        ForEach(0..<60) { m in
                            Text("\(m) min")
                                .foregroundStyle(.white)
                                .tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120, height: 120)
                    .clipped()
                    .onChange(of: selectedMinutes) { _, _ in commitWheelGoal() }
                    
                    // Seconds wheel: 0, 5, 10, … 55 in 5-second steps
                    Picker("Seconds", selection: $selectedSeconds) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { s in
                            Text("\(s) sec")
                                .foregroundStyle(.white)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 120, height: 120)
                    .clipped()
                    .onChange(of: selectedSeconds) { _, _ in commitWheelGoal() }
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Spacer(minLength: 0)
        }
        // Fixed height keeps the .position() anchor stable regardless of wheel visibility.
        // 168 = 32pt pill + 16pt gap + 120pt wheel
        .frame(width: 260, height: 168, alignment: .top)
        .animation(.easeInOut(duration: 0.25), value: timerMode)
    }
    
    /// Called when either wheel changes. Updates storedGoalSeconds and schedules a
    /// debounced backend sync. Falls back to 5 seconds minimum (0 min 0 sec → 5 sec).
    private func commitWheelGoal() {
        let total = selectedMinutes * 60 + selectedSeconds
        let clamped = max(5, total)
        // If both wheels are 0, bump seconds to 5 to prevent a zero-duration goal
        if total == 0 { selectedSeconds = 5 }
        storedGoalSeconds = clamped
        scheduleGoalSync(seconds: clamped)
    }
    
    /// Debounced backend sync for the goal preference — cancels any in-flight task
    /// and waits 1 second of inactivity before sending the PATCH request.
    private func scheduleGoalSync(seconds: Int) {
        goalSyncTask?.cancel()
        goalSyncTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
                // Call APIClient directly to avoid setting UserService.isLoading, which
                // would briefly show a loading indicator on any view that observes it.
                let request = UpdateProfileRequest(plankGoalSeconds: seconds)
                let _: APIUser = try await APIClient.shared.patch("/users/me", body: request)
            } catch is CancellationError {
                // Superseded by a newer wheel scroll — no-op
            } catch {
                // Non-critical: the value is already saved locally via @AppStorage.
                // Don't surface an alert — this is a background preference sync.
                #if DEBUG
                print("[PlankTimer] Goal sync failed (non-fatal): \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleButtonTap() {
        switch timerState {
        case .ready:
            startCountdown()
        case .countdown:
            cancelCountdown()
        case .active:
            stopPlank()
        case .celebration:
            // Ignore taps during celebration
            break
        case .completedToday:
            // One plank per day — tapping does nothing in this state.
            // The user can delete via Settings to re-submit.
            break
        }
    }
    
    private func startCountdown() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Scale animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            buttonScale = 0.95
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 1.0
            }
        }
        
        // Start countdown from 5
        withAnimation(.easeInOut(duration: 0.2)) {
            timerState = .countdown(countdownDuration)
        }
        
        // Play countdown beep
        if soundEnabled {
            PlankAudioService.shared.playCountdownBeep()
        }
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                guard case .countdown(let current) = timerState else {
                    timer.invalidate()
                    return
                }
                
                if current > 1 {
                    // Light haptic for each number
                    let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                    lightFeedback.impactOccurred()
                    
                    withAnimation(.easeInOut(duration: 0.15)) {
                        timerState = .countdown(current - 1)
                    }
                    
                    // Play countdown beep
                    if soundEnabled {
                        PlankAudioService.shared.playCountdownBeep()
                    }
                } else {
                    // Countdown finished - start plank!
                    timer.invalidate()
                    countdownTimer = nil
                    startPlank()
                }
            }
        }
    }
    
    private func cancelCountdown() {
        // Light haptic feedback
        let lightFeedback = UIImpactFeedbackGenerator(style: .light)
        lightFeedback.impactOccurred()
        
        // Cancel the countdown
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        withAnimation(.easeInOut(duration: 0.2)) {
            timerState = .ready
        }
    }
    
    private func startPlank() {
        // Heavy haptic feedback for GO
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Play GO sound
        if soundEnabled {
            PlankAudioService.shared.playGoSound()
        }
        
        // In goal mode, tell TimerService the target so it can compute displayTime and
        // fire hasReachedGoal. elapsedTime still counts up for the saved duration.
        // Guard: if the input was cleared (storedGoalSeconds is 0 or goal text is blank),
        // fall back to free mode rather than starting with an undefined goal.
        if timerMode == .goal, storedGoalSeconds > 0 {
            timerService.goalSeconds = storedGoalSeconds
        }
        
        // Order matters: timerState must be .active before timerService.start() is called.
        // onChange(of: timerService.hasReachedGoal) checks timerState == .active; if the
        // state transition happened after start(), a very short goal could fire hasReachedGoal
        // before the guard is in place.
        withAnimation(.easeInOut(duration: 0.4)) {
            timerState = .active
        }
        
        timerService.start()
    }
    
    private func stopPlank() {
        // Success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Play success sound
        if soundEnabled {
            PlankAudioService.shared.playSuccessChime()
        }
        
        timerService.stop()
        
        // Auto-save the plank
        autoSavePlank()
        
        // Start celebration
        withAnimation(.easeInOut(duration: 0.2)) {
            timerState = .celebration
        }
        
        // After celebration duration, transition to completedToday state
        celebrationTimer = Timer.scheduledTimer(withTimeInterval: celebrationDuration, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.3)) {
                    timerState = .completedToday
                }
            }
        }
    }
    
    /// Auto-save plank and update today's totals
    private func autoSavePlank() {
        let today = todayDateString()
        let plankDuration = timerService.elapsedTime
        
        // Check if this is a new day
        if todayPlankDateString != today {
            // Reset for new day
            todayPlankDateString = today
            todayPlankTotalTime = 0
            todayPlankCount = 0
            clearPlankTimes()
        }
        
        // Add this plank to today's totals (optimistic update)
        todayPlankTotalTime += plankDuration
        todayPlankCount += 1
        
        // Track individual plank times
        addPlankTime(plankDuration)
        
        // Save to backend via PlankService - track task so we can cancel on cleanup
        saveTask?.cancel()
        saveTask = Task { @MainActor [plankService, streakService, badgeService, leaderboardService] in
            do {
                let response = try await plankService.createPlank(
                    durationSeconds: plankDuration,
                    inputMethod: .timer
                )
                
                // Check for cancellation before continuing
                try Task.checkCancellation()
                
                // Apply streak data returned inline — no extra network round-trip needed.
                // The response already contains the recalculated current + longest streak.
                if let streak = response.streak {
                    streakService.applyInlineStreakUpdate(
                        current: streak.current,
                        longest: streak.longest
                    )
                }
                
                // If new badges were earned, fetch the full badge list.
                // Called directly — @MainActor task ensures correct actor context.
                if let badges = response.badges, !badges.newlyEarned.isEmpty {
                    try? await badgeService.fetchAvailableBadges()
                }
                
                // Mark leaderboard stale — user's rank may have changed after this plank
                leaderboardService.markStale()
                
                // Schedule a background full streak refresh to pick up calendar
                // activity, freeze tokens, and other fields not in the inline response.
                Task {
                    try? await streakService.fetchStreak()
                }
                
                #if DEBUG
                print("[PlankTimer] Plank saved: \(response.plank.id), badges earned: \(response.badges?.newlyEarned.count ?? 0)")
                #endif
            } catch is CancellationError {
                // Task was cancelled - rollback optimistic update
                rollbackPlank(duration: plankDuration)
                #if DEBUG
                print("[PlankTimer] Save task cancelled, rolled back local state")
                #endif
            } catch {
                // API error - rollback optimistic update and show error.
                // Direct access is safe — Task is @MainActor.
                self.rollbackPlank(duration: plankDuration)
                self.saveError = error.localizedDescription
                #if DEBUG
                print("[PlankTimer] Failed to save plank: \(error), rolled back local state")
                #endif
            }
        }
        
        // Reset timer for next plank
        timerService.reset()
    }
    
    /// Get today's date as a string for comparison
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// Rolls back an optimistic plank update when save fails
    /// - Parameter duration: The duration of the plank to remove
    private func rollbackPlank(duration: Double) {
        // Remove from today's totals
        todayPlankTotalTime = max(0, todayPlankTotalTime - duration)
        todayPlankCount = max(0, todayPlankCount - 1)
        
        // Remove the last plank time from the array
        var times = todayPlankTimes
        if let lastIndex = times.lastIndex(where: { abs($0 - duration) < 0.1 }) {
            times.remove(at: lastIndex)
            if let data = try? JSONEncoder().encode(times),
               let json = String(data: data, encoding: .utf8) {
                todayPlankTimesJSON = json
            }
        }
        
        // If all planks rolled back, go back to ready state
        if todayPlankCount == 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                timerState = .ready
            }
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        celebrationTimer?.invalidate()
        celebrationTimer = nil
        saveTask?.cancel()
        saveTask = nil
        goalSyncTask?.cancel()
        goalSyncTask = nil
        timerService.stop()
    }
}

// MARK: - Animated Flame Icon

struct AnimatedFlameIcon: View {
    let isAnimating: Bool
    
    @State private var flamePhase: CGFloat = 0
    @State private var glowOpacity: CGFloat = 0.5
    
    var body: some View {
        ZStack {
            // Outer glow when animating
            if isAnimating {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange.opacity(glowOpacity))
                    .blur(radius: 8)
                    .scaleEffect(1.3)
            }
            
            // Main flame icon
            Image(systemName: "flame.fill")
                .foregroundStyle(
                    isAnimating
                        ? LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(
                            colors: [.white, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
                .scaleEffect(isAnimating ? 1.0 + (flamePhase * 0.1) : 1.0)
                .offset(y: isAnimating ? -flamePhase * 2 : 0)
        }
        .onAppear {
            if isAnimating {
                startFlameAnimation()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startFlameAnimation()
            }
        }
    }
    
    private func startFlameAnimation() {
        // Flickering scale animation
        withAnimation(
            .easeInOut(duration: 0.4)
            .repeatForever(autoreverses: true)
        ) {
            flamePhase = 1.0
        }
        
        // Glow pulsing animation
        withAnimation(
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
        ) {
            glowOpacity = 0.8
        }
    }
}

#Preview {
    PlankTimerView()
        .withMockServices()
}
