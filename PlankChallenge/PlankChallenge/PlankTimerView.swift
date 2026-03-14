//
//  PlankTimerView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

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
    private var mockData: MockDataService { MockDataService.shared }
    
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    @State private var showingPlankTypeSelector = false
    @State private var showingManualEntry = false
    @State private var buttonScale: CGFloat = 1.0
    
    // Enhanced timer state
    @State private var timerState: PlankTimerState = .ready
    @State private var countdownTimer: Timer?
    @State private var celebrationTimer: Timer?
    
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
                // Full screen gradient background
                LinearGradient.plankGradient
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
                
                // Previous planks list - positioned just below the button (8pt gap)
                if timerState == .completedToday {
                    previousPlanksStack
                        .position(x: geometry.size.width / 2, y: centerY + (maxButtonSize / 2) + 8)
                }
                
                // Top bar overlay - fixed at top
                VStack {
                    // Top bar with plank type selector and manual entry button
                    // Only visible in ready and completedToday states
                    if timerState == .ready || timerState == .completedToday {
                        topBar
                    }
                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: timerState)
        .sheet(isPresented: $showingPlankTypeSelector) {
            PlankTypeSelectorSheet(selectedType: $selectedPlankType)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .toolbar(shouldHideNavigation ? .hidden : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: shouldHideNavigation)
        .onAppear {
            checkForNewDayOrExistingPlanks()
        }
        .onChange(of: todayPlankCount) { oldValue, newValue in
            // If all planks were deleted (from Settings), transition back to ready state
            if newValue == 0 && timerState == .completedToday {
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
        // Top button row: Plank type (left) and Manual entry (right)
        HStack {
            // Plank type selector (left)
            Button {
                showingPlankTypeSelector = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                    Text(selectedPlankType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            
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
            return "Well done!"
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
            return "Tap to cancel"
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
                        Text("Protect your \(mockData.currentUser.currentStreak) day streak")
                    } else {
                        Text("\(mockData.currentUser.currentStreak) day streak")
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
            // Show icon and "Tap to Plank" text
            VStack(spacing: 12) {
                Image(systemName: "figure.core.training")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(.white)
                
                Text("Tap to Plank")
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
            // Show small icon above timer - scale font based on button size
            let timerFontSize: CGFloat = size * 0.16 // ~56pt for 350pt button (20% smaller)
            let iconSize: CGFloat = size * 0.07      // ~24pt for 350pt button
            
            VStack(spacing: 12) {
                Image(systemName: "figure.core.training")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                
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
            // Show checkmark, last plank time, and "Tap to plank again"
            VStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                
                Text(formattedLastPlank)
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("Tap to plank again")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
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
    
    /// Format a plank duration
    private func formatPlankTime(_ duration: Double) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Previous Planks Stack
    
    /// Stack of previous plank times (excluding the last one shown in the button)
    /// Most recent is closest to the button, oldest at bottom
    /// Times fade out and shrink as they get older
    @ViewBuilder
    private var previousPlanksStack: some View {
        let times = todayPlankTimes
        // Get all times except the last one (which is shown in the button)
        let previousTimes = times.dropLast()
        
        if previousTimes.isEmpty {
            // No previous planks - just show empty space
            Color.clear.frame(height: 44)
        } else {
            // Show previous planks in reverse order (most recent first, closest to button)
            VStack(spacing: 8) {
                ForEach(Array(previousTimes.reversed().enumerated()), id: \.offset) { index, duration in
                    let opacity = opacityForIndex(index, total: previousTimes.count)
                    let scale = scaleForIndex(index, total: previousTimes.count)
                    
                    Text(formatPlankTime(duration))
                        .font(.system(size: 16 * scale, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(opacity))
                }
            }
        }
    }
    
    /// Calculate opacity for a plank time based on its position (0 = most recent)
    private func opacityForIndex(_ index: Int, total: Int) -> Double {
        // Most recent (index 0) = 0.7, fading down to 0.3 for oldest
        let minOpacity = 0.25
        let maxOpacity = 0.7
        
        if total <= 1 { return maxOpacity }
        
        let progress = Double(index) / Double(total - 1)
        return maxOpacity - (progress * (maxOpacity - minOpacity))
    }
    
    /// Calculate scale for a plank time based on its position (0 = most recent)
    private func scaleForIndex(_ index: Int, total: Int) -> Double {
        // Most recent (index 0) = 1.0, shrinking down to 0.75 for oldest
        let minScale = 0.75
        let maxScale = 1.0
        
        if total <= 1 { return maxScale }
        
        let progress = Double(index) / Double(total - 1)
        return maxScale - (progress * (maxScale - minScale))
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
            // Start another plank
            startCountdown()
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
        
        // Schedule countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
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
        celebrationTimer = Timer.scheduledTimer(withTimeInterval: celebrationDuration, repeats: false) { [self] _ in
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
        
        // Add this plank to today's totals
        todayPlankTotalTime += plankDuration
        todayPlankCount += 1
        
        // Track individual plank times
        addPlankTime(plankDuration)
        
        // Save to mock data service
        let session = PlankSession(
            durationSeconds: plankDuration,
            plankType: selectedPlankType
        )
        mockData.addPlankSession(session)
        
        // Reset timer for next plank
        timerService.reset()
    }
    
    /// Get today's date as a string for comparison
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        celebrationTimer?.invalidate()
        celebrationTimer = nil
    }
}

// MARK: - Plank Button Style

struct PlankButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
}
