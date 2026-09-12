# Spendly AI --- Milestones

> **Arbeidstittel:** Spendly AI\
> **Plattform:** iPhone / iPad\
> **Teknologi:** SwiftUI + SwiftData\
> **Mål:** Gjøre privatøkonomi enkel, visuell og handlingsorientert ved
> å vise hva brukeren trygt kan bruke i dag, og gi korte AI-baserte råd
> uten å moralisere.

------------------------------------------------------------------------

## 0. Produktidé

Spendly AI skal ikke være enda en komplisert budsjett-app full av
regneark. Appen skal svare på ett enkelt spørsmål:

**«Hvor mye kan jeg trygt bruke i dag?»**

Eksempel:

> God morgen! Du har ca. 240 kr tilgjengelig i dag. Hvis du bruker under
> 150 kr i dag og i morgen, ligger du fortsatt godt an til målet ditt på
> fredag.

AI skal forklare brukerens egne budsjettdata på vanlig språk. Selve
økonomiske beregningen skal gjøres deterministisk i appen --- AI skal
ikke få lov til å finne på saldoer eller regnestykker.

------------------------------------------------------------------------

# MILESTONE 1 --- Opprett prosjektet

-   [x] Opprett nytt Xcode-prosjekt
-   [x] Interface: SwiftUI
-   [x] Language: Swift
-   [x] Storage: SwiftData
-   [x] Aktiver Git fra starten
-   [x] Velg endelig Bundle Identifier
-   [x] Sett første versjon til `0.1`
-   [x] Sett Build til `1`
-   [x] Endre `ContentView` til `DashboardView`
-   [x] Opprett `RootTabView`
-   [ ] Kontroller at appen bygger på simulator og fysisk iPhone

### Foreslått mappestruktur

``` text
SpendlyAI/
├── App/
│   └── SpendlyAIApp.swift
├── Models/
├── Views/
│   ├── Dashboard/
│   ├── Transactions/
│   ├── Insights/
│   ├── Goals/
│   ├── Onboarding/
│   └── Settings/
├── ViewModels/
├── Services/
│   ├── AI/
│   ├── Budget/
│   └── Notifications/
├── Components/
├── Extensions/
├── Localization/
├── Resources/
└── Config/
```

------------------------------------------------------------------------

# MILESTONE 2 --- Grunnoppsett

-   [x] Lag `RootTabView`
-   [x] Faner: Home, Transactions, AI, Goals og Settings
-   [x] Lag gjenbrukbar app-stil
-   [x] Støtt Light / Dark / System
-   [x] Lag `SettingsView`
-   [x] Vis appnavn
-   [x] Vis Version og Build
-   [x] Legg inn lokaliseringsstruktur
-   [x] Språk: English
-   [x] Språk: Norsk
-   [x] Språk: Thai
-   [x] Ingen hardkodede brukerstrenger i Views

------------------------------------------------------------------------

# MILESTONE 3 --- SwiftData-modeller

Opprett minst:

### UserFinancialProfile

-   [x] Månedlig nettoinntekt
-   [x] Lønningsdato / budsjettperiode
-   [x] Valuta
-   [x] Ønsket minimumsbuffer
-   [x] Opprettet / sist endret

### FixedExpense

-   [x] Navn
-   [x] Beløp
-   [x] Forfallsdato
-   [x] Kategori
-   [x] Gjentakelse
-   [x] Aktiv / inaktiv

### Transaction

-   [x] Beløp
-   [x] Dato
-   [x] Kategori
-   [x] Beskrivelse
-   [x] Nødvendig / valgfritt
-   [x] Eventuelle notater

### SavingsGoal

-   [x] Navn
-   [x] Målbeløp
-   [x] Måldato
-   [x] Spart hittil
-   [x] Prioritet

### DailyBudgetSnapshot

-   [x] Dato
-   [x] Beregnet tilgjengelig beløp
-   [x] Brukt i dag
-   [x] Gjenstående trygt beløp

------------------------------------------------------------------------

# MILESTONE 4 --- Onboarding

Lag en kort onboarding som ikke føles som et regnskapsskjema.

