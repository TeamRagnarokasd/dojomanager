import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/asd_deadlines_service.dart';

/// How many nearest-due deadlines to show by default, before "Mostra tutte
/// le scadenze" is tapped.
const int _kRecommendedCount = 5;

/// Distinguishes "the user picked Nessuna" (deadlineId null) from "the
/// sheet was dismissed without a choice" (Navigator.pop returns plain
/// null in that case) — both would otherwise look like the same null.
class _DeadlinePickResult {
  const _DeadlinePickResult(this.deadlineId);
  final String? deadlineId;
}

/// A tappable field, styled like a form field, that opens a full-height
/// panel to pick a linked Scadenzario entry — used wherever a document
/// (or its edit form) needs "Scadenza collegata" without listing every
/// deadline in a single long dropdown. With the search box empty, the
/// panel shows only the [_kRecommendedCount] deadlines with the nearest
/// current due date (overdue first, then soonest), read from
/// AsdDeadlinesService.getDueOccurrences; a deadline with no current due
/// date sorts after those, alphabetically. Typing in the search box
/// switches to a case-insensitive title search across every deadline.
class AsdDeadlinePicker extends StatelessWidget {
  const AsdDeadlinePicker({
    Key? key,
    required this.label,
    required this.deadlines,
    required this.selectedDeadlineId,
    required this.onChanged,
  }) : super(key: key);

  final String label;
  final List<AsdDeadline> deadlines;
  final String? selectedDeadlineId;
  final ValueChanged<String?> onChanged;

  String? get _selectedTitle {
    final id = selectedDeadlineId;
    if (id == null) return null;
    for (final deadline in deadlines) {
      if (deadline.id == id) return deadline.title;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_DeadlinePickResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AsdDeadlinePickerSheet(
        deadlines: deadlines,
        selectedDeadlineId: selectedDeadlineId,
      ),
    );
    if (result != null) onChanged(result.deadlineId);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedTitle ?? 'Nessuna',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _AsdDeadlinePickerSheet extends StatefulWidget {
  const _AsdDeadlinePickerSheet({
    required this.deadlines,
    required this.selectedDeadlineId,
  });

  final List<AsdDeadline> deadlines;
  final String? selectedDeadlineId;

  @override
  State<_AsdDeadlinePickerSheet> createState() => _AsdDeadlinePickerSheetState();
}

class _AsdDeadlinePickerSheetState extends State<_AsdDeadlinePickerSheet> {
  final _searchController = TextEditingController();

  bool _isLoadingDueDates = true;
  Map<String, DateTime> _dueDateById = {};
  String _query = '';
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadDueDates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDueDates() async {
    try {
      final occurrences =
          await AsdDeadlinesService.instance.getDueOccurrences(widget.deadlines);
      if (!mounted) return;
      setState(() {
        _dueDateById = {for (final o in occurrences) o.deadline.id: o.dueDate};
        _isLoadingDueDates = false;
      });
    } catch (_) {
      // Not critical — the panel just shows titles with no date, and
      // "consigliate" falls back to a plain alphabetical order.
      if (!mounted) return;
      setState(() => _isLoadingDueDates = false);
    }
  }

  List<AsdDeadline> _alphabetical(List<AsdDeadline> source) {
    final list = [...source];
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  List<AsdDeadline> get _recommended {
    final list = [...widget.deadlines];
    list.sort((a, b) {
      final dueA = _dueDateById[a.id];
      final dueB = _dueDateById[b.id];
      if (dueA != null && dueB != null) return dueA.compareTo(dueB);
      if (dueA != null) return -1;
      if (dueB != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list.take(_kRecommendedCount).toList();
  }

  List<AsdDeadline> get _searchResults => _alphabetical(widget.deadlines)
      .where((d) => d.title.toLowerCase().contains(_query))
      .toList();

  void _choose(String? deadlineId) {
    Navigator.pop(context, _DeadlinePickResult(deadlineId));
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;
    final canExpand = widget.deadlines.length > _kRecommendedCount;
    final visible = isSearching
        ? _searchResults
        : (_showAll ? _alphabetical(widget.deadlines) : _recommended);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).viewPadding.bottom +
              16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scadenza collegata',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca scadenza',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      )
                    : null,
              ),
            ),
            if (!isSearching)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block),
                title: const Text('Nessuna (non collegare)'),
                trailing: widget.selectedDeadlineId == null
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => _choose(null),
              ),
            Expanded(
              child: _isLoadingDueDates
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? Center(
                          child: Text(
                            isSearching
                                ? 'Nessuna scadenza trovata.'
                                : 'Nessuna scadenza disponibile.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final deadline = visible[index];
                            final dueDate = _dueDateById[deadline.id];
                            final isSelected = deadline.id == widget.selectedDeadlineId;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(deadline.title),
                              subtitle: dueDate != null
                                  ? Text(DateFormat('dd/MM/yyyy', 'it_IT').format(dueDate))
                                  : null,
                              trailing: isSelected
                                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                                  : null,
                              onTap: () => _choose(deadline.id),
                            );
                          },
                        ),
            ),
            if (!isSearching && !_isLoadingDueDates && canExpand)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll
                        ? 'Mostra solo le consigliate'
                        : 'Mostra tutte le scadenze (${widget.deadlines.length})',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
