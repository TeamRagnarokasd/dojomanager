import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClassHistorySectionWidget extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onRefresh;

  const ClassHistorySectionWidget({
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
                    Icons.history,
                    color: Color(0xFFFF0000),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Storico Classi',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Class History List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _classHistory.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? const Color(0xFF404040) : Colors.grey[200],
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final classItem = _classHistory[index];
              return _buildHistoryItem(
                context,
                date: classItem['date'],
                title: classItem['title'],
                attendance: classItem['attendance'],
                totalStudents: classItem['totalStudents'],
                feedback: classItem['feedback'],
                rating: classItem['rating'],
                isDark: isDark,
              );
            },
          ),

          // View More Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  // Navigate to full class history
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF0000), // Team Ragnarok red
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.view_list, size: 18),
                label: Text(
                  'Visualizza Tutto lo Storico',
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

  Widget _buildHistoryItem(
    BuildContext context, {
    required String date,
    required String title,
    required int attendance,
    required int totalStudents,
    required double rating,
    required String feedback,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Date Column
          Container(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.split('/')[0], // Day
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF0000), // Team Ragnarok red
                  ),
                ),
                Text(
                  date.substring(3), // Month/Year
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                  ),
                ),
              ],
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
                      '$attendance/$totalStudents presenti',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color:
                            isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  feedback,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Rating
          Column(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: const Color(0xFFF39C12),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                rating.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFF39C12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final List<Map<String, dynamic>> _classHistory = [
    {
      'date': '30/12',
      'title': 'BJJ Avanzato',
      'attendance': 8,
      'totalStudents': 10,
      'rating': 4.8,
      'feedback': 'Ottima sessione di sparring',
    },
    {
      'date': '29/12',
      'title': 'Muay Thai Intermedio',
      'attendance': 12,
      'totalStudents': 15,
      'rating': 4.5,
      'feedback': 'Focus su tecniche di clinch',
    },
    {
      'date': '28/12',
      'title': 'BJJ Principianti',
      'attendance': 6,
      'totalStudents': 8,
      'rating': 4.9,
      'feedback': 'Perfetto per i nuovi studenti',
    },
  ];
}
