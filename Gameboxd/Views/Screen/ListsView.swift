//
//  ListsView.swift
//  Gameboxd
//
//  Manage custom game lists/collections
//

import SwiftUI

struct ListsView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    @State private var showingCreateList = false
    @State private var editingList: GameList?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(store.gameLists) { list in
                        NavigationLink(destination: ListDetailView(list: list)) {
                            ListRowView(list: list)
                        }
                        .contextMenu {
                            if !list.isDefault {
                                Button(action: { editingList = list }) {
                                    Label("Modifier", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: { store.deleteList(list) }) {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Mes listes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateList = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.gbGreen)
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
            }
            .sheet(item: $editingList) { list in
                CreateListView(editingList: list)
            }
        }
    }
}

// MARK: - List Row View
struct ListRowView: View {
    let list: GameList
    @EnvironmentObject var store: GameStore
    
    var games: [Game] {
        store.gamesInList(list)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(list.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: list.iconName)
                    .font(.title2)
                    .foregroundColor(list.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(list.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if list.isDefault {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                Text("\(games.count) jeu\(games.count > 1 ? "x" : "")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if !list.description.isEmpty {
                    Text(list.description)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Preview covers
            HStack(spacing: -15) {
                ForEach(games.prefix(3)) { game in
                    if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(game.coverColor.gradient)
                        }
                        .frame(width: 30, height: 40)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gbCard, lineWidth: 2)
                        )
                    } else {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .frame(width: 30, height: 40)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gbCard, lineWidth: 2)
                            )
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - List Detail View
struct ListDetailView: View {
    let list: GameList
    @EnvironmentObject var store: GameStore
    @State private var showingAddGame = false
    
    var games: [Game] {
        store.gamesInList(list)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(list.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: list.iconName)
                            .font(.largeTitle)
                            .foregroundColor(list.color)
                    }
                    
                    Text(list.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !list.description.isEmpty {
                        Text(list.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("\(games.count) jeu\(games.count > 1 ? "x" : "")")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                
                // Games Grid
                if games.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("Cette liste est vide")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: { showingAddGame = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Ajouter des jeux")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.gbGreen)
                            .foregroundColor(.gbDark)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.vertical, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                        ForEach(games) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                GameCard(game: game)
                            }
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    store.removeGameFromList(game, list: list)
                                }) {
                                    Label("Retirer de la liste", systemImage: "minus.circle")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddGame = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(.gbGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddGame) {
            AddGameToListView(list: list)
        }
    }
}

// MARK: - Create List View
struct CreateListView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    var editingList: GameList?
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedIcon = "list.bullet"
    @State private var selectedColor = Color.blue
    
    let icons = [
        "list.bullet", "star.fill", "heart.fill", "bookmark.fill",
        "gamecontroller.fill", "trophy.fill", "crown.fill", "flame.fill",
        "sparkles", "bolt.fill", "leaf.fill", "moon.fill"
    ]
    
    let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .cyan, .indigo, .mint]
    
    var isEditing: Bool { editingList != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations") {
                    TextField("Nom de la liste", text: $name)
                    TextField("Description (optionnel)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Icône") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .background(selectedIcon == icon ? selectedColor.opacity(0.3) : Color.gbCard)
                                        .foregroundColor(selectedIcon == icon ? selectedColor : .gray)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("Couleur") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle(isEditing ? "Modifier la liste" : "Nouvelle liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Sauvegarder" : "Créer") {
                        saveList()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(name.isEmpty ? .gray : .gbGreen)
                }
            }
            .onAppear {
                if let list = editingList {
                    name = list.name
                    description = list.description
                    selectedIcon = list.iconName
                    selectedColor = list.color
                }
            }
        }
    }
    
    private func saveList() {
        if let existing = editingList {
            var updatedList = existing
            updatedList.name = name
            updatedList.description = description
            updatedList.iconName = selectedIcon
            updatedList.colorHex = selectedColor.toHex()
            updatedList.updatedDate = Date()
            store.updateList(updatedList)
        } else {
            let newList = GameList(
                name: name,
                description: description,
                iconName: selectedIcon,
                color: selectedColor
            )
            store.createList(newList)
        }
        dismiss()
    }
}

// MARK: - Add Game to List View
struct AddGameToListView: View {
    let list: GameList
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var availableGames: [Game] {
        let gamesNotInList = store.myGames.filter { game in
            !list.gameIds.contains(game.id)
        }
        
        if searchText.isEmpty {
            return gamesNotInList
        }
        
        return gamesNotInList.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(availableGames) { game in
                Button(action: {
                    store.addGameToList(game, list: list)
                }) {
                    HStack {
                        if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(game.coverColor.gradient)
                            }
                            .frame(width: 40, height: 50)
                            .cornerRadius(4)
                        } else {
                            Rectangle()
                                .fill(game.coverColor.gradient)
                                .frame(width: 40, height: 50)
                                .cornerRadius(4)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(game.title)
                                .foregroundColor(.white)
                            Text(game.platform)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .foregroundColor(.gbGreen)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .searchable(text: $searchText, prompt: "Chercher un jeu")
            .navigationTitle("Ajouter à \(list.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") { dismiss() }
                        .foregroundColor(.gbGreen)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ListsView()
        .environmentObject(GameStore())
}
