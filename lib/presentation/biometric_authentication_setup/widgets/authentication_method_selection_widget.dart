import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthenticationMethodSelectionWidget extends StatelessWidget {
  final List<String> availableMethods;
  final String selectedMethod;
  final Function(String) onMethodSelected;
  final VoidCallback onContinue;

  const AuthenticationMethodSelectionWidget({
    super.key,
    required this.availableMethods,
    required this.selectedMethod,
    required this.onMethodSelected,
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
            'Scegli il Metodo Preferito',
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
            'Seleziona il metodo di autenticazione biometrica che preferisci utilizzare per accedere all\'app Team Ragnarok.',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Available methods
          Expanded(
            child: ListView.builder(
              itemCount: availableMethods.length,
              itemBuilder: (context, index) {
                final method = availableMethods[index];
                final isSelected = method == selectedMethod;

                return _buildMethodOption(method, isSelected);
              },
            ),
          ),

          SizedBox(height: 3.h),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedMethod.isNotEmpty ? onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedMethod.isNotEmpty
                    ? const Color(0xFFFF0000)
                    : Colors.grey.shade700,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continua con ${_getMethodDisplayName(selectedMethod)}',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
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

  /// Build individual method option
  Widget _buildMethodOption(String method, bool isSelected) {
    return GestureDetector(
      onTap: () => onMethodSelected(method),
      child: Container(
        margin: EdgeInsets.only(bottom: 3.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF0000).withAlpha(26)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF0000) : Colors.grey.shade700,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Method icon
            Container(
              width: 15.w,
              height: 15.w,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFFF0000) : Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getMethodIcon(method),
                color: Colors.white,
                size: 8.w,
              ),
            ),

            SizedBox(width: 4.w),

            // Method details
            Expanded(
              child: Column(
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
                  SizedBox(height: 1.h),
                  Text(
                    _getMethodDescription(method),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey.shade400,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 1.h),

                  // Security level
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: _getSecurityColor(method),
                        size: 4.w,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        _getSecurityLevel(method),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: _getSecurityColor(method),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Selection indicator
            if (isSelected)
              Container(
                width: 6.w,
                height: 6.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF0000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 4.w,
                ),
              )
            else
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade600, width: 2),
                ),
              ),
          ],
        ),
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
    if (method.isEmpty) return '';

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

  /// Get description for biometric method
  String _getMethodDescription(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'Accesso rapido e sicuro utilizzando il riconoscimento facciale. Tieni il dispositivo di fronte al viso per sbloccare l\'app.';
      case 'fingerprint':
        return 'Accesso sicuro utilizzando la tua impronta digitale. Posiziona il dito sul sensore per accedere rapidamente.';
      case 'iris':
        return 'Massima sicurezza con riconoscimento dell\'iris. Guarda lo schermo per un accesso ultra-sicuro.';
      default:
        return 'Metodo di autenticazione biometrica sicuro e conveniente.';
    }
  }

  /// Get security level for method
  String _getSecurityLevel(String method) {
    switch (method.toLowerCase()) {
      case 'face':
        return 'SICUREZZA ALTA';
      case 'fingerprint':
        return 'SICUREZZA ALTA';
      case 'iris':
        return 'SICUREZZA MASSIMA';
      default:
        return 'SICUREZZA ALTA';
    }
  }

  /// Get security color for method
  Color _getSecurityColor(String method) {
    switch (method.toLowerCase()) {
      case 'iris':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }
}
