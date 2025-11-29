import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class SetupCompletionWidget extends StatelessWidget {
  final String selectedMethod;
  final Map<String, bool> settings;
  final VoidCallback onActivate;
  final VoidCallback onComplete;
  final bool isActivated;

  const SetupCompletionWidget({
    super.key,
    required this.selectedMethod,
    required this.settings,
    required this.onActivate,
    required this.onComplete,
    required this.isActivated,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        children: [
          // Success icon
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: isActivated
                  ? Colors.green.withAlpha(26)
                  : const Color(0xFF2A2A2A),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActivated ? Colors.green : const Color(0xFFFF0000),
                width: 3,
              ),
            ),
            child: Icon(
              isActivated ? Icons.check_circle : Icons.rocket_launch_outlined,
              size: 15.w,
              color: isActivated ? Colors.green : const Color(0xFFFF0000),
            ),
          ),

          SizedBox(height: 4.h),

          // Title
          Text(
            isActivated
                ? 'Configurazione Completata!'
                : 'Pronto per l\'Attivazione',
            style: GoogleFonts.inter(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: isActivated ? Colors.green : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 2.h),

          // Description
          Text(
            isActivated
                ? 'L\'autenticazione biometrica è ora attiva per il tuo account Team Ragnarok.'
                : 'Tutto è configurato correttamente. Attiva l\'autenticazione biometrica per iniziare ad utilizzarla.',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Configuration summary
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActivated ? Colors.green : Colors.grey.shade800,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Riepilogo Configurazione',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 3.h),

                // Method selected
                _buildSummaryRow(
                  icon: _getMethodIcon(selectedMethod),
                  title: 'Metodo Biometrico',
                  value: _getMethodDisplayName(selectedMethod),
                  isActive: true,
                ),

                Divider(color: Colors.grey.shade800, height: 3.h),

                // Security level
                _buildSummaryRow(
                  icon: Icons.security,
                  title: 'Livello Sicurezza',
                  value: _getSecurityLevelText(),
                  isActive: true,
                ),

                Divider(color: Colors.grey.shade800, height: 3.h),

                // Active features
                Column(
                  children: [
                    _buildFeatureSummary(
                        'Avvio App', settings['appLaunch'] ?? false),
                    _buildFeatureSummary('Conferma Pagamenti',
                        settings['paymentConfirmation'] ?? false),
                    _buildFeatureSummary('Dati Sensibili',
                        settings['sensitiveDataAccess'] ?? false),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Security status indicator
          if (isActivated)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(77)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    color: Colors.green,
                    size: 6.w,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Protezione Attiva',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          'Il tuo account è ora protetto con autenticazione biometrica',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.green.withAlpha(204),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActivated ? onComplete : onActivate,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isActivated ? Colors.green : const Color(0xFFFF0000),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActivated ? Icons.home : Icons.security,
                    color: Colors.white,
                    size: 5.w,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    isActivated
                        ? 'Vai alla Dashboard'
                        : 'Attiva Autenticazione',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build summary row
  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isActive ? const Color(0xFFFF0000) : Colors.grey.shade500,
          size: 5.w,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Build feature summary
  Widget _buildFeatureSummary(String feature, bool isEnabled) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.check_circle : Icons.cancel,
            color: isEnabled ? Colors.green : Colors.grey.shade600,
            size: 4.w,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              feature,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: isEnabled ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ),
          Text(
            isEnabled ? 'Attivo' : 'Disattivo',
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: isEnabled ? Colors.green : Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Get method icon
  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return Icons.face;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'iris':
        return Icons.visibility;
      default:
        return Icons.security;
    }
  }

  /// Get method display name
  String _getMethodDisplayName(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'Face ID';
      case 'fingerprint':
        return 'Touch ID';
      case 'iris':
        return 'Riconoscimento Iris';
      default:
        return 'Autenticazione Biometrica';
    }
  }

  /// Get security level text
  String _getSecurityLevelText() {
    final enabledCount = settings.values.where((enabled) => enabled).length;
    if (enabledCount == 3) return 'Massimo';
    if (enabledCount == 2) return 'Alto';
    if (enabledCount == 1) return 'Medio';
    return 'Basso';
  }
}
