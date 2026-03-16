//
//  OnboardingView.swift
//  Gameboxd
//
//  First-time user onboarding experience
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: GameStore
    @State private var currentPage = 0
    @Binding var hasCompletedOnboarding: Bool
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Bienvenue sur Gameboxd",
            subtitle: "Ton journal de jeux vidéo personnel",
            icon: "gamecontroller.fill",
            color: .gbGreen,
            features: [
                "📚 Catalogue ta collection",
                "📝 Note et critique tes jeux",
                "📊 Suis tes statistiques"
            ]
        ),
        OnboardingPage(
            title: "Ta bibliothèque",
            subtitle: "Organise tes jeux comme tu veux",
            icon: "square.stack.3d.up.fill",
            color: .blue,
            features: [
                "🎮 En cours, terminé, à jouer...",
                "⭐ Note de 1 à 5 étoiles",
                "🏷️ Tags personnalisés"
            ]
        ),
        OnboardingPage(
            title: "Journal de jeu",
            subtitle: "Garde une trace de tes sessions",
            icon: "book.fill",
            color: .purple,
            features: [
                "⏱️ Temps de jeu par session",
                "📅 Calendrier interactif",
                "😊 Ton ressenti du moment"
            ]
        ),
        OnboardingPage(
            title: "Découvre & Partage",
            subtitle: "Explore de nouveaux jeux",
            icon: "magnifyingglass",
            color: .orange,
            features: [
                "🔥 Jeux tendances",
                "🆕 Nouvelles sorties",
                "🏆 Les mieux notés"
            ]
        ),
        OnboardingPage(
            title: "Prêt à jouer ?",
            subtitle: "Commence ton aventure",
            icon: "rocket.fill",
            color: .gbGreen,
            features: []
        )
    ]
    
    var body: some View {
        ZStack {
            Color.gbDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip Button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Passer") {
                            completeOnboarding()
                        }
                        .foregroundColor(.gray)
                        .padding()
                    }
                }
                
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.indices), id: \.self) { index in
                        OnboardingPageView(page: pages[index], isLastPage: index == pages.count - 1)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page Indicator & Button
                VStack(spacing: 24) {
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(Array(pages.indices), id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.gbGreen : Color.gray.opacity(0.3))
                                .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    
                    // Button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Suivant" : "Commencer")
                                .fontWeight(.semibold)
                            
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "play.fill")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gbGreen.gradient)
                        .foregroundColor(.gbDark)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let features: [String]
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isLastPage: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.gradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: page.color.opacity(0.5), radius: 20)
                
                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .scaleEffect(isLastPage ? 1.2 : 1.0)
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(page.subtitle)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            // Features
            if !page.features.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(page.features, id: \.self) { feature in
                        HStack(spacing: 12) {
                            Text(feature)
                                .font(.body)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(16)
                .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(GameStore())
}
