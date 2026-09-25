import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cron/cron.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/asd_deadlines_service.dart';
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
    if (kIsWeb) {
      // flutter_local_notifications is not supported on web — skip initialization
      return;
    }

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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
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
        'user-id-2',
      ]; // Mock data

      for (String userId in activeUserIds) {
        final needsReminder = await _receiptService.needsPaymentReminder(
          userId,
        );

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
    if (kIsWeb) return;
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
    if (kIsWeb) return;
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
          'route': '/admin-management-system',
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
        final timeAgo = _getTimeAgo(
          DateTime.parse(communication['created_at']),
        );
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
          .gte(
            'confirmed_at',
            DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
          )
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
          'route': '/italian-receipt-generation',
          'data': payment,
        });
      }

      // 4. Get pending password reset requests
      try {
        final passwordResetRequests = await client
            .from('password_reset_requests')
            .select('id, user_full_name, user_email, requested_at')
            .eq('status', 'pending')
            .order('requested_at', ascending: false)
            .limit(5);

        for (final request in passwordResetRequests) {
          final timeAgo = _getTimeAgo(DateTime.parse(request['requested_at']));
          notifications.add({
            'id': request['id'],
            'title': 'Richiesta Recupero Password',
            'description':
                '${request['user_full_name']} ha richiesto il recupero della password',
            'type': 'admin_task',
            'priority': 'high',
            'icon': Icons.lock_reset,
            'time': timeAgo,
            'route': '/admin-management-system',
            'data': request,
          });
        }
      } catch (_) {
        // Table may not exist yet — skip silently
      }

      // 5. Get shop orders with a payment declared, awaiting admin confirmation
      try {
        final shopPayments = await client
            .from('shop_orders')
            .select('''
              id, payment_method, final_total, member_total, updated_at,
              user_profiles!inner(full_name)
            ''')
            .eq('status', 'pagamento_dichiarato')
            .order('updated_at', ascending: false)
            .limit(5);

        for (final order in shopPayments) {
          final timeAgo = _getTimeAgo(DateTime.parse(order['updated_at']));
          final amount = order['final_total'] ?? order['member_total'] ?? 0;
          notifications.add({
            'id': order['id'],
            'title': 'Shop: pagamento dichiarato',
            'description':
                'Shop: ${order['user_profiles']['full_name']} ha pagato con '
                '${order['payment_method']} €$amount',
            'type': 'system_alert',
            'priority': 'low',
            'icon': Icons.shopping_cart,
            'time': timeAgo,
            'route': '/shop-admin-orders',
            'data': order,
          });
        }
      } catch (_) {
        // Table may not exist yet — skip silently
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
          .gte(
            'created_at',
            DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
          )
          .count(CountOption.exact);

      // Count pending password reset requests
      int passwordResetCount = 0;
      try {
        final passwordResetResponse = await client
            .from('password_reset_requests')
            .select('id')
            .eq('status', 'pending')
            .count(CountOption.exact);
        passwordResetCount = passwordResetResponse.count;
      } catch (_) {
        // Table may not exist yet — skip silently
      }

      return pendingCountResponse.count +
          highPriorityCommunicationsResponse.count +
          passwordResetCount;
    } catch (error) {
      print('Error getting high priority notifications count: $error');
      return 0;
    }
  }

  Future<void> sendPaymentReminderForUser(String userId) async {
    await _sendPaymentReminderNotification(userId);
  }

  /// Local notification for each Scadenzario ASD occurrence that is overdue
  /// or within its notice window, at most once a day per occurrence
  /// (tracked in shared_preferences so re-entering the app the same day
  /// doesn't repeat it). No deadline text is hardcoded — titles and dates
  /// all come from [summary]. Not shown on web, and this never touches any
  /// other notification this service sends.
  Future<void> showAsdDeadlineAlerts(AsdDeadlineSummary summary) async {
    if (kIsWeb) return;
    if (summary.dueOccurrences.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().split('T').first;
    final dayMonthFormat = DateFormat('dd/MM');

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'asd_deadlines',
          'Scadenzario ASD',
          channelDescription: 'Promemoria per le scadenze e gli adempimenti ASD',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFF9800),
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

    for (final occurrence in summary.dueOccurrences) {
      if (occurrence.urgency == AsdDeadlineUrgency.normal) continue;

      final dueDateKey = occurrence.dueDate.toIso8601String().split('T').first;
      final prefsKey =
          'asd_deadline_alert_${occurrence.deadline.id}_${dueDateKey}_$todayKey';
      if (prefs.getBool(prefsKey) == true) continue;

      final body = occurrence.urgency == AsdDeadlineUrgency.overdue
          ? 'Scadenza superata: ${occurrence.deadline.title}'
          : 'Scadenza in arrivo: ${occurrence.deadline.title} (${dayMonthFormat.format(occurrence.dueDate)})';

      await _flutterLocalNotificationsPlugin.show(
        _asdNotificationId(prefsKey),
        'Scadenzario ASD - Team Ragnarok ASD',
        body,
        platformChannelSpecifics,
        payload: 'asd_deadline:${occurrence.deadline.id}',
      );
      await prefs.setBool(prefsKey, true);
    }
  }

  int _asdNotificationId(String seed) => seed.hashCode & 0x7fffffff;

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  void dispose() {
    _cron.close();
  }
}