-   [x] Velkomstskjerm
-   [x] Månedlig nettoinntekt
-   [x] Neste lønningsdato
-   [x] Faste månedlige utgifter
-   [x] Minimumsbuffer
-   [x] Første sparemål
-   [x] Valuta
-   [x] Oppsummering
-   [x] Lagre profilen i SwiftData
-   [x] Mulighet til å endre alt senere i Settings

**Mål:** Brukeren skal kunne komme fra installasjon til første
dagsbudsjett på få minutter.

------------------------------------------------------------------------

# MILESTONE 5 --- Budget Engine

Dette er appens viktigste del.

Lag en egen `BudgetService` som beregner tallene uten AI.

-   [x] Finn disponibelt beløp frem til neste inntekt
-   [x] Trekk fra kommende faste utgifter
-   [x] Reserver ønsket sparing
-   [x] Reserver minimumsbuffer
-   [x] Beregn antall dager igjen
-   [x] Beregn dagens anbefalte maksimum
-   [x] Oppdater etter hvert kjøp
-   [x] Håndter negative budsjetter
-   [ ] Håndter uregelmessig inntekt senere
-   [x] Unit tests for alle viktige beregninger

### Grunnprinsipp

``` text
Tilgjengelige penger
- kommende faste utgifter
- planlagt sparing
- sikkerhetsbuffer
= disponibelt beløp

Disponibelt beløp / dager igjen
= omtrentlig trygt dagsbudsjett
```

AI skal motta resultatene fra denne motoren --- ikke beregne dem selv.

------------------------------------------------------------------------

# MILESTONE 6 --- Dashboard

Dashboardet skal kunne forstås på noen sekunder.

-   [x] Stor visning: «Du kan trygt bruke ... i dag»
-   [x] SwiftUI Gauge/ring
-   [x] Brukt i dag
-   [x] Igjen i dag
-   [x] Dager til neste inntekt
-   [x] Kommende faste utgifter
-   [x] Fremdrift på viktigste sparemål
-   [x] Stor `+` knapp for nytt kjøp
-   [x] Dagens korte AI-innsikt
-   [x] Vis advarsel dersom budsjettet er presset

Unngå å fylle førstesiden med avanserte grafer.

------------------------------------------------------------------------

# MILESTONE 7 --- Registrere kjøp

MVP skal prioritere ekstremt rask manuell registrering.

-   [x] Beløp
-   [x] Kategori
-   [x] Kort beskrivelse
-   [x] Dato/tid
-   [x] Lagre
-   [x] Dashboard oppdateres umiddelbart
-   [x] Redigere transaksjon
-   [x] Slette transaksjon
-   [x] Transaksjonshistorikk
-   [x] Enkel kategorifiltrering

Senere kan bankintegrasjon vurderes. Ikke gjør dette til et krav for
første versjon.

------------------------------------------------------------------------

# MILESTONE 8 --- AI Assistant

Lag AI som en separat service.

-   [x] `AIService`
-   [x] Definer strukturert input til AI
-   [x] Send bare data AI faktisk trenger
-   [x] Lag systeminstruksjoner for økonomisk assistent
-   [x] AI må være kort, vennlig og konkret
-   [x] AI må aldri dikte opp økonomiske tall
-   [x] AI skal tydelig skille mellom budsjettveiledning og profesjonell
    finansiell rådgivning
-   [x] Håndter nettverksfeil
-   [x] Håndter API-feil
-   [x] Håndter manglende AI-tilgang
-   [x] Lag lokal fallback-tekst slik at appen fortsatt fungerer uten AI

### Eksempler på spørsmål

-   «Har jeg råd til å spise ute i kveld?»
-   «Hva skjer hvis jeg bruker 500 kr i dag?»
-   «Hvordan kan jeg nå sparemålet mitt denne måneden?»
-   «Hvor mye kan jeg bruke i helgen?»
-   «Hvorfor er dagsbudsjettet mitt lavere enn i går?»

### Viktig sikkerhet

**Ikke legg en hemmelig OpenAI API-nøkkel direkte i iOS-appen.**

Før produksjon skal AI-kall gå gjennom en sikker backend/proxy slik at
API-nøkkelen ikke kan hentes ut fra appen.

------------------------------------------------------------------------

