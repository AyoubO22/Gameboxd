//
//  AchievementsView.swift
//  Gameboxd
//
//  Display achievements and badges
//

import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedCategory: AchievementCategory? = nil
    @State private var showingUnlockedOnly = false
    
    var filteredAchievements: [Achievement] {
        var achievements = store.achievements
        
        if let category = selectedCategory {
            achievements = achievements.filter { $0.category == category }
        }
        
        if showingUnlockedOnly {
            achievements = achievements.filter { $0.isUnlocked }
        }
        
        return achievements
    }
    
    var unlockedCount: Int {
        store.achievements.filter { $0.isUnlocked }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Progress Header
                AchievementProgressHeader(
                    unlocked: unlockedCount,
                    total: store.achievements.count
                )
                
                // Recently Unlocked
                if !store.recentlyUnlockedAchievements.isEmpty {
                    RecentAchievementsSection(achievements: store.recentlyUnlockedAchievements)
                }
                
                // Filters
                VStack(spacing: 12) {
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            CategoryFilterButton(
                                title: "Tous",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }
                            
                            ForEach(AchievementCategory.allCases, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Toggle
                    Toggle("Débloqués uniquement", isOn: $showingUnlockedOnly)
                        .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
                        .padding(.horizontal)
                        .foregroundColor(.white)
                }
                
                // Achievements Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredAchievements) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Succès")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Progress Header
struct AchievementProgressHeader: View {
    let unlocked: Int
    let total: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(unlocked) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Trophy Icon
            ZStack {
                Circle()
                    .fill(Color.gbGreen.gradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.gbDark)
            }
            
            // Count
            Text("\(unlocked)/\(total)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Succès débloqués")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gbCard)
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gbGreen.gradient)
                        .frame(width: geometry.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 40)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.gbGreen)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Recent Achievements
struct RecentAchievementsSection: View {
    let achievements: [Achievement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎉 Récemment débloqués")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements) { achievement in
                        RecentAchievementBadge(achievement: achievement)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecentAchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievementColor(for: achievement).gradient)
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 80)
    }
}

// Helper function for achievement colors
func achievementColor(for achievement: Achievement) -> Color {
    switch achievement.category {
    case .collection: return .green
    case .completion: return .blue
    case .time: return .purple
    case .social: return .pink
    case .exploration: return .cyan
    case .dedication: return .orange
    }
}

// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.gbGreen : Color.gbCard)
            .foregroundColor(isSelected ? .gbDark : .gray)
            .cornerRadius(20)
        }
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    @State private var showingDetail = false
    @State private var animateUnlock = false
    @State private var shimmer = false
    
    var color: Color { achievementColor(for: achievement) }
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    // Glow effect for unlocked
                    if achievement.isUnlocked {
                        Circle()
                            .fill(color.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .blur(radius: animateUnlock ? 8 : 4)
                            .scaleEffect(animateUnlock ? 1.2 : 1.0)
                    }
                    
                    Circle()
                        .fill(achievement.isUnlocked ? color.gradient : Color.gray.opacity(0.3).gradient)
                        .frame(width: 60, height: 60)
                        .scaleEffect(animateUnlock ? 1.1 : 1.0)
                    
                    if achievement.isUnlocked {
                        Image(systemName: achievement.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(animateUnlock ? 360 : 0))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    // Shimmer effect
                    if achievement.isUnlocked && shimmer {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 60, height: 60)
                            .mask(Circle().frame(width: 60, height: 60))
                    }
                }
                
                // Title
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(achievement.isUnlocked ? .white : .gray)
                    .lineLimit(1)
                
                // Description
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                // Progress
                if !achievement.isUnlocked {
                    ProgressView(value: achievement.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: color))
                        .frame(height: 4)
                    
                    Text("\(achievement.currentProgress)/\(achievement.requirement)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gbCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(achievement.isUnlocked ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .sheet(isPresented: $showingDetail) {
            AchievementDetailSheet(achievement: achievement)
        }
        .onAppear {
            if achievement.isUnlocked {
                // Entrance animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    animateUnlock = true
                }
                
                // Shimmer after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        shimmer = true
                    }
                    withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                        shimmer = false
                    }
                }
                
                // Reset scale
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring()) {
                        animateUnlock = false
                    }
                }
            }
        }
    }
}

// MARK: - Achievement Detail Sheet
struct AchievementDetailSheet: View {
    let achievement: Achievement
    @Environment(\.dismiss) var dismiss
    
    var color: Color { achievementColor(for: achievement) }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Large Icon
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? color.gradient : Color.gray.opacity(0.3).gradient)
                        .frame(width: 120, height: 120)
                        .shadow(color: achievement.isUnlocked ? color.opacity(0.5) : .clear, radius: 20)
                    
                    if achievement.isUnlocked {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                
                // Title
                Text(achievement.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Category
                Text(achievement.category.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gbCard)
                    .foregroundColor(.gbGreen)
                    .cornerRadius(20)
                
                // Description
                Text(achievement.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Progress or Unlock Date
                if achievement.isUnlocked {
                    if let date = achievement.unlockedDate {
                        VStack(spacing: 4) {
                            Text("Débloqué le")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(date, style: .date)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Progression")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ProgressView(value: achievement.progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: color))
                            .frame(width: 200)
                        
                        Text("\(achievement.currentProgress)/\(achievement.requirement)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gbDark.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gbGreen)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AchievementsView()
            .environmentObject(GameStore())
    }
}
