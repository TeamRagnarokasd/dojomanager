import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_export.dart';

class QuickAccessCardsWidget extends StatelessWidget {
  final bool isLoading;

  const QuickAccessCardsWidget({
    Key? key,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accesso Immediato',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : theme.textTheme.titleLarge?.color,
          ),
        ),

        const SizedBox(height: 16),

        // Priority Cards Row - Most Used Features
        Row(
          children: [
            Expanded(
              child: _buildPriorityCard(
                context,
                title: 'Palinsesto',
                subtitle: 'Prenota ora',
                icon: Icons.calendar_month,
                color: const Color(0xFFFF0000),
                onTap: () => Navigator.pushNamed(context, '/class-schedule'),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPriorityCard(
                context,
                title: 'Ricevute',
                subtitle: 'Download PDF',
                icon: Icons.receipt_long,
                color: const Color(0xFFFF0000),
                onTap: () => Navigator.pushNamed(context, '/receipt-archive'),
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Secondary Access Cards
        _buildSecondaryAccessCard(
          context,
          title: 'profile.medical_certificate'.tr(),
          subtitle: 'Scade tra 45 giorni',
          icon: Icons.medical_services,
          color: const Color(0xFFF39C12),
          onTap: () =>
              Navigator.pushNamed(context, '/medical-certificate-upload'),
          isDark: isDark,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF39C12).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '45gg',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF39C12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        _buildSecondaryAccessCard(
          context,
          title: 'Storico Pagamenti',
          subtitle: 'Visualizza cronologia abbonamenti',
          icon: Icons.payment,
          color: const Color(0xFF9B59B6),
          onTap: () => Navigator.pushNamed(context, '/payment-history'),
          isDark: isDark,
        ),

        const SizedBox(height: 12),

        _buildSecondaryAccessCard(
          context,
          title: 'Elenco Istruttori',
          subtitle: 'Visualizza i nostri istruttori',
          icon: Icons.groups,
          color: const Color(0xFF2ECC71),
          onTap: () => Navigator.pushNamed(context, '/instructor-directory'),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPriorityCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                const Spacer(),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAccessCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing,
  }) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? const Color(0xFFE0E0E0)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing,
                ] else ...[
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[400],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
