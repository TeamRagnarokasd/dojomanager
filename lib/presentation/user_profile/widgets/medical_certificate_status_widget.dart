import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

// Add this import for min function
// Add this import for launchUrl

class MedicalCertificateStatusWidget extends StatefulWidget {
  final String? userId; // NEW: Optional user ID parameter

  const MedicalCertificateStatusWidget({Key? key, this.userId})
      : super(key: key);

  @override
  State<MedicalCertificateStatusWidget> createState() =>
      _MedicalCertificateStatusWidgetState();
}

class _MedicalCertificateStatusWidgetState
    extends State<MedicalCertificateStatusWidget> {
  Map<String, dynamic>? _certificateData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificateStatus();
  }

  Future<void> _loadCertificateStatus() async {
    try {
      final client = SupabaseService.instance.client;

      String? targetUserId = widget.userId;

      final response = await client
          .from('user_profiles')
          .select(
            'medical_certificate_url, medical_certificate_expiry, medical_certificate_start_date',
          )
          .eq('id', targetUserId ?? '')
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _certificateData = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading certificate status: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCertificateLinkButton() {
    if (_certificateData == null ||
        _certificateData!['medical_certificate_url'] == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _openCertificateFullScreen(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 4.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkTheme.colorScheme.primary.withAlpha(26),
              AppTheme.darkTheme.colorScheme.secondary.withAlpha(26),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.darkTheme.colorScheme.primary.withAlpha(102),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.darkTheme.colorScheme.primary.withAlpha(38),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AppTheme.darkTheme.colorScheme.primary.withAlpha(51),
                shape: BoxShape.circle,
              ),
              child: CustomIconWidget(
                iconName: 'description',
                color: AppTheme.darkTheme.colorScheme.primary,
                size: 28,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'profile.click_to_open'.tr(),
                    style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    'profile.medical_certificate'.tr(),
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.onSurface.withAlpha(
                        179,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'open_in_new',
              color: AppTheme.darkTheme.colorScheme.primary.withAlpha(179),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCertificateFullScreen() async {
    if (_certificateData == null ||
        _certificateData!['medical_certificate_url'] == null) {
      debugPrint('⚠️ Cannot open certificate: URL is null or empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.certificate_url_unavailable'.tr()),
            backgroundColor: AppTheme.darkTheme.colorScheme.error,
          ),
        );
      }
      return;
    }

    final String certificateUrl =
        _certificateData!['medical_certificate_url'] as String;
    final int urlLength = certificateUrl.length;

    debugPrint(
      '🔗 Opening certificate URL: ${certificateUrl.substring(0, min(100, urlLength))}...',
    );

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 3.w),
                Text('profile.opening_certificate'.tr()),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: AppTheme.darkTheme.colorScheme.primary,
          ),
        );
      }

      // Regenerate signed URL before opening (handles expired URLs)
      String? freshUrl = _certificateData!['medical_certificate_url'];

      try {
        final client = SupabaseService.instance.client;
        final uri = Uri.parse(freshUrl!);
        final pathSegments = uri.pathSegments;

        // Extract filename from URL path
        final fileName = pathSegments.lastWhere(
          (segment) => segment.isNotEmpty && !segment.startsWith('sign'),
          orElse: () => pathSegments.last.split('?').first,
        );

        debugPrint('📝 Regenerating URL for file: $fileName');

        // Generate fresh signed URL (valid for 24 hours)
        freshUrl = await client.storage
            .from('medical-certificates')
            .createSignedUrl(fileName, 86400); // 24 hours

        debugPrint('✅ Fresh signed URL generated');

        if (mounted) {
          setState(
              () => _certificateData!['medical_certificate_url'] = freshUrl);
        }
      } catch (urlError) {
        debugPrint('⚠️ Could not regenerate URL: $urlError');
        // Continue with existing URL if regeneration fails
      }

      final url = Uri.parse(freshUrl!);
      bool launched = false;

      // Try multiple launch modes for maximum compatibility
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        debugPrint('✅ Opened with externalApplication');
      } catch (e) {
        debugPrint('⚠️ externalApplication failed: $e');

        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
          debugPrint('✅ Opened with platformDefault');
        } catch (e) {
          debugPrint('⚠️ platformDefault failed: $e');

          try {
            launched = await launchUrl(
              url,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            debugPrint('✅ Opened with externalNonBrowserApplication');
          } catch (e) {
            debugPrint('❌ All launch modes failed: $e');
          }
        }
      }

      if (launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 2.w),
                  Text('profile.certificate_opened'.tr()),
                ],
              ),
              backgroundColor: AppTheme.darkTheme.colorScheme.secondary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌ Cannot launch URL');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('profile.cannot_open_certificate'.tr()),
              backgroundColor: AppTheme.darkTheme.colorScheme.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error opening certificate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'profile.certificate_error'
                  .tr(namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: AppTheme.darkTheme.colorScheme.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildExpiryDateSection() {
    // 🎯 FIX: Use correct column name - medical_certificate_expiry
    if (_certificateData == null ||
        _certificateData!['medical_certificate_expiry'] == null)
      return const SizedBox.shrink();

    final expiryDate = DateTime.tryParse(
      _certificateData!['medical_certificate_expiry'],
    );
    final daysUntilExpiry = expiryDate?.difference(DateTime.now()).inDays ?? 0;
    final isExpiringSoon = daysUntilExpiry < 60;
    final isExpired = daysUntilExpiry < 0;

    Color statusColor;
    String statusMessage;
    IconData statusIcon;

    if (isExpired) {
      statusColor = AppTheme.darkTheme.colorScheme.error;
      statusMessage = 'profile.status_expired'.tr();
      statusIcon = Icons.error_outline;
    } else if (isExpiringSoon) {
      statusColor = AppTheme.darkTheme.colorScheme.tertiary;
      statusMessage = 'profile.status_expiring_soon'
          .tr(namedArgs: {'days': '$daysUntilExpiry'});
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = AppTheme.darkTheme.colorScheme.secondary;
      statusMessage = 'profile.status_valid'.tr();
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(77), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: statusIcon.toString().split('.').last,
                color: statusColor,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'profile.expiry_date'.tr(),
                style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            _formatDate(expiryDate ?? DateTime.now()),
            style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          if (!isExpired) ...[
            SizedBox(height: 0.5.h),
            Text(
              statusMessage,
              style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                color: statusColor.withAlpha(204),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: AppTheme.darkTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(
            color: AppTheme.darkTheme.colorScheme.primary.withAlpha(77),
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.darkTheme.colorScheme.secondary,
          ),
        ),
      );
    }

    final hasCertificate = _certificateData != null &&
        _certificateData!['medical_certificate_url'] != null &&
        _certificateData!['medical_certificate_url']!.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: AppTheme.darkTheme.colorScheme.primary.withAlpha(77),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.medical_certificate'.tr(),
            style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkTheme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 2.h),

          // Certificate Link Button (replaces preview)
          if (hasCertificate) ...[
            _buildCertificateLinkButton(),
            SizedBox(height: 2.h),

            // Expiry Date Section (automatic display after upload)
            _buildExpiryDateSection(),
            SizedBox(height: 2.h),
          ],

          // Upload Button
          _buildUploadButton(),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    final hasCertificate = _certificateData != null &&
        _certificateData!['medical_certificate_url'] != null &&
        _certificateData!['medical_certificate_url']!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.medicalCertificateUpload,
        ).then((_) => _loadCertificateStatus());
      },
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.darkTheme.colorScheme.primary.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.darkTheme.colorScheme.primary.withAlpha(77),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: hasCertificate ? 'refresh' : 'cloud_upload',
              color: AppTheme.darkTheme.colorScheme.primary,
              size: 24,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCertificate
                        ? 'profile.update_certificate'.tr()
                        : 'profile.upload_certificate'.tr(),
                    style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkTheme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    hasCertificate
                        ? 'profile.tap_upload_new'.tr()
                        : 'profile.tap_select_upload'.tr(),
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.onSurface.withAlpha(
                        153,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'chevron_right',
              color: AppTheme.darkTheme.colorScheme.primary.withAlpha(153),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
