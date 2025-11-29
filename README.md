# Team Ragnarok ASD APP

Una moderna applicazione Flutter per la gestione della palestra di arti marziali Team Ragnarok ASD.

## Caratteristiche Principali

- 🥋 **Gestione Completa delle Discipline**: Karate, Judo, Aikido, Kendo e altre arti marziali
- 👥 **Sistema di Ruoli Avanzato**: Studenti, Istruttori e Amministratori con accesso personalizzato
- 📅 **Prenotazione Classi**: Sistema di prenotazione intelligente con calendario integrato
- 🏥 **Certificati Medici**: Upload e gestione automatica dei certificati medici
- 🧾 **Ricevute Italiane**: Sistema di generazione ricevute conforme alla normativa italiana
- 💳 **Gestione Abbonamenti**: Piani flessibili con sistema entry-based innovativo
- 📱 **Interfaccia Responsiva**: Design ottimizzato per smartphone, tablet e desktop
- 🔔 **Notifiche Automatiche**: Sistema di promemoria e comunicazioni integrate

## Aggiornamento Icona Applicazione

L'applicazione utilizza il logo ufficiale Team Ragnarok come icona dell'app su tutte le piattaforme.

### Per aggiornare le icone dell'applicazione:

1. **Preparazione**: Assicurarsi che l'immagine del logo si trovi in `assets/images/img_app_logo.svg`

2. **Generazione automatica icone**:
   ```bash
   # Installa le dipendenze
   flutter pub get
   
   # Genera le icone per tutte le piattaforme
   dart run flutter_launcher_icons
   ```

3. **Piattaforme supportate**:
   - **Android**: Genera icone adaptive e legacy in tutte le risoluzioni richieste
   - **iOS**: Crea icone per tutte le dimensioni dell'App Store e dispositivi
   - **Web**: Aggiorna favicon e icone del manifest per PWA

4. **Configurazione personalizzata**: 
   - Le icone Android utilizzano uno sfondo bianco con il logo come foreground
   - Le icone iOS mantengono le proporzioni originali del logo
   - Le icone Web sono ottimizzate per browser e PWA

### Struttura dei file icona generati:

```
android/app/src/main/res/
├── mipmap-hdpi/ic_launcher.png
├── mipmap-mdpi/ic_launcher.png
├── mipmap-xhdpi/ic_launcher.png
├── mipmap-xxhdpi/ic_launcher.png
└── mipmap-xxxhdpi/ic_launcher.png

ios/Runner/Assets.xcassets/AppIcon.appiconset/
├── Icon-App-20x20@1x.png
├── Icon-App-29x29@1x.png
└── [tutte le altre dimensioni iOS]

web/
├── favicon.png
└── icons/Icon-192.png, Icon-512.png
```

## Tecnologie Utilizzate

- **Framework**: Flutter 3.16.0+ / Dart 3.2.0+
- **Database**: Supabase (PostgreSQL)
- **Autenticazione**: Supabase Auth con RLS policies
- **State Management**: Provider + setState
- **Design System**: Material Design 3 con temi personalizzati
- **Icone**: flutter_launcher_icons per generazione automatica

## Installazione e Setup

1. **Clona il repository**:
   ```bash
   git clone [repository-url]
   cd team-ragnarok-app
   ```

2. **Installa le dipendenze**:
   ```bash
   flutter pub get
   ```

3. **Configura Supabase**:
   - Copia `env.json.example` in `env.json`
   - Inserisci le tue credenziali Supabase

4. **Genera le icone dell'app**:
   ```bash
   dart run flutter_launcher_icons
   ```

5. **Avvia l'applicazione**:
   ```bash
   flutter run
   ```

## Struttura del Progetto

```
lib/
├── presentation/          # Schermate e widget UI
├── services/             # Logica business e integrazione API
├── models/              # Modelli dati
├── core/                # Configurazioni e utilità core
├── theme/               # Temi e stili
├── constants/           # Costanti applicazione
└── routes/              # Configurazione routing

supabase/
└── migrations/          # Script migrazione database

assets/
└── images/              # Risorse immagini (incluso logo)
```

## Contribuire

1. Fork del repository
2. Crea un branch per la feature (`git checkout -b feature/AmazingFeature`)
3. Commit delle modifiche (`git commit -m 'Add some AmazingFeature'`)
4. Push del branch (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

## Licenza

Questo progetto è di proprietà di Team Ragnarok ASD. Tutti i diritti riservati.

## Contatti

**Team Ragnarok ASD**
- Email: info@teamragnarok.it
- Website: www.teamragnarok.it
- Sede: [Piazza caduti sul lavoro 13 Ravenna]

---

*Sviluppato con ❤️ per la comunità delle arti marziali Team Ragnarok*