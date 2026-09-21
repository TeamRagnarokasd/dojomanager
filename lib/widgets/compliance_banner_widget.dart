import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/compliance_service.dart';

/// Banner shown to a student when `my_compliance()` says something is
/// missing (minor 14-17 documents and/or a valid medical certificate).
/// Reloads on open and whenever the app comes back to the foreground.
/// Shows nothing on network errors, and nothing when everything is fine.
class ComplianceBannerWidget extends StatefulWidget {
  const ComplianceBannerWidget({super.key});

  @override
  State<ComplianceBannerWidget> createState() =>
      _ComplianceBannerWidgetState();
}

class _ComplianceBannerWidgetState extends State<ComplianceBannerWidget>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _compliance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await ComplianceService.instance.myCompliance();
      if (!mounted) return;
      setState(() => _compliance = data);
    } catch (_) {
      // Network errors: no banner, no message.
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}';
  }

  Color _colorForDaysLeft(int? daysLeft) {
    if (daysLeft == null) return Colors.blue;
    if (daysLeft < 0) return Colors.red;
    if (daysLeft <= 3) return Colors.orange;
    return Colors.blue;
  }

  String _messageFor(String kind, Map<String, dynamic> data) {
    final daysLeft = data['days_left'] as int?;
    final dateStr = _formatDate(data['due'] as String?);
    if (daysLeft != null && daysLeft < 0) {
      return 'Scaduto il $dateStr';
    }
    final daysText = daysLeft != null
        ? ' (mancano $daysLeft ${daysLeft == 1 ? 'giorno' : 'giorni'})'
        : '';
    if (kind == 'minor_docs') {
      return 'Carica il modulo firmato e il documento del genitore entro il $dateStr$daysText';
    }
    return 'Carica il certificato medico entro il $dateStr$daysText';
  }

  Widget _buildRow({
    required Color color,
    required String message,
    VoidCallback? onUpload,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          if (onUpload != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onUpload,
              style: TextButton.styleFrom(foregroundColor: color),
              child: const Text('Carica ora'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _compliance;
    if (data == null || data['applies'] != true) return const SizedBox.shrink();

    final blocked = data['blocked'] == true;
    final minorDocs = (data['minor_docs'] as Map?)?.cast<String, dynamic>();
    final medicalCert = (data['medical_cert'] as Map?)?.cast<String, dynamic>();

    final rows = <Widget>[];

    if (blocked) {
      rows.add(_buildRow(
        color: Colors.red,
        message:
            'Prenotazioni sospese: carica i documenti richiesti per tornare a prenotare',
      ));
    }

    if (minorDocs != null &&
        minorDocs['needed'] == true &&
        minorDocs['ok'] != true) {
      rows.add(_buildRow(
        color: _colorForDaysLeft(minorDocs['days_left'] as int?),
        message: _messageFor('minor_docs', minorDocs),
        onUpload: () => Navigator.pushNamed(context, AppRoutes.userProfile),
      ));
    }

    if (medicalCert != null &&
        medicalCert['needed'] == true &&
        medicalCert['ok'] != true) {
      rows.add(_buildRow(
        color: _colorForDaysLeft(medicalCert['days_left'] as int?),
        message: _messageFor('medical_cert', medicalCert),
        onUpload: () =>
            Navigator.pushNamed(context, AppRoutes.medicalCertificateUpload),
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}
