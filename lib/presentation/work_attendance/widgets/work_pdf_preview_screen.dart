import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Preview for one of the "prospetti PDF" (compensi/buoni pasto/rimborso
/// km), built ahead of time by work_pdfs.dart. Stampa/Condividi are
/// PdfPreview's own built-in actions (package printing); "Salva
/// nell'Archivio" is a separate button here, shown only when
/// [onSaveToArchive] is given (principal admin only — see
/// work_attendance_screen.dart, which decides that and does the actual
/// upload via AsdDocumentsService).
class WorkPdfPreviewScreen extends StatefulWidget {
  const WorkPdfPreviewScreen({
    Key? key,
    required this.title,
    required this.bytes,
    required this.fileName,
    this.onSaveToArchive,
  }) : super(key: key);

  final String title;
  final Uint8List bytes;
  final String fileName;
  final Future<void> Function()? onSaveToArchive;

  @override
  State<WorkPdfPreviewScreen> createState() => _WorkPdfPreviewScreenState();
}

class _WorkPdfPreviewScreenState extends State<WorkPdfPreviewScreen> {
  bool _isSaving = false;

  Future<void> _save() async {
    final callback = widget.onSaveToArchive;
    if (callback == null) return;
    setState(() => _isSaving = true);
    try {
      await callback();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvato nell\'Archivio documenti.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PdfPreview(
        build: (format) async => widget.bytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: widget.fileName,
      ),
      bottomNavigationBar: widget.onSaveToArchive == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.archive_outlined),
                  label: const Text('Salva nell\'Archivio'),
                ),
              ),
            ),
    );
  }
}
