//
//  StarRating.swift
//  Gameboxd
//
//  Created by Ayoub Ouaadoud on 01/12/2025.
//

import SwiftUI
import Foundation

struct StarRating: View {
    @Binding var rating: Int
    var maxRating = 5
    var editable: Bool = false
    var size: CGFloat = 20
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundColor(star <= rating ? .gbGreen : .gray)
                    .scaleEffect(star <= rating ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: rating)
                    .onTapGesture {
                        if editable {
                            // Petit retour haptique (vibration)
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                // Permet de désélectionner en retappant la même étoile
                                rating = (rating == star) ? star - 1 : star
                            }
                        }
                    }
                    .accessibilityLabel("\(star) étoile\(star > 1 ? "s" : "")")
                    .accessibilityAddTraits(editable ? .isButton : [])
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(rating) sur \(maxRating)")
        .accessibilityAdjustableAction { direction in
            guard editable else { return }
            switch direction {
            case .increment:
                if rating < maxRating { rating += 1 }
            case .decrement:
                if rating > 0 { rating -= 1 }
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        StarRating(rating: .constant(3), editable: false)
        StarRating(rating: .constant(5), editable: true, size: 30)
        StarRating(rating: .constant(0), editable: true, size: 25)
    }
    .padding()
    .background(Color.gbDark)
}

