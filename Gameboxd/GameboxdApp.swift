import SwiftUI
import TipKit
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
    @State private var store = GameboxdApp.makeStore()
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
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    private static func makeStore() -> GameStore {
        #if DEBUG
        if DemoShelf.isOn { return DemoShelf.makeStore() } // launch argument `-debugDemoShelf 1`
        #endif
        return GameStore()
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
            // The app is built under the onboarding from the start, so the shelf (every case and
            // its art) is ready when the player finishes: building it on that tap froze the app.
            ZStack {
                ContentView()
                    .accessibilityHidden(!hasCompletedOnboarding)
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: hasCompletedOnboarding)
            .environment(store)
            .environment(timerManager)
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            // Saves are written in the background; make sure they hit disk
            // before iOS may suspend or kill the app.
            if phase == .background {
                store.flush()
            }
        }
    }
}
