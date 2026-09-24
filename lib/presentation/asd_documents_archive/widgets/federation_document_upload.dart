import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/asd_documents_service.dart';
import '../../../services/federation_membership_service.dart';

/// Shared upload flow for the two federation-affiliation document types
/// ("Certificato di affiliazione" and "Elenco tesserati (Excel)"), used both
/// from a deadline's required-documents panel and from the "+" button in
/// the "Affiliazioni e tesseramenti" archive folder — same save, same Drive
/// reminder, same roster sync.

/// "Che documento carichi?" — returns 'certificate' | 'roster' | 'other', or
/// null if dismissed.
Future<String?> pickFederationDocumentKind(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Che documento carichi?'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'certificate'),
          child: const Text(kFederationCertificateLabel),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'roster'),
          child: const Text(kFederationRosterLabel),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'other'),
          child: const Text('Altro documento'),
        ),
      ],
    ),
  );
}

/// "Per quale federazione?" — returns a federation key, or null if dismissed.
Future<String?> pickFederation(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Per quale federazione?'),
      children: kFederationFullLabels.entries
          .map(
            (entry) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value),
            ),
          )
          .toList(),
    ),
  );
}

void _showDriveReminder(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Ricorda di caricare una copia anche su Google Drive.'),
    ),
  );
}

/// Picks a pdf/image file and uploads it as "Certificato di affiliazione"
/// for [federation]. Returns true if a document was saved.
Future<bool> uploadFederationCertificate(
  BuildContext context, {
  required String category,
  required String federation,
  String? deadlineId,
}) async {
  final documentsService = AsdDocumentsService.instance;
  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
      withData: true,
    );
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    return false;
  }
  if (result == null || result.files.isEmpty) return false;
  final file = result.files.first;
  final bytes = file.bytes;
  if (bytes == null) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile leggere il file selezionato.')),
    );
    return false;
  }

  try {
    final sanitizedName = documentsService.sanitizeFileName(file.name);
    final storagePath = documentsService.archiveStoragePath(
      category: category,
      fileName: documentsService.timestampedFileName(sanitizedName),
    );
    await documentsService.uploadBytes(
      storagePath,
      bytes,
      contentType: _guessMimeType(file.name) ?? 'application/octet-stream',
    );
    await documentsService.createDocument(
      deadlineId: deadlineId,
      title: '$kFederationCertificateLabel — ${federationFullLabel(federation)}',
      storagePath: storagePath,
      category: category,
      subject: kFederationCertificateLabel,
      docDate: DateTime.now(),
      source: kAsdDocumentSourceUploaded,
      fileName: sanitizedName,
      mimeType: _guessMimeType(file.name),
      federation: federation,
    );
    if (!context.mounted) return true;
    _showDriveReminder(context);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore durante il salvataggio: $e')),
    );
    return false;
  }
}

/// Picks an .xlsx/.xls roster export, uploads it as "Elenco tesserati
/// (Excel)" for [federation], then parses it and syncs
/// `user_federation_memberships` via `admin_sync_federation_roster`. The
/// document is saved even if the roster columns can't be found or the sync
/// itself fails — only the sync step is skipped. Returns true if a document
/// was saved.
Future<bool> uploadFederationRosterExcel(
  BuildContext context, {
  required String category,
  required String federation,
  String? deadlineId,
}) async {
  final documentsService = AsdDocumentsService.instance;
  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    return false;
  }
  if (result == null || result.files.isEmpty) return false;
  final file = result.files.first;
  final bytes = file.bytes;
  final lowerName = file.name.toLowerCase();
  if (bytes == null) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossibile leggere il file selezionato.')),
    );
    return false;
  }
  if (!lowerName.endsWith('.xlsx') && !lowerName.endsWith('.xls')) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seleziona un file Excel (.xlsx o .xls).')),
    );
    return false;
  }

  String storagePath;
  try {
    final sanitizedName = documentsService.sanitizeFileName(file.name);
    storagePath = documentsService.archiveStoragePath(
      category: category,
      fileName: documentsService.timestampedFileName(sanitizedName),
    );
    await documentsService.uploadBytes(
      storagePath,
      bytes,
      contentType: _guessMimeType(file.name) ?? 'application/octet-stream',
    );
    final document = await documentsService.createDocument(
      deadlineId: deadlineId,
      title: '$kFederationRosterLabel — ${federationFullLabel(federation)}',
      storagePath: storagePath,
      category: category,
      subject: kFederationRosterLabel,
      docDate: DateTime.now(),
      source: kAsdDocumentSourceUploaded,
      fileName: sanitizedName,
      mimeType: _guessMimeType(file.name),
      federation: federation,
    );

    List<Map<String, String>> rows;
    try {
      rows = parseFederationRosterExcel(bytes);
    } on FederationRosterInvalidFormatException {
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Il file non sembra un vero file Excel (.xlsx). Se lo hai scaricato da un sito, '
            'aprilo con Excel o Google Sheets e salvalo di nuovo come .xlsx, poi ricaricalo qui.',
          ),
        ),
      );
      return true;
    } on FederationRosterColumnsNotFoundException {
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Il file deve contenere le colonne 'Codice Fiscale' e il numero di tessera (es. 'Cod.Tessera').",
          ),
        ),
      );
      return true;
    }

    try {
      final syncResult = await FederationMembershipService.instance.syncRoster(
        federation: federation,
        rows: rows,
        documentId: document.id,
      );
      if (!context.mounted) return true;
      await _showSyncResultDialog(context, syncResult);
      if (!context.mounted) return true;
      _showDriveReminder(context);
    } catch (e) {
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la sincronizzazione: $e')),
      );
    }
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Errore durante il salvataggio: $e')),
    );
    return false;
  }
}

Future<void> _showSyncResultDialog(
  BuildContext context,
  FederationRosterSyncResult result,
) async {
  final notFound = result.notFound;
  final shown = notFound.take(15).toList();
  final remaining = notFound.length - shown.length;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sincronizzazione completata'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aggiornati ${result.matched} tesserati.'),
            if (notFound.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${notFound.length} codici fiscali non trovati:'),
              const SizedBox(height: 4),
              Text(shown.join(', ')),
              if (remaining > 0) Text('e altri $remaining'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    ),
  );
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
    case 'heif':
      return 'image/heic';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'xls':
      return 'application/vnd.ms-excel';
    default:
      return null;
  }
}
