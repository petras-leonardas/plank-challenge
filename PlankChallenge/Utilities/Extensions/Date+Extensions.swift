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
