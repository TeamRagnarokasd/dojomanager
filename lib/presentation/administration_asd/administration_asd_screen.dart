import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routes/app_routes.dart';
import '../../services/admin_section_visibility_service.dart';
import '../../services/asd_deadlines_service.dart';
import '../../services/asd_governance_service.dart';
import '../../services/auth_service.dart';
import '../../services/compliance_service.dart';
import '../../services/italian_receipt_service.dart';

/// Definition of one "Amministrazione ASD" section. Adding a future section
/// is adding one more entry to [kAdminAsdSections] — plus a matching
/// `admin_section_visibility` row (`section_key`) created server-side —
/// nothing else needs to change. Also used by ManagementCardsWidget to
/// decide whether the "Amministrazione ASD" dashboard card itself should be
/// shown (shown when at least one of these is accessible).
class AdminAsdSection {
  const AdminAsdSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.arguments,
  });

  /// Matches a `section_key` in `admin_section_visibility` and the `p_key`
  /// passed to `can_access_admin_section`/`set_admin_section_visibility`.
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Object? arguments;
}

// Ordine logico: adempimenti, contabilità, lavoro e attività, documenti,
// dati fissi. Nuove sezioni vanno messe nel gruppo giusto.
const List<AdminAsdSection> kAdminAsdSections = [
  AdminAsdSection(
    key: 'deadlines',
    title: 'Scadenzario ASD',
    subtitle: 'Scadenze e adempimenti',
    icon: Icons.calendar_month_outlined,
    route: AppRoutes.asdDeadlines,
  ),
  AdminAsdSection(
    key: 'cash_register',
    title: 'Registro di Cassa',
    subtitle: 'Entrate e uscite in contanti, prima nota mensile',
    icon: Icons.point_of_sale_outlined,
    route: AppRoutes.cashRegister,
  ),
  AdminAsdSection(
    key: 'receipts',
    title: 'Gestione Ricevute',
    subtitle: 'Sistema ricevute italiane integrato',
    icon: Icons.receipt,
    route: AppRoutes.italianReceiptGeneration,
  ),
  AdminAsdSection(
    key: 'payment_review',
    title: 'Pagamenti da verificare',
    subtitle: 'Pagamenti SumUp da abbinare',
    icon: Icons.fact_check_outlined,
    route: AppRoutes.paymentReview,
  ),
  AdminAsdSection(
    key: 'compliance_docs',
    title: 'Documenti mancanti',
    subtitle: 'Moduli minori 14-17 e certificati medici in scadenza',
    icon: Icons.assignment_late,
    route: AppRoutes.complianceDocs,
  ),
  AdminAsdSection(
    key: 'attendance_compensation',
    title: 'Presenze e compensi',
    subtitle: 'Lezioni, compenso, buoni pasto e rimborso km',
    icon: Icons.event_available_outlined,
    route: AppRoutes.workAttendance,
  ),
  AdminAsdSection(
    key: 'social_events',
    title: 'Eventi sociali',
    subtitle: 'Cene sociali: verbale e spese',
    icon: Icons.celebration_outlined,
    route: AppRoutes.socialEvents,
  ),
  AdminAsdSection(
    key: 'documents_archive',
    title: 'Archivio documenti',
    subtitle: 'Tutti i documenti per categoria',
    icon: Icons.folder_copy_outlined,
    route: AppRoutes.asdDocumentsArchive,
  ),
  AdminAsdSection(
    key: 'drive_documents',
    title: 'Documenti Drive',
    subtitle: 'Cartella condivisa: salva e carica i documenti',
    icon: Icons.folder_shared_outlined,
    route: '',
  ),
  AdminAsdSection(
    key: 'team_data',
    title: 'Dati Team / ASD',
    subtitle: 'Nome, indirizzo, C.F., PEC e contatti',
    icon: Icons.business_center,
    route: AppRoutes.adminManagementSystem,
    arguments: {'initialTab': 'settings'},
  ),
];

/// Umbrella section key: switching this off hides every section below to
/// non-principal admins, regardless of their own individual switches (see
/// can_access_admin_section).
const String kAdministrationAsdKey = 'administration_asd';

/// One AI assistant offered by "Chiedi all'assistente".
class _AssistantOption {
  const _AssistantOption(this.key, this.label, this.url);

  final String key;
  final String label;
  final String url;
}

