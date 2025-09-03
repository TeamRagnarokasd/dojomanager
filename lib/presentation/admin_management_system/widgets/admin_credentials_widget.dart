import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class AdminCredentialsWidget extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminCredentialsWidget({super.key, required this.onRefresh});

  @override
  State<AdminCredentialsWidget> createState() => _AdminCredentialsWidgetState();
}

class _AdminCredentialsWidgetState extends State<AdminCredentialsWidget> {
  bool _showPassword = false;
  String _authStatus = 'Loading...';
  Map<String, dynamic>? _principalAdmin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrincipalAdminData();
  }

  Future<void> _loadPrincipalAdminData() async {
    try {
      setState(() => _isLoading = true);

      final client = SupabaseService.instance.client;

      // Get principal admin profile
      final response =
          await client
              .from('user_profiles')
              .select('*')
              .eq('role', 'principal_admin')
              .single();

      // Check current auth status
      final currentUser = client.auth.currentUser;
      String authStatus = 'Non autenticato';

      if (currentUser != null) {
        if (currentUser.id == response['id']) {
          authStatus = '✅ Autenticato come Admin Principale';
        } else {
          authStatus = '⚠️ Autenticato con altro account';
        }
      }

      setState(() {
        _principalAdmin = response;
        _authStatus = authStatus;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copiato negli appunti'),
        backgroundColor: AppTheme.lightTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.lightTheme.primaryColor,
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Principal Admin Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(20.sp),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightTheme.primaryColor.withAlpha(26),
                    Colors.white,
                  ],
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
                          color: AppTheme.primaryColor,
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
                              'Admin Principale',
                              style: GoogleFonts.inter(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              'Credenziali di accesso sicure',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Credentials Section
                  _buildCredentialField(
                    'Email',
                    'lutadordeeliteravenna@gmail.com',
                    Icons.email,
                  ),
                  SizedBox(height: 16.h),

                  _buildCredentialField(
                    'Password',
                    _showPassword ? 'Magnus833cc' : '••••••••••',
                    Icons.lock,
                    isPassword: true,
                  ),
                  SizedBox(height: 20.h),

                  // Auth Status
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.sp),
                    decoration: BoxDecoration(
                      color:
                          _authStatus.contains('✅')
                              ? Colors.green.withAlpha(26)
                              : Colors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _authStatus.contains('✅')
                                ? Colors.green
                                : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _authStatus.contains('✅')
                              ? Icons.check_circle
                              : Icons.warning,
                          color:
                              _authStatus.contains('✅')
                                  ? Colors.green
                                  : Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            _authStatus,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color:
                                  _authStatus.contains('✅')
                                      ? Colors.green[800]
                                      : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20.h),

          // Admin Profile Info
          if (_principalAdmin != null) ...[
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
                      'Informazioni Profilo',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildInfoRow(
                      'Nome Completo',
                      _principalAdmin!['full_name'] ?? 'N/A',
                    ),
                    _buildInfoRow('Email', _principalAdmin!['email'] ?? 'N/A'),
                    _buildInfoRow('Ruolo', 'Admin Principale'),
                    _buildInfoRow(
                      'Stato Account',
                      _principalAdmin!['is_active'] == true
                          ? 'Attivo'
                          : 'Inattivo',
                    ),
                    _buildInfoRow(
                      'Data Creazione',
                      _formatDate(_principalAdmin!['created_at']),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: 20.h),

          // Security Notice
          Card(
            elevation: 2,
            color: Colors.blue.withAlpha(26),
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
                      const Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8.w),
                      Text(
                        'Note di Sicurezza',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '• Queste credenziali garantiscono accesso completo al sistema\n'
                    '• L\'admin principale può promuovere utenti e approvare registrazioni\n'
                    '• Le sessioni vengono monitorate per sicurezza\n'
                    '• Cambiare password regolarmente per sicurezza ottimale',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.blue[800],
                      height: 1.4,
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

  Widget _buildCredentialField(
    String label,
    String value,
    IconData icon, {
    bool isPassword = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isPassword) ...[
                IconButton(
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ),
              ],
              IconButton(
                onPressed:
                    () => _copyToClipboard(
                      isPassword && !_showPassword ? 'Magnus833cc' : value,
                      label,
                    ),
                icon: Icon(Icons.copy, color: AppTheme.primaryColor, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data non valida';
    }
  }
}
