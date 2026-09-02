import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../services/user_profile_service.dart';
import './widgets/camera_capture_widget.dart';
import './widgets/certificate_details_form_widget.dart';
import './widgets/certificate_requirements_widget.dart';
import './widgets/document_preview_widget.dart';
import './widgets/upload_progress_widget.dart';

class MedicalCertificateUpload extends StatefulWidget {
  const MedicalCertificateUpload({super.key});

  @override
  State<MedicalCertificateUpload> createState() =>
      _MedicalCertificateUploadState();
}

class _MedicalCertificateUploadState extends State<MedicalCertificateUpload>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final UserProfileService _userProfileService = UserProfileService();

  // Form and upload state
  XFile? _capturedImage;
  Map<String, dynamic> _certificateDetails = {};
  bool _isUploading = false;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusMessage;
  int _currentStep = 0;
  bool _hasUnsavedChanges = false;

  // Mock data for offline functionality
  final List<Map<String, dynamic>> _pendingUploads = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  void _onImageCaptured(XFile image) {
    setState(() {
      _capturedImage = image;
      _hasUnsavedChanges = true;
      _currentStep = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.animateTo(1);
    });

    Fluttertoast.showToast(
      msg: 'medical_certificate.document_selected_hint'.tr(),
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _onRemoveImage() {
    setState(() {
      _capturedImage = null;
      _hasUnsavedChanges = false;
      _currentStep = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.animateTo(0);
    });
  }

  void _onImageUpdated(XFile updatedImage) {
    setState(() {
      _capturedImage = updatedImage;
      _hasUnsavedChanges = true;
    });
  }

  void _onFormChanged(Map<String, dynamic> formData) {
    setState(() {
      _certificateDetails = formData;
      _hasUnsavedChanges = true;
      if (formData['isValid'] == true && _capturedImage != null) {
        _currentStep = 2;
      }
    });
  }

  bool _isFormValid() {
    return _capturedImage != null &&
        _certificateDetails['isValid'] == true &&
        _certificateDetails['startDate'] != null &&
        _certificateDetails['endDate'] != null;
  }

  Future<void> _uploadCertificate() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('medical_certificate.complete_fields'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadProgress = 0.1;
      _uploadStatusMessage = 'medical_upload_ui.preparing_file'.tr();
    });

    try {
      final userId = SupabaseService.instance.getCurrentUserId();
      if (userId == null) {
        throw Exception('Utente non autenticato. Effettua il login.');
      }

      String? uploadedUrl;
      String? storagePath;

      if (_capturedImage != null) {
        setState(() {
          _uploadProgress = 0.2;
          _uploadStatusMessage = 'medical_upload_ui.reading_image'.tr();
        });

        final imageBytes = await _capturedImage!.readAsBytes();
        debugPrint('Image bytes read: ${imageBytes.length} bytes');

        if (imageBytes.isEmpty) {
          throw Exception(
            'Il file immagine è vuoto. Seleziona nuovamente il documento.',
          );
        }

        final fileName =
            'medical_cert_${DateTime.now().millisecondsSinceEpoch}.jpg';
        storagePath = '$userId/$fileName';

        setState(() {
          _uploadProgress = 0.4;
          _uploadStatusMessage = 'medical_upload_ui.uploading'.tr();
        });

        try {
          await SupabaseService.instance.client.storage
              .from('medical-certificates')
              .uploadBinary(
                storagePath,
                imageBytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
        } catch (storageError) {
          debugPrint('Storage upload error: $storageError');
          final errStr = storageError.toString().toLowerCase();
          if (errStr.contains('bucket') || errStr.contains('not found')) {
            throw Exception(
              'Bucket di storage non configurato. Contatta l\'amministratore.',
            );
          }
          if (errStr.contains('policy') ||
              errStr.contains('permission') ||
              errStr.contains('403') ||
              errStr.contains('rls')) {
            throw Exception(
              'Permesso negato per il caricamento. Contatta l\'amministratore.',
            );
          }
          rethrow;
        }

        setState(() {
          _uploadProgress = 0.7;
          _uploadStatusMessage = 'medical_upload_ui.generating_url'.tr();
        });

        try {
          uploadedUrl = await SupabaseService.instance.client.storage
              .from('medical-certificates')
              .createSignedUrl(storagePath, 60 * 60 * 24 * 365 * 10);
        } catch (e) {
          debugPrint('Signed URL error (using path): $e');
          uploadedUrl = storagePath;
        }
      }

      setState(() {
        _uploadProgress = 0.85;
        _uploadStatusMessage = 'medical_upload_ui.saving_details'.tr();
      });

      final result =
          await UserProfileService().updateMedicalCertificateComplete(
        userId: userId,
        certificateUrl: uploadedUrl ?? storagePath ?? '',
        startDate: _certificateDetails['startDate'] as DateTime?,
        expiryDate: _certificateDetails['endDate'] as DateTime?,
        doctorName: _certificateDetails['doctorName'] as String?,
        medicalCenter: _certificateDetails['medicalCenter'] as String?,
        certificateType: _certificateDetails['certificateType'] as String?,
        certificateStatus: 'pending',
      );

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatusMessage = 'medical_upload_ui.completed'.tr();
      });

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('medical_certificate.upload_success'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(
            result['error'] ?? 'medical_certificate.save_error'.tr());
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'errors.load_data_error'.tr(namedArgs: {'detail': errorMsg})),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStatusMessage = null;
        });
      }
    }
  }

  void _addToPendingUploads() {
    final pendingUpload = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'imagePath': _capturedImage!.path,
      'imageName': _capturedImage!.name,
      'certificateDetails': _certificateDetails,
      'createdAt': DateTime.now(),
      'status': 'pending',
    };

    setState(() {
      _pendingUploads.add(pendingUpload);
    });
  }

  void _cancelUpload() {
    setState(() {
      _isUploading = false;
      _uploadProgress = 0.0;
      _uploadStatusMessage = null;
    });

    Fluttertoast.showToast(
      msg: "Caricamento annullato",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _showSuccessDialog(Map<String, dynamic> uploadResult) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: AppTheme.lightTheme.colorScheme.tertiary,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'medical_upload_ui.certificate_uploaded_title'.tr(),
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.tertiary,
                  fontWeight: FontWeight.w600,
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
              uploadResult['message'] ??
                  'medical_upload_ui.certificate_uploaded_body'.tr(),
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary.withAlpha(
                    77,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'medical_upload_ui.pending_approval'.tr(),
                          style: AppTheme.lightTheme.textTheme.labelLarge
                              ?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'medical_upload_ui.pending_approval_detail'.tr(),
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.primary,
                    ),
                  ),
                  if (_certificateDetails['expirationDate'] != null) ...[
                    SizedBox(height: 1.h),
                    Text(
                      'medical_upload_ui.expiry_label'.tr(namedArgs: {
                        'date':
                            _formatDate(_certificateDetails['expirationDate']),
                      }),
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: AppTheme.lightTheme.colorScheme.secondary,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'medical_upload_ui.approval_notification'.tr(),
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to profile
            },
            child: Text(
              'medical_upload_ui.back_to_profile'.tr(),
              style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            ),
            child: Text(
              'medical_upload_ui.upload_another'.tr(),
              style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _capturedImage = null;
      _certificateDetails = {};
      _currentStep = 0;
      _hasUnsavedChanges = false;
      _uploadProgress = 0.0;
      _uploadStatusMessage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabController.animateTo(0);
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          title: Text(
            'medical_upload_ui.unsaved_changes_title'.tr(),
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            'medical_upload_ui.unsaved_changes_body'.tr(),
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'common.cancel'.tr(),
                style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Esci',
                style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildProgressIndicator(),
            _buildTabBar(),
            Expanded(child: _buildTabBarView()),
            if (!_isUploading) _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.lightTheme.colorScheme.primary,
      foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
      title: Text(
        'medical_certificate.title'.tr(),
        style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
          color: AppTheme.lightTheme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        onPressed: () async {
          if (await _onWillPop()) {
            Navigator.of(context).pop();
          }
        },
        icon: CustomIconWidget(
          iconName: 'arrow_back',
          color: AppTheme.lightTheme.colorScheme.onPrimary,
          size: 24,
        ),
      ),
      actions: [
        if (_pendingUploads.isNotEmpty)
          IconButton(
            onPressed: _showPendingUploads,
            icon: Badge(
              label: Text('${_pendingUploads.length}'),
              child: CustomIconWidget(
                iconName: 'cloud_off',
                color: AppTheme.lightTheme.colorScheme.error,
                size: 24,
              ),
            ),
          ),
        IconButton(
          onPressed: _showHelpDialog,
          icon: CustomIconWidget(
            iconName: 'help_outline',
            color: AppTheme.lightTheme.colorScheme.onPrimary,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: i <= _currentStep
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline.withValues(
                          alpha: 0.3,
                        ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) SizedBox(width: 2.w),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.all(4),
        labelColor: AppTheme.lightTheme.colorScheme.onPrimary,
        unselectedLabelColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'camera_alt',
                  color: _tabController.index == 0
                      ? AppTheme.lightTheme.colorScheme.onPrimary
                      : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                SizedBox(width: 1.w),
                Text('medical_certificate.tab_capture'.tr(),
                    style: TextStyle(fontSize: 12.sp)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'preview',
                  color: _tabController.index == 1
                      ? AppTheme.lightTheme.colorScheme.onPrimary
                      : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                SizedBox(width: 1.w),
                Text('receipt.preview'.tr(), style: TextStyle(fontSize: 12.sp)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'assignment',
                  color: _tabController.index == 2
                      ? AppTheme.lightTheme.colorScheme.onPrimary
                      : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                SizedBox(width: 1.w),
                Text('medical_certificate.tab_details'.tr(),
                    style: TextStyle(fontSize: 12.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [_buildCaptureTab(), _buildPreviewTab(), _buildDetailsTab()],
    );
  }

  Widget _buildCaptureTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Column(
        children: [
          CertificateRequirementsWidget(),
          SizedBox(height: 2.h),
          CameraCaptureWidget(onImageCaptured: _onImageCaptured),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Column(
        children: [
          DocumentPreviewWidget(
            capturedImage: _capturedImage,
            onRemoveImage: _onRemoveImage,
            onImageUpdated: _onImageUpdated,
          ),
          if (_isUploading)
            UploadProgressWidget(
              isUploading: _isUploading,
              progress: _uploadProgress,
              statusMessage: _uploadStatusMessage,
              onCancel: _cancelUpload,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Column(
        children: [
          CertificateDetailsFormWidget(
            onFormChanged: _onFormChanged,
            isEnabled: !_isUploading,
          ),
          if (_isUploading)
            UploadProgressWidget(
              isUploading: _isUploading,
              progress: _uploadProgress,
              statusMessage: _uploadStatusMessage,
              onCancel: _cancelUpload,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: AppTheme.lightTheme.colorScheme.outline.withValues(
              alpha: 0.2,
            ),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_capturedImage == null)
              Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Text(
                  'medical_certificate.select_photo_from_capture'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.error,
                  ),
                ),
              )
            else if (_certificateDetails['isValid'] != true)
              Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: Text(
                  _getMissingFieldsMessage(),
                  textAlign: TextAlign.center,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.error,
                  ),
                ),
              ),
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetForm,
                      child: Text('medical_certificate.restart'.tr()),
                    ),
                  ),
                if (_currentStep > 0) SizedBox(width: 4.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _canUpload() ? _uploadCertificate : null,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.lightTheme.colorScheme.onPrimary,
                            ),
                          )
                        : CustomIconWidget(
                            iconName: 'cloud_upload',
                            color: _canUpload()
                                ? AppTheme.lightTheme.colorScheme.onPrimary
                                : AppTheme.lightTheme.colorScheme.outline,
                            size: 20,
                          ),
                    label: Text(_isLoading
                        ? 'common.loading'.tr()
                        : 'profile.upload_certificate'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMissingFieldsMessage() {
    final missingFields = _certificateDetails['missingFields'] as List<String>?;
    if (missingFields != null && missingFields.isNotEmpty) {
      return 'medical_upload_ui.missing_fields'
          .tr(namedArgs: {'fields': missingFields.join(', ')});
    }
    return 'medical_upload_ui.complete_details_tab'.tr();
  }

  bool _canUpload() {
    return _capturedImage != null &&
        _certificateDetails['isValid'] == true &&
        _certificateDetails['startDate'] != null &&
        _certificateDetails['endDate'] != null &&
        !_isUploading &&
        !_isLoading;
  }

  void _showPendingUploads() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      builder: (context) => Container(
        height: 60.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'cloud_off',
                  color: AppTheme.lightTheme.colorScheme.error,
                  size: 24,
                ),
                SizedBox(width: 2.w),
                Text(
                  'medical_upload_ui.pending_uploads'.tr(),
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Expanded(
              child: ListView.builder(
                itemCount: _pendingUploads.length,
                itemBuilder: (context, index) {
                  final upload = _pendingUploads[index];
                  return Card(
                    color: AppTheme.lightTheme.colorScheme.surface,
                    elevation: 2,
                    child: ListTile(
                      leading: CustomIconWidget(
                        iconName: 'schedule',
                        color: AppTheme.lightTheme.colorScheme.error,
                        size: 24,
                      ),
                      title: Text(
                        upload['imageName'],
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        'medical_upload_ui.created_label'.tr(namedArgs: {
                          'date': _formatDate(upload['createdAt']),
                        }),
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color:
                              AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          setState(() {
                            _pendingUploads.removeAt(index);
                          });
                          Navigator.of(context).pop();
                        },
                        icon: CustomIconWidget(
                          iconName: 'delete',
                          color: AppTheme.lightTheme.colorScheme.error,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        title: Text(
          'medical_upload_ui.help_title'.tr(),
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'medical_upload_ui.help_how_to'.tr(),
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              _buildHelpStep(
                '1',
                'medical_upload_ui.help_step_capture'.tr(),
              ),
              _buildHelpStep(
                '2',
                'medical_upload_ui.help_step_preview'.tr(),
              ),
              _buildHelpStep('3', 'medical_upload_ui.help_step_details'.tr()),
              _buildHelpStep('4', 'medical_upload_ui.help_step_upload'.tr()),
              SizedBox(height: 2.h),
              Text(
                'medical_upload_ui.help_requirements'.tr(),
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                '• Formato: PDF, JPG, PNG (max 5MB)',
                style: AppTheme.lightTheme.textTheme.bodySmall,
              ),
              Text(
                '• Documento leggibile e completo',
                style: AppTheme.lightTheme.textTheme.bodySmall,
              ),
              Text(
                '• Date di emissione e scadenza visibili',
                style: AppTheme.lightTheme.textTheme.bodySmall,
              ),
              Text(
                '• Informazioni del medico presenti',
                style: AppTheme.lightTheme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'class_schedule.close_modal'.tr(),
              style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              description,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
