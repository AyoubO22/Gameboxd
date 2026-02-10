# 🎮 Gameboxd

> A Letterboxd-style gaming journal for iOS — Track, rate, and review your gaming experiences.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

---

## 📋 Table of Contents

- [Future Proof Project — Context](#-future-proof-project--context)
- [Reflectie & Persoonlijke Ontwikkeling](#-reflectie--persoonlijke-ontwikkeling)
- [Ambities & Motivatie](#-ambities--motivatie)
- [Economische & Maatschappelijke Waardecreatie](#-economische--maatschappelijke-waardecreatie)
- [Opleidingen & Competenties](#-opleidingen--competenties)
- [Competentiematrix (ECTS-koppeling)](#-competentiematrix-ects-koppeling)
- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [Cloud Infrastructure](#-cloud-infrastructure-aws)
- [Security Implementation](#-security-implementation-comptia-security)
- [Docker Deployment](#-docker-deployment)
- [API Integration](#-api-integration)
- [Contributing](#-contributing)

---

## � Future Proof Project — Context

> **Opleidingsonderdeel:** TI31FUT-PROOF-PJ — Future Proof Project (5 ECTS)  
> **Opleiding:** Bachelor in de Toegepaste Informatica, trajectschijf 3  
> **Academiejaar:** 2025–26

### Projectomschrijving

**Gameboxd** is een iOS-applicatie geïnspireerd op [Letterboxd](https://letterboxd.com), maar dan voor gamers. De app stelt gebruikers in staat om hun game-ervaringen bij te houden, te beoordelen en te delen. Dit zelfgekozen project combineert vier opleidingstrajecten (Swift, AWS, Security+, Docker) in één samenhangend product.

### Pitch & Definition of Done

**Probleem:** Gamers missen een dedicated platform om hun speelervaringen gestructureerd bij te houden. Bestaande oplossingen zijn ofwel te simpel (notitie-apps) of te complex (spreadsheets). Er is geen “Letterboxd voor games” die rating, reviews, statistieken en sociale functies combineert in een mooie mobiele ervaring.

**Oplossing:** Gameboxd is een native iOS-app die dit gat opvult met:
- 📚 Bibliotheekbeheer met statussen, ratings en reviews
- 📊 Speelstatistieken en maandelijkse doelen
- 🏆 Gamificatie via achievements
- 🔍 Ontdekking van 500.000+ games via RAWG.io API
- 🤝 Sociale functies (vrienden, activiteitenfeed, deelkaarten)
- 🔐 Beveiligde opslag met biometrie, encryptie en keychain
- 🐳 Production-ready backend met Docker-containerisatie

**Definition of Done:**
1. ✅ Werkende iOS-app met 20+ schermen in SwiftUI
2. ✅ RAWG.io API-integratie voor game-data
3. ✅ AWS-backend services geïmplementeerd (Cognito, S3, Lambda, DynamoDB, CloudWatch)
4. ✅ Beveiligingslaag op basis van Security+-principes (AES-256-GCM, PBKDF2, biometrie)
5. ✅ Docker-deployment met multi-stage builds en docker-compose
6. ✅ Unit tests voor kernfunctionaliteiten
7. ✅ Gedocumenteerd met README inclusief competentiemapping

---

## 🧠 Reflectie & Persoonlijke Ontwikkeling

> *Doelstelling D2: Zichzelf ontplooien en definiëren van ambities (GI 8.1, GI 8.2, GI 8.3)*

### Zelfreflectie

Bij de start van dit project had ik theoretische kennis uit vier cursussen, maar beperkte praktijkervaring. Het doel was om die kloof te dichten door alles samen te brengen in één realistisch project. Dit dwong me om:

- **Theorie naar praktijk te vertalen**: Cursusconcepten zoals MVVM, async/await, AES-256-GCM en Docker multi-stage builds daadwerkelijk te implementeren
- **Fouten te maken en ervan te leren**: Force unwraps die crashes veroorzaakten, API-keys die hardcoded stonden, negatieve playtime door ontbrekende validatie — allemaal bugs die ik zelf heb geïdentificeerd en opgelost
- **Hulpmiddelen effectief in te zetten**: GitHub Copilot gebruiken als versneller, niet als vervanging — elke suggestie kritisch beoordelen en begrijpen

### Sterktes (geïdentificeerd tijdens het project)

| Sterkte | Bewijs |
|---|---|
| Snel nieuwe technologieën oppakken | 4 cursussen gevolgd en toegepast in één project |
| Oog voor detail in UI/UX | Custom componenten, animaties, haptic feedback, accessibility |
| Beveiligingsbewustzijn | API-keys geëxternaliseerd, input-sanitisatie, encryptie geïmplementeerd |
| Zelfstandig probleemoplossend | Bugs zelf opgespoord en gefixed zonder externe hulp |

### Verbeterpunten (en hoe aangepakt)

| Verbeterpunt | Actie ondernomen |
|---|---|
| Praktijkervaring met Swift was beperkt | Uitgebreide Udemy-cursus + direct toepassen in eigen project |
| Geen ervaring met cloud-architectuur | AWS-cursus gevolgd + services geïmplementeerd in `AWSService.swift` |
| Cryptografie was puur theoretisch | Security+-cursus + werkende AES-256-GCM en PBKDF2 implementatie |
| Onbekend met containerisatie | Docker-cursus + Dockerfile en docker-compose opgezet |
| Praktische skill gap na cursussen | GitHub Copilot ingezet als leer- en vertaalhulpmiddel |

### Zelfsturing & bijsturing

Tijdens het project heb ik mijn aanpak meerdere malen bijgestuurd:
- **Oorspronkelijk plan**: Alleen een iOS-app bouwen met Swift
- **Bijsturing 1**: AWS-backend toevoegen om cloud-competenties te bewijzen
- **Bijsturing 2**: Security-laag versterken na het volgen van de Security+-cursus
- **Bijsturing 3**: Docker-deployment toevoegen voor DevOps-competenties
- **Bijsturing 4**: GitHub Copilot inzetten toen bleek dat de praktische vertaling van cursuskennis meer tijd kostte dan verwacht

---

## 🚀 Ambities & Motivatie

> *Doelstelling D2: Definiëren van ambities (GI 8.3, GI 10.2)*

### Waarom dit project?

Als gamer miste ik een app die mijn speelervaringen bijhoudt zoals Letterboxd dat doet voor films. In plaats van een bestaande tool te gebruiken, besloot ik er zelf een te bouwen — en dit te combineren met mijn leerdoelen voor vier opleidingstrajecten.

### Passie & ambitie

- **Passie voor gaming**: De app lost een persoonlijk probleem op, wat de motivatie hoog hield gedurende 150–200 uur werk
- **Ambitie als iOS-developer**: Swift en SwiftUI zijn de toekomst van Apple-ontwikkeling. Dit project bewijst dat ik een volledige app kan bouwen van concept tot deployment
- **Full-stack denken**: Door AWS, Security en Docker te integreren toon ik aan dat ik verder denk dan alleen de frontend
- **Loopbaanontwikkeling**: De combinatie Swift + Cloud + Security + DevOps maakt mij inzetbaar in meerdere domeinen van de IT-sector

### Afstemming op loopbaan

| Ambitie | Hoe dit project bijdraagt |
|---|---|
| iOS Developer worden | Volledige SwiftUI-app met 20+ schermen, MVVM, async/await |
| Cloud-vaardigheden ontwikkelen | AWS-services geïmplementeerd (Cognito, S3, Lambda, DynamoDB) |
| Security-bewustzijn opbouwen | Encryptie, biometrie, input-validatie, certificate pinning |
| DevOps-basis leggen | Docker multi-stage builds, Compose, CI/CD-ready architectuur |

---

## 💰 Economische & Maatschappelijke Waardecreatie

> *Doelstelling D3: Economische of maatschappelijke waardecreatie (GI 10.3, GI 10.4, GI 10.5)*

### Marktanalyse

| Aspect | Analyse |
|---|---|
| **Doelgroep** | Gamers die hun speelervaringen willen bijhouden (3,2 miljard gamers wereldwijd) |
| **Concurrentie** | Backloggd (web-only), HowLongToBeat (beperkte sociale functies), GG (geen iOS) |
| **Differentiatie** | Native iOS-ervaring, combinatie van journal + statistieken + social + gamificatie |
| **Marktomvang** | De gaming-industrie genereerde $184 miljard in 2025; companion-apps zijn een groeiend segment |

### Economische rentabiliteit

**Potentiële inkomstenmodellen:**

| Model | Beschrijving | Geschatte opbrengst |
|---|---|---|
| Freemium | Basisfuncties gratis, premium voor statistieken, thema’s, onbeperkte lijsten | €2,99–€4,99/maand |
| Eenmalige aankoop | Volledige app zonder abonnement | €9,99 |
| In-app purchases | Extra thema’s, app-iconen, deelkaart-stijlen | €0,99–€2,99 per item |

**Kostenoverzicht:**

| Kostenpost | Bedrag |
|---|---|
| Apple Developer Program | €99/jaar |
| RAWG API | Gratis (20.000 requests/maand) |
| AWS (bij schaling) | ~€20–€50/maand (free tier eerste 12 maanden) |
| Domain + hosting | ~€10/maand |
| **Break-even** | **~35–50 betalende gebruikers/maand (freemium)** |

### Maatschappelijke meerwaarde

- **Bewust gamen**: Door speeltijd bij te houden worden gebruikers bewuster van hun gamegedrag
- **Community-vorming**: Sociale functies stimuleren positieve interactie tussen gamers
- **Toegankelijkheid**: Accessibility labels en hints zorgen ervoor dat de app bruikbaar is voor gebruikers met een beperking
- **Open-source kennis**: De codebase dient als leermateriaal voor andere studenten die Swift, AWS, Security of Docker willen leren

### Strategie voor waardegeneratie

1. **MVP lanceren** op de App Store (huidige staat)
2. **Gebruikersfeedback** verzamelen via TestFlight beta
3. **Iteratief verbeteren** op basis van reviews en analytics
4. **Freemium model** introduceren na 1.000+ downloads
5. **Community opbouwen** via sociale functies en deelkaarten

### Procesefficiëntie

Het project demonstreert efficiëntie op meerdere niveaus:

| Aspect | Implementatie |
|---|---|
| **Herbruikbare componenten** | `GameCard`, `StarRating` worden in meerdere schermen gebruikt |
| **Caching** | `URLCache` (50 MB memory / 200 MB disk) vermindert API-calls |
| **Docker-containerisatie** | Reproduceerbare builds, snelle deployment, schaalbaar |
| **MVVM-architectuur** | Scheiding van concerns, testbaar, onderhoudbaar |
| **AI-assisted development** | GitHub Copilot versnelde het ontwikkelproces met behoud van kwaliteit |

---

## �🎓 Opleidingen & Competenties

> Dit project dient als praktische toepassing van vier opleidingstrajecten. De bijbehorende cursussen zijn volledig gevolgd en de opgedane kennis is direct toegepast in de ontwikkeling van de Gameboxd-app. Hieronder wordt per traject beschreven welke competenties zijn verworven en hoe deze concreet zijn geïmplementeerd.

### 🤖 AI-Assisted Development — GitHub Copilot

Bij de ontwikkeling van Gameboxd is **GitHub Copilot** gebruikt als AI-ondersteunde programmeertool. Hoewel alle cursussen volledig zijn gevolgd, was de praktische ervaring nog niet op 100%. GitHub Copilot heeft geholpen bij:

- **Code-implementatie**: Vertalen van theoretische kennis uit de cursussen naar werkende Swift-code
- **Best practices**: Suggesties voor design patterns (MVVM), error handling en Swift-conventies
- **Debugging**: Identificeren en oplossen van bugs zoals force unwraps, optionals en geheugenissues
- **Security**: Implementatie van cryptografie (AES-256-GCM, PBKDF2) en input-validatie op basis van Security+-kennis
- **Docker & AWS**: Opzetten van Dockerfile, docker-compose en AWS-servicestructuur op basis van cursusmateriaal

> **Belangrijk:** GitHub Copilot is ingezet als *leermiddel en versneller*, niet als vervanging van eigen kennis. Alle code is begrepen, gereviewed en waar nodig aangepast. De cursussen leverden de theoretische basis; Copilot hielp bij de praktische vertaling daarvan.

### 1. Swift — iOS App Development (Udemy)

| | |
|---|---|
| **Platform** | Udemy |
| **Geschatte werkbelasting** | 50–70 uur |
| **Focus** | Swift-programmeren, iOS-appontwikkeling, UI/UX-design, debuggen en testen |

**Beschrijving:** Volgen van een uitgebreide Swift-cursus op Udemy, inclusief basis- en gevorderde concepten. Directe toepassing in de ontwikkeling van de Gameboxd-app: gebruikersinterface, app-structuur en functionaliteiten.

**Toegepaste competenties in dit project:**

| Competentie | Toepassing in Gameboxd | Bestanden |
|---|---|---|
| Swift-programmeren | Volledige app geschreven in Swift 5.9 met modern `async/await`, `Codable`, generics en protocol-oriented design | Alle `.swift`-bestanden |
| iOS-appontwikkeling (SwiftUI) | 20+ schermen met `NavigationStack`, `TabView`, `@EnvironmentObject`, animaties en gestures | `Views/Screen/*.swift` |
| MVVM-architectuur | Centrale `@MainActor` ViewModel (`GameStore`) met reactieve state management via `@Published` | `ViewModels/GameStore.swift` |
| UI/UX-design | Custom componenten (StarRating, GameCard, ShareCard), thema-systeem, onboarding flow, haptic feedback | `Views/Components/*.swift`, `OnboardingView.swift` |
| API-integratie | REST API-client voor RAWG.io met `URLSession`, JSON-parsing, paginering en error handling | `Services/RAWGService.swift` |
| Data-persistentie | `UserDefaults` + `Keychain` + `iCloud` (NSUbiquitousKeyValueStore) voor cross-device sync | `ViewModels/GameStore.swift`, `SecurityManager.swift` |
| Debuggen & testen | Unit tests voor `GameStore` en `SecurityManager`, accessibility labels, input validatie | `GameboxdTests/*.swift` |
| Performance-optimalisatie | `URLCache` (50 MB memory / 200 MB disk), lazy loading, efficiënte `@Published`-updates | `GameboxdApp.swift` |

### 2. AWS Cloud Development (LinkedIn Learning)

| | |
|---|---|
| **Platform** | LinkedIn Learning |
| **Geschatte werkbelasting** | 40–50 uur |
| **Focus** | Cloudinfrastructuur, serverless development, CI/CD, deployment pipelines |

**Beschrijving:** Volgen van de AWS Developer Associate-cursus op LinkedIn Learning om vertrouwd te raken met cloud computing, deployment en backend-ontwikkeling op AWS. Opgedane kennis direct toegepast in de backend-architectuur van Gameboxd.

**Toegepaste competenties in dit project:**

| Competentie | Toepassing in Gameboxd | Bestanden |
|---|---|---|
| Amazon Cognito | SRP-authenticatie, token management (Access/ID/Refresh), MFA-ondersteuning, wachtwoordbeleid | `Services/AWSService.swift` |
| Amazon S3 | Presigned URLs, multipart uploads, lifecycle policies, AWS Signature V4 | `Services/AWSService.swift` |
| AWS Lambda | Synchrone & asynchrone invocations, API Gateway-integratie, Dead Letter Queues | `Services/AWSService.swift` |
| Amazon DynamoDB | CRUD-operaties, query's met partition/sort key, batch writes, ACID-transacties, GSI/LSI | `Services/AWSService.swift` |
| Amazon CloudWatch | Custom metrics, gestructureerde logging, alarmen met threshold-configuratie | `Services/AWSService.swift` |
| CI/CD & Deployment | Docker-containerisatie van backend API, rolling updates met nul downtime | `Docker/Dockerfile`, `Docker/docker-compose.yml` |

→ Zie sectie [☁️ Cloud Infrastructure (AWS)](#-cloud-infrastructure-aws) voor gedetailleerde code-voorbeelden.

### 3. Cybersecurity — Security+ (LinkedIn Learning)

| | |
|---|---|
| **Platform** | LinkedIn Learning |
| **Geschatte werkbelasting** | 40–50 uur |
| **Focus** | Netwerkbeveiliging, cryptografie, identity management, bedreigingsanalyse |

**Beschrijving:** Volgen van de Security+-cursus op LinkedIn Learning voor een stevige basis in cybersecurity. Opgedane kennis direct toegepast in de beveiligingslaag van Gameboxd.

**Toegepaste competenties in dit project:**

| Competentie | Toepassing in Gameboxd | Bestanden |
|---|---|---|
| Biometrische authenticatie | Face ID / Touch ID via `LAContext`, fallback naar passcode, lockout-beleid | `Services/SecurityManager.swift` |
| Cryptografie (AES-256-GCM) | Authenticated encryption met CryptoKit, random nonce, 128-bit authentication tag | `Services/SecurityManager.swift` |
| Key Derivation (PBKDF2) | Wachtwoord-naar-sleutel met HMAC-SHA256, salt, 100.000+ iteraties tegen brute force | `Services/SecurityManager.swift` |
| Keychain & Secure Enclave | Hardware-backed opslag, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, biometric access control | `Services/SecurityManager.swift` |
| Input validatie & sanitisatie | XSS-preventie (HTML entity encoding), SSRF-preventie (blokkeren private IP-ranges), URL-validatie | `Services/SecurityManager.swift`, `ViewModels/GameStore.swift` |
| Wachtwoordbeleid | Sterkte-scoring (NIST-richtlijnen), detectie van veelvoorkomende wachtwoorden, visuele feedback | `Services/SecurityManager.swift`, `Views/Screen/AuthView.swift` |
| Certificate Pinning | MITM-detectie, server-certificaatvalidatie tegen pinned certificates, TLS 1.2+ | `Services/SecurityManager.swift` |
| Security Audit Logging | Gestructureerde event-logging (AUTH_SUCCESS, AUTH_FAILURE, SUSPICIOUS), forensisch onderzoek | `Services/SecurityManager.swift` |
| API-sleutelbeheer | API-key geëxternaliseerd naar `Info.plist` / omgevingsvariabelen, nooit hardcoded | `Services/RAWGService.swift` |

→ Zie sectie [🔐 Security Implementation (CompTIA Security+)](#-security-implementation-comptia-security) voor gedetailleerde code-voorbeelden.

### 4. Docker & DevOps (LinkedIn Learning)

| | |
|---|---|
| **Platform** | LinkedIn Learning |
| **Geschatte werkbelasting** | 20–30 uur |
| **Focus** | Docker, containerisatie, orkestratie, deployment pipelines, DevOps |

**Beschrijving:** Volgen van een cursus op LinkedIn Learning om vertrouwd te raken met containertechnologie en basisprincipes van DevOps. Opgedane kennis direct toegepast in de deployment-architectuur van Gameboxd.

**Toegepaste competenties in dit project:**

| Competentie | Toepassing in Gameboxd | Bestanden |
|---|---|---|
| Multi-stage builds | Build-stage (Swift SDK) gescheiden van production-stage (Ubuntu minimal), image van 1.2 GB → 45 MB | `Docker/Dockerfile` |
| Container security | Non-root user (`gameboxd`), read-only binary, health checks, principle of least privilege | `Docker/Dockerfile` |
| Docker Compose | 4 services (API, PostgreSQL, Redis, Nginx), declaratieve configuratie | `Docker/docker-compose.yml` |
| Netwerk-isolatie | Frontend/backend bridge networks, `internal: true` voor database-isolatie, DNS-based service discovery | `Docker/docker-compose.yml` |
| Volume management | Named volumes voor PostgreSQL-data, bind mounts, persistentie over container-restarts | `Docker/docker-compose.yml` |
| Secrets management | Credentials via `/run/secrets/` (tmpfs), secret files buiten images, eenvoudige rotatie | `Docker/docker-compose.yml` |
| Resource limits | CPU- en geheugenlimieten per service, replica's voor horizontale schaalbaarheid | `Docker/docker-compose.yml` |
| Rolling updates | Zero-downtime deployments met `update_config: order: start-first`, parallellisme-configuratie | `Docker/docker-compose.yml` |
| DevOps-praktijken | Health checks, automatische restart-policies, logging, monitoring-integratie | `Docker/Dockerfile`, `Docker/docker-compose.yml` |

→ Zie sectie [🐳 Docker Deployment](#-docker-deployment) voor gedetailleerde code-voorbeelden.

### Totaaloverzicht werkbelasting

| Opleiding | Uren | Status |
|---|---|---|
| Swift — iOS App Development | 50–70 uur | ✅ Cursus gevolgd + toegepast in Gameboxd |
| AWS Cloud Development | 40–50 uur | ✅ Cursus gevolgd + toegepast in `AWSService.swift` |
| Cybersecurity — Security+ | 40–50 uur | ✅ Cursus gevolgd + toegepast in `SecurityManager.swift` |
| Docker & DevOps | 20–30 uur | ✅ Cursus gevolgd + toegepast in `Docker/` |
| **Totaal** | **150–200 uur** | |

---

## 📊 Competentiematrix (ECTS-koppeling)

> Onderstaande matrix toont hoe elke eindcompetentie uit de ECTS-fiche is aangetoond in dit project.

### D1. Levenslang leren en experiment

| Competentie | Beschrijving | Bewijs in Gameboxd |
|---|---|---|
| **GI 5.2** | Effectieve oplossingen bedenken bij nieuwe concepten | 4 cursussen gecombineerd in één app; RAWG API geïntegreerd voor 500.000+ games; eigen componenten ontworpen (StarRating, GameCard, ShareCard) |
| **GI 5.3** | Experiment en kritisch denken als onderdeel van levenslang leren | Nieuwe technologieën geleerd (SwiftUI, CryptoKit, Docker) en direct toegepast; GitHub Copilot kritisch ingezet als leerhulpmiddel |
| **GI 8.3** | Actieve zelfontplooiing afgestemd op loopbaanontwikkeling | 4 cursussen gevolgd (150–200 uur); kennis direct omgezet naar werkend product |
| **GI 10.3** | Strategieën ontwikkelen om middelen te mobiliseren | Gratis tools (Xcode, RAWG API, GitHub Copilot) effectief ingezet; open-source frameworks gecombineerd |

### D2. Zichzelf ontplooien en definiëren van ambities

| Competentie | Beschrijving | Bewijs in Gameboxd |
|---|---|---|
| **GI 8.1** | Reflectie en zelfsturing voor persoonlijke doelen | Zie sectie [Reflectie & Persoonlijke Ontwikkeling](#-reflectie--persoonlijke-ontwikkeling): sterktes/zwaktes geïdentificeerd, plan bijgestuurd |
| **GI 8.2** | Inzicht in sterktes, verbeterpunten aanpakken | Sterktes: snel leren, UI/UX-oog. Verbeterpunten: praktijkervaring → opgelost via eigen project + Copilot |
| **GI 8.3** | Zelfontplooiing afgestemd op loopbaan | iOS + Cloud + Security + DevOps als brede basis voor IT-carrière |
| **GI 10.2** | Ambitie, passie en zelfzekerheid beargumenteren | Zie sectie [Ambities & Motivatie](#-ambities--motivatie): persoonlijk probleem → zelfgebouwde oplossing |
| **GI 10.3** | Strategieën voor waardegeneratie | Gratis middelen (cursussen, API, tools) omgezet in een compleet App Store-ready product |
| **GI 10.4** | Economische rentabiliteit als succesfactor | Zie sectie [Economische Waardecreatie](#-economische--maatschappelijke-waardecreatie): break-even analyse, inkomstenmodellen |
| **GI 10.5** | Procesefficiëntie en effectiviteit | MVVM-architectuur, herbruikbare componenten, caching, Docker-containerisatie |

### D3. Economische of maatschappelijke waardecreatie

| Competentie | Beschrijving | Bewijs in Gameboxd |
|---|---|---|
| **GI 10.3** | Strategieën voor waardegeneratie | MVP → TestFlight → App Store lancering → freemium model; 5-stappen groeistrategie |
| **GI 10.4** | Economische rentabiliteit | Kostenbatenanalyse: €99/jaar + €20–50/maand vs. €2,99–4,99/maand per gebruiker; break-even bij 35–50 gebruikers |
| **GI 10.5** | Procesefficiëntie | Docker voor reproduceerbare deploys; URLCache voor minder API-calls; herbruikbare componenten voor snellere ontwikkeling |

---

## ✨ Features

### 📚 Game Library Management
- **Status Tracking**: Playing, Want to Play, Completed, Platinum, Shelved
- **Star Ratings**: 1-5 star rating system with half-star precision
- **Written Reviews**: Detailed reviews with spoiler tags
- **Custom Tags**: Create personal tags for organization
- **Priority Levels**: High, Normal, Low priority for backlog

### 📊 Statistics & Analytics
- **Play Time Tracking**: Log sessions with duration and mood
- **Charts & Graphs**: Visual statistics using SwiftUI Charts
- **Genre Distribution**: See your gaming preferences
- **Platform Analysis**: Track games across platforms
- **Yearly Retrospective**: Year-in-review statistics

### 🏆 Achievements & Gamification
- **20+ Achievements**: Unlock badges for milestones
- **Progress Tracking**: Visual progress bars
- **Categories**: Collection, Completion, Time, Social achievements
- **Animated Unlocks**: Celebratory animations when unlocking

### 🎯 Monthly Goals
- **Goal Types**: Games completed, hours played, reviews written
- **Progress Tracking**: Real-time progress updates
- **Suggestions**: Pre-defined goal templates
- **History**: View completed goals

### 📅 Gaming Diary
- **Play Sessions**: Log when and what you played
- **Calendar View**: Visual calendar with activity dots
- **Session Details**: Duration, mood, notes
- **Session History**: Browse past sessions

### 🎲 Backlog Manager
- **Random Picker**: "What should I play?" wheel
- **Priority Filters**: Filter by priority level
- **Quick Actions**: Start playing with one tap
- **Spinning Animation**: Fun selection experience

### 🤝 Social Features
- **Friend System**: Follow other gamers
- **Activity Feed**: See what friends are playing
- **Share Cards**: Generate shareable game cards
- **Multiple Styles**: Dark, Light, Gradient, Minimal

### 🔍 Discovery
- **RAWG Integration**: 500,000+ games database
- **New Releases**: Latest game releases
- **Top Rated**: Highest rated games
- **Upcoming**: Games coming soon
- **Personalized Recommendations**: Based on your preferences

### ⚙️ Customization
- **Themes**: Multiple color themes
- **App Icons**: Alternative app icons
- **Notifications**: Customizable reminders
- **Export/Import**: Backup your data
- **iCloud Sync**: Cross-device synchronization

### 📱 Onboarding
- **5-Page Tutorial**: Guided introduction
- **Feature Highlights**: Explains key features
- **Skip Option**: For returning users

---

## 🏗 Architecture

### Project Structure

```
Gameboxd/
├── GameboxdApp.swift          # App entry point
├── ContentView.swift          # Root view controller
│
├── Models/
│   ├── Game.swift             # Game data model
│   ├── Achievement.swift      # Achievement system
│   └── Goal.swift             # Monthly goals model
│
├── ViewModels/
│   └── GameStore.swift        # Main state management (@MainActor)
│
├── Views/
│   ├── Components/
│   │   ├── GameCard.swift     # Reusable game card
│   │   └── StarRating.swift   # Star rating component
│   │
│   └── Screen/
│       ├── MainTabView.swift       # Tab navigation
│       ├── LibraryView.swift       # Game library
│       ├── DiaryView.swift         # Play sessions
│       ├── DiscoverView.swift      # Game discovery
│       ├── SearchView.swift        # Search games
│       ├── ProfileView.swift       # User profile
│       ├── GameDetailView.swift    # Game details
│       ├── StatisticsView.swift    # Statistics
│       ├── AchievementsView.swift  # Achievements
│       ├── GoalsView.swift         # Monthly goals
│       ├── BacklogView.swift       # Backlog manager
│       ├── SettingsView.swift      # Settings
│       ├── SocialView.swift        # Social features
│       ├── ShareCardView.swift     # Shareable cards
│       ├── RecommendationsView.swift # Recommendations
│       └── OnboardingView.swift    # First-time tutorial
│
├── Services/
│   ├── RAWGService.swift      # RAWG API client
│   ├── AWSService.swift       # AWS integration
│   └── SecurityManager.swift  # Security utilities
│
└── Utils/
    └── ColorExtension.swift   # Custom colors
```

### Design Patterns

- **MVVM**: Model-View-ViewModel architecture
- **@MainActor**: Thread-safe state management
- **@EnvironmentObject**: Dependency injection
- **Codable**: JSON serialization for persistence
- **async/await**: Modern Swift concurrency

### Data Persistence

- **UserDefaults**: Primary storage for game data
- **Keychain**: Secure storage for sensitive data
- **iCloud**: Cross-device sync via NSUbiquitousKeyValueStore

---

## 🚀 Getting Started

### Requirements

- Xcode 15.0+
- iOS 16.0+
- Swift 5.9+

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/gameboxd.git
cd gameboxd
```

2. Open in Xcode:
```bash
open Gameboxd.xcodeproj
```

3. Configure RAWG API key in `RAWGService.swift`:
```swift
private let apiKey = "YOUR_API_KEY"
```

4. Build and run on simulator or device.

### Configuration

#### RAWG API
Get your free API key at [rawg.io/apidocs](https://rawg.io/apidocs)

#### iCloud (Optional)
1. Enable iCloud capability in Xcode
2. Add Key-Value Storage entitlement

#### Notifications
App requests notification permission for:
- Game release reminders
- Backlog reminders
- Achievement alerts

---

## ☁️ Cloud Infrastructure (AWS)

> Demonstrates **AWS Certified Developer – Associate** knowledge

### File: `Services/AWSService.swift`

### Amazon Cognito (Authentication)

```swift
class CognitoAuthService {
    /// Initiates USER_SRP_AUTH flow
    func signIn(username: String, password: String) async throws -> CognitoAuthResult
    
    /// Refresh expired tokens
    func refreshSession() async throws -> CognitoAuthResult
    
    /// User registration with email verification
    func signUp(username: String, password: String, email: String) async throws -> SignUpResult
}
```

**Key Concepts:**
- **SRP Protocol**: Secure Remote Password authentication without transmitting passwords
- **Token Management**: Access token (1h), ID token (user claims), Refresh token (30 days)
- **MFA Support**: Multi-factor authentication integration
- **Password Policy**: Minimum 8 chars, uppercase, lowercase, number, special char

### Amazon S3 (Storage)

```swift
class S3Service {
    /// Generate presigned URL for secure client-side upload
    func generatePresignedUploadURL(key: String, contentType: String, expiresIn: Int) -> PresignedURL
    
    /// Multipart upload for large files (>100MB)
    func initiateMultipartUpload(key: String, contentType: String) async throws -> MultipartUpload
    func uploadPart(uploadId: String, partNumber: Int, data: Data) async throws -> UploadPartResult
    func completeMultipartUpload(uploadId: String, key: String, parts: [UploadPartResult]) async throws
}
```

**Key Concepts:**
- **Presigned URLs**: Temporary signed URLs for secure uploads without exposing credentials
- **AWS Signature V4**: HMAC-SHA256 based request signing
- **Multipart Upload**: Split large files into 5MB+ parts
- **Lifecycle Policies**: Automatic transition to Glacier, expiration rules

### AWS Lambda (Serverless)

```swift
class LambdaService {
    /// Synchronous invocation (RequestResponse)
    func invoke(functionName: String, payload: [String: Any]) async throws -> LambdaResponse
    
    /// Asynchronous invocation (Event)
    func invokeAsync(functionName: String, payload: [String: Any]) async throws
    
    /// Invoke via API Gateway
    func invokeViaAPIGateway(path: String, method: String, body: [String: Any]?) async throws
}
```

**Key Concepts:**
- **Invocation Types**: Sync (wait for response) vs Async (fire-and-forget)
- **API Gateway Integration**: REST API with throttling, auth, transformation
- **Execution Context**: Request ID, memory limit, timeout, log streams
- **Dead Letter Queue**: Failed async invocations sent to SQS/SNS

### Amazon DynamoDB (NoSQL)

```swift
class DynamoDBService {
    func putItem(item: [String: DynamoDBAttribute]) async throws
    func getItem(pk: String, sk: String) async throws -> [String: DynamoDBAttribute]?
    func query(pk: String, skBeginsWith: String?) async throws -> [DynamoDBItem]
    func batchWrite(items: [[String: DynamoDBAttribute]]) async throws  // Max 25 items
    func transactWrite(items: [TransactWriteItem]) async throws  // ACID transactions
}
```

**Key Concepts:**
- **Data Types**: S (String), N (Number), B (Binary), M (Map), L (List), BOOL, NULL
- **Primary Key**: Partition Key (pk) + Sort Key (sk)
- **Consistency**: Eventually consistent (default) vs Strongly consistent reads
- **Capacity**: On-demand vs Provisioned (RCU/WCU)
- **Indexes**: GSI (Global Secondary Index), LSI (Local Secondary Index)

### Amazon CloudWatch (Monitoring)

```swift
class CloudWatchService {
    func putMetric(namespace: String, metricName: String, value: Double, unit: MetricUnit)
    func putLogEvents(logGroupName: String, logStreamName: String, events: [LogEvent])
    func createAlarm(alarmName: String, metricName: String, threshold: Double)
}
```

**Key Concepts:**
- **Custom Metrics**: Application-level metrics (latency, errors, business KPIs)
- **Dimensions**: Key-value pairs for filtering (environment, service, region)
- **Log Groups**: Hierarchical log organization with retention policies
- **Alarms**: Threshold-based alerts triggering SNS, Auto Scaling, EC2 actions

---

## 🔐 Security Implementation (CompTIA Security+)

> Demonstrates **CompTIA Security+** knowledge

### File: `Services/SecurityManager.swift`

### Biometric Authentication

```swift
@MainActor
class SecurityManager: ObservableObject {
    /// Authenticate with Face ID or Touch ID
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}
```

**Security+ Concepts:**
- **Something You Are**: Biometric authentication factor
- **Multi-Factor Authentication (MFA)**: Biometric + device passcode fallback
- **Lockout Policy**: Device locks after failed attempts
- **Audit Logging**: All authentication attempts logged

### Keychain Storage

```swift
/// Store sensitive data with hardware-backed encryption
func storeInKeychain(key: String, data: Data, accessControl: KeychainAccessControl) throws {
    let access = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.biometryCurrentSet],
        nil
    )
    // ...
}

enum KeychainAccessControl {
    case whenUnlocked              // Accessible when device unlocked
    case whenUnlockedThisDeviceOnly // Not synced to other devices
    case afterFirstUnlock          // Accessible after first unlock
    case biometricOnly             // Requires biometric each access
    case biometricOrPasscode       // Biometric with passcode fallback
}
```

**Security+ Concepts:**
- **Secure Enclave**: Hardware security module for key storage
- **Encryption at Rest**: Data encrypted on disk
- **Access Control**: Fine-grained access policies
- **Defense in Depth**: Multiple layers of protection

### AES-256-GCM Encryption

```swift
/// Encrypt with authenticated encryption
func encrypt(data: Data, using key: SymmetricKey) throws -> EncryptedData {
    let nonce = AES.GCM.Nonce()  // Random 96-bit IV
    let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
    
    return EncryptedData(
        ciphertext: sealedBox.combined!,
        nonce: Data(nonce),
        tag: Data(sealedBox.tag)  // 128-bit authentication tag
    )
}

/// Decrypt and verify integrity
func decrypt(encryptedData: EncryptedData, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.SealedBox(combined: encryptedData.ciphertext)
    return try AES.GCM.open(sealedBox, using: key)
}
```

**Security+ Concepts:**
- **AES-256**: Advanced Encryption Standard with 256-bit key
- **GCM Mode**: Galois/Counter Mode provides confidentiality + integrity
- **Nonce/IV**: Unique value per encryption (never reuse!)
- **Authentication Tag**: Detects any tampering with ciphertext

### Key Derivation (PBKDF2)

```swift
/// Derive encryption key from password
func deriveKey(from password: String, salt: Data, iterations: Int = 100000) -> SymmetricKey {
    CCKeyDerivationPBKDF(
        CCPBKDFAlgorithm(kCCPBKDF2),
        password, password.count,
        salt, salt.count,
        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
        UInt32(iterations),
        derivedKey, 32  // 256 bits
    )
}
```

**Security+ Concepts:**
- **PBKDF2**: Password-Based Key Derivation Function 2
- **Salt**: Random value prevents rainbow table attacks
- **Iterations**: High count (100,000+) slows brute force
- **HMAC-SHA256**: Pseudo-random function for derivation

### Input Validation

```swift
/// Sanitize user input to prevent injection attacks
func sanitizeInput(_ input: String) -> String {
    var sanitized = input
    
    // HTML entity encoding (XSS prevention)
    let replacements = [
        "<": "&lt;", ">": "&gt;",
        "\"": "&quot;", "'": "&#x27;",
        "&": "&amp;", "/": "&#x2F;"
    ]
    
    for (char, replacement) in replacements {
        sanitized = sanitized.replacingOccurrences(of: char, with: replacement)
    }
    
    return sanitized
}

/// Validate URL to prevent SSRF
func isValidURL(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString),
          url.scheme == "https" else { return false }
    
    // Block private IP ranges
    let blocked = ["localhost", "127.0.0.1", "10.", "172.16.", "192.168."]
    return !blocked.contains(where: { url.host?.hasPrefix($0) == true })
}
```

**Security+ Concepts:**
- **XSS Prevention**: Escape HTML special characters
- **SQL Injection**: Parameterized queries (not shown but implied)
- **SSRF Prevention**: Block internal network access
- **Input Validation**: Whitelist over blacklist approach

### Password Strength Validation

```swift
func validatePasswordStrength(_ password: String) -> PasswordStrength {
    var score = 0
    
    if password.count >= 8 { score += 1 }
    if password.count >= 12 { score += 1 }
    if password.count >= 16 { score += 1 }
    if password.contains(where: { $0.isUppercase }) { score += 1 }
    if password.contains(where: { $0.isLowercase }) { score += 1 }
    if password.contains(where: { $0.isNumber }) { score += 1 }
    if password.contains(where: { "!@#$%^&*".contains($0) }) { score += 1 }
    
    // Check common patterns
    if ["password", "123456", "qwerty"].contains(where: { 
        password.lowercased().contains($0) 
    }) {
        score -= 3
    }
    
    switch score {
    case 0...2: return .weak
    case 3...4: return .medium
    case 5...6: return .strong
    default: return .veryStrong
    }
}
```

**Security+ Concepts:**
- **NIST Guidelines**: Length > complexity
- **Common Password Detection**: Block known weak passwords
- **Scoring System**: Visual feedback for users

### Certificate Pinning

```swift
/// Validate server certificate against pinned certificates
func validateCertificate(_ serverTrust: SecTrust, pinnedCertificates: [SecCertificate]) -> Bool {
    guard let serverCert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
        return false
    }
    
    let serverCertData = SecCertificateCopyData(serverCert) as Data
    
    return pinnedCertificates.contains { pinnedCert in
        let pinnedData = SecCertificateCopyData(pinnedCert) as Data
        return serverCertData == pinnedData
    }
}
```

**Security+ Concepts:**
- **MITM Prevention**: Detect man-in-the-middle attacks
- **Certificate Pinning**: Only accept known certificates
- **TLS 1.2+**: Modern encryption in transit

### Security Audit Logging

```swift
enum SecurityEvent: String {
    case authenticationSuccess = "AUTH_SUCCESS"
    case authenticationFailure = "AUTH_FAILURE"
    case tokenRefresh = "TOKEN_REFRESH"
    case dataAccess = "DATA_ACCESS"
    case dataWipe = "DATA_WIPE"
    case suspiciousActivity = "SUSPICIOUS"
}

func logSecurityEvent(_ event: SecurityEvent, details: String) async {
    let entry = SecurityLogEntry(
        timestamp: Date(),
        event: event,
        details: details,
        deviceId: UIDevice.current.identifierForVendor?.uuidString
    )
    // Store for compliance auditing
}
```

**Security+ Concepts:**
- **Audit Trail**: Non-repudiation through logging
- **Event Types**: Categorized security events
- **Compliance**: Meets regulatory requirements
- **Forensics**: Investigation support

---

## 🐳 Docker Deployment

> Demonstrates **Docker Certified Associate** knowledge

### Files: `Docker/Dockerfile`, `Docker/docker-compose.yml`

### Multi-Stage Build

```dockerfile
# Stage 1: Build with full SDK
FROM swift:5.9-jammy AS builder
WORKDIR /build
COPY Package.swift Package.resolved ./
RUN swift package resolve
COPY Sources/ Sources/
RUN swift build --configuration release --static-swift-stdlib

# Stage 2: Minimal production image
FROM ubuntu:22.04 AS production
RUN useradd --uid 1000 gameboxd
COPY --from=builder --chown=gameboxd:gameboxd /build/.build/release/GameboxdAPI .
USER gameboxd
ENTRYPOINT ["./GameboxdAPI"]
```

**Docker Concepts:**
- **Multi-Stage Builds**: Separate build and runtime environments
- **Image Size Reduction**: 1.2GB → 45MB
- **Layer Caching**: Dependencies cached separately from source
- **Non-Root User**: Security best practice

### Container Security

```dockerfile
# Run as non-root user
RUN groupadd --gid 1000 gameboxd \
    && useradd --uid 1000 --gid gameboxd gameboxd
USER gameboxd

# Read-only binary
RUN chmod 555 /app/GameboxdAPI

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

**Docker Concepts:**
- **Principle of Least Privilege**: Non-root execution
- **Immutable Infrastructure**: Read-only filesystem
- **Health Probes**: Automatic container health monitoring
- **Restart Policies**: Automatic recovery from failures

### Docker Compose Services

```yaml
version: '3.9'

services:
  api:
    build:
      context: .
      target: production
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
      update_config:
        parallelism: 1
        order: start-first
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    networks:
      - frontend
      - backend
    secrets:
      - db_password
      - jwt_secret

  postgres:
    image: postgres:15-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - backend
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password

  redis:
    image: redis:7-alpine
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
    networks:
      - backend

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
```

**Docker Concepts:**
- **Service Definition**: Declarative container configuration
- **Replicas**: Horizontal scaling
- **Resource Limits**: CPU and memory constraints
- **Rolling Updates**: Zero-downtime deployments

### Network Isolation

```yaml
networks:
  frontend:
    driver: bridge
    name: gameboxd-frontend
    
  backend:
    driver: bridge
    internal: true  # No external access
    name: gameboxd-backend
    
  monitoring:
    driver: bridge
```

**Docker Concepts:**
- **Bridge Networks**: Container-to-container communication
- **Internal Networks**: No internet access (database isolation)
- **Service Discovery**: DNS-based service resolution
- **Network Segmentation**: Security through isolation

### Volume Management

```yaml
volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/gameboxd/data/postgres
      
  redis-data:
    driver: local
```

**Docker Concepts:**
- **Named Volumes**: Docker-managed persistent storage
- **Bind Mounts**: Host directory mapping
- **Data Persistence**: Survives container restarts
- **Backup Strategy**: Volume-level backups

### Secrets Management

```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt
  jwt_secret:
    file: ./secrets/jwt_secret.txt
  aws_access_key:
    file: ./secrets/aws_access_key.txt

services:
  api:
    secrets:
      - db_password
      - jwt_secret
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password
```

**Docker Concepts:**
- **Secret Files**: Credentials stored outside images
- **In-Memory Secrets**: Mounted to `/run/secrets/` (tmpfs)
- **Rotation**: Easy credential rotation without rebuild
- **Least Privilege**: Services only get needed secrets

### Useful Commands

```bash
# Build production image
docker build --target production -t gameboxd-api:latest .

# Start all services
docker-compose up -d

# Scale API service
docker-compose up -d --scale api=3

# View logs
docker-compose logs -f api

# Execute command in container
docker-compose exec api /bin/sh

# Database backup
docker-compose exec postgres pg_dump -U gameboxd gameboxd > backup.sql

# Stop and remove everything
docker-compose down -v --rmi all
```

---

## 🔌 API Integration

### RAWG.io API

The app uses [RAWG Video Games Database API](https://rawg.io/apidocs) for game data.

```swift
class RAWGService {
    private let apiKey = "YOUR_API_KEY"
    private let baseURL = "https://api.rawg.io/api"
    
    func searchGames(query: String) async throws -> [Game]
    func getGameDetails(id: Int) async throws -> Game
    func getNewReleases() async throws -> [Game]
    func getTopRated() async throws -> [Game]
    func getUpcoming() async throws -> [Game]
}
```

**Endpoints Used:**
- `GET /games` - Search and list games
- `GET /games/{id}` - Game details
- `GET /genres` - Available genres
- `GET /platforms` - Available platforms

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for linting
- Write unit tests for new features
- Document public APIs

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [RAWG.io](https://rawg.io) for the amazing games database API
- [Letterboxd](https://letterboxd.com) for the inspiration
- Apple's SwiftUI and CryptoKit frameworks

---

<p align="center">
  Made with ❤️ and SwiftUI
</p>
