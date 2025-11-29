import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class BiometricToggleControlsWidget extends StatelessWidget {
  final Map<String, bool> settings;
  final Function(String, bool) onSettingChanged;
  final VoidCallback onContinue;

  const BiometricToggleControlsWidget({
    super.key,
    required this.settings,
    required this.onSettingChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        children: [
          // Title
          Text(
            'Preferenze Biometriche',
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 2.h),

          // Description
          Text(
            'Scegli quando utilizzare l\'autenticazione biometrica nell\'app Team Ragnarok.',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Settings toggles
          Expanded(
            child: ListView(
              children: [
                _buildToggleCard(
                  key: 'appLaunch',
                  icon: Icons.launch,
                  title: 'Avvio App',
                  description:
                      'Richiedi autenticazione biometrica all\'apertura dell\'app',
                  isEnabled: settings['appLaunch'] ?? true,
                  isRecommended: true,
                ),
                SizedBox(height: 3.h),
                _buildToggleCard(
                  key: 'paymentConfirmation',
                  icon: Icons.payment,
                  title: 'Conferma Pagamenti',
                  description:
                      'Richiedi autenticazione per confermare pagamenti e transazioni',
                  isEnabled: settings['paymentConfirmation'] ?? true,
                  isRecommended: true,
                ),
                SizedBox(height: 3.h),
                _buildToggleCard(
                  key: 'sensitiveDataAccess',
                  icon: Icons.security,
                  title: 'Dati Sensibili',
                  description:
                      'Richiedi autenticazione per accedere a informazioni personali e mediche',
                  isEnabled: settings['sensitiveDataAccess'] ?? true,
                  isRecommended: true,
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Security level indicator
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: _getSecurityLevelColor().withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getSecurityLevelColor().withAlpha(77)),
            ),
            child: Row(
              children: [
                Icon(
                  _getSecurityLevelIcon(),
                  color: _getSecurityLevelColor(),
                  size: 6.w,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Livello di Sicurezza: ${_getSecurityLevelText()}',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _getSecurityLevelColor(),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        _getSecurityLevelDescription(),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: _getSecurityLevelColor().withAlpha(204),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Conferma Preferenze',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual toggle card
  Widget _buildToggleCard({
    required String key,
    required IconData icon,
    required String title,
    required String description,
    required bool isEnabled,
    bool isRecommended = false,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFFFF0000).withAlpha(77)
              : Colors.grey.shade800,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: isEnabled
                  ? const Color(0xFFFF0000).withAlpha(26)
                  : Colors.grey.shade700.withAlpha(128),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isEnabled ? const Color(0xFFFF0000) : Colors.grey.shade500,
              size: 6.w,
            ),
          ),

          SizedBox(width: 4.w),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (isRecommended) ...[
                      SizedBox(width: 2.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 0.5.h),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CONSIGLIATO',
                          style: GoogleFonts.inter(
                            fontSize: 8.sp,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey.shade400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 2.w),

          // Toggle switch
          Switch(
            value: isEnabled,
            onChanged: (value) {
              onSettingChanged(key, value);
            },
            activeColor: const Color(0xFFFF0000),
            activeTrackColor: const Color(0xFFFF0000).withAlpha(77),
            inactiveTrackColor: Colors.grey.shade700,
            inactiveThumbColor: Colors.grey.shade500,
          ),
        ],
      ),
    );
  }

  /// Get security level based on enabled settings
  int _getEnabledSettingsCount() {
    return settings.values.where((enabled) => enabled).length;
  }

  /// Get security level color
  Color _getSecurityLevelColor() {
    final count = _getEnabledSettingsCount();
    if (count == 3) return Colors.green;
    if (count == 2) return Colors.orange;
    return Colors.red;
  }

  /// Get security level icon
  IconData _getSecurityLevelIcon() {
    final count = _getEnabledSettingsCount();
    if (count == 3) return Icons.shield;
    if (count == 2) return Icons.shield_outlined;
    return Icons.warning;
  }

  /// Get security level text
  String _getSecurityLevelText() {
    final count = _getEnabledSettingsCount();
    if (count == 3) return 'Massimo';
    if (count == 2) return 'Alto';
    if (count == 1) return 'Medio';
    return 'Basso';
  }

  /// Get security level description
  String _getSecurityLevelDescription() {
    final count = _getEnabledSettingsCount();
    if (count == 3) {
      return 'Tutte le funzioni protette - Massima sicurezza';
    } else if (count == 2) {
      return 'Buona protezione con alcune funzioni sbloccate';
    } else if (count == 1) {
      return 'Protezione base - Considera di abilitare più opzioni';
    } else {
      return 'Nessuna protezione biometrica attiva';
    }
  }
}
