import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class TestAuthenticationWidget extends StatelessWidget {
  final String selectedMethod;
  final bool testPassed;
  final VoidCallback onTest;
  final VoidCallback? onContinue;

  const TestAuthenticationWidget({
    super.key,
    required this.selectedMethod,
    required this.testPassed,
    required this.onTest,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        children: [
          // Title
          Text(
            'Test Autenticazione',
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
            'Ora testiamo il funzionamento del ${_getMethodDisplayName(selectedMethod)} per assicurarci che tutto sia configurato correttamente.',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Test interface
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: testPassed
                    ? Colors.green
                    : const Color(0xFFFF0000).withAlpha(77),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Test icon
                Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    color: testPassed
                        ? Colors.green.withAlpha(26)
                        : const Color(0xFFFF0000).withAlpha(26),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          testPassed ? Colors.green : const Color(0xFFFF0000),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    testPassed
                        ? Icons.check_circle_outline
                        : _getMethodIcon(selectedMethod),
                    size: 15.w,
                    color: testPassed ? Colors.green : const Color(0xFFFF0000),
                  ),
                ),

                SizedBox(height: 3.h),

                // Status text
                Text(
                  testPassed
                      ? 'Test Completato con Successo!'
                      : 'Pronto per il Test',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: testPassed ? Colors.green : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 1.h),

                // Instructions
                Text(
                  testPassed
                      ? 'Il ${_getMethodDisplayName(selectedMethod)} funziona correttamente'
                      : _getTestInstructions(selectedMethod),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey.shade400,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 3.h),

                // Test button
                if (!testPassed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getMethodIcon(selectedMethod),
                            color: Colors.white,
                            size: 5.w,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Inizia Test',
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
          ),

          SizedBox(height: 4.h),

          // Help section
          if (!testPassed)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withAlpha(77)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Colors.orange,
                    size: 6.w,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Problemi con il test?',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          _getTroubleshootingTip(selectedMethod),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.orange.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Continue button
          if (testPassed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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

  /// Get test instructions
  String _getTestInstructions(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'Posiziona il viso di fronte alla fotocamera e segui le istruzioni';
      case 'fingerprint':
        return 'Posiziona il dito sul sensore di impronte quando richiesto';
      case 'iris':
        return 'Guarda lo schermo mantenendo gli occhi aperti';
      default:
        return 'Segui le istruzioni per completare l\'autenticazione';
    }
  }

  /// Get troubleshooting tip
  String _getTroubleshootingTip(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'Assicurati di essere in un ambiente ben illuminato e tieni il dispositivo a distanza del braccio.';
      case 'fingerprint':
        return 'Assicurati che il dito sia pulito e asciutto. Posiziona il dito completamente sul sensore.';
      case 'iris':
        return 'Mantieni gli occhi aperti e guarda direttamente lo schermo senza muovere la testa.';
      default:
        return 'Verifica che il sensore sia pulito e segui attentamente le istruzioni.';
    }
  }
}
