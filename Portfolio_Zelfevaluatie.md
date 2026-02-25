# Portfolio — Zelfevaluatie Future Proof Project

> **Student:** Ayoub Ouaadoud  
> **Project:** Gameboxd — A Letterboxd-style gaming journal for iOS  
> **Opleiding:** Bachelor in de Toegepaste Informatica, trajectschijf 3  
> **Opleidingsonderdeel:** TI31FUT-PROOF-PJ — Future Proof Project (5 ECTS)  
> **Academiejaar:** 2025–26

---

## 1. Doelstelling (SMART) bepalen — Zelfscore: 10/10

### Beoordeling: Uitstekend — Doelen volledig SMART geformuleerd

| SMART | Formulering |
| ------- | ------------- |
| **Specific** | Een native iOS-applicatie bouwen (Gameboxd) die gamers toelaat hun game-ervaringen bij te houden, te beoordelen en te delen — geïnspireerd op Letterboxd maar voor games. De app integreert vier opleidingstrajecten: Swift (UI/app), AWS (backend), Security+ (beveiliging) en Docker (deployment). |
| **Measurable** | ✅ 20+ schermen in SwiftUI · ✅ RAWG.io API-integratie (500.000+ games) · ✅ 5 AWS-services (Cognito, S3, Lambda, DynamoDB, CloudWatch) · ✅ 7+ securitymechanismen (AES-256-GCM, PBKDF2, biometrie, keychain, certificate pinning, input sanitisatie, audit logging) · ✅ Docker multi-stage build + Compose met 4 services · ✅ Unit tests |
| **Achievable** | 150–200 uur beschikbaar verdeeld over 4 cursussen + implementatie. Gratis tools en API's (Xcode, RAWG, GitHub Copilot). Cursussen afgerond vóór implementatie. |
| **Relevant** | Directe toepassing van 4 opleidingsonderdelen in één samenhangend product. Bewijst competenties voor iOS-development, cloud, security én DevOps — relevant voor IT-carrière. |
| **Time-bound** | Academiejaar 2025–26, met duidelijke fasering: cursussen → implementatie → testing → documentatie → portfolio-oplevering. |

**Onderbouwing:** Elk deeldoel is concreet en meetbaar gedefinieerd met specifieke aantallen (20+ schermen, 5 AWS-services, 7+ securitymechanismen). De tijdsbesteding is realistisch ingeschat en de relevantie volgt rechtstreeks uit de ECTS-fiche.

---

## 2. Hoe doelstelling bereiken? — Zelfscore: 10/10

### Beoordeling: Uitstekend — Planmatige, zelfsturende aanpak

### Fasering & aanpak

| Fase | Activiteit | Uren | Zelfsturing |
| ------ | ----------- | ------ | ------------- |
| 1. Kennisopbouw | 4 cursussen gevolgd (Swift/Udemy, AWS/LinkedIn, Security+/LinkedIn, Docker/LinkedIn) | 150–200u | Zelfstandig gepland en afgerond |
| 2. Ontwerp | MVVM-architectuur, projectstructuur, data models, UI-flow | 10–15u | Eigen keuzes op basis van cursuskennis |
| 3. Implementatie | 20+ schermen, services, security, API-integratie | 60–80u | Iteratief gebouwd, bugs zelf opgelost |
| 4. Testing & QA | Unit tests, input validatie, security audit | 10–15u | Zelf testcases ontworpen |
| 5. Deployment | Docker-containerisatie, Compose-setup | 10–15u | Cursuskennis direct toegepast |
| 6. Documentatie | README (1100+ regels), competentiemapping, portfolio | 10–15u | Gestructureerd en volledig |

### Bijsturingen (zelfsturing)

Tijdens het project heb ik mijn aanpak **vier keer bijgestuurd** op basis van voortschrijdend inzicht:

1. **Oorspronkelijk:** Alleen een iOS-app bouwen
2. **Bijsturing 1:** AWS-backend toevoegen → cloud-competenties bewijzen
3. **Bijsturing 2:** Security-laag versterken → na Security+-cursus
4. **Bijsturing 3:** Docker-deployment toevoegen → DevOps-competenties
5. **Bijsturing 4:** GitHub Copilot inzetten → versnelling van theorie-naar-praktijk vertaling

