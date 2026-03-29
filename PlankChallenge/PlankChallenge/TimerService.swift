//
//  TimerService.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class TimerService {
    var elapsedTime: TimeInterval = 0
    var isRunning: Bool = false
    
    /// When set, the timer runs in goal (countdown) mode.
    /// The timer still increments elapsedTime upward — this is the authoritative
    /// elapsed duration that gets saved. The display and auto-stop behaviour change.
    var goalSeconds: Int? = nil
    
    private var timer: Timer?
    private var startTime: Date?
    
    // MARK: - Display
    
    /// Time to display on the button.
    /// In free mode: elapsed time counting up.
    /// In goal mode: remaining time counting down to zero.
    var displayTime: TimeInterval {
        guard let goal = goalSeconds else {
            return elapsedTime
        }
        return max(0, Double(goal) - elapsedTime)
    }
    
    /// The display time formatted as MM:SS (no centiseconds in goal mode, full precision in free mode).
    var formattedTime: String {
        if goalSeconds != nil {
            // Countdown: MM:SS only — centiseconds aren't useful when watching a target
            let total = Int(displayTime.rounded(.up))
            let minutes = total / 60
            let seconds = total % 60
            return String(format: "%02d:%02d", minutes, seconds)
        } else {
            // Stopwatch: MM:SS.cs
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
            return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
        }
    }
    
    /// True once the elapsed time has reached or exceeded the goal.
    /// Only meaningful in goal mode — always false in free mode.
    var hasReachedGoal: Bool {
        guard let goal = goalSeconds else { return false }
        return elapsedTime >= Double(goal)
    }
    
    var isAtMinimumDuration: Bool {
        elapsedTime >= Constants.Plank.minimumDurationSeconds
    }
    
    var isAtMaximumDuration: Bool {
        elapsedTime >= Constants.Plank.maximumDurationSeconds
    }
    
    // MARK: - Control
    
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        startTime = Date()
        elapsedTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: Constants.UI.timerUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startTime = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
                
                if self.isAtMaximumDuration {
                    self.stop()
                }
            }
        }
        
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
        goalSeconds = nil
    }
}
