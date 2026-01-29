//
//  CloudInfrastructureView.swift
//  Gameboxd
//
//  View demonstrating AWS, Security, and Docker concepts
//  For certification proof: AWS Developer, CompTIA Security+, Docker CA
//

import SwiftUI
import LocalAuthentication

struct CloudInfrastructureView: View {
    @EnvironmentObject var store: GameStore
    @StateObject private var securityManager = SecurityManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    CertificationHeader()
                    
                    // Tab Selector
                    Picker("Section", selection: $selectedTab) {
                        Text("AWS").tag(0)
                        Text("Sécurité").tag(1)
                        Text("Docker").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    switch selectedTab {
                    case 0:
                        AWSSection()
                    case 1:
                        SecuritySection()
                    case 2:
                        DockerSection()
                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical)
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Infrastructure")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Header
struct CertificationHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                CertBadge(title: "AWS", subtitle: "Developer", color: .orange)
                CertBadge(title: "CompTIA", subtitle: "Security+", color: .red)
                CertBadge(title: "Docker", subtitle: "DCA", color: .blue)
            }
            
            Text("Compétences Cloud & Sécurité")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct CertBadge: View {
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - AWS Section
struct AWSSection: View {
    @State private var isLoading = false
    @State private var cognitoStatus = "Non connecté"
    @State private var s3Status = "Prêt"
    @State private var lambdaResult = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Cognito Authentication
            AWSServiceCard(
                icon: "person.badge.key.fill",
                title: "Amazon Cognito",
                description: "User Pool Authentication avec SRP",
                status: cognitoStatus,
                statusColor: cognitoStatus == "Connecté" ? .green : .gray
            ) {
                Button("Simuler Auth") {
                    simulateCognitoAuth()
                }
                .buttonStyle(AWSButtonStyle())
            }
            
            // S3 Storage
            AWSServiceCard(
                icon: "externaldrive.fill.badge.icloud",
                title: "Amazon S3",
                description: "Stockage objet avec presigned URLs",
                status: s3Status,
                statusColor: .green
            ) {
                HStack {
                    Button("Upload") { simulateS3Upload() }
                        .buttonStyle(AWSButtonStyle())
                    Button("Download") { simulateS3Download() }
                        .buttonStyle(AWSButtonStyle())
                }
            }
            
            // Lambda Functions
            AWSServiceCard(
                icon: "function",
                title: "AWS Lambda",
                description: "Fonctions serverless via API Gateway",
                status: lambdaResult.isEmpty ? "Prêt" : lambdaResult,
                statusColor: .green
            ) {
                Button("Invoquer Lambda") {
                    invokeLambda()
                }
                .buttonStyle(AWSButtonStyle())
            }
            
            // DynamoDB
            AWSServiceCard(
                icon: "cylinder.split.1x2.fill",
                title: "Amazon DynamoDB",
                description: "NoSQL avec partition/sort keys",
                status: "Connecté",
                statusColor: .green
            ) {
                Button("Query Table") { }
                    .buttonStyle(AWSButtonStyle())
            }
            
            // CloudWatch
            AWSServiceCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "CloudWatch",
                description: "Monitoring, logs et alarmes",
                status: "Actif",
                statusColor: .green
            ) {
                Button("Voir Métriques") { }
                    .buttonStyle(AWSButtonStyle())
            }
            
            // Code Examples
            AWSCodeExamples()
        }
        .padding(.horizontal)
    }
    
    func simulateCognitoAuth() {
        isLoading = true
        cognitoStatus = "Authentification..."
        
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                cognitoStatus = "Connecté"
                isLoading = false
            }
        }
    }
    
    func simulateS3Upload() {
        s3Status = "Upload en cours..."
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                s3Status = "Upload réussi ✓"
            }
        }
    }
    
    func simulateS3Download() {
        s3Status = "Download..."
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                s3Status = "Téléchargé ✓"
            }
        }
    }
    
    func invokeLambda() {
        lambdaResult = "Exécution..."
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                lambdaResult = "200 OK (45ms)"
            }
        }
    }
}

struct AWSServiceCard<Actions: View>: View {
    let icon: String
    let title: String
    let description: String
    let status: String
    let statusColor: Color
    @ViewBuilder let actions: () -> Actions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            actions()
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

struct AWSButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(configuration.isPressed ? 0.3 : 0.2))
            .foregroundColor(.orange)
            .cornerRadius(8)
    }
}

