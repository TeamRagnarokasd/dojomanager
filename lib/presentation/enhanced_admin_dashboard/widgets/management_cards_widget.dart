import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

class ManagementCardsWidget extends StatelessWidget {
  final VoidCallback? onNavigateReturn;

  const ManagementCardsWidget({Key? key, this.onNavigateReturn})
    : super(key: key);

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
        'title': 'receipt.management_title'.tr(),
        'subtitle': 'Sistema ricevute italiane integrato',
        'icon': Icons.receipt,
        'color': Colors.blue,
        'route': '/italian-receipt-generation',
        'description':
            'Sistema completo per ricevute fiscali italiane con integrazione Supabase',
        'status': 'Funzionale',
        'badgeColor': Colors.green,
        'category': 'financial',
      },
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
      // NEW: Dati Team / ASD Card
      {
        'title': 'Dati Team / ASD',
        'subtitle': 'Nome, indirizzo, C.F., PEC e contatti',
        'icon': Icons.business_center,
        'color': Colors.green,
        'route': '/admin-management-system',
        'description':
            'Modifica i dati ufficiali del team: ragione sociale, sede, codice fiscale e PEC per le ricevute',
        'status': 'Impostazioni',
        'badgeColor': Colors.green,
        'category': 'admin',
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
            final arguments = option['title'] == 'Dati Team / ASD'
                ? {'initialTab': 'settings'}
                : null;
            Navigator.pushNamed(context, route, arguments: arguments).then((_) {
              onNavigateReturn?.call();
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
