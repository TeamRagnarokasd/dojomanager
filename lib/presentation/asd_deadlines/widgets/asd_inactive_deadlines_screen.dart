import 'package:flutter/material.dart';

import '../../../services/asd_deadlines_service.dart';
import 'asd_deadline_form_screen.dart';

/// "Scadenze non attive": the full list of is_active=false deadlines,
/// reached from the collapsed "Non attive (N)" row on the main Scadenzario
/// screen. Same rows as before this screen existed — condition_note,
/// reactivate switch, tap for detail (the edit form) — just moved off the
/// main list so it no longer mixes with the active ones.
class AsdInactiveDeadlinesScreen extends StatefulWidget {
  const AsdInactiveDeadlinesScreen({Key? key}) : super(key: key);

  @override
  State<AsdInactiveDeadlinesScreen> createState() =>
      _AsdInactiveDeadlinesScreenState();
}

class _AsdInactiveDeadlinesScreenState extends State<AsdInactiveDeadlinesScreen> {
  final _service = AsdDeadlinesService.instance;

  bool _isLoading = true;
  String? _loadError;
  List<AsdDeadline> _inactiveDeadlines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final all = await _service.getAllDeadlines();
      final inactive = all.where((d) => !d.isActive).toList()
        ..sort((a, b) => a.title.compareTo(b.title));
      if (!mounted) return;
      setState(() {
        _inactiveDeadlines = inactive;
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

  Future<void> _reactivate(AsdDeadline deadline, bool active) async {
    try {
      await _service.setDeadlineActive(deadline.id, active);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scadenze non attive')),
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
              : _inactiveDeadlines.isEmpty
                  ? const Center(child: Text('Nessuna scadenza non attiva.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _inactiveDeadlines.map((deadline) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            child: ListTile(
                              title: Text(deadline.title),
                              subtitle: deadline.conditionNote != null &&
                                      deadline.conditionNote!.isNotEmpty
                                  ? Text(
                                      deadline.conditionNote!,
                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                    )
                                  : null,
                              trailing: Switch(
                                value: false,
                                onChanged: (value) => _reactivate(deadline, value),
                              ),
                              onTap: () => _openEditDeadline(deadline),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
}
