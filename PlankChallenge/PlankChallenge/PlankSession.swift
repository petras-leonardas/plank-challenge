//
//  PlankSession.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import Foundation

struct PlankSession: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var durationSeconds: TimeInterval
    var plankTypeRaw: String
    var inputMethodRaw: String
    var timezoneIdentifier: String
    var createdAt: Date
    var modifiedAt: Date
    
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
    
    enum InputMethod: String, Codable {
        case timer = "timer"
        case manual = "manual"
    }
    
    init(
        date: Date = Date(),
        durationSeconds: TimeInterval,
        plankType: Constants.Plank.PlankType,
        inputMethod: InputMethod = .timer
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.plankTypeRaw = plankType.rawValue
        self.inputMethodRaw = inputMethod.rawValue
        self.timezoneIdentifier = TimeZone.current.identifier
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}
