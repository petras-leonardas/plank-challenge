import SwiftUI

extension View {
    /// Keeps the screen awake while this view is displayed
    func keepScreenAwake(_ isActive: Bool = true) -> some View {
        self.onAppear {
            UIApplication.shared.isIdleTimerDisabled = isActive
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    /// Applies a card-style background (Apple Health-inspired)
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
