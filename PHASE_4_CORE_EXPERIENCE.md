# Phase 4: Perfect the Core Plank Experience

**Goal:** Focus entirely on perfecting the plank timer experience, manual entry, and personal tracking. Polish UX with animations, haptics, and handle all edge cases. All data remains local (no backend yet).

**Outcome:** A delightful, polished plank tracking experience that feels like a first-party Apple app.

**Prerequisites:** Phase 3 complete — all screens connected with navigation and local data integration working.

---

## Step 1: Enhance Timer Service with Haptics and Sound

### 1.1 Update TimerService with Haptics
- [ ] Update `TimerService.swift` in **Services/**:

```swift
import Foundation
import Combine
import UIKit
import AVFoundation

/// Service for managing the plank timer with haptics and audio
class TimerService: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var isPastMinimum: Bool = false
    
    private var timer: Timer?
    private var startTime: Date?
    private var backgroundTime: Date?
    
    // Haptic generators
    private let startHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let stopHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let milestoneHaptic = UINotificationFeedbackGenerator()
    private let tickHaptic = UIImpactFeedbackGenerator(style: .light)
    
    // Audio player for optional sounds
    private var audioPlayer: AVAudioPlayer?
    
    // Milestone tracking
    private var lastMilestone: TimeInterval = 0
    private let milestoneIntervals: [TimeInterval] = [10, 30, 60, 120, 180, 300, 600, 1800, 3600]
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    var formattedTimeAccessible: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        if minutes > 0 {
            return "\(minutes) minutes, \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
    
    var isAtMinimumDuration: Bool {
        elapsedTime >= Constants.Plank.minimumDurationSeconds
    }
    
    var isAtMaximumDuration: Bool {
        elapsedTime >= Constants.Plank.maximumDurationSeconds
    }
    
    var progressToMinimum: Double {
        min(elapsedTime / Constants.Plank.minimumDurationSeconds, 1.0)
    }
    
    // MARK: - Initialization
    
    init() {
        // Prepare haptic generators
        startHaptic.prepare()
        stopHaptic.prepare()
        milestoneHaptic.prepare()
        
        // Observe app lifecycle
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        if isRunning {
            backgroundTime = Date()
        }
    }
    
    @objc private func appWillEnterForeground() {
        if isRunning, let backgroundTime = backgroundTime, let startTime = startTime {
            // Recalculate elapsed time including background time
            elapsedTime = Date().timeIntervalSince(startTime)
            
            // Check if max duration exceeded while in background
            if isAtMaximumDuration {
                elapsedTime = Constants.Plank.maximumDurationSeconds
                stop()
            }
        }
        self.backgroundTime = nil
    }
    
    // MARK: - Timer Control
    
    func start() {
        guard !isRunning else { return }
        
        // Haptic feedback
        startHaptic.impactOccurred()
        
        isRunning = true
        isPastMinimum = false
        startTime = Date()
        elapsedTime = 0
        lastMilestone = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: Constants.UI.timerUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // Ensure timer runs even when scrolling
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func updateTimer() {
        guard let startTime = startTime else { return }
        
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Check minimum duration milestone
        if !isPastMinimum && isAtMinimumDuration {
            isPastMinimum = true
            milestoneHaptic.notificationOccurred(.success)
        }
        
        // Check other milestones
        checkMilestones()
        
        // Auto-stop at maximum duration
        if isAtMaximumDuration {
            elapsedTime = Constants.Plank.maximumDurationSeconds
            stop()
            milestoneHaptic.notificationOccurred(.warning)
        }
    }
    
    private func checkMilestones() {
        for milestone in milestoneIntervals {
            if elapsedTime >= milestone && lastMilestone < milestone {
                lastMilestone = milestone
                
                // Subtle haptic for milestones
                if milestone > Constants.Plank.minimumDurationSeconds {
                    tickHaptic.impactOccurred()
                }
            }
        }
    }
    
    func stop() -> TimeInterval {
        let finalTime = elapsedTime
        
        timer?.invalidate()
        timer = nil
        isRunning = false
        
        // Haptic feedback
        if finalTime >= Constants.Plank.minimumDurationSeconds {
            stopHaptic.impactOccurred()
        }
        
        return finalTime
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPastMinimum = false
        elapsedTime = 0
        startTime = nil
        backgroundTime = nil
        lastMilestone = 0
    }
    
    // MARK: - Audio (Optional)
    
    func playStartSound() {
        // Optional: Play a start sound
        // Implementation would load and play an audio file
    }
    
    func playStopSound() {
        // Optional: Play a completion sound
        // Implementation would load and play an audio file
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
```

### 1.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Enhance TimerService with haptics, milestones, and background handling"`

---

## Step 2: Create Animated Timer Display

### 2.1 Create AnimatedTimerView
- [ ] Create `AnimatedTimerView.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct AnimatedTimerView: View {
    let elapsedTime: TimeInterval
    let isAtMinimum: Bool
    let progressToMinimum: Double
    
    @State private var pulseAnimation = false
    
    private var minutes: Int {
        Int(elapsedTime) / 60
    }
    
    private var seconds: Int {
        Int(elapsedTime) % 60
    }
    
    private var milliseconds: Int {
        Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress ring (shows progress to minimum)
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 280, height: 280)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progressToMinimum)
                    .stroke(
                        progressGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progressToMinimum)
                
                // Timer display
                VStack(spacing: 4) {
                    // Main time
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        // Minutes
                        Text(String(format: "%02d", minutes))
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .contentTransition(.numericText())
                        
                        Text(":")
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .opacity(pulseAnimation ? 1 : 0.5)
                        
                        // Seconds
                        Text(String(format: "%02d", seconds))
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(timerColor)
                    
                    // Milliseconds
                    Text(".\(String(format: "%02d", milliseconds))")
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundStyle(timerColor.opacity(0.7))
                }
            }
            
            // Status message
            statusMessage
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer: \(accessibleTime)")
        .accessibilityValue(isAtMinimum ? "Minimum reached" : "Keep going")
    }
    
    private var progressGradient: LinearGradient {
        if isAtMinimum {
            return LinearGradient(
                colors: [.green, .green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var timerColor: Color {
        isAtMinimum ? .green : .primary
    }
    
    private var statusMessage: some View {
        Group {
            if !isAtMinimum {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Keep going! \(Int(Constants.Plank.minimumDurationSeconds - elapsedTime))s to minimum")
                        .font(.subheadline)
                }
                .foregroundStyle(.orange)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Great job! Keep it up!")
                        .font(.subheadline)
                }
                .foregroundStyle(.green)
            }
        }
        .animation(.easeInOut, value: isAtMinimum)
    }
    
    private var accessibleTime: String {
        if minutes > 0 {
            return "\(minutes) minutes, \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        AnimatedTimerView(
            elapsedTime: 5.5,
            isAtMinimum: false,
            progressToMinimum: 0.55
        )
        
        AnimatedTimerView(
            elapsedTime: 65.32,
            isAtMinimum: true,
            progressToMinimum: 1.0
        )
    }
}
```

### 2.2 Create PlankFormImageView
- [ ] Create `PlankFormImageView.swift` in **Views/Plank/**:

```swift
import SwiftUI

struct PlankFormImageView: View {
    let plankType: Constants.Plank.PlankType
    let isAnimating: Bool
    
    @State private var breatheAnimation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.colorForPlankType(plankType).opacity(0.1),
                    Color.colorForPlankType(plankType).opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 16) {
                // Plank illustration
                plankIllustration
                    .scaleEffect(breatheAnimation ? 1.02 : 1.0)
                
                // Type label
                VStack(spacing: 4) {
                    Text(plankType.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(plankType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .onAppear {
            if isAnimating {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    breatheAnimation = true
                }
            }
        }
        .onChange(of: isAnimating) { oldValue, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    breatheAnimation = true
                }
            } else {
                breatheAnimation = false
            }
        }
    }
    
    @ViewBuilder
    private var plankIllustration: some View {
        // Placeholder illustration - would be replaced with actual images
        ZStack {
            // Body representation
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.colorForPlankType(plankType).opacity(0.3))
                .frame(width: 200, height: 60)
                .rotationEffect(.degrees(-5))
            
            // Icon overlay
            Image(systemName: plankTypeIcon)
                .font(.system(size: 60))
                .foregroundStyle(Color.colorForPlankType(plankType))
        }
        .frame(height: 120)
    }
    
    private var plankTypeIcon: String {
        switch plankType {
        case .elbow:
            return "figure.core.training"
        case .straightArm:
            return "figure.strengthtraining.traditional"
        case .parallettes:
            return "figure.highintensity.intervaltraining"
        }
    }
}

#Preview {
    VStack {
        PlankFormImageView(plankType: .elbow, isAnimating: true)
            .frame(height: 200)
        
        PlankFormImageView(plankType: .straightArm, isAnimating: true)
            .frame(height: 200)
        
        PlankFormImageView(plankType: .parallettes, isAnimating: true)
            .frame(height: 200)
    }
}
```

### 2.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add AnimatedTimerView and PlankFormImageView"`

---

## Step 3: Create Enhanced Completion Flow

### 3.1 Create PlankCompletionView (Full Screen)
- [ ] Update `PlankCompletionSheet.swift` in **Views/Plank/**:

```swift
import SwiftUI
import ConfettiSwiftUI

struct PlankCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let duration: TimeInterval
    let plankType: Constants.Plank.PlankType
    let isNewPersonalBest: Bool
    let newStreak: Int
    let previousStreak: Int
    let badgeEarned: Badge.BadgeType?
    let tokenEarned: Bool
    var onDismiss: (() -> Void)?
    
    @State private var confettiCounter = 0
    @State private var showStats = false
    @State private var showBadge = false
    
    init(
        duration: TimeInterval,
        plankType: Constants.Plank.PlankType,
        isNewPersonalBest: Bool = false,
        newStreak: Int = 1,
        previousStreak: Int = 0,
        badgeEarned: Badge.BadgeType? = nil,
        tokenEarned: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self.duration = duration
        self.plankType = plankType
        self.isNewPersonalBest = isNewPersonalBest
        self.newStreak = newStreak
        self.previousStreak = previousStreak
        self.badgeEarned = badgeEarned
        self.tokenEarned = tokenEarned
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Celebration header
                        celebrationHeader
                            .onAppear {
                                triggerCelebration()
                            }
                        
                        // Duration display
                        durationDisplay
                            .opacity(showStats ? 1 : 0)
                            .offset(y: showStats ? 0 : 20)
                        
                        // Stats grid
                        statsGrid
                            .opacity(showStats ? 1 : 0)
                            .offset(y: showStats ? 0 : 20)
                        
                        // Badge earned (if any)
                        if let badge = badgeEarned {
                            badgeEarnedView(badge)
                                .opacity(showBadge ? 1 : 0)
                                .scaleEffect(showBadge ? 1 : 0.5)
                        }
                        
                        // Token earned (if any)
                        if tokenEarned {
                            tokenEarnedView
                                .opacity(showBadge ? 1 : 0)
                                .scaleEffect(showBadge ? 1 : 0.5)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Done button
                        doneButton
                    }
                    .padding()
                }
                
                // Confetti overlay
                ConfettiCannon(
                    counter: $confettiCounter,
                    num: isNewPersonalBest ? 100 : 50,
                    colors: [.orange, .yellow, .green, .blue],
                    rainHeight: 800,
                    radius: 400
                )
            }
            .navigationTitle("Plank Complete!")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Celebration Header
    
    private var celebrationHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showStats ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: showStats)
                
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showStats)
            }
            
            if isNewPersonalBest {
                Label("New Personal Best!", systemImage: "trophy.fill")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce.up, value: showStats)
            }
        }
    }
    
    // MARK: - Duration Display
    
    private var durationDisplay: some View {
        VStack(spacing: 8) {
            Text(duration.formattedDurationWithMilliseconds)
                .font(.system(size: 56, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
            
            HStack(spacing: 8) {
                Image(systemName: "figure.core.training")
                    .foregroundStyle(Color.colorForPlankType(plankType))
                Text(plankType.rawValue)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        HStack(spacing: 24) {
            // Streak
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                }
                
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(newStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if newStreak > previousStreak {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    Text("Day Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1, height: 80)
            
            // Today status
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                }
                
                VStack(spacing: 2) {
                    Text("Done")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Badge Earned
    
    private func badgeEarnedView(_ badge: Badge.BadgeType) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundStyle(.yellow)
                Text("Badge Earned!")
                    .fontWeight(.semibold)
            }
            .font(.headline)
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: badge.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                }
                
                Text(badge.displayName)
                    .font(.headline)
                
                Text(badge.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Token Earned
    
    private var tokenEarnedView: some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake.circle.fill")
                .font(.title)
                .foregroundStyle(.cyan)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Freeze Token Earned!")
                    .font(.headline)
                
                Text("20-day streak reward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.cyan.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Done Button
    
    private var doneButton: some View {
        Button {
            onDismiss?()
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
    
    // MARK: - Animation Triggers
    
    private func triggerCelebration() {
        // Trigger confetti
        confettiCounter += 1
        
        // Staggered animations
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            showStats = true
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.8)) {
            showBadge = true
        }
    }
}

#Preview {
    PlankCompletionSheet(
        duration: 125.45,
        plankType: .elbow,
        isNewPersonalBest: true,
        newStreak: 14,
        previousStreak: 13,
        badgeEarned: .streak14,
        tokenEarned: false
    )
}
```

### 3.2 Add ConfettiSwiftUI Package
- [ ] In Xcode: File → Add Packages
- [ ] Search for: `https://github.com/simibac/ConfettiSwiftUI`
- [ ] Add the package to your project

### 3.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add enhanced completion sheet with confetti and animations"`

---

## Step 4: Create Polished Start Button

### 4.1 Create AnimatedStartButton
- [ ] Create `AnimatedStartButton.swift` in **Views/Components/**:

```swift
import SwiftUI

struct AnimatedStartButton: View {
    let action: () -> Void
    let isDisabled: Bool
    
    @State private var isPressing = false
    @State private var pulseAnimation = false
    
    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .opacity(pulseAnimation ? 0 : 0.5)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDisabled
                                ? [.gray, .gray.opacity(0.8)]
                                : [.appAccent, .appAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(
                        color: isDisabled ? .clear : .appAccent.opacity(0.4),
                        radius: isPressing ? 5 : 20,
                        x: 0,
                        y: isPressing ? 5 : 10
                    )
                    .scaleEffect(isPressing ? 0.95 : 1.0)
                
                // Button content
                VStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 50))
                    
                    Text("START")
                        .font(.headline)
                        .tracking(2)
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
            // Never completes
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressing = pressing
            }
        }
        .onAppear {
            if !isDisabled {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseAnimation = true
                }
            }
        }
        .accessibilityLabel("Start plank")
        .accessibilityHint("Double tap to begin your plank timer")
    }
}

#Preview {
    VStack(spacing: 40) {
        AnimatedStartButton {
            print("Start tapped")
        }
        
        AnimatedStartButton(isDisabled: true) {
            print("Start tapped")
        }
    }
}
```

### 4.2 Create AnimatedStopButton
- [ ] Create `AnimatedStopButton.swift` in **Views/Components/**:

```swift
import SwiftUI

struct AnimatedStopButton: View {
    let action: () -> Void
    let canStop: Bool
    
    @State private var isPressing = false
    @State private var holdProgress: CGFloat = 0
    
    private let holdDuration: CGFloat = 0.5 // Hold for half second to stop
    
    var body: some View {
        ZStack {
            // Progress ring (for hold-to-stop)
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Color.white.opacity(0.5), lineWidth: 4)
                .frame(width: 108, height: 108)
                .rotationEffect(.degrees(-90))
            
            // Main button
            Circle()
                .fill(
                    LinearGradient(
                        colors: canStop
                            ? [.red, .red.opacity(0.8)]
                            : [.orange, .orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(
                    color: canStop ? .red.opacity(0.4) : .orange.opacity(0.4),
                    radius: isPressing ? 5 : 10,
                    x: 0,
                    y: isPressing ? 2 : 5
                )
                .scaleEffect(isPressing ? 0.95 : 1.0)
            
            // Button content
            VStack(spacing: 4) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 30))
                
                Text("STOP")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
        }
        .onTapGesture {
            if canStop {
                action()
            }
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
            // Never completes
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressing = pressing
            }
        }
        .accessibilityLabel(canStop ? "Stop plank" : "Stop plank (minimum not reached)")
        .accessibilityHint(canStop ? "Double tap to stop and save your plank" : "Keep planking to reach the minimum duration")
    }
}

#Preview {
    VStack(spacing: 40) {
        AnimatedStopButton(action: { print("Stop") }, canStop: true)
        AnimatedStopButton(action: { print("Stop") }, canStop: false)
    }
}
```

### 4.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add AnimatedStartButton and AnimatedStopButton"`

---

## Step 5: Update Plank Timer View with Polish

### 5.1 Create Fully Polished PlankTimerView
- [ ] Update `PlankTimerView.swift` in **Views/Plank/**:

```swift
import SwiftUI
import SwiftData

struct PlankTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var timerService = TimerService()
    @State private var viewModel: PlankViewModel?
    
    @State private var selectedPlankType: Constants.Plank.PlankType = .elbow
    @State private var showingPlankTypeSelector = false
    @State private var showingCompletionSheet = false
    @State private var showingAlreadyPlankedAlert = false
    @State private var showingManualEntry = false
    @State private var showingMinimumNotReachedAlert = false
    
    // Completion data
    @State private var completedDuration: TimeInterval = 0
    @State private var isNewPersonalBest = false
    @State private var newStreak = 0
    @State private var previousStreak = 0
    @State private var badgeEarned: Badge.BadgeType?
    @State private var tokenEarned = false
    
    var body: some View {
        ZStack {
            // Animated background
            backgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: timerService.isRunning)
            
            VStack(spacing: 0) {
                if timerService.isRunning {
                    activePlankView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    prePlankView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: timerService.isRunning)
        }
        .navigationTitle("Plank")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeViewModel()
        }
        .sheet(isPresented: $showingPlankTypeSelector) {
            PlankTypeSelectorSheet(selectedType: $selectedPlankType)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                if let vm = viewModel {
                    ManualEntryView(viewModel: vm) {
                        vm.loadTodaysPlank()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCompletionSheet) {
            PlankCompletionSheet(
                duration: completedDuration,
                plankType: selectedPlankType,
                isNewPersonalBest: isNewPersonalBest,
                newStreak: newStreak,
                previousStreak: previousStreak,
                badgeEarned: badgeEarned,
                tokenEarned: tokenEarned,
                onDismiss: {
                    viewModel?.loadTodaysPlank()
                }
            )
            .interactiveDismissDisabled()
        }
        .alert("Already Planked Today", isPresented: $showingAlreadyPlankedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've already completed your plank for today. Come back tomorrow!")
        }
        .alert("Keep Going!", isPresented: $showingMinimumNotReachedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need to plank for at least 10 seconds. Keep going!")
        }
        .keepScreenAwake(timerService.isRunning)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        Group {
            if timerService.isRunning {
                LinearGradient(
                    colors: [
                        Color.colorForPlankType(selectedPlankType).opacity(0.1),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(.systemGroupedBackground)
            }
        }
    }
    
    // MARK: - Pre-Plank View
    
    private var prePlankView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            if viewModel?.hasPlankToday == true {
                alreadyPlankedView
            } else {
                readyToPlankView
            }
            
            Spacer()
            
            if viewModel?.hasPlankToday != true {
                manualEntryButton
                    .padding(.bottom, 16)
            }
        }
        .padding()
    }
    
    private var readyToPlankView: some View {
        VStack(spacing: 32) {
            // Plank type selector
            plankTypeButton
            
            // Start button
            AnimatedStartButton {
                startPlank()
            }
            
            // Instructions
            VStack(spacing: 8) {
                Text("Tap to start your daily plank")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("Min 10s • Max 1hr")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var alreadyPlankedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse, options: .repeating)
            }
            
            VStack(spacing: 8) {
                Text("Today's Plank Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let plank = viewModel?.todaysPlank {
                    Text(plank.durationSeconds.formattedDuration)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.green)
                    
                    HStack {
                        Image(systemName: "figure.core.training")
                        Text(plank.plankType.rawValue)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            
            // Streak indicator
            if let streak = viewModel?.getCurrentStreak(), streak > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak) day streak!")
                        .fontWeight(.medium)
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            
            Text("Come back tomorrow to continue your streak")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var plankTypeButton: some View {
        Button {
            showingPlankTypeSelector = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.colorForPlankType(selectedPlankType).opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "figure.core.training")
                        .font(.title3)
                        .foregroundStyle(Color.colorForPlankType(selectedPlankType))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPlankType.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(selectedPlankType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    private var manualEntryButton: some View {
        Button {
            showingManualEntry = true
        } label: {
            HStack {
                Image(systemName: "hand.tap")
                Text("Add time manually")
            }
            .font(.subheadline)
            .foregroundStyle(.appAccent)
        }
    }
    
    // MARK: - Active Plank View
    
    private var activePlankView: some View {
        VStack(spacing: 0) {
            // Plank form image
            PlankFormImageView(plankType: selectedPlankType, isAnimating: true)
                .frame(height: 220)
            
            Spacer()
            
            // Timer display
            AnimatedTimerView(
                elapsedTime: timerService.elapsedTime,
                isAtMinimum: timerService.isAtMinimumDuration,
                progressToMinimum: timerService.progressToMinimum
            )
            
            Spacer()
            
            // Stop button
            AnimatedStopButton(action: stopPlank, canStop: timerService.isAtMinimumDuration)
                .padding(.bottom, 50)
            
            // Minimum warning
            if !timerService.isAtMinimumDuration {
                Text("Hold for at least 10 seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Actions
    
    private func initializeViewModel() {
        viewModel = PlankViewModel(modelContext: modelContext)
        if let vm = viewModel {
            selectedPlankType = vm.selectedPlankType
        }
    }
    
    private func startPlank() {
        guard viewModel?.hasPlankToday != true else {
            showingAlreadyPlankedAlert = true
            return
        }
        
        timerService.start()
    }
    
    private func stopPlank() {
        completedDuration = timerService.stop()
        
        guard completedDuration >= Constants.Plank.minimumDurationSeconds else {
            showingMinimumNotReachedAlert = true
            timerService.reset()
            return
        }
        
        // Get current state before saving
        previousStreak = viewModel?.getCurrentStreak() ?? 0
        let previousLongestPlank = viewModel?.getLongestPlank() ?? 0
        
        // Save the plank
        guard let vm = viewModel else { return }
        vm.selectedPlankType = selectedPlankType
        
        let result = vm.savePlankWithDetails(duration: completedDuration, inputMethod: .timer)
        
        // Set completion data
        newStreak = result.newStreak
        isNewPersonalBest = completedDuration > previousLongestPlank
        badgeEarned = result.badgeEarned
        tokenEarned = result.tokenEarned
        
        timerService.reset()
        showingCompletionSheet = true
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlankTimerView()
    }
    .modelContainer(for: [PlankSession.self, UserProfile.self, Badge.self, AppNotification.self], inMemory: true)
}
```

### 5.2 Update PlankViewModel with Additional Methods
- [ ] Add these methods to `PlankViewModel.swift`:

```swift
// Add to PlankViewModel class:

struct SaveResult {
    let success: Bool
    let newStreak: Int
    let badgeEarned: Badge.BadgeType?
    let tokenEarned: Bool
}

func getCurrentStreak() -> Int {
    let descriptor = FetchDescriptor<UserProfile>()
    return (try? modelContext.fetch(descriptor).first?.currentStreak) ?? 0
}

func getLongestPlank() -> TimeInterval {
    let descriptor = FetchDescriptor<PlankSession>()
    let sessions = try? modelContext.fetch(descriptor)
    return sessions?.map { $0.durationSeconds }.max() ?? 0
}

func savePlankWithDetails(duration: TimeInterval, inputMethod: PlankSession.InputMethod) -> SaveResult {
    guard duration >= Constants.Plank.minimumDurationSeconds else {
        return SaveResult(success: false, newStreak: 0, badgeEarned: nil, tokenEarned: false)
    }
    
    guard duration <= Constants.Plank.maximumDurationSeconds else {
        return SaveResult(success: false, newStreak: 0, badgeEarned: nil, tokenEarned: false)
    }
    
    guard !hasPlankToday else {
        return SaveResult(success: false, newStreak: 0, badgeEarned: nil, tokenEarned: false)
    }
    
    // Get profile
    let profileDescriptor = FetchDescriptor<UserProfile>()
    guard let profile = try? modelContext.fetch(profileDescriptor).first else {
        return SaveResult(success: false, newStreak: 0, badgeEarned: nil, tokenEarned: false)
    }
    
    let previousTokens = profile.freezeTokens
    
    // Create session
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
        let earnedBadge = checkAndAwardBadges()
        
        // Check if token was earned
        let tokenEarned = profile.freezeTokens > previousTokens
        
        let newStreak = profile.currentStreak
        
        return SaveResult(
            success: true,
            newStreak: newStreak,
            badgeEarned: earnedBadge,
            tokenEarned: tokenEarned
        )
    } catch {
        print("Error saving plank: \(error)")
        return SaveResult(success: false, newStreak: 0, badgeEarned: nil, tokenEarned: false)
    }
}

private func checkAndAwardBadges() -> Badge.BadgeType? {
    let profileDescriptor = FetchDescriptor<UserProfile>()
    guard let profile = try? modelContext.fetch(profileDescriptor).first else { return nil }
    
    let currentStreak = profile.currentStreak
    var newBadge: Badge.BadgeType?
    
    // Check each milestone in order (highest first for new badge)
    for milestone in Constants.Streak.badgeMilestones.sorted(by: >) {
        if currentStreak >= milestone {
            if let badgeType = Badge.BadgeType.allCases.first(where: { $0.streakDays == milestone }) {
                if awardBadgeIfNotEarned(badgeType) {
                    newBadge = badgeType
                    break // Only report the highest new badge
                }
            }
        }
    }
    
    return newBadge
}

private func awardBadgeIfNotEarned(_ badgeType: Badge.BadgeType) -> Bool {
    let predicate = #Predicate<Badge> { badge in
        badge.badgeTypeRaw == badgeType.rawValue
    }
    let descriptor = FetchDescriptor<Badge>(predicate: predicate)
    
    if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
        return false // Already earned
    }
    
    let badge = Badge(badgeType: badgeType)
    modelContext.insert(badge)
    
    createNotification(
        type: .badgeEarned,
        title: "New Badge Earned!",
        message: "Congratulations! You've earned the '\(badgeType.displayName)' badge!"
    )
    
    try? modelContext.save()
    return true
}
```

### 5.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Polish PlankTimerView with animations and enhanced UX"`

---

## Step 6: Add Accessibility Support

### 6.1 Create AccessibilityModifiers
- [ ] Create `AccessibilityModifiers.swift` in **Utilities/**:

```swift
import SwiftUI

// MARK: - Accessibility Extensions

extension View {
    /// Adds accessibility for timer displays
    func timerAccessibility(time: TimeInterval, isRunning: Bool) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibleTimeLabel(time))
            .accessibilityValue(isRunning ? "Running" : "Stopped")
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Adds accessibility for stat cards
    func statCardAccessibility(title: String, value: String, subtitle: String? = nil) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title): \(value)" + (subtitle != nil ? ", \(subtitle!)" : ""))
    }
    
    private func accessibleTimeLabel(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") and \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
}

// MARK: - Accessible Components

struct AccessibleStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let color: Color
    
    var body: some View {
        StatCard(
            title: title,
            value: value,
            subtitle: subtitle,
            icon: icon,
            color: color
        )
        .statCardAccessibility(title: title, value: value, subtitle: subtitle)
    }
}

// MARK: - Dynamic Type Support

struct ScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    
    @Environment(\.sizeCategory) var sizeCategory
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight, design: design))
    }
    
    private var scaledSize: CGFloat {
        UIFontMetrics.default.scaledValue(for: size)
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
```

### 6.2 Update Key Components with Accessibility
- [ ] Add accessibility to `AnimatedTimerView.swift`:

```swift
// Add to AnimatedTimerView body:
.accessibilityElement(children: .ignore)
.accessibilityLabel("Timer")
.accessibilityValue(accessibleTime + (isAtMinimum ? ", minimum reached" : ", keep going"))
.accessibilityAddTraits(.updatesFrequently)
```

### 6.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add accessibility support and Dynamic Type"`

---

## Step 7: Handle Edge Cases

### 7.1 Create EdgeCaseHandler
- [ ] Create `EdgeCaseHandler.swift` in **Services/**:

```swift
import Foundation
import SwiftUI

/// Handles various edge cases in the plank timer
class EdgeCaseHandler: ObservableObject {
    static let shared = EdgeCaseHandler()
    
    @Published var showingAppWillTerminateWarning = false
    @Published var showingLowBatteryWarning = false
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func batteryLevelDidChange() {
        if UIDevice.current.batteryLevel < 0.1 && UIDevice.current.batteryState != .charging {
            showingLowBatteryWarning = true
        }
    }
    
    /// Validates a plank duration
    static func validateDuration(_ duration: TimeInterval) -> DurationValidation {
        if duration < Constants.Plank.minimumDurationSeconds {
            return .tooShort(minimum: Constants.Plank.minimumDurationSeconds)
        }
        
        if duration > Constants.Plank.maximumDurationSeconds {
            return .tooLong(maximum: Constants.Plank.maximumDurationSeconds)
        }
        
        return .valid
    }
    
    enum DurationValidation {
        case valid
        case tooShort(minimum: TimeInterval)
        case tooLong(maximum: TimeInterval)
        
        var errorMessage: String? {
            switch self {
            case .valid:
                return nil
            case .tooShort(let minimum):
                return "Plank must be at least \(Int(minimum)) seconds"
            case .tooLong(let maximum):
                return "Plank cannot exceed \(Int(maximum / 60)) minutes"
            }
        }
    }
    
    /// Checks if user can plank today
    static func canPlankToday(existingPlank: PlankSession?) -> CanPlankResult {
        guard existingPlank == nil else {
            return .alreadyPlanked
        }
        
        return .canPlank
    }
    
    enum CanPlankResult {
        case canPlank
        case alreadyPlanked
        
        var message: String? {
            switch self {
            case .canPlank:
                return nil
            case .alreadyPlanked:
                return "You've already completed your plank for today. Come back tomorrow!"
            }
        }
    }
    
    /// Checks timezone changes
    static func checkTimezoneConsistency(storedTimezone: String) -> Bool {
        return storedTimezone == TimeZone.current.identifier
    }
}
```

### 7.2 Create RecoveryHandler for Interrupted Planks
- [ ] Create `PlankRecoveryHandler.swift` in **Services/**:

```swift
import Foundation
import SwiftData

/// Handles recovery from interrupted plank sessions
class PlankRecoveryHandler {
    
    struct RecoveryData: Codable {
        let startTime: Date
        let plankType: String
        let wasActive: Bool
    }
    
    private static let recoveryKey = "PlankRecoveryData"
    
    /// Saves current plank state for potential recovery
    static func saveState(startTime: Date, plankType: Constants.Plank.PlankType) {
        let data = RecoveryData(
            startTime: startTime,
            plankType: plankType.rawValue,
            wasActive: true
        )
        
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: recoveryKey)
        }
    }
    
    /// Clears saved recovery state
    static func clearState() {
        UserDefaults.standard.removeObject(forKey: recoveryKey)
    }
    
    /// Checks for recoverable plank session
    static func checkForRecovery() -> RecoveryData? {
        guard let data = UserDefaults.standard.data(forKey: recoveryKey),
              let recovery = try? JSONDecoder().decode(RecoveryData.self, from: data) else {
            return nil
        }
        
        // Only recover if within reasonable time (e.g., last hour)
        let timeSinceStart = Date().timeIntervalSince(recovery.startTime)
        guard timeSinceStart < 3600 else { // 1 hour max
            clearState()
            return nil
        }
        
        return recovery
    }
    
    /// Calculates recoverable duration
    static func recoverableDuration(from recovery: RecoveryData) -> TimeInterval {
        let elapsed = Date().timeIntervalSince(recovery.startTime)
        
        // Cap at maximum duration
        return min(elapsed, Constants.Plank.maximumDurationSeconds)
    }
}
```

### 7.3 Add Recovery UI to PlankTimerView
- [ ] Add recovery check to `PlankTimerView.swift`:

```swift
// Add to PlankTimerView:

@State private var showingRecoveryAlert = false
@State private var recoveryData: PlankRecoveryHandler.RecoveryData?

// Add to body, after .onAppear:
.onAppear {
    initializeViewModel()
    checkForRecovery()
}
.alert("Recover Plank?", isPresented: $showingRecoveryAlert) {
    Button("Recover") {
        recoverPlank()
    }
    Button("Discard", role: .destructive) {
        PlankRecoveryHandler.clearState()
    }
    Button("Cancel", role: .cancel) {}
} message: {
    if let recovery = recoveryData {
        let duration = PlankRecoveryHandler.recoverableDuration(from: recovery)
        Text("It looks like your previous plank was interrupted. Would you like to save \(duration.formattedDuration)?")
    }
}

// Add methods:
private func checkForRecovery() {
    if let recovery = PlankRecoveryHandler.checkForRecovery(),
       viewModel?.hasPlankToday != true {
        recoveryData = recovery
        showingRecoveryAlert = true
    }
}

private func recoverPlank() {
    guard let recovery = recoveryData else { return }
    
    let duration = PlankRecoveryHandler.recoverableDuration(from: recovery)
    
    if let plankType = Constants.Plank.PlankType(rawValue: recovery.plankType) {
        selectedPlankType = plankType
        viewModel?.selectedPlankType = plankType
    }
    
    // Save the recovered plank
    if let result = viewModel?.savePlankWithDetails(duration: duration, inputMethod: .timer) {
        if result.success {
            completedDuration = duration
            newStreak = result.newStreak
            badgeEarned = result.badgeEarned
            tokenEarned = result.tokenEarned
            showingCompletionSheet = true
        }
    }
    
    PlankRecoveryHandler.clearState()
}
```

### 7.4 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add edge case handling and plank recovery"`

---

## Step 8: Polish Progress Charts

### 8.1 Create Enhanced Chart Components
- [ ] Create `PlankProgressChart.swift` in **Views/Progress/**:

```swift
import SwiftUI
import Charts

struct PlankProgressChart: View {
    let data: [(date: Date, duration: TimeInterval)]
    let showAverage: Bool
    
    init(data: [(date: Date, duration: TimeInterval)], showAverage: Bool = true) {
        self.data = data
        self.showAverage = showAverage
    }
    
    private var averageDuration: TimeInterval {
        let validDurations = data.map { $0.duration }.filter { $0 > 0 }
        guard !validDurations.isEmpty else { return 0 }
        return validDurations.reduce(0, +) / Double(validDurations.count)
    }
    
    private var maxDuration: TimeInterval {
        data.map { $0.duration }.max() ?? 60
    }
    
    var body: some View {
        Chart {
            ForEach(data, id: \.date) { item in
                if item.duration > 0 {
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Duration", item.duration)
                    )
                    .foregroundStyle(barGradient)
                    .cornerRadius(4)
                }
            }
            
            if showAverage && averageDuration > 0 {
                RuleMark(y: .value("Average", averageDuration))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Avg: \(averageDuration.formattedDuration)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: calculateStrideCount())) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.day())
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks { value in
                if let seconds = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatYAxisLabel(seconds))
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: 0...(maxDuration * 1.2))
    }
    
    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [.appAccent, .appAccent.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func calculateStrideCount() -> Int {
        switch data.count {
        case 0...7: return 1
        case 8...14: return 2
        case 15...30: return 5
        default: return 7
        }
    }
    
    private func formatYAxisLabel(_ seconds: Double) -> String {
        if seconds >= 60 {
            return "\(Int(seconds / 60))m"
        }
        return "\(Int(seconds))s"
    }
}

// MARK: - Trend Indicator

struct TrendIndicatorView: View {
    let trend: ProgressViewModel.Trend
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
            
            Text(trendText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(trendColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(trendColor.opacity(0.15))
        .clipShape(Capsule())
    }
    
    private var iconName: String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .noData: return "questionmark"
        }
    }
    
    private var trendText: String {
        switch trend {
        case .improving: return "Improving"
        case .declining: return "Needs attention"
        case .stable: return "Stable"
        case .noData: return "Not enough data"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .declining: return .orange
        case .stable: return .blue
        case .noData: return .gray
        }
    }
}

#Preview {
    let sampleData: [(Date, TimeInterval)] = (0..<14).map { dayOffset in
        let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
        let duration = Double.random(in: 45...180)
        return (date, duration)
    }
    
    return VStack {
        PlankProgressChart(data: sampleData)
            .frame(height: 200)
            .padding()
        
        TrendIndicatorView(trend: .improving)
    }
}
```

### 8.2 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add enhanced progress charts with trend indicators"`

---

## Step 9: Final Design Polish

### 9.1 Create Theme Constants
- [ ] Create `Theme.swift` in **Utilities/**:

```swift
import SwiftUI

/// App-wide theme constants
enum Theme {
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    // MARK: - Shadows
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static let small = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Animation Durations
    
    enum Animation {
        static let fast: Double = 0.15
        static let normal: Double = 0.3
        static let slow: Double = 0.5
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        
        // Special
        static let timerLarge = Font.system(size: 64, weight: .bold, design: .monospaced)
        static let timerMedium = Font.system(size: 48, weight: .bold, design: .monospaced)
        static let statValue = Font.system(size: 34, weight: .bold, design: .rounded)
    }
}

// MARK: - View Extensions

extension View {
    func cardShadow(_ shadow: Theme.Shadow = .small) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func standardCard() -> some View {
        self
            .padding(Theme.Spacing.md)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }
}
```

### 9.2 Update App-Wide Styling
- [ ] Review and update all views to use Theme constants consistently

### 9.3 Commit
- [ ] `git add .`
- [ ] `git commit -m "Add Theme constants and standardize styling"`

---

## Step 10: Final Testing & Optimization

### 10.1 Performance Testing
- [ ] Test timer accuracy over long durations
- [ ] Test app performance with many plank records
- [ ] Test memory usage during plank session
- [ ] Test on older supported devices

### 10.2 Visual Testing
- [ ] Test all screens in Light Mode
- [ ] Test all screens in Dark Mode
- [ ] Test with various Dynamic Type sizes
- [ ] Test with Bold Text enabled
- [ ] Test with Reduce Motion enabled

### 10.3 Edge Case Testing
- [ ] Test app backgrounding during plank
- [ ] Test incoming call during plank
- [ ] Test low battery during plank
- [ ] Test timezone change
- [ ] Test exactly 10-second plank
- [ ] Test exactly 1-hour plank
- [ ] Test manual entry edge cases

### 10.4 Accessibility Testing
- [ ] Test with VoiceOver
- [ ] Verify all buttons are accessible
- [ ] Verify timer announces correctly
- [ ] Test with Switch Control

### 10.5 Final Commit
- [ ] `git add .`
- [ ] `git commit -m "Phase 4 complete: Polished core plank experience"`
- [ ] Consider creating a tag: `git tag v0.4-polished`

---

## Phase 4 Completion Checklist

- [ ] TimerService enhanced with haptics and background handling
- [ ] AnimatedTimerView with progress ring and milliseconds
- [ ] PlankFormImageView with breathing animation
- [ ] PlankCompletionSheet with confetti and celebrations
- [ ] AnimatedStartButton with pulse animation
- [ ] AnimatedStopButton with visual feedback
- [ ] Full accessibility support
- [ ] Edge case handling (backgrounding, recovery, validation)
- [ ] Enhanced progress charts with trends
- [ ] Theme constants for consistent styling
- [ ] All visual testing passed
- [ ] All accessibility testing passed
- [ ] All edge case testing passed
- [ ] All changes committed to Git

---

## Next Steps

With Phase 4 complete, you have a polished, delightful plank tracking experience. Move to **Phase 5: Backend Integration & Real Functionality** to:
1. Set up backend infrastructure
2. Implement authentication
3. Add data sync
4. Replace all mock data with real functionality
5. Prepare for App Store

Proceed to `PHASE_5_BACKEND_INTEGRATION.md` when ready.
