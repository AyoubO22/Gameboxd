//
//  ContentView.swift
//  Gameboxd
//
//  Root view that switches between Auth and Main app
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingAchievementToast = false
    @State private var toastAchievement: Achievement?
    
    var body: some View {
        ZStack {
            Group {
                if store.isLoggedIn {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .animation(.easeInOut, value: store.isLoggedIn)
            
            // Achievement Toast Overlay
            VStack {
                if showingAchievementToast, let achievement = toastAchievement {
                    AchievementToast(achievement: achievement)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .zIndex(100)
                }
                Spacer()
            }
        }
        .onChange(of: store.recentlyUnlockedAchievements) { _, newAchievements in
            if let achievement = newAchievements.first {
                showAchievementToast(achievement)
            }
        }
    }
    
    func showAchievementToast(_ achievement: Achievement) {
        toastAchievement = achievement
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingAchievementToast = true
        }
        
        // Auto hide after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.spring()) {
                showingAchievementToast = false
                store.recentlyUnlockedAchievements.removeAll()
            }
        }
    }
}

// MARK: - Achievement Toast
struct AchievementToast: View {
    let achievement: Achievement
    @State private var animate = false
    
    var color: Color {
        switch achievement.category {
        case .collection: return .blue
        case .completionist: return .green
        case .dedicated: return .purple
        case .explorer: return .orange
        case .social: return .pink
        case .special: return .yellow
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 50, height: 50)
                    .scaleEffect(animate ? 1.1 : 1.0)
                    .shadow(color: color.opacity(0.5), radius: animate ? 12 : 6)
                
                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("🏆 Succès débloqué!")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gbCard)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStore())
}
