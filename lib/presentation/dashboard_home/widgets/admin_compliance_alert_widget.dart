import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../services/compliance_service.dart';

/// Highlighted row on the admin dashboard: how many students have gone past
/// their compliance deadline (minor docs / medical certificate) and are not
/// yet blocked from booking. Tapping it opens "Documenti mancanti".
/// Hidden entirely when the count is zero or on any load error.
class AdminComplianceAlertWidget extends StatefulWidget {
  const AdminComplianceAlertWidget({super.key});

  @override
  State<AdminComplianceAlertWidget> createState() =>
      _AdminComplianceAlertWidgetState();
}

class _AdminComplianceAlertWidgetState
    extends State<AdminComplianceAlertWidget> {
  int? _overdueCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ComplianceService.instance.adminComplianceList();
      final count = list.where((row) {
        final worstDaysLeft = row['worst_days_left'] as int?;
        final blocked = row['blocked'] == true;
        return worstDaysLeft != null && worstDaysLeft < 0 && !blocked;
      }).length;
      if (!mounted) return;
      setState(() => _overdueCount = count);
    } catch (_) {
      // Not critical — the row just stays hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _overdueCount;
    if (count == null || count == 0) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.pushNamed(context, AppRoutes.complianceDocs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count ${count == 1 ? 'allievo ha' : 'allievi hanno'} superato '
                'la scadenza documenti: decidi se bloccare',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }
}
