import 'package:flutter/material.dart';

import '../presentation/admin_discipline_management/admin_discipline_management.dart';
import '../presentation/admin_event_management/admin_event_management.dart';
import '../presentation/admin_management_system/admin_management_system.dart';
import '../presentation/admin_receipt_management/admin_receipt_management.dart';
import '../presentation/admin_sponsor_management/admin_sponsor_management.dart';
import '../presentation/admin_profile_screen/admin_profile_screen.dart';
import '../presentation/class_schedule/class_schedule.dart';
import '../presentation/dashboard_home/dashboard_home.dart';
import '../presentation/enhanced_admin_dashboard/enhanced_admin_dashboard.dart';
import '../presentation/instructor_main_dashboard/instructor_main_dashboard.dart';
import '../presentation/instructor_directory/instructor_directory.dart';
import '../presentation/instructor_management_system/instructor_management_system.dart';
import '../presentation/italian_receipt_generation/italian_receipt_generation.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/medical_certificate_upload/medical_certificate_upload.dart';
import '../presentation/payment_history/payment_history.dart';
import '../presentation/receipt_archive/receipt_archive.dart';
import '../presentation/receipt_management/receipt_management.dart';
import '../presentation/seasonal_schedule_creation/seasonal_schedule_creation.dart';
import '../presentation/student_registration/student_registration.dart';
import '../presentation/student_registration_personal_info/student_registration_personal_info.dart';
import '../presentation/student_registration_emergency_contacts/student_registration_emergency_contacts.dart';
import '../presentation/student_registration_medical_certificate/student_registration_medical_certificate.dart';
import '../presentation/student_registration_terms_and_completion/student_registration_terms_and_completion.dart';
import '../presentation/subscription_plan_selection/subscription_plan_selection.dart';
import '../presentation/user_profile/user_profile.dart';
import '../presentation/student_progress/student_progress_screen.dart';
import '../presentation/child_profiles/child_profiles_screen.dart';
import '../presentation/admin_child_profile/admin_child_profile_screen.dart';
import '../presentation/piani_convenzione/piani_convenzione_screen.dart';

class AppRoutes {
  // Global RouteObserver — add to MaterialApp.navigatorObservers
  // and subscribe in screens that need didPush / didPopNext callbacks.
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  static const String initial = '/';
  static const String dashboardHome = '/dashboard-home';
  static const String classSchedule = '/class-schedule';
  static const String studentRegistration = '/student-registration';
  static const String studentRegistrationPersonalInfo =
      '/student-registration-personal-info';
  static const String studentRegistrationEmergencyContacts =
      '/student-registration-emergency-contacts';
  static const String studentRegistrationMedicalCertificate =
      '/student-registration-medical-certificate';
  static const String studentRegistrationTermsAndCompletion =
      '/student-registration-terms-and-completion';
  static const String medicalCertificateUpload = '/medical-certificate-upload';
  static const String login = '/login-screen';
  static const String paymentHistory = '/payment-history';
  static const String userProfile = '/user-profile';
  static const String instructorDashboard = '/instructor-dashboard';
  static const String instructorMainDashboard = '/instructor-main-dashboard';
  static const String adminDisciplineManagement =
      '/admin-discipline-management';
  static const String subscriptionPlanSelection = '/plan-selection';
  static const String adminEventManagement = '/admin-event-management';
  static const String instructorDirectory = '/instructor-directory';
  static const String receiptManagement = '/receipt-management';
  static const String adminReceiptManagement = '/admin-receipt-management';
  static const String receiptArchive = '/receipt-archive';
  static const String adminManagementSystem = '/admin-management-system';
  static const String enhancedAdminDashboard = '/enhanced-admin-dashboard';
  static const String italianReceiptGeneration = '/italian-receipt-generation';
  static const String seasonalScheduleCreation = '/seasonal-schedule-creation';
  static const String adminSponsorManagement = '/admin-sponsor-management';
  static const String instructorManagementSystem =
      '/instructor-management-system';
  static const String adminProfile = '/admin-profile';
  static const String studentProgress = '/student-progress';
  static const String childProfiles = '/child-profiles';
  static const String adminChildProfile = '/admin-child-profile';
  static const String pianiConvenzione = '/piani-convenzione';

  static Map<String, WidgetBuilder> get routes {
    return {
      initial: (context) => const LoginScreen(),
      dashboardHome: (context) => const DashboardHome(),
      classSchedule: (context) => const ClassSchedule(),
      studentRegistration: (context) => const StudentRegistration(),
      studentRegistrationPersonalInfo: (context) =>
          const StudentRegistrationPersonalInfo(),
      studentRegistrationEmergencyContacts: (context) =>
          const StudentRegistrationEmergencyContacts(),
      studentRegistrationMedicalCertificate: (context) =>
          const StudentRegistrationMedicalCertificate(),
      studentRegistrationTermsAndCompletion: (context) =>
          const StudentRegistrationTermsAndCompletion(),
      medicalCertificateUpload: (context) => const MedicalCertificateUpload(),
      login: (context) => const LoginScreen(),
      paymentHistory: (context) => const PaymentHistory(),
      userProfile: (context) => const UserProfile(),
      instructorDashboard: (context) => const InstructorMainDashboard(),
      instructorMainDashboard: (context) => const InstructorMainDashboard(),
      adminDisciplineManagement: (context) => const AdminDisciplineManagement(),
      subscriptionPlanSelection: (context) => const SubscriptionPlanSelection(),
      adminEventManagement: (context) => const AdminEventManagement(),
      instructorDirectory: (context) => const InstructorDirectory(),
      receiptManagement: (context) => const ReceiptManagement(),
      adminReceiptManagement: (context) => const AdminReceiptManagement(),
      receiptArchive: (context) => const ReceiptArchive(),
      adminManagementSystem: (context) => const AdminManagementSystem(),
      enhancedAdminDashboard: (context) => const EnhancedAdminDashboard(),
      italianReceiptGeneration: (context) =>
          const ItalianReceiptGenerationScreen(),
      seasonalScheduleCreation: (context) => const SeasonalScheduleCreation(),
      adminSponsorManagement: (context) => const AdminSponsorManagement(),
      instructorManagementSystem: (context) =>
          const InstructorManagementSystem(),
      adminProfile: (context) => const AdminProfileScreen(),
      studentProgress: (context) => const StudentProgressScreen(),
      childProfiles: (context) => const ChildProfilesScreen(),
      adminChildProfile: (context) => const AdminChildProfileScreen(),
      pianiConvenzione: (context) => const PianiConvenzioneScreen(),
    };
  }
}
