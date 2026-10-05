import SwiftUI

extension Color {
    // Palette graphite + corail (vidéo de lancement).
    static let gbCoral = Color(hex: "F2553C")      // corail : actions, sélection
    static let gbDark = Color(hex: "0F1216")       // graphite : fond
    static let gbCard = Color(hex: "1A1E24")       // surfaces
    static let gbSurface2 = Color(hex: "252A32")   // surfaces imbriquées
    static let gbBorder = Color(hex: "2A3038")     // séparateurs

    static let gbTextSecondary = Color(hex: "9AA3AE")

    // MARK: - Semantic Design System Colors
    static let accent = Color.gbCoral
    static let textPrimary = Color(hex: "F3F5F8")
    static let textSecondary = Color.gbTextSecondary
    static let textTertiary = Color(hex: "646D78")
    static let surfacePrimary = Color.gbCard
    static let surfaceSecondary = Color.gbSurface2
    static let separator = Color.gbBorder
    
    // MARK: - Hex Conversion (pour Codable)
    
    /// Crée une couleur à partir d'un code hex
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128) // Gris par défaut
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convertit la couleur en code hex ARGB (8 chiffres).
    /// Les composantes sont clampées à [0, 1] pour rester valides même avec des
    /// couleurs wide-gamut (P3) dont les composantes peuvent dépasser 1.0, et
    /// l'alpha est conservé pour un round-trip fidèle avec `init(hex:)`.
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        // getRed renvoie false pour certains espaces colorimétriques (motifs,
        // niveaux de gris non convertis) : on retombe alors sur un gris opaque.
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "FF808080"
        }
        func channel(_ value: CGFloat) -> Int {
            Int((max(0, min(1, value)) * 255).rounded())
        }
        return String(format: "%02X%02X%02X%02X", channel(a), channel(r), channel(g), channel(b))
    }
}

// MARK: - Metacritic Color Helper (global)
func metacriticColor(_ score: Int) -> Color {
    DS.Colors.score(score)
}