struct AWSCodeExamples: View {
    @State private var expanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { expanded.toggle() } }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.orange)
                    Text("Exemples de Code AWS")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    CodeBlock(title: "Cognito SRP Auth", code: """
// USER_SRP_AUTH flow
let srpA = generateSRPValue()
let response = await cognito.initiateAuth(
    AuthFlow: .USER_SRP_AUTH,
    AuthParameters: ["SRP_A": srpA]
)
""")
                    
                    CodeBlock(title: "S3 Presigned URL", code: """
// Generate presigned upload URL
let url = s3.generatePresignedURL(
    bucket: "gameboxd-data",
    key: "backups/user123.json",
    expires: 3600
)
""")
                    
                    CodeBlock(title: "DynamoDB Query", code: """
// Query with key conditions
let items = await dynamodb.query(
    TableName: "GameboxdData",
    KeyConditionExpression: 
        "pk = :pk AND begins_with(sk, :prefix)"
)
""")
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Security Section
struct SecuritySection: View {
    @StateObject private var security = SecurityManager.shared
    @State private var biometricResult = ""
    @State private var passwordToTest = ""
    @State private var passwordStrength: PasswordStrength = .weak
    @State private var encryptionDemo = ""
    @State private var inputToSanitize = "<script>alert('xss')</script>"
    @State private var sanitizedOutput = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Biometric Auth
            SecurityFeatureCard(
                icon: "faceid",
                title: "Authentification Biométrique",
                description: "Face ID / Touch ID avec LAContext"
            ) {
                VStack(spacing: 8) {
                    Button("Tester Face ID") {
                        testBiometrics()
                    }
                    .buttonStyle(SecurityButtonStyle(color: .blue))
                    
                    if !biometricResult.isEmpty {
                        Text(biometricResult)
                            .font(.caption)
                            .foregroundColor(biometricResult.contains("✓") ? .green : .red)
                    }
                }
            }
            
