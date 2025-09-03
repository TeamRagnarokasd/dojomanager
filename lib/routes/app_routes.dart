import 'package:flutter/material.dart';
import '../presentation/class_schedule/class_schedule.dart';
import '../presentation/student_registration/student_registration.dart';
import '../presentation/medical_certificate_upload/medical_certificate_upload.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/payment_history/payment_history.dart';
import '../presentation/dashboard_home/dashboard_home.dart';
import '../presentation/user_profile/user_profile.dart';
import '../presentation/instructor_dashboard/instructor_dashboard.dart';
import '../presentation/admin_discipline_management/admin_discipline_management.dart';
import '../presentation/subscription_plan_selection/subscription_plan_selection.dart';
import '../presentation/admin_event_management/admin_event_management.dart';
import '../presentation/instructor_directory/instructor_directory.dart';
import '../presentation/receipt_management/receipt_management.dart';
import '../presentation/admin_receipt_management/admin_receipt_management.dart';
import '../presentation/receipt_generation_system/receipt_generation_system.dart';
import '../presentation/receipt_archive/receipt_archive.dart';
import '../presentation/automatic_reminder_system/automatic_reminder_system.dart';
import '../presentation/admin_management_system/admin_management_system.dart';
import '../presentation/enhanced_user_dashboard/enhanced_user_dashboard.dart';
import '../presentation/enhanced_instructor_dashboard/enhanced_instructor_dashboard.dart';
import '../presentation/enhanced_admin_dashboard/enhanced_admin_dashboard.dart';
import '../presentation/user_management_system/user_management_system.dart';
import '../presentation/registration_management_system/registration_management_system.dart';
import '../presentation/communication_center/communication_center.dart';
import '../presentation/italian_receipt_generation/italian_receipt_generation.dart';
import '../presentation/seasonal_schedule_management/seasonal_schedule_management.dart';

class AppRoutes {
  static const String initial = '/';
  static const String classSchedule = '/class-schedule';
  static const String studentRegistration = '/student-registration';
  static const String medicalCertificateUpload = '/medical-certificate-upload';
  static const String login = '/login-screen';
  static const String paymentHistory = '/payment-history';
  static const String dashboardHome = '/dashboard-home';
  static const String userProfile = '/user-profile';
  static const String instructorDashboard = '/instructor-dashboard';
  static const String adminDisciplineManagement =
      '/admin-discipline-management';
  static const String subscriptionPlanSelection =
      '/subscription-plan-selection';
  static const String adminEventManagement = '/admin-event-management';
  static const String instructorDirectory = '/instructor-directory';
  static const String receiptManagement = '/receipt-management';
  static const String adminReceiptManagement = '/admin-receipt-management';
  static const String receiptGenerationSystem = '/receipt-generation-system';
  static const String receiptArchive = '/receipt-archive';
  static const String automaticReminderSystem = '/automatic-reminder-system';
  static const String adminManagementSystem = '/admin-management-system';
  static const String enhancedUserDashboard = '/enhanced-user-dashboard';
  static const String enhancedInstructorDashboard =
      '/enhanced-instructor-dashboard';
  static const String enhancedAdminDashboard = '/enhanced-admin-dashboard';
  static const String userManagementSystem = '/user-management-system';
  static const String registrationManagementSystem =
      '/registration-management-system';
  static const String communicationCenter = '/communication-center';
  static const String italianReceiptGeneration = '/italian-receipt-generation';
  static const String seasonalScheduleManagement =
      '/seasonal-schedule-management';

  static final Map<String, WidgetBuilder> routes = {
    initial: (context) => const LoginScreen(),
    classSchedule: (context) => const ClassSchedule(),
    studentRegistration: (context) => const StudentRegistration(),
    medicalCertificateUpload: (context) => const MedicalCertificateUpload(),
    login: (context) => const LoginScreen(),
    paymentHistory: (context) => const PaymentHistory(),
    dashboardHome: (context) => const DashboardHome(),
    userProfile: (context) => const UserProfile(),
    instructorDashboard: (context) => const InstructorDashboard(),
    adminDisciplineManagement: (context) => const AdminDisciplineManagement(),
    subscriptionPlanSelection: (context) => const SubscriptionPlanSelection(),
    adminEventManagement: (context) => const AdminEventManagement(),
    instructorDirectory: (context) => const InstructorDirectory(),
    receiptManagement: (context) => const ReceiptManagement(),
    adminReceiptManagement: (context) => const AdminReceiptManagement(),
    receiptGenerationSystem: (context) => const ReceiptGenerationSystem(),
    receiptArchive: (context) => const ReceiptArchive(),
    automaticReminderSystem: (context) => const AutomaticReminderSystem(),
    adminManagementSystem: (context) => const AdminManagementSystem(),
    enhancedUserDashboard: (context) => const EnhancedUserDashboard(),
    enhancedInstructorDashboard: (context) =>
        const EnhancedInstructorDashboard(),
    enhancedAdminDashboard: (context) => const EnhancedAdminDashboard(),
    userManagementSystem: (context) => const UserManagementSystem(),
    registrationManagementSystem: (context) =>
        const RegistrationManagementSystem(),
    communicationCenter: (context) => const CommunicationCenter(),
    italianReceiptGeneration: (context) =>
        const ItalianReceiptGenerationScreen(),
    seasonalScheduleManagement: (context) => const SeasonalScheduleManagement(),
  };
}
