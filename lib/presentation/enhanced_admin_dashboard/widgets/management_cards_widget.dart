import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

class ManagementCardsWidget extends StatelessWidget {
  const ManagementCardsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> managementOptions = [
      {
        'title': 'Gestione Utenti',
        'subtitle': 'Controllo ruoli e assegnazioni',
        'icon': Icons.group,
        'color': Theme.of(context).colorScheme.secondary,
        'route': '/admin-management-system',
        'description': 'Amministra utenti, ruoli e permessi',
        'status': 'Funzionale',
        'badgeColor': Colors.green,
      },
      {
        'title': 'Generazione Ricevute',
        'subtitle': 'Elaborazione automatizzata',
        'icon': Icons.receipt_long,
        'color': Colors.green,
        'route': '/receipt-generation-system',
        'description': 'Sistema automatico di fatturazione',
        'status': 'Attivo',
        'badgeColor': Colors.blue,
      },
      {
        'title': 'Gestione Eventi',
        'subtitle': 'Seminari e stage programmatici',
        'icon': Icons.event_note,
        'color': Colors.blue,
        'route': '/admin-event-management',
        'description': 'Organizza seminari, stage e eventi',
        'status': 'Disponibile',
        'badgeColor': Colors.orange,
      },
      {
        'title': 'Programmazione Discipline',
        'subtitle': 'Assegnazioni istruttori',
        'icon': Icons.sports_martial_arts,
        'color': Colors.orange,
        'route': '/admin-discipline-management',
        'description': 'Gestisci BJJ, MMA, SAMBO e istruttori',
        'status': 'Configurato',
        'badgeColor': Colors.purple,
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              SizedBox(width: 2.w),
              Text(
                'Gestione dei Sistemi Amministrativi',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.3),
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
                    'Navigazione completamente ricostruita e funzionale per tutti i sistemi Team Ragnarok',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
              childAspectRatio: 0.82,
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
      BuildContext context, Map<String, dynamic> option) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();

          // Show loading indicator briefly
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text('Caricamento ${option['title']}...'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // Navigate to the route
          Future.delayed(Duration(milliseconds: 300), () {
            Navigator.pushNamed(context, option['route']);
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
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge and Icon Row
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: (option['color'] as Color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      option['icon'],
                      color: option['color'],
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: (option['badgeColor'] as Color)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (option['badgeColor'] as Color)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      option['status'],
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w600,
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
                    ),
              ),
              SizedBox(height: 0.5.h),

              // Subtitle
              Text(
                option['subtitle'],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              SizedBox(height: 1.h),

              // Description
              Text(
                option['description'],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      height: 1.3,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),

              // Action Row with enhanced visual feedback
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                  vertical: 1.h,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.1),
                      Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.launch,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 14,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Accedi al Sistema',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.all(1.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 12,
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
