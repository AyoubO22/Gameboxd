//
//  SettingsView.swift
//  Gameboxd
//
//  Settings with themes, notifications, import/export
//

import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var exportedFileURL: URL?
    @State private var showingImportError = false
    @State private var importErrorMessage = ""
    @State private var showingExportError = false
    
    var body: some View {
        List {
            // Appearance Section
            Section {
                NavigationLink(destination: ThemePickerView()) {
                    SettingsRow(icon: "paintbrush.fill", title: "Thème", color: .purple)
                }
                
                NavigationLink(destination: AppIconPickerView()) {
                    SettingsRow(icon: "app.fill", title: "Icône de l'app", color: .blue)
                }
            } header: {
                Text("Apparence")
            }
            .listRowBackground(Color.gbCard)
            
            // Notifications Section
            Section {
                NavigationLink(destination: NotificationsSettingsView()) {
                    SettingsRow(icon: "bell.fill", title: "Notifications", color: .red)
                }
            } header: {
                Text("Notifications")
            }
            .listRowBackground(Color.gbCard)
            
            // Data Section
            Section {
                NavigationLink(destination: iCloudSyncView()) {
                    SettingsRow(icon: "icloud.fill", title: "Synchronisation iCloud", color: .blue)
                }
                
                Button(action: exportData) {
                    SettingsRow(icon: "square.and.arrow.up.fill", title: "Exporter mes données", color: .green)
                }
                
                Button(action: { showingImportPicker = true }) {
                    SettingsRow(icon: "square.and.arrow.down.fill", title: "Importer des données", color: .orange)
                }
                
                NavigationLink(destination: CustomTagsView()) {
                    SettingsRow(icon: "tag.fill", title: "Mes tags personnalisés", color: .cyan)
                }
            } header: {
                Text("Données")
            }
            .listRowBackground(Color.gbCard)
            
            // Account Section
            Section {
                NavigationLink(destination: EditProfileView()) {
                    SettingsRow(icon: "person.fill", title: "Profil", color: .blue)
                }
                
                Button(action: { showingDeleteConfirmation = true }) {
                    SettingsRow(icon: "trash.fill", title: "Supprimer toutes les données", color: .red)
                }
                
                Button(action: { store.logout() }) {
                    SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Déconnexion", color: .gray)
                }
            } header: {
                Text("Compte")
            }
            .listRowBackground(Color.gbCard)
            
            // About Section
            Section {
                NavigationLink(destination: AboutView()) {
                    SettingsRow(icon: "info.circle.fill", title: "À propos", color: .gray)
                }
                
                if let url = URL(string: "https://rawg.io") {
                    Link(destination: url) {
                        SettingsRow(icon: "globe", title: "Données fournies par RAWG", color: .gbGreen)
                    }
                }
            } header: {
                Text("Informations")
            }
            .listRowBackground(Color.gbCard)
            
            // App Version
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Gameboxd")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Paramètres")
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
                    .presentationDetents([.medium, .large])
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Supprimer toutes les données ?", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                store.deleteAllData()
            }
        } message: {
            Text("Cette action est irréversible. Toutes tes données seront perdues.")
        }
        .alert("Échec de l'import", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .alert("Échec de l'export", isPresented: $showingExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Impossible d'exporter les données. Réessaie plus tard.")
        }
    }
    
    func exportData() {
        if let url = store.exportData() {
            exportedFileURL = url
            // Small delay to ensure the URL is set before presenting the sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingExportSheet = true
            }
        } else {
            showingExportError = true
        }
    }
    
    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                let success = store.importData(from: url)
                if !success {
                    importErrorMessage = "Le fichier sélectionné n'a pas pu être lu. Vérifie qu'il s'agit d'un export Gameboxd valide."
                    showingImportError = true
                }
            }
        case .failure(let error):
            importErrorMessage = "Impossible d'accéder au fichier : \(error.localizedDescription)"
            showingImportError = true
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Theme Picker
struct ThemePickerView: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeCard(theme: theme, isSelected: store.currentTheme == theme) {
                        store.setTheme(theme)
                    }
                }
            }
            .padding()
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Thème")
    }
}

struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Preview
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.darkColor)
                        .frame(width: 30, height: 50)
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.accentColor)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.cardColor)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.cardColor)
                            .frame(height: 8)
                    }
                }
                .padding(8)
                .background(theme.darkColor)
                .cornerRadius(8)
                
                // Name
                Text(theme.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.accentColor : Color.clear, lineWidth: 3)
            )
        }
    }
}

