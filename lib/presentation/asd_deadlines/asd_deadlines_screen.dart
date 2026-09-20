import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/asd_deadlines_service.dart';
import '../../services/asd_governance_service.dart';
import './widgets/asd_board_members_sheet.dart';
import './widgets/asd_deadline_detail_sheet.dart';
import './widgets/asd_deadline_form_screen.dart';
import './widgets/asd_deadline_guide_sheet.dart';
import './widgets/asd_inactive_deadlines_screen.dart';

/// Scadenzario ASD: status banner + "Da fare" / "Certificati medici" /
/// "Completate" / "Non attive" groups. No deadline text or guide content is
/// hardcoded here — everything comes from asd_deadlines/asd_deadline_completions
/// (AsdDeadlinesService) and, read-only, the existing medical-certificate
/// columns. Purely additive and admin-only: nothing here touches payments,
/// bookings, subscriptions, receipts, the Registro di Cassa, or any
/// student-facing screen.
class AsdDeadlinesScreen extends StatefulWidget {
  const AsdDeadlinesScreen({Key? key}) : super(key: key);

  @override
  State<AsdDeadlinesScreen> createState() => _AsdDeadlinesScreenState();
}

class _AsdDeadlinesScreenState extends State<AsdDeadlinesScreen> {
  final _service = AsdDeadlinesService.instance;
  final _governanceService = AsdGovernanceService.instance;

  bool _isCheckingAccess = true;
  bool _canAccess = false;

