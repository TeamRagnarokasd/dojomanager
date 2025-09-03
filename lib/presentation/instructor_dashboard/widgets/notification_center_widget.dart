import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class NotificationCenterWidget extends StatefulWidget {
  final bool isFullScreen;

  const NotificationCenterWidget({Key? key, this.isFullScreen = false})
      : super(key: key);

  @override
  State<NotificationCenterWidget> createState() =>
      _NotificationCenterWidgetState();
}

class _NotificationCenterWidgetState extends State<NotificationCenterWidget> {
  List<Map<String, dynamic>> notifications = [
    {
      'type': 'booking',
      'title': 'Nuova Prenotazione',
      'message':
          'Marco Rossi ha prenotato BJJ Principianti per domani alle 18:00',
      'time': '5 min fa',
      'isRead': false,
      'icon': Icons.book_online,
      'color': Colors.green,
    },
    {
      'type': 'certificate',
      'title': 'Certificato in Scadenza',
      'message': 'Il certificato medico di Sofia Bianchi scade tra 15 giorni',
      'time': '1 ora fa',
      'isRead': false,
      'icon': Icons.medical_services,
      'color': Colors.orange,
    },
    {
      'type': 'admin',
      'title': 'Messaggio Amministrazione',
      'message': 'Ricorda di confermare le presenze per la lezione di ieri',
      'time': '3 ore fa',
      'isRead': true,
      'icon': Icons.admin_panel_settings,
      'color': Colors.red,
    },
    {
      'type': 'payment',
      'title': 'Pagamento Ricevuto',
      'message': 'Pagamento mensile ricevuto da Luca Verdi - €89',
      'time': '1 giorno fa',
      'isRead': true,
      'icon': Icons.payment,
      'color': Colors.blue,
    },
    {
      'type': 'achievement',
      'title': 'Nuovo Traguardo',
      'message': 'Anna Neri ha raggiunto 50 lezioni di MMA!',
      'time': '2 giorni fa',
      'isRead': true,
      'icon': Icons.emoji_events,
      'color': Colors.purple,
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.isFullScreen) {
      return _buildFullScreenNotifications();
    } else {
      return _buildCompactNotifications();
    }
  }

  Widget _buildCompactNotifications() {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifiche',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withAlpha(128)),
                ),
                child: Text(
                  '${notifications.where((n) => !n['isRead']).length} nuove',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...notifications
              .take(3)
              .map((notification) => _buildNotificationItem(notification)),
          if (notifications.length > 3)
            TextButton(
              onPressed: () {
                // This will be handled by the parent dashboard
              },
              child: Text(
                'Vedi tutte le notifiche',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullScreenNotifications() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => SizedBox(height: 1.h),
      itemBuilder: (context, index) => _buildNotificationItem(
        notifications[index],
        isFullScreen: true,
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification,
      {bool isFullScreen = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isFullScreen ? 0 : 1.h),
      padding: EdgeInsets.all(isFullScreen ? 4.w : 3.w),
      decoration: BoxDecoration(
        color: notification['isRead'] ? Color(0xFF2A2A2A) : Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !notification['isRead']
              ? notification['color'].withAlpha(128)
              : Colors.grey.withAlpha(77),
        ),
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isFullScreen ? 12.w : 10.w,
              height: isFullScreen ? 12.w : 10.w,
              decoration: BoxDecoration(
                color: notification['color'].withAlpha(51),
                shape: BoxShape.circle,
                border: Border.all(color: notification['color']),
              ),
              child: Icon(
                notification['icon'],
                color: notification['color'],
                size: isFullScreen ? 5.w : 4.w,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'],
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: isFullScreen ? 12.sp : 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!notification['isRead'])
                        Container(
                          width: 2.w,
                          height: 2.w,
                          decoration: BoxDecoration(
                            color: notification['color'],
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    notification['message'],
                    style: GoogleFonts.inter(
                      color: Colors.grey[300],
                      fontSize: isFullScreen ? 10.sp : 9.sp,
                      height: 1.3,
                    ),
                    maxLines: isFullScreen ? null : 2,
                    overflow: isFullScreen ? null : TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    notification['time'],
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: isFullScreen ? 9.sp : 8.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (isFullScreen)
              PopupMenuButton<String>(
                color: Color(0xFF2A2A2A),
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 4.w),
                onSelected: (value) =>
                    _handleNotificationAction(notification, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(
                          notification['isRead']
                              ? Icons.mark_email_unread
                              : Icons.mark_email_read,
                          color: Colors.blue,
                          size: 4.w,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          notification['isRead'] ? 'Non letto' : 'Letto',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 4.w),
                        SizedBox(width: 2.w),
                        Text('Elimina',
                            style: GoogleFonts.inter(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    if (!notification['isRead']) {
      setState(() {
        notification['isRead'] = true;
      });
    }

    // Handle different notification types
    switch (notification['type']) {
      case 'booking':
        _handleBookingNotification(notification);
        break;
      case 'certificate':
        _handleCertificateNotification(notification);
        break;
      case 'admin':
        _handleAdminNotification(notification);
        break;
      case 'payment':
        _handlePaymentNotification(notification);
        break;
      case 'achievement':
        _handleAchievementNotification(notification);
        break;
    }
  }

  void _handleNotificationAction(
      Map<String, dynamic> notification, String action) {
    switch (action) {
      case 'mark_read':
        setState(() {
          notification['isRead'] = !notification['isRead'];
        });
        break;
      case 'delete':
        setState(() {
          notifications.removeWhere((n) => n == notification);
        });
        break;
    }
  }

  void _handleBookingNotification(Map<String, dynamic> notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Visualizza dettagli prenotazione'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleCertificateNotification(Map<String, dynamic> notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gestione certificati medici'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleAdminNotification(Map<String, dynamic> notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Messaggio amministrazione'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handlePaymentNotification(Map<String, dynamic> notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dettagli pagamento'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _handleAchievementNotification(Map<String, dynamic> notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Visualizza traguardo studente'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}