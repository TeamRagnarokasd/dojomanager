import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/profile_typography.dart';
import '../../../services/auth_service.dart';
import '../../../services/biometric_service.dart';
import '../../../services/supabase_service.dart';

class AccountSecurityWidget extends StatefulWidget {
  const AccountSecurityWidget({Key? key}) : super(key: key);

  @override
  State<AccountSecurityWidget> createState() => _AccountSecurityWidgetState();
}

class _AccountSecurityWidgetState extends State<AccountSecurityWidget> {
  bool twoFactorEnabled = false;

  // 🆕 Fingerprint login toggle — Android only, mirrors the login screen's
  // own availability check (isDeviceSupported + at least one enrolled
  // biometric). Stays false on web, so nothing new ever shows there.
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _isBiometricBusy = false;

  String get _currentEmail =>
      SupabaseService.instance.client.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    if (kIsWeb) return;
    final available = await BiometricService.instance.isAvailable();
    final biometrics = available
        ? await BiometricService.instance.getAvailableBiometrics()
        : const <String>[];
    final enabled = _currentEmail.isNotEmpty
        ? await BiometricService.instance.isBiometricEnabledForUser(
            _currentEmail,
          )
        : false;
    if (mounted) {
      setState(() {
        _biometricAvailable = available && biometrics.isNotEmpty;
        _biometricEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.account_security_title'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: ProfileTypography.sectionTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _buildEmailSection(),
          SizedBox(height: 2.h),
          _buildPasswordSection(),
          if (_biometricAvailable) ...[
            SizedBox(height: 2.h),
            _buildBiometricSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.email, color: Colors.red, size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email di accesso',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.rowLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  _currentEmail.isNotEmpty ? _currentEmail : 'Non disponibile',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: ProfileTypography.subtitle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showChangeEmailDialog,
            child: Text(
              'profile.modify'.tr(),
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: ProfileTypography.action,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.red, size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'profile.change_password'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.rowLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  'profile.last_password_change'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: ProfileTypography.subtitle,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showChangePasswordDialog,
            child: Text(
              'profile.modify'.tr(),
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: ProfileTypography.action,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint, color: Colors.red, size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accesso con impronta digitale',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.rowLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  'Entra senza scrivere email e password',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: ProfileTypography.subtitle,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _biometricEnabled,
            activeColor: Colors.red,
            onChanged: _isBiometricBusy ? null : _onBiometricToggle,
          ),
        ],
      ),
    );
  }

  Future<void> _onBiometricToggle(bool value) async {
    if (value) {
      await _enableBiometricLogin();
    } else {
      await _confirmAndDisableBiometricLogin();
    }
  }

  /// Asks for the current password (the app never keeps it in memory),
  /// verifies it with a real sign-in, then asks for the fingerprint as
  /// confirmation before saving the credentials in the secure storage.
  Future<void> _enableBiometricLogin() async {
    final email = _currentEmail;
    if (email.isEmpty) return;

    final password = await _promptCurrentPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _isBiometricBusy = true);
    try {
      // Verifies the password with a real sign-in — this is the only way
      // to check it, since the app doesn't keep it in memory otherwise.
      await AuthService.instance.signInWithPassword(
        email: email,
        password: password,
      );

      final authenticated = await BiometricService.instance.authenticate(
        reason:
            'Conferma la tua identità per attivare l\'accesso con impronta digitale',
      );
      if (!authenticated) return;

      final user = SupabaseService.instance.client.auth.currentUser;
      final fullName =
          (user?.userMetadata?['full_name'] as String?) ??
          email.split('@').first;

      await BiometricService.instance.enableBiometricLogin(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (mounted) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accesso con impronta digitale attivato.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password errata. Accesso con impronta digitale non attivato.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBiometricBusy = false);
    }
  }

