import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../routes/app_routes.dart';
import '../../services/admin_section_visibility_service.dart';
import '../../services/auth_service.dart';

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

const List<AdminAsdSection> kAdminAsdSections = [
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

  @override
  void initState() {
    super.initState();
    _load();
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
      appBar: AppBar(title: const Text('Amministrazione ASD')),
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

  Widget _buildSectionTile(AdminAsdSection section) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Card(
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
            child: Icon(section.icon, color: Theme.of(context).colorScheme.secondary),
          ),
          title: Text(
            section.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(section.subtitle),
          trailing: _isPrincipalAdmin
              ? _buildSectionSwitch(section)
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () =>
              Navigator.pushNamed(context, section.route, arguments: section.arguments),
        ),
      ),
    );
  }

  /// The whole label+switch area (with margin) is one opaque tap zone that
  /// only ever toggles visibility — it never lets the tap reach the
  /// ListTile's onTap (which opens the section). The inner Switch is
  /// visual only (IgnorePointer): letting it keep its own tap handling
  /// would race this GestureDetector in the gesture arena. While saving,
  /// taps are swallowed here (still never reaching the ListTile) but do
  /// nothing, and the spinner takes the exact space the switch would.
  Widget _buildSectionSwitch(AdminAsdSection section) {
    final isVisible = _visibilityMap[section.key] ?? false;
    final isSaving = _togglingKeys.contains(section.key);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSaving) return;
        _toggleVisibility(section.key, !isVisible);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: 22.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        : IgnorePointer(
                            child: _buildVisibilitySwitch(
                              value: isVisible,
                              onChanged: (_) {},
                            ),
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
}
