import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class AdminCredentialsWidget extends StatefulWidget {
  final VoidCallback onRefresh;

  const AdminCredentialsWidget({super.key, required this.onRefresh});

  @override
  State<AdminCredentialsWidget> createState() => _AdminCredentialsWidgetState();
}

class _AdminCredentialsWidgetState extends State<AdminCredentialsWidget> {
  bool _showPassword = false;
  String _authStatus = '';
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

      final response = await client
          .from('user_profiles')
          .select('*')
          .eq('role', 'principal_admin')
          .single();

      final currentUser = client.auth.currentUser;
      String authStatus = 'admin_management.not_authenticated'.tr();

      if (currentUser != null) {
        if (currentUser.id == response['id']) {
          authStatus = 'admin_management.auth_as_principal'.tr();
        } else {
          authStatus = 'admin_management.auth_other_account'.tr();
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
            content: Text('admin_management.credentials_load_error'.tr()),
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
        content: Text('admin_management.copied_to_clipboard'
            .tr(namedArgs: {'label': label})),
        backgroundColor: AppTheme.lightTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditCredentialsDialog() {
    final client = SupabaseService.instance.client;
    final currentUser = client.auth.currentUser;

    final emailController =
        TextEditingController(text: currentUser?.email ?? '');
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.edit, color: AppTheme.primaryColor, size: 22),
              SizedBox(width: 8.w),
              Text(
                'Modifica Credenziali',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email di accesso',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Nuova email',
                    prefixIcon: Icon(Icons.email, color: AppTheme.primaryColor),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Nuova password (lascia vuoto per non cambiare)',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  style: GoogleFonts.inter(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Nuova password',
                    prefixIcon: Icon(Icons.lock, color: AppTheme.primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setDialogState(
                          () => showNewPassword = !showNewPassword),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 1.5.h),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  style: GoogleFonts.inter(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'Conferma nuova password',
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setDialogState(
                          () => showConfirmPassword = !showConfirmPassword),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text('common.cancel'.tr(),
                  style: GoogleFonts.inter(color: Colors.grey[600])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newEmail = emailController.text.trim();
                      final newPassword = newPasswordController.text;
                      final confirmPassword = confirmPasswordController.text;

                      if (newEmail.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Inserisci una email valida'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      if (newPassword.isNotEmpty &&
                          newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Le password non coincidono'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      if (newPassword.isNotEmpty && newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'La password deve essere di almeno 6 caratteri'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        final authClient = SupabaseService.instance.client;
                        UserAttributes attrs = UserAttributes();

                        if (newEmail != currentUser?.email) {
                          attrs = UserAttributes(email: newEmail);
                        }

                        if (newPassword.isNotEmpty) {
                          attrs = UserAttributes(
                            email: newEmail != currentUser?.email
                                ? newEmail
                                : null,
                            password: newPassword,
                          );
                        }

                        await authClient.auth.updateUser(attrs);

                        // Update email in user_profiles table too
                        if (newEmail != currentUser?.email) {
                          await authClient
                              .from('user_profiles')
                              .update({'email': newEmail}).eq(
                                  'role', 'principal_admin');
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Credenziali aggiornate con successo'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadPrincipalAdminData();
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Errore: ${e.toString().replaceAll('Exception: ', '')}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Salva',
                      style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
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
                              'roles.principal_admin_short'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              'admin_management.principal_admin_credentials'
                                  .tr(),
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit button
                      TextButton.icon(
                        onPressed: _showEditCredentialsDialog,
                        icon: Icon(Icons.edit,
                            color: AppTheme.primaryColor, size: 18),
                        label: Text(
                          'Modifica',
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Credentials Section
                  _buildCredentialField(
                    'common.email'.tr(),
                    _principalAdmin?['email'] ??
                        SupabaseService
                            .instance.client.auth.currentUser?.email ??
                        'N/A',
                    Icons.email,
                  ),
                  SizedBox(height: 16.h),

                  _buildCredentialField(
                    'common.password'.tr(),
                    _showPassword ? '••••••••••' : '••••••••••',
                    Icons.lock,
                    isPassword: true,
                  ),
                  SizedBox(height: 20.h),

                  // Auth Status
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.sp),
                    decoration: BoxDecoration(
                      color: _authStatus.contains('✅')
                          ? Colors.green.withAlpha(26)
                          : Colors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _authStatus.contains('✅')
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
                          color: _authStatus.contains('✅')
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
                              color: _authStatus.contains('✅')
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
                      'admin_management.profile_info'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildInfoRow(
                      'admin_dashboard.full_name_label'.tr(),
                      _principalAdmin!['full_name'] ?? 'N/A',
                    ),
                    _buildInfoRow('common.email'.tr(),
                        _principalAdmin!['email'] ?? 'N/A'),
                    _buildInfoRow('profile.role'.tr(),
                        'roles.principal_admin_short'.tr()),
                    _buildInfoRow(
                      'admin_management.account_status'.tr(),
                      _principalAdmin!['is_active'] == true
                          ? 'admin_management.active_status'.tr()
                          : 'admin_management.inactive_status'.tr(),
                    ),
                    _buildInfoRow(
                      'admin_management.creation_date'.tr(),
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
              if (!isPassword)
                IconButton(
                  onPressed: () => _copyToClipboard(value, label),
                  icon:
                      Icon(Icons.copy, color: AppTheme.primaryColor, size: 20),
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
