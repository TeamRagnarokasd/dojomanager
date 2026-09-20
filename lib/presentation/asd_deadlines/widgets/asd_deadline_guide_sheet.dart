import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/asd_deadlines_service.dart';
import '../../../services/asd_governance_service.dart';
import '../document_generation/asd_document_generation_screen.dart';

/// "Come si fa" bottom sheet for one deadline: how_to (one step per line),
/// notes, condition_note, legal references (+ guide_url) opened in the
/// external browser, "Genera bozza: <titolo>" per document template, and
/// "Apri la cartella Drive". No guide text is hardcoded — how_to/notes/
/// legal_refs/document_templates all come from the deadline row itself;
/// only the template titles and the Drive link are fetched here.
class AsdDeadlineGuideSheet extends StatefulWidget {
  const AsdDeadlineGuideSheet({Key? key, required this.deadline}) : super(key: key);

  final AsdDeadline deadline;

  @override
  State<AsdDeadlineGuideSheet> createState() => _AsdDeadlineGuideSheetState();
}

class _AsdDeadlineGuideSheetState extends State<AsdDeadlineGuideSheet> {
  final _governanceService = AsdGovernanceService.instance;

  bool _isLoading = true;
  List<AsdDocumentTemplate> _templates = [];
  String? _driveUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final templates = await _governanceService.getTemplatesByKeys(
        widget.deadline.documentTemplates,
      );
      var driveUrl = widget.deadline.driveUrl;
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
        _driveUrl = driveUrl;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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

  void _generateDraft(AsdDocumentTemplate template) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AsdDocumentGenerationScreen(
          template: template,
          sourceDeadline: widget.deadline,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
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
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
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
              ...howToSteps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
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
                  onTap: () => _openUrl(ref.url),
                ),
              ),
              if (deadline.guideUrl != null && deadline.guideUrl!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.link, size: 18),
                  title: const Text('Guida'),
                  onTap: () => _openUrl(deadline.guideUrl!),
                ),
              const SizedBox(height: 12),
            ],
            if (_templates.isNotEmpty) ...[
              const Divider(),
              ..._templates.map(
                (template) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: OutlinedButton.icon(
                    onPressed: () => _generateDraft(template),
                    icon: const Icon(Icons.description_outlined),
                    label: Text('Genera bozza: ${template.title}'),
                  ),
                ),
              ),
            ],
            if (_driveUrl != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl(_driveUrl!),
                  icon: const Icon(Icons.folder_shared_outlined),
                  label: const Text('Apri la cartella Drive'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
