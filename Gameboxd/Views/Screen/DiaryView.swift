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
                PillSegmentedControl(options: DiaryViewMode.allCases, selection: $viewMode) { $0.rawValue }
                    .padding()
                    .background(Color.gbDark)

                if viewMode == .list {
                    DiaryListView(showingAddSession: $showingAddSession)
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
                            .foregroundStyle(Color.accent)
                    }
                    .accessibilityLabel("Ajouter une session")
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
    @Binding var showingAddSession: Bool

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
            EmptyDiaryView(action: { showingAddSession = true })
        } else {
            let grouped = groupedSessions
            let dates = grouped.keys.sorted(by: >)
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                    ForEach(dates, id: \.self) { date in
                        Section {
                            ForEach(grouped[date, default: []]) { session in
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
                .font(DS.Typography.headline)
                .foregroundStyle(Color.textPrimary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
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
                    Group {
                        if let coverURL = session.gameCoverURL, let url = URL(string: coverURL) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(session.gameCoverColor.gradient)
                            }
                        } else {
                            Rectangle().fill(session.gameCoverColor.gradient)
                        }
                    }
                    .frame(width: 44, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(Color.gbBorder, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.gameTitle)
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            // Duration
                            Label(session.formattedDuration, systemImage: "clock")
                                .font(DS.Typography.label)
                                .foregroundStyle(Color.accent)

                            // Time
                            Text(session.date, style: .time)
                                .font(DS.Typography.label)
                                .foregroundStyle(Color.textTertiary)
                        }

                    // Mood tag
                    if let mood = session.mood {
                        TagPill(label: mood.rawValue, icon: mood.icon, isSelected: true, tint: mood.color)
                    }
                }

                Spacer()

                // Rating if any
                if let rating = session.rating, rating > 0 {
                    VStack {
                        HStack(spacing: 2) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(DS.Typography.micro)
                            }
                        }
                        .foregroundStyle(Color.accent)
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
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(hex: "E3A24C"))
                    }
                } else {
                    Text(session.notes)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .cardStyle()
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
                        Group {
                            if let coverURL = session.gameCoverURL, let url = URL(string: coverURL) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(session.gameCoverColor.gradient)
                                }
                            } else {
                                Rectangle()
                                    .fill(session.gameCoverColor.gradient)
                                    .overlay(
                                        Image(systemName: "gamecontroller.fill")
                                            .foregroundStyle(Color.textTertiary)
                                    )
                            }
                        }
                        .frame(width: 80, height: 105)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(Color.gbBorder, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.gameTitle)
                                .font(DS.Typography.title)
                                .foregroundStyle(Color.textPrimary)

                            if let game = game {
                                Text(game.platform)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }

                        Spacer()
                    }
                    .cardStyle()

                    // Session Info
                    VStack(spacing: 16) {
                        // Date & Time
                        SessionDetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: session.date.formatted(date: .long, time: .shortened)
                        )

                        Divider().overlay(Color.gbBorder)

                        // Duration
                        SessionDetailRow(
                            icon: "clock.fill",
                            title: "Durée",
                            value: session.formattedDuration
                        )

                        // Mood
                        if let mood = session.mood {
                            Divider().overlay(Color.gbBorder)

                            HStack {
                                Image(systemName: "face.smiling")
                                    .foregroundStyle(Color.accent)
                                    .frame(width: 24)

                                Text("Ressenti")
                                    .foregroundStyle(Color.textSecondary)

                                Spacer()

                                TagPill(label: mood.rawValue, icon: mood.icon, isSelected: true, tint: mood.color)
                            }
                        }

                        // Rating
                        if let rating = session.rating, rating > 0 {
                            Divider().overlay(Color.gbBorder)

                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color.accent)
                                    .frame(width: 24)

                                Text("Note")
                                    .foregroundStyle(Color.textSecondary)

                                Spacer()

                                HStack(spacing: 2) {
                                    ForEach(1...rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(DS.Typography.caption)
                                    }
                                    if rating < 5 {
                                    ForEach(rating..<5, id: \.self) { _ in
                                        Image(systemName: "star")
                                            .font(DS.Typography.caption)
                                    }
                                    }
                                }
                                .foregroundStyle(Color.accent)
                            }
                        }
                    }
                    .cardStyle()

                    // Notes Section
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "note.text")
                                    .foregroundStyle(Color.accent)
                                Text("Notes")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.textPrimary)

                                if session.isSpoiler {
                                    Text("SPOILER")
                                        .font(DS.Typography.label)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "E3A24C"))
                                        .foregroundStyle(Color.gbDark)
                                        .clipShape(Capsule())
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
                                    .background(Color(hex: "E3A24C").opacity(0.16))
                                    .foregroundStyle(Color(hex: "E3A24C"))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                }
                            } else {
                                Text(session.notes)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                        .cardStyle()
                    }

                    // Delete Button
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Supprimer cette session")
                        }
                        .font(DS.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(Color(hex: "D9695A"))
                        .contentShape(Rectangle())
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
                        .foregroundStyle(Color.accent)
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
                .foregroundStyle(Color.accent)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(Color.textSecondary)

            Spacer()

            Text(value)
                .foregroundStyle(Color.textPrimary)
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
                .cardStyle()
                .padding(.horizontal)

                // Sessions for selected date
                if selectedSessions.isEmpty {
                    EmptyState(icon: "calendar.badge.exclamationmark", title: "Aucune session ce jour")
                        .frame(height: 150)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(selectedSessions.count) session(s)")
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.textPrimary)
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .frame(width: 32, height: 32)
                        .background(Color.gbSurface2)
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Mois précédent")

                Spacer()

                Text(monthTitle.capitalized)
                    .font(DS.Typography.title)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .frame(width: 32, height: 32)
                        .background(Color.gbSurface2)
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Mois suivant")
            }

            // Days of Week Header
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.textTertiary)
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
                    // Selection/Today/session background
                    if isSelected {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(Color.accent)
                            .frame(width: 34, height: 34)
                    } else if hasSession {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(Color.gbSurface2)
                            .frame(width: 34, height: 34)
                    }
                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(Color.accent, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    Text(dayNumber)
                        .font(DS.Typography.text(16, weight: isSelected || isToday ? .bold : .regular).monospacedDigit())
                        .foregroundStyle(isSelected ? Color.gbDark : (isToday ? Color.accent : Color.textPrimary))
                }

                // Dot indicator for sessions
                Circle()
                    .fill(hasSession ? Color.accent : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Empty Diary View
struct EmptyDiaryView: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            EmptyState(
                icon: "book.closed",
                title: "Ton journal est vide",
                message: "Enregistre tes sessions de jeu pour garder une trace de tes aventures"
            )
            .frame(height: 180)

            PrimaryButton(title: "Ajouter une session", icon: "plus.circle.fill", action: action)
                .padding(.horizontal, 60)

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
                            Group {
                                if let url = game.artURL {
                                    CachedAsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(game.coverColor.gradient)
                                    }
                                } else {
                                    Rectangle().fill(game.coverColor.gradient)
                                }
                            }
                            .frame(width: 40, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                            Text(game.title)
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Button("Changer") {
                                showingGamePicker = true
                            }
                            .foregroundStyle(Color.accent)
                        }
                    } else {
                        Button(action: { showingGamePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Sélectionner un jeu")
                            }
                            .foregroundStyle(Color.accent)
                        }
                    }
                }

                // Date & Time
                Section("Date") {
                    DatePicker("Date et heure", selection: $date)
                        .tint(.accent)
                }
                
                // Duration
                Section("Durée de la session") {
                    HStack {
                        Picker("Heures", selection: $hours) {
                            ForEach(Array(0..<24), id: \.self) { h in
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
                                            .font(DS.Typography.title3)
                                        Text(tag.rawValue)
                                            .font(DS.Typography.micro)
                                    }
                                    .frame(width: 70, height: 55)
                                    .background(mood == tag ? tag.color.opacity(0.16) : Color.gbSurface2)
                                    .foregroundStyle(mood == tag ? tag.color : Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                            .stroke(mood == tag ? tag.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
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
                    .tint(Color(hex: "E3A24C"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Nouvelle session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        saveSession()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? Color.accent : Color.textTertiary)
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
            gameCoverURL: game.artURL?.absoluteString,
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
                        Group {
                            if let url = game.artURL {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(game.coverColor.gradient)
                                }
                            } else {
                                Rectangle().fill(game.coverColor.gradient)
                            }
                        }
                        .frame(width: 40, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                        VStack(alignment: .leading) {
                            Text(game.title)
                                .foregroundStyle(Color.textPrimary)
                            Text(game.platform)
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        if selectedGame?.id == game.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accent)
                        }
                    }
                }
                .listRowBackground(Color.gbCard)
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
                        .foregroundStyle(Color.textSecondary)
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
