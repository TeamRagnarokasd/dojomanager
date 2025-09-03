import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class RecentActivityFeedWidget extends StatelessWidget {
  const RecentActivityFeedWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> activities = [
      {
        'action': 'Registrazione Utente',
        'description':
            'Marco Rossi si è iscritto per il corso BJJ Principianti',
        'actor': 'Sistema',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
        'icon': Icons.person_add,
        'color': Theme.of(context).colorScheme.secondary,
        'type': 'registration',
      },
      {
        'action': 'Pagamento Elaborato',
        'description': 'Giulia Bianchi - Pagamento mensile €80 elaborato',
        'actor': 'Admin Finanziario',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 12)),
        'icon': Icons.payment,
        'color': Colors.green,
        'type': 'payment',
      },
      {
        'action': 'Modifica Evento',
        'description': 'Seminario BJJ spostato dal 15/09 al 22/09',
        'actor': 'Andrea Lombardi',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 25)),
        'icon': Icons.event_note,
        'color': Colors.blue,
        'type': 'event',
      },
      {
        'action': 'Approvazione Admin',
        'description': 'Certificato medico di Lisa Verde approvato',
        'actor': 'Dr. Admin',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 35)),
        'icon': Icons.verified,
        'color': Colors.orange,
        'type': 'approval',
      },
      {
        'action': 'Nuova Lezione',
        'description': 'Aggiunta lezione SAMBO Avanzato - Mercoledì 19:00',
        'actor': 'Coordinatore',
        'timestamp':
            DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        'icon': Icons.sports_martial_arts,
        'color': Colors.purple,
        'type': 'schedule',
      },
      {
        'action': 'Backup Sistema',
        'description': 'Backup automatico database completato con successo',
        'actor': 'Sistema Automatico',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'icon': Icons.backup,
        'color': Colors.teal,
        'type': 'system',
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feed Attività Recenti',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Azioni amministrative e registrazioni utenti con timestamp tema scuro',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 3.h),

          // Activity Feed
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
              children: activities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                final isLast = index == activities.length - 1;

                return Container(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline Indicator
                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: (activity['color'] as Color)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  activity['icon'],
                                  color: activity['color'],
                                  size: 18,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 6.h,
                                  margin: EdgeInsets.only(top: 1.h),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(width: 4.w),

                          // Activity Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        activity['action'],
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
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2.w,
                                        vertical: 0.5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (activity['color'] as Color)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _getTypeLabel(activity['type']),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: activity['color'],
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 1.h),

                                // Description
                                Text(
                                  activity['description'],
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                SizedBox(height: 1.5.h),

                                // Footer
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    SizedBox(width: 1.w),
                                    Text(
                                      activity['actor'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatTimestamp(activity['timestamp']),
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
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: 2.h),

          // View All Button
          Center(
            child: TextButton(
              onPressed: () {
                // Navigate to full activity log
                Navigator.pushNamed(context, '/admin-management-system');
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.secondary,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Visualizza Tutte le Attività',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'registration':
        return 'Registrazione';
      case 'payment':
        return 'Pagamento';
      case 'event':
        return 'Evento';
      case 'approval':
        return 'Approvazione';
      case 'schedule':
        return 'Programmazione';
      case 'system':
        return 'Sistema';
      default:
        return 'Generico';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h fa';
    } else {
      return '${difference.inDays}g fa';
    }
  }
}
