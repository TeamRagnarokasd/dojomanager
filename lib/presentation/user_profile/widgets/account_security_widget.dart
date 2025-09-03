import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class AccountSecurityWidget extends StatefulWidget {
  const AccountSecurityWidget({Key? key}) : super(key: key);

  @override
  State<AccountSecurityWidget> createState() => _AccountSecurityWidgetState();
}

class _AccountSecurityWidgetState extends State<AccountSecurityWidget> {
  bool biometricEnabled = true;
  bool twoFactorEnabled = false;

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
            'Sicurezza Account',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _buildPasswordSection(),
          SizedBox(height: 2.h),
          _buildBiometricSection(),
          SizedBox(height: 2.h),
          _buildTwoFactorSection(),
          SizedBox(height: 2.h),
          _buildLoginActivitySection(),
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
          Icon(Icons.lock, color: Colors.red, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambia Password',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Ultima modifica: 3 mesi fa',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showChangePasswordDialog,
            child: Text(
              'Modifica',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: 10.sp,
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
          Icon(Icons.fingerprint, color: Colors.red, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autenticazione Biometrica',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Usa impronta digitale o Face ID',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: biometricEnabled,
            onChanged: (value) {
              setState(() {
                biometricEnabled = value;
              });
              _handleBiometricToggle(value);
            },
            activeColor: Colors.red,
            activeTrackColor: Colors.red.withAlpha(77),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoFactorSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.red, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autenticazione a Due Fattori',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  twoFactorEnabled
                      ? 'Attiva via SMS'
                      : 'Aumenta la sicurezza dell\'account',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _handleTwoFactorSetup,
            child: Text(
              twoFactorEnabled ? 'Gestisci' : 'Attiva',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginActivitySection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.red, size: 5.w),
              SizedBox(width: 3.w),
              Text(
                'Attività di Accesso Recente',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildLoginActivity('iPhone 14', 'Milano, Italia', 'Ora', true),
          SizedBox(height: 1.h),
          _buildLoginActivity(
              'MacBook Pro', 'Milano, Italia', '2 ore fa', false),
          SizedBox(height: 1.h),
          _buildLoginActivity('iPad', 'Roma, Italia', '3 giorni fa', false),
        ],
      ),
    );
  }

  Widget _buildLoginActivity(
      String device, String location, String time, bool isCurrentSession) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: isCurrentSession
                ? Colors.green.withAlpha(51)
                : Colors.grey.withAlpha(51),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getDeviceIcon(device),
            color: isCurrentSession ? Colors.green : Colors.grey,
            size: 4.w,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$device${isCurrentSession ? ' (Sessione Corrente)' : ''}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$location • $time',
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 9.sp,
                ),
              ),
            ],
          ),
        ),
        if (!isCurrentSession)
          IconButton(
            onPressed: () => _revokeSession(device),
            icon: Icon(Icons.close, color: Colors.red, size: 4.w),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 8.w, minHeight: 8.w),
          ),
      ],
    );
  }

  IconData _getDeviceIcon(String device) {
    if (device.contains('iPhone') || device.contains('iPad')) {
      return Icons.phone_iphone;
    } else if (device.contains('MacBook') || device.contains('Mac')) {
      return Icons.laptop_mac;
    } else {
      return Icons.devices;
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('Cambia Password',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField('Password Attuale', currentPasswordController),
            SizedBox(height: 2.h),
            _buildPasswordField('Nuova Password', newPasswordController),
            SizedBox(height: 2.h),
            _buildPasswordField('Conferma Password', confirmPasswordController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Handle password change
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password cambiata con successo!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Cambia', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: GoogleFonts.inter(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
        prefixIcon: Icon(Icons.lock, color: Colors.red),
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

  void _handleBiometricToggle(bool enabled) {
    if (enabled) {
      // In a real app, you would check if biometrics are available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Autenticazione biometrica attivata'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Autenticazione biometrica disattivata'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleTwoFactorSetup() {
    if (twoFactorEnabled) {
      // Show management options
      _showTwoFactorManagementDialog();
    } else {
      // Show setup dialog
      _showTwoFactorSetupDialog();
    }
  }

  void _showTwoFactorSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title:
            Text('Attiva 2FA', style: GoogleFonts.inter(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'L\'autenticazione a due fattori aggiunge un livello extra di sicurezza al tuo account.',
              style: GoogleFonts.inter(color: Colors.grey[300]),
            ),
            SizedBox(height: 2.h),
            Text(
              'Inserisci il tuo numero di telefono per ricevere i codici di verifica via SMS.',
              style:
                  GoogleFonts.inter(color: Colors.grey[400], fontSize: 10.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                twoFactorEnabled = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('2FA attivato con successo!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Attiva', style: GoogleFonts.inter(color: Colors.red)),
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
        title:
            Text('Gestisci 2FA', style: GoogleFonts.inter(color: Colors.white)),
        content: Text(
          'L\'autenticazione a due fattori è attiva sul numero +39 339 *** 4567',
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Chiudi', style: GoogleFonts.inter(color: Colors.grey)),
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

  void _revokeSession(String device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text('Termina Sessione',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Text(
          'Vuoi terminare la sessione su $device?',
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Annulla', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sessione terminata su $device'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text('Termina', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}