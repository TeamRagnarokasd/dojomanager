import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class BiometricDetectionWidget extends StatelessWidget {
  final List<String> availableBiometrics;
  final VoidCallback onDetectionComplete;

  const BiometricDetectionWidget({
    super.key,
    required this.availableBiometrics,
    required this.onDetectionComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        children: [
          // Detection icon
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              shape: BoxShape.circle,
              border: Border.all(
                color: availableBiometrics.isNotEmpty
                    ? const Color(0xFFFF0000)
                    : Colors.grey.shade600,
                width: 3,
              ),
            ),
            child: Icon(
              _getBiometricIcon(),
              size: 15.w,
              color: availableBiometrics.isNotEmpty
                  ? const Color(0xFFFF0000)
                  : Colors.grey.shade600,
            ),
          ),

          SizedBox(height: 4.h),

          // Detection status
          Text(
            availableBiometrics.isNotEmpty
                ? 'Sensori Biometrici Rilevati'
                : 'Nessun Sensore Rilevato',
            style: GoogleFonts.inter(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 2.h),

          // Available methods
          if (availableBiometrics.isNotEmpty) ...[
            Text(
              'Metodi disponibili sul tuo dispositivo:',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 3.h),

            // List of available methods
            ...availableBiometrics.map((method) => _buildMethodCard(method)),

            SizedBox(height: 4.h),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDetectionComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continua Configurazione',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Il tuo dispositivo non supporta l\'autenticazione biometrica o non ha sensori configurati.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 4.h),

            // Instructions for enabling
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 6.w,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Per utilizzare l\'autenticazione biometrica, configura Face ID, Touch ID o Impronta digitale nelle impostazioni del dispositivo.',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey.shade300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get appropriate icon based on available biometrics
  IconData _getBiometricIcon() {
    if (availableBiometrics.isEmpty) {
      return Icons.fingerprint_outlined;
    }

    if (availableBiometrics.contains('face')) {
      return Icons.face;
    } else if (availableBiometrics.contains('fingerprint')) {
      return Icons.fingerprint;
    } else {
      return Icons.security;
    }
  }

  /// Build individual biometric method card
  Widget _buildMethodCard(String method) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF0000).withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(
            _getMethodIcon(method),
            color: const Color(0xFFFF0000),
            size: 6.w,
          ),
          SizedBox(width: 4.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getMethodDisplayName(method),
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                _getMethodDescription(method),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Disponibile',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get icon for biometric method
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

  /// Get display name for biometric method
  String _getMethodDisplayName(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'Face ID / Riconoscimento Facciale';
      case 'fingerprint':
        return 'Touch ID / Impronta Digitale';
      case 'iris':
        return 'Riconoscimento Iris';
      default:
        return 'Autenticazione Biometrica';
    }
  }

  /// Get description for biometric method
  String _getMethodDescription(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'Accesso rapido con riconoscimento del volto';
      case 'fingerprint':
        return 'Accesso sicuro con impronta digitale';
      case 'iris':
        return 'Accesso sicuro con riconoscimento dell\'iris';
      default:
        return 'Metodo di autenticazione sicuro';
    }
  }
}
