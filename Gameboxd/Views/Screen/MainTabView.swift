//
//  MainTabView.swift
//  Gameboxd
//
//  Main navigation with 5 tabs
//

import SwiftUI

struct MainTabView: View {
    // Launch argument `-initialTab N` (simulator screenshots); unset in normal use, so 0.
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "initialTab")
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Collection", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)
            
            DiscoverView()
                .tabItem {
                    Label("Découvrir", systemImage: "sparkles")
                }
                .tag(1)
            
            SearchView()
                .tabItem {
                    Label("Recherche", systemImage: "magnifyingglass")
                }
                .tag(2)
            
            DiaryView()
                .tabItem {
                    Label("Journal", systemImage: "book.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(.gbBrass)
        .toolbarBackground(Color.gbDark, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}