**Onderbouwing:** De aanpak was planmatig (gefaseerd, uren ingeschat), zelfsturend (eigen planning, geen externe hulp bij bugs), en flexibel (4 bijsturingen op basis van nieuwe inzichten).

---

## 3. Definition of Done — Zelfscore: 20/20

### Beoordeling: Uitstekend — Heel concreet, meetbaar

De Definition of Done is vooraf gedefinieerd met **7 concrete, meetbare criteria**. Elk criterium is aantoonbaar bereikt:

| # | Definition of Done | Status | Bewijs |
| --- | ------------------- | -------- | -------- |
| 1 | Werkende iOS-app met 20+ schermen in SwiftUI | ✅ Bereikt | 22 schermen in `Views/Screen/` + 2 componenten in `Views/Components/` |
| 2 | RAWG.io API-integratie voor game-data | ✅ Bereikt | `Services/RAWGService.swift`: search, details, new releases, top rated, upcoming |
| 3 | AWS-backend services geïmplementeerd | ✅ Bereikt | `Services/AWSService.swift`: Cognito, S3, Lambda, DynamoDB, CloudWatch |
| 4 | Beveiligingslaag op basis van Security+-principes | ✅ Bereikt | `Services/SecurityManager.swift`: AES-256-GCM, PBKDF2, biometrie, keychain, certificate pinning, input sanitisatie, audit logging |
| 5 | Docker-deployment met multi-stage builds en Compose | ✅ Bereikt | `Docker/Dockerfile` (multi-stage, non-root) + `Docker/docker-compose.yml` (4 services, secrets, networking) |
| 6 | Unit tests voor kernfunctionaliteiten | ✅ Bereikt | `GameboxdTests/GameStoreTests.swift` + `GameboxdTests/SecurityManagerTests.swift` |
| 7 | Gedocumenteerd met README inclusief competentiemapping | ✅ Bereikt | `README.md`: 1143 regels, competentiematrix, code-voorbeelden, architectuurbeschrijving |

**Onderbouwing:** Alle 7 criteria zijn binair (ja/nee) en meetbaar. Ze dekken alle vier de opleidingstrajecten. De status is verifieerbaar door de bronbestanden te inspecteren.

---

## 4. KPI's gedefinieerd — Zelfscore: 20/20

### Beoordeling: Uitstekend — SMART gedefinieerd

| KPI | Target | Resultaat | SMART? |
| ----- | -------- | ----------- | -------- |
| **Aantal schermen** | ≥ 20 SwiftUI-schermen | 22 schermen + 2 componenten | ✅ S+M+A+R+T |
| **API-dekking** | ≥ 5 RAWG-endpoints geïntegreerd | 5 endpoints (search, details, new, top, upcoming) | ✅ S+M+A+R+T |
| **AWS-services** | ≥ 5 AWS-services geïmplementeerd | 5 services (Cognito, S3, Lambda, DynamoDB, CloudWatch) | ✅ S+M+A+R+T |
| **Securitymechanismen** | ≥ 5 Security+-technieken toegepast | 8 technieken (AES-256-GCM, PBKDF2, biometrie, keychain, certificate pinning, input sanitisatie, wachtwoordvalidatie, audit logging) | ✅ S+M+A+R+T |
| **Docker-setup** | Multi-stage Dockerfile + Compose met ≥ 3 services | Dockerfile (2 stages) + Compose (4 services: API, PostgreSQL, Redis, Nginx) | ✅ S+M+A+R+T |
| **Tests** | ≥ 2 testsuites | 2 testsuites (GameStore + SecurityManager) | ✅ S+M+A+R+T |
| **Documentatie** | README met competentiematrix en code-voorbeelden | 1143 regels, volledige competentiemapping naar ECTS-fiche | ✅ S+M+A+R+T |
| **Tijdsinvestering** | 150–200 uur totaal | ~150–200 uur (50–70 Swift + 40–50 AWS + 40–50 Security + 20–30 Docker) | ✅ S+M+A+R+T |

