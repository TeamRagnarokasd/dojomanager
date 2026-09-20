import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/asd_deadlines_service.dart';

/// "Come si fa" bottom sheet for one deadline: how_to (one step per line),
/// notes, condition_note, and legal references (+ guide_url) opened in the
/// external browser. No guide text is hardcoded — how_to/notes/legal_refs
/// all come from the deadline row itself. "Genera bozza" and "Apri la
/// cartella Drive" live on the full "Scadenza" page now, not here.
class AsdDeadlineGuideSheet extends StatelessWidget {
  const AsdDeadlineGuideSheet({Key? key, required this.deadline}) : super(key: key);

  final AsdDeadline deadline;

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final howToSteps = (deadline.howTo ?? '')
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final hasLegalRefs = deadline.legalRefs.isNotEmpty ||
        (deadline.guideUrl != null && deadline.guideUrl!.isNotEmpty);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              deadline.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 16),
            if (howToSteps.isNotEmpty) ...[
              const Text('Come si fa', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...howToSteps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(step),
                    ),
                  ),
              const SizedBox(height: 12),
            ],
            if (deadline.notes != null && deadline.notes!.trim().isNotEmpty) ...[
              const Text('Note', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(deadline.notes!),
              const SizedBox(height: 12),
            ],
            if (deadline.conditionNote != null &&
                deadline.conditionNote!.trim().isNotEmpty) ...[
              const Text('Quando si applica', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(deadline.conditionNote!, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
            ],
            if (hasLegalRefs) ...[
              const Text(
                'Riferimenti e approfondimenti',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ...deadline.legalRefs.map(
                (ref) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: Text(ref.label),
                  onTap: () => _openUrl(context, ref.url),
                ),
              ),
              if (deadline.guideUrl != null && deadline.guideUrl!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: const Text('Guida'),
                  onTap: () => _openUrl(context, deadline.guideUrl!),
                ),
            ],
          ],
        );
      },
    );
  }
}
