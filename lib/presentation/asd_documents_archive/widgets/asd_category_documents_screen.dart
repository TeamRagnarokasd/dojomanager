import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/asd_documents_service.dart';
import 'asd_document_actions.dart';

/// One category's documents, grouped by year of doc_date (most recent
/// first). Each row: title, subject, date, Drive status (tap to toggle),
/// tap to open, menu to edit its data or delete it.
class AsdCategoryDocumentsScreen extends StatefulWidget {
  const AsdCategoryDocumentsScreen({Key? key, required this.category}) : super(key: key);

  final AsdDocumentCategory category;

  @override
  State<AsdCategoryDocumentsScreen> createState() => _AsdCategoryDocumentsScreenState();
}

class _AsdCategoryDocumentsScreenState extends State<AsdCategoryDocumentsScreen> {
  final _documentsService = AsdDocumentsService.instance;

  bool _isLoading = true;
  String? _loadError;
  List<AsdDocument> _documents = [];
  List<AsdDocumentCategory> _allCategories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final documents = await _documentsService.getDocumentsByCategory(widget.category.key);
      final categories = await _documentsService.getCategories();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _allCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDriveUploaded(AsdDocument document) async {
    try {
      await _documentsService.setDriveUploaded(document.id, !document.driveUploaded);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _confirmDelete(AsdDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questo documento?'),
        content: Text('Eliminare "${document.title}"? Non si può annullare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _documentsService.deleteDocument(document);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
      );
    }
  }

  Future<void> _editDocument(AsdDocument document) async {
    final titleController = TextEditingController(text: document.title);
    final subjectController = TextEditingController(text: document.subject ?? '');
    var selectedCategory = document.category;
    var selectedDate = document.docDate;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifica dati'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: _allCategories
                        .map((c) => DropdownMenuItem(value: c.key, child: Text(c.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Persona o ente (facoltativo)'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data documento'),
                    subtitle: Text(DateFormat('dd/MM/yyyy', 'it_IT').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(DateTime.now().year - 20),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _documentsService.updateDocument(
        document.id,
        title: titleController.text.trim(),
        category: selectedCategory,
        subject: subjectController.text.trim(),
        docDate: selectedDate,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  List<Widget> _buildDocumentsByYear() {
    final byYear = <int, List<AsdDocument>>{};
    for (final document in _documents) {
      byYear.putIfAbsent(document.docDate.year, () => []).add(document);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    final widgets = <Widget>[];
    for (final year in years) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text('$year', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
      for (final document in byYear[year]!) {
        widgets.add(
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              leading: IconButton(
                icon: Icon(
                  document.driveUploaded ? Icons.cloud_done : Icons.cloud_upload_outlined,
                  color: document.driveUploaded ? Colors.green : Colors.orange,
                ),
                tooltip: document.driveUploaded ? 'Su Drive' : 'Da caricare sul Drive',
                onPressed: () => _toggleDriveUploaded(document),
              ),
              title: Text(document.title),
              subtitle: Text(
                [
                  if (document.subject != null && document.subject!.isNotEmpty) document.subject!,
                  dayFormat.format(document.docDate),
                ].join(' · '),
              ),
              onTap: () => openAsdDocument(context, document),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _editDocument(document);
                  if (value == 'delete') _confirmDelete(document);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifica dati')),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.label)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Riprova')),
                      ],
                    ),
                  ),
                )
              : _documents.isEmpty
                  ? const Center(child: Text('Nessun documento in questa categoria.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          MediaQuery.of(context).viewPadding.bottom + 24,
                        ),
                        children: _buildDocumentsByYear(),
                      ),
                    ),
    );
  }
}