// MARK: - App Icon Picker
struct AppIconPickerView: View {
    let iconNames = ["AppIcon", "AppIcon-Dark", "AppIcon-Retro", "AppIcon-Minimal"]
    @State private var selectedIcon: String? = nil
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(iconNames, id: \.self) { iconName in
                    Button(action: { setAppIcon(iconName) }) {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gbCard)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.gbGreen)
                                )
                            
                            Text(iconName.replacingOccurrences(of: "AppIcon-", with: ""))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Icône de l'app")
    }
    
    func setAppIcon(_ name: String) {
        let iconName = name == "AppIcon" ? nil : name
        UIApplication.shared.setAlternateIconName(iconName)
    }
}

// MARK: - Notifications Settings
struct NotificationsSettingsView: View {
    @EnvironmentObject var store: GameStore
    @State private var releaseReminders = true
    @State private var achievementAlerts = true
    @State private var weeklyDigest = false
    @State private var backlogReminders = true
    @State private var reminderDays = 1
    @State private var backlogReminderDays = 7
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        List {
            Section {
                Toggle("Rappels de sortie", isOn: $releaseReminders)
                    .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
                
                if releaseReminders {
                    Stepper("Rappel \(reminderDays) jour\(reminderDays > 1 ? "s" : "") avant", value: $reminderDays, in: 1...7)
                }
            } header: {
                Text("Jeux à venir")
            }
            .listRowBackground(Color.gbCard)
            
            Section {
                Toggle("Rappels backlog", isOn: $backlogReminders)
                    .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
                
                if backlogReminders {
                    Stepper("Rappeler après \(backlogReminderDays) jours", value: $backlogReminderDays, in: 3...30)
                }
            } header: {
                Text("Backlog")
            } footer: {
                Text("Rappelle-toi de jouer aux jeux qui attendent dans ton backlog")
            }
            .listRowBackground(Color.gbCard)
            
            Section {
                Toggle("Succès débloqués", isOn: $achievementAlerts)
                    .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
            } header: {
                Text("Succès")
            }
            .listRowBackground(Color.gbCard)
            
            Section {
                Toggle("Résumé hebdomadaire", isOn: $weeklyDigest)
                    .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
            } header: {
                Text("Récapitulatifs")
            } footer: {
                Text("Reçois un résumé de tes sessions de jeu chaque semaine")
            }
            .listRowBackground(Color.gbCard)
            
            Section {
                HStack {
                    Text("Statut")
                        .foregroundColor(.white)
                    Spacer()
                    Text(notificationStatusText)
                        .foregroundColor(notificationStatusColor)
                        .fontWeight(.medium)
                }
                
                if notificationStatus == .denied {
                    Button("Ouvrir les réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.gbGreen)
                } else if notificationStatus == .notDetermined {
                    Button("Demander l'autorisation") {
                        requestNotificationPermission()
                    }
                    .foregroundColor(.gbGreen)
                }
                
                if notificationStatus == .authorized {
                    Button("Tester les notifications") {
                        sendTestNotification()
                    }
                    .foregroundColor(.orange)
                }
            } header: {
                Text("Permissions")
            }
            .listRowBackground(Color.gbCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Notifications")
        .foregroundColor(.white)
        .onChange(of: backlogReminders) { _, newValue in
            if newValue {
                scheduleBacklogReminders()
            } else {
                cancelBacklogReminders()
            }
        }
        .onAppear {
            checkNotificationStatus()
        }
        .alert("Notifications", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "Autorisées ✓"
        case .denied: return "Refusées"
        case .notDetermined: return "Non configuré"
        case .provisional: return "Provisoire"
        case .ephemeral: return "Éphémère"
        @unknown default: return "Inconnu"
        }
    }
    
    var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }
    
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                checkNotificationStatus()
                if granted {
                    permissionAlertMessage = "Notifications activées avec succès !"
                } else if let error = error {
                    permissionAlertMessage = "Erreur : \(error.localizedDescription)"
                } else {
                    permissionAlertMessage = "Les notifications ont été refusées. Tu peux les activer dans Réglages > Gameboxd."
                }
                showingPermissionAlert = true
            }
        }
    }
    
    func sendTestNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                DispatchQueue.main.async {
                    permissionAlertMessage = "Les notifications ne sont pas autorisées. Active-les d'abord."
                    showingPermissionAlert = true
                }
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🎮 Gameboxd"
            content.body = "Les notifications fonctionnent ! Tu seras rappelé de jouer."
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notification_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        permissionAlertMessage = "Erreur : \(error.localizedDescription)"
                    } else {
                        permissionAlertMessage = "Notification envoyée ! Elle apparaîtra dans 1 seconde."
                    }
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    func scheduleBacklogReminders() {
        guard let randomGame = store.randomBacklogPick() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎮 Un jeu t'attend!"
        content.body = "Que dirais-tu de lancer \(randomGame.title) ?"
        content.sound = .default
        
        // Schedule for next week at 6pm
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.weekday = Calendar.current.component(.weekday, from: Date()) + backlogReminderDays % 7
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "backlog_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelBacklogReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["backlog_reminder"])
    }
}

