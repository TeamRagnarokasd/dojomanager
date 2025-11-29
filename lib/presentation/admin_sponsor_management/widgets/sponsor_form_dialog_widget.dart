import 'package:flutter/material.dart';
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
          imageFilePath:
              _selectedImagePath, // Changed from imageUrl to imageFilePath
          externalUrl: _externalUrlController.text.trim(),
          status: _status,
          displayOrder: displayOrder,
          currentImageUrl:
              _currentImageUrl, // Pass current image URL for deletion
        );

        if (result != null) {
          widget.onSponsorUpdated?.call();
        } else {
          _showErrorMessage('Errore nell\'aggiornamento dello sponsor');
        }
      } else {
        // Create new sponsor
        final result = await SponsorService.createSponsor(
          name: _nameController.text.trim(),
          externalUrl: _externalUrlController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          imageFilePath:
              _selectedImagePath, // Changed from imageUrl to imageFilePath
          displayOrder: displayOrder,
        );

        if (result != null) {
          widget.onSponsorCreated?.call();
        } else {
          _showErrorMessage('Errore nella creazione dello sponsor');
        }
      }
    } catch (error) {
      print('Error submitting sponsor form: $error');
      _showErrorMessage(_isEditing
          ? 'Errore nell\'aggiornamento dello sponsor'
          : 'Errore nella creazione dello sponsor');
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
              _isEditing ? 'Modifica Sponsor' : 'Nuovo Sponsor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                        decoration: const InputDecoration(
                          labelText: 'Nome Sponsor *',
                          hintText: 'Inserisci il nome dello sponsor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Il nome è obbligatorio';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 2.h),

                      // External URL Field
                      TextFormField(
                        controller: _externalUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL Esterno *',
                          hintText: 'https://esempio.com',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L\'URL è obbligatorio';
                          }
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'L\'URL deve iniziare con http:// o https://';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 2.h),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                          hintText: 'Inserisci una descrizione dello sponsor',
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

                      Row(
                        children: [
                          // Display Order Field
                          Expanded(
                            child: TextFormField(
                              controller: _displayOrderController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ordine',
                                hintText: '0',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final order = int.tryParse(value);
                                  if (order == null) {
                                    return 'Inserisci un numero valido';
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
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Stato',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'active',
                                  child: Text('Attivo'),
                                ),
                                DropdownMenuItem(
                                  value: 'inactive',
                                  child: Text('Inattivo'),
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
                    child: const Text('Annulla'),
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
                        : Text(_isEditing ? 'Aggiorna' : 'Crea'),
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
