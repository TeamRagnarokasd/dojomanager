import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/compliance_service.dart';

enum _ComplianceFilter { expired, dueSoon, all }

/// "Documenti mancanti": students with a minor 14-17 form and/or medical
/// certificate missing or expiring, read from `admin_compliance_list`
/// (already ordered from most urgent). Additive and isolated — actions here
/// only call admin_set_booking_block / admin_extend_compliance, nothing
/// else changes payments, subscriptions or the Registro di Cassa.
class ComplianceDocsScreen extends StatefulWidget {
  const ComplianceDocsScreen({Key? key}) : super(key: key);

  @override
  State<ComplianceDocsScreen> createState() => _ComplianceDocsScreenState();
}

class _ComplianceDocsScreenState extends State<ComplianceDocsScreen> {
  final _service = ComplianceService.instance;

  bool _isCheckingAccess = true;
  bool _canAccess = false;

  bool _isLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _students = [];
  _ComplianceFilter _filter = _ComplianceFilter.all;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    try {
      canAccess = await AdminSectionVisibilityService.instance
          .canAccess('compliance_docs');
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
      final students = await _service.adminComplianceList();
      if (!mounted) return;
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _afterAction(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    switch (_filter) {
      case _ComplianceFilter.expired:
        return _students.where((s) {
          final worst = s['worst_days_left'] as int?;
          return worst != null && worst < 0;
        }).toList();
      case _ComplianceFilter.dueSoon:
        return _students.where((s) {
          final worst = s['worst_days_left'] as int?;
          return worst != null && worst >= 0 && worst <= 3;
        }).toList();
      case _ComplianceFilter.all:
        return _students;
    }
  }

  List<String> _missingKinds(Map<String, dynamic> student) {
    final kinds = <String>[];
    final minorDocs = (student['minor_docs'] as Map?)?.cast<String, dynamic>();
    final medicalCert =
        (student['medical_cert'] as Map?)?.cast<String, dynamic>();
    if (minorDocs != null &&
        minorDocs['needed'] == true &&
        minorDocs['ok'] != true) {
      kinds.add('minor_docs');
    }
    if (medicalCert != null &&
        medicalCert['needed'] == true &&
        medicalCert['ok'] != true) {
      kinds.add('medical_cert');
    }
    return kinds;
  }

  String _kindLabel(String kind) =>
      kind == 'minor_docs' ? 'Modulo minori 14-17' : 'Certificato medico';

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw);
      return DateFormat('dd/MM/yyyy', 'it_IT').format(date);
    } catch (_) {
      return raw;
    }
  }

  String _formatDueShort(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw);
      return DateFormat('dd/MM', 'it_IT').format(date);
    } catch (_) {
      return raw;
    }
  }

  /// Null means "use the theme's default text color" — only overdue/due-soon
  /// items get a specific red/orange color.
  Color? _colorForDaysLeft(int? daysLeft) {
    if (daysLeft == null) return null;
    if (daysLeft < 0) return Colors.red;
    if (daysLeft <= 3) return Colors.orange;
    return null;
  }

  Future<void> _toggleBlock(Map<String, dynamic> student) async {
    final blocked = student['blocked'] == true;
    final name = student['name'] as String? ?? 'questo allievo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Sbloccare le prenotazioni?' : 'Bloccare le prenotazioni?'),
        content: Text(
          blocked
              ? '$name potrà tornare a prenotare le lezioni.'
              : '$name non potrà più prenotare lezioni finché non carica i documenti richiesti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: blocked
                ? null
                : ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(blocked ? 'Sblocca' : 'Blocca'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.setBookingBlock(
        userId: student['user_id'] as String,
        active: !blocked,
      );
      await _afterAction(blocked
          ? 'Prenotazioni sbloccate per $name.'
          : 'Prenotazioni bloccate per $name.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _extend(Map<String, dynamic> student, int days) async {
    final missingKinds = _missingKinds(student);
    String? kind;
    if (missingKinds.isEmpty) {
      return;
    } else if (missingKinds.length == 1) {
      kind = missingKinds.first;
    } else {
      kind = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Proroga quale documento?'),
          children: missingKinds
              .map(
                (k) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, k),
                  child: Text(_kindLabel(k)),
                ),
              )
              .toList(),
        ),
      );
    }
    if (kind == null) return;
    try {
      await _service.extendCompliance(
        userId: student['user_id'] as String,
        kind: kind,
        days: days,
      );
      await _afterAction(
          'Scadenza prorogata di $days giorni per ${student['name'] ?? 'l\'allievo'}.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _writeEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Impossibile aprire il client email.')));
    }
  }

  Widget _buildMissingLine(String kind, Map<String, dynamic> student) {
    final data = (kind == 'minor_docs'
            ? student['minor_docs']
            : student['medical_cert']) as Map?;
    if (data == null) return const SizedBox.shrink();
    final daysLeft = data['days_left'] as int?;
    final due = _formatDueShort(data['due'] as String?);
    final color = _colorForDaysLeft(daysLeft);
    String text;
    if (daysLeft != null && daysLeft < 0) {
      text = '${_kindLabel(kind)}: scaduto il $due';
    } else if (daysLeft != null) {
      text = '${_kindLabel(kind)}: entro il $due (mancano $daysLeft giorni)';
    } else {
      text = '${_kindLabel(kind)}: entro il $due';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = student['name'] as String? ?? 'Utente';
    final email = student['email'] as String?;
    final registeredAt = student['registered_at'] as String?;
    final blocked = student['blocked'] == true;
    final missingKinds = _missingKinds(student);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (blocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Prenotazioni bloccate',
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            if (registeredAt != null && registeredAt.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Iscritto il ${_formatDate(registeredAt)}',
                  style: const TextStyle(fontSize: 12)),
            ],
            for (final kind in missingKinds) _buildMissingLine(kind, student),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _toggleBlock(student),
                  style: blocked
                      ? null
                      : ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(blocked ? 'Sblocca prenotazioni' : 'Blocca prenotazioni'),
                ),
                OutlinedButton(
                  onPressed:
                      missingKinds.isEmpty ? null : () => _extend(student, 3),
                  child: const Text('Proroga 3 giorni'),
                ),
                OutlinedButton(
                  onPressed:
                      missingKinds.isEmpty ? null : () => _extend(student, 7),
                  child: const Text('Proroga 7 giorni'),
                ),
                if (email != null && email.trim().isNotEmpty)
                  OutlinedButton(
                    onPressed: () => _writeEmail(email),
                    child: const Text('Scrivi'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Scaduti'),
            selected: _filter == _ComplianceFilter.expired,
            onSelected: (_) => setState(() => _filter = _ComplianceFilter.expired),
          ),
          ChoiceChip(
            label: const Text('In scadenza (3 giorni)'),
            selected: _filter == _ComplianceFilter.dueSoon,
            onSelected: (_) => setState(() => _filter = _ComplianceFilter.dueSoon),
          ),
          ChoiceChip(
            label: const Text('Tutti'),
            selected: _filter == _ComplianceFilter.all,
            onSelected: (_) => setState(() => _filter = _ComplianceFilter.all),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Documenti mancanti')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Non hai accesso a questa sezione.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final filtered = _filteredStudents;

    return Scaffold(
      appBar: AppBar(title: const Text('Documenti mancanti')),
      body: Column(
        children: [
          if (!_isLoading && _loadError == null) _buildFilterChips(),
          Expanded(
            child: _isLoading
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
                              ElevatedButton(onPressed: _load, child: const Text('Riprova')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? ListView(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewPadding.bottom + 24,
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.only(top: 80),
                                    child: Center(child: Text('Nessun allievo con documenti mancanti.')),
                                  ),
                                ],
                              )
                            : ListView(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  MediaQuery.of(context).viewPadding.bottom + 24,
                                ),
                                children: filtered.map(_buildStudentCard).toList(),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
