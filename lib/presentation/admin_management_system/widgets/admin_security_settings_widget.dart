import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class AdminSecuritySettingsWidget extends StatefulWidget {
  const AdminSecuritySettingsWidget({super.key});

  @override
  State<AdminSecuritySettingsWidget> createState() =>
      _AdminSecuritySettingsWidgetState();
}

class _AdminSecuritySettingsWidgetState
    extends State<AdminSecuritySettingsWidget> {
  List<Map<String, dynamic>> _activeSessions = [];
  bool _isLoading = true;
  bool _twoFactorEnabled = false;
  bool _sessionMonitoring = true;
  bool _loginAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    try {
      setState(() => _isLoading = true);

      final client = SupabaseService.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      // Load active sessions
      final sessionsResponse = await client
          .from('admin_sessions')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      setState(() {
        _activeSessions = List<Map<String, dynamic>>.from(sessionsResponse);
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_management.security_load_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _terminateSession(String sessionId) async {
    try {
      final client = SupabaseService.instance.client;

      await client
          .from('admin_sessions')
          .update({'is_active': false}).eq('id', sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_management.session_ended'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadSecurityData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_management.end_session_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _terminateAllSessions() async {
    final confirmResult = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'admin_management.confirm_termination'.tr(),
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sei sicuro di voler terminare tutte le sessioni attive? '
          'Dovrai effettuare nuovamente l\'accesso su tutti i dispositivi.',
          style: GoogleFonts.inter(fontSize: 16.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Termina Tutto',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    if (confirmResult != true) return;

    try {
      final client = SupabaseService.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      await client
          .from('admin_sessions')
          .update({'is_active': false})
          .eq('user_id', userId)
          .eq('is_active', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_management.all_sessions_ended'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadSecurityData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_management.end_sessions_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security Overview Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(20.sp),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.green.withAlpha(26), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.sp),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'profile.account_security_title'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'admin_management.account_protected'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Security Settings
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Impostazioni Sicurezza',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Two Factor Authentication
                  _buildSecurityToggle(
                    'Autenticazione a Due Fattori',
                    'Aggiungi un ulteriore livello di sicurezza',
                    Icons.security,
                    _twoFactorEnabled,
                    (value) {
                      setState(() => _twoFactorEnabled = value);
                      // In a real app, you would implement 2FA setup here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'admin_management.2fa_next_update'.tr()
                                : 'profile.2fa_deactivated'.tr(),
                          ),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                  ),

                  Divider(height: 32.h),

                  // Session Monitoring
                  _buildSecurityToggle(
                    'Monitoraggio Sessioni',
                    'Monitora accessi e sessioni attive',
                    Icons.monitor,
                    _sessionMonitoring,
                    (value) {
                      setState(() => _sessionMonitoring = value);
                    },
                  ),

                  Divider(height: 32.h),

                  // Login Alerts
                  _buildSecurityToggle(
                    'Avvisi di Accesso',
                    'Ricevi notifiche per nuovi accessi',
                    Icons.notifications_active,
                    _loginAlerts,
                    (value) {
                      setState(() => _loginAlerts = value);
                    },
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Active Sessions
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Sessioni Attive',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      if (_activeSessions.length > 1) ...[
                        TextButton.icon(
                          onPressed: _terminateAllSessions,
                          icon: const Icon(Icons.logout, size: 16),
                          label: Text(
                            'Termina Tutto',
                            style: GoogleFonts.inter(fontSize: 12.sp),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 16.h),
                  if (_isLoading) ...[
                    Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ] else if (_activeSessions.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.sp),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.devices,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'common.no_sessions'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ..._activeSessions
                        .map((session) => _buildSessionCard(session))
                        .toList(),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Password Policy
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Criteri Password',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildPasswordCriterion('Minimo 8 caratteri', true),
                  _buildPasswordCriterion('Almeno una lettera maiuscola', true),
                  _buildPasswordCriterion('Almeno una lettera minuscola', true),
                  _buildPasswordCriterion('Almeno un numero', true),
                  _buildPasswordCriterion(
                    'Almeno un carattere speciale',
                    false,
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      // In a real app, you would navigate to change password screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'admin_management.password_change_next_update'.tr(),
                          ),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_reset, size: 16),
                    label: Text(
                      'profile.change_password'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildSecurityToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.sp),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final createdAt = DateTime.parse(session['created_at'] as String);
    final expiresAt = DateTime.parse(session['expires_at'] as String);
    final isCurrentSession = session['session_token'] ==
        SupabaseService.instance.client.auth.currentSession?.accessToken;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: isCurrentSession
            ? AppTheme.primaryColor.withAlpha(26)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentSession
              ? AppTheme.primaryColor.withAlpha(77)
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.devices,
                color:
                    isCurrentSession ? AppTheme.primaryColor : Colors.grey[600],
                size: 20,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  isCurrentSession ? 'Sessione Corrente' : 'Altra Sessione',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isCurrentSession
                        ? AppTheme.primaryColor
                        : Colors.grey[800],
                  ),
                ),
              ),
              if (!isCurrentSession) ...[
                IconButton(
                  onPressed: () => _terminateSession(session['id'] as String),
                  icon: const Icon(Icons.logout, size: 18),
                  style: IconButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          if (session['ip_address'] != null) ...[
            Text(
              'IP: ${session['ip_address']}',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (session['user_agent'] != null) ...[
            Text(
              'Browser: ${_formatUserAgent(session['user_agent'] as String)}',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          Text(
            'Creata: ${_formatDateTime(createdAt)}',
            style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey[600]),
          ),
          Text(
            'Scade: ${_formatDateTime(expiresAt)}',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: expiresAt.isBefore(
                DateTime.now().add(const Duration(days: 1)),
              )
                  ? Colors.orange[800]
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCriterion(String criterion, bool met) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            color: met ? Colors.green : Colors.grey[400],
            size: 16,
          ),
          SizedBox(width: 8.w),
          Text(
            criterion,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: met ? Colors.green[800] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatUserAgent(String userAgent) {
    if (userAgent.contains('Chrome')) return 'Chrome';
    if (userAgent.contains('Firefox')) return 'Firefox';
    if (userAgent.contains('Safari')) return 'Safari';
    if (userAgent.contains('Edge')) return 'Edge';
    return 'Browser sconosciuto';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