# MILESTONE 9 --- Dagens AI-innsikt

-   [x] Generer dagens budskap fra faktiske budsjettdata
-   [x] Maks 1--3 korte setninger
-   [x] Unngå skyld, skam og moraliserende språk
-   [x] Gi konkrete alternativer
-   [x] Ikke anta at kaffe, restaurant eller andre kjøp alltid er
    «unødvendige»
-   [x] Forklar konsekvensen av et valg fremfor å bestemme for brukeren

Eksempel:

> Du har 240 kr tilgjengelig i dag. Holder du deg under 150 kr, får du
> omtrent 180 kr ekstra handlingsrom til helgen.

------------------------------------------------------------------------

# MILESTONE 10 --- Push-varsler

-   [x] Be om notification permission på riktig tidspunkt
-   [x] Innstilling for daglig morgenvarsel
-   [x] Standardforslag kl. 08:00
-   [x] Brukeren kan endre tidspunkt
-   [x] Brukeren kan slå varsler helt av
-   [x] Varsel skal bruke oppdaterte budsjettdata
-   [x] Ikke send sensitive økonomiske detaljer på låseskjermen uten at
    brukeren ønsker det

------------------------------------------------------------------------

# MILESTONE 11 --- Sparemål

-   [ ] Opprette flere mål
-   [ ] Beløp
-   [ ] Måldato
-   [ ] Fremdriftsring
-   [ ] Beregn nødvendig sparing per uke/måned
-   [ ] AI kan forklare hvordan dagens valg påvirker målet
-   [ ] Marker mål som fullført

Eksempler: bufferkonto, ferie, konsert, gjeld, ny telefon.

------------------------------------------------------------------------

# MILESTONE 12 --- Personvern og datasikkerhet

Økonomiske data er svært private.

-   [ ] Dataminimering
-   [ ] Lagre mest mulig lokalt
-   [ ] Ikke send komplette transaksjonshistorikker til AI uten behov
-   [ ] Ingen bankpassord eller BankID-data
-   [ ] Beskytt hemmeligheter på server
-   [ ] Vurder Keychain for sensitive lokale verdier
-   [ ] Mulighet til å slette brukerdata
-   [ ] Privacy Policy
-   [ ] Support-side
-   [ ] Forklar tydelig hvilke data som sendes til AI
-   [ ] Gjennomgå App Privacy i App Store Connect før innsending

------------------------------------------------------------------------

# MILESTONE 13 --- Betalingsmodell

Ikke lås MVP-en til én modell før den er testet.

Mulig modell:

### Gratis

-   [ ] Manuelt budsjett
-   [ ] Transaksjoner
-   [ ] Dagsbudsjett
-   [ ] Ett sparemål
-   [ ] Begrenset AI

### Spendly AI Plus

-   [ ] Flere mål

-   [ ] Flere AI-spørsmål

-   [ ] Avanserte prognoser

-   [ ] Ukentlig AI-oppsummering

-   [ ] Smarte scenarioer

-   [ ] Eksport / rapporter

-   [ ] Eventuell synkronisering mellom enheter

-   [ ] Bruk StoreKit 2

-   [ ] Restore Purchases

-   [ ] Test abonnement i Sandbox/TestFlight

-   [ ] Ikke bygg betalingsveggen før kjernefunksjonen faktisk gir verdi

------------------------------------------------------------------------

# MILESTONE 14 --- iCloud og flere enheter

Etter at lokal MVP fungerer stabilt:

-   [ ] Vurder CloudKit/iCloud-synk
-   [ ] Samme data på iPhone og iPad
-   [ ] Test konflikter
-   [ ] Test offline → online
-   [ ] Test sletting og reinstallasjon
-   [ ] Ikke la synkronisering blokkere første MVP

------------------------------------------------------------------------

# MILESTONE 15 --- Testing

-   [ ] Unit tests for Budget Engine
-   [ ] Test svært lav inntekt
-   [ ] Test utgifter større enn inntekt
-   [ ] Test null kroner tilgjengelig
-   [ ] Test negativt budsjett
-   [ ] Test månedsskifte
-   [ ] Test lønningsdato
-   [ ] Test forskjellige valutaer
-   [ ] Test norsk/engelsk/thai
-   [ ] Test Dark/Light/System
-   [ ] Test Dynamic Type
-   [ ] Test VoiceOver
-   [ ] Test uten internett
-   [ ] Test når AI-tjenesten er utilgjengelig
-   [ ] Test fysisk iPhone
-   [ ] Test iPad

