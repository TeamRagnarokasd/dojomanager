import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/auth_service.dart';

// Add this import for kDebugMode

class BiometricPromptWidget extends StatefulWidget {
  final VoidCallback onBiometricLogin;
  final VoidCallback onSkip;
  final bool isAvailable;

  const BiometricPromptWidget({
    Key? key,
    required this.onBiometricLogin,
    required this.onSkip,
    required this.isAvailable,
  }) : super(key: key);

  @override
  State<BiometricPromptWidget> createState() => _BiometricPromptWidgetState();
}

class _BiometricPromptWidgetState extends State<BiometricPromptWidget> {
  final AuthService _authService = AuthService.instance;
  bool _isEnabling = false;
  bool _isEnabled = false;
  Map<String, dynamic>? _pendingSetup;

  @override
  void initState() {
    super.initState();
    _loadPendingSetup();
  }

  Future<void> _loadPendingSetup() async {
    try {
      final pendingSetup = await _authService.getPendingBiometricSetup();
      if (mounted) {
        setState(() {
          _pendingSetup = pendingSetup;
        });
      }
    } catch (e) {
      print('Error loading pending biometric setup: $e');
    }
  }

  Future<void> _enableBiometricAuth() async {
    if (_isEnabling) return;

    setState(() {
      _isEnabling = true;
    });

    try {
      // Check if biometric is actually available
      final isAvailable = await _authService.biometricService.isAvailable();
      if (!isAvailable) {
        _authService.showErrorToast(
          'Autenticazione biometrica non disponibile su questo dispositivo',
        );
        return;
      }

      // Get available biometric types
      final availableBiometrics =
          await _authService.biometricService.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        _authService.showErrorToast(
          'Nessun metodo biometrico configurato. Configura Face ID, Touch ID o impronta digitale nelle impostazioni del dispositivo.',
        );
        return;
      }

      // Test biometric authentication before enabling
      final authenticated = await _authService.biometricService.authenticate(
        reason: 'Conferma la tua identità per abilitare l\'accesso biometrico',
        stickyAuth: true,
      );

      if (!authenticated) {
        _authService.showErrorToast('Autenticazione biometrica fallita');
        return;
      }

      // Enable biometric authentication
      final success = await _authService.enableBiometricAuth();

      if (success) {
        setState(() {
          _isEnabled = true;
        });

        HapticFeedback.heavyImpact();
        _authService
            .showSuccessToast('Accesso biometrico abilitato con successo!');

        // Wait a moment then proceed to dashboard
        await Future.delayed(const Duration(milliseconds: 1500));
        widget.onBiometricLogin();
      } else {
        _authService.showErrorToast(
            'Errore nell\'abilitazione dell\'accesso biometrico');
      }
    } catch (e) {
      print('Error enabling biometric auth: $e');
      _authService.showErrorToast('Errore inaspettato: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isEnabling = false;
        });
      }
    }
  }

  Future<void> _skipBiometricSetup() async {
    try {
      await _authService.clearPendingBiometricSetup();
      HapticFeedback.lightImpact();
      widget.onSkip();
    } catch (e) {
      print('Error skipping biometric setup: $e');
      widget.onSkip();
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Always show prompt when there's pending setup, regardless of availability
    if (_pendingSetup == null) {
      return const SizedBox.shrink();
    }

    // Show availability warning if biometric is not available
    if (!widget.isAvailable) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 12.w,
            ),
            SizedBox(height: 3.h),
            Text(
              'Biometrico Non Disponibile',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Il dispositivo non supporta l\'autenticazione biometrica o non è configurata. Puoi accedere normalmente con email e password.',
              textAlign: TextAlign.center,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryLight,
                height: 1.4,
              ),
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onSkip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continua senza Biometrico',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isEnabled ? Colors.green : AppTheme.primaryLight,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isEnabled ? Colors.green : AppTheme.primaryLight)
                .withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: _isEnabled
                ? Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 12.w,
                  )
                : CustomIconWidget(
                    iconName: 'fingerprint',
                    color: AppTheme.primaryLight,
                    size: 48,
                  ),
          ),

          SizedBox(height: 3.h),

          // Title
          Text(
            _isEnabled
                ? 'Accesso Biometrico Abilitato!'
                : 'Abilita Accesso Biometrico',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: _isEnabled ? Colors.green : AppTheme.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: 1.h),

          // Description
          Text(
            _isEnabled
                ? 'Potrai ora accedere velocemente usando Face ID, Touch ID o impronta digitale'
                : 'Accedi rapidamente la prossima volta con Face ID, Touch ID o impronta digitale',
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
              height: 1.4,
            ),
          ),

          if (_pendingSetup != null && !_isEnabled) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person,
                    color: AppTheme.primaryLight,
                    size: 4.w,
                  ),
                  SizedBox(width: 2.w),
                  Flexible(
                    child: Text(
                      'Per: ${_pendingSetup!['fullName']}',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 4.h),

          // Action Buttons
          if (!_isEnabled) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isEnabling ? null : _skipBiometricSetup,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      side: BorderSide(color: AppTheme.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Salta',
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isEnabling ? null : _enableBiometricAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isEnabling
                        ? SizedBox(
                            width: 5.w,
                            height: 5.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Abilita Biometrico',
                            style: AppTheme.lightTheme.textTheme.titleSmall
                                ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Success state - just continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onBiometricLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 5.w),
                    SizedBox(width: 2.w),
                    Text(
                      'Continua',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Debug info (only in development)
          if (kDebugMode && _pendingSetup != null) ...[
            SizedBox(height: 2.h),
            Text(
              'Debug: Setup pending for ${_pendingSetup!['email']}',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
