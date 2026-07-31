import SwiftUI

/// Onboarding — Final Step: Notifications
///
/// The last screen before entering the app. Asks the user to set a daily
/// plank reminder. CTAs clearly signal this is the final step:
/// "Enable reminders and start" or "Skip and start planking".
struct OnboardingNotificationsView: View {
    let onComplete: () -> Void
    
    @State private var flamePulse = false
    @State private var notificationBob = false
    @State private var notificationSlideIn = false
    
    @State private var reminderTime: Date = {
        // Default to 7:00 PM
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 19
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    @State private var isRequesting = false
    
    var body: some View {
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
            
            // Primary CTA — enable reminders and enter the app
            Button {
                Task { await requestAndSchedule() }
            } label: {
                HStack(spacing: 10) {
                    if isRequesting {
                        ProgressView().tint(Color.appAccent)
                    } else {
                        Image(systemName: "bell.fill")
                        Text("Enable reminders and start")
                    }
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .padding(.horizontal, 32)
            .disabled(isRequesting)
            
            // Skip — enter the app without reminders
            Button("Skip and start planking") {
                completeOnboarding()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 16)
            
            // Bottom space for navigation controls (managed by container)
            Spacer()
                .frame(height: 100)
        }
    }
    
    // MARK: - Illustration
    
    private var streakIllustration: some View {
        ZStack {
            // Pulsing glow rings
            Circle()
                .fill(Color.streakColor.opacity(0.08))
                .frame(width: 130, height: 130)
                .scaleEffect(flamePulse ? 1.1 : 0.9)
                .opacity(flamePulse ? 0.4 : 0.8)
            Circle()
                .fill(Color.streakColor.opacity(0.12))
                .frame(width: 100, height: 100)
                .scaleEffect(flamePulse ? 0.95 : 1.05)
            
            // Flame with subtle flicker
            Image(systemName: "flame.fill")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.streakColor, Color.warningColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(flamePulse ? 1.05 : 0.95)
                .rotationEffect(.degrees(flamePulse ? 2 : -2))
            
            // Bobbing mock notification badge
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
                    .offset(
                        x: notificationSlideIn ? 0 : 80,
                        y: notificationBob ? -6 : 6
                    )
                    .opacity(notificationSlideIn ? 1 : 0)
                }
                .padding(.trailing, -30)
                Spacer()
            }
            .frame(width: 130, height: 130)
        }
        .onAppear {
            // Reset for replay on swipe-back
            flamePulse = false
            notificationSlideIn = false
            notificationBob = false
            
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
            // Slide the notification card in from the right
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.4)) {
                notificationSlideIn = true
            }
            // Start bobbing after the slide-in settles
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.5)) {
                notificationBob = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func requestAndSchedule() async {
        isRequesting = true
        defer { isRequesting = false }
        
        let service = NotificationService.shared
        let granted = await service.requestAuthorization()
        
        if granted {
            service.scheduleDailyReminder(at: reminderTime)
        }
        
        completeOnboarding()
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: AppConfig.UserDefaultsKeys.hasCompletedOnboarding)
        onComplete()
    }
}

#Preview {
    OnboardingNotificationsView(onComplete: {})
}
