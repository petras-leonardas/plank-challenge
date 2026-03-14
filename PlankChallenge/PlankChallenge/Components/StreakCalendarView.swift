//
//  StreakCalendarView.swift
//  PlankChallenge
//
//  A Strava-inspired calendar view showing the current month with
//  blue flame icons on days where planks were completed.
//

import SwiftUI

struct StreakCalendarView: View {
    let plankSessions: [PlankSession]
    
    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    
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
        let components = calendar.dateComponents([.year, .month], from: currentDate)
        var days = Set<Int>()
        
        for session in plankSessions {
            let sessionComponents = calendar.dateComponents([.year, .month, .day], from: session.date)
            if sessionComponents.year == components.year && sessionComponents.month == components.month {
                if let day = sessionComponents.day {
                    days.insert(day)
                }
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
        .padding(16)
        .background(Color.warmWhiteCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
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
            StreakCalendarView(
                plankSessions: generateMockSessions()
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
    .background(Color.softBlueBackground)
}

// Helper function for preview
private func generateMockSessions() -> [PlankSession] {
    let calendar = Calendar.current
    let today = Date()
    var sessions: [PlankSession] = []
    
    // Generate sessions for the past 14 days (current streak)
    for daysAgo in 0..<14 {
        if let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) {
            sessions.append(PlankSession(
                date: date,
                durationSeconds: Double.random(in: 60...180),
                plankType: .elbow,
                inputMethod: .timer
            ))
        }
    }
    
    // Add a few more random sessions earlier in the month
    for daysAgo in [16, 18, 20, 22] {
        if let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) {
            sessions.append(PlankSession(
                date: date,
                durationSeconds: Double.random(in: 60...180),
                plankType: .elbow,
                inputMethod: .timer
            ))
        }
    }
    
    return sessions
}
