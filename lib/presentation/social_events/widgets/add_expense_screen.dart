import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../services/asd_documents_service.dart';
import '../../../services/social_events_service.dart';

double? _parseItalianAmount(String text) {
  final cleaned = text.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

/// "Aggiungi spesa": date/fornitore/importo/metodo/nota plus an optional
/// giustificativo — same picker (fotocamera/galleria/file) and mime-type
/// guess as asd_add_document_screen.dart, replicated here rather than
/// imported since those pickers are private to that screen's State class.
/// A picked file is uploaded via AsdDocumentsService exactly like any other
/// archive document (category 'eventi_sociali', source 'uploaded'); its id
/// is then stored on the expense row.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({Key? key, required this.eventId, required this.eventTitle})
      : super(key: key);

  final String eventId;
  final String eventTitle;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _service = SocialEventsService.instance;
  final _documentsService = AsdDocumentsService.instance;
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _vendorController = TextEditingController(text: 'Metro');
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  String _paymentMethod = kSocialEventPaymentMethodKeys.first;
  bool _isSaving = false;

  Uint8List? _pickedBytes;
  String? _pickedFileName;
  String? _pickedMimeType;

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _guessMimeType(String fileName) {
    switch (fileName.toLowerCase().split('.').last) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 90);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _pickedFileName = xfile.name;
        _pickedMimeType = xfile.mimeType ?? _guessMimeType(xfile.name);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile leggere il file selezionato.')),
        );
        return;
      }
      setState(() {
        _pickedBytes = file.bytes;
        _pickedFileName = file.name;
        _pickedMimeType = _guessMimeType(file.name);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _pickExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      String? documentId;
      if (_pickedBytes != null) {
        final sanitizedName = _documentsService.sanitizeFileName(_pickedFileName!);
        final storagePath = _documentsService.archiveStoragePath(
          category: 'eventi_sociali',
          fileName: _documentsService.timestampedFileName(sanitizedName),
        );
        await _documentsService.uploadBytes(
          storagePath,
          _pickedBytes!,
          contentType: _pickedMimeType ?? 'application/octet-stream',
        );
        final title = 'Scontrino ${_vendorController.text.trim()} - '
            '${DateFormat('dd/MM/yyyy', 'it_IT').format(_expenseDate)}';
        final savedDocument = await _documentsService.createDocument(
          title: title,
          storagePath: storagePath,
          category: 'eventi_sociali',
          subject: widget.eventTitle,
          docDate: _expenseDate,
          source: kAsdDocumentSourceUploaded,
          fileName: sanitizedName,
          mimeType: _pickedMimeType,
        );
        documentId = savedDocument.id;
      }
      await _service.addExpense(
        eventId: widget.eventId,
        expenseDate: _expenseDate,
        vendor: _vendorController.text,
        amount: _parseItalianAmount(_amountController.text)!,
        paymentMethod: _paymentMethod,
        note: _noteController.text,
        documentId: documentId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi spesa'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Fotocamera'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galleria'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('File'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _pickedFileName != null
                  ? 'Giustificativo selezionato: $_pickedFileName'
                  : 'Nessun giustificativo selezionato (facoltativo).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              subtitle: Text(DateFormat('dd/MM/yyyy', 'it_IT').format(_expenseDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickExpenseDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _vendorController,
              decoration: const InputDecoration(labelText: 'Fornitore'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Importo (€) *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => _parseItalianAmount(v ?? '') == null ? 'Valore non valido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Metodo di pagamento'),
              items: kSocialEventPaymentMethodKeys
                  .map((key) => DropdownMenuItem(
                        value: key,
                        child: Text(socialEventPaymentMethodLabel(key)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Nota (facoltativa)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
