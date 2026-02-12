//
//  SearchView.swift
//  Gameboxd
//
//  Search for games using RAWG API
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var store: GameStore
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack {
                if store.searchResults.isEmpty && !store.isSearching {
                    // Empty state or suggestions
                    SearchEmptyStateView(searchText: searchText, onSuggestionTap: { suggestion in
                        searchText = suggestion
                    })
                } else if store.isSearching {
                    // Loading state
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.gbGreen)
                        Text("Recherche en cours...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    // Results
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.searchResults) { game in
                                let displayGame = store.libraryGame(for: game) ?? game
                                NavigationLink(destination: GameDetailView(game: displayGame)) {
                                    SearchResultRow(game: game, isInLibrary: store.isInLibrary(game))
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Chercher un jeu (ex: Zelda, Elden Ring...)")
            .onChange(of: searchText) { _, newValue in
                // Cancel previous search
                searchTask?.cancel()
                
                // Debounce search
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    guard !Task.isCancelled else { return }
                    await store.searchGamesOnline(query: newValue)
                }
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Recherche")
        }
    }
}

// Vue pour l'état vide de recherche
struct SearchEmptyStateView: View {
    let searchText: String
    var onSuggestionTap: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 70))
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("Découvre de nouveaux jeux")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("Recherche par titre, développeur ou plateforme")
                    .font(.subheadline)
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Quick search suggestions
                VStack(spacing: 12) {
                    Text("Suggestions")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(["Zelda", "Elden Ring", "Hades", "Mario", "God of War"], id: \.self) { suggestion in
                            Button(action: { onSuggestionTap?(suggestion) }) {
                            Text(suggestion)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gbCard)
                                .foregroundColor(.gbGreen)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("Aucun résultat pour '\(searchText)'")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("Vérifie l'orthographe ou essaie un autre terme")
                    .font(.subheadline)
                    .foregroundColor(.gray.opacity(0.7))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Simple flow layout for suggestions
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
                self.size.height = y + rowHeight
            }
        }
    }
}

// Composant d'une ligne de résultat de recherche
struct SearchResultRow: View {
    let game: Game
    var isInLibrary: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .overlay(ProgressView().tint(.white))
                }
                .frame(width: 70, height: 90)
                .cornerRadius(8)
                .clipped()
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(width: 70, height: 90)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(game.developer)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Platform badge
                    Text(game.platform)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gbGreen.opacity(0.2))
                        .foregroundColor(.gbGreen)
                        .cornerRadius(6)
                    
                    // Year
                    Text(game.releaseYear)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Metacritic
                    if let score = game.metacriticScore {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("\(score)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(metacriticColor(score))
                    }
                }
                
                // Genres
                if !game.genres.isEmpty {
                    Text(game.genres.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if isInLibrary {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.gbGreen)
                        .font(.title2)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color.gbCard)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.title) par \(game.developer), \(game.platform), \(game.releaseYear)\(isInLibrary ? ", dans ta collection" : "")")
    }
}

// MARK: - Preview
#Preview {
    SearchView()
        .environmentObject(GameStore())
}