  Future<String?> _promptCurrentPassword() async {
    final controller = TextEditingController();
    bool obscure = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Conferma la password',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Per attivare l\'accesso con impronta digitale, inserisci la password attuale.',
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password attuale',
                  labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.lock, color: Colors.red),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common.cancel'.tr(),
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final pwd = controller.text;
                if (pwd.isEmpty) return;
                Navigator.pop(context, pwd);
              },
              child: Text(
                'Conferma',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDisableBiometricLogin() async {
    final email = _currentEmail;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Disattivare l\'accesso con impronta?',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Non potrai più entrare senza scrivere email e password.',
              style: GoogleFonts.inter(color: Colors.grey[300]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'common.cancel'.tr(),
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Disattiva',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || email.isEmpty) return;

    setState(() => _isBiometricBusy = true);
    try {
      await BiometricService.instance.disableBiometricForUser(email);
      if (mounted) {
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accesso con impronta disattivato.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBiometricBusy = false);
    }
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController(text: _currentEmail);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.red, size: 20),
              SizedBox(width: 8.w),
              Text(
                'Modifica Email',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inserisci la nuova email di accesso',
                style:
                    GoogleFonts.inter(color: Colors.grey[400], fontSize: 13.sp),
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nuova email',
                  labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.email, color: Colors.red),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text('common.cancel'.tr(),
                  style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newEmail = emailController.text.trim();
                      if (newEmail.isEmpty || !newEmail.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Inserisci un\'email valida'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await SupabaseService.instance.client.auth
                            .updateUser(UserAttributes(email: newEmail));

                        // Update in user_profiles table
                        final userId = SupabaseService
                            .instance.client.auth.currentUser?.id;
                        if (userId != null) {
                          await SupabaseService.instance.client
                              .from('user_profiles')
                              .update({'email': newEmail}).eq('id', userId);
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {}); // refresh displayed email
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Email aggiornata. Controlla la tua casella per confermare.'),
                              backgroundColor: Colors.green,
                            ),
                          );
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

  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showNew = false;
    bool showConfirm = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('profile.change_password'.tr(),
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordField(
                'profile.new_password'.tr(),
                newPasswordController,
                showNew,
                () => setDialogState(() => showNew = !showNew),
              ),
              SizedBox(height: 2.h),
              _buildPasswordField(
                'profile.confirm_password'.tr(),
                confirmPasswordController,
                showConfirm,
                () => setDialogState(() => showConfirm = !showConfirm),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text('common.cancel'.tr(),
                  style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final newPwd = newPasswordController.text;
                      final confirmPwd = confirmPasswordController.text;

                      if (newPwd.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Inserisci una nuova password'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (newPwd.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'La password deve essere di almeno 6 caratteri'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (newPwd != confirmPwd) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Le password non coincidono'),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await SupabaseService.instance.client.auth.updateUser(
                          UserAttributes(password: newPwd),
                        );

                        // Changing the password from the app makes any
                        // saved fingerprint-login credentials stale — drop
                        // them (and the flag) rather than leave a broken
                        // biometric login around.
                        final email = _currentEmail;
                        if (email.isNotEmpty) {
                          await BiometricService.instance
                              .disableBiometricForUser(email);
                          if (mounted) {
                            setState(() => _biometricEnabled = false);
                          }
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password aggiornata con successo'),
                              backgroundColor: Colors.green,
                            ),
                          );
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
                  : Text('common.change'.tr(),
                      style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller,
      bool visible, VoidCallback onToggle) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
        prefixIcon: Icon(Icons.lock, color: Colors.red),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handleTwoFactorSetup() {
    if (twoFactorEnabled) {
      _showTwoFactorManagementDialog();
    } else {
      _showTwoFactorSetupDialog();
    }
  }

  void _showTwoFactorSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('profile.activate_2fa'.tr(),
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'profile.2fa_setup_description'.tr(),
              style: GoogleFonts.inter(color: Colors.grey[300]),
            ),
            SizedBox(height: 2.h),
            Text(
              'profile.2fa_phone_hint'.tr(),
              style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: ProfileTypography.subtitle),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(),
                style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                twoFactorEnabled = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('profile.2fa_activated'.tr()),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('profile.activate'.tr(),
                style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTwoFactorManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('profile.manage_2fa'.tr(),
            style: GoogleFonts.inter(color: Colors.white)),
        content: Text(
          'profile.2fa_active_phone'.tr(),
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr(),
                style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                twoFactorEnabled = false;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('2FA disattivato'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child:
                Text('Disattiva', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
