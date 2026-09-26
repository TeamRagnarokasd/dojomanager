import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/admin_section_visibility_service.dart';
import '../../../services/asd_deadlines_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../administration_asd/administration_asd_screen.dart';

class ManagementCardsWidget extends StatefulWidget {
  final VoidCallback? onNavigateReturn;

  const ManagementCardsWidget({Key? key, this.onNavigateReturn})
    : super(key: key);

  @override
  State<ManagementCardsWidget> createState() => _ManagementCardsWidgetState();
}

class _ManagementCardsWidgetState extends State<ManagementCardsWidget>
    with WidgetsBindingObserver {
  bool _showAdministrationAsdCard = false;

  /// Badge shown on the "Amministrazione ASD" card — overdue/due-soon count
  /// from the Scadenzario, only for admins with access to 'deadlines'.
  int? _asdDeadlinesBadgeCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAdministrationAsdVisibility();
    _loadAsdDeadlinesBadgeAndNotify();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// This widget sits on the admin dashboard, mounted right after login and
  /// normally kept alive as the base route — the natural place to detect
  /// "app startup and foreground-resume" for the Scadenzario notifications.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAsdDeadlinesBadgeAndNotify();
    }
  }

  /// Refreshes the "Amministrazione ASD" card badge and, on startup/resume,
  /// fires the local notifications for overdue/due-soon Scadenzario items —
  /// only for admins with access to the 'deadlines' section.
  Future<void> _loadAsdDeadlinesBadgeAndNotify() async {
    try {
      final canAccessDeadlines =
          await AdminSectionVisibilityService.instance.canAccess('deadlines');
      if (!canAccessDeadlines) {
        if (mounted) setState(() => _asdDeadlinesBadgeCount = null);
        return;
      }
      final summary = await AsdDeadlinesService.instance.getPendingSummary();
      if (mounted) setState(() => _asdDeadlinesBadgeCount = summary.pendingCount);
      if (!kIsWeb) {
        await NotificationService().showAsdDeadlineAlerts(summary);
      }
    } catch (_) {
      // Not critical — the card just shows no badge.
    }
  }

  /// "Amministrazione ASD" shows when can_access_admin_section returns true
  /// for the umbrella key AND at least one section inside it — if the RPC
  /// call fails, the principal admin still sees the card, other admins
  /// don't.
  Future<void> _checkAdministrationAsdVisibility() async {
    final isPrincipal = await AuthService.instance.isPrincipalAdmin();
    final visibilityService = AdminSectionVisibilityService.instance;
    bool show;
    try {
      final canAccessAsd = await visibilityService.canAccess(
        kAdministrationAsdKey,
      );
      show = false;
      if (canAccessAsd) {
        for (final section in kAdminAsdSections) {
          if (await visibilityService.canAccess(section.key)) {
            show = true;
            break;
          }
        }
      }
    } catch (_) {
      show = isPrincipal;
    }
    if (mounted) setState(() => _showAdministrationAsdCard = show);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> managementOptions = [
      // Row 1: Core Management
      {
        'title': 'Sponsor, Collab e Affiliazioni',
        'subtitle': 'Partner commerciali, collaborazioni e affiliazioni',
        'icon': Icons.business,
        'color': Colors.purple,
        'route': '/admin-sponsor-management',
        'description':
            'Gestisci sponsor, partnership commerciali e affiliazioni/certificazioni del team',
        'status': 'Funzionale',
        'badgeColor': Colors.blue,
        'category': 'core',
      },

      // Row 2: Financial Management
      {
        'title': 'instructor_management.title'.tr(),
        'subtitle': 'Profili, foto e corsi associati',
        'icon': Icons.person_4,
        'color': Colors.deepOrange,
        'route': '/instructor-management-system',
        'description': 'Modifica descrizioni, foto e corsi di ogni istruttore',
        'status': 'Operativo',
        'badgeColor': Colors.deepOrange,
        'category': 'personnel',
      },

      // Row 3: Schedule & Events Management
      {
        'title': 'Palinsesto Stagionale',
        'subtitle': 'Programmazione corsi e calendari',
        'icon': Icons.calendar_today,
        'color': Colors.indigo,
        'route': '/seasonal-schedule-creation',
        'description': 'Gestisci programmazione stagionale completa',
        'status': 'Configurato',
        'badgeColor': Colors.indigo,
        'category': 'scheduling',
      },
      {
        'title': 'admin_event.title'.tr(),
        'subtitle': 'Seminari, stage e competizioni',
        'icon': Icons.event_note,
        'color': Colors.blue,
        'route': '/admin-event-management',
        'description': 'Organizza seminari, stage e eventi speciali',
        'status': 'Disponibile',
        'badgeColor': Colors.orange,
        'category': 'scheduling',
      },

      // Row 4: Discipline & Admin Management (REMOVED Communication Center)
      {
        'title': 'admin_discipline.title'.tr(),
        'subtitle': 'BJJ, MMA, SAMBO e istruttori',
        'icon': Icons.sports_martial_arts,
        'color': Colors.deepPurple,
        'route': '/admin-discipline-management',
        'description': 'Amministra discipline e assegnazioni istruttori',
        'status': 'Configurato',
        'badgeColor': Colors.purple,
        'category': 'disciplines',
      },
      // NEW: Gestione Abbonamenti Card
      {
        'title': 'Gestione Abbonamenti',
        'subtitle': 'Piani e abbonamenti personalizzati',
        'icon': Icons.card_membership,
        'color': Colors.amber,
        'route': '/plan-selection',
        'description': 'Gestisci piani di abbonamento e crea nuovi piani',
        'status': 'Attivo',
        'badgeColor': Colors.amber,
        'category': 'subscriptions',
      },
      // NEW: Profilo Card - Added next to Lista utenti
      {
        'title': 'Profilo',
        'subtitle': 'Dati amministratore principale',
        'icon': Icons.account_circle,
        'color': Colors.teal,
        'route': '/admin-profile',
        'description': 'Visualizza e modifica il tuo profilo amministratore',
        'status': 'Attivo',
        'badgeColor': Colors.teal,
        'category': 'admin',
      },

      // Row 5: Admin Management
      {
        'title': 'Lista utenti e comunicazioni',
        'subtitle': 'Controllo accessi e sicurezza',
        'icon': Icons.admin_panel_settings,
        'color': Colors.red,
        'route': '/admin-management-system',
        'description': 'Gestisci amministratori e permessi sistema',
        'status': 'Sicuro',
        'badgeColor': Colors.red,
        'category': 'admin',
      },
      // NEW: Amministrazione ASD — replaces the "Gestione Ricevute" and
      // "Dati Team / ASD" cards above, now moved inside this section (see
      // AdministrationAsdScreen), plus "Registro di Cassa". Visible per
      // can_access_admin_section (see _checkAdministrationAsdVisibility).
      if (_showAdministrationAsdCard)
        {
          'title': 'Amministrazione ASD',
          'subtitle': 'Registro di cassa e altre sezioni amministrative',
          'icon': Icons.account_balance_outlined,
          'color': Colors.brown,
          'route': AppRoutes.administrationAsd,
          'description':
              'Sezioni amministrative dell\'ASD: registro di cassa, ricevute e dati del team',
          'status': 'Riservato',
          'badgeColor': Colors.brown,
          'category': 'admin',
          'notificationCount':
              (_asdDeadlinesBadgeCount ?? 0) > 0 ? _asdDeadlinesBadgeCount : null,
        },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with enhanced design
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.dashboard,
                        color: Theme.of(context).colorScheme.onSecondary,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pannello di Controllo Amministrativo',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'Tutti i sistemi sono integrati con Supabase e operativi. Navigazione ottimizzata per amministratori.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Tutti i sistemi sono integrati con Supabase e operativi. Navigazione ottimizzata per amministratori.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Management Cards Grid - Enhanced Layout
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
              childAspectRatio:
                  0.75, // Slightly taller cards for better content
            ),
            itemCount: managementOptions.length,
            itemBuilder: (context, index) {
              final option = managementOptions[index];
              return _buildEnhancedManagementCard(context, option);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedManagementCard(
    BuildContext context,
    Map<String, dynamic> option,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();

          // Enhanced loading feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Caricamento ${option['title']}...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.all(4.w),
            ),
          );

          // Navigate after brief delay for better UX
          Future.delayed(Duration(milliseconds: 400), () {
            final route = option['route'] as String;
            Navigator.pushNamed(context, route).then((_) {
              widget.onNavigateReturn?.call();
            });
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (option['color'] as Color).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: (option['color'] as Color).withValues(alpha: 0.05),
                blurRadius: 40,
                offset: const Offset(0, 16),
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Icon and Status Badge
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              (option['color'] as Color).withValues(alpha: 0.15),
                              (option['color'] as Color).withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (option['color'] as Color).withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Icon(
                          option['icon'],
                          color: option['color'],
                          size: 28,
                        ),
                      ),
                      if (option['notificationCount'] != null)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${option['notificationCount']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (option['badgeColor'] as Color).withValues(
                            alpha: 0.15,
                          ),
                          (option['badgeColor'] as Color).withValues(
                            alpha: 0.08,
                          ),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (option['badgeColor'] as Color).withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Text(
                      option['status'],
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: option['badgeColor'],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),

              // Title
              Text(
                option['title'],
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 0.8.h),

              // Subtitle
              Text(
                option['subtitle'],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 1.h),

              // Description
              Expanded(
                child: Text(
                  option['description'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Action Button with Enhanced Design
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (option['color'] as Color).withValues(alpha: 0.12),
                      (option['color'] as Color).withValues(alpha: 0.06),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: (option['color'] as Color).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.launch_rounded,
                      color: option['color'],
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Accedi al Sistema',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: option['color'],
                          fontWeight: FontWeight.w700,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(1.2.w),
                      decoration: BoxDecoration(
                        color: (option['color'] as Color).withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (option['color'] as Color).withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: option['color'],
                        size: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
