import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class BackupAuthenticationWidget extends StatefulWidget {
  final String backupPIN;
  final bool isConfigured;
  final Function(String) onPINConfigured;
  final VoidCallback? onContinue;

  const BackupAuthenticationWidget({
    super.key,
    required this.backupPIN,
    required this.isConfigured,
    required this.onPINConfigured,
    this.onContinue,
  });

  @override
  State<BackupAuthenticationWidget> createState() =>
      _BackupAuthenticationWidgetState();
}

class _BackupAuthenticationWidgetState
    extends State<BackupAuthenticationWidget> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final FocusNode _confirmPinFocusNode = FocusNode();

  bool _obscurePIN = true;
  bool _obscureConfirmPIN = true;
  String _pinError = '';
  bool _pinStrengthGood = false;

  @override
  void initState() {
    super.initState();
    _pinController.text = widget.backupPIN;
    _pinController.addListener(_checkPINStrength);
    _confirmPinController.addListener(_validatePINMatch);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _pinFocusNode.dispose();
    _confirmPinFocusNode.dispose();
    super.dispose();
  }

  /// Check PIN strength
  void _checkPINStrength() {
    final pin = _pinController.text;
    setState(() {
      _pinStrengthGood = pin.length >= 4 && !_isWeakPIN(pin);
    });
    _validatePINMatch();
  }

  /// Validate PIN match
  void _validatePINMatch() {
    final pin = _pinController.text;
    final confirmPin = _confirmPinController.text;

    setState(() {
      if (pin.isEmpty) {
        _pinError = '';
      } else if (pin.length < 4) {
        _pinError = 'Il PIN deve essere di almeno 4 cifre';
      } else if (_isWeakPIN(pin)) {
        _pinError = 'PIN troppo semplice. Evita sequenze come 1234 o 1111';
      } else if (confirmPin.isNotEmpty && pin != confirmPin) {
        _pinError = 'I PIN non corrispondono';
      } else if (pin == confirmPin && pin.length >= 4 && !_isWeakPIN(pin)) {
        _pinError = '';
        widget.onPINConfigured(pin);
      } else {
        _pinError = '';
      }
    });
  }

  /// Check if PIN is weak
  bool _isWeakPIN(String pin) {
    // Check for common weak patterns
    final weakPatterns = [
      '1234',
      '4321',
      '1111',
      '2222',
      '3333',
      '4444',
      '5555',
      '6666',
      '7777',
      '8888',
      '9999',
      '0000',
      '0123',
      '3210',
      '1122',
      '2211',
    ];

    return weakPatterns.contains(pin) || _isSequential(pin);
  }

  /// Check if PIN is sequential
  bool _isSequential(String pin) {
    if (pin.length < 3) return false;

    for (int i = 0; i < pin.length - 2; i++) {
      final a = int.tryParse(pin[i]) ?? 0;
      final b = int.tryParse(pin[i + 1]) ?? 0;
      final c = int.tryParse(pin[i + 2]) ?? 0;

      if ((b == a + 1 && c == b + 1) || (b == a - 1 && c == b - 1)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Column(
        children: [
          // Title
          Text(
            'Autenticazione di Backup',
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
            'Configura un PIN di backup per accedere all\'app quando l\'autenticazione biometrica non è disponibile.',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // PIN configuration form
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    widget.isConfigured ? Colors.green : Colors.grey.shade800,
              ),
            ),
            child: Column(
              children: [
                // PIN input
                TextFormField(
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  obscureText: _obscurePIN,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: Colors.white,
                    letterSpacing: 4.0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'PIN di Backup',
                    labelStyle: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontSize: 14.sp,
                    ),
                    hintText: 'Inserisci PIN (min. 4 cifre)',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePIN ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePIN = !_obscurePIN;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFF0000)),
                    ),
                    counterText: '',
                  ),
                  onFieldSubmitted: (_) {
                    _confirmPinFocusNode.requestFocus();
                  },
                ),

                SizedBox(height: 3.h),

                // Confirm PIN input
                TextFormField(
                  controller: _confirmPinController,
                  focusNode: _confirmPinFocusNode,
                  obscureText: _obscureConfirmPIN,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    color: Colors.white,
                    letterSpacing: 4.0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Conferma PIN',
                    labelStyle: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontSize: 14.sp,
                    ),
                    hintText: 'Reinserisci PIN',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPIN
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPIN = !_obscureConfirmPIN;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFF0000)),
                    ),
                    counterText: '',
                  ),
                ),

                SizedBox(height: 2.h),

                // PIN strength indicator
                if (_pinController.text.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        _pinStrengthGood ? Icons.check_circle : Icons.warning,
                        color: _pinStrengthGood ? Colors.green : Colors.orange,
                        size: 5.w,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        _pinStrengthGood ? 'PIN sicuro' : 'PIN debole',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color:
                              _pinStrengthGood ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                ],

                // Error message
                if (_pinError.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(77)),
                    ),
                    child: Text(
                      _pinError,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],

                // Success indicator
                if (widget.isConfigured) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(77)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 4.w,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'PIN di backup configurato',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Security tips
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withAlpha(77)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue,
                      size: 6.w,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'Suggerimenti per un PIN sicuro:',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                _buildTip('• Usa almeno 4 cifre, meglio se 6'),
                _buildTip('• Evita sequenze come 1234 o 4321'),
                _buildTip('• Evita ripetizioni come 1111 o 2222'),
                _buildTip('• Non usare date di nascita o anni'),
              ],
            ),
          ),

          const Spacer(),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.isConfigured ? widget.onContinue : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isConfigured
                    ? const Color(0xFFFF0000)
                    : Colors.grey.shade700,
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

  /// Build security tip
  Widget _buildTip(String tip) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.5.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          tip,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: Colors.blue.shade200,
          ),
        ),
      ),
    );
  }
}
