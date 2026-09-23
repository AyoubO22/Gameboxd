import SwiftUI
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
    // Plain stored reference (not @State): the delegate never changes and must stay
    // alive for the app's lifetime since UNUserNotificationCenter holds it weakly.
    private let notificationDelegate = NotificationDelegate()

    init() {
        let memoryCapacity = 4 * 1024 * 1024
        let diskCapacity = 50 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)

        UNUserNotificationCenter.current().delegate = notificationDelegate
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
    }
}
