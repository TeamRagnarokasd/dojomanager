import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cron/cron.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/receipt_service.dart';
import '../services/supabase_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final ReceiptService _receiptService = ReceiptService();
  final Cron _cron = Cron();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // Request permissions
    await _requestPermissions();

    // Setup daily reminder scheduler
    _scheduleDailyPaymentReminder();
  }

  Future<void> _requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    // Navigate to payment screen or receipt management
  }

  void _scheduleDailyPaymentReminder() {
    // Schedule to run every day at 9:00 AM
    _cron.schedule(Schedule.parse('0 9 * * *'), () async {
      await _checkAndSendPaymentReminders();
    });
  }

  Future<void> _checkAndSendPaymentReminders() async {
    final now = DateTime.now();

    // Only send reminders on the 7th of each month
    if (now.day != 7) return;

    try {
      // Get all active users (in real implementation, fetch from user service)
      final List<String> activeUserIds = [
        'user-id-1',
        'user-id-2'
      ]; // Mock data

      for (String userId in activeUserIds) {
        final needsReminder =
            await _receiptService.needsPaymentReminder(userId);

        if (needsReminder) {
          await _sendPaymentReminderNotification(userId);
          await _receiptService.createPaymentReminder(userId);
        }
      }
    } catch (error) {
      print('Error checking payment reminders: $error');
    }
  }

  Future<void> _sendPaymentReminderNotification(String userId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'payment_reminder',
      'Payment Reminders',
      channelDescription: 'Notifications for monthly payment reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2196F3),
      autoCancel: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      userId.hashCode, // Use user ID hash as notification ID
      'Promemoria Pagamento - Team Ragnarok ASD',
      'Ricorda di pagare il tuo abbonamento mensile entro il giorno 10. Tocca per aprire l\'app.',
      platformChannelSpecifics,
      payload: 'payment_reminder:$userId',
    );
  }

  Future<void> sendReceiptGeneratedNotification({
    required String userId,
    required int receiptNumber,
    required double amount,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'receipt_generated',
      'Receipt Notifications',
      channelDescription: 'Notifications for generated receipts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
      autoCancel: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      receiptNumber, // Use receipt number as notification ID
      'Ricevuta Generata - Team Ragnarok ASD',
      'La tua ricevuta #$receiptNumber per €${amount.toStringAsFixed(2).replaceAll('.', ',')} è stata generata con successo.',
      platformChannelSpecifics,
      payload: 'receipt_generated:$receiptNumber',
    );
  }

  /// Fetch real admin notifications from Supabase database
  Future<List<Map<String, dynamic>>> getAdminNotifications() async {
    try {
      final client = SupabaseService.instance.client;
      final List<Map<String, dynamic>> notifications = [];

      // 1. Get pending student registrations for approval
      final pendingRegistrations = await client
          .from('user_profiles')
          .select('id, full_name, email, created_at')
          .eq('status', 'pending')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);

      // Add pending registrations as notifications
      for (final registration in pendingRegistrations) {
        final timeAgo = _getTimeAgo(DateTime.parse(registration['created_at']));
        notifications.add({
          'id': registration['id'],
          'title': 'Registrazione Studente in Attesa',
          'description':
              '${registration['full_name']} ha completato la registrazione',
          'type': 'admin_task',
          'priority': 'high',
          'icon': Icons.person_add,
          'time': timeAgo,
          'route': '/registration-management-system',
          'data': registration,
        });
      }

      // 2. Get admin communications from the database
      final adminCommunications = await client
          .from('admin_communications')
          .select('*')
          .eq('target_audience', 'all')
          .order('created_at', ascending: false)
          .limit(10);

      // Add admin communications as notifications
      for (final communication in adminCommunications) {
        final timeAgo =
            _getTimeAgo(DateTime.parse(communication['created_at']));
        notifications.add({
          'id': communication['id'],
          'title': communication['title'] ?? 'Comunicazione Admin',
          'description':
              communication['content'] ?? communication['message'] ?? '',
          'type': 'system_alert',
          'priority': communication['priority'] ?? 'normal',
          'icon': Icons.announcement,
          'time': timeAgo,
          'route': null,
          'data': communication,
        });
      }

      // 3. Get recent payment confirmations
      final recentPayments = await client
          .from('payment_confirmations')
          .select('''
            *,
            user_profiles!inner(full_name, email)
          ''')
          .eq('status', 'confirmed')
          .gte('confirmed_at',
              DateTime.now().subtract(Duration(days: 7)).toIso8601String())
          .order('confirmed_at', ascending: false)
          .limit(5);

      // Add payment confirmations as notifications
      for (final payment in recentPayments) {
        final timeAgo = _getTimeAgo(DateTime.parse(payment['confirmed_at']));
        notifications.add({
          'id': payment['id'],
          'title': 'Pagamento Ricevuto',
          'description':
              '${payment['user_profiles']['full_name']} ha confermato il pagamento di €${payment['amount']}',
          'type': 'system_alert',
          'priority': 'low',
          'icon': Icons.payment,
          'time': timeAgo,
          'route': '/admin-receipt-management',
          'data': payment,
        });
      }

      // 4. Check for medical certificates expiring soon
      final medicalCertExpiring = await client
          .from('user_profiles')
          .select('id, full_name, medical_certificate_status')
          .eq('medical_certificate_status', 'pending')
          .eq('is_active', true)
          .limit(5);

      if (medicalCertExpiring.isNotEmpty) {
        notifications.add({
          'id': 'medical_cert_expiring',
          'title': 'Certificati Medici in Sospeso',
          'description':
              '${medicalCertExpiring.length} certificati medici richiedono verifica',
          'type': 'admin_task',
          'priority': 'medium',
          'icon': Icons.medical_information,
          'time': 'Controlla ora',
          'route': '/user-management-system',
          'data': medicalCertExpiring,
        });
      }

      // Sort notifications by priority and time
      notifications.sort((a, b) {
        final priorityOrder = {'high': 0, 'medium': 1, 'low': 2, 'normal': 3};
        final priorityComparison = (priorityOrder[a['priority']] ?? 3)
            .compareTo(priorityOrder[b['priority']] ?? 3);
        if (priorityComparison != 0) return priorityComparison;

        // If priorities are the same, sort by creation time (most recent first)
        return b['time'].toString().compareTo(a['time'].toString());
      });

      return notifications.take(8).toList(); // Limit to 8 notifications
    } catch (error) {
      print('Error fetching admin notifications: $error');
      // Return empty list on error to avoid crashes
      return [];
    }
  }

  /// Convert DateTime to Italian time ago format
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'ora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ore fa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} giorni fa';
    } else {
      return '${(difference.inDays / 7).floor()} settimane fa';
    }
  }

  /// Get count of high priority notifications
  Future<int> getHighPriorityNotificationsCount() async {
    try {
      final client = SupabaseService.instance.client;

      // Count pending registrations
      final pendingCountResponse = await client
          .from('user_profiles')
          .select('id')
          .eq('status', 'pending')
          .eq('is_active', true)
          .count(CountOption.exact);

      // Count high priority admin communications
      final highPriorityCommunicationsResponse = await client
          .from('admin_communications')
          .select('id')
          .eq('priority', 'high')
          .gte('created_at',
              DateTime.now().subtract(Duration(days: 7)).toIso8601String())
          .count(CountOption.exact);

      return pendingCountResponse.count + highPriorityCommunicationsResponse.count;
    } catch (error) {
      print('Error getting high priority notifications count: $error');
      return 0;
    }
  }

  Future<void> sendPaymentReminderForUser(String userId) async {
    await _sendPaymentReminderNotification(userId);
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  void dispose() {
    _cron.close();
  }
}