/// Claude first — the default assistant.
const List<_AssistantOption> _kAssistantOptions = [
  _AssistantOption('claude', 'Claude', 'https://claude.ai/new'),
  _AssistantOption('chatgpt', 'ChatGPT', 'https://chatgpt.com/'),
  _AssistantOption('gemini', 'Gemini', 'https://gemini.google.com/app'),
  _AssistantOption('grok', 'Grok', 'https://grok.com/'),
  _AssistantOption('copilot', 'Copilot', 'https://copilot.microsoft.com/'),
];

/// "Amministrazione ASD": a list of admin sections. The principal admin
/// always sees every section and can toggle, for each one, whether other
/// admins may access it (including the umbrella switch at the top). Other
/// admins only ever see the sections currently enabled for them, with no
/// switches.
class AdministrationAsdScreen extends StatefulWidget {
  const AdministrationAsdScreen({Key? key}) : super(key: key);

  @override
  State<AdministrationAsdScreen> createState() =>
      _AdministrationAsdScreenState();
}

class _AdministrationAsdScreenState extends State<AdministrationAsdScreen> {
  final _visibilityService = AdminSectionVisibilityService.instance;

  bool _isLoading = true;
  bool _isPrincipalAdmin = false;
  List<AdminAsdSection> _visibleSections = [];

  /// section_key -> visible_to_admins, only loaded/shown for the principal
  /// admin (the switches).
  Map<String, bool> _visibilityMap = {};
  final Set<String> _togglingKeys = {};

  String? _appVersionText;

  /// Count shown on the "Scadenzario ASD" row (overdue + due-soon), only
  /// fetched when that section is visible to the current admin.
  int? _deadlinesBadgeCount;

  /// Count shown on the "Documenti mancanti" row: students past their
  /// compliance deadline and not yet blocked, only fetched when that
  /// section is visible to the current admin.
  int? _complianceOverdueCount;

  /// The shared Drive folder link, only fetched when "Documenti Drive" is
  /// visible to the current admin. Editable only by the principal admin.
  String? _driveFolderUrl;

  /// "Chiedi all'assistente": which assistant the short tap opens, saved
  /// per user in shared_preferences. Defaults to Claude.
  String _assistantKey = _kAssistantOptions.first.key;

  @override
  void initState() {
    super.initState();
    _load();
    _loadAppVersion();
    _loadAssistantChoice();
  }

  _AssistantOption get _currentAssistant => _kAssistantOptions.firstWhere(
        (a) => a.key == _assistantKey,
        orElse: () => _kAssistantOptions.first,
      );

  String get _assistantPrefsKey {
    final userId = AuthService.instance.currentUser?.id ?? 'anon';
    return 'asd_assistant_choice_$userId';
  }

