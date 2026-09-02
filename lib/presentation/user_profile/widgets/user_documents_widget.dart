import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

import '../../../constants/app_constants.dart';
import '../../../services/user_document_service.dart';
import '../../../services/terms_document_service.dart';
import '../../../core/app_export.dart';

class UserDocumentsWidget extends StatefulWidget {
  final String? userId;

  const UserDocumentsWidget({Key? key, this.userId}) : super(key: key);

  @override
  State<UserDocumentsWidget> createState() => _UserDocumentsWidgetState();
}

class _UserDocumentsWidgetState extends State<UserDocumentsWidget> {
  final UserDocumentService _documentService = UserDocumentService();
  final TermsDocumentService _termsService = TermsDocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await _documentService.getUserDocuments(
        userId: widget.userId,
      );
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading documents: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument() async {
    try {
      if (mounted) setState(() => _isUploading = true);
      final result = await _documentService.pickAndUploadDocument();
      if (!mounted) return;
      setState(() => _isUploading = false);

      if (result != null) {
        _showSuccessSnackBar('profile.document_uploaded'.tr());
        await _loadDocuments();
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      _showErrorSnackBar(
        'profile.document_upload_error'.tr(namedArgs: {'error': '$e'}),
      );
    }
  }

  Future<void> _viewDocument(String filePath) async {
    try {
      final url = await _documentService.getDocumentUrl(filePath);
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorSnackBar(
        'profile.document_open_error'.tr(namedArgs: {'error': '$e'}),
      );
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docId = doc['id'] as String;
    final filePath = doc['file_url'] as String;
    final fileName = doc['file_name'] as String? ?? 'documento';
    final documentType = doc['document_type'] as String? ?? 'user_upload';
    final documentLabel = doc['document_label'] as String? ?? fileName;

    setState(() => _downloadingId = docId);
    try {
      // For terms documents, generate and download as PDF
      final isTermsDoc = documentType == 'terms_acceptance' ||
          documentType == 'child_terms_acceptance' ||
          documentType == 'minor_1417_terms';

      if (isTermsDoc) {
        await _termsService.downloadTermsDocumentAsPdf(
          filePath: filePath,
          documentType: documentType,
          documentLabel: documentLabel,
        );
      } else {
        // Regular document: get signed URL and trigger download
        final url = await _documentService.getDocumentUrl(filePath);
        if (kIsWeb) {
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..setAttribute('target', '_blank')
            ..click();
        } else {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Errore durante il download: $e');
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'user_mgmt.confirm_deletion'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'profile.delete_document_confirm'.tr(),
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'common.delete'.tr(),
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Soft-delete: document disappears from user view but admin can still see it
        await _documentService.softDeleteDocument(documentId);
        _showSuccessSnackBar('profile.document_deleted'.tr());
        await _loadDocuments();
      } catch (e) {
        _showErrorSnackBar(
          'profile.document_delete_error'.tr(namedArgs: {'error': '$e'}),
        );
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String? fileType) {
    switch (fileType) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.blue;
      case 'document':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'profile.documents_upload_title'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.folder_open, color: Colors.grey, size: 20.sp),
            ],
          ),
          SizedBox(height: 2.h),
          // Upload button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadDocument,
              icon: _isUploading
                  ? SizedBox(
                      width: 16.sp,
                      height: 16.sp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.upload_file, size: 18.sp),
              label: Text(
                _isUploading
                    ? 'common.loading'.tr()
                    : 'profile.upload_document'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultBorderRadius,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          // Documents list
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: Colors.red))
          else if (_documents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Text(
                  'profile.no_documents'.tr(),
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12.sp),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _documents.length,
              separatorBuilder: (context, index) => SizedBox(height: 1.h),
              itemBuilder: (context, index) {
                final doc = _documents[index];
                final docId = doc['id'] as String;
                final isDownloading = _downloadingId == docId;
                final documentType =
                    doc['document_type'] as String? ?? 'user_upload';
                final isTermsDoc = documentType == 'terms_acceptance' ||
                    documentType == 'child_terms_acceptance' ||
                    documentType == 'minor_1417_terms';

                return Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultBorderRadius / 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(doc['file_type']),
                        color: _getFileIconColor(doc['file_type']),
                        size: 24.sp,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    doc['document_label'] ??
                                        doc['file_name'] ??
                                        'profile.document_default_name'.tr(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isTermsDoc)
                                  Container(
                                    margin: EdgeInsets.only(left: 1.w),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 1.5.w, vertical: 0.3.h),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withAlpha(40),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.blue, width: 0.5),
                                    ),
                                    child: Text(
                                      'PDF',
                                      style: GoogleFonts.inter(
                                        color: Colors.blue,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              _formatDate(doc['created_at']),
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // View button
                      IconButton(
                        onPressed: () => _viewDocument(doc['file_url']),
                        icon: Icon(Icons.visibility, color: Colors.blue),
                        iconSize: 20.sp,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        tooltip: 'Visualizza',
                      ),
                      SizedBox(width: 2.w),
                      // Download button (PDF for terms docs, direct download for others)
                      isDownloading
                          ? SizedBox(
                              width: 20.sp,
                              height: 20.sp,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            )
                          : IconButton(
                              onPressed: () => _downloadDocument(doc),
                              icon: Icon(
                                isTermsDoc
                                    ? Icons.picture_as_pdf
                                    : Icons.download,
                                color: Colors.green,
                              ),
                              iconSize: 20.sp,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                              tooltip: isTermsDoc ? 'Scarica PDF' : 'Scarica',
                            ),
                      SizedBox(width: 2.w),
                      // Delete button (soft-delete for user)
                      IconButton(
                        onPressed: () => _deleteDocument(doc['id']),
                        icon: Icon(Icons.delete, color: Colors.red),
                        iconSize: 20.sp,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        tooltip: 'Elimina',
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
