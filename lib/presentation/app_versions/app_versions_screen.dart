import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/app_client_versions_service.dart';

/// "Versioni app": admin-only list of users with the platform, app version
/// and last access reported by their client (via report_app_version).
/// Users whose build is older than the current app_version.version_code are
/// highlighted in red. Already ordered oldest-last-access-first by the RPC.
class AppVersionsScreen extends StatefulWidget {
  const AppVersionsScreen({Key? key}) : super(key: key);

  @override
  State<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends State<AppVersionsScreen> {
  final _service = AppClientVersionsService.instance;

  bool _isCheckingAccess = true;
  bool _canAccess = false;

  bool _isLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    try {
      canAccess =
          await AdminSectionVisibilityService.instance.canAccess('app_versions');
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
      final clients = await _service.adminOutdatedClientsList();
      if (!mounted) return;
      setState(() {
        _clients = clients;
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

  String _formatLastSeen(String? raw) {
    if (raw == null || raw.isEmpty) return 'Mai';
    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(date);
    } catch (_) {
      return raw;
    }
  }

  String _versionLabel(Map<String, dynamic> client) {
    final versionName = client['version_name'] as String?;
    final buildNumber = client['build_number'] as int?;
    if (versionName == null && buildNumber == null) return 'Sconosciuta';
    if (buildNumber == null) return versionName ?? 'Sconosciuta';
    return '${versionName ?? '?'} (build $buildNumber)';
  }

  IconData _platformIcon(String? platform) {
    switch (platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices_other;
    }
  }

  Widget _buildClientTile(Map<String, dynamic> client) {
    final name = client['name'] as String? ?? 'Utente';
    final email = client['email'] as String?;
    final platform = client['platform'] as String?;
    final outdated = client['outdated'] == true;
    final color = outdated ? Colors.red : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_platformIcon(platform), color: color),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null && email.trim().isNotEmpty) Text(email),
            Text(
              'Versione: ${_versionLabel(client)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            Text('Ultimo accesso: ${_formatLastSeen(client['last_seen_at'] as String?)}'),
          ],
        ),
        trailing: outdated
            ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
            : null,
        isThreeLine: true,
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
        appBar: AppBar(title: const Text('Versioni app')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Non hai accesso a questa sezione.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Versioni app')),
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
                        ElevatedButton(onPressed: _load, child: const Text('Riprova')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _clients.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewPadding.bottom + 24,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('Nessun dato di versione disponibile.')),
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
                          children: _clients.map(_buildClientTile).toList(),
                        ),
                ),
    );
  }
}
