import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InstructorNotificationCenterWidget extends StatelessWidget {
  final bool isLoading;

  const InstructorNotificationCenterWidget({
    Key? key,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000)
                        .withValues(alpha: 0.1), // Team Ragnarok red
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Color(0xFFFF0000),
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    'Centro Notifiche',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),

                // Unread count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000), // Team Ragnarok red
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '3',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Notifications List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _notifications.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? const Color(0xFF404040) : Colors.grey[200],
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _buildNotificationItem(
                context,
                type: notification['type'],
                title: notification['title'],
                message: notification['message'],
                time: notification['time'],
                isUnread: notification['isUnread'],
                isDark: isDark,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required String type,
    required String title,
    required String message,
    required String time,
    required bool isUnread,
    required bool isDark,
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case 'booking':
        icon = Icons.event_available;
        color = const Color(0xFF27AE60);
        break;
      case 'certificate':
        icon = Icons.medical_services;
        color = const Color(0xFFF39C12);
        break;
      case 'admin':
        icon = Icons.admin_panel_settings;
        color = const Color(0xFF3498DB);
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      color: isUnread
          ? (isDark
              ? const Color(0xFF2A2A2A)
              : Colors.blue.withValues(alpha: 0.05))
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF0000), // Team Ragnarok red
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color:
                          isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Time
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'booking',
      'title': 'Nuova Prenotazione',
      'message': 'Marco Rossi ha prenotato BJJ Intermedio',
      'time': '10min',
      'isUnread': true,
    },
    {
      'type': 'certificate',
      'title': 'Certificato in Scadenza',
      'message': 'Anna Verdi - certificato medico scade tra 15 giorni',
      'time': '2h',
      'isUnread': true,
    },
    {
      'type': 'admin',
      'title': 'Messaggio Amministrativo',
      'message': 'Nuovo protocollo COVID aggiornato',
      'time': '1 giorno',
      'isUnread': false,
    },
  ];
}
