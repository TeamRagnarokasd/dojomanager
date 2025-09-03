class AppConstants {
  // Team Information
  static const String teamName = 'Team Ragnarok ASD';
  static const String teamFiscalCode = '92100170395';
  static const String teamAddress = 'via giulio bezzi 25, 48026 Russi - RA';
  static const String teamLogo = 'assets/images/149054-1756519869859.jpg';

  // Martial Arts Disciplines - Corrected to remove karate, judo, taekwondo
  static const List<String> disciplines = ['BJJ', 'MMA', 'SAMBO', 'Grappling'];

  // App Configuration
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@teamragnarok.com';

  // UI Constants
  static const double defaultBorderRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const double cardElevation = 4.0;

  // Time Constants
  static const int sessionTimeoutMinutes = 30;
  static const int refreshIntervalSeconds = 300;

  // Notification Constants
  static const String defaultNotificationTitle = 'Team Ragnarok APP';
  static const int maxNotifications = 50;

  // Subscription Plans - 6 different subscription options
  static const List<Map<String, dynamic>> subscriptionPlans = [
    {
      "id": 1,
      "title": "Corso Singolo",
      "price": 60,
      "frequency": "Mensile",
      "paymentUrl": "https://pay.sumup.com/b2c/QHVYXRZR",
    },
    {
      "id": 2,
      "title": "Doppio Corso",
      "price": 95,
      "frequency": "Mensile",
      "paymentUrl": "https://pay.sumup.com/b2c/DOUBLEPLAN",
    },
    {
      "id": 3,
      "title": "Preparazione Atletica",
      "price": 30,
      "frequency": "Mensile",
      "paymentUrl": "https://pay.sumup.com/b2c/ATHLETIC",
    },
    {
      "id": 4,
      "title": "Corso Singolo + Prep. Atletica",
      "price": 90,
      "frequency": "Mensile",
      "paymentUrl": "https://pay.sumup.com/b2c/SINGLEPLUS",
    },
    {
      "id": 5,
      "title": "Doppio Corso + Prep. Atletica",
      "price": 120,
      "frequency": "Mensile",
      "paymentUrl": "https://pay.sumup.com/b2c/DOUBLEPLUS",
    },
    {
      "id": 6,
      "title": "Iscrizione Annuale",
      "price": 30,
      "frequency": "Annuale",
      "paymentUrl": "https://pay.sumup.com/b2c/ANNUAL",
    },
  ];
}
