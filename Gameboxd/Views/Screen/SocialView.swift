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
                        .foregroundColor(.gbBrass)
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
                .foregroundColor(.textSecondary.opacity(0.3))
            
            Text("Aucune activité")
                .font(DS.Typography.headline)
                .foregroundColor(.textSecondary)
            
            Text("Suis des amis pour voir leur activité")
                .font(DS.Typography.body)
                .foregroundColor(.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: FindFriendsView()) {
                Text("Trouver des amis")
                    .font(DS.Typography.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gbBrass)
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
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.gbBrass.gradient)
                        .frame(width: 40, height: 40)
                    
                    Text(activity.avatarEmoji)
                        .font(DS.Typography.title3)
                }
                
                // User & Action
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(activity.username)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                        
                        Text(activity.actionType.rawValue)
                            .foregroundColor(.textSecondary)
                    }
                    .font(DS.Typography.body)
                    
                    Text(activity.timestamp, style: .relative)
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary.opacity(0.7))
                }
                
                Spacer()
            }
            
            // Game Info
            HStack(spacing: 12) {
                // Cover
                if let coverURL = activity.gameCoverURL, let url = URL(string: coverURL) {
                    CachedAsyncImage(url: url) { image in
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
                                .foregroundColor(.textSecondary)
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.gameTitle)
                        .font(DS.Typography.headline)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                    
                    // Rating if present
                    if let rating = activity.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(DS.Typography.caption)
                            }
                        }
                        .foregroundColor(.gbBrass)
                    }
                    
                    // Review excerpt if present
                    if let review = activity.review, !review.isEmpty {
                        Text(review)
                            .font(DS.Typography.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // Actions
            HStack(spacing: 20) {
                Button(action: { isLiked.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                        Text("J'aime")
                    }
                    .font(DS.Typography.caption)
                    .foregroundColor(isLiked ? .gbBrass : .gray)
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
                .foregroundColor(.textSecondary.opacity(0.3))
            
            Text("Pas encore d'amis")
                .font(DS.Typography.headline)
                .foregroundColor(.textSecondary)
            
            Text("Trouve des joueurs avec les mêmes goûts")
                .font(DS.Typography.body)
                .foregroundColor(.textSecondary.opacity(0.7))
            
            NavigationLink(destination: FindFriendsView()) {
                Text("Trouver des amis")
                    .font(DS.Typography.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.gbBrass)
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
                    .fill(Color.gbBrass.gradient)
                    .frame(width: 50, height: 50)
                
                Text(friend.avatarEmoji)
                    .font(DS.Typography.title)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(DS.Typography.headline)
                    .foregroundColor(.textPrimary)
                
                Text("\(friend.gamesCount) jeux • Actif \(friend.lastActive, style: .relative)")
                    .font(DS.Typography.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Follow Button
            Button(action: { toggleFollow() }) {
                Text(friend.isFollowing ? "Suivi" : "Suivre")
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(friend.isFollowing ? Color.gbCard : Color.gbBrass)
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
    
    private var filteredSuggestions: [Friend] {
        guard !searchText.isEmpty else { return suggestedUsers }
        return suggestedUsers.filter { $0.username.localizedCaseInsensitiveContains(searchText) }
    }

    /// Stable across launches (String.hashValue is randomly seeded per launch).
    private var friendCode: String {
        let name = store.userProfile.username
        let checksum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 10_000 }
        return "GBOXD-\(name.prefix(4).uppercased())-\(checksum)"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textSecondary)
                    
                    TextField("Rechercher un joueur...", text: $searchText)
                        .foregroundColor(.textPrimary)
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
                
                // Suggestions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Suggestions")
                        .font(DS.Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    ForEach(filteredSuggestions) { user in
                        SuggestedUserRow(user: user)
                    }
                }
                
                // Share Code
                VStack(spacing: 12) {
                    Text("Partage ton code ami")
                        .font(DS.Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text(friendCode)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.gbBrass)
                        .padding()
                        .background(Color.gbCard)
                        .cornerRadius(12)
                    
                    Button(action: {
                        UIPasteboard.general.string = friendCode
                        HapticManager.notification(.success)
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copier")
                        }
                        .font(DS.Typography.body)
                        .foregroundColor(.gbBrass)
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
    @EnvironmentObject var store: GameStore
    let user: Friend

    private var isFollowing: Bool {
        store.friends.contains { $0.username == user.username }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gbBrass.gradient)
                    .frame(width: 45, height: 45)
                
                Text(user.avatarEmoji)
                    .font(DS.Typography.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text("\(user.gamesCount) jeux")
                    .font(DS.Typography.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Button(action: {
                if let friend = store.friends.first(where: { $0.username == user.username }) {
                    store.removeFriend(friend)
                } else {
                    store.addFriend(user)
                }
            }) {
                Text(isFollowing ? "Suivi ✓" : "Suivre")
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gbCard : Color.gbBrass)
                    .foregroundColor(isFollowing ? .gbBrass : .gbDark)
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
    NavigationStack { SocialView() }
        .environmentObject(GameStore())
}
