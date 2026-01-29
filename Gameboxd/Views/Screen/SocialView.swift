//
//  SocialView.swift
//  Gameboxd
//
//  Social features: Friends, Activity Feed, Comments
//

import SwiftUI

struct SocialView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Section", selection: $selectedTab) {
                    Text("Activité").tag(0)
                    Text("Amis").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.gbDark)
                
                // Content
                switch selectedTab {
                case 0:
                    ActivityFeedView()
                case 1:
                    FriendsListView()
                default:
                    EmptyView()
                }
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Social")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: FindFriendsView()) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.gbGreen)
                    }
                }
            }
        }
    }
}

// MARK: - Activity Feed
struct ActivityFeedView: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        if store.activityFeed.isEmpty {
            EmptyActivityView()
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(store.activityFeed) { activity in
                        ActivityCard(activity: activity)
                    }
                }
                .padding()
            }
        }
    }
}

struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("Aucune activité")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Suis des amis pour voir leur activité")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: FindFriendsView()) {
                Text("Trouver des amis")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gbGreen)
                    .foregroundColor(.gbDark)
                    .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ActivityCard: View {
    let activity: ActivityItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.gbGreen.gradient)
                        .frame(width: 40, height: 40)
                    
                    Text(activity.avatarEmoji)
                        .font(.title3)
                }
                
                // User & Action
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(activity.username)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(activity.actionType.rawValue)
                            .foregroundColor(.gray)
                    }
                    .font(.subheadline)
                    
                    Text(activity.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Game Info
            HStack(spacing: 12) {
                // Cover
                if let coverURL = activity.gameCoverURL, let url = URL(string: coverURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gbCard)
                    }
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gbCard)
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.gameTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    // Rating if present
                    if let rating = activity.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.gbGreen)
                    }
                    
                    // Review excerpt if present
                    if let review = activity.review, !review.isEmpty {
                        Text(review)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("J'aime")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("Commenter")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Friends List
struct FriendsListView: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        if store.friends.isEmpty {
            EmptyFriendsView()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.friends) { friend in
                        FriendRow(friend: friend)
                    }
                }
                .padding()
            }
        }
    }
}

struct EmptyFriendsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("Pas encore d'amis")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Trouve des joueurs avec les mêmes goûts")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
            
            NavigationLink(destination: FindFriendsView()) {
                Text("Trouver des amis")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gbGreen)
                    .foregroundColor(.gbDark)
                    .cornerRadius(25)
            }
            
            Spacer()
        }
    }
}

struct FriendRow: View {
    let friend: Friend
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gbGreen.gradient)
                    .frame(width: 50, height: 50)
                
                Text(friend.avatarEmoji)
                    .font(.title2)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(friend.gamesCount) jeux • Actif \(friend.lastActive, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Follow Button
            Button(action: { toggleFollow() }) {
                Text(friend.isFollowing ? "Suivi" : "Suivre")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(friend.isFollowing ? Color.gbCard : Color.gbGreen)
                    .foregroundColor(friend.isFollowing ? .gray : .gbDark)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
    
    func toggleFollow() {
        store.toggleFollowFriend(friend)
    }
}

// MARK: - Find Friends
struct FindFriendsView: View {
    @State private var searchText = ""
    @EnvironmentObject var store: GameStore
    
    // Mock suggested users
    let suggestedUsers = [
        Friend(username: "GamerPro42", avatarEmoji: "🎮", gamesCount: 156, isFollowing: false),
        Friend(username: "RetroLover", avatarEmoji: "👾", gamesCount: 89, isFollowing: false),
        Friend(username: "RPGMaster", avatarEmoji: "⚔️", gamesCount: 234, isFollowing: false),
        Friend(username: "IndieExplorer", avatarEmoji: "🌟", gamesCount: 67, isFollowing: false),
        Friend(username: "SpeedRunner", avatarEmoji: "🏃", gamesCount: 45, isFollowing: false)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Rechercher un joueur...", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
                
                // Suggestions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Suggestions")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(suggestedUsers) { user in
                        SuggestedUserRow(user: user)
                    }
                }
                
                // Share Code
                VStack(spacing: 12) {
                    Text("Partage ton code ami")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("GBOXD-\(store.userProfile.username.prefix(4).uppercased())-\(Int.random(in: 1000...9999))")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.gbGreen)
                        .padding()
                        .background(Color.gbCard)
                        .cornerRadius(12)
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copier")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gbGreen)
                    }
                }
                .padding()
                .background(Color.gbCard.opacity(0.5))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Trouver des amis")
    }
}

struct SuggestedUserRow: View {
    let user: Friend
    @State private var isFollowing = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gbGreen.gradient)
                    .frame(width: 45, height: 45)
                
                Text(user.avatarEmoji)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("\(user.gamesCount) jeux")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { isFollowing.toggle() }) {
                Text(isFollowing ? "Suivi ✓" : "Suivre")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gbCard : Color.gbGreen)
                    .foregroundColor(isFollowing ? .gbGreen : .gbDark)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    SocialView()
        .environmentObject(GameStore())
}
