import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InstructorDashboardHeaderWidget extends StatelessWidget {
  final bool isLoading;

  const InstructorDashboardHeaderWidget({
    Key? key,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A1A)
            : theme.appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Instructor Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF404040) : Colors.grey[200],
              border: Border.all(
                color: const Color(0xFFFF0000), // Team Ragnarok red
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Icon(
                Icons.school,
                size: 24,
                color: isDark ? Colors.white : Colors.grey[600],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Instructor Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maestro Rossi',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 14,
                      color:
                          isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '3 classi oggi',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? const Color(0xFFE0E0E0)
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Settings Button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF404040) : Colors.grey[100],
            ),
            child: IconButton(
              onPressed: () {
                // Navigate to instructor settings
              },
              icon: Icon(
                Icons.settings_outlined,
                size: 20,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
