import SwiftUI

extension Color {
    // Vert "Gameboy" rétro pour les accents
    static let gbGreen = Color(red: 0.55, green: 0.76, blue: 0.29)
    
    // Fond sombre principal (presque noir)
    static let gbDark = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    // Couleur des cartes et éléments de fond secondaires
    static let gbCard = Color(red: 0.15, green: 0.15, blue: 0.18)
    
    // Couleur pour le texte secondaire
    static let gbTextSecondary = Color.gray
    
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
        guard let components = UIColor(self).cgColor.components else { return "808080" }
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
