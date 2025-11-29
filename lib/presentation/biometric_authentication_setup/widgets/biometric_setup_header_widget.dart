import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/custom_image_widget.dart';

class BiometricSetupHeaderWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback onSkip;

  const BiometricSetupHeaderWidget({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(6.w, 8.h, 6.w, 3.h),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF333333), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header row with logo and skip button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Team Ragnarok logo with security shield
              Row(
                children: [
                  CustomImageWidget(
                    imageUrl: "assets/images/img_app_logo.svg",
                    width: 12.w,
                    height: 6.h,
                  ),
                  SizedBox(width: 3.w),
                  Icon(
                    Icons.security,
                    color: const Color(0xFFFF0000),
                    size: 6.w,
                  ),
                ],
              ),

              // Skip button
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Salta',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // Title
          Text(
            'Configurazione Sicurezza',
            style: GoogleFonts.inter(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 1.h),

          // Subtitle
          Text(
            'Imposta l\'autenticazione biometrica per accesso sicuro',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 3.h),

          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  /// Build step progress indicator
  Widget _buildProgressIndicator() {
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (currentStep + 1) / totalSteps,
          backgroundColor: Colors.grey.shade800,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
          minHeight: 6,
        ),

        SizedBox(height: 1.h),

        // Step text
        Text(
          'Passo ${currentStep + 1} di $totalSteps',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}