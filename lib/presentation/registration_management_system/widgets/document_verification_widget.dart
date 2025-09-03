import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_theme.dart';

class DocumentVerificationWidget extends StatefulWidget {
  final Map<String, dynamic> registration;
  final Function(String) onDocumentApprove;
  final Function(String, String) onDocumentReject;

  const DocumentVerificationWidget({
    super.key,
    required this.registration,
    required this.onDocumentApprove,
    required this.onDocumentReject,
  });

  @override
  State<DocumentVerificationWidget> createState() =>
      _DocumentVerificationWidgetState();
}

class _DocumentVerificationWidgetState
    extends State<DocumentVerificationWidget> {
  final List<Map<String, dynamic>> _documents = [
    {
      'name': 'Certificato Medico',
      'type': 'medical_certificate',
      'status': 'pending',
      'url': 'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=400',
      'uploadedAt': '2025-01-15',
    },
    {
      'name': 'Documento Identità',
      'type': 'identity_document',
      'status': 'pending',
      'url': 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400',
      'uploadedAt': '2025-01-15',
    },
    {
      'name': 'Codice Fiscale',
      'type': 'tax_code',
      'status': 'pending',
      'url': 'https://images.unsplash.com/photo-1554224154-26032fced8bd?w=400',
      'uploadedAt': '2025-01-15',
    },
  ];

  String? _selectedDocumentType;
  bool _isZoomedIn = false;
  String? _zoomedImageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90.w,
      height: 80.h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
            ),
            child: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.white, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verifica Documenti',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        widget.registration['full_name']?.toString() ??
                            'Candidato',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(204),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Document gallery with zoom functionality
          Expanded(
            child: _isZoomedIn ? _buildZoomedView() : _buildDocumentGallery(),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(12.0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 4.0,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedDocumentType != null
                        ? () => _showRejectDialog()
                        : null,
                    icon: Icon(Icons.close, size: 16.sp),
                    label: Text('Rifiuta Documento'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedDocumentType != null
                        ? () => _approveDocument()
                        : null,
                    icon: Icon(Icons.check, size: 16.sp),
                    label: Text('Approva Documento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentGallery() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documenti Caricati',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16.sp,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          SizedBox(height: 12.h),

          // Documents grid
          ...(_documents.map((doc) => _buildDocumentCard(doc)).toList()),

          SizedBox(height: 20.h),

          // Approval checkboxes section
          Text(
            'Verifica Completata',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          SizedBox(height: 8.h),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight.withAlpha(128),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              children: _documents
                  .map((doc) => CheckboxListTile(
                        title: Text(
                          'Documento ${doc['name']} verificato e conforme',
                          style: GoogleFonts.inter(fontSize: 12.sp),
                        ),
                        subtitle: Text(
                          'Caricato il ${doc['uploadedAt']}',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                        value: doc['status'] == 'approved',
                        onChanged: (value) {
                          setState(() {
                            doc['status'] =
                                value == true ? 'approved' : 'pending';
                            if (value == true) {
                              _selectedDocumentType = doc['type'];
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final isSelected = _selectedDocumentType == doc['type'];

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withAlpha(26) : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        elevation: 2,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedDocumentType = doc['type'];
            });
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Document preview
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isZoomedIn = true;
                      _zoomedImageUrl = doc['url'];
                    });
                  },
                  child: Container(
                    width: 80.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.0),
                      image: DecorationImage(
                        image: NetworkImage(doc['url']),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6.0),
                        color: Colors.black.withAlpha(77),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12.w),

                // Document info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['name'],
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: AppTheme.textPrimaryLight,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Caricato: ${doc['uploadedAt']}',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: _getStatusColor(doc['status']).withAlpha(26),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          _getStatusLabel(doc['status']),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(doc['status']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryColor,
                    size: 20.sp,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomedView() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: EdgeInsets.all(20.w),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                _zoomedImageUrl ?? '',
                fit: BoxFit.contain,
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
            ),
          ),
          Positioned(
            top: 16.h,
            right: 16.w,
            child: CircleAvatar(
              backgroundColor: Colors.black.withAlpha(128),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isZoomedIn = false;
                    _zoomedImageUrl = null;
                  });
                },
                icon: Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _approveDocument() {
    if (_selectedDocumentType != null) {
      widget.onDocumentApprove(_selectedDocumentType!);
      Navigator.pop(context);
    }
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rifiuta Documento',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inserisci il motivo del rifiuto:',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Documento non leggibile, scaduto, non conforme...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty &&
                  _selectedDocumentType != null) {
                Navigator.pop(context);
                widget.onDocumentReject(
                    _selectedDocumentType!, reasonController.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Rifiuta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approvato';
      case 'rejected':
        return 'Respinto';
      case 'pending':
      default:
        return 'In Attesa';
    }
  }
}
