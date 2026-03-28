import SwiftUI
import UserNotifications

/// Onboarding Screen 3 — Notifications Permission
///
/// Asks the user if they'd like a daily reminder to keep their streak alive.
/// Requests system notification permission, then schedules a local daily notification
/// at the user's chosen time. "Maybe later" skips without scheduling.
struct OnboardingNotificationsView: View {
    let onComplete: () -> Void
    
    @State private var reminderTime: Date = {
        // Default to 7:00 PM
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 19
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    @State private var isRequesting = false
    
    var body: some View {
        ZStack {
            LinearGradient.plankGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Illustration
                streakIllustration
                    .padding(.bottom, 40)
                
                // Headline
                Text("Never miss a day")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
                
                // Subtext
                Text("Set a daily reminder and we'll nudge you once — just once — to hold your plank.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)
                
                // Time picker card
                VStack(spacing: 4) {
                    Text("Remind me at")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    DatePicker(
                        "",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .frame(height: 120)
                    .clipped()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 32)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                
                Spacer()
                Spacer()
                
                // Allow button
                Button {
                    Task { await requestAndSchedule() }
                } label: {
                    HStack(spacing: 10) {
                        if isRequesting {
                            ProgressView().tint(Color.appAccent)
                        } else {
                            Image(systemName: "bell.fill")
                            Text("Turn on reminders")
                        }
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 32)
                .disabled(isRequesting)
                
                // Skip link
                Button("Maybe later") {
                    completeOnboarding()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
    }
    
    // MARK: - Illustration
    
    private var streakIllustration: some View {
        ZStack {
            // Glow rings
            Circle()
                .fill(Color.streakColor.opacity(0.08))
                .frame(width: 130, height: 130)
            Circle()
                .fill(Color.streakColor.opacity(0.12))
                .frame(width: 100, height: 100)
            
            // Flame
            Image(systemName: "flame.fill")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.streakColor, Color.warningColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Mock notification badge
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white)
                            .frame(width: 120, height: 40)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.appAccent)
                                .frame(width: 8, height: 8)
                            Text("Time to plank 🔥")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.trailing, -30)
                Spacer()
            }
            .frame(width: 130, height: 130)
        }
    }
    
    // MARK: - Actions
    
    private func requestAndSchedule() async {
        isRequesting = true
        defer { isRequesting = false }
        
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                await scheduleDaily(at: reminderTime, center: center)
            }
        } catch {
            // Permission request failed — still complete onboarding
            #if DEBUG
            print("[Onboarding] Notification permission error: \(error)")
            #endif
        }
        
        completeOnboarding()
    }
    
    @MainActor
    private func scheduleDaily(at time: Date, center: UNUserNotificationCenter) async {
        // Remove any existing plank reminder
        center.removePendingNotificationRequests(withIdentifiers: ["daily-plank-reminder"])
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        
        let content = UNMutableNotificationContent()
        content.title = "Time to plank 🔥"
        content.body = "Your streak is waiting."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-plank-reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            // Persist the chosen time for display in Settings
            UserDefaults.standard.set(time, forKey: AppConfig.UserDefaultsKeys.dailyReminderTime)
            UserDefaults.standard.set(true, forKey: AppConfig.UserDefaultsKeys.notificationsEnabled)
            #if DEBUG
            print("[Onboarding] Daily reminder scheduled at \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
            #endif
        } catch {
            #if DEBUG
            print("[Onboarding] Failed to schedule notification: \(error)")
            #endif
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: AppConfig.UserDefaultsKeys.hasCompletedOnboarding)
        onComplete()
    }
}

#Preview {
    OnboardingNotificationsView(onComplete: {})
}
