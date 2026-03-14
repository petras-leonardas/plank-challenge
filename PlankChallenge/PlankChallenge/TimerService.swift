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
    }
}
