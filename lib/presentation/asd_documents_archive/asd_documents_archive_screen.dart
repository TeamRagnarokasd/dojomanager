import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/asd_documents_service.dart';
import 'widgets/asd_add_document_screen.dart';
import 'widgets/asd_category_documents_screen.dart';
import 'widgets/asd_document_actions.dart';

/// "Archivio documenti": search across every asd_documents row, or browse
/// by category (asd_document_categories) with a document count per
/// category. No document text is hardcoded — everything comes from the
/// database. Purely additive and admin-only: nothing here touches
/// payments, bookings, subscriptions, receipts, the Registro di Cassa, or
/// any student-facing screen.
class AsdDocumentsArchiveScreen extends StatefulWidget {
  const AsdDocumentsArchiveScreen({Key? key}) : super(key: key);

  @override
  State<AsdDocumentsArchiveScreen> createState() => _AsdDocumentsArchiveScreenState();
}

class _AsdDocumentsArchiveScreenState extends State<AsdDocumentsArchiveScreen> {
  final _documentsService = AsdDocumentsService.instance;
  final _searchController = TextEditingController();

  bool _isCheckingAccess = true;
  bool _canAccess = false;

  bool _isLoading = true;
  String? _loadError;
  List<AsdDocumentCategory> _categories = [];
  Map<String, int> _categoryCounts = {};

  bool _isSearching = false;
  List<AsdDocument>? _searchResults;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    try {
      canAccess = await AdminSectionVisibilityService.instance.canAccess('documents_archive');
    } catch (_) {
      canAccess = false;
    }
    if (!mounted) return;
    setState(() {
      _canAccess = canAccess;
      _isCheckingAccess = false;
    });
    if (canAccess) await _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final categories = await _documentsService.getCategories();
      final counts = await _documentsService.getCategoryCounts();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryCounts = counts;
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

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = null;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _documentsService.searchDocuments(trimmed);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nella ricerca: $e')),
      );
    }
  }

  Future<void> _openCategory(AsdDocumentCategory category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AsdCategoryDocumentsScreen(category: category)),
    );
    await _load();
  }

  Future<void> _openAddDocument() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AsdAddDocumentScreen()),
    );
    if (saved == true) await _load();
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova categoria'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    if (added != true || controller.text.trim().isEmpty) return;
    try {
      await _documentsService.addCategory(controller.text.trim());
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _confirmDeleteCategory(AsdDocumentCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa categoria?'),
        content: Text('Eliminare "${category.label}"?'),
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
      await _documentsService.deleteCategory(category.key);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Archivio documenti')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Non hai accesso all\'archivio documenti.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivio documenti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Nuova categoria',
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Cerca per titolo o persona/ente',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
            SizedBox(height: 2.h),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _isLoading
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
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewPadding.bottom + 24,
                                ),
                                children: _categories.map(_buildCategoryTile).toList(),
                              ),
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDocument,
        tooltip: 'Aggiungi documento',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryTile(AsdDocumentCategory category) {
    final count = _categoryCounts[category.key] ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: const Icon(Icons.folder_outlined),
        title: Text(category.label),
        subtitle: Text('$count documenti'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_forward_ios, size: 16),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Elimina categoria',
              onPressed: () => _confirmDeleteCategory(category),
            ),
          ],
        ),
        onTap: () => _openCategory(category),
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _searchResults;
    if (results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return const Center(child: Text('Nessun documento trovato.'));
    }
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom + 24),
      children: results.map((document) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            title: Text(document.title),
            subtitle: Text(
              [
                if (document.subject != null && document.subject!.isNotEmpty) document.subject!,
                dayFormat.format(document.docDate),
              ].join(' · '),
            ),
            onTap: () => openAsdDocument(context, document),
          ),
        );
      }).toList(),
    );
  }
}
