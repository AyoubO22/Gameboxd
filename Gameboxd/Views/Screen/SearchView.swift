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

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isPending: Bool { store.searchedQuery != query }
    
    var body: some View {
        NavigationStack {
            VStack {
                if query.isEmpty {
                    SearchEmptyStateView(searchText: "", onSuggestionTap: { suggestion in
                        searchText = suggestion
                    })
                } else if store.searchResults.isEmpty && isPending {
                    // Typed, not answered yet: loading, never "no results".
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.gbBrass)
                        Text("Recherche en cours...")
                            .font(DS.Typography.body)
                            .foregroundColor(.textSecondary)
                        Spacer()
                    }
                } else if store.searchResults.isEmpty {
                    SearchEmptyStateView(searchText: query)
                } else {
                    // Results (the previous ones stay, dimmed, while the next query runs)
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
                    .opacity(isPending ? 0.5 : 1)
                    .animation(.easeOut(duration: 0.15), value: isPending)
                }
            }
            // Fill the screen: without this the VStack is only as wide as its content,
            // and the background showed as a narrow strip with black on each side.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .searchable(text: $searchText, prompt: "Chercher un jeu (ex: Zelda, Elden Ring...)")
            .onChange(of: searchText) { _, newValue in
                // Cancel previous search
                searchTask?.cancel()
                
                // Debounce search
                let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await store.searchGamesOnline(query: query)
                }
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Recherche")
            #if DEBUG
            // Launch argument `-debugSearch "<text>"`: type a search, for simulator checks.
            .onAppear {
                if searchText.isEmpty, let text = UserDefaults.standard.string(forKey: "debugSearch") {
                    searchText = text
                }
            }
            #endif
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
                    .foregroundColor(.textSecondary.opacity(0.3))
                
                Text("Découvre de nouveaux jeux")
                    .font(DS.Typography.headline)
                    .foregroundColor(.textSecondary)
                
                Text("Recherche par titre, développeur ou plateforme")
                    .font(DS.Typography.body)
                    .foregroundColor(.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Quick search suggestions
                VStack(spacing: 12) {
                    Text("Suggestions")
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(["Zelda", "Elden Ring", "Hades", "Mario", "God of War"], id: \.self) { suggestion in
                            Button(action: { onSuggestionTap?(suggestion) }) {
                            Text(suggestion)
                                .font(DS.Typography.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gbCard)
                                .foregroundColor(.gbBrass)
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
                    .foregroundColor(.textSecondary.opacity(0.3))
                
                Text("Aucun résultat pour '\(searchText)'")
                    .font(DS.Typography.headline)
                    .foregroundColor(.textSecondary)
                
                Text("Vérifie l'orthographe ou essaie un autre terme")
                    .font(DS.Typography.body)
                    .foregroundColor(.textSecondary.opacity(0.7))
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
            if let url = game.artURL {
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
                            .foregroundColor(.textPrimary.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(DS.Typography.headline)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                if !game.developer.isEmpty {
                    Text(game.developer)
                        .font(DS.Typography.body)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Platform badge
                    Text(game.platform)
                        .font(DS.Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gbBrass.opacity(0.2))
                        .foregroundColor(.gbBrass)
                        .cornerRadius(6)
                    
                    // Year
                    Text(game.releaseYear)
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    // Metacritic
                    if let score = game.metacriticScore {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(DS.Typography.micro)
                            Text("\(score)")
                                .font(DS.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(metacriticColor(score))
                    }
                }
                
                // Genres
                if !game.genres.isEmpty {
                    Text(game.genres.prefix(2).joined(separator: ", "))
                        .font(DS.Typography.micro)
                        .foregroundColor(.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if isInLibrary {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.gbBrass)
                        .font(DS.Typography.title)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
                    .font(DS.Typography.caption)
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