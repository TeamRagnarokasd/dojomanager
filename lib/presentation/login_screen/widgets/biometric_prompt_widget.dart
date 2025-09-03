import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class BiometricPromptWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!isAvailable) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: 'fingerprint',
            color: AppTheme.primaryLight,
            size: 32,
          ),
          SizedBox(height: 2.h),
          Text(
            'Accesso Biometrico',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Usa Face ID o Touch ID per accedere rapidamente',
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onSkip();
                  },
                  child: Text('Salta'),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onBiometricLogin();
                  },
                  child: Text('Usa Biometrico'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
