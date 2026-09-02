import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

import '../../../constants/app_constants.dart';
import '../../../services/user_document_service.dart';
import '../../../core/app_export.dart';

class UserDocumentsAdminWidget extends StatefulWidget {
  final String userId;
  final String userName;

  const UserDocumentsAdminWidget({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserDocumentsAdminWidget> createState() =>
      _UserDocumentsAdminWidgetState();
}

class _UserDocumentsAdminWidgetState extends State<UserDocumentsAdminWidget> {
  final _documentService = UserDocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      setState(() => _isLoading = true);
      // Admin sees ALL documents including soft-deleted ones
      final documents =
          await _documentService.getUserDocumentsByUserId(widget.userId);
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('user_mgmt.load_documents_error'
          .tr(namedArgs: {'detail': e.toString()}));
    }
  }

  Future<void> _viewDocument(String filePath) async {
    try {
      final url = await _documentService.getDocumentUrl(filePath);
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showErrorSnackBar('user_mgmt.open_document_error'
          .tr(namedArgs: {'detail': e.toString()}));
    }
  }

  Future<void> _downloadDocument(String filePath, String fileName) async {
    try {
      final url = await _documentService.getDocumentUrl(filePath);
      if (kIsWeb) {
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..setAttribute('target', '_blank')
          ..click();
      } else {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Errore durante il download: $e');
    }
  }

  /// Admin hard-delete: permanently removes document from storage and database
  Future<void> _deleteDocument(String documentId, String filePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'user_mgmt.confirm_deletion'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'Eliminare definitivamente questo documento? L\'operazione non può essere annullata.',
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
              'Elimina definitivamente',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Admin performs hard-delete (permanent)
        await _documentService.deleteDocument(documentId, filePath);
        _showSuccessSnackBar('profile.document_deleted'.tr());
        await _loadDocuments();
      } catch (e) {
        _showErrorSnackBar('user_mgmt.delete_document_error'
            .tr(namedArgs: {'detail': e.toString()}));
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.user_documents_title'.tr(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      widget.userName,
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.folder_open, color: Colors.grey, size: 20.sp),
            ],
          ),
          SizedBox(height: 2.h),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: Colors.red),
            )
          else if (_documents.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Text(
                  'user_mgmt.no_documents_admin'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.grey,
                    fontSize: 12.sp,
                  ),
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
                final isDeletedByUser = doc['deleted_by_user'] == true;
                return Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: isDeletedByUser
                        ? Color(
                            0xFF3A2A2A) // Slightly reddish tint for soft-deleted
                        : Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultBorderRadius / 2),
                    border: isDeletedByUser
                        ? Border.all(
                            color: Colors.orange.withAlpha(80), width: 1)
                        : null,
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
                                      color: isDeletedByUser
                                          ? Colors.grey[500]
                                          : Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isDeletedByUser)
                                  Container(
                                    margin: EdgeInsets.only(left: 1.w),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 1.5.w, vertical: 0.3.h),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withAlpha(40),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.orange, width: 0.5),
                                    ),
                                    child: Text(
                                      'Nascosto',
                                      style: GoogleFonts.inter(
                                        color: Colors.orange,
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
                      // Download button (new - between view and delete)
                      IconButton(
                        onPressed: () => _downloadDocument(
                          doc['file_url'],
                          doc['file_name'] ?? 'documento',
                        ),
                        icon: Icon(Icons.download, color: Colors.green),
                        iconSize: 20.sp,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        tooltip: 'Scarica',
                      ),
                      SizedBox(width: 2.w),
                      // Admin hard-delete button
                      IconButton(
                        onPressed: () =>
                            _deleteDocument(doc['id'], doc['file_url']),
                        icon: Icon(Icons.delete_forever, color: Colors.red),
                        iconSize: 20.sp,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        tooltip: 'Elimina definitivamente',
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
