import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class NotificationCenterWidget extends StatelessWidget {
  const NotificationCenterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> notifications = [
      {
        'title': 'Registrazione Studente in Attesa',
        'description': 'Marco Rossi ha completato la registrazione per BJJ',
        'type': 'admin_task',
        'priority': 'high',
        'icon': Icons.person_add,
        'time': '2 min fa',
        'route': '/admin-management-system',
      },
      {
        'title': 'Sistema di Backup Completato',
        'description': 'Backup automatico database completato con successo',
        'type': 'system_alert',
        'priority': 'low',
        'icon': Icons.backup,
        'time': '15 min fa',
        'route': null,
      },
      {
        'title': 'Richiesta Modifica Orario',
        'description':
            'L\'istruttore Andrea ha richiesto modifica per BJJ Avanzato',
        'type': 'user_request',
        'priority': 'medium',
        'icon': Icons.schedule,
        'time': '1 ora fa',
        'route': '/admin-event-management',
      },
      {
        'title': 'Certificato Medico in Scadenza',
        'description': '3 certificati medici scadranno nei prossimi 7 giorni',
        'type': 'admin_task',
        'priority': 'high',
        'icon': Icons.medical_information,
        'time': '2 ore fa',
        'route': '/admin-management-system',
      },
      {
        'title': 'Pagamento Ricevuto',
        'description': 'Giulia Bianchi ha effettuato il pagamento mensile',
        'type': 'system_alert',
        'priority': 'low',
        'icon': Icons.payment,
        'time': '3 ore fa',
        'route': '/admin-receipt-management',
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centro Notifiche',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Attività amministrative e avvisi sistema con tema scuro',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${notifications.where((n) => n['priority'] == 'high').length} priorità',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Notifications List
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: notifications.asMap().entries.map((entry) {
                final index = entry.key;
                final notification = entry.value;
                final isLast = index == notifications.length - 1;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: notification['route'] != null
                        ? () =>
                            Navigator.pushNamed(context, notification['route'])
                        : null,
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(16) : Radius.zero,
                      bottom: isLast ? const Radius.circular(16) : Radius.zero,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(4.w),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Priority Indicator & Icon
                              Stack(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(2.5.w),
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(
                                              notification['priority'])
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      notification['icon'],
                                      color: _getPriorityColor(
                                          notification['priority']),
                                      size: 20,
                                    ),
                                  ),
                                  if (notification['priority'] == 'high')
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 2.w,
                                        height: 2.w,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(width: 3.w),

                              // Notification Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification['title'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      notification['description'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 1.h),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 2.w,
                                            vertical: 0.5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getTypeColor(
                                                    notification['type'])
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getTypeLabel(notification['type']),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: _getTypeColor(
                                                      notification['type']),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          notification['time'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Action Indicator
                              if (notification['route'] != null)
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 14,
                                ),
                            ],
                          ),
                          if (!isLast) ...[
                            SizedBox(height: 2.h),
                            Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2),
                              thickness: 1,
                              height: 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFFF0000); // Team Ragnarok red
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'admin_task':
        return const Color(0xFFFF0000); // Team Ragnarok red
      case 'system_alert':
        return Colors.blue;
      case 'user_request':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'admin_task':
        return 'Attività Admin';
      case 'system_alert':
        return 'Sistema';
      case 'user_request':
        return 'Richiesta';
      default:
        return 'Generico';
    }
  }
}
