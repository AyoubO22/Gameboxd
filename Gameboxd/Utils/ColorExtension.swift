import SwiftUI

// MARK: - Theme Manager
final class ThemeManager {
    static let shared = ThemeManager()
    var currentTheme: AppTheme = .default
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: "gameboxd_theme"),
           let theme = AppTheme(rawValue: raw) {
            currentTheme = theme
        }
    }
}

extension Color {
    // Dynamic theme colors
    static var gbGreen: Color { ThemeManager.shared.currentTheme.accentColor }
    static var gbDark: Color { ThemeManager.shared.currentTheme.darkColor }
    static var gbCard: Color { ThemeManager.shared.currentTheme.cardColor }
    
    // Couleur pour le texte secondaire
    static let gbTextSecondary = Color.gray

    // MARK: - Semantic Design System Colors
    static var accent: Color { ThemeManager.shared.currentTheme.accentColor }
    static var textPrimary: Color { .white }
    static var textSecondary: Color { .gray }
    static var textTertiary: Color { Color.gray.opacity(0.5) }
    static var surfacePrimary: Color { ThemeManager.shared.currentTheme.cardColor }
    static var surfaceSecondary: Color { ThemeManager.shared.currentTheme.darkColor }
    static var separator: Color { Color.gray.opacity(0.3) }
    
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
    
    /// Convertit la couleur en code hex
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Metacritic Color Helper (global)
func metacriticColor(_ score: Int) -> Color {
    if score >= 75 { return .green }
    if score >= 50 { return .yellow }
    return .red
}
