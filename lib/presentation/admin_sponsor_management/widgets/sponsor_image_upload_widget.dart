import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';

class SponsorImageUploadWidget extends StatefulWidget {
  final String? currentImageUrl;
  final Function(String?) onImageSelected;
  final bool isRequired;

  const SponsorImageUploadWidget({
    Key? key,
    this.currentImageUrl,
    required this.onImageSelected,
    this.isRequired = false,
  }) : super(key: key);

  @override
  State<SponsorImageUploadWidget> createState() =>
      _SponsorImageUploadWidgetState();
}

class _SponsorImageUploadWidgetState extends State<SponsorImageUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              'Immagine Sponsor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (widget.isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),

        SizedBox(height: 1.h),

        // Upload Container
        Container(
          width: double.infinity,
          height: 25.h,
          decoration: BoxDecoration(
            border: Border.all(
              color: _error != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
              width: _error != null ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: _buildUploadContent(),
        ),

        // Error Message
        if (_error != null) ...[
          SizedBox(height: 0.5.h),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],

        SizedBox(height: 1.h),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _isUploading ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text('common.gallery'.tr()),
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _isUploading ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: Text('sponsor_ui.camera'.tr()),
              ),
            ),
            if (_selectedImage != null || widget.currentImageUrl != null) ...[
              SizedBox(width: 2.w),
              IconButton(
                onPressed: _isUploading ? null : _removeImage,
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: 'Rimuovi immagine',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildUploadContent() {
    if (_isUploading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 2.h),
            Text(
              'common.uploading'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: kIsWeb
            ? Image.network(
                _selectedImage!.path,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPlaceholder();
                },
              )
            : Image.file(
                File(_selectedImage!.path),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPlaceholder();
                },
              ),
      );
    }

    if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.network(
          widget.currentImageUrl!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      );
    }

    return _buildUploadPlaceholder();
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 48,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.6),
        ),
        SizedBox(height: 2.h),
        Text(
          'common.upload_image'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
        SizedBox(height: 1.h),
        Text(
          'Tocca per selezionare un\'immagine\ndalla galleria o scattare una foto',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
        ),
        SizedBox(height: 2.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'JPEG, PNG, WebP - Max 5MB',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6),
        ),
        SizedBox(height: 2.h),
        Text(
          'sponsor_ui.image_load_error'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
    });

    try {
      // Request permissions for camera on mobile
      if (source == ImageSource.camera && !kIsWeb) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          setState(() {
            _error = 'Permesso fotocamera richiesto per scattare foto';
          });
          return;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        // Validate file size (5MB limit)
        int fileSizeInBytes = await image.length();
        double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

        if (fileSizeInMB > 5.0) {
          setState(() {
            _error = 'L\'immagine deve essere più piccola di 5MB';
          });
          return;
        }

        // Validate file type
        final String fileName = image.name.toLowerCase();
        final List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
        final bool isValidType =
            allowedExtensions.any((ext) => fileName.endsWith('.$ext'));

        if (!isValidType) {
          setState(() {
            _error = 'Formato file non supportato. Usa JPEG, PNG o WebP';
          });
          return;
        }

        setState(() {
          _selectedImage = image;
          _error = null;
        });

        // Callback to parent widget
        widget.onImageSelected(_selectedImage!.path);
      }
    } catch (error) {
      setState(() {
        _error = 'sponsor_ui.image_select_error'
            .tr(namedArgs: {'error': error.toString()});
      });
      print('Error picking image: $error');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _error = null;
    });
    widget.onImageSelected(null);
  }

  String? validateImage() {
    if (widget.isRequired &&
        _selectedImage == null &&
        (widget.currentImageUrl == null || widget.currentImageUrl!.isEmpty)) {
      return 'L\'immagine è obbligatoria';
    }
    return null;
  }
}
