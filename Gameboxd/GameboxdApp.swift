import SwiftUI

@main
struct GameboxdApp: App {
    // On instancie le store ici pour qu'il vive pendant toute la durée de vie de l'app
    @StateObject private var store = GameStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store) // On l'injecte dans toute l'app
                .preferredColorScheme(.dark) // Force le mode sombre
        }
    }
}
