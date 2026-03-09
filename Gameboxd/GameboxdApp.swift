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
    private let notificationDelegate = NotificationDelegate()

    let modelContainer: ModelContainer

    init() {
        let memoryCapacity = 50 * 1024 * 1024
        let diskCapacity = 200 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)

        UNUserNotificationCenter.current().delegate = notificationDelegate

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
