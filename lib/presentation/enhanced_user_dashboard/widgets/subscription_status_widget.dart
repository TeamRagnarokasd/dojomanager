import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionStatusWidget extends StatefulWidget {
  final bool isLoading;

  const SubscriptionStatusWidget({
    Key? key,
    required this.isLoading,
  }) : super(key: key);

  @override
  State<SubscriptionStatusWidget> createState() =>
      _SubscriptionStatusWidgetState();
}

class _SubscriptionStatusWidgetState extends State<SubscriptionStatusWidget> {
  bool _autoRenew = true;

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
                    color: const Color(0xFF27AE60)
                        .withValues(alpha: 0.1), // Success green
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: Color(0xFF27AE60),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stato Abbonamento',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ATTIVO',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Current Plan
            _buildInfoRow(
              'Piano Attuale',
              'Mensile Premium',
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            // Renewal Date
            _buildInfoRow(
              'Prossimo Rinnovo',
              '15 Gennaio 2025',
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            // Payment Method
            _buildInfoRow(
              'Metodo Pagamento',
              '**** 1234 (Visa)',
              isDark: isDark,
              trailing: TextButton(
                onPressed: () {
                  // Change payment method
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF0000), // Team Ragnarok red
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cambia',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Auto Renewal Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF404040) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rinnovo Automatico',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Il tuo abbonamento si rinnoverà automaticamente',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFFE0E0E0)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoRenew,
                    onChanged: (value) {
                      setState(() => _autoRenew = value);
                    },
                    activeColor: const Color(0xFFFF0000), // Team Ragnarok red
                    activeTrackColor:
                        const Color(0xFFFF0000).withValues(alpha: 0.3),
                    inactiveThumbColor:
                        isDark ? Colors.grey[400] : Colors.grey[600],
                    inactiveTrackColor:
                        isDark ? const Color(0xFF404040) : Colors.grey[300],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    required bool isDark,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[700],
          ),
        ),
        if (trailing != null) ...[
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ] else ...[
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
