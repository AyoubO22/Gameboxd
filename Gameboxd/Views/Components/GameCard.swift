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
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image or Color
            ZStack(alignment: .topTrailing) {
                if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(game.coverColor.gradient)
                                .aspectRatio(3/4, contentMode: .fit)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                        .tint(.white.opacity(0.7))
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(3/4, contentMode: .fit)
                                .clipped()
                                .cornerRadius(8)
                        case .failure:
                            Rectangle()
                                .fill(game.coverColor.gradient)
                                .aspectRatio(3/4, contentMode: .fit)
                                .cornerRadius(8)
                        @unknown default:
                            Rectangle()
                                .fill(game.coverColor.gradient)
                                .aspectRatio(3/4, contentMode: .fit)
                                .cornerRadius(8)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: game.coverColor.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .aspectRatio(3/4, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            VStack {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: game.coverColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                // Badges overlay
                VStack(alignment: .trailing, spacing: 4) {
                    // Status badge
                    if game.status != .none {
                        Image(systemName: game.status.icon)
                            .font(.caption)
                            .padding(6)
                            .background(game.status.color)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    // Favorite badge
                    if game.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .padding(6)
                            .background(.red)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(6)
            }
            
            // Title
            Text(game.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.white)
            
            // Rating & Play Time
            HStack {
                if game.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...game.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                        }
                    }
                    .foregroundColor(.gbGreen)
                } else {
                    Text("Non noté")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Completion or Play Time
                if game.completionPercentage > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "percent")
                            .font(.system(size: 6))
                        Text("\(game.completionPercentage)")
                            .font(.caption2)
                    }
                    .foregroundColor(.gbGreen)
                } else if !game.playTime.isEmpty {
                    Text(game.playTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.gbCard)
        .cornerRadius(12)
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
        HStack(spacing: 12) {
            // Thumbnail
            if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(game.coverColor.gradient)
                }
                .frame(width: 50, height: 65)
                .cornerRadius(6)
                .clipped()
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(width: 50, height: 65)
                    .cornerRadius(6)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(game.developer)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 8) {
                    if game.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...game.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(.gbGreen)
                    }
                    
                    if game.status != .none {
                        HStack(spacing: 2) {
                            Image(systemName: game.status.icon)
                                .font(.system(size: 8))
                            Text(game.status.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(game.status.color)
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.gbCard)
        .cornerRadius(10)
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