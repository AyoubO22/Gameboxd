import SwiftUI

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
    enum Typography {
        static let largeTitle: Font = .largeTitle.weight(.bold)
        static let title: Font = .title2.weight(.semibold)
        static let headline: Font = .headline.weight(.semibold)
        static let body: Font = .subheadline
        static let bodyMedium: Font = .subheadline.weight(.medium)
        static let caption: Font = .caption
        static let captionMedium: Font = .caption.weight(.medium)
        static let micro: Font = .caption2
    }

    // MARK: - Semantic Colors
    enum Colors {
        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FF9F0A")
        static let error = Color(hex: "FF453A")

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
    }
}

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(DS.Typography.title)
            .foregroundStyle(Color.textPrimary)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func sectionHeader() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.Typography.title)
                .foregroundStyle(Color.textPrimary)

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

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TagPill: View {
    let label: String
    var icon: String? = nil
    var isSelected: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Text(label)
                .font(DS.Typography.captionMedium)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(isSelected ? Color.accent.opacity(0.15) : Color.surfaceSecondary)
        .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
        .clipShape(Capsule())
    }
}

struct MetricCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accent)

            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(DS.Typography.micro)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
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
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
    }
}
