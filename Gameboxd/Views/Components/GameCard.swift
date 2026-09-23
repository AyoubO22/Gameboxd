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
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Cover — poster-first, one radius, no colored drop shadow
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(game.coverColor.gradient)
                                .overlay(ProgressView().tint(.textSecondary))
                        }
                    } else {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .font(.title)
                                    .foregroundStyle(Color.textTertiary)
                            )
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(Color.gbBorder, lineWidth: 1)
                )

                // Status capsule
                if game.status != .none {
                    HStack(spacing: 3) {
                        Image(systemName: game.status.icon)
                            .font(.system(size: 8))
                        Text(game.status.rawValue)
                            .font(DS.Typography.label)
                            .lineLimit(1)
                    }
                    .foregroundStyle(game.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(game.status.color.opacity(0.16))
                    .background(Color.gbDark.opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(game.status.color.opacity(0.4), lineWidth: 1))
                    .padding(6)
                }

                if game.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .padding(6)
                        .background(Color.gbDark.opacity(0.7))
                        .foregroundStyle(Color(hex: "FF5C5C"))
                        .clipShape(Circle())
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
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
                                .font(.system(size: 8))
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
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
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
                if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
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
                                    .font(.system(size: 8))
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
                .font(.caption)
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