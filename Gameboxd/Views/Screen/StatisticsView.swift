//
//  StatisticsView.swift
//  Gameboxd
//
//  Detailed statistics with charts
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedPeriod: StatPeriod = .year
    @State private var selectedChart: ChartType = .gamesPerMonth
    
    enum StatPeriod: String, CaseIterable {
        case month = "Mois"
        case year = "Année"
        case allTime = "Tout"
    }
    
    enum ChartType: String, CaseIterable {
        case gamesPerMonth = "Par mois"
        case byGenre = "Par genre"
        case byPlatform = "Par plateforme"
        case byRating = "Par note"
        case byStatus = "Par statut"
    }
    
    var filteredGames: [Game] {
        let now = Date()
        let calendar = Calendar.current
        switch selectedPeriod {
        case .month:
            return store.myGames.filter {
                guard let date = $0.startedDate else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
        case .year:
            return store.myGames.filter {
                guard let date = $0.startedDate else { return false }
                return calendar.component(.year, from: date) == calendar.component(.year, from: now)
            }
        case .allTime:
            return store.myGames
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period Selector
                Picker("Période", selection: $selectedPeriod) {
                    ForEach(StatPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Summary Cards
                SummaryCardsView(games: filteredGames)
                
                // Chart Type Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            ChartTypeButton(type: type, selected: $selectedChart)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Main Chart
                ChartContainer(chartType: selectedChart, period: selectedPeriod, games: filteredGames)
                
                // Additional Stats
                AdditionalStatsView(games: filteredGames)
                
                // Gaming Habits
                GamingHabitsView()
            }
            .padding(.vertical)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Summary Cards
struct SummaryCardsView: View {
    let games: [Game]
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(
                title: "Total jeux",
                value: "\(games.count)",
                icon: "gamecontroller.fill",
                color: .blue
            )
            
            SummaryCard(
                title: "Terminés",
                value: "\(games.filter { $0.status == .completed || $0.status == .platinum }.count)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            SummaryCard(
                title: "Heures jouées",
                value: {
                    let totalMin = games.reduce(0) { $0 + $1.playTimeMinutes }
                    let h = totalMin / 60
                    return h > 0 ? "\(h)h" : "0h"
                }(),
                icon: "clock.fill",
                color: .orange
            )
            
            SummaryCard(
                title: "Note moyenne",
                value: {
                    let rated = games.filter { $0.rating > 0 }
                    guard !rated.isEmpty else { return "—" }
                    let avg = Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count)
                    return String(format: "%.1f", avg)
                }(),
                icon: "star.fill",
                color: .yellow
            )
        }
        .padding(.horizontal)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Chart Type Button
struct ChartTypeButton: View {
    let type: StatisticsView.ChartType
    @Binding var selected: StatisticsView.ChartType
    
    var body: some View {
        Button(action: { selected = type }) {
            Text(type.rawValue)
                .font(.subheadline)
                .fontWeight(selected == type ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected == type ? Color.gbGreen : Color.gbCard)
                .foregroundColor(selected == type ? .gbDark : .gray)
                .cornerRadius(20)
        }
    }
}

// MARK: - Chart Container
struct ChartContainer: View {
    let chartType: StatisticsView.ChartType
    let period: StatisticsView.StatPeriod
    let games: [Game]
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chartTitle)
                .font(.headline)
                .foregroundColor(.white)
            
            if games.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Pas encore de données pour cette période")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            } else {
            switch chartType {
            case .gamesPerMonth:
                GamesPerMonthChart(games: games)
            case .byGenre:
                GenreChart(games: games)
            case .byPlatform:
                PlatformChart(games: games)
            case .byRating:
                RatingChart(games: games)
            case .byStatus:
                StatusChart(games: games)
            }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    var chartTitle: String {
        switch chartType {
        case .gamesPerMonth: return "Jeux ajoutés par mois"
        case .byGenre: return "Répartition par genre"
        case .byPlatform: return "Répartition par plateforme"
        case .byRating: return "Distribution des notes"
        case .byStatus: return "Statut des jeux"
        }
    }
}

// MARK: - Games Per Month Chart
struct GamesPerMonthChart: View {
    let games: [Game]
    
    var monthlyData: [(month: String, count: Int)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        var data: [String: Int] = [:]
        
        // Get last 6 months
        for i in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -i, to: Date()) {
                let monthName = dateFormatter.string(from: date)
                data[monthName] = 0
            }
        }
        
        // Count games per month based on startedDate
        for game in games {
            if let startedDate = game.startedDate {
                let monthName = dateFormatter.string(from: startedDate)
                if data[monthName] != nil {
                    data[monthName]! += 1
                }
            }
        }
        
        // Convert to array and sort
        return data.map { (month: $0.key, count: $0.value) }
            .sorted { 
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                let date1 = formatter.date(from: $0.month) ?? Date()
                let date2 = formatter.date(from: $1.month) ?? Date()
                return date1 < date2
            }
    }
    
    var body: some View {
        Chart(monthlyData, id: \.month) { item in
            BarMark(
                x: .value("Mois", item.month),
                y: .value("Jeux", item.count)
            )
            .foregroundStyle(Color.gbGreen.gradient)
            .cornerRadius(4)
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.gray)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.gray)
            }
        }
    }
}

// MARK: - Genre Chart
struct GenreChart: View {
    let games: [Game]
    
