import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/asd_deadlines_service.dart';
import './widgets/asd_board_members_sheet.dart';
import './widgets/asd_deadline_detail_sheet.dart';
import './widgets/asd_deadline_form_screen.dart';
import './widgets/asd_deadline_guide_sheet.dart';
import './widgets/asd_deadline_page.dart';
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

  bool _isCheckingAccess = true;
  bool _canAccess = false;

  bool _isLoading = true;
  String? _loadError;
  AsdDeadlineSummary? _summary;

  /// Occurrences the checkbox has selected for a bulk "Segna come fatte",
  /// keyed by [_occurrenceKey] — purely local UI state, nothing is written
  /// to the database until "Conferma" is tapped.
  final Map<String, AsdDeadlineOccurrence> _selectedOccurrences = {};

  String _occurrenceKey(AsdDeadlineOccurrence occurrence) =>
      '${occurrence.deadline.id}_${occurrence.dueDate.toIso8601String()}';

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
      final validKeys = summary.dueOccurrences.map(_occurrenceKey).toSet();
      setState(() {
        _summary = summary;
        _selectedOccurrences.removeWhere((key, _) => !validKeys.contains(key));
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
      useSafeArea: true,
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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AsdDeadlineGuideSheet(deadline: deadline),
    );
  }

  /// Row tap: the full "Scadenza" page. "Segna come fatta"/"Salta" pop back
  /// with the same action-string convention the old detail sheet used.
  Future<void> _openDeadlinePage(AsdDeadlineOccurrence occurrence) async {
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => AsdDeadlinePage(occurrence: occurrence)),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'done':
        await _completeOccurrence(occurrence);
        break;
      case 'skip':
        await _skipOccurrence(occurrence);
        break;
    }
  }

  /// Three-dot menu: Segna come fatta / Salta / Modifica / Elimina.
  Future<void> _openActionsMenu(AsdDeadlineOccurrence occurrence) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
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
      case 'delete':
        await _confirmDeleteDeadline(occurrence.deadline);
        break;
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

  /// The checkbox only orders the local selection — no database write
  /// happens until "Conferma" on the bottom bar.
  void _toggleSelection(AsdDeadlineOccurrence occurrence) {
    final key = _occurrenceKey(occurrence);
    setState(() {
      if (_selectedOccurrences.containsKey(key)) {
        _selectedOccurrences.remove(key);
      } else {
        _selectedOccurrences[key] = occurrence;
      }
    });
  }

  Future<void> _confirmSelectedDone() async {
    final occurrences = _selectedOccurrences.values.toList();
    if (occurrences.isEmpty) return;
    try {
      for (final occurrence in occurrences) {
        await _service.completeOccurrence(
          deadlineId: occurrence.deadline.id,
          dueDate: occurrence.dueDate,
        );
      }
      setState(() => _selectedOccurrences.clear());
      await _load();
      if (!mounted) return;
      final count = occurrences.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? '1 scadenza segnata come fatta'
                : '$count scadenze segnate come fatte',
          ),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () async {
              final summary = _summary;
              if (summary == null) return;
              for (final occurrence in occurrences) {
                AsdDeadlineCompletion? completion;
                for (final c in summary.recentCompletions) {
                  if (c.deadlineId == occurrence.deadline.id &&
                      c.dueDate == occurrence.dueDate) {
                    completion = c;
                    break;
                  }
                }
                if (completion != null) {
                  await _service.undoCompletion(completion.id);
                }
              }
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

  Future<void> _confirmUndoCompletion(AsdDeadlineCompletion completion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Riportare in Da fare?'),
        content: const Text(
          'Il completamento verrà annullato e la scadenza tornerà tra quelle da fare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Riporta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _undoCompletion(completion);
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
                    padding: EdgeInsets.fromLTRB(
                      4.w,
                      4.w,
                      4.w,
                      MediaQuery.of(context).viewPadding.bottom + 88,
                    ),
                    children: _buildBody(),
                  ),
                ),
      bottomNavigationBar: _selectedOccurrences.isEmpty ? null : _buildSelectionBar(),
      floatingActionButton: _selectedOccurrences.isEmpty
          ? FloatingActionButton(
              onPressed: _openAddDeadline,
              tooltip: 'Aggiungi scadenza',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Fixed bar, above the FAB's spot, shown while at least one occurrence
  /// is selected. Wrapped in SafeArea so it never sits under Android's
  /// nav bar, and never covers the list itself — Scaffold reserves its
  /// height above bottomNavigationBar automatically.
  Widget _buildSelectionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _confirmSelectedDone,
                child: Text(
                  _selectedOccurrences.length == 1
                      ? 'Conferma 1 scadenza fatta'
                      : 'Conferma ${_selectedOccurrences.length} scadenze fatte',
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _selectedOccurrences.clear()),
              child: const Text('Annulla'),
            ),
          ],
        ),
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

    final upcomingSection = _buildUpcomingSection(summary);
    if (upcomingSection.isNotEmpty) {
      widgets.add(SizedBox(height: 2.h));
      widgets.addAll(upcomingSection);
    }

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
    final dueOccurrences = summary.dueOccurrences
        .where((o) => o.urgency != AsdDeadlineUrgency.normal)
        .toList();
    return [
      _sectionHeader('Da fare'),
      if (dueOccurrences.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Niente da fare adesso'),
        )
      else
        ...dueOccurrences.map(_buildOccurrenceCard),
    ];
  }

  /// Active deadlines whose current occurrence is neither overdue nor
  /// due-soon and whose previous cycle was never completed — i.e. genuinely
  /// still far away, not just a freshly-completed recurring deadline
  /// waiting for its next cycle (that one shows in "Completate" instead).
  /// Hidden entirely when empty.
  List<Widget> _buildUpcomingSection(AsdDeadlineSummary summary) {
    final upcoming = summary.dueOccurrences
        .where((o) =>
            o.urgency == AsdDeadlineUrgency.normal && !o.previousCycleCompleted)
        .toList();
    if (upcoming.isEmpty) return const [];
    return [
      _sectionHeader('In programma'),
      ...upcoming.map(_buildOccurrenceCard),
    ];
  }

  /// Shared row for "Da fare" and "In programma": same checkbox (selection
  /// only), three-dot menu, "?" guide, tap-to-open-page and long-press-to-
  /// delete. Built by hand instead of ListTile: ListTile wraps its whole
  /// content — leading included — in one InkWell for onTap/onLongPress, and
  /// on a real phone that ink response was winning the touch over the
  /// three-dot InkWell nested two items down inside `leading` (the
  /// checkbox, first in that same slot, was never affected). With our own
  /// InkWell here, the row's tap/long-press and the three-dot button are
  /// each exactly one recognizer with nothing else layered over the same
  /// 48x48 box — the Tooltip that used to wrap it is gone too, since it
  /// added its own long-press recognizer over that same area.
  Widget _buildOccurrenceCard(AsdDeadlineOccurrence occurrence) {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    final color = switch (occurrence.urgency) {
      AsdDeadlineUrgency.overdue => Colors.red,
      AsdDeadlineUrgency.dueSoon => Colors.orange,
      AsdDeadlineUrgency.normal => null,
    };
    final isSelected = _selectedOccurrences.containsKey(_occurrenceKey(occurrence));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDeadlinePage(occurrence),
        onLongPress: () => _confirmDeleteDeadline(occurrence.deadline),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(occurrence),
                ),
                // Full 48x48 tap target of its own, nothing else
                // registered over the same box (see doc comment above).
                SizedBox(
                  width: 48,
                  height: 48,
                  child: InkWell(
                    onTap: () => _openActionsMenu(occurrence),
                    child: const Center(
                      child: Icon(Icons.more_vert, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occurrence.deadline.title,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${dayFormat.format(occurrence.dueDate)} · ${asdCategoryLabel(occurrence.deadline.category)}',
                          style: TextStyle(color: color),
                        ),
                        if (occurrence.deadline.needsConfirmation)
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
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Come si fa',
              onPressed: () => _openGuide(occurrence.deadline),
            ),
          ],
        ),
      ),
    );
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
    final occurrenceByDeadlineId = {
      for (final o in summary.dueOccurrences) o.deadline.id: o,
    };
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

          // Recurring deadlines only: when the next occurrence re-enters
          // "Da fare" (its due date minus its own notice_days).
          String? returnText;
          final deadline = summary.deadlinesById[completion.deadlineId];
          if (deadline != null && !deadline.isOneTime) {
            final nextOccurrence = occurrenceByDeadlineId[completion.deadlineId];
            if (nextOccurrence != null) {
              final returnDate = nextOccurrence.dueDate
                  .subtract(Duration(days: deadline.noticeDays));
              returnText = 'Torna in Da fare il ${dayFormat.format(returnDate)}';
            }
          }

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
              subtitle: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle),
                  if (returnText != null)
                    Text(returnText, style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
              onTap: () => _confirmUndoCompletion(completion),
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
