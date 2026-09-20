import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/asd_documents_service.dart';

/// Downloads [document] from the bucket and opens it the way its type
/// calls for: a PDF goes to Printing (share on mobile, print layout on
/// web), an image opens full-screen with pinch-to-zoom, anything else is
/// handed to the native share sheet (not available on web). Shared by the
/// archive's search results, its category lists, and the Scadenzario's
/// "Documenti precedenti".
Future<void> openAsdDocument(BuildContext context, AsdDocument document) async {
  final documentsService = AsdDocumentsService.instance;
  try {
    final bytes = await documentsService.downloadBytes(document.storagePath);
    if (!context.mounted) return;
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
          builder: (context) => AsdDocumentImageViewer(bytes: bytes, title: document.title),
        ),
      );
    } else if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apertura non disponibile sul web per questo tipo di file.')),
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${document.fileName ?? document.title}');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Impossibile aprire il documento: $e')),
    );
  }
}

/// Full-screen, zoomable viewer for an image document.
class AsdDocumentImageViewer extends StatelessWidget {
  const AsdDocumentImageViewer({Key? key, required this.bytes, required this.title})
      : super(key: key);

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
