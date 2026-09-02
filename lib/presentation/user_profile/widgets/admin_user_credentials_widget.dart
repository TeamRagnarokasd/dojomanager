import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../constants/app_constants.dart';
import '../../../constants/profile_typography.dart';
import '../../../services/supabase_service.dart';

/// Widget shown to admins when viewing another user's profile.
/// Allows the admin to change the user's email and/or password
/// via the `update-auth-user` Edge Function (uses service role key).
class AdminUserCredentialsWidget extends StatelessWidget {
  final String targetUserId;
  final String targetUserEmail;
  final String targetUserName;

  const AdminUserCredentialsWidget({
    Key? key,
    required this.targetUserId,
    required this.targetUserEmail,
    required this.targetUserName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.orange.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
              SizedBox(width: 2.w),
              Text(
                'Credenziali Utente (Admin)',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: ProfileTypography.sectionTitle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Modifica email o password di $targetUserName',
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: ProfileTypography.subtitle,
            ),
          ),
          SizedBox(height: 3.h),
          _buildEmailRow(context),
          SizedBox(height: 2.h),
          _buildPasswordRow(context),
        ],
      ),
    );
  }

  Widget _buildEmailRow(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.email, color: Colors.orange, size: 22),
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
                  targetUserEmail.isNotEmpty
                      ? targetUserEmail
                      : 'Non disponibile',
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
            onPressed: () => _showChangeEmailDialog(context),
            child: Text(
              'Modifica',
              style: GoogleFonts.inter(
                color: Colors.orange,
                fontSize: ProfileTypography.action,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRow(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.orange, size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.rowLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  'Imposta una nuova password per l\'utente',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: ProfileTypography.subtitle,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showChangePasswordDialog(context),
            child: Text(
              'Modifica',
              style: GoogleFonts.inter(
                color: Colors.orange,
                fontSize: ProfileTypography.action,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context) {
    final emailController = TextEditingController(text: targetUserEmail);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.orange, size: 20),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Modifica Email',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuova email per $targetUserName',
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
                  prefixIcon: Icon(Icons.email, color: Colors.orange),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child:
                  Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final response = await SupabaseService
                            .instance.client.functions
                            .invoke(
                          'update-auth-user',
                          body: {
                            'userId': targetUserId,
                            'email': newEmail,
                          },
                        );

                        final data = response.data;
                        if (data != null && data['success'] == true) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email aggiornata con successo'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          throw Exception(
                              data?['error'] ?? 'Errore sconosciuto');
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Errore: ${e.toString().replaceAll('Exception: ', '')}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Salva',
                      style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showNew = false;
    bool showConfirm = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Imposta Nuova Password',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuova password per $targetUserName',
                style:
                    GoogleFonts.inter(color: Colors.grey[400], fontSize: 13.sp),
              ),
              SizedBox(height: 2.h),
              _buildPasswordField(
                'Nuova password',
                newPasswordController,
                showNew,
                () => setDialogState(() => showNew = !showNew),
              ),
              SizedBox(height: 2.h),
              _buildPasswordField(
                'Conferma password',
                confirmPasswordController,
                showConfirm,
                () => setDialogState(() => showConfirm = !showConfirm),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child:
                  Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
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
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (newPwd.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'La password deve essere di almeno 6 caratteri'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      if (newPwd != confirmPwd) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le password non coincidono'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        final response = await SupabaseService
                            .instance.client.functions
                            .invoke(
                          'update-auth-user',
                          body: {
                            'userId': targetUserId,
                            'password': newPwd,
                          },
                        );

                        final data = response.data;
                        if (data != null && data['success'] == true) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password aggiornata con successo'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          throw Exception(
                              data?['error'] ?? 'Errore sconosciuto');
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Errore: ${e.toString().replaceAll('Exception: ', '')}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Salva',
                      style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
        prefixIcon: Icon(Icons.lock, color: Colors.orange),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withAlpha(77)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
