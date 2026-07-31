//
//  PlankHistoryListView.swift
//  PlankChallenge
//
//  Created by Leo Bacevicius on 08/03/2026.
//

import SwiftUI

struct PlankHistoryListView: View {
    @Environment(\.plankService) private var plankService
    
    @State private var historyLoadError: String?
    @State private var showingHistoryError = false
    
    /// Group planks by month
    private var planksGroupedByMonth: [(key: String, sessions: [APIPlankSession])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let grouped = Dictionary(grouping: plankService.planks) { session -> String in
            if let date = isoFormatter.date(from: session.performedAt) {
                return formatter.string(from: date)
            }
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: session.performedAt) {
                return formatter.string(from: date)
            }
            return "Unknown"
        }
        
        return grouped.map { (key: $0.key, sessions: $0.value.sorted { s1, s2 in
            guard let d1 = parseDate(s1.performedAt), let d2 = parseDate(s2.performedAt) else { return false }
            return d1 > d2
        })}
        .sorted { g1, g2 in
            guard let d1 = g1.sessions.first.flatMap({ parseDate($0.performedAt) }),
                  let d2 = g2.sessions.first.flatMap({ parseDate($0.performedAt) }) else { return false }
            return d1 > d2
        }
    }
    
    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    var body: some View {
        Group {
            if !plankService.hasLoaded {
                PlankHistorySkeleton()
                    .transition(.opacity)
            } else {
                // Content with fade-in from skeleton
                List {
                    if plankService.hasLoaded && plankService.planks.isEmpty {
                        Section {
                            Text("No planks yet — your first one is waiting")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    } else {
                        ForEach(planksGroupedByMonth, id: \.key) { month, sessions in
                            Section(month) {
                                ForEach(sessions) { session in
                                    APIPlankHistoryRowFull(session: session)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Plank History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !plankService.hasLoaded {
                do {
                    try await plankService.fetchPlanks(refresh: false)
                } catch is CancellationError {
                    // View disappeared before load completed — not a user error
                } catch {
                    historyLoadError = error.localizedDescription
                    showingHistoryError = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: plankService.hasLoaded)
        .alert("Couldn't load your history", isPresented: $showingHistoryError) {
            Button("Retry") {
                historyLoadError = nil
                Task {
                    do {
                        try await plankService.fetchPlanks(refresh: true)
                    } catch is CancellationError {
                        // Cancelled — not a user error
                    } catch {
                        historyLoadError = error.localizedDescription
                        showingHistoryError = true
                    }
                }
            }
            Button("OK", role: .cancel) { historyLoadError = nil }
        } message: {
            Text(historyLoadError ?? "Something went wrong. Pull down to try again.")
        }
    }
}

// MARK: - API Plank History Row

struct APIPlankHistoryRowFull: View {
    let session: APIPlankSession
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private var performedDate: Date {
        if let date = Self.iso8601Formatter.date(from: session.performedAt) { return date }
        return Self.iso8601FormatterBasic.date(from: session.performedAt) ?? Date()
    }
    
    private var plankType: APIPlankType {
        APIPlankType(rawValue: session.plankType) ?? .elbow
    }
    
    private var isTimerInput: Bool {
        session.inputMethod == "timer"
    }
    
    var body: some View {
        HStack {
            // Date
            VStack(alignment: .leading, spacing: 2) {
                Text(performedDate.relativeFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(plankType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Duration
            Text(session.durationSeconds.formattedDuration)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appAccent)
            
            // Input method indicator
            Image(systemName: isTimerInput ? "timer" : "hand.tap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}



#Preview {
    NavigationStack {
        PlankHistoryListView()
            .withMockServices()
    }
}
