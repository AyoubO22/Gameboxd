import SwiftUI
import SwiftData
import UserNotifications

// Allow notifications to show even when app is in foreground
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct GameboxdApp: App {
    // On instancie le store ici pour qu'il vive pendant toute la durée de vie de l'app
    @StateObject private var store = GameStore()
    @State private var timerManager = TimerManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var notificationDelegate = NotificationDelegate()

    let modelContainer: ModelContainer

    init() {
        let memoryCapacity = 4 * 1024 * 1024
        let diskCapacity = 50 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)

        // Set up SwiftData ModelContainer
        let schema = Schema([
            SDGame.self, SDPlaySession.self, SDGameList.self,
            SDUserProfile.self, SDAchievement.self, SDCustomTag.self,
            SDFriend.self, SDActivityItem.self, SDGameNotification.self,
            SDMonthlyGoal.self, SDLinkedAccount.self, SDImportedGame.self
        ])
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Must be set after all stored properties are initialized
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Run one-time migration from UserDefaults
        MigrationService.migrateIfNeeded(into: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(store)
                    .environment(timerManager)
                    .preferredColorScheme(.dark)
                    .onOpenURL { url in
                        // Handle Google Sign-In redirect URL
                        _ = GoogleSignInService.shared.handleURL(url)
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(store)
                    .environment(timerManager)
                    .preferredColorScheme(.dark)
                    .onOpenURL { url in
                        _ = GoogleSignInService.shared.handleURL(url)
                    }
            }
        }
        .modelContainer(modelContainer)
    }
}
