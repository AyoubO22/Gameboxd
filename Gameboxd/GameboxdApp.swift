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
    @State private var store = GameStore()
    @State private var timerManager = TimerManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    // Plain stored reference (not @State): the delegate never changes and must stay
    // alive for the app's lifetime since UNUserNotificationCenter holds it weakly.
    private let notificationDelegate = NotificationDelegate()

    init() {
        let memoryCapacity = 4 * 1024 * 1024
        let diskCapacity = 50 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)

        UNUserNotificationCenter.current().delegate = notificationDelegate
        Self.styleNavigationBars()
    }

    /// Navigation titles are UIKit: heavy system face, scaled for Dynamic Type.
    private static func styleNavigationBars() {
        func display(_ size: CGFloat, weight: UIFont.Weight, style: UIFont.TextStyle) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight))
        }
        let text = UIColor(Color.textPrimary)
        let large: [NSAttributedString.Key: Any] = [.font: display(34, weight: .bold, style: .largeTitle), .foregroundColor: text]
        let inline: [NSAttributedString.Key: Any] = [.font: display(17, weight: .semibold, style: .headline), .foregroundColor: text]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.largeTitleTextAttributes = large
        standard.titleTextAttributes = inline
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.largeTitleTextAttributes = large
        edge.titleTextAttributes = inline

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = standard
        bar.compactAppearance = standard
        bar.scrollEdgeAppearance = edge
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(store)
                    .environment(timerManager)
                    .preferredColorScheme(.dark)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environment(store)
                    .environment(timerManager)
                    .preferredColorScheme(.dark)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Saves are written in the background; make sure they hit disk
            // before iOS may suspend or kill the app.
            if phase == .background {
                FileStore.shared.flush()
            }
        }
    }
}