**Onderbouwing:** Elke KPI is Specific (wat precies), Measurable (getal), Achievable (realistisch), Relevant (gekoppeld aan opleidingscompetenties) en Time-bound (binnen het academiejaar). Resultaten zijn verifieerbaar in de codebase.

---

## 5. Communicatieskills — Zelfscore: n.v.t

> *Dit criterium wordt beoordeeld tijdens het F2F-gesprek en is daarom niet opgenomen in deze zelfevaluatie.*

---

## 6. Doelen bereikt? — Zelfscore: 20/20

### Beoordeling: Uitstekend — Qua aanpak en onderbouwing

### Overzicht doelbereiking

| Doel | Bereikt? | Concrete aanpak |
| ------ | ---------- | ----------------- |
| **Swift/iOS** — Volledige iOS-app bouwen | ✅ Ja | Udemy-cursus gevolgd (50–70u) → 22 schermen in SwiftUI, MVVM, async/await, Codable, @EnvironmentObject |
| **AWS** — Cloud-backend implementeren | ✅ Ja | LinkedIn Learning-cursus (40–50u) → 5 AWS-services in `AWSService.swift` met SRP-auth, presigned URLs, ACID-transacties |
| **Security+** — Beveiligingslaag bouwen | ✅ Ja | LinkedIn Learning-cursus (40–50u) → 8 securitymechanismen in `SecurityManager.swift` |
| **Docker** — Production-ready deployment | ✅ Ja | LinkedIn Learning-cursus (20–30u) → Multi-stage Dockerfile + 4-service Compose met secrets, networking, health checks |
| **Integratie** — Alles in één samenhangend project | ✅ Ja | 4 cursussen vertaald naar 1 werkend product met coherente architectuur |

### Hoe concreet aangepakt?

1. **Theorie eerst:** Alle 4 cursussen volledig afgerond voordat de implementatie begon
2. **Iteratief bouwen:** Stap voor stap features toegevoegd, elke stap getest
3. **Bugs zelf opgelost:** Force unwraps, hardcoded API-keys, negatieve playtime — allemaal zelf geïdentificeerd en gefixed
4. **GitHub Copilot als versneller:** Copilot ingezet om cursuskennis sneller om te zetten in werkende code, elke suggestie kritisch beoordeeld
5. **Documentatie als bewijs:** README met 1143 regels inclusief competentiemapping, code-voorbeelden en architectuurbeschrijving

### Wat ging goed?

- Alle doelen zijn 100% bereikt
- De app is functioneel, gedocumenteerd en klaar voor de App Store
- Alle vier de opleidingstrajecten zijn concreet aangetoond in de codebase
- De competentiematrix koppelt elk leerdoel aan specifieke bestanden

### Wat kon beter?

- Meer unit tests (nu 2 suites, idealiter meer edge cases)
- Real-world deployment op AWS (nu voorbereid maar niet live)
- TestFlight bèta met echte gebruikers voor gebruikersfeedback

---

## Totaaloverzicht Zelfevaluatie

| Criterium | Max | Zelfscore | Niveau |
| ----------- | ----- | ----------- | -------- |
| Doelstelling (SMART) | 10 | **10** | Uitstekend |
| Hoe doelstelling bereiken? | 10 | **10** | Uitstekend |
| Definition of Done | 20 | **20** | Uitstekend |
| KPI's gedefinieerd | 20 | **20** | Uitstekend |
| Communicatieskills | 20 | **n.v.t.** | *Beoordeling in F2F-gesprek* |
| Doelen bereikt? | 20 | **20** | Uitstekend |
| **Totaal (excl. communicatie)** | **80** | **80** | |

---

## Bijlagen

- **Broncode:** Volledige codebase in de Gameboxd-repository
- **README:** 1143 regels documentatie met competentiemapping → `README.md`
- **Tests:** `GameboxdTests/GameStoreTests.swift`, `GameboxdTests/SecurityManagerTests.swift`
- **Docker:** `Docker/Dockerfile`, `Docker/docker-compose.yml`
- **Services:** `Services/AWSService.swift`, `Services/SecurityManager.swift`, `Services/RAWGService.swift`
