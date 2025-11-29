import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import './widgets/subscription_option_card_widget.dart';

class SubscriptionPlanSelection extends StatefulWidget {
  const SubscriptionPlanSelection({Key? key}) : super(key: key);

  @override
  State<SubscriptionPlanSelection> createState() =>
      _SubscriptionPlanSelectionState();
}

class _SubscriptionPlanSelectionState extends State<SubscriptionPlanSelection>
    with WidgetsBindingObserver {
  bool _showSubscriptionOptions = false;
  bool _isLoading = false;
  int? _selectedPlanId;

  final List<Map<String, dynamic>> _subscriptionPlans = [
// NEW ENTRY-BASED PLANS
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
      "disciplines": ["MMA o BJJ"],
      "classesPerWeek": 4,
      "entryBased": false,
      "benefits": ["Scelta tra MMA o BJJ ogni mese"],
      "sumupUrl": "https://pay.sumup.com/b2c/QHVYXRZR",
      "color": 0xFFD32F2F,
    },
    {
      "id": 7,
      "title": "Corso Singolo (in convenzione)",
      "price": 50,
      "frequency": "Mensile",
      "disciplines": ["MMA o BJJ"],
      "classesPerWeek": 4,
      "entryBased": false,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Tariffa agevolata in convenzione",
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QPQ08OQA",
      "color": 0xFFFF6B35,
    },
    {
      "id": 2,
      "title": "Doppio Corso",
      "price": 95,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA"],
      "classesPerWeek": 6,
      "entryBased": false,
      "benefits": ["Accesso a tutte le discipline", "Allenamenti intensivi"],
      "sumupUrl": "https://pay.sumup.com/b2c/QZLJXISP",
      "color": 0xFF1976D2,
    },
    {
      "id": 8,
      "title": "Doppio corso (in convenzione)",
      "price": 75,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA"],
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
      "disciplines": ["MMA o BJJ", "Prep. Atletica"],
      "classesPerWeek": 6,
      "entryBased": false,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
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
      "disciplines": ["BJJ", "MMA", "Prep. Atletica"],
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
      "disciplines": ["BJJ", "MMA", "Prep. Atletica"],
      "classesPerWeek": 8,
      "entryBased": false,
      "benefits": [
        "Tutte le discipline incluse",
        "Piano di allenamento completo",
        "Massima intensità",
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _checkPaymentConfirmation();
    }
  }

  Future<void> _checkPaymentConfirmation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPaymentPending = prefs.getBool('isPaymentPending') ?? false;

      if (isPaymentPending && mounted) {
        // Navigate to payment history which will show the dialog
        Navigator.pushReplacementNamed(context, AppRoutes.paymentHistory);
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _launchSumUpUrl(String url, String planTitle) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Find the selected plan details
      final selectedPlan = _subscriptionPlans.firstWhere(
        (plan) => plan['title'] == planTitle,
        orElse: () => {},
      );

      // Set payment pending flag before launching external URL
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', true);
      await prefs.setString('pendingPlanId', selectedPlan['id'].toString());
      await prefs.setString('pendingPlanTitle', planTitle);
      await prefs.setDouble(
          'pendingPlanAmount', (selectedPlan['price'] as num).toDouble());
      await prefs.setString('pendingPaymentMethod', 'sumup');

      final Uri uri = Uri.parse(url);

      // Show loading for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // Clear pending flag if launch failed
        await prefs.setBool('isPaymentPending', false);

        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Impossibile aprire il link di pagamento',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Reindirizzamento al pagamento per $planTitle',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      // Clear pending flag on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', false);

      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Errore durante il reindirizzamento: ${e.toString()}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedPlanId = null;
        });
      }
    }
  }

  void _handlePlanSelection(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlanId = plan['id'];
    });

    _launchSumUpUrl(plan['sumupUrl'], plan['title']);
  }

  void _showSubscriptionPlans() {
    setState(() {
      _showSubscriptionOptions = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (_showSubscriptionOptions) {
              setState(() {
                _showSubscriptionOptions = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _showSubscriptionOptions ? 'Selezione Piano' : 'Team Ragnarok',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showSubscriptionOptions
            ? _buildSubscriptionOptionsView()
            : _buildInitialView(),
      ),
    );
  }

  Widget _buildInitialView() {
    return Container(
      key: const ValueKey('initial'),
      padding: EdgeInsets.all(6.w),
      child: Column(
        children: [
          // Header with Team Logo
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.lightTheme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/149054-1756525854643.jpg',
                      width: 25.w,
                      height: 25.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Team Ragnarok',
                  style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Scegli il tuo piano di allenamento\ne inizia il tuo percorso',
                  textAlign: TextAlign.center,
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Choose Plan Button
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 7.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.lightTheme.colorScheme.primary,
                        AppTheme.lightTheme.colorScheme.primary.withValues(
                          alpha: 0.8,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showSubscriptionPlans,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomIconWidget(
                              iconName: 'payment',
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Scegli Piano',
                              style: AppTheme.lightTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            CustomIconWidget(
                              iconName: 'arrow_forward',
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.lightTheme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'security',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          'Pagamenti sicuri tramite SumUp con crittografia SSL',
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.primary,
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
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptionsView() {
    return Container(
      key: const ValueKey('options'),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary.withValues(
                alpha: 0.1,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Team Ragnarok logo above team name
                Container(
                  margin: EdgeInsets.only(bottom: 2.h),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/149054-1756525854643.jpg',
                      width: 20.w,
                      height: 15.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Team Ragnarok',
                      style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'Seleziona il tuo abbonamento',
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Entry-based plans notice
          Container(
            margin: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
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
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'NUOVO: Piani ad ingresso singolo o multiplo - non scadono mai!',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Important Notice about included courses
          Container(
            margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.primary.withValues(
                  alpha: 0.3,
                ),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Grappling e Sambo sono sempre compresi sia nel corso singolo che nel doppio corso',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Subscription Plans Grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 3.w,
                mainAxisSpacing: 2.h,
              ),
              itemCount: _subscriptionPlans.length,
              itemBuilder: (context, index) {
                final plan = _subscriptionPlans[index];
                final isLoading = _isLoading && _selectedPlanId == plan['id'];

                return SubscriptionOptionCardWidget(
                  plan: plan,
                  onTap: () => _handlePlanSelection(plan),
                  isLoading: isLoading,
                );
              },
            ),
          ),

          SizedBox(height: 2.h),
        ],
      ),
    );
  }
}
