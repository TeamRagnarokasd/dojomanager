import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RevenueAnalyticsCardWidget extends StatelessWidget {
  final bool isLoading;

  const RevenueAnalyticsCardWidget({
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
                    color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Color(0xFF27AE60),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Analytics Ricavi',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Monthly Earnings
            _buildMetricRow(
              'Guadagni Mensili',
              '€2.450',
              '+15% vs scorso mese',
              const Color(0xFF27AE60),
              isDark,
            ),

            const SizedBox(height: 16),

            // Class Popularity
            _buildMetricRow(
              'Classe Più Popolare',
              'BJJ Intermedio',
              '85% di affluenza',
              const Color(0xFFFF0000), // Team Ragnarok red
              isDark,
            ),

            const SizedBox(height: 16),

            // Payment Status
            _buildMetricRow(
              'Stato Pagamenti',
              '96% Completati',
              '2 pagamenti in attesa',
              const Color(0xFFF39C12),
              isDark,
            ),

            const SizedBox(height: 20),

            // View Full Analytics Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  // Navigate to full analytics
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF0000), // Team Ragnarok red
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: Text(
                  'Visualizza Analytics Completi',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    String subtitle,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}
