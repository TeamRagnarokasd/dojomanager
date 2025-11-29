import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math'; // Add this import

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';
import '../../../services/user_profile_service.dart';

class MedicalCertificateStatusWidget extends StatefulWidget {
  const MedicalCertificateStatusWidget({Key? key}) : super(key: key);

  @override
  State<MedicalCertificateStatusWidget> createState() =>
      _MedicalCertificateStatusWidgetState();
}

class _MedicalCertificateStatusWidgetState
    extends State<MedicalCertificateStatusWidget> {
  final UserProfileService _userProfileService = UserProfileService();
  Map<String, dynamic>? _certificateStatus;
  bool _isLoading = false;
  String? _certificateUrl;
  DateTime? _startDate;
  DateTime? _expiryDate;
  String? _doctorName;
  String? _medicalCenter;
  String? _certificateType;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadCertificateStatus();
  }

  Future<void> _loadCertificateStatus() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('🔄 Loading certificate status...');
      final result = await _userProfileService.getUserUploadStatus();

      debugPrint('📊 Result received - success: ${result['success']}');

      if (result['success'] == true) {
        setState(() {
          _certificateStatus = result;
          // Extract certificate data
          _certificateUrl = result['medical_certificate_url'];

          debugPrint(
            '📄 Certificate URL: ${_certificateUrl != null ? "Present (${_certificateUrl!.substring(0, 50)}...)" : "NULL"}',
          );
          debugPrint(
            '📅 Start Date: ${result['medical_certificate_start_date']}',
          );
          debugPrint('📅 Expiry Date: ${result['medical_certificate_expiry']}');
          debugPrint(
            '👨‍⚕️ Doctor: ${result['medical_certificate_doctor_name']}',
          );
          debugPrint(
            '🏥 Center: ${result['medical_certificate_medical_center']}',
          );
          debugPrint('📋 Type: ${result['medical_certificate_type']}');
          debugPrint('✅ Status: ${result['medical_certificate_status']}');

          // Parse dates
          if (result['medical_certificate_start_date'] != null) {
            _startDate = DateTime.tryParse(
              result['medical_certificate_start_date'].toString(),
            );
            debugPrint('📆 Parsed start date: $_startDate');
          }
          if (result['medical_certificate_expiry'] != null) {
            _expiryDate = DateTime.tryParse(
              result['medical_certificate_expiry'].toString(),
            );
            debugPrint('📆 Parsed expiry date: $_expiryDate');
          }

          _doctorName = result['medical_certificate_doctor_name'];
          _medicalCenter = result['medical_certificate_medical_center'];
          _certificateType = result['medical_certificate_type'];
          _status = result['medical_certificate_status'] ?? 'pending';
        });

        debugPrint('✅ Certificate status loaded successfully');
      } else {
        debugPrint('⚠️ Failed to load certificate status');
      }
    } catch (e) {
      debugPrint('❌ Error loading certificate status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore nel caricamento del certificato: ${e.toString()}',
            ),
            backgroundColor: AppTheme.darkTheme.colorScheme.error,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildCertificateLinkButton() {
    if (_certificateUrl == null || _certificateUrl!.isEmpty) {
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
                    'Clicca per aprire',
                    style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    'Certificato Medico',
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
    if (_certificateUrl == null || _certificateUrl!.isEmpty) {
      debugPrint('⚠️ Cannot open certificate: URL is null or empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URL del certificato non disponibile'),
            backgroundColor: AppTheme.darkTheme.colorScheme.error,
          ),
        );
      }
      return;
    }

    debugPrint(
      '🔗 Opening certificate URL: ${_certificateUrl!.substring(0, min(100, _certificateUrl!.length))}...',
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
                Text('Apertura certificato...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: AppTheme.darkTheme.colorScheme.primary,
          ),
        );
      }

      // Regenerate signed URL before opening (handles expired URLs)
      String? freshUrl = _certificateUrl;

      try {
        final client = SupabaseService.instance.client;
        final uri = Uri.parse(_certificateUrl!);
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

        // Update local state with new URL
        setState(() => _certificateUrl = freshUrl);
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
                  Text('Certificato aperto'),
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
              content: Text('Impossibile aprire il certificato'),
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
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: AppTheme.darkTheme.colorScheme.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildExpiryDateSection() {
    if (_expiryDate == null) return const SizedBox.shrink();

    final daysUntilExpiry = _expiryDate!.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry < 60;
    final isExpired = daysUntilExpiry < 0;

    Color statusColor;
    String statusMessage;
    IconData statusIcon;

    if (isExpired) {
      statusColor = AppTheme.darkTheme.colorScheme.error;
      statusMessage = 'Scaduto';
      statusIcon = Icons.error_outline;
    } else if (isExpiringSoon) {
      statusColor = AppTheme.darkTheme.colorScheme.tertiary;
      statusMessage = 'In scadenza tra $daysUntilExpiry giorni';
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = AppTheme.darkTheme.colorScheme.secondary;
      statusMessage = 'Valido';
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
                'Data di Scadenza',
                style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            _formatDate(_expiryDate!),
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

    final hasCertificate =
        _certificateUrl != null && _certificateUrl!.isNotEmpty;

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
            'Certificato Medico',
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
    final hasCertificate =
        _certificateUrl != null && _certificateUrl!.isNotEmpty;

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
                        ? 'Aggiorna Certificato'
                        : 'Carica Certificato',
                    style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkTheme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    hasCertificate
                        ? 'Tocca per caricare un nuovo certificato'
                        : 'Tocca per selezionare e caricare il documento',
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}