------------------------------------------------------------------------

# MILESTONE 16 --- TestFlight

-   [ ] Opprett App ID
-   [ ] Opprett app i App Store Connect
-   [ ] Kontroller Bundle Identifier
-   [ ] Archive fra Xcode
-   [ ] Upload til App Store Connect
-   [ ] Internal Testing
-   [ ] Test onboarding med helt ny installasjon
-   [ ] Test AI-kostnader
-   [ ] Test varsler over flere dager
-   [ ] Samle tilbakemeldinger
-   [ ] Rett krasj og kritiske problemer
-   [ ] External Testing når appen er stabil

------------------------------------------------------------------------

# MILESTONE 17 --- App Store

-   [ ] Endelig appnavn
-   [ ] Appikon
-   [ ] Subtitle
-   [ ] App Description
-   [ ] Keywords
-   [ ] Screenshots
-   [ ] Privacy Policy URL
-   [ ] Support URL
-   [ ] App Privacy
-   [ ] Age Rating
-   [ ] Pris / abonnement
-   [ ] Subscription metadata hvis aktuelt
-   [ ] Review Notes
-   [ ] Demo-/testinformasjon dersom Apple trenger det
-   [ ] Version `1.0`
-   [ ] Production build
-   [ ] Send til App Review

------------------------------------------------------------------------

# ETTER 1.0 --- Mulige funksjoner

Ikke bygg disse før MVP-en er bevist.

-   [ ] Gjentakende transaksjoner oppdages automatisk
-   [ ] AI lærer brukerens forbruksmønstre
-   [ ] Ukentlig økonomisk oppsummering
-   [ ] Månedlig prognose
-   [ ] «Hva hvis?»-simulator
-   [ ] Kvitteringsskanning
-   [ ] CSV-import
-   [ ] Bankintegrasjon der det er juridisk og teknisk hensiktsmessig
-   [ ] Gjeldsnedbetalingsplan
-   [ ] Delte husholdningsbudsjetter
-   [ ] Widgets
-   [ ] Apple Watch
-   [ ] Siri/App Intents

------------------------------------------------------------------------

# Codex --- første oppdrag

Når prosjektet er opprettet, legg denne filen i prosjektets rotmappe og
be Codex lese den før den gjør endringer.

Første Codex-oppdrag bør være:

``` text
Read MILESTONES.md completely before making changes.

We are building Spendly AI as a SwiftUI + SwiftData iOS application.

Start ONLY with Milestone 1 and Milestone 2.

Requirements:
- Do not implement later milestones yet.
- Rename ContentView to DashboardView.
- Create RootTabView.
- Create the folder/file structure described in MILESTONES.md.
- Add SettingsView.
- Support Light, Dark and System appearance.
- Prepare localization for English, Norwegian and Thai.
- Display app version and build number in Settings.
- Keep the project compiling after every step.
- Do not add third-party dependencies unless explicitly approved.
- When finished, report exactly which checklist items were completed and which remain.
```

------------------------------------------------------------------------

# Definisjon av en vellykket MVP

Spendly AI er klar for første seriøse TestFlight-test når en ny bruker
kan:

1.  Legge inn inntekt og faste utgifter.
2.  Opprette et sparemål.
3.  Åpne appen og umiddelbart se et troverdig «trygt å bruke i
    dag»-beløp.
4.  Registrere et kjøp på få sekunder.
5.  Se dagsbudsjettet oppdatere seg korrekt.
6.  Spørre AI om konsekvensen av et kjøp.
7.  Få et kort, nyttig morgenvarsel.
8.  Forstå hvorfor appen anbefaler beløpet den viser.
9.  Bruke kjernefunksjonene selv om AI eller internett er utilgjengelig.

**Viktig produktregel:** Først bygger vi en god økonomimotor. Deretter
bruker vi AI til å forklare og gjøre den personlig.
