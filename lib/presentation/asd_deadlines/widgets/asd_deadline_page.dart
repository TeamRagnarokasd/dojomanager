import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/asd_deadlines_service.dart';
import '../../../services/asd_documents_service.dart';
import '../../../services/asd_governance_service.dart';
import '../document_generation/asd_document_generation_screen.dart';
import 'asd_deadline_guide_sheet.dart';

/// Full-screen "Scadenza" page: everything about one "Da fare" occurrence —
/// status, notes, actions, the deadline's document templates ("Genera
/// bozza"), and its previous documents grouped by year, with their Drive
/// status. Opened by tapping a row in the "Da fare" list; "Segna come
/// fatta"/"Salta" pop back with an action string the list screen acts on
/// (same convention as the old detail sheet, now the three-dot menu).
class AsdDeadlinePage extends StatefulWidget {
  const AsdDeadlinePage({Key? key, required this.occurrence}) : super(key: key);

  final AsdDeadlineOccurrence occurrence;

  @override
  State<AsdDeadlinePage> createState() => _AsdDeadlinePageState();
}

class _AsdDeadlinePageState extends State<AsdDeadlinePage> {
  final _governanceService = AsdGovernanceService.instance;
  final _documentsService = AsdDocumentsService.instance;

  bool _isLoading = true;
  List<AsdDocumentTemplate> _templates = [];
  List<AsdDocument> _documents = [];
  String? _driveUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final deadline = widget.occurrence.deadline;
    try {
      final templates = await _governanceService.getTemplatesByKeys(deadline.documentTemplates);
      final documents = await _documentsService.getDocumentsForDeadline(deadline.id);
      var driveUrl = deadline.driveUrl;
      if (driveUrl == null || driveUrl.isEmpty) {
        try {
          driveUrl = await _governanceService.getDriveFolderUrl();
        } catch (_) {
          driveUrl = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _documents = documents;
        _driveUrl = driveUrl;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AsdDeadlineGuideSheet(deadline: widget.occurrence.deadline),
    );
  }

  void _markDone() => Navigator.pop(context, 'done');

  void _skip() => Navigator.pop(context, 'skip');

  Future<void> _generateDraft(AsdDocumentTemplate template) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AsdDocumentGenerationScreen(
          template: template,
          sourceDeadline: widget.occurrence.deadline,
          dueDate: widget.occurrence.dueDate,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il link: $e')),
      );
    }
  }

  Future<void> _openDriveFolder() async {
    final url = _driveUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun link della cartella Drive configurato.')),
      );
      return;
    }
    await _openUrl(url);
  }

  Future<void> _openDocument(AsdDocument document) async {
    try {
      final bytes = await _documentsService.downloadBytes(document.storagePath);
      if (!mounted) return;
      if (document.isPdf) {
        final name = document.fileName ?? '${document.title}.pdf';
        if (kIsWeb) {
          await Printing.layoutPdf(onLayout: (format) async => bytes, name: name);
        } else {
          await Printing.sharePdf(bytes: bytes, filename: name);
        }
      } else if (document.isImage) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _AsdDocumentImageViewer(bytes: bytes, title: document.title),
          ),
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${document.fileName ?? document.title}');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il documento: $e')),
      );
    }
  }

  Future<void> _toggleDriveUploaded(AsdDocument document) async {
    try {
      await _documentsService.setDriveUploaded(document.id, !document.driveUploaded);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _confirmDeleteDocument(AsdDocument document) async {
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
              onTap: () => _openDocument(document),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _confirmDeleteDocument(document);
                },
                itemBuilder: (context) => const [
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
    final occurrence = widget.occurrence;
    final deadline = occurrence.deadline;
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    final color = switch (occurrence.urgency) {
      AsdDeadlineUrgency.overdue => Colors.red,
      AsdDeadlineUrgency.dueSoon => Colors.orange,
      AsdDeadlineUrgency.normal => null,
    };
    final statusText = switch (occurrence.urgency) {
      AsdDeadlineUrgency.overdue => 'Scaduta',
      AsdDeadlineUrgency.dueSoon => 'Da fare a breve',
      AsdDeadlineUrgency.normal => 'Da fare',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Scadenza')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewPadding.bottom + 24),
        children: [
          Text(
            deadline.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${dayFormat.format(occurrence.dueDate)} · $statusText',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text('·  ${asdCategoryLabel(deadline.category)}'),
              if (deadline.needsConfirmation)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Da confermare', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          if (deadline.notes != null && deadline.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Note', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(deadline.notes!),
          ],
          if (deadline.conditionNote != null && deadline.conditionNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Quando si applica', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(deadline.conditionNote!, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openGuide,
                icon: const Icon(Icons.help_outline),
                label: const Text('Come si fa'),
              ),
              OutlinedButton.icon(
                onPressed: _markDone,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Segna come fatta'),
              ),
              OutlinedButton.icon(
                onPressed: _skip,
                icon: const Icon(Icons.skip_next_outlined),
                label: const Text('Salta questa scadenza'),
              ),
            ],
          ),
          if (_templates.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Documenti da generare', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._templates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _generateDraft(template),
                  icon: const Icon(Icons.description_outlined),
                  label: Text('Genera bozza: ${template.title}'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Documenti precedenti', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_documents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nessun documento precedente.'),
            )
          else
            ..._buildDocumentsByYear(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openDriveFolder,
              icon: const Icon(Icons.folder_shared_outlined),
              label: const Text('Apri la cartella Drive'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal full-screen image viewer for an uploaded/generated document,
/// zoomable with InteractiveViewer.
class _AsdDocumentImageViewer extends StatelessWidget {
  const _AsdDocumentImageViewer({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}
