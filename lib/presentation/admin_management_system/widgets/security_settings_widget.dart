import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SecuritySettingsWidget extends StatelessWidget {
  final bool isPrincipalAdmin;
  final Function(String) onSecurityAction;

  const SecuritySettingsWidget({
    super.key,
    required this.isPrincipalAdmin,
    required this.onSecurityAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.security,
                  color: Colors.red,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Impostazioni di Sicurezza',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Gestione sessioni e controlli di accesso',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isPrincipalAdmin
                      ? Colors.red.withAlpha(26)
                      : Colors.grey.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPrincipalAdmin ? 'Accesso completo' : 'Accesso limitato',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isPrincipalAdmin ? Colors.red : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (!isPrincipalAdmin)
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.amber.shade700,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Alcune funzioni di sicurezza richiedono privilegi di admin principale',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 20.h),
          _buildSecuritySection(
            'Gestione Sessioni',
            'Controlli per la sicurezza delle sessioni utente',
            [
              _buildSecurityAction(
                'Reset Sessioni Utente',
                'Disconnette tutti gli utenti e forza il re-login',
                Icons.logout,
                Colors.orange,
                'reset_sessions',
                isPrincipalAdmin,
              ),
              _buildSecurityAction(
                'Monitoraggio Accessi',
                'Visualizza tentativi di accesso e sessioni attive',
                Icons.monitor,
                Colors.blue,
                'monitor_access',
                true,
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildSecuritySection(
            'Controlli di Sicurezza',
            'Audit e verifica dei permessi di sistema',
            [
              _buildSecurityAction(
                'Audit Permessi',
                'Verifica e valida tutti i permessi utente',
                Icons.verified_user,
                Colors.green,
                'audit_permissions',
                isPrincipalAdmin,
              ),
              _buildSecurityAction(
                'Log di Sicurezza',
                'Esporta log dettagliati delle attività di sicurezza',
                Icons.file_download,
                Colors.purple,
                'export_security_logs',
                true,
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildSecuritySection(
            'Sistema e Backup',
            'Operazioni di manutenzione e sicurezza del sistema',
            [
              _buildSecurityAction(
                'Backup Sistema',
                'Crea backup completo delle configurazioni',
                Icons.backup,
                Colors.indigo,
                'backup_system',
                isPrincipalAdmin,
              ),
              _buildSecurityAction(
                'Verifica Integrità',
                'Controlla l\'integrità dei dati di sistema',
                Icons.shield_outlined,
                Colors.teal,
                'verify_integrity',
                isPrincipalAdmin,
              ),
            ],
          ),
          if (isPrincipalAdmin) ...[
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fingerprint, color: Colors.red, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Autenticazione Biometrica',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Per operazioni sensibili viene richiesta l\'autenticazione biometrica per garantire la massima sicurezza',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton.icon(
                    onPressed: () => _showBiometricPrompt(context),
                    icon: Icon(Icons.fingerprint, size: 16.sp),
                    label: Text('biometric.configure_biometric'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecuritySection(
      String title, String subtitle, List<Widget> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: AppTheme.textSecondaryLight,
          ),
        ),
        SizedBox(height: 12.h),
        ...actions,
      ],
    );
  }

  Widget _buildSecurityAction(
    String title,
    String description,
    IconData icon,
    Color color,
    String actionId,
    bool enabled,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _handleSecurityAction(actionId) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? color.withAlpha(77) : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: (enabled ? color : Colors.grey).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? color : Colors.grey,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? AppTheme.textPrimaryLight
                              : AppTheme.textPrimaryLight.withAlpha(128),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: enabled
                              ? AppTheme.textSecondaryLight
                              : AppTheme.textSecondaryLight.withAlpha(128),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!enabled)
                  Icon(
                    Icons.lock,
                    color: Colors.grey,
                    size: 16.sp,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color,
                    size: 16.sp,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSecurityAction(String actionId) {
    onSecurityAction(actionId);
  }

  void _showBiometricPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: Colors.red),
            SizedBox(width: 8.w),
            Text(
              'Autenticazione Biometrica',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Configura l\'autenticazione biometrica per operazioni sensibili'),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Richiesto per: Reset sessioni, Audit permessi, Backup sistema',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Simulate biometric setup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('biometric.configured_success'.tr()),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('biometric.configure'.tr()),
          ),
        ],
      ),
    );
  }
}
