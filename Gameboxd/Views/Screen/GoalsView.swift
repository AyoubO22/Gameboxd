//
//  GoalsView.swift
//  Gameboxd
//
//  Monthly gaming goals with progress tracking
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingAddGoal = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Month Header
                    MonthHeaderView()
                    
                    // Active Goals
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Objectifs actifs")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: { showingAddGoal = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.gbGreen)
                            }
                        }
                        .padding(.horizontal)
                        
                        if store.monthlyGoals.isEmpty {
                            EmptyGoalsView(onAdd: { showingAddGoal = true })
                        } else {
                            ForEach(store.monthlyGoals) { goal in
                                GoalCard(goal: goal)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Suggested Goals
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Suggestions")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(GoalSuggestions.all, id: \.title) { suggestion in
                            SuggestedGoalCard(suggestion: suggestion) {
                                addGoal(from: suggestion)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Past Goals Summary
                    if !store.completedGoals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Objectifs accomplis")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(store.completedGoals.prefix(5)) { goal in
                                        CompletedGoalBadge(goal: goal)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Objectifs")
            .sheet(isPresented: $showingAddGoal) {
                AddGoalSheet()
            }
        }
    }
    
    func addGoal(from suggestion: GoalSuggestion) {
        let goal = MonthlyGoal(
            title: suggestion.title,
            description: suggestion.description,
            icon: suggestion.icon,
            type: suggestion.type,
            target: suggestion.defaultTarget,
            current: 0
        )
        store.addMonthlyGoal(goal)
    }
}

// MARK: - Month Header
struct MonthHeaderView: View {
    var monthName: String {
        Date().formatted(.dateTime.month(.wide).year())
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(monthName.capitalized)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Fixe-toi des objectifs et suis ta progression")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gbCard)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Goal Card
struct GoalCard: View {
    let goal: MonthlyGoal
    @EnvironmentObject var store: GameStore
    
    var progress: Double {
        guard goal.target > 0 else { return 0 }
        return min(Double(goal.current) / Double(goal.target), 1.0)
    }
    
    var isCompleted: Bool {
        goal.current >= goal.target
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.gbGreen : Color.gbGreen.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isCompleted ? "checkmark" : goal.icon)
                        .font(.title3)
                        .foregroundColor(isCompleted ? .gbDark : .gbGreen)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(goal.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Progress Text
                Text("\(goal.current)/\(goal.target)")
                    .font(.headline)
                    .foregroundColor(isCompleted ? .gbGreen : .white)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gbDark)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCompleted ? Color.gbGreen : Color.gbGreen.gradient)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 8)
            
            // Days Remaining
            if !isCompleted {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("\(daysRemainingInMonth()) jours restants")
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Color.gbGreen : Color.clear, lineWidth: 2)
        )
    }
    
    func daysRemainingInMonth() -> Int {
        let calendar = Calendar.current
        let today = Date()
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let lastDay = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: today),
                month: calendar.component(.month, from: today),
                day: range.count
              )) else { return 0 }
        
        return calendar.dateComponents([.day], from: today, to: lastDay).day ?? 0
    }
}

// MARK: - Empty Goals View
struct EmptyGoalsView: View {
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Aucun objectif défini")
                .font(.headline)
                .foregroundColor(.gray)
            
            Button(action: onAdd) {
                Text("Ajouter un objectif")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.gbGreen)
                    .foregroundColor(.gbDark)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.gbCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Suggested Goal Card
struct SuggestedGoalCard: View {
    let suggestion: GoalSuggestion
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.icon)
                .font(.title2)
                .foregroundColor(.gbGreen)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gbGreen)
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Completed Goal Badge
struct CompletedGoalBadge: View {
    let goal: MonthlyGoal
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.gbGreen.gradient)
                    .frame(width: 50, height: 50)
                
                Image(systemName: goal.icon)
                    .foregroundColor(.gbDark)
            }
            
            Text(goal.title)
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
            
            if let date = goal.completedDate {
                Text(date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 80)
    }
}

// MARK: - Add Goal Sheet
struct AddGoalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: GameStore
    
    @State private var title = ""
    @State private var selectedType: GoalType = .gamesCompleted
    @State private var target = 3
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Type d'objectif") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(GoalType.allCases, id: \.self) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section("Objectif") {
                    Stepper("\(target) \(selectedType.unit)", value: $target, in: 1...100)
                }
                
                Section("Titre personnalisé (optionnel)") {
                    TextField("Ex: Finir ma série", text: $title)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Nouvel objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ajouter") {
                        addGoal()
                        dismiss()
                    }
                    .foregroundColor(.gbGreen)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    func addGoal() {
        let goalTitle = title.isEmpty ? selectedType.title : title
        let goal = MonthlyGoal(
            title: goalTitle,
            description: selectedType.description,
            icon: selectedType.icon,
            type: selectedType,
            target: target,
            current: 0
        )
        store.addMonthlyGoal(goal)
    }
}

// MARK: - Preview
#Preview {
    GoalsView()
        .environmentObject(GameStore())
}
