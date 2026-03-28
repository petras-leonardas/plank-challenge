//
//  StreakCalendarView.swift
//  PlankChallenge
//
//  A Strava-inspired calendar view showing the current month with
//  blue flame icons on days where planks were completed.
//

import SwiftUI

struct StreakCalendarView: View {
    @Environment(\.streakService) private var streakService
    
    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private func parseDate(_ dateString: String) -> Date? {
        Self.dateFormatter.date(from: dateString)
    }
    
    // MARK: - Computed Properties
    
    private var currentDate: Date {
        Date()
    }
    
    private var currentMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: currentDate))!
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }
    
    private var daysWithPlanks: Set<Int> {
        let currentComponents = calendar.dateComponents([.year, .month], from: currentDate)
        var days = Set<Int>()
        
        for activity in streakService.recentActivity {
            guard activity.planks > 0,
                  let date = parseDate(activity.date) else { continue }
            
            let activityComponents = calendar.dateComponents([.year, .month, .day], from: date)
            
            if activityComponents.year == currentComponents.year &&
               activityComponents.month == currentComponents.month,
               let day = activityComponents.day {
                days.insert(day)
            }
        }
        return days
    }
    
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 30
    }
    
    /// Returns 0 for Monday, 1 for Tuesday, ..., 6 for Sunday
    private var firstWeekdayOfMonth: Int {
        let firstDay = currentMonth
        let weekday = calendar.component(.weekday, from: firstDay)
        // Convert from Sunday=1 to Monday=0 system
        return (weekday + 5) % 7
    }
    
    private var todayDay: Int {
        calendar.component(.day, from: currentDate)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            // Month Header
            monthHeader
            
            // Weekday Headers
            weekdayHeaders
            
            // Calendar Grid
            calendarGrid
        }
        .appCardStyle()
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Text(monthYearString)
                .font(.title3)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
    
    // MARK: - Weekday Headers
    
    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        
        return LazyVGrid(columns: columns, spacing: 8) {
            // Empty cells before the first day
            ForEach(0..<firstWeekdayOfMonth, id: \.self) { _ in
                Color.clear
                    .frame(height: 44)
            }
            
            // Days of the month
            ForEach(1...daysInMonth, id: \.self) { day in
                CalendarDayCell(
                    day: day,
                    isToday: day == todayDay,
                    hasPlanked: daysWithPlanks.contains(day),
                    isFuture: day > todayDay
                )
            }
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let hasPlanked: Bool
    let isFuture: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // Day number
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 28, height: 28)
                }
                
                Text("\(day)")
                    .font(.callout)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(dayTextColor)
            }
            .frame(height: 28)
            
            // Flame icon (only for past/today days with planks)
            if hasPlanked && !isFuture {
                BlueFlameIcon(size: 14)
            } else {
                // Placeholder to maintain consistent height
                Color.clear
                    .frame(width: 14, height: 14)
            }
        }
        .frame(height: 44)
    }
    
    private var dayTextColor: Color {
        if isToday {
            return .white
        } else if isFuture {
            return .secondary.opacity(0.4)
        } else {
            return .primary
        }
    }
}

// MARK: - Preview

#Preview("Streak Calendar") {
    ScrollView {
        VStack(spacing: 20) {
            StreakCalendarView()
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
    .background(Color.softBlueBackground)
    .withMockServices()
}
