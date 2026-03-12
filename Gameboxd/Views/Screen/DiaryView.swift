//
//  DiaryView.swift
//  Gameboxd
//
//  Game diary for logging play sessions
//

import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingAddSession = false
    @State private var selectedDate = Date()
    @State private var viewMode: DiaryViewMode = .list
    
    enum DiaryViewMode: String, CaseIterable {
        case list = "Liste"
        case calendar = "Calendrier"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Picker
                Picker("Mode", selection: $viewMode) {
                    ForEach(DiaryViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.gbDark)
                
                if viewMode == .list {
                    DiaryListView()
                } else {
                    DiaryCalendarView(selectedDate: $selectedDate)
                }
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSession = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.gbGreen)
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddPlaySessionView()
            }
        }
    }
}

// MARK: - Diary List View
struct DiaryListView: View {
    @EnvironmentObject var store: GameStore
    
    var groupedSessions: [Date: [PlaySession]] {
        Dictionary(grouping: store.playSessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
    }
    
    var sortedDates: [Date] {
        groupedSessions.keys.sorted(by: >)
    }
    
    var body: some View {
        if store.playSessions.isEmpty {
            EmptyDiaryView()
        } else {
            let grouped = groupedSessions
            let dates = grouped.keys.sorted(by: >)
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                    ForEach(dates, id: \.self) { date in
                        Section {
                            ForEach(grouped[date] ?? []) { session in
                                PlaySessionCard(session: session)
                            }
                        } header: {
                            DiaryDateHeader(date: date)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Date Header
struct DiaryDateHeader: View {
    let date: Date
    
    var body: some View {
        HStack {
            Text(date, style: .date)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gbDark)
    }
}

// MARK: - Play Session Card
struct PlaySessionCard: View {
    let session: PlaySession
    @EnvironmentObject var store: GameStore
    @State private var showingSpoiler = false
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    // Game Cover
                    if let coverURL = session.gameCoverURL, let url = URL(string: coverURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(session.gameCoverColor.gradient)
                        }
                        .frame(width: 50, height: 65)
                        .cornerRadius(6)
                    } else {
                        Rectangle()
                            .fill(session.gameCoverColor.gradient)
                            .frame(width: 50, height: 65)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.gameTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            // Duration
                            Label(session.formattedDuration, systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.gbGreen)
                            
                            // Time
                            Text(session.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    
                    // Mood tag
                    if let mood = session.mood {
                        HStack(spacing: 4) {
                            Image(systemName: mood.icon)
                            Text(mood.rawValue)
                        }
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(mood.color.opacity(0.2))
                        .foregroundColor(mood.color)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                // Rating if any
                if let rating = session.rating, rating > 0 {
                    VStack {
                        HStack(spacing: 2) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.gbGreen)
                    }
                }
            }
            
            // Notes
            if !session.notes.isEmpty {
                if session.isSpoiler && !showingSpoiler {
                    Button(action: { showingSpoiler = true }) {
                        HStack {
                            Image(systemName: "eye.slash")
                            Text("Voir le spoiler")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                } else {
                    Text(session.notes)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            PlaySessionDetailView(session: session)
        }
    }
}

// MARK: - Play Session Detail View
struct PlaySessionDetailView: View {
    let session: PlaySession
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    @State private var showingSpoiler = false
    @State private var showingDeleteConfirmation = false
    
    var game: Game? {
        store.myGames.first { $0.id == session.gameId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Game Header
                    HStack(spacing: 16) {
                        if let coverURL = session.gameCoverURL, let url = URL(string: coverURL) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(session.gameCoverColor.gradient)
                            }
                            .frame(width: 80, height: 105)
                            .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(session.gameCoverColor.gradient)
                                .frame(width: 80, height: 105)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "gamecontroller.fill")
                                        .foregroundColor(.white.opacity(0.5))
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.gameTitle)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if let game = game {
                                Text(game.platform)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gbCard)
                    .cornerRadius(12)
                    
                    // Session Info
                    VStack(spacing: 16) {
                        // Date & Time
                        SessionDetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: session.date.formatted(date: .long, time: .shortened)
                        )
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        // Duration
                        SessionDetailRow(
                            icon: "clock.fill",
                            title: "Durée",
                            value: session.formattedDuration
                        )
                        
                        // Mood
                        if let mood = session.mood {
                            Divider().background(Color.gray.opacity(0.3))
                            
                            HStack {
                                Image(systemName: "face.smiling")
                                    .foregroundColor(.gbGreen)
                                    .frame(width: 24)
                                
                                Text("Ressenti")
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    Image(systemName: mood.icon)
                                    Text(mood.rawValue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(mood.color.opacity(0.2))
                                .foregroundColor(mood.color)
                                .cornerRadius(20)
                            }
                        }
                        
                        // Rating
                        if let rating = session.rating, rating > 0 {
                            Divider().background(Color.gray.opacity(0.3))
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.gbGreen)
                                    .frame(width: 24)
                                
                                Text("Note")
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                HStack(spacing: 2) {
                                    ForEach(1...rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                    }
                                    if rating < 5 {
                                    ForEach(rating..<5, id: \.self) { _ in
                                        Image(systemName: "star")
                                            .font(.caption)
                                    }
                                    }
                                }
                                .foregroundColor(.gbGreen)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gbCard)
                    .cornerRadius(12)
                    
                    // Notes Section
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundColor(.gbGreen)
                                Text("Notes")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if session.isSpoiler {
                                    Text("SPOILER")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                            }
                            
                            if session.isSpoiler && !showingSpoiler {
                                Button(action: { showingSpoiler = true }) {
                                    HStack {
                                        Image(systemName: "eye.slash.fill")
                                        Text("Cliquer pour révéler le contenu")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                                }
                            } else {
                                Text(session.notes)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .padding()
                        .background(Color.gbCard)
                        .cornerRadius(12)
                    }
                    
                    // Delete Button
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Supprimer cette session")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Détails de la session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gbGreen)
                }
            }
            .alert("Supprimer cette session ?", isPresented: $showingDeleteConfirmation) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    store.deletePlaySession(session)
                    dismiss()
                }
            }
        }
    }
}

struct SessionDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gbGreen)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Calendar View
struct DiaryCalendarView: View {
    @EnvironmentObject var store: GameStore
    @Binding var selectedDate: Date
    @State private var currentMonth = Date()
    
    var sessionsForSelectedDate: [PlaySession] {
        store.sessionsForDate(selectedDate)
    }
    
    // Get all dates that have sessions
    var datesWithSessions: Set<Date> {
        let calendar = Calendar.current
        return Set(store.playSessions.map { calendar.startOfDay(for: $0.date) })
    }
    
    var body: some View {
        let sessionDates = datesWithSessions
        let selectedSessions = sessionsForSelectedDate
        ScrollView {
            VStack(spacing: 16) {
                // Custom Calendar with dots
                CustomCalendarView(
                    selectedDate: $selectedDate,
                    currentMonth: $currentMonth,
                    datesWithSessions: sessionDates
                )
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
                .padding(.horizontal)

                // Sessions for selected date
                if selectedSessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Aucune session ce jour")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(height: 150)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(selectedSessions.count) session(s)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        LazyVStack(spacing: 12) {
                            ForEach(selectedSessions) { session in
                                PlaySessionCard(session: session)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
    }
}

// MARK: - Custom Calendar with Dots
struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let datesWithSessions: Set<Date>
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
    
    var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }
    
    var daysInMonth: [Date?] {
        var days: [Date?] = []
        
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        // Get weekday of first day (1 = Sunday in US, adjust for Monday start)
        var weekday = calendar.component(.weekday, from: firstDay)
        weekday = weekday == 1 ? 7 : weekday - 1 // Convert to Monday = 1
        
        // Add empty days for padding
        for _ in 1..<weekday {
            days.append(nil)
        }
        
        // Add all days of the month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month Navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.gbGreen)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text(monthTitle.capitalized)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.gbGreen)
                        .frame(width: 44, height: 44)
                }
            }
            
            // Days of Week Header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasSession: datesWithSessions.contains(calendar.startOfDay(for: date))
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }
    
    func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasSession: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Selection/Today background
                    if isSelected {
                        Circle()
                            .fill(Color.gbGreen)
                            .frame(width: 36, height: 36)
                    } else if isToday {
                        Circle()
                            .stroke(Color.gbGreen, lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }
                    
                    Text(dayNumber)
                        .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                        .foregroundColor(isSelected ? .gbDark : (isToday ? .gbGreen : .white))
                }
                
                // Green dot indicator for sessions
                Circle()
                    .fill(hasSession ? Color.gbGreen : Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Empty Diary View
struct EmptyDiaryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("Ton journal est vide")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Enregistre tes sessions de jeu\npour garder une trace de tes aventures")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
}

// MARK: - Add Play Session View
struct AddPlaySessionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    var preselectedGame: Game? = nil
    
    @State private var selectedGame: Game?
    @State private var date = Date()
    @State private var hours = 0
    @State private var minutes = 30
    @State private var notes = ""
    @State private var isSpoiler = false
    @State private var rating: Int = 0
    @State private var mood: MoodTag?
    @State private var showingGamePicker = false
    
    var canSave: Bool {
        selectedGame != nil && (hours > 0 || minutes > 0)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Game Selection
                Section("Jeu") {
                    if let game = selectedGame {
                        HStack {
                            if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                                CachedAsyncImage(url: url) { image in
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
                            
                            Text(game.title)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("Changer") {
                                showingGamePicker = true
                            }
                            .foregroundColor(.gbGreen)
                        }
                    } else {
                        Button(action: { showingGamePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Sélectionner un jeu")
                            }
                            .foregroundColor(.gbGreen)
                        }
                    }
                }
                
                // Date & Time
                Section("Date") {
                    DatePicker("Date et heure", selection: $date)
                        .tint(.gbGreen)
                }
                
                // Duration
                Section("Durée de la session") {
                    HStack {
                        Picker("Heures", selection: $hours) {
                            ForEach(0..<24, id: \.self) { h in
                                Text("\(h)h").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        
                        Picker("Minutes", selection: $minutes) {
                            ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                                Text("\(m)m").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 120)
                }
                
                // Mood
                Section("Ressenti") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MoodTag.allCases, id: \.self) { tag in
                                Button(action: { 
                                    mood = mood == tag ? nil : tag 
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: tag.icon)
                                            .font(.title3)
                                        Text(tag.rawValue)
                                            .font(.caption2)
                                    }
                                    .frame(width: 70, height: 55)
                                    .background(mood == tag ? tag.color.opacity(0.3) : Color.gbCard)
                                    .foregroundColor(mood == tag ? tag.color : .gray)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Rating
                Section("Note (optionnel)") {
                    HStack {
                        Spacer()
                        StarRating(rating: $rating, editable: true, size: 30)
                        Spacer()
                    }
                    .listRowBackground(Color.gbCard)
                }
                
                // Notes
                Section("Notes") {
                    TextField("Qu'as-tu fait pendant cette session ?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Toggle(isOn: $isSpoiler) {
                        Label("Contient des spoilers", systemImage: "eye.slash")
                    }
                    .tint(.orange)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Nouvelle session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.gray)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        saveSession()
                    }
                    .disabled(!canSave)
                    .foregroundColor(canSave ? .gbGreen : .gray)
                }
            }
            .sheet(isPresented: $showingGamePicker) {
                GamePickerView(selectedGame: $selectedGame)
            }
            .onAppear {
                if selectedGame == nil, let preselected = preselectedGame {
                    selectedGame = preselected
                }
            }
        }
    }
    
    private func saveSession() {
        guard let game = selectedGame else { return }
        
        let duration = hours * 60 + minutes
        let session = PlaySession(
            gameId: game.id,
            gameTitle: game.title,
            gameCoverURL: game.coverImageURL,
            gameCoverColor: game.coverColor,
            date: date,
            duration: duration,
            rating: rating > 0 ? rating : nil,
            notes: notes,
            isSpoiler: isSpoiler,
            mood: mood
        )
        
        store.addPlaySession(session)
        dismiss()
    }
}

// MARK: - Game Picker View
struct GamePickerView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    @Binding var selectedGame: Game?
    @State private var searchText = ""
    
    var filteredGames: [Game] {
        if searchText.isEmpty {
            return store.myGames
        }
        return store.myGames.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredGames) { game in
                Button(action: {
                    selectedGame = game
                    dismiss()
                }) {
                    HStack {
                        if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                            CachedAsyncImage(url: url) { image in
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
                        
                        if selectedGame?.id == game.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.gbGreen)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .searchable(text: $searchText, prompt: "Chercher dans ta collection")
            .navigationTitle("Choisir un jeu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DiaryView()
        .environmentObject(GameStore())
}
