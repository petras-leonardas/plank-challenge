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