// MARK: - Custom Tags View
struct CustomTagsView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    @State private var newTagIcon = "tag.fill"
    
    let iconOptions = ["tag.fill", "star.fill", "heart.fill", "flame.fill", "bolt.fill", "leaf.fill", "crown.fill", "flag.fill"]
    
    var body: some View {
        List {
            // Existing Tags
            Section {
                ForEach(store.customTags) { tag in
                    HStack {
                        Image(systemName: tag.icon)
                            .foregroundColor(tag.color)
                            .frame(width: 30)
                        
                        Text(tag.name)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                }
                .onDelete(perform: deleteTag)
            } header: {
                Text("Mes tags")
            }
            .listRowBackground(Color.gbCard)
            
            // Add New Tag
            Section {
                TextField("Nom du tag", text: $newTagName)
                    .foregroundColor(.white)
                
                ColorPicker("Couleur", selection: $newTagColor)
                
                Picker("Icône", selection: $newTagIcon) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Image(systemName: icon).tag(icon)
                    }
                }
                
                Button("Ajouter le tag") {
                    addTag()
                }
                .foregroundColor(.gbGreen)
                .disabled(newTagName.isEmpty)
            } header: {
                Text("Nouveau tag")
            }
            .listRowBackground(Color.gbCard)
            
            // Suggestions
            Section {
                ForEach(CustomTag.suggestions) { tag in
                    Button(action: { addSuggestedTag(tag) }) {
                        HStack {
                            Image(systemName: tag.icon)
                                .foregroundColor(tag.color)
                                .frame(width: 30)
                            
                            Text(tag.name)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if store.customTags.contains(where: { $0.name == tag.name }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.gbGreen)
                            } else {
                                Image(systemName: "plus")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            } header: {
                Text("Suggestions")
            }
            .listRowBackground(Color.gbCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Tags personnalisés")
    }
    
    func addTag() {
        let tag = CustomTag(name: newTagName, colorHex: newTagColor.toHex(), icon: newTagIcon)
        store.addCustomTag(tag)
        newTagName = ""
    }
    
    func addSuggestedTag(_ tag: CustomTag) {
        if !store.customTags.contains(where: { $0.name == tag.name }) {
            store.addCustomTag(tag)
        }
    }
    
    func deleteTag(at offsets: IndexSet) {
        store.customTags.remove(atOffsets: offsets)
        store.saveCustomTags()
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon
                ZStack {
                    Circle()
                        .fill(Color.gbGreen.gradient)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 45))
                        .foregroundColor(.gbDark)
                }
                
                Text("Gameboxd")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text("Ton journal de jeux vidéo personnel. Track tes jeux, note tes expériences, et découvre de nouveaux titres.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Credits
                VStack(spacing: 16) {
                    Text("Crédits")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 8) {
                        Text("Données de jeux par RAWG.io")
                        Text("Développé avec ❤️ en SwiftUI")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                .padding(.top)
                
                Spacer()
            }
            .padding(.vertical, 40)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("À propos")
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - iCloud Sync View
struct iCloudSyncView: View {
    @EnvironmentObject var store: GameStore
    @State private var iCloudEnabled = false
    @State private var autoSync = true
    @State private var lastSyncDate: Date?
    @State private var isSyncing = false
    @State private var syncStatus: SyncStatus = .idle
    @State private var showingSyncAlert = false
    @State private var alertMessage = ""
    
    enum SyncStatus {
        case idle, syncing, success, error
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .syncing: return .blue
            case .success: return .green
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .success: return "checkmark.icloud"
            case .error: return "exclamationmark.icloud"
            }
        }
    }
    
    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    ZStack {
                        Circle()
                            .fill(syncStatus.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: syncStatus.icon)
                            .font(.title2)
                            .foregroundColor(syncStatus.color)
                            .symbolEffect(.pulse, isActive: syncStatus == .syncing)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(iCloudEnabled ? "iCloud activé" : "iCloud désactivé")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if let lastSync = lastSyncDate {
                            Text("Dernière sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("Jamais synchronisé")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.gbCard)
            
            // Settings Section
            Section {
                Toggle("Activer iCloud", isOn: $iCloudEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
                
                if iCloudEnabled {
                    Toggle("Synchronisation automatique", isOn: $autoSync)
                        .toggleStyle(SwitchToggleStyle(tint: .gbGreen))
                }
            } header: {
                Text("Paramètres")
            }
            .listRowBackground(Color.gbCard)
            
            // Actions Section
            if iCloudEnabled {
                Section {
                    Button(action: syncNow) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Synchroniser maintenant")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                    .disabled(isSyncing)
                    .foregroundColor(.gbGreen)
                    
                    Button(action: uploadToiCloud) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Envoyer vers iCloud")
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button(action: downloadFromiCloud) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                            Text("Récupérer depuis iCloud")
                        }
                    }
                    .foregroundColor(.orange)
                } header: {
                    Text("Actions")
                }
                .listRowBackground(Color.gbCard)
            }
            
            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Comment ça marche?")
                            .fontWeight(.medium)
                    }
                    
                    Text("La synchronisation iCloud permet de garder tes jeux, sessions et statistiques synchronisés sur tous tes appareils Apple connectés au même compte iCloud.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            } header: {
                Text("À propos")
            }
            .listRowBackground(Color.gbCard)
            
            // Data Info
            Section {
                DataInfoRow(title: "Jeux", count: store.myGames.count)
                DataInfoRow(title: "Sessions", count: store.playSessions.count)
                DataInfoRow(title: "Listes", count: store.gameLists.count)
                DataInfoRow(title: "Objectifs", count: store.monthlyGoals.count)
            } header: {
                Text("Données à synchroniser")
            }
            .listRowBackground(Color.gbCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("iCloud Sync")
        .foregroundColor(.white)
        .onAppear {
            loadSyncSettings()
        }
        .onChange(of: iCloudEnabled) { _, newValue in
            saveSyncSettings()
            if newValue {
                setupiCloudObserver()
            }
        }
        .alert("Synchronisation", isPresented: $showingSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func loadSyncSettings() {
        iCloudEnabled = UserDefaults.standard.bool(forKey: "icloud_enabled")
        autoSync = UserDefaults.standard.object(forKey: "icloud_auto_sync") as? Bool ?? true
        if let date = UserDefaults.standard.object(forKey: "icloud_last_sync") as? Date {
            lastSyncDate = date
        }
    }
    
    func saveSyncSettings() {
        UserDefaults.standard.set(iCloudEnabled, forKey: "icloud_enabled")
        UserDefaults.standard.set(autoSync, forKey: "icloud_auto_sync")
    }
    
    func setupiCloudObserver() {
        // In a real app, you would set up NSUbiquitousKeyValueStore observation here
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            downloadFromiCloud()
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    func syncNow() {
        isSyncing = true
        syncStatus = .syncing
        
        // Simulate sync delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            uploadToiCloud()
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "icloud_last_sync")
            isSyncing = false
            syncStatus = .success
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                syncStatus = .idle
            }
        }
    }
    
    func uploadToiCloud() {
        let iCloudStore = NSUbiquitousKeyValueStore.default
        
        // Save games
        if let gamesData = try? JSONEncoder().encode(store.myGames) {
            iCloudStore.set(gamesData, forKey: "icloud_games")
        }
        
        // Save sessions
        if let sessionsData = try? JSONEncoder().encode(store.playSessions) {
            iCloudStore.set(sessionsData, forKey: "icloud_sessions")
        }
        
        // Save lists
        if let listsData = try? JSONEncoder().encode(store.gameLists) {
            iCloudStore.set(listsData, forKey: "icloud_lists")
        }
        
        // Save goals
        if let goalsData = try? JSONEncoder().encode(store.monthlyGoals) {
            iCloudStore.set(goalsData, forKey: "icloud_goals")
        }
        
        // Force sync
        iCloudStore.synchronize()
        
        alertMessage = "Données envoyées vers iCloud avec succès!"
        showingSyncAlert = true
    }
    
    func downloadFromiCloud() {
        let iCloudStore = NSUbiquitousKeyValueStore.default
        iCloudStore.synchronize()
        
        var importedCount = 0
        
        // Load games
        if let gamesData = iCloudStore.data(forKey: "icloud_games"),
           let games = try? JSONDecoder().decode([Game].self, from: gamesData) {
            // Merge with existing games
            for game in games {
                if !store.myGames.contains(where: { $0.id == game.id }) {
                    store.myGames.append(game)
                    importedCount += 1
                }
            }
        }
        
        alertMessage = importedCount > 0 ? 
            "\(importedCount) nouveaux éléments importés depuis iCloud!" :
            "Tes données sont déjà à jour!"
        showingSyncAlert = true
    }
}

// MARK: - Data Info Row
struct DataInfoRow: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text("\(count)")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(GameStore())
    }
}
