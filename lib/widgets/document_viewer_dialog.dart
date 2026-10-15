import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] the right way for the current platform.
///
/// On Android/iOS this is just the usual `launchUrl` call, unchanged.
///
/// On web, calling `launchUrl` right after an `await` (e.g. the Supabase
/// Storage call that creates the signed URL) is routinely blocked by
/// Safari and mobile Chrome's popup blocker, silently — the await breaks
/// the browser's link between the user's tap and the new-tab request, so
/// nothing visibly happens. Showing a dialog instead, with an image
/// preview when the file is one, and letting the dialog's own button call
/// `launchUrl` directly from its `onPressed` (a fresh user gesture the
/// browser always allows) works around that reliably.
Future<void> openDocumentUrl(
  BuildContext context,
  String url, {
  String title = 'Documento pronto',
}) async {
  if (!kIsWeb) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  if (!context.mounted) return;

  final lowerUrl = url.toLowerCase();
  final isImage = ['.jpg', '.jpeg', '.png', '.webp'].any(
    (ext) => lowerUrl.contains(ext),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: isImage
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'Anteprima non disponibile.',
                ),
              ),
            )
          : const Text(
              'Il file è pronto. Usa il pulsante sotto per aprirlo a schermo intero.',
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Chiudi'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            Navigator.of(dialogContext).pop();
          },
          icon: const Icon(Icons.open_in_full),
          label: const Text('Apri a schermo intero'),
        ),
      ],
    ),
  );
}
