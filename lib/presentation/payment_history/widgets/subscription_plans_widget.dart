import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class SubscriptionPlansWidget extends StatelessWidget {
  final Function(int)? onTabChanged;
  final Function(Map<String, dynamic>)? onPlanSelected;

  const SubscriptionPlansWidget({
    Key? key,
    this.onTabChanged,
    this.onPlanSelected,
  }) : super(key: key);

  final List<Map<String, dynamic>> _subscriptionPlans = const [
    // NEW ENTRY-BASED PLANS - Featured at top
    {
      "id": 10,
      "title": "Ingresso singolo",
      "price": 10,
      "frequency": "Per ingresso",
      "disciplines": ["Accesso singolo"],
      "classesPerWeek": 1,
      "entryBased": true,
      "entryCount": 1,
      "benefits": [
        "Un singolo accesso agli allenamenti",
        "Nessuna data di scadenza",
        "Perfetto per provare"
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QQE90R7O",
      "color": 0xFF4CAF50,
    },
    {
      "id": 11,
      "title": "Pacchetto 10 ingressi",
      "price": 80,
      "frequency": "10 ingressi",
      "disciplines": ["Accesso multiplo"],
      "classesPerWeek": 10,
      "entryBased": true,
      "entryCount": 10,
      "benefits": [
        "10 ingressi agli allenamenti",
        "Nessuna data di scadenza",
        "Scade al finire degli ingressi",
        "Risparmio rispetto all'ingresso singolo"
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QR3160IO",
      "color": 0xFF2E7D32,
    },
    // EXISTING MONTHLY PLANS
    {
      "id": 1,
      "title": "Corso Singolo",
      "price": 60,
      "frequency": "Mensile",
      "disciplines": ["MMA o BJJ", "Grappling", "Sambo"],
      "classesPerWeek": 4,
      "entryBased": false,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Grappling e Sambo sempre inclusi",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QHVYXRZR",
      "color": 0xFFD32F2F,
    },
    {
      "id": 7,
      "title": "Corso Singolo (in convenzione)",
      "price": 50,
      "frequency": "Mensile",
      "disciplines": ["MMA o BJJ", "Grappling", "Sambo"],
      "classesPerWeek": 4,
      "entryBased": false,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Grappling e Sambo sempre inclusi",
        "Tariffa agevolata in convenzione",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QPQ08OQA",
      "color": 0xFFFF6B35,
    },
    {
      "id": 8,
      "title": "Doppio corso (in convenzione)",
      "price": 75,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo"],
      "classesPerWeek": 6,
      "entryBased": false,
      "benefits": [
        "Accesso a tutte le discipline",
        "Allenamenti intensivi",
        "Tariffa agevolata in convenzione",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QR42R0RH",
      "color": 0xFF4A90E2,
    },
    {
      "id": 2,
      "title": "Doppio Corso",
      "price": 95,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo"],
      "classesPerWeek": 6,
      "entryBased": false,
      "benefits": ["Accesso a tutte le discipline", "Allenamenti intensivi"],
      "sumupUrl": "https://pay.sumup.com/b2c/QZLJXISP",
      "color": 0xFF1976D2,
    },
    {
      "id": 3,
      "title": "Preparazione Atletica",
      "price": 30,
      "frequency": "Mensile",
      "disciplines": ["Preparazione Atletica"],
      "classesPerWeek": 2,
      "entryBased": false,
      "benefits": [
        "Focus su condizionamento fisico",
        "Allenamento personalizzato",
        "Programmi specifici",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QU0R8I0A",
      "color": 0xFF388E3C,
    },
    {
      "id": 4,
      "title": "Corso Singolo + Preparazione",
      "price": 90,
      "frequency": "Mensile",
      "disciplines": ["MMA o BJJ", "Grappling", "Sambo", "Prep. Atletica"],
      "classesPerWeek": 6,
      "entryBased": false,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Grappling e Sambo sempre inclusi",
        "Preparazione atletica completa",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QQ9F1KED",
      "color": 0xFFF57F17,
    },
    {
      "id": 5,
      "title": "Doppio Corso + Preparazione",
      "price": 120,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo", "Prep. Atletica"],
      "classesPerWeek": 8,
      "entryBased": false,
      "benefits": [
        "Tutte le discipline incluse",
        "Piano di allenamento completo",
        "Massima intensità",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QR5I6ZO7",
      "color": 0xFF7B1FA2,
    },
    {
      "id": 9,
      "title": "Doppio corso + Prep. Atl. (in conv.)",
      "price": 105,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo", "Prep. Atletica"],
      "classesPerWeek": 8,
      "entryBased": false,
      "benefits": [
        "Tutte le discipline incluse",
        "Piano di allenamento completo",
        "Preparazione atletica completa",
        "Tariffa agevolata in convenzione",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QT4LT4XQ",
      "color": 0xFF9C27B0,
    },
    {
      "id": 6,
      "title": "Iscrizione Annuale",
      "price": 30,
      "frequency": "Annuale",
      "disciplines": ["Iscrizione Base"],
      "classesPerWeek": 0,
      "entryBased": false,
      "benefits": ["Quota associativa annuale", "Accesso agli eventi del team"],
      "sumupUrl": "https://pay.sumup.com/b2c/Q0ND0EKY",
      "color": 0xFF5D4037,
    },
  ];

  void _onSubscriptionSelect(BuildContext context, Map<String, dynamic> plan) {
    // Store selected plan data for payment tab
    if (onPlanSelected != null) {
      onPlanSelected!(plan);
    }

    // Show toast message for plan selection
    Fluttertoast.showToast(
      msg: 'Piano selezionato: ${plan['title']}',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );

    // Navigate to payment tab
    if (onTabChanged != null) {
      onTabChanged!(0); // Switch to "Paga" tab (index 0)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'subscriptions',
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Abbonamenti',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                'Scegli il piano perfetto per le tue esigenze',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),

                  // New entry-based plans highlight
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'new_releases',
                          color: Colors.green,
                          size: 24,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            'Nuovi piani ad ingresso: nessuna scadenza, paghi solo quello che usi!',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),

          // Plans Grid
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 3.w,
                mainAxisSpacing: 2.h,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final plan = _subscriptionPlans[index];
                final color = Color(plan['color'] as int);
                final isEntryBased = plan['entryBased'] ?? false;
                final entryCount = plan['entryCount'] ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onSubscriptionSelect(context, plan),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with price and NEW badge
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(2.w),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CustomIconWidget(
                                    iconName: isEntryBased
                                        ? 'confirmation_number'
                                        : 'fitness_center',
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2.w,
                                    vertical: 0.5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '€${plan['price']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2.h),

                            // NEW badge for entry-based plans
                            if (isEntryBased) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 2.w, vertical: 0.5.h),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'NUOVO',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                              SizedBox(height: 1.h),
                            ],

                            // Title
                            Text(
                              plan['title'] as String,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 1.h),

                            // Frequency or entries
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 2.w, vertical: 0.5.h),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isEntryBased
                                    ? (entryCount > 1
                                        ? '$entryCount ingressi'
                                        : '1 ingresso')
                                    : plan['frequency'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            SizedBox(height: 1.h),

                            // Entry info or classes per week
                            if (isEntryBased) ...[
                              Row(
                                children: [
                                  CustomIconWidget(
                                    iconName: 'schedule',
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    size: 14,
                                  ),
                                  SizedBox(width: 1.w),
                                  Expanded(
                                    child: Text(
                                      'Nessuna scadenza',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if ((plan['classesPerWeek'] as int) > 0) ...[
                              Row(
                                children: [
                                  CustomIconWidget(
                                    iconName: 'calendar_today',
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    size: 14,
                                  ),
                                  SizedBox(width: 1.w),
                                  Text(
                                    '${plan['classesPerWeek']} lezioni/settimana',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ],

                            const Spacer(),

                            // Action button
                            Container(
                              width: double.infinity,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      _onSubscriptionSelect(context, plan),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 1.5.h),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isEntryBased
                                              ? 'Acquista'
                                              : 'Sottoscrivi',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        SizedBox(width: 1.w),
                                        CustomIconWidget(
                                          iconName: 'arrow_forward',
                                          color: color,
                                          size: 16,
                                        ),
                                      ],
                                    ),
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
              }, childCount: _subscriptionPlans.length),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.all(4.w),
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'security',
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'Tutti i pagamenti sono protetti da sistemi di sicurezza avanzati SumUp con crittografia SSL',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),
    );
  }
}
