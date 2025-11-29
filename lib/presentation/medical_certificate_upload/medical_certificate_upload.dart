import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

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
  final PageController _pageController = PageController();
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
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _pageController.animateToPage(
        _tabController.index,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onImageCaptured(XFile image) {
    setState(() {
      _capturedImage = image;
      _hasUnsavedChanges = true;
      _currentStep = 1;
    });

    // Move to next tab
    _tabController.animateTo(1);

    Fluttertoast.showToast(
      msg: "Documento acquisito con successo",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _onRemoveImage() {
    setState(() {
      _capturedImage = null;
      _hasUnsavedChanges = false;
      _currentStep = 0;
    });

    // Move back to first tab
    _tabController.animateTo(0);
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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completare tutti i campi richiesti'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedUrl;

      // Upload file if available
      if (_capturedImage != null) {
        final userId = SupabaseService.instance.getCurrentUserId();
        if (userId == null) {
          throw Exception('Utente non autenticato');
        }

        final fileName =
            'medical_cert_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await SupabaseService.instance.client.storage
            .from('medical-certificates')
            .uploadBinary(fileName, await _capturedImage!.readAsBytes());

        uploadedUrl = SupabaseService.instance.client.storage
            .from('medical-certificates')
            .getPublicUrl(fileName);
      }

      // Update user profile with complete certificate details
      final userId = SupabaseService.instance.getCurrentUserId();
      if (userId != null) {
        final result =
            await UserProfileService().updateMedicalCertificateComplete(
          userId: userId,
          certificateUrl: uploadedUrl ?? '',
          startDate: _certificateDetails['startDate'] as DateTime?,
          expiryDate: _certificateDetails['endDate'] as DateTime?,
          doctorName: _certificateDetails['doctorName'] as String?,
          medicalCenter: _certificateDetails['medicalCenter'] as String?,
          certificateType: _certificateDetails['certificateType'] as String?,
          certificateStatus: 'pending',
        );

        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Certificato medico caricato con successo!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception(result['error'] ?? 'Errore durante il salvataggio');
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il caricamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                'Certificato Caricato',
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
                  'Il certificato medico è stato caricato con successo.',
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
                          'Stato: In attesa di approvazione',
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
                    'Il tuo certificato è stato caricato ed è ora in attesa di approvazione da parte dell\'amministrazione.',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.primary,
                    ),
                  ),
                  if (_certificateDetails['expirationDate'] != null) ...[
                    SizedBox(height: 1.h),
                    Text(
                      'Scadenza: ${_formatDate(_certificateDetails['expirationDate'])}',
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
                    'Riceverai una notifica quando il certificato sarà approvato',
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
              'Torna al Profilo',
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
              'Carica Altro',
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

    _tabController.animateTo(0);
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
            'Modifiche non salvate',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            'Hai modifiche non salvate. Vuoi uscire senza salvare?',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annulla',
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
        'Carica Certificato Medico',
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
                Text('Scatta', style: TextStyle(fontSize: 12.sp)),
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
                Text('Anteprima', style: TextStyle(fontSize: 12.sp)),
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
                Text('Dettagli', style: TextStyle(fontSize: 12.sp)),
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
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetForm,
                  child: Text('Ricomincia'),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: 4.w),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _canUpload() ? _uploadCertificate : null,
                icon: CustomIconWidget(
                  iconName: 'cloud_upload',
                  color: _canUpload()
                      ? AppTheme.lightTheme.colorScheme.onPrimary
                      : AppTheme.lightTheme.colorScheme.outline,
                  size: 20,
                ),
                label: Text('Carica Certificato'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canUpload() {
    return _capturedImage != null &&
        _certificateDetails['isValid'] == true &&
        !_isUploading;
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
                  'Caricamenti in Sospeso',
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
                        'Creato: ${_formatDate(upload['createdAt'])}',
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
          'Aiuto',
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
                'Come caricare il certificato medico:',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              _buildHelpStep(
                '1',
                'Scatta una foto del certificato o selezionalo dalla galleria',
              ),
              _buildHelpStep(
                '2',
                'Controlla l\'anteprima e ritaglia se necessario',
              ),
              _buildHelpStep('3', 'Compila i dettagli del certificato'),
              _buildHelpStep('4', 'Carica il documento'),
              SizedBox(height: 2.h),
              Text(
                'Requisiti:',
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
              'Chiudi',
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
