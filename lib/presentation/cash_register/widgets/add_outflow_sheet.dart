import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../services/cash_register_service.dart';

/// "+ Uscita" form: date (default today), free description (required),
/// amount, optional receipt photo (camera or gallery — compressed and
/// uploaded to the private 'cash-receipts' bucket by CashRegisterService).
/// Returns true via Navigator.pop when an outflow was successfully added.
class AddOutflowSheet extends StatefulWidget {
  const AddOutflowSheet({Key? key}) : super(key: key);

  @override
  State<AddOutflowSheet> createState() => _AddOutflowSheetState();
}

class _AddOutflowSheetState extends State<AddOutflowSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  Uint8List? _photoPreviewBytes;
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photoPreviewBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire fotocamera/galleria: $e')),
      );
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta foto'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Scegli dalla galleria'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? photoPath;
      if (_photoPreviewBytes != null) {
        photoPath = await CashRegisterService.instance.uploadReceiptPhoto(
          _photoPreviewBytes!,
        );
      }

      final amount = double.parse(
        _amountController.text.trim().replaceAll(',', '.'),
      );

      await CashRegisterService.instance.addOutflow(
        date: _selectedDate,
        description: _descriptionController.text.trim(),
        amount: amount,
        photoPath: photoPath,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = CashRegisterService.isCashNegativeError(e)
          ? 'Il saldo di cassa scenderebbe sotto zero: operazione non consentita.'
          : 'Errore durante il salvataggio: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 5.w,
        right: 5.w,
        top: 3.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 3.h,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuova uscita',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 2.h),

              // Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                ),
              ),
              SizedBox(height: 2.h),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'La descrizione è obbligatoria'
                    : null,
              ),
              SizedBox(height: 2.h),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo (€)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Inserisci l\'importo';
                  }
                  final amount = double.tryParse(value.trim().replaceAll(',', '.'));
                  if (amount == null || amount <= 0) {
                    return 'Inserisci un importo valido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 2.h),

              // Photo
              if (_photoPreviewBytes != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _photoPreviewBytes!,
                        height: 20.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                        onPressed: () =>
                            setState(() => _photoPreviewBytes = null),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
              ] else
                OutlinedButton.icon(
                  onPressed: _showPhotoSourceSheet,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Aggiungi foto scontrino (opzionale)'),
                ),
              SizedBox(height: 3.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salva uscita'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
