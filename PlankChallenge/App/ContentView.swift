import SwiftUI

struct ContentView: View {
    var body: some View {
        // Placeholder - will be replaced with TabView in Phase 3
        VStack(spacing: 20) {
            Image(systemName: "figure.core.training")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Plank Challenge")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Ready to build your foundation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
