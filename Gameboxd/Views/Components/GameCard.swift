//
//  GameCard.swift
//  Gameboxd
//
//  Enhanced game card with cover image support
//

import SwiftUI
import Foundation

struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Cover — poster-first, one radius, no colored drop shadow
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let url = game.artURL {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(game.coverColor.gradient)
                        }
                    } else {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .font(DS.Typography.title)
                                    .foregroundStyle(Color.textTertiary)
                            )
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
                // Printed-sleeve sheen, a hairline edge and a soft drop: the cover reads as
                // an object sitting on the page, not a flat tile.
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .center)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 10, y: 6)

                // Status and favorite float on the cover as Liquid Glass: the glass picks
                // up the cover's colours, and the two drops merge instead of overlapping.
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        if game.status != .none {
                            HStack(spacing: 3) {
                                Image(systemName: game.status.icon)
                                    .font(DS.Typography.glyph)
                                Text(game.status.rawValue)
                                    .font(DS.Typography.label)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(game.status.color.opacity(0.5)), in: .capsule)
                        }

                        Spacer(minLength: 0)

                        if game.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(DS.Typography.micro)
                                .foregroundStyle(DS.Colors.error)
                                .padding(6)
                                .glassEffect(.regular, in: .circle)
                        }
                    }
                }
                .padding(6)
            }

            // Title
            Text(game.title)
                .font(DS.Typography.bodyMedium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.textPrimary)

            // Rating & Play Time
            HStack {
                if game.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...game.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(DS.Typography.glyph)
                        }
                    }
                    .foregroundStyle(Color.accent)
                } else {
                    Text("Non noté")
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                // Completion or Play Time
                if game.completionPercentage > 0 {
                    Text("\(game.completionPercentage)%")
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.accent)
                } else if !game.playTime.isEmpty {
                    Text(game.playTime)
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.title), \(game.rating > 0 ? "\(game.rating) étoiles" : "non noté"), \(game.status.rawValue)")
        .accessibilityHint("Ouvre la fiche du jeu")
    }
}

// MARK: - Compact Card for Lists
struct CompactGameCard: View {
    let game: Game

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Thumbnail
            Group {
                if let url = game.artURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                } else {
                    Rectangle().fill(game.coverColor.gradient)
                }
            }
            .frame(width: 44, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(Color.gbBorder, lineWidth: 1)
            )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(game.developer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: 8) {
                    if game.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...game.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(DS.Typography.glyph)
                            }
                        }
                        .foregroundStyle(Color.accent)
                    }

                    if game.status != .none {
                        TagPill(label: game.status.rawValue, icon: game.status.icon, isSelected: true, tint: game.status.color)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .cardStyle()
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack {
            GameCard(game: Game(
                title: "The Legend of Zelda",
                developer: "Nintendo",
                platform: "Switch",
                releaseYear: "2023",
                coverColor: .green,
                rating: 5,
                status: .playing,
                review: "",
                playTime: "45h",
                genres: ["Action"]
            ))
            
            GameCard(game: Game(
                title: "Elden Ring",
                developer: "FromSoftware",
                platform: "PS5",
                releaseYear: "2022",
                coverColor: .orange,
                rating: 4,
                status: .completed,
                review: "",
                playTime: "120h",
                genres: ["RPG"]
            ))
        }
        .padding()
        
        CompactGameCard(game: Game(
            title: "Hollow Knight",
            developer: "Team Cherry",
            platform: "Switch",
            releaseYear: "2017",
            coverColor: .blue,
            rating: 5,
            status: .completed,
            review: "",
            playTime: "30h",
            genres: ["Metroidvania"]
        ))
        .padding(.horizontal)
    }
    .background(Color.gbDark)
}