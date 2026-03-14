//
//  PlankAudioService.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 14/03/2026.
//

import AVFoundation
import AudioToolbox

/// Audio service for plank timer sounds
/// Generates simple beeps and chimes using AVAudioEngine
@MainActor
final class PlankAudioService {
    static let shared = PlankAudioService()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #endif
    }
    
    // MARK: - Sound Generation
    
    /// Play a short high-pitched beep for countdown numbers (5-1)
    func playCountdownBeep() {
        playTone(frequency: 880, duration: 0.1) // A5 note
    }
    
    /// Play a longer lower-pitched beep for "GO"
    func playGoSound() {
        playTone(frequency: 523.25, duration: 0.3) // C5 note, longer
    }
    
    /// Play a success chime when timer stops
    func playSuccessChime() {
        // Play a quick ascending arpeggio for success feeling
        playTone(frequency: 523.25, duration: 0.1) // C5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 659.25, duration: 0.1) // E5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playTone(frequency: 783.99, duration: 0.15) // G5
        }
    }
    
    // MARK: - Tone Generation
    
    private func playTone(frequency: Double, duration: Double) {
        // Use system sound as a simple approach
        // For production, consider using AVAudioEngine for custom tones
        
        let systemSoundID: SystemSoundID
        
        // Map to system sounds based on frequency range
        if frequency > 700 {
            // High beep - use tock sound
            systemSoundID = 1104 // Tock
        } else if frequency > 500 {
            // Medium tone - use tink sound
            systemSoundID = 1103 // Tink
        } else {
            // Lower tone
            systemSoundID = 1057 // General beep
        }
        
        AudioServicesPlaySystemSound(systemSoundID)
    }
    
    // MARK: - Alternative: Generate Custom Tones
    
    /// Generate and play a pure sine wave tone
    /// This is more complex but allows precise control over frequency and duration
    func playCustomTone(frequency: Double, duration: Double, amplitude: Float = 0.5) {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        guard let floatChannelData = buffer.floatChannelData else { return }
        let channelData = floatChannelData[0]
        
        // Generate sine wave
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let value = sin(2.0 * .pi * frequency * time)
            
            // Apply envelope to avoid clicks
            let attackFrames = Int(sampleRate * 0.01)
            let releaseFrames = Int(sampleRate * 0.02)
            
            var envelope: Float = amplitude
            if frame < attackFrames {
                envelope = amplitude * Float(frame) / Float(attackFrames)
            } else if frame > frameCount - releaseFrames {
                let releaseFrame = frame - (frameCount - releaseFrames)
                envelope = amplitude * (1.0 - Float(releaseFrame) / Float(releaseFrames))
            }
            
            channelData[frame] = Float(value) * envelope
        }
        
        // Play the buffer
        playBuffer(buffer)
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        // Create fresh audio engine each time to avoid state issues
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        
        do {
            try engine.start()
            player.scheduleBuffer(buffer) {
                DispatchQueue.main.async {
                    engine.stop()
                }
            }
            player.play()
            
            // Store reference to prevent deallocation
            self.audioEngine = engine
            self.playerNode = player
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
}
