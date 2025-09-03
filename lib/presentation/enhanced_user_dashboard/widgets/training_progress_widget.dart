import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrainingProgressWidget extends StatelessWidget {
  final bool isLoading;

  const TrainingProgressWidget({
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
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
                    Icons.trending_up,
                    color: Color(0xFFFF0000),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Progresso Allenamento',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Belt Progress
            _buildProgressItem(
              context,
              title: 'Cintura Attuale',
              value: 'Blu',
              progress: 0.75,
              progressText: '75% verso Marrone',
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Hours Logged
            _buildProgressItem(
              context,
              title: 'Ore di Allenamento',
              value: '48h',
              progress: 0.6,
              progressText: 'Questo mese',
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Achievement Badges
            Row(
              children: [
                Text(
                  'Distintivi',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                _buildBadge('🥋', isDark),
                const SizedBox(width: 8),
                _buildBadge('🏆', isDark),
                const SizedBox(width: 8),
                _buildBadge('⭐', isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(
    BuildContext context, {
    required String title,
    required String value,
    required double progress,
    required String progressText,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[700],
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Progress Bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF404040) : Colors.grey[200],
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000), // Team Ragnarok red
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          progressText,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String emoji, bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF404040) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