  bool _isLoading = true;
  String? _loadError;
  AsdDeadlineSummary? _summary;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    try {
      canAccess =
          await AdminSectionVisibilityService.instance.canAccess('deadlines');
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
      final summary = await _service.getSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento dello scadenzario: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddDeadline() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AsdDeadlineFormScreen()),
    );
    if (saved == true) await _load();
  }

  Future<void> _openEditDeadline(AsdDeadline deadline) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AsdDeadlineFormScreen(deadline: deadline),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openBoardMembers() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AsdBoardMembersSheet(),
    );
  }

  Future<void> _openGuide(AsdDeadline deadline) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AsdDeadlineGuideSheet(deadline: deadline),
    );
  }

  Future<void> _openDetail(AsdDeadlineOccurrence occurrence) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AsdDeadlineDetailSheet(occurrence: occurrence),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'done':
        await _completeOccurrence(occurrence);
        break;
      case 'skip':
        await _skipOccurrence(occurrence);
        break;
      case 'edit':
        await _openEditDeadline(occurrence.deadline);
        break;
      case 'open_drive':
        await _openDriveForDeadline(occurrence.deadline);
        break;
      case 'delete':
        await _confirmDeleteDeadline(occurrence.deadline);
        break;
    }
  }

  /// Opens the deadline's own drive_url when set, otherwise falls back to
  /// the general asd_settings.drive_folder_url — same fallback used by the
  /// guide sheet and the post-generation reminder.
  Future<void> _openDriveForDeadline(AsdDeadline deadline) async {
    var url = deadline.driveUrl;
    if (url == null || url.isEmpty) {
      try {
        url = await _governanceService.getDriveFolderUrl();
      } catch (_) {
        url = null;
      }
    }
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun link della cartella Drive configurato.')),
      );
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il link: $e')),
      );
    }
  }

  Future<void> _completeOccurrence(AsdDeadlineOccurrence occurrence) async {
    try {
      await _service.completeOccurrence(
        deadlineId: occurrence.deadline.id,
        dueDate: occurrence.dueDate,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fatto'),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () async {
              final summary = _summary;
              if (summary == null) return;
              AsdDeadlineCompletion? completion;
              for (final c in summary.recentCompletions) {
                if (c.deadlineId == occurrence.deadline.id &&
                    c.dueDate == occurrence.dueDate) {
                  completion = c;
                  break;
                }
              }
              if (completion == null) return;
              await _service.undoCompletion(completion.id);
              await _load();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _skipOccurrence(AsdDeadlineOccurrence occurrence) async {
    try {
      await _service.completeOccurrence(
        deadlineId: occurrence.deadline.id,
        dueDate: occurrence.dueDate,
        note: 'Saltata',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _undoCompletion(AsdDeadlineCompletion completion) async {
    try {
      await _service.undoCompletion(completion.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _confirmDeleteDeadline(AsdDeadline deadline) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa scadenza?'),
        content: Text(
          'Eliminare "${deadline.title}" dallo scadenzario? Non si può annullare.',
        ),
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
      await _service.deleteDeadline(deadline.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
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
        appBar: AppBar(title: const Text('Scadenzario ASD')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Non hai accesso allo Scadenzario ASD.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scadenzario ASD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Consiglio direttivo',
            onPressed: _openBoardMembers,
          ),
        ],
      ),
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
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.all(4.w),
                    children: _buildBody(),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDeadline,
        tooltip: 'Aggiungi scadenza',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildBody() {
    final summary = _summary;
    if (summary == null) return const [];

    final widgets = <Widget>[
      _buildStatusBanner(summary),
      SizedBox(height: 2.h),
    ];

    widgets.addAll(_buildDueSection(summary));

    if (summary.medicalReport != null) {
      widgets.add(SizedBox(height: 2.h));
      widgets.addAll(_buildMedicalSection(summary.medicalReport!));
    }

    widgets.add(SizedBox(height: 2.h));
    widgets.addAll(_buildCompletedSection(summary));

    if (summary.inactiveDeadlines.isNotEmpty) {
      widgets.add(SizedBox(height: 2.h));
      widgets.add(_buildInactiveSummaryRow(summary.inactiveDeadlines.length));
    }

    widgets.add(SizedBox(height: 10.h));
    return widgets;
  }

  Widget _buildStatusBanner(AsdDeadlineSummary summary) {
    late Color color;
    late IconData icon;
    late String text;

    if (summary.overdueCount > 0) {
      color = Colors.red;
      icon = Icons.error_outline;
      text = '${summary.overdueCount} scadute';
    } else if (summary.dueSoonCount > 0) {
      color = Colors.orange;
      icon = Icons.warning_amber_outlined;
      text = '${summary.dueSoonCount} scadenze da fare';
    } else {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      text = 'Tutto in regola: nessuna scadenza in arrivo';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: EdgeInsets.only(bottom: 1.h),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      );

  List<Widget> _buildDueSection(AsdDeadlineSummary summary) {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return [
      _sectionHeader('Da fare'),
      if (summary.dueOccurrences.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Nessuna scadenza in elenco.'),
        )
      else
        ...summary.dueOccurrences.map((occurrence) {
          final color = switch (occurrence.urgency) {
            AsdDeadlineUrgency.overdue => Colors.red,
            AsdDeadlineUrgency.dueSoon => Colors.orange,
            AsdDeadlineUrgency.normal => null,
          };
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              leading: Checkbox(
                value: false,
                onChanged: (_) => _completeOccurrence(occurrence),
              ),
              title: Text(
                occurrence.deadline.title,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${dayFormat.format(occurrence.dueDate)} · ${asdCategoryLabel(occurrence.deadline.category)}',
                      style: TextStyle(color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (occurrence.deadline.needsConfirmation) ...[
                    SizedBox(width: 2.w),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Da confermare',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Come si fa',
                onPressed: () => _openGuide(occurrence.deadline),
              ),
              onTap: () => _openDetail(occurrence),
              onLongPress: () => _confirmDeleteDeadline(occurrence.deadline),
            ),
          );
        }),
    ];
  }

  List<Widget> _buildMedicalSection(AsdMedicalCertificateReport report) {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return [
      _sectionHeader('Certificati medici'),
      if (report.alerts.isEmpty && report.missingCount == 0)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Nessun certificato scaduto o in scadenza.'),
        )
      else ...[
        ...report.alerts.map((alert) {
          final color = alert.isOverdue ? Colors.red : Colors.orange;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              leading: Icon(Icons.medical_information_outlined, color: color),
              title: Text(alert.name, style: TextStyle(color: color)),
              subtitle: Text(
                dayFormat.format(alert.expiry),
                style: TextStyle(color: color),
              ),
            ),
          );
        }),
        if (report.missingCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('${report.missingCount} allievi senza data del certificato'),
          ),
      ],
    ];
  }

  List<Widget> _buildCompletedSection(AsdDeadlineSummary summary) {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return [
      _sectionHeader('Completate'),
      if (summary.recentCompletions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Nessuna scadenza completata.'),
        )
      else
        ...summary.recentCompletions.map((completion) {
          final title = summary.titlesByDeadlineId[completion.deadlineId] ??
              completion.deadlineId;
          final subtitle = completion.isSkipped
              ? 'Saltata il ${dayFormat.format(completion.completedAt)}'
              : 'Fatto da ${completion.completedByName ?? 'un admin'} il ${dayFormat.format(completion.completedAt)}';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              leading: Icon(
                completion.isSkipped
                    ? Icons.skip_next_outlined
                    : Icons.check_box_outlined,
                color: completion.isSkipped ? Colors.grey : Colors.green,
              ),
              title: Text(title),
              subtitle: Text(subtitle),
              onTap: () => _undoCompletion(completion),
            ),
          );
        }),
    ];
  }

  Widget _buildInactiveSummaryRow(int count) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        title: Text(
          'Non attive ($count)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _openInactiveDeadlines,
      ),
    );
  }

  Future<void> _openInactiveDeadlines() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AsdInactiveDeadlinesScreen()),
    );
    await _load();
  }
}
