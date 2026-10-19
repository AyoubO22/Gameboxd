import SwiftUI
import CoreText

// MARK: - Design Tokens
// Single source of truth for all visual constants.
// Never hardcode colors, spacing, or radii elsewhere.

enum DS {

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999
    }

    // MARK: - Typography
    // System sans, heavy and tight for titles (launch-video look). Big Shoulders stays
    // only on box spines, the condensed face of game-case spines. Everything scales with
    // Dynamic Type (sizes go through UIFontMetrics, and the presets are computed so a
    // size change is picked up on the next render), except type printed on cases
    // (spinePrint, PEGI): print is a fixed size.
    enum Typography {
        private static func scaled(_ size: CGFloat, _ style: Font.TextStyle) -> CGFloat {
            UIFontMetrics(forTextStyle: style.uiKit).scaledValue(for: size)
        }
        static func display(_ size: CGFloat, weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
            .system(size: scaled(size, style), weight: weight)
        }
        static func text(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
            .system(size: scaled(size, style), weight: weight)
        }
        /// Type printed on a case spine: Big Shoulders at a fixed size (print doesn't follow
        /// Dynamic Type), its weight axis set through Core Text since `.weight()` isn't
        /// documented to drive a variable font's axis. 900 is Black.
        static func spinePrint(_ size: CGFloat, weight: CGFloat = 900) -> Font {
            let key = SpinePrintKey(size: size, weight: weight)
            if let font = spinePrintFonts[key] { return font }
            let attributes: [String: Any] = [
                kCTFontNameAttribute as String: "BigShouldersDisplay-Thin",
                kCTFontVariationAttribute as String: [NSNumber(value: 0x7767_6874): NSNumber(value: Double(weight))], // 'wght'
            ]
            let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
            let font = Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
            spinePrintFonts[key] = font
            return font
        }

        /// A shelf asks for a handful of sizes, once per spine built while scrolling: each
        /// variable-font instance is made once, and spines share it.
        private static var spinePrintFonts: [SpinePrintKey: Font] = [:]

        static var largeTitle: Font { display(34) }
        static var title: Font { display(24, relativeTo: .title2) }
        static var title3: Font { display(20, weight: .semibold, relativeTo: .title3) }
        static var headline: Font { text(17, weight: .semibold, relativeTo: .headline) }
        static var bodyLarge: Font { text(17) }
        static var body: Font { text(15, relativeTo: .subheadline) }
        static var bodyMedium: Font { text(15, weight: .semibold, relativeTo: .subheadline) }
        static var caption: Font { text(13, relativeTo: .caption) }
        static var captionMedium: Font { text(13, weight: .semibold, relativeTo: .caption) }
        static var micro: Font { text(11, relativeTo: .caption2) }
        /// Tiny icons next to text (stars, status glyphs). 9 pt floor: 8 pt drops below legibility.
        static var glyph: Font { text(9, weight: .semibold, relativeTo: .caption2) }

        /// Big numbers (hours, counts).
        static var stat: Font { display(32, relativeTo: .title) }
        /// Small data labels. Sentence case, no monospace.
        static var label: Font { text(12, weight: .semibold, relativeTo: .caption2) }
        /// Month / section dividers: small caps, wide tracking. Pair with `.tracking(1.2)`.
        static var overline: Font { text(12, weight: .bold, relativeTo: .caption2) }
    }

    // MARK: - Semantic Colors
    enum Colors {
        static let success = Color(hex: "3DDC84")   // vert « En cours »
        static let warning = Color(hex: "F5B942")   // jaune étoiles / backlog
        static let error = Color(hex: "FF5A4E")

        // Metacritic-style score color
        static func score(_ value: Int) -> Color {
            if value >= 75 { return success }
            if value >= 50 { return warning }
            return error
        }
    }
}

// MARK: - Reusable View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.md)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.gbBorder, lineWidth: 1)
            )
    }
}


/// Covers sink a little under the finger, then the zoom transition takes over.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.title)
                    .foregroundStyle(Color.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            if let trailing = trailing {
                Button(action: { trailingAction?() }) {
                    Text(trailing)
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    /// The one thing to do about it, as a button (a sentence telling where to go is not enough).
    var actionTitle: String? = nil
    var actionIcon = "magnifyingglass"
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.textTertiary)

            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.textSecondary)

            if let message = message {
                Text(message)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionIcon)
                        .font(DS.Typography.headline)
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(height: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.gbCoral)
                .padding(.top, DS.Spacing.xs)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TagPill: View {
    let label: String
    var icon: String? = nil
    var isSelected: Bool = false
    var tint: Color = .accent
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(DS.Typography.micro)
            }

            Text(label)
                .font(DS.Typography.captionMedium)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .accessibilityLabel("Retirer")
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(isSelected ? tint.opacity(0.16) : Color.surfacePrimary)
        .foregroundStyle(isSelected ? tint : Color.textSecondary)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(isSelected ? tint.opacity(0.4) : Color.gbBorder, lineWidth: 1)
        )
    }
}

struct MetricCard: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = .accent
    var compact: Bool = false

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.bodyLarge)
                .foregroundStyle(tint)

            Text(value)
                .font(compact ? DS.Typography.headline.monospacedDigit() : DS.Typography.stat)
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? DS.Spacing.sm : DS.Spacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.gbBorder, lineWidth: 1)
        )
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(Color.accent)
            .foregroundStyle(Color.gbDark)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
    }
}

/// Capsule-row segmented control replacing native `.pickerStyle(.segmented)`,
/// which doesn't take the app's colors. Preserves selection semantics for
/// VoiceOver via `.isSelected`.
struct PillSegmentedControl<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    @Namespace private var namespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selection = option
                        }
                    }) {
                        Text(label(option))
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(isSelected ? Color.gbDark : Color.textSecondary)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.accent)
                                        .matchedGeometryEffect(id: "pillSegment", in: namespace)
                                } else {
                                    Capsule()
                                        .stroke(Color.gbBorder, lineWidth: 1)
                                }
                            }
                    }
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private extension Font.TextStyle {
    var uiKit: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
}

/// A spine font's size and weight, to make each variable-font instance once (DS.Typography.spinePrint).
private struct SpinePrintKey: Hashable {
    let size: CGFloat
    let weight: CGFloat
}
