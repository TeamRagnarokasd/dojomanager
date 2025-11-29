import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodaysClassesSectionWidget extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onRefresh;

  const TodaysClassesSectionWidget({
    Key? key,
    required this.isLoading,
    this.onRefresh,
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
                    Icons.schedule,
                    color: Color(0xFFFF0000),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Classi di Oggi',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Classes List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayClasses.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? const Color(0xFF404040) : Colors.grey[200],
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final classItem = _todayClasses[index];
              return _buildClassItem(
                context,
                time: classItem['time'],
                title: classItem['title'],
                students: classItem['students'],
                maxStudents: classItem['maxStudents'],
                status: classItem['status'],
                isDark: isDark,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassItem(
    BuildContext context, {
    required String time,
    required String title,
    required int students,
    required int maxStudents,
    required String status,
    required bool isDark,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'upcoming':
        statusColor = const Color(0xFF3498DB);
        statusIcon = Icons.schedule;
        break;
      case 'active':
        statusColor = const Color(0xFF27AE60);
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = const Color(0xFF95A5A6);
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Time
          Container(
            width: 60,
            child: Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF0000), // Team Ragnarok red
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Class Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 14,
                      color:
                          isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$students/$maxStudents studenti',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color:
                            isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status & Actions
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status == 'upcoming'
                          ? 'Prossima'
                          : status == 'active'
                              ? 'In corso'
                              : 'Completata',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Action Buttons
              Row(
                children: [
                  _buildActionButton(
                    Icons.check,
                    'Presenze',
                    () {
                      // Handle attendance
                    },
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    Icons.note_add,
                    'Note',
                    () {
                      // Handle notes
                    },
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String tooltip, VoidCallback onPressed, bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF404040) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 16,
          color: const Color(0xFFFF0000), // Team Ragnarok red
        ),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }

  static final List<Map<String, dynamic>> _todayClasses = [
    {
      'time': '09:00',
      'title': 'BJJ Principianti',
      'students': 8,
      'maxStudents': 12,
      'status': 'completed',
    },
    {
      'time': '11:00',
      'title': 'Muay Thai Intermedio',
      'students': 10,
      'maxStudents': 15,
      'status': 'active',
    },
    {
      'time': '19:00',
      'title': 'BJJ Avanzato',
      'students': 6,
      'maxStudents': 10,
      'status': 'upcoming',
    },
  ];
}
