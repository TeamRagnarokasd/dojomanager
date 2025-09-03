import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickActionsPanelWidget extends StatelessWidget {
  final bool isLoading;

  const QuickActionsPanelWidget({
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
            // Header with Enhanced Icon
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF0000),
                        const Color(0xFFDD0000),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.flash_on,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Gestione Avanzata',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Enhanced Action Grid with Instructor-Specific Functions
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildAdvancedActionCard(
                  'Presenze & Assenze',
                  Icons.how_to_reg,
                  const Color(0xFF27AE60),
                  '✓ Registro elettronico',
                  () {
                    Navigator.pushNamed(context, '/attendance-tracking');
                  },
                  isDark,
                ),
                _buildAdvancedActionCard(
                  'Valuta Progressi',
                  Icons.analytics,
                  const Color(0xFF3498DB),
                  '📊 Report studenti',
                  () {
                    Navigator.pushNamed(context, '/student-progress');
                  },
                  isDark,
                ),
                _buildAdvancedActionCard(
                  'Gestisci Ricevute',
                  Icons.receipt_long,
                  const Color(0xFFFF0000),
                  '💰 Pagamenti classe',
                  () {
                    Navigator.pushNamed(context, '/receipt-generation-system');
                  },
                  isDark,
                ),
                _buildAdvancedActionCard(
                  'Notifiche Gruppo',
                  Icons.campaign,
                  const Color(0xFFF39C12),
                  '📢 Comunica a tutti',
                  () {
                    Navigator.pushNamed(context, '/automatic-reminder-system');
                  },
                  isDark,
                ),
                _buildAdvancedActionCard(
                  'Programma Esami',
                  Icons.school,
                  const Color(0xFF9B59B6),
                  '🏆 Promozioni cinture',
                  () {
                    // Handle belt promotion exams
                  },
                  isDark,
                ),
                _buildAdvancedActionCard(
                  'Recuperi & Supplenze',
                  Icons.event_repeat,
                  const Color(0xFFE67E22),
                  '🔄 Riprogrammazioni',
                  () {
                    Navigator.pushNamed(context, '/class-schedule');
                  },
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedActionCard(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF404040) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF606060) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with gradient background
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

                const Spacer(),

                // Title and subtitle
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[600],
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
