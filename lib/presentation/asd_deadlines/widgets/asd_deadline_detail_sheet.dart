import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/asd_deadlines_service.dart';

/// Bottom sheet for a "Da fare" occurrence: Segna come fatta / Salta questa
/// scadenza / Modifica / Elimina. Pops with a short action string that the
/// caller (AsdDeadlinesScreen) acts on, so this sheet has no service calls
/// of its own beyond what it needs to display.
class AsdDeadlineDetailSheet extends StatelessWidget {
  const AsdDeadlineDetailSheet({Key? key, required this.occurrence})
      : super(key: key);

  final AsdDeadlineOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final deadline = occurrence.deadline;
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              deadline.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '${dayFormat.format(occurrence.dueDate)} · ${asdCategoryLabel(deadline.category)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Segna come fatta'),
              onTap: () => Navigator.pop(context, 'done'),
            ),
            ListTile(
              leading: const Icon(Icons.skip_next_outlined),
              title: const Text('Salta questa scadenza'),
              onTap: () => Navigator.pop(context, 'skip'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifica'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Elimina'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
  }
}
