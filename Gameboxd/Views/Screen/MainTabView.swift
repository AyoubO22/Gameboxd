//
//  MainTabView.swift
//  Gameboxd
//
//  Main navigation: five tabs, Profile at the far right, on a Liquid Glass tab bar
//

import SwiftUI

struct MainTabView: View {
    @Environment(TimerManager.self) private var timerManager
    /// Stops the live timer and logs the session (owned by ContentView, which holds the store).
    let onStopSession: () -> Void

    // Launch argument `-initialTab N` (simulator screenshots); unset in normal use, so 0.
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "initialTab")

    var body: some View {
        // No opaque tab bar background: on iOS 26 the bar is a floating glass capsule
        // and the covers scroll underneath it.
        TabView(selection: $selectedTab) {
            Tab("Collection", systemImage: "square.grid.2x2.fill", value: 0) {
                LibraryView()
            }

            Tab("Découvrir", systemImage: "sparkles", value: 1) {
                DiscoverView()
            }

            Tab("Recherche", systemImage: "magnifyingglass", value: 2) {
                SearchView()
            }

            Tab("Journal", systemImage: "book.fill", value: 3) {
                DiaryView()
            }

            // Profile stays at the far right (no search role: it would detach search there).
            Tab("Profil", systemImage: "person.fill", value: 4) {
                ProfileView()
            }
        }
        .tint(.gbCoral)
        .tabBarMinimizeBehavior(.onScrollDown)
        .modifier(SessionAccessoryModifier(isRunning: timerManager.isRunning, onStop: onStopSession))
    }
}

/// Docks the play-session timer above the tab bar, like the Music mini player.
/// It folds into the bar when the bar minimizes on scroll.
private struct SessionAccessoryModifier: ViewModifier {
    let isRunning: Bool
    let onStop: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isRunning) {
                SessionAccessory(onStop: onStop)
            }
        } else {
            // iOS 26.0 has no isEnabled: an always-attached accessory shows an empty capsule,
            // and attaching it conditionally rebuilds the TabView (popping every tab's stack).
            // Keep the floating card there instead.
            content.overlay {
                PlayTimerOverlay(onStop: onStop)
                    // ponytail: fixed offset to clear the tab bar; measure it if the tab bar changes
                    .padding(.bottom, 56)
            }
        }
    }
}
