import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecentActivityFeedWidget extends StatelessWidget {
  final bool isLoading;

  const RecentActivityFeedWidget({
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
                    Icons.history,
                    color: Color(0xFFFF0000),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Attività Recente',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Activity Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activityItems.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? const Color(0xFF404040) : Colors.grey[200],
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final item = _activityItems[index];
              return Dismissible(
                key: Key('activity_$index'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFFF0000),
                    size: 20,
                  ),
                ),
                child: _buildActivityItem(
                  context,
                  icon: item['icon'],
                  title: item['title'],
                  subtitle: item['subtitle'],
                  time: item['time'],
                  color: item['color'],
                  isDark: isDark,
                ),
              );
            },
          ),

          // View All Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  // Navigate to full activity log
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF0000), // Team Ragnarok red
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Vedi Tutte le Attività',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
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
    );
  }

  static final List<Map<String, dynamic>> _activityItems = [
    {
      'icon': Icons.event_available,
      'title': 'Classe Prenotata',
      'subtitle': 'BJJ Intermedio - Martedì 19:00',
      'time': '2h fa',
      'color': const Color(0xFF27AE60),
    },
    {
      'icon': Icons.payment,
      'title': 'Pagamento Ricevuto',
      'subtitle': 'Abbonamento Mensile - €80.00',
      'time': '1 giorno',
      'color': const Color(0xFF3498DB),
    },
    {
      'icon': Icons.notifications,
      'title': 'Promemoria',
      'subtitle': 'Rinnovo certificato medico',
      'time': '2 giorni',
      'color': const Color(0xFFF39C12),
    },
    {
      'icon': Icons.celebration,
      'title': 'Nuovo Traguardo',
      'subtitle': 'Completate 20 ore di allenamento',
      'time': '3 giorni',
      'color': const Color(0xFFFF0000),
    },
  ];
}
