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
