import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cron/cron.dart';
import '../services/receipt_service.dart';

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