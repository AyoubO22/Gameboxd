//
//  ContentView.swift
//  Gameboxd
//
//  Root view that switches between Auth and Main app
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        Group {
            if store.isLoggedIn {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: store.isLoggedIn)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStore())
}
