//
//  ShareCardView.swift
//  Gameboxd
//
//  Generate shareable image cards for games
//

import SwiftUI

struct ShareCardView: View {
    let game: Game
    @Environment(\.dismiss) var dismiss
    @State private var selectedStyle: ShareCardStyle = .dark
    @State private var renderedImage: UIImage?
    @State private var showingShareSheet = false
    
    enum ShareCardStyle: String, CaseIterable {
        case dark = "Sombre"
        case light = "Clair"
        case gradient = "Dégradé"
        case minimal = "Minimal"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Card
                    GameShareCard(game: game, style: selectedStyle)
                        .frame(width: 350, height: 450)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.3), radius: 20)
                    
                    // Style Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Style")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 12) {
                            ForEach(ShareCardStyle.allCases, id: \.self) { style in
                                Button(action: { selectedStyle = style }) {
                                    Text(style.rawValue)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(selectedStyle == style ? Color.gbGreen : Color.gbCard)
                                        .foregroundColor(selectedStyle == style ? .gbDark : .gray)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Share Button
                    Button(action: shareCard) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Partager")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gbGreen.gradient)
                        .foregroundColor(.gbDark)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Partager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = renderedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }
    
    @MainActor
    func shareCard() {
        let renderer = ImageRenderer(content: GameShareCard(game: game, style: selectedStyle).frame(width: 350, height: 450))
        renderer.scale = 3.0
        
        if let image = renderer.uiImage {
            renderedImage = image
            showingShareSheet = true
        }
    }
}

// MARK: - Game Share Card
struct GameShareCard: View {
    let game: Game
    let style: ShareCardView.ShareCardStyle
    
    var backgroundColor: Color {
        switch style {
        case .dark: return Color(hex: "1A1A1E")
        case .light: return .white
        case .gradient: return game.coverColor
        case .minimal: return Color(hex: "0A0A0A")
        }
    }
    
    var textColor: Color {
        style == .light ? .black : .white
    }
    
    var body: some View {
        ZStack {
            // Background
            if style == .gradient {
                LinearGradient(
                    colors: [game.coverColor, game.coverColor.opacity(0.5), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                backgroundColor
            }
            
            VStack(spacing: 20) {
                // Cover
                if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                    .frame(width: style == .minimal ? 150 : 180, height: style == .minimal ? 200 : 240)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 10)
                } else {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .frame(width: 180, height: 240)
                        .cornerRadius(12)
                }
                
                // Title
                Text(game.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Rating
                if game.rating > 0 {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= game.rating ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                // Review Preview
                if let review = game.review, !review.isEmpty {
                    Text("\"\(review)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(textColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Branding
                HStack(spacing: 6) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.caption)
                    Text("Gameboxd")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(textColor.opacity(0.5))
            }
            .padding(24)
        }
    }
}

// MARK: - Preview
#Preview {
    ShareCardView(game: Game(
        title: "The Legend of Zelda: TOTK",
        developer: "Nintendo",
        platform: "Switch",
        releaseYear: "2023",
        coverColor: .green,
        rating: 5,
        status: .completed,
        review: "Un chef-d'œuvre absolu qui redéfinit le genre open world."
    ))
}