    var genreData: [(genre: String, count: Int)] {
        var data: [String: Int] = [:]
        
        for game in games {
            for genre in game.genres {
                data[genre, default: 0] += 1
            }
        }
        
        return data.map { (genre: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(8)
            .map { $0 }
    }
    
    var body: some View {
        Chart(genreData, id: \.genre) { item in
            SectorMark(
                angle: .value("Count", item.count),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(by: .value("Genre", item.genre))
            .cornerRadius(4)
        }
        .frame(height: 200)
        .chartLegend(position: .bottom, spacing: 10)
    }
}

// MARK: - Platform Chart
struct PlatformChart: View {
    let games: [Game]
    
    var platformData: [(platform: String, count: Int)] {
        var data: [String: Int] = [:]
        
        for game in games {
            let platform = simplifyPlatform(game.platform)
            data[platform, default: 0] += 1
        }
        
        return data.map { (platform: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    func simplifyPlatform(_ platform: String) -> String {
        if platform.contains("PlayStation") { return "PlayStation" }
        if platform.contains("Xbox") { return "Xbox" }
        if platform.contains("Nintendo") || platform.contains("Switch") { return "Nintendo" }
        if platform.contains("PC") || platform.contains("Windows") { return "PC" }
        if platform.contains("iOS") || platform.contains("Android") { return "Mobile" }
        return platform
    }
    
    var body: some View {
        Chart(platformData, id: \.platform) { item in
            BarMark(
                x: .value("Jeux", item.count),
                y: .value("Plateforme", item.platform)
            )
            .foregroundStyle(platformColor(item.platform).gradient)
            .cornerRadius(4)
        }
        .frame(height: CGFloat(max(platformData.count * 40, 150)))
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.gray)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.white)
            }
        }
    }
    
    func platformColor(_ platform: String) -> Color {
        switch platform {
        case "PlayStation": return .blue
        case "Xbox": return .green
        case "Nintendo": return .red
        case "PC": return .purple
        case "Mobile": return .orange
        default: return .gray
        }
    }
}

// MARK: - Rating Chart
struct RatingChart: View {
    let games: [Game]
    
    var ratingData: [(rating: Int, count: Int)] {
        var data: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        
        for game in games where game.rating > 0 {
            data[game.rating, default: 0] += 1
        }
        
        return data.map { (rating: $0.key, count: $0.value) }
            .sorted { $0.rating < $1.rating }
    }
    
    var body: some View {
        Chart(ratingData, id: \.rating) { item in
            BarMark(
                x: .value("Note", "⭐ \(item.rating)"),
                y: .value("Jeux", item.count)
            )
            .foregroundStyle(ratingColor(item.rating).gradient)
            .cornerRadius(4)
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.white)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel()
                    .foregroundStyle(Color.gray)
            }
        }
    }
    
    func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .gbGreen
        default: return .gray
        }
    }
}

// MARK: - Status Chart
struct StatusChart: View {
    let games: [Game]
    
    var statusData: [(status: String, count: Int, color: Color)] {
        var data: [(status: String, count: Int, color: Color)] = []
        
        for status in GameStatus.allCases where status != .none {
            let count = games.filter { $0.status == status }.count
            if count > 0 {
                data.append((status: status.rawValue, count: count, color: status.color))
            }
        }
        
        return data.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        Chart(statusData, id: \.status) { item in
            SectorMark(
                angle: .value("Count", item.count),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(item.color)
            .cornerRadius(4)
            .annotation(position: .overlay) {
                Text("\(item.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 200)
        .chartLegend(position: .bottom, spacing: 10)
    }
}

// MARK: - Additional Stats
struct AdditionalStatsView: View {
    let games: [Game]
    @EnvironmentObject var store: GameStore
    
    var completionRate: Double {
        guard !games.isEmpty else { return 0 }
        let completed = games.filter { $0.status == .completed || $0.status == .platinum }.count
        return Double(completed) / Double(games.count) * 100
    }
    
    var averagePlaytime: String {
        let totalMinutes = games.reduce(0) { $0 + $1.playTimeMinutes }
        guard !games.isEmpty else { return "0h" }
        let avgMinutes = totalMinutes / games.count
        let hours = avgMinutes / 60
        let mins = avgMinutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h\(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📈 Statistiques détaillées")
                .font(.headline)
                .foregroundColor(.white)
            
            StatRow(label: "Taux de complétion", value: String(format: "%.0f%%", completionRate))
            StatRow(label: "Temps moyen par jeu", value: averagePlaytime)
            StatRow(label: "Sessions enregistrées", value: "\(store.playSessions.count)")
            StatRow(label: "Listes créées", value: "\(store.gameLists.count)")
            StatRow(label: "Jeux favoris", value: "\(store.favoriteGames().count)")
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Gaming Habits
struct GamingHabitsView: View {
    @EnvironmentObject var store: GameStore
    
    var mostPlayedGenre: String {
        var genreCount: [String: Int] = [:]
        for game in store.myGames {
            for genre in game.genres {
                genreCount[genre, default: 0] += 1
            }
        }
        return genreCount.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
    
    var favoritePlatform: String {
        var platformCount: [String: Int] = [:]
        for game in store.myGames {
            platformCount[game.platform, default: 0] += 1
        }
        return platformCount.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎮 Tes habitudes")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                HabitCard(icon: "star.fill", title: "Genre préféré", value: mostPlayedGenre, color: .purple)
                HabitCard(icon: "display", title: "Plateforme", value: favoritePlatform, color: .blue)
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct HabitCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gbDark)
        .cornerRadius(10)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        StatisticsView()
            .environmentObject(GameStore())
    }
}
