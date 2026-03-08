import SwiftUI
import SwiftData

@main
struct PlankChallengeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlankSession.self,
            UserProfile.self,
            Badge.self,
            AppNotification.self,
            PlankGroup.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
