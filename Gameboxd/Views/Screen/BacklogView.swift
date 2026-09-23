//
//  BacklogView.swift
//  Gameboxd
//
//  Backlog management with random picker
//

import SwiftUI

struct BacklogView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedPriority: GamePriority? = nil
    @State private var showingRandomPicker = false
    @State private var randomGame: Game? = nil
    @State private var isSpinning = false
    @State private var spinTimer: Timer? = nil
    
    var filteredBacklog: [Game] {
        if let priority = selectedPriority {
            return store.backlog.filter { $0.priority == priority }
        }
        return store.backlog
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Random Picker Card
            RandomPickerCard(
                onSpin: spinWheel,
                isSpinning: isSpinning,
                selectedGame: randomGame
            )
            .padding()
            
            // Priority Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PriorityFilterChip(
                        label: "Tous",
                        count: store.backlog.count,
                        isSelected: selectedPriority == nil,
                        color: .gray
                    ) {
                        selectedPriority = nil
                    }
                    
                    ForEach(GamePriority.allCases, id: \.self) { priority in
                        PriorityFilterChip(
                            label: priority.rawValue,
                            count: store.backlog.filter { $0.priority == priority }.count,
                            isSelected: selectedPriority == priority,
                            color: priority.color
                        ) {
                            selectedPriority = priority
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // Backlog List
            if filteredBacklog.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.textSecondary.opacity(0.3))
                    Text("Backlog vide")
                        .font(DS.Typography.headline)
                        .foregroundColor(.textSecondary)
                    Text("Ajoute des jeux avec le statut\n\"À jouer\" pour les voir ici")
                        .font(DS.Typography.body)
                        .foregroundColor(.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredBacklog) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                BacklogGameRow(game: game)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Backlog")
        .navigationBarTitleDisplayMode(.large)
        .onDisappear {
            spinTimer?.invalidate()
            spinTimer = nil
        }
    }
    
    func spinWheel() {
        guard !store.backlog.isEmpty else { return }
        
        isSpinning = true
        randomGame = nil
        
        // Capture values for timer closure
        let backlogGames = store.backlog
        
        // Simulate spinning animation
        var iterations = 0
        let maxIterations = 15
        
        spinTimer?.invalidate()
        spinTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] timer in
            randomGame = backlogGames.randomElement()
            iterations += 1
            
            if iterations >= maxIterations {
                timer.invalidate()
                spinTimer = nil
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    randomGame = backlogGames.randomElement()
                    isSpinning = false
                }
            }
        }
    }
}

// MARK: - Random Picker Card
struct RandomPickerCard: View {
    let onSpin: () -> Void
    let isSpinning: Bool
    let selectedGame: Game?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "dice.fill")
                    .font(DS.Typography.title)
                    .foregroundColor(.gbBrass)
                
                Text("À quoi jouer ?")
                    .font(DS.Typography.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
            }
            
            if let game = selectedGame {
                // Selected Game Display
                HStack(spacing: 12) {
                    if let url = game.artURL {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(game.coverColor.gradient)
                        }
                        .frame(width: 60, height: 80)
                        .cornerRadius(8)
                        .shadow(color: .gbBrass.opacity(0.5), radius: 10)
                    } else {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .frame(width: 60, height: 80)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title)
                            .font(DS.Typography.headline)
                            .foregroundColor(.textPrimary)
                            .lineLimit(2)
                        
                        Text(game.platform)
                            .font(DS.Typography.caption)
                            .foregroundColor(.textSecondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: game.priority.icon)
                            Text(game.priority.rawValue)
                        }
                        .font(DS.Typography.micro)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(game.priority.color.opacity(0.2))
                        .foregroundColor(game.priority.color)
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    NavigationLink(destination: GameDetailView(game: game)) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gbBrass)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Placeholder
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gbCard)
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "questionmark")
                                .font(DS.Typography.title)
                                .foregroundColor(.textSecondary.opacity(0.5))
                        )
                    
                    Text(isSpinning ? "Recherche en cours..." : "Clique sur le bouton pour choisir")
                        .font(DS.Typography.body)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                }
            }
            
            // Spin Button
            Button(action: onSpin) {
                HStack {
                    Image(systemName: isSpinning ? "arrow.triangle.2.circlepath" : "shuffle")
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(isSpinning ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default, value: isSpinning)
                    
                    Text(isSpinning ? "Choix en cours..." : "Choisis pour moi !")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gbBrass.gradient)
                .foregroundColor(.gbDark)
                .cornerRadius(12)
            }
            .disabled(isSpinning)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(16)
    }
}

// MARK: - Priority Filter Chip
struct PriorityFilterChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(DS.Typography.micro)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                    .cornerRadius(10)
            }
            .font(DS.Typography.body)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(isSelected ? color : Color.gbCard)
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
        }
    }
}

// MARK: - Backlog Game Row
struct BacklogGameRow: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let url = game.artURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(game.coverColor.gradient)
                }
                .frame(width: 60, height: 80)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(DS.Typography.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(game.platform)
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    if let playtime = game.estimatedPlaytime, playtime > 0 {
                        Label("~\(playtime)h", systemImage: "clock")
                            .font(DS.Typography.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // Priority Badge
                HStack(spacing: 4) {
                    Image(systemName: game.priority.icon)
                    Text(game.priority.rawValue)
                }
                .font(DS.Typography.micro)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(game.priority.color.opacity(0.2))
                .foregroundColor(game.priority.color)
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Quick Actions
            VStack(spacing: 8) {
                Button(action: { startPlaying() }) {
                    Image(systemName: "play.fill")
                        .font(DS.Typography.caption)
                        .padding(8)
                        .background(Color.gbBrass)
                        .foregroundColor(.gbDark)
                        .cornerRadius(8)
                }
                
                Menu {
                    ForEach(GamePriority.allCases, id: \.self) { priority in
                        Button(action: { setPriority(priority) }) {
                            Label(priority.rawValue, systemImage: priority.icon)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(DS.Typography.caption)
                        .padding(8)
                        .background(Color.gbCard)
                        .foregroundColor(.textSecondary)
                        .cornerRadius(8)
                }
                .accessibilityLabel("Plus d'actions")
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
    
    func startPlaying() {
        var updatedGame = game
        updatedGame.status = .playing
        updatedGame.startedDate = Date()
        store.updateGame(updatedGame)
    }
    
    func setPriority(_ priority: GamePriority) {
        var updatedGame = game
        updatedGame.priority = priority
        store.updateGame(updatedGame)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { BacklogView() }
        .environmentObject(GameStore())
}