  Future<void> _loadAssistantChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_assistantPrefsKey);
      if (saved != null &&
          _kAssistantOptions.any((a) => a.key == saved) &&
          mounted) {
        setState(() => _assistantKey = saved);
      }
    } catch (_) {
      // Not critical — stays on the default assistant.
    }
  }

  Future<void> _selectAssistant(String key) async {
    Navigator.pop(context);
    setState(() => _assistantKey = key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_assistantPrefsKey, key);
    } catch (_) {
      // Not critical — the choice just won't be remembered next time.
    }
  }

  Future<void> _showAssistantPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Scegli il tuo assistente',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ..._kAssistantOptions.map(
              (assistant) => ListTile(
                title: Text(assistant.label),
                trailing: assistant.key == _assistantKey
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => _selectAssistant(assistant.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Builds the Italian context text handed to the assistant: association
  /// data plus, only where the current admin can actually read them, the
  /// board and the active Scadenzario entries. No student data, medical
  /// certificates, payments or Drive links are ever included, and a read
  /// the database denies is skipped silently rather than shown as an error.
  Future<String> _buildAssistantContext() async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Sono un amministratore dell\'ASD Team Ragnarok e ho un dubbio sulla '
      'gestione dell\'associazione. Qui sotto trovi i dati dell\'associazione '
      'e il mio scadenzario. Rispondi in italiano e ricorda che non sei un '
      'consulente fiscale o legale: per le decisioni importanti va sentita '
      'la commercialista.',
    );

    try {
      final orgInfo = await ItalianReceiptService().getOrganizationInfo();
      buffer.writeln();
      buffer.writeln('Associazione: ${orgInfo.name}');
      buffer.writeln('Indirizzo: ${orgInfo.address}');
      buffer.writeln('Codice fiscale: ${orgInfo.taxCode}');
    } catch (_) {
      // Skip silently if organization_info can't be read.
    }

    try {
      final members =
          await AsdGovernanceService.instance.getBoardMembers(onlyActive: true);
      if (members.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Consiglio direttivo:');
        for (final member in members) {
          buffer.writeln('- ${member.fullName} (${asdBoardRoleLabel(member.role)})');
        }
      }
    } catch (_) {
      // Skip silently if asd_board_members can't be read.
    }

    try {
      final all = await AsdDeadlinesService.instance.getAllDeadlines();
      final active = all.where((d) => d.isActive).toList();
      if (active.isNotEmpty) {
        final occurrences = await AsdDeadlinesService.instance.getDueOccurrences(all);
        final occurrenceByDeadlineId = {
          for (final o in occurrences) o.deadline.id: o,
        };
        final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');

        buffer.writeln();
        buffer.writeln('Scadenzario (voci attive):');
        for (final deadline in active) {
          final occurrence = occurrenceByDeadlineId[deadline.id];
          DateTime dueDate;
          String status;
          if (occurrence != null) {
            dueDate = occurrence.dueDate;
            status = occurrence.urgency == AsdDeadlineUrgency.overdue
                ? 'scaduta'
                : 'da fare';
          } else if (deadline.isOneTime) {
            dueDate = DateTime(deadline.dueYear!, deadline.dueMonth, deadline.dueDay);
            status = 'completata';
          } else {
            continue;
          }
          buffer.writeln(
            '- ${deadline.title} (${asdCategoryLabel(deadline.category)}), '
            '${dayFormat.format(dueDate)}, stato: $status',
          );
          if (deadline.notes != null && deadline.notes!.trim().isNotEmpty) {
            buffer.writeln('  Note: ${deadline.notes!.trim()}');
          }
          if (deadline.conditionNote != null &&
              deadline.conditionNote!.trim().isNotEmpty) {
            buffer.writeln('  Condizione: ${deadline.conditionNote!.trim()}');
          }
          if (deadline.howTo != null && deadline.howTo!.trim().isNotEmpty) {
            buffer.writeln('  Guida pratica:');
            for (final step in deadline.howTo!.split('\n')) {
              final trimmedStep = step.trim();
              if (trimmedStep.isNotEmpty) buffer.writeln('    - $trimmedStep');
            }
          }
        }
      }
    } catch (_) {
      // Skip silently if asd_deadlines can't be read.
    }

    return buffer.toString().trim();
  }

  Future<void> _askAssistant() async {
    final assistant = _currentAssistant;
    String contextText;
    try {
      contextText = await _buildAssistantContext();
    } catch (_) {
      contextText = '';
    }
    await Clipboard.setData(ClipboardData(text: contextText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contesto copiato: incollalo nella chat di ${assistant.label}'),
      ),
    );
    try {
      await launchUrl(Uri.parse(assistant.url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire ${assistant.label}: $e')),
      );
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionText = 'Versione app ${info.version} (build ${info.buildNumber})';
      });
    } catch (_) {
      // Not critical — just leave it unshown if it can't be read.
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final isPrincipal = await AuthService.instance.isPrincipalAdmin();

    if (isPrincipal) {
      // Principal admin always sees everything; still load the raw
      // visibility map to render the switches' current state.
      Map<String, bool> visibilityMap = {};
      try {
        visibilityMap = await _visibilityService.getVisibilityMap();
      } catch (_) {
        // Switches default to "off" if the table can't be read — the
        // principal admin's own access is unaffected either way.
      }
      if (!mounted) return;
      setState(() {
        _isPrincipalAdmin = true;
        _visibleSections = kAdminAsdSections;
        _visibilityMap = visibilityMap;
        _isLoading = false;
      });
      _loadDeadlinesBadge(kAdminAsdSections);
      _loadComplianceBadge(kAdminAsdSections);
      _loadDriveUrl(kAdminAsdSections);
      return;
    }

    // Non-principal admin: filter to sections currently enabled for them.
    final visible = <AdminAsdSection>[];
    for (final section in kAdminAsdSections) {
      try {
        if (await _visibilityService.canAccess(section.key)) {
          visible.add(section);
        }
      } catch (_) {
        // Fail closed for a section we couldn't verify.
      }
    }
    if (!mounted) return;
    setState(() {
      _isPrincipalAdmin = false;
      _visibleSections = visible;
      _isLoading = false;
    });
    _loadDeadlinesBadge(visible);
    _loadComplianceBadge(visible);
    _loadDriveUrl(visible);
  }

  /// Fire-and-forget: only fetched when "Scadenzario ASD" is one of the
  /// sections this admin can see. Failure just leaves the badge unshown.
  Future<void> _loadDeadlinesBadge(List<AdminAsdSection> sections) async {
    if (!sections.any((s) => s.key == 'deadlines')) return;
    try {
      final summary = await AsdDeadlinesService.instance.getPendingSummary();
      if (!mounted) return;
      setState(() => _deadlinesBadgeCount = summary.pendingCount);
    } catch (_) {
      // Not critical — the row just shows no badge.
    }
  }

  /// Red count shown next to a section's title, if any.
  int? _sectionBadgeCount(String sectionKey) {
    switch (sectionKey) {
      case 'deadlines':
        return _deadlinesBadgeCount;
      case 'compliance_docs':
        return _complianceOverdueCount;
      default:
        return null;
    }
  }

  /// Fire-and-forget: only fetched when "Documenti mancanti" is one of the
  /// sections this admin can see. Failure just leaves the badge unshown.
  Future<void> _loadComplianceBadge(List<AdminAsdSection> sections) async {
    if (!sections.any((s) => s.key == 'compliance_docs')) return;
    try {
      final list = await ComplianceService.instance.adminComplianceList();
      final count = list.where((row) {
        final worstDaysLeft = row['worst_days_left'] as int?;
        final blocked = row['blocked'] == true;
        return worstDaysLeft != null && worstDaysLeft < 0 && !blocked;
      }).length;
      if (!mounted) return;
      setState(() => _complianceOverdueCount = count);
    } catch (_) {
      // Not critical — the row just shows no badge.
    }
  }

  /// Fire-and-forget: only fetched when "Documenti Drive" is one of the
  /// sections this admin can see.
  Future<void> _loadDriveUrl(List<AdminAsdSection> sections) async {
    if (!sections.any((s) => s.key == 'drive_documents')) return;
    try {
      final url = await AsdGovernanceService.instance.getDriveFolderUrl();
      if (!mounted) return;
      setState(() => _driveFolderUrl = url);
    } catch (_) {
      // Not critical — tapping the row will just report no link configured.
    }
  }

  Future<void> _openDriveFolder() async {
    final url = _driveFolderUrl;
    if (url == null || url.isEmpty) {
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

  Future<void> _showEditDriveUrlDialog() async {
    final controller = TextEditingController(text: _driveFolderUrl ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link cartella Drive'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Link della cartella condivisa'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;
    try {
      await AsdGovernanceService.instance.setDriveFolderUrl(url);
      if (!mounted) return;
      setState(() => _driveFolderUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _toggleVisibility(String key, bool value) async {
    setState(() => _togglingKeys.add(key));
    try {
      await _visibilityService.setVisibility(key, value);
      if (!mounted) return;
      setState(() => _visibilityMap[key] = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    } finally {
      if (mounted) setState(() => _togglingKeys.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amministrazione ASD'),
        actions: [_buildAssistantAction()],
      ),
      body: ListView(
        padding: EdgeInsets.all(4.w),
        children: [
          if (_isPrincipalAdmin) ...[
            _buildAdministrationAsdToggleCard(),
            SizedBox(height: 2.h),
          ],
          if (_visibleSections.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Center(
                child: Text(
                  'Nessuna sezione disponibile.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ..._visibleSections.map(_buildSectionTile),
          if (_appVersionText != null) ...[
            SizedBox(height: 3.h),
            Center(
              child: Text(
                _appVersionText!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdministrationAsdToggleCard() {
    final isVisible = _visibilityMap[kAdministrationAsdKey] ?? false;
    final isSaving = _togglingKeys.contains(kAdministrationAsdKey);

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVisible
                        ? 'Amministrazione ASD visibile agli altri admin'
                        : 'Amministrazione ASD non visibile agli altri admin',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Se lo spegni, gli altri admin non vedono nessuna sezione qui dentro.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.w),
            isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _buildVisibilitySwitch(
                    value: isVisible,
                    onChanged: (value) =>
                        _toggleVisibility(kAdministrationAsdKey, value),
                  ),
          ],
        ),
      ),
    );
  }

  /// AppBar pill, visible to every admin who opens this screen (principal
  /// or not): the assistant currently in use. Short tap: copy the Italian
  /// context to the clipboard and open it. Long press: pick a different
  /// assistant. Both gestures live on one InkResponse (not nested
  /// ancestor/descendant detectors), so they can't race each other; the
  /// Tooltip is manual-only so it doesn't compete for the long press
  /// either. The label is capped and non-wrapping so a narrow screen never
  /// overflows the AppBar.
  Widget _buildAssistantAction() {
    final foregroundColor = IconTheme.of(context).color;
    return Tooltip(
      triggerMode: TooltipTriggerMode.manual,
      message: 'Chiedi a ${_currentAssistant.label} (tieni premuto per cambiare)',
      child: InkResponse(
        onTap: _askAssistant,
        onLongPress: _showAssistantPicker,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (foregroundColor ?? Colors.white).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: foregroundColor),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: Text(
                    _currentAssistant.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Green thumb/track when on, red when off (with a lighter/more muted red
  /// track) — used for every visibility switch in this screen.
  Widget _buildVisibilitySwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
      activeTrackColor: Colors.green.withValues(alpha: 0.5),
      inactiveThumbColor: Colors.red,
      inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
    );
  }

  /// No ListTile: a ListTile's onTap wraps the WHOLE row (title, subtitle,
  /// trailing) in one InkWell, so a switch nested in its trailing slot was
  /// racing that same ancestor tap in the gesture arena — hence the
  /// previous, unreliable "sometimes the row wins" bug. Two independent
  /// sibling zones in a Row can't have this problem: a tap can only ever
  /// land in one of them, so there's no shared ancestor gesture to race.
  Widget _buildSectionTile(AdminAsdSection section) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left zone: icon + title + subtitle, opens the section.
              Expanded(
                child: InkWell(
                  onTap: () => section.key == 'drive_documents'
                      ? _openDriveFolder()
                      : Navigator.pushNamed(
                          context,
                          section.route,
                          arguments: section.arguments,
                        ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.15),
                          child: Icon(
                            section.icon,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                section.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 0.3.h),
                              Text(
                                section.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (_sectionBadgeCount(section.key) != null &&
                            _sectionBadgeCount(section.key)! > 0) ...[
                          SizedBox(width: 2.w),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_sectionBadgeCount(section.key)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (!_isPrincipalAdmin) ...[
                          SizedBox(width: 2.w),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Right zone: principal admin only, full height, separated by
              // a thin vertical divider — never opens the section.
              if (_isPrincipalAdmin) ...[
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
                _buildSectionVisibilityZone(section),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Fixed-width (~110dp) column: label + Switch, wrapped in its own opaque
  /// GestureDetector (which never opens the section); the Switch inside
  /// also toggles on its own native tap/drag when hit directly — the two
  /// never conflict, since only one recognizer can ever win a given tap in
  /// the gesture arena, and this GestureDetector has no shared ancestor
  /// with the left zone's InkWell. While saving, the spinner takes the
  /// exact space of the Switch (same height throughout) and taps do
  /// nothing. For "Documenti Drive", principal admin only, a pencil sits
  /// below as a plain sibling IconButton outside that GestureDetector — a
  /// separate tap that can't activate the switch, exactly like the
  /// switch-zone's own independence from the left zone above.
  Widget _buildSectionVisibilityZone(AdminAsdSection section) {
    final isVisible = _visibilityMap[section.key] ?? false;
    final isSaving = _togglingKeys.contains(section.key);

    void toggle() {
      if (isSaving) return;
      _toggleVisibility(section.key, !isVisible);
    }

    return SizedBox(
      width: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isVisible
                        ? 'Visibile agli altri admin'
                        : 'Non visibile agli altri admin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  SizedBox(
                    height: 48,
                    child: Center(
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _buildVisibilitySwitch(
                              value: isVisible,
                              onChanged: (value) =>
                                  _toggleVisibility(section.key, value),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (section.key == 'drive_documents')
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Modifica il link della cartella Drive',
              onPressed: _showEditDriveUrlDialog,
            ),
        ],
      ),
    );
  }
}
