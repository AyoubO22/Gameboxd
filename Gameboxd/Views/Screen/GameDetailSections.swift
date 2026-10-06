//
//  GameDetailSections.swift
//  Gameboxd
//
//  The sections of a game's page, top to bottom in the order you need them:
//  your game (status, rating, progress), your review, about the game,
//  screenshots, your journal for it, the finer details, similar games.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Section title

struct DetailSectionTitle: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.Typography.title3)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

// MARK: - Your game

/// Status, rating and progress: what you change most, first on the page.
/// For a game you don't own yet, the status row adds it with that status in one tap.
struct YourGameSection: View {
    @Binding var game: Game
    let isInLibrary: Bool
    let onAdd: (GameStatus) -> Void
    let onAddSession: () -> Void
    @Environment(TimerManager.self) private var timerManager

    private var isTimingThisGame: Bool {
        timerManager.isRunning && timerManager.activeGame?.id == game.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DetailSectionTitle(title: isInLibrary ? "Ta partie" : "Où le ranges-tu ?")

            StatusStrip(selection: isInLibrary ? game.status : nil) { status in
                if isInLibrary {
                    withAnimation(.snappy) {
                        game.status = status
                        if status == .platinum { game.completionPercentage = 100 }
                    }
                } else {
                    onAdd(status)
                }
            }

            if isInLibrary {
                VStack(spacing: DS.Spacing.md) {
                    // Rating
                    HStack {
                        StarRating(rating: $game.rating, editable: true, size: 30)
                            .sensoryFeedback(.selection, trigger: game.rating)
                        Spacer()
                        Text(ratingLabel)
                            .font(DS.Typography.bodyMedium)
                            .foregroundStyle(game.rating > 0 ? Color.accent : Color.textTertiary)
                            .contentTransition(.opacity)
                            .animation(.easeOut(duration: 0.15), value: game.rating)
                    }

                    Divider().overlay(Color.gbBorder)

                    // Progress
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(game.completionPercentage) %")
                                .font(DS.Typography.display(28, relativeTo: .title2))
                                .foregroundStyle(Color.textPrimary)
                                .contentTransition(.numericText())
                            Text("terminé")
                                .font(DS.Typography.body)
                                .foregroundStyle(Color.textSecondary)
                            Spacer()
                            Text(game.playTimeMinutes > 0 ? "\(game.formattedPlayTime) jouées" : "Pas encore joué")
                                .font(DS.Typography.body)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Slider(value: Binding(
                            get: { Double(game.completionPercentage) },
                            set: { game.completionPercentage = Int($0) }
                        ), in: 0...100, step: 5)
                        .tint(Color.accent)
                        .sensoryFeedback(.selection, trigger: game.completionPercentage)
                        .accessibilityLabel("Progression")
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        Button {
                            timerManager.start(game: game)
                            HapticManager.notification(.success)
                        } label: {
                            Label(isTimingThisGame ? "Chrono en cours" : "Lancer le chrono",
                                  systemImage: isTimingThisGame ? "timer.circle.fill" : "timer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ShelfButtonStyle(prominent: true))
                        .disabled(timerManager.isRunning)

                        Button(action: onAddSession) {
                            Label("Session", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ShelfButtonStyle(prominent: false))
                    }
                }
                .padding(DS.Spacing.md)
                .background(Color.gbCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
        }
        .padding(.horizontal)
    }

    private var ratingLabel: String {
        switch game.rating {
        case 1: return "Mauvais"
        case 2: return "Moyen"
        case 3: return "Bon"
        case 4: return "Excellent"
        case 5: return "Chef-d'œuvre"
        default: return "Pas encore noté"
        }
    }
}

/// The five statuses as one row of equal buttons: one tap, no scrolling.
struct StatusStrip: View {
    let selection: GameStatus?
    let onSelect: (GameStatus) -> Void

    private let statuses: [GameStatus] = [.wantToPlay, .playing, .completed, .platinum, .shelved]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(statuses, id: \.self) { status in
                let selected = status == selection
                Button {
                    onSelect(status)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: status.icon)
                            .font(DS.Typography.headline)
                        Text(status.rawValue)
                            .font(DS.Typography.text(11, weight: .bold, relativeTo: .caption2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle(selected ? Color.gbDark : Color.textSecondary)
                    .background(selected ? status.color : Color.gbCard,
                                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct ShelfButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyMedium)
            .foregroundStyle(prominent ? Color.gbDark : Color.textPrimary)
            .frame(height: 46)
            .background(prominent ? Color.accent : Color.gbSurface2,
                        in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Your review

struct ReviewSection: View {
    @Binding var game: Game
    @State private var showsNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DetailSectionTitle(title: "Ta critique")

            TextField("Qu'en as-tu pensé ?", text: $game.review, axis: .vertical)
                .font(DS.Typography.bodyLarge)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3...12)
                .padding(DS.Spacing.md)
                .background(Color.gbCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

            HStack {
                Toggle(isOn: $game.isSpoiler) {
                    Label("Contient des spoilers", systemImage: "eye.slash")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
                .tint(Color.accent)
            }

            DisclosureGroup(isExpanded: $showsNotes) {
                TextField("Astuces, rappels, où tu en es…", text: $game.notes, axis: .vertical)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2...10)
                    .padding(DS.Spacing.sm)
                    .background(Color.gbCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .padding(.top, DS.Spacing.xs)
            } label: {
                Text(game.notes.isEmpty ? "Notes privées" : "Notes privées (\(game.notes.count) caractères)")
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
            }
            .tint(Color.textSecondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - About the game

struct AboutSection: View {
    let game: Game

    private static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        return f
    }()

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var release: String? {
        if let string = game.releaseDate, let date = Self.isoDate.date(from: string) {
            return Self.longDate.string(from: date)
        }
        return game.releaseYear.isEmpty || game.releaseYear == "TBA" ? nil : game.releaseYear
    }

    private var developer: String? {
        ["", "Unknown", "—"].contains(game.developer) ? nil : game.developer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DetailSectionTitle(title: "À propos")

            if let description = game.description, !description.isEmpty {
                ExpandableText(text: description)
            }

            Grid(alignment: .leading, horizontalSpacing: DS.Spacing.lg, verticalSpacing: DS.Spacing.md) {
                GridRow {
                    fact("Développeur", developer)
                    fact("Sortie", release)
                }
                GridRow {
                    fact("Genres", game.genres.isEmpty ? nil : game.genres.prefix(3).joined(separator: ", "))
                    fact("Durée moyenne", game.estimatedPlaytime.flatMap { $0 > 0 ? "\($0) h" : nil })
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 3) {
                        label("Metacritic")
                        if let score = game.metacriticScore {
                            Text("\(score)")
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(DS.Colors.score(score))
                        } else {
                            dash
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        label("Âge")
                        if let pegi = game.pegi {
                            PEGIBadge(age: pegi, size: 24)
                        } else {
                            dash
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(Color.textSecondary)
    }

    private var dash: some View {
        Text("—").font(DS.Typography.bodyMedium).foregroundStyle(Color.textTertiary)
    }

    private func fact(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            label(title)
            Text(value ?? "—")
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(value == nil ? Color.textTertiary : Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Text cut after a few lines, with "Lire la suite" only when it actually is cut.
struct ExpandableText: View {
    let text: String
    var lineLimit = 5

    @State private var isExpanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var limitedHeight: CGFloat = 0

    private var isTruncated: Bool { fullHeight > limitedHeight + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            styled(Text(text))
                .lineLimit(isExpanded ? nil : lineLimit)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if !isExpanded { limitedHeight = $0 } }
                // The full text, measured but never shown (a background doesn't affect layout).
                .background(alignment: .top) {
                    styled(Text(text))
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
                }

            if isTruncated || isExpanded {
                Button(isExpanded ? "Réduire" : "Lire la suite") {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                }
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(Color.accent)
            }
        }
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(DS.Typography.bodyLarge)
            .lineSpacing(4)
            .foregroundStyle(Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Screenshots

struct ScreenshotStrip: View {
    let urls: [URL]
    let namespace: Namespace.ID
    let onOpen: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DetailSectionTitle(title: "Captures d'écran", trailing: "\(urls.count)")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.sm) {
                    ForEach(urls.indices, id: \.self) { index in
                        Button { onOpen(index) } label: {
                            CachedAsyncImage(url: urls[index]) { $0.resizable().scaledToFill() } placeholder: { Color.gbSurface2 }
                                .frame(width: 272, height: 153)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: "shot-\(index)", in: namespace)
                        .accessibilityLabel("Capture \(index + 1) sur \(urls.count), toucher pour agrandir")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Full-screen gallery: swipe between shots, pinch or double-tap to zoom, pull down to close.
struct ScreenshotViewer: View {
    let urls: [URL]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var pull: CGFloat = 0
    @State private var isZoomed = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
                .opacity(1 - min(abs(pull) / 500, 0.6))
                .ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(urls.indices, id: \.self) { i in
                    ZoomableImage(url: urls[i], isZoomed: $isZoomed)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: pull)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Only a mostly vertical drag closes; horizontal ones page.
                        guard !isZoomed, abs(value.translation.height) > abs(value.translation.width) else { return }
                        pull = value.translation.height
                    }
                    .onEnded { value in
                        guard !isZoomed else { return }
                        if abs(pull) > 120 || abs(value.predictedEndTranslation.height) > 400 {
                            dismiss()
                        } else {
                            withAnimation(.spring(duration: 0.3)) { pull = 0 }
                        }
                    }
            )

            HStack {
                Text("\(index + 1) / \(urls.count)")
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(.white.opacity(0.85))
                    .contentTransition(.numericText())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Fermer")
            }
            .padding(.horizontal)
            .opacity(1 - min(abs(pull) / 200, 1))
        }
        .statusBarHidden()
        .onChange(of: index) { _, _ in isZoomed = false }
    }
}

struct ZoomableImage: View {
    let url: URL
    @Binding var isZoomed: Bool
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        CachedAsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: {
            ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .scaleEffect(scale)
        .offset(offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            MagnifyGesture()
                .onChanged { scale = min(max(baseScale * $0.magnification, 1), 4) }
                .onEnded { _ in settle() }
        )
        .gesture(
            DragGesture()
                .onChanged { offset = CGSize(width: baseOffset.width + $0.translation.width,
                                             height: baseOffset.height + $0.translation.height) }
                .onEnded { _ in baseOffset = offset },
            including: scale > 1 ? .all : .none // pan only when zoomed; otherwise swipes page
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(duration: 0.3)) {
                if scale > 1 { reset() } else { scale = 2.5; baseScale = 2.5; isZoomed = true }
            }
        }
    }

    private func settle() {
        baseScale = scale
        if scale < 1.05 {
            withAnimation(.spring(duration: 0.3)) { reset() }
        } else {
            isZoomed = true
        }
    }

    private func reset() {
        scale = 1
        baseScale = 1
        offset = .zero
        baseOffset = .zero
        isZoomed = false
    }
}

// MARK: - Your journal for this game

struct GameJournalSection: View {
    let sessions: [PlaySession]
    let onAdd: () -> Void

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    var body: some View {
        let total = sessions.reduce(0) { $0 + $1.duration }
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DetailSectionTitle(title: "Ton journal",
                               trailing: sessions.isEmpty ? nil : "\(sessions.count) session\(sessions.count > 1 ? "s" : ""), \(total / 60) h \(total % 60) min")

            if sessions.isEmpty {
                Button(action: onAdd) {
                    Text("Aucune session pour l'instant. Lance le chrono quand tu joues, ou ajoute une session passée.")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.md)
                        .background(Color.gbCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions.prefix(5)) { session in
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                            Text(Self.day.string(from: session.date))
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 96, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.formattedDuration)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color.textSecondary)
                                if !session.notes.isEmpty {
                                    Text(session.notes)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(Color.textPrimary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        if session.id != sessions.prefix(5).last?.id {
                            Divider().overlay(Color.gbBorder)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .background(Color.gbCard, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - The finer details (folded)

struct PlayDetailsSection: View {
    @Binding var game: Game
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    subTitle("Notes détaillées")
                    SubRatingRow(label: "Histoire", icon: "book.fill", rating: $game.subRatings.story)
                    SubRatingRow(label: "Gameplay", icon: "gamecontroller.fill", rating: $game.subRatings.gameplay)
                    SubRatingRow(label: "Graphismes", icon: "paintbrush.fill", rating: $game.subRatings.graphics)
                    SubRatingRow(label: "Musique et son", icon: "speaker.wave.3.fill", rating: $game.subRatings.sound)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    subTitle("Ressenti")
                    FlowLayout(spacing: 8) {
                        ForEach(MoodTag.allCases, id: \.self) { tag in
                            Button {
                                if game.moodTags.contains(tag) { game.moodTags.removeAll { $0 == tag } } else { game.moodTags.append(tag) }
                            } label: {
                                TagPill(label: tag.rawValue, icon: tag.icon, isSelected: game.moodTags.contains(tag), tint: tag.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    subTitle("Difficulté jouée")
                    FlowLayout(spacing: 8) {
                        ForEach(GameDifficulty.allCases, id: \.self) { difficulty in
                            Button { game.difficulty = game.difficulty == difficulty ? nil : difficulty } label: {
                                TagPill(label: difficulty.rawValue, isSelected: game.difficulty == difficulty)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if game.status == .wantToPlay {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        subTitle("Priorité dans ton backlog")
                        Picker("Priorité", selection: $game.priority) {
                            ForEach(BacklogPriority.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Stepper("Partie n° \(game.playthroughCount)", value: $game.playthroughCount, in: 1...10)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)

                DatePicker("Commencé le", selection: Binding(
                    get: { game.startedDate ?? Date() },
                    set: { game.startedDate = $0 }
                ), displayedComponents: .date)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(Color.textPrimary)

                if game.status == .completed || game.status == .platinum {
                    DatePicker("Terminé le", selection: Binding(
                        get: { game.completedDate ?? Date() },
                        set: { game.completedDate = $0 }
                    ), displayedComponents: .date)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                }
            }
            .padding(.top, DS.Spacing.md)
            .tint(Color.accent)
        } label: {
            Text("Détails de ta partie")
                .font(DS.Typography.title3)
                .foregroundStyle(Color.textPrimary)
        }
        .tint(Color.textSecondary)
        .padding(.horizontal)
    }

    private func subTitle(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.bodyMedium)
            .foregroundStyle(Color.textSecondary)
    }
}

// MARK: - Similar games

struct SimilarGamesShelf: View {
    @Environment(GameStore.self) private var store
    let games: [Game]
    let isLoading: Bool
    let namespace: Namespace.ID

    var body: some View {
        if isLoading || !games.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                DetailSectionTitle(title: "Jeux similaires")
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: DS.Spacing.md) {
                        if games.isEmpty {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 5).fill(Color.gbSurface2).frame(width: 90, height: 118)
                            }
                        }
                        ForEach(games) { similar in
                            NavigationLink {
                                GameDetailView(game: store.libraryGame(for: similar) ?? similar)
                                    .navigationTransition(.zoom(sourceID: "similar-\(similar.id)", in: namespace))
                            } label: {
                                FaceOutCase(game: similar, coverWidth: 85, showsProgress: false)
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: "similar-\(similar.id)", in: namespace)
                            .accessibilityLabel(similar.title)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, DS.Spacing.xs)
                }
                ShelfPlank().padding(.horizontal, DS.Spacing.md)
            }
        }
    }
}

// MARK: - Stickers

/// Stickers unlocked by playing, then the locked slots with what unlocks them.
/// Opening the page cuts the art of any sticker that doesn't have it yet.
struct StickersSection: View {
    let game: Game
    @Environment(GameStore.self) private var store

    var body: some View {
        let all = store.stickers(for: game)
        // Stickers the game ran out of art for stay hidden; with no art at all (or on the
        // simulator) the first one stands in with the cover, so the section is never empty.
        let withArt = all.filter { !$0.isOutOfArt }
        let unlocked = withArt.isEmpty ? Array(all.prefix(1)) : withArt
        // Once out of art, more play can't bring new stickers: only show the one-off goals.
        let outOfArt = all.contains(where: \.isOutOfArt)
        let goals = StickerRules.nextGoals(for: game).filter { !outOfArt || !$0.isPlaytime }
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DetailSectionTitle(title: "Autocollants", trailing: "\(unlocked.count) débloqué\(unlocked.count > 1 ? "s" : "")")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: DS.Spacing.md) {
                    ForEach(unlocked) { sticker in
                        StickerView(sticker: sticker, game: game)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                    ForEach(goals, id: \.self) { LockedStickerSlot(reason: $0) }
                }
                .padding(.vertical, DS.Spacing.md)
                .padding(.horizontal)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: unlocked.map(\.id))
            }
            .padding(.horizontal, -DS.Spacing.md)
        }
        .padding(.horizontal)
        .task(id: all.filter { $0.imageFile == nil }.count) {
            await store.cutStickers(for: game)
        }
    }
}

struct StickerView: View {
    let sticker: Sticker
    let game: Game
    var height: CGFloat = 130
    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            art
                .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
                .rotationEffect(.degrees(sticker.tilt))
                .overlay {
                    if copied {
                        Text("Copié")
                            .font(DS.Typography.captionMedium)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.75), in: Capsule())
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityElement()
        .accessibilityLabel("Autocollant \(game.title), \(sticker.reason.label)\(sticker.isHolo ? ", holographique" : "")")
        .accessibilityHint("Copie l'autocollant dans le presse-papiers")
    }

    /// Puts the sticker on the pasteboard as a transparent PNG, ready to paste in Messages.
    private func copy() {
        let png: Data?
        if sticker.hasArt, let file = sticker.imageFile {
            png = try? Data(contentsOf: StickerService.shared.url(for: file))
        } else {
            // Cover stand-in: render it as drawn (white border included), without tilt or shadow.
            let renderer = ImageRenderer(content: art)
            renderer.scale = 3
            png = renderer.uiImage?.pngData()
        }
        guard let png else { return }
        UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)
        HapticManager.notification(.success)
        withAnimation(.spring(response: 0.3)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.25)) { copied = false }
        }
    }

    @ViewBuilder private var art: some View {
        if sticker.hasArt, let file = sticker.imageFile,
           let image = UIImage(contentsOfFile: StickerService.shared.url(for: file).path) {
            let picture = Image(uiImage: image).resizable().scaledToFit()
            picture
                .frame(height: height)
                .overlay { if sticker.isHolo { HoloSheen().mask(picture) } }
        } else {
            // No cut-out (no art, or the simulator): the cover as a plain die-cut sticker.
            CachedAsyncImage(url: game.artURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                game.coverColor
            }
            .frame(width: height * 0.7, height: height * 0.92)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay { if sticker.isHolo { HoloSheen().clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) } }
            .padding(5)
            .background(.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

/// Rainbow foil for platinum stickers.
/// ponytail: static sheen; make it follow the phone's tilt (CoreMotion) if it feels flat.
private struct HoloSheen: View {
    var body: some View {
        LinearGradient(colors: ([.pink, .yellow, .mint, .cyan, .purple, .pink] as [Color]).map { $0.opacity(0.55) },
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}

private struct LockedStickerSlot: View {
    let reason: Sticker.Reason

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "lock.fill")
                .font(.title3)
            Text(reason.label)
                .font(DS.Typography.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.textTertiary)
        .frame(width: 96, height: 120)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(Color.gbBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Autocollant verrouillé : \(reason.label)")
    }
}