            // Password Strength
            SecurityFeatureCard(
                icon: "key.fill",
                title: "Validation Mot de Passe",
                description: "Politique NIST avec scoring"
            ) {
                VStack(spacing: 8) {
                    TextField("Tester un mot de passe", text: $passwordToTest)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .onChange(of: passwordToTest) { _, newValue in
                            passwordStrength = security.validatePasswordStrength(newValue)
                        }
                    
                    HStack {
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(strengthColor(for: i))
                                .frame(height: 4)
                                .cornerRadius(2)
                        }
                    }
                    
                    Text("Force: \(strengthText)")
                        .font(.caption)
                        .foregroundColor(strengthUIColor)
                }
            }
            
            // Encryption
            SecurityFeatureCard(
                icon: "lock.shield.fill",
                title: "Chiffrement AES-256-GCM",
                description: "Authenticated encryption avec CryptoKit"
            ) {
                VStack(spacing: 8) {
                    Button("Démo Chiffrement") {
                        demoEncryption()
                    }
                    .buttonStyle(SecurityButtonStyle(color: .purple))
                    
                    if !encryptionDemo.isEmpty {
                        Text(encryptionDemo)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(3)
                    }
                }
            }
            
            // Input Sanitization
            SecurityFeatureCard(
                icon: "shield.lefthalf.filled",
                title: "Validation des Entrées",
                description: "Protection XSS, injection, SSRF"
            ) {
                VStack(spacing: 8) {
                    Text("Input malveillant:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(inputToSanitize)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button("Sanitizer") {
                        sanitizedOutput = security.sanitizeInput(inputToSanitize)
                    }
                    .buttonStyle(SecurityButtonStyle(color: .green))
                    
                    if !sanitizedOutput.isEmpty {
                        Text("Output sécurisé:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(sanitizedOutput)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Keychain
            SecurityFeatureCard(
                icon: "key.viewfinder",
                title: "Stockage Keychain",
                description: "Secure Enclave avec biométrie"
            ) {
                HStack {
                    Button("Stocker") { }
                        .buttonStyle(SecurityButtonStyle(color: .orange))
                    Button("Récupérer") { }
                        .buttonStyle(SecurityButtonStyle(color: .orange))
                    Button("Supprimer") { }
                        .buttonStyle(SecurityButtonStyle(color: .red))
                }
            }
            
            // Security Concepts
            SecurityConceptsList()
        }
        .padding(.horizontal)
    }
    
    var strengthText: String {
        switch passwordStrength {
        case .weak: return "Faible"
        case .medium: return "Moyen"
        case .strong: return "Fort"
        case .veryStrong: return "Très fort"
        }
    }
    
    var strengthUIColor: Color {
        switch passwordStrength {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        case .veryStrong: return .blue
        }
    }
    
    func strengthColor(for index: Int) -> Color {
        let filled: Int
        switch passwordStrength {
        case .weak: filled = 1
        case .medium: filled = 2
        case .strong: filled = 3
        case .veryStrong: filled = 4
        }
        return index < filled ? strengthUIColor : Color.gray.opacity(0.3)
    }
    
    func testBiometrics() {
        Task {
            do {
                let success = try await security.authenticateWithBiometrics(
                    reason: "Authentifiez-vous pour accéder aux données"
                )
                await MainActor.run {
                    biometricResult = success ? "Authentification réussie ✓" : "Échec"
                }
            } catch {
                await MainActor.run {
                    biometricResult = "Erreur: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func demoEncryption() {
        let plaintext = "Données sensibles de l'utilisateur"
        let key = security.generateEncryptionKey()
        
        do {
            let encrypted = try security.encrypt(data: Data(plaintext.utf8), using: key)
            let decrypted = try security.decrypt(encryptedData: encrypted, using: key)
            let decryptedString = String(data: decrypted, encoding: .utf8) ?? ""
            
            encryptionDemo = "✓ Chiffré (\(encrypted.ciphertext.count) bytes) → Déchiffré: \"\(decryptedString)\""
        } catch {
            encryptionDemo = "Erreur: \(error.localizedDescription)"
        }
    }
}

struct SecurityFeatureCard<Actions: View>: View {
    let icon: String
    let title: String
    let description: String
    @ViewBuilder let actions: () -> Actions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            actions()
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

struct SecurityButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct SecurityConceptsList: View {
    let concepts = [
        ("CIA Triad", "Confidentialité, Intégrité, Disponibilité"),
        ("Defense in Depth", "Couches multiples de sécurité"),
        ("Zero Trust", "Ne jamais faire confiance, toujours vérifier"),
        ("Least Privilege", "Permissions minimales nécessaires"),
        ("MFA", "Authentification multi-facteurs")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concepts Security+")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(concepts, id: \.0) { concept in
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text(concept.0)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text(concept.1)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Docker Section
struct DockerSection: View {
    @State private var containerStatus: [String: String] = [
        "api": "running",
        "postgres": "running",
        "redis": "running",
        "nginx": "running"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Container Overview
            ContainerOverviewCard(containerStatus: containerStatus)
            
            // Docker Concepts
            DockerConceptCard(
                icon: "square.stack.3d.up.fill",
                title: "Multi-Stage Build",
                description: "Images optimisées pour production",
                details: [
                    "Stage 1: Build avec dépendances complètes",
                    "Stage 2: Runtime minimal (Alpine)",
                    "Réduction taille image de 1.2GB → 45MB"
                ]
            )
            
            DockerConceptCard(
                icon: "network",
                title: "Docker Networks",
                description: "Isolation et communication inter-services",
                details: [
                    "frontend: Accès externe (API, nginx)",
                    "backend: Interne uniquement (DB, Redis)",
                    "monitoring: Prometheus, Grafana"
                ]
            )
            
            DockerConceptCard(
                icon: "cylinder.fill",
                title: "Volumes & Persistence",
                description: "Données persistantes et backups",
                details: [
                    "postgres-data: Base de données",
                    "redis-data: Cache avec AOF",
                    "Backups automatiques quotidiens"
                ]
            )
            
            DockerConceptCard(
                icon: "lock.shield.fill",
                title: "Secrets Management",
                description: "Gestion sécurisée des credentials",
                details: [
                    "Docker secrets pour mots de passe",
                    "Variables d'environnement injectées",
                    "Pas de secrets dans les images"
                ]
            )
            
            // Docker Commands
            DockerCommandsCard()
            
            // Compose Services
            ComposeServicesCard()
        }
        .padding(.horizontal)
    }
}

struct ContainerOverviewCard: View {
    let containerStatus: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.blue)
                Text("Containers")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(containerStatus.count) running")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(containerStatus.keys.sorted()), id: \.self) { container in
                    HStack {
                        Circle()
                            .fill(containerStatus[container] == "running" ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(container)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.gbDark)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

struct DockerConceptCard: View {
    let icon: String
    let title: String
    let description: String
    let details: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(details, id: \.self) { detail in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

struct DockerCommandsCard: View {
    let commands = [
        ("docker build", "Créer une image"),
        ("docker run", "Lancer un container"),
        ("docker-compose up", "Démarrer les services"),
        ("docker logs", "Voir les logs"),
        ("docker exec", "Exécuter une commande"),
        ("docker network", "Gérer les réseaux")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commandes Docker")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(commands, id: \.0) { cmd in
                HStack {
                    Text(cmd.0)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 140, alignment: .leading)
                    
                    Text(cmd.1)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

struct ComposeServicesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("docker-compose.yml")
                .font(.headline)
                .foregroundColor(.white)
            
            CodeBlock(title: "Services", code: """
services:
  api:
    build: .
    deploy:
      replicas: 2
      resources:
        limits: { cpus: '1', memory: 512M }
  postgres:
    image: postgres:15-alpine
    volumes: [postgres-data:/data]
  redis:
    image: redis:7-alpine
    command: --maxmemory 256mb
""")
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Code Block Helper
struct CodeBlock: View {
    let title: String
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            Text(code)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.green)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview
#Preview {
    CloudInfrastructureView()
        .environmentObject(GameStore())
}
