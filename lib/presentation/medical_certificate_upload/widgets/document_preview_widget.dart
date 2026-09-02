import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class DocumentPreviewWidget extends StatefulWidget {
  final XFile? capturedImage;
  final VoidCallback? onRemoveImage;
  final Function(XFile)? onImageUpdated;

  const DocumentPreviewWidget({
    super.key,
    this.capturedImage,
    this.onRemoveImage,
    this.onImageUpdated,
  });

  @override
  State<DocumentPreviewWidget> createState() => _DocumentPreviewWidgetState();
}

class _DocumentPreviewWidgetState extends State<DocumentPreviewWidget> {
  bool _isProcessing = false;

  Future<void> _cropImage() async {
    if (widget.capturedImage == null || kIsWeb) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: widget.capturedImage!.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ritaglia Certificato',
            toolbarColor: AppTheme.lightTheme.colorScheme.primary,
            toolbarWidgetColor: AppTheme.lightTheme.colorScheme.onPrimary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Ritaglia Certificato',
            doneButtonTitle: 'Fatto',
            cancelButtonTitle: 'common.cancel'.tr(),
          ),
        ],
      );

      if (croppedFile != null && widget.onImageUpdated != null) {
        widget.onImageUpdated!(XFile(croppedFile.path));
      }
    } catch (e) {
      // Handle crop error silently
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rotateImage() async {
    // For web, rotation would require canvas manipulation
    // For mobile, this would require image processing
    // Simplified implementation - in real app would use image processing library
    if (kIsWeb) return;

    // Placeholder for rotation functionality
    // In production, would use packages like image or flutter_image_compress
  }

  @override
  Widget build(BuildContext context) {
    if (widget.capturedImage == null) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreviewHeader(),
          _buildImagePreview(),
          _buildImageActions(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: 20.h,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'image',
              color: AppTheme.lightTheme.colorScheme.outline,
              size: 32,
            ),
            SizedBox(height: 1.h),
            Text(
              'Nessun documento selezionato',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Padding(
      padding: EdgeInsets.all(4.w),
      child: Row(
        children: [
          CustomIconWidget(
            iconName: 'preview',
            color: AppTheme.lightTheme.colorScheme.primary,
            size: 20,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              'Anteprima Documento',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
          ),
          if (widget.onRemoveImage != null)
            IconButton(
              onPressed: widget.onRemoveImage,
              icon: CustomIconWidget(
                iconName: 'close',
                color: AppTheme.lightTheme.colorScheme.error,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 30.h,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _isProcessing ? _buildProcessingState() : _buildImageContent(),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.lightTheme.colorScheme.primary,
          ),
          SizedBox(height: 2.h),
          Text(
            'Elaborazione immagine...',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: widget.capturedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            );
          }
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
          );
        },
      );
    } else {
      return Image.file(
        File(widget.capturedImage!.path),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  Widget _buildImageActions() {
    return Padding(
      padding: EdgeInsets.all(4.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            onPressed: kIsWeb ? null : _cropImage,
            icon: 'crop',
            label: 'Ritaglia',
            isEnabled: !kIsWeb && !_isProcessing,
          ),
          _buildActionButton(
            onPressed: kIsWeb ? null : _rotateImage,
            icon: 'rotate_right',
            label: 'Ruota',
            isEnabled: !kIsWeb && !_isProcessing,
          ),
          _buildActionButton(
            onPressed: _showImageDetails,
            icon: 'info',
            label: 'receipt.details_label'.tr(),
            isEnabled: !_isProcessing,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String icon,
    required String label,
    required bool isEnabled,
  }) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 1.w),
        child: OutlinedButton.icon(
          onPressed: isEnabled ? onPressed : null,
          icon: CustomIconWidget(
            iconName: icon,
            color: isEnabled
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline,
            size: 16,
          ),
          label: Text(
            label,
            style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: isEnabled
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.outline,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            side: BorderSide(
              color: isEnabled
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.outline,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _showImageDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        title: Text(
          'Dettagli Immagine',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Nome:', widget.capturedImage!.name),
            SizedBox(height: 1.h),
            _buildDetailRow(
              'Percorso:',
              widget.capturedImage!.path.split('/').last,
            ),
            SizedBox(height: 1.h),
            FutureBuilder<int>(
              future: widget.capturedImage!.length(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final sizeInMB =
                      (snapshot.data! / (1024 * 1024)).toStringAsFixed(2);
                  return _buildDetailRow('Dimensione:', '$sizeInMB MB');
                }
                return _buildDetailRow('Dimensione:', 'Calcolando...');
              },
            ),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20.w,
          child: Text(
            label,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
