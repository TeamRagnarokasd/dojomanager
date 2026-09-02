import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:sizer/sizer.dart';

import '../../../services/sponsor_service.dart';
import './sponsor_image_upload_widget.dart';

class SponsorFormDialogWidget extends StatefulWidget {
  final Map<String, dynamic>? sponsor;
  final VoidCallback? onSponsorCreated;
  final VoidCallback? onSponsorUpdated;

  const SponsorFormDialogWidget({
    Key? key,
    this.sponsor,
    this.onSponsorCreated,
    this.onSponsorUpdated,
  }) : super(key: key);

  @override
  State<SponsorFormDialogWidget> createState() =>
      _SponsorFormDialogWidgetState();
}

class _SponsorFormDialogWidgetState extends State<SponsorFormDialogWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _externalUrlController = TextEditingController();
  final _displayOrderController = TextEditingController();

  String _status = 'active';
  String _category = 'sponsor';
  bool _isLoading = false;
  bool get _isEditing => widget.sponsor != null;
  String? _selectedImagePath;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFields();
    }
  }

  void _populateFields() {
    final sponsor = widget.sponsor!;
    _nameController.text = sponsor['name'] ?? '';
    _descriptionController.text = sponsor['description'] ?? '';
    _externalUrlController.text = sponsor['external_url'] ?? '';
    _displayOrderController.text = sponsor['display_order']?.toString() ?? '0';
    _status = sponsor['status'] ?? 'active';
    _category = sponsor['category'] ?? 'sponsor';
    _currentImageUrl = sponsor['image_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _externalUrlController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final displayOrder = int.tryParse(_displayOrderController.text) ?? 0;

      if (_isEditing) {
        // Update existing sponsor
        final result = await SponsorService.updateSponsor(
          id: widget.sponsor!['id'],
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageFilePath: _selectedImagePath,
          externalUrl: _externalUrlController.text.trim(),
          status: _status,
          displayOrder: displayOrder,
          currentImageUrl: _currentImageUrl,
          category: _category,
        );

        if (result != null) {
          widget.onSponsorUpdated?.call();
        } else {
          _showErrorMessage('sponsor_ui.update_error'.tr());
        }
      } else {
        // Create new sponsor
        final result = await SponsorService.createSponsor(
          name: _nameController.text.trim(),
          externalUrl: _externalUrlController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageFilePath: _selectedImagePath,
          displayOrder: displayOrder,
          category: _category,
        );

        if (result != null) {
          widget.onSponsorCreated?.call();
        } else {
          _showErrorMessage('sponsor_ui.create_error'.tr());
        }
      }
    } catch (error) {
      print('Error submitting sponsor form: $error');
      _showErrorMessage(
        _isEditing
            ? 'sponsor_ui.update_error'.tr()
            : 'sponsor_ui.create_error'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 90.w,
        constraints: BoxConstraints(maxHeight: 85.h),
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              _isEditing
                  ? 'sponsor_ui.edit_sponsor'.tr()
                  : 'sponsor_ui.new_sponsor'.tr(),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),

            SizedBox(height: 3.h),

            // Form
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'admin_sponsor.name_label'.tr(),
                          hintText: 'sponsor_ui.name_hint'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'validation.name_required'.tr();
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 2.h),

                      // External URL Field
                      TextFormField(
                        controller: _externalUrlController,
                        decoration: InputDecoration(
                          labelText: 'admin_sponsor.url_label'.tr(),
                          hintText: 'sponsor_ui.url_hint'.tr(),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'validation.url_required'.tr();
                          }
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'validation.url_must_start_http'.tr();
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 2.h),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'common.description'.tr(),
                          hintText: 'sponsor_ui.description_hint'.tr(),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      SizedBox(height: 2.h),

                      // Image Upload Widget - REPLACED URL INPUT FIELD
                      SponsorImageUploadWidget(
                        currentImageUrl: _currentImageUrl,
                        onImageSelected: (imagePath) {
                          setState(() {
                            _selectedImagePath = imagePath;
                          });
                        },
                        isRequired: false,
                      ),

                      SizedBox(height: 2.h),

                      // Category Selector
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'sponsor',
                            child: Text('Sponsor / Partner'),
                          ),
                          DropdownMenuItem(
                            value: 'affiliazione',
                            child: Text('Affiliazione / Certificazione'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _category = value ?? 'sponsor');
                        },
                      ),

                      SizedBox(height: 2.h),

                      Row(
                        children: [
                          // Display Order Field
                          Expanded(
                            child: TextFormField(
                              controller: _displayOrderController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'sponsor_ui.display_order'.tr(),
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final order = int.tryParse(value);
                                  if (order == null) {
                                    return 'validation.enter_valid_number'.tr();
                                  }
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: 4.w),

                          // Status Field
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Stato',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'active',
                                  child: Text('sponsor_ui.active'.tr()),
                                ),
                                DropdownMenuItem(
                                  value: 'inactive',
                                  child: Text('sponsor_ui.inactive'.tr()),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _status = value ?? 'active');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isEditing
                                ? 'common.update'.tr()
                                : 'common.create'.tr(),
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
}
