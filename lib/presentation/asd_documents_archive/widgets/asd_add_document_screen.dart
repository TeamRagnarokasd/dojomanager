import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../services/asd_deadlines_service.dart';
import '../../../services/asd_documents_service.dart';
import 'asd_deadline_picker.dart';

/// "+ Aggiungi documento": brings any document produced outside the app
/// into the archive — pick a photo, PDF or other file, then
/// titolo/categoria/persona-ente/data and an optional linked Scadenzario
/// entry. Uploads to archive/<category>/<timestamp>_<file> and inserts an
/// asd_documents row with source 'uploaded'.
class AsdAddDocumentScreen extends StatefulWidget {
  const AsdAddDocumentScreen({Key? key, this.initialCategoryKey}) : super(key: key);

  /// Preselects this category (e.g. when opened from within a category's
  /// own screen) — still changeable from the dropdown. Falls back to the
  /// first loaded category, as before, when null or not found among them.
  final String? initialCategoryKey;

  @override
  State<AsdAddDocumentScreen> createState() => _AsdAddDocumentScreenState();
}

class _AsdAddDocumentScreenState extends State<AsdAddDocumentScreen> {
  final _documentsService = AsdDocumentsService.instance;
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();

  bool _isLoadingOptions = true;
  bool _isSaving = false;
  List<AsdDocumentCategory> _categories = [];
  List<AsdDeadline> _deadlines = [];

  String? _selectedCategory;
  String? _selectedDeadlineId;
  DateTime _docDate = DateTime.now();

  Uint8List? _pickedBytes;
  String? _pickedFileName;
  String? _pickedMimeType;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final categories = await _documentsService.getCategories();
      List<AsdDeadline> deadlines = [];
      try {
        deadlines = await AsdDeadlinesService.instance.getAllDeadlines();
      } catch (_) {
        // Not critical — the linked-deadline picker just stays empty.
      }
      if (!mounted) return;
      final preselected = widget.initialCategoryKey;
      final hasPreselected =
          preselected != null && categories.any((c) => c.key == preselected);
      setState(() {
        _categories = categories;
        _deadlines = deadlines;
        _selectedCategory = hasPreselected
            ? preselected
            : (categories.isNotEmpty ? categories.first.key : null);
        _isLoadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingOptions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel caricamento delle categorie: $e')),
      );
    }
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
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
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

  Future<void> _pickDocDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(DateTime.now().year - 20),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  Future<void> _save() async {
    if (_pickedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima un file.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una categoria.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final sanitizedName = _documentsService.sanitizeFileName(_pickedFileName!);
      final storagePath = _documentsService.archiveStoragePath(
        category: _selectedCategory!,
        fileName: _documentsService.timestampedFileName(sanitizedName),
      );
      await _documentsService.uploadBytes(
        storagePath,
        _pickedBytes!,
        contentType: _pickedMimeType ?? 'application/octet-stream',
      );
      await _documentsService.createDocument(
        deadlineId: _selectedDeadlineId,
        title: _titleController.text.trim(),
        storagePath: storagePath,
        category: _selectedCategory!,
        subject: _subjectController.text.trim(),
        docDate: _docDate,
        source: kAsdDocumentSourceUploaded,
        fileName: sanitizedName,
        mimeType: _pickedMimeType,
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
        title: const Text('Aggiungi documento'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                        ? 'File selezionato: $_pickedFileName'
                        : 'Nessun file selezionato.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titolo *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c.key, child: Text(c.label)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Persona o ente (facoltativo)'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data del documento'),
                    subtitle: Text(DateFormat('dd/MM/yyyy', 'it_IT').format(_docDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _pickDocDate,
                  ),
                  const SizedBox(height: 8),
                  AsdDeadlinePicker(
                    label: 'Scadenza collegata (facoltativa)',
                    deadlines: _deadlines,
                    selectedDeadlineId: _selectedDeadlineId,
                    onChanged: (value) => setState(() => _selectedDeadlineId = value),
                  ),
                ],
              ),
            ),
    );
  }
}
