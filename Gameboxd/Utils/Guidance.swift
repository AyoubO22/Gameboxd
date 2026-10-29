//
//  Guidance.swift
//  Gameboxd
//
//  What the app teaches as it goes: a tip the first time a gesture matters, and a way for an
//  empty screen to send the player to the tab that fills it.
//

import SwiftUI
import TipKit

/// The first time the shelf has games: what a case does when touched.
struct ShelfTip: Tip {
    var title: Text { Text("Touche un boîtier") }
    var message: Text? { Text("Pour noter le jeu, suivre ta partie ou changer son statut. Reste appuyé pour les raccourcis.") }
    var image: Image? { Image(systemName: "hand.tap.fill") }
}

/// The first time a game page opens: the case turns.
struct SpinCaseTip: Tip {
    var title: Text { Text("Fais tourner le boîtier") }
    var message: Text? { Text("Glisse ton doigt dessus pour voir la tranche et le dos.") }
    var image: Image? { Image(systemName: "hand.draw.fill") }
}

extension EnvironmentValues {
    /// Switches the main tab bar to a tab (0 Collection, 1 Découvrir, 2 Recherche, 3 Journal, 4 Profil).
    @Entry var selectTab: (Int) -> Void = { _ in }
}
