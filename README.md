# Team Ragnarok ASD App

Team Ragnarok ASD Management Application - A comprehensive martial arts school management system built with Flutter and Supabase.

## Features

- Student registration and management
- Class scheduling and booking
- Instructor dashboard and management
- Payment processing and receipt generation
- Medical certificate tracking
- Admin management system
- Real-time notifications
- Multi-role authentication

## Getting Started

This project is a Flutter application with Supabase backend integration.

### Prerequisites

- Flutter SDK ≥ 3.10
- Dart SDK ≥ 3.0
- Android Studio / VS Code
- Supabase account and project

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure your environment variables in `env.json`
4. Run `flutter run` to start the application

## Project Structure

- `lib/` - Main application code
- `lib/presentation/` - UI screens and widgets  
- `lib/services/` - Business logic and API services
- `lib/core/` - Core utilities and exports
- `lib/theme/` - Application theming
- `lib/routes/` - Navigation routing
- `android/` - Android-specific configuration
- `ios/` - iOS-specific configuration

## Build Instructions

### Debug Build
```bash
flutter run
```

### Release APK
```bash
flutter build apk --release
```

### Release Bundle
```bash
flutter build appbundle --release
```

## Environment Configuration

Configure the following environment variables in `env.json`:

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anonymous key

## License

This project is proprietary software developed for Team Ragnarok ASD.