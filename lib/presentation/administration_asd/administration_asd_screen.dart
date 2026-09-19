import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

/// Definition of one "Amministrazione ASD" section. Adding a future section
/// is adding one more entry to [AdministrationAsdScreen._sections] —
/// nothing else in this screen needs to change.
class _AsdSection {
  const _AsdSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.isVisible,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  /// For now this only ever returns true for the principal admin — kept as
  /// a function so a future section can define its own visibility rule.
  final bool Function(bool isPrincipalAdmin) isVisible;
}

/// "Amministrazione ASD": a list of admin sections, visible only to the
/// principal admin. For Fase 1 it lists only "Registro di Cassa".
class AdministrationAsdScreen extends StatefulWidget {
  const AdministrationAsdScreen({Key? key}) : super(key: key);

  @override
  State<AdministrationAsdScreen> createState() =>
      _AdministrationAsdScreenState();
}

class _AdministrationAsdScreenState extends State<AdministrationAsdScreen> {
  static final List<_AsdSection> _sections = [
    _AsdSection(
      title: 'Registro di Cassa',
      subtitle: 'Entrate e uscite in contanti, prima nota mensile',
      icon: Icons.point_of_sale_outlined,
      route: AppRoutes.cashRegister,
      isVisible: (isPrincipalAdmin) => isPrincipalAdmin,
    ),
  ];

  bool _isLoading = true;
  bool _isPrincipalAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final isPrincipal = await AuthService.instance.isPrincipalAdmin();
    if (!mounted) return;
    setState(() {
      _isPrincipalAdmin = isPrincipal;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isPrincipalAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Amministrazione ASD')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Accesso riservato all\'amministratore principale.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final visibleSections =
        _sections.where((s) => s.isVisible(_isPrincipalAdmin)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Amministrazione ASD')),
      body: ListView.separated(
        padding: EdgeInsets.all(4.w),
        itemCount: visibleSections.length,
        separatorBuilder: (context, index) => SizedBox(height: 1.5.h),
        itemBuilder: (context, index) {
          final section = visibleSections[index];
          return Card(
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
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pushNamed(context, section.route),
            ),
          );
        },
      ),
    );
  }
}
