import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class MedicalCertificateSection extends StatefulWidget {
  final List<Map<String, dynamic>> uploadedDocuments;
  final Function(Map<String, dynamic>) onDocumentAdded;
  final Function(int) onDocumentRemoved;

  const MedicalCertificateSection({
    super.key,
    required this.uploadedDocuments,
    required this.onDocumentAdded,
    required this.onDocumentRemoved,
  });

  @override
  State<MedicalCertificateSection> createState() =>
      _MedicalCertificateSectionState();
}

class _MedicalCertificateSectionState extends State<MedicalCertificateSection> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certificato Medico',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 1.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.tertiary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.tertiary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: AppTheme.lightTheme.colorScheme.tertiary,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Il certificato medico sportivo non è obbligatorio per l\'iscrizione, ma hai 30 giorni di tempo per caricarlo. Dopo questo periodo, l\'iscrizione e l\'abbonamento verranno sospesi.',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Carica il certificato medico sportivo (opzionale per ora)',
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 3.h),
          _buildUploadButtons(),
          SizedBox(height: 2.h),
          widget.uploadedDocuments.isEmpty
              ? _buildEmptyState()
              : _buildDocumentsList(),
          if (_isUploading) ...[
            SizedBox(height: 2.h),
            _buildUploadingIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _captureFromCamera,
            icon: CustomIconWidget(
              iconName: 'camera_alt',
              color: AppTheme.lightTheme.colorScheme.onPrimary,
              size: 20,
            ),
            label: Text('Fotocamera'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 2.h),
            ),
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickFromGallery,
            icon: CustomIconWidget(
              iconName: 'photo_library',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 20,
            ),
            label: Text('Galleria'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 2.h),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          CustomIconWidget(
            iconName: 'description',
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 32,
          ),
          SizedBox(height: 1.h),
          Text(
            'Nessun documento caricato',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 0.5.h),
          Text(
            'Puoi caricare il certificato medico ora o entro 30 giorni dall\'iscrizione',
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      children: widget.uploadedDocuments.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> document = entry.value;
        return _buildDocumentCard(index, document);
      }).toList(),
    );
  }

  Widget _buildDocumentCard(int index, Map<String, dynamic> document) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 15.w,
            height: 15.w,
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: document['type'] == 'image'
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.memory(
                            document['bytes'],
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(document['path']),
                            fit: BoxFit.cover,
                          ),
                  )
                : Center(
                    child: CustomIconWidget(
                      iconName: 'picture_as_pdf',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document['name'] ?? 'Documento',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${document['size']} • ${document['type'].toString().toUpperCase()}',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showDeleteDialog(index),
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.error
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: CustomIconWidget(
                iconName: 'delete',
                color: AppTheme.lightTheme.colorScheme.error,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Text(
            'Caricamento documento in corso...',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureFromCamera() async {
    try {
      setState(() => _isUploading = true);

      if (!kIsWeb) {
        final cameraPermission = await Permission.camera.request();
        if (!cameraPermission.isGranted) {
          _showPermissionDialog('fotocamera');
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        await _processSelectedFile(image);
      }
    } catch (e) {
      _showErrorDialog('Errore durante l\'acquisizione dalla fotocamera');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isUploading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        await _processPickedFile(file);
      }
    } catch (e) {
      _showErrorDialog('Errore durante la selezione del file');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _processSelectedFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final sizeInMB = bytes.length / (1024 * 1024);

    if (sizeInMB > 5) {
      _showErrorDialog('Il file è troppo grande. Dimensione massima: 5MB');
      return;
    }

    final document = {
      'name': file.name,
      'path': file.path,
      'bytes': bytes,
      'size': _formatFileSize(bytes.length),
      'type': 'image',
      'uploadDate': DateTime.now(),
    };

    widget.onDocumentAdded(document);
  }

  Future<void> _processPickedFile(PlatformFile file) async {
    final sizeInMB = file.size / (1024 * 1024);

    if (sizeInMB > 5) {
      _showErrorDialog('Il file è troppo grande. Dimensione massima: 5MB');
      return;
    }

    final document = {
      'name': file.name,
      'path': file.path,
      'bytes': file.bytes,
      'size': _formatFileSize(file.size),
      'type': file.extension?.toLowerCase() == 'pdf' ? 'pdf' : 'image',
      'uploadDate': DateTime.now(),
    };

    widget.onDocumentAdded(document);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Elimina Documento'),
        content: Text('Sei sicuro di voler eliminare questo documento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDocumentRemoved(index);
            },
            child: Text(
              'Elimina',
              style: TextStyle(color: AppTheme.lightTheme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permesso Richiesto'),
        content: Text(
            'È necessario il permesso per accedere alla $permission per caricare i documenti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Impostazioni'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Errore'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
