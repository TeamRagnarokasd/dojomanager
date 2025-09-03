import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import './widgets/payment_method_section_widget.dart';
import './widgets/subscription_card_widget.dart';

class SubscriptionSelection extends StatefulWidget {
  const SubscriptionSelection({super.key});

  @override
  State<SubscriptionSelection> createState() => _SubscriptionSelectionState();
}

class _SubscriptionSelectionState extends State<SubscriptionSelection> {
  int? _selectedSubscriptionId;
  bool _isLoading = false;
  String? _selectedPaymentMethod;
  String? _previouslySelectedPaymentMethod;

  final List<Map<String, dynamic>> _subscriptionPlans = [
    {
      "id": 1,
      "title": "Corso Singolo",
      "price": 60,
      "frequency": "Mensile",
      "disciplines": ["MMA o BJJ (mensile)", "Grappling", "Sambo"],
      "classesPerWeek": 4,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Grappling e Sambo sempre inclusi"
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QHVYXRZR",
      "color": 0xFFD32F2F,
    },
    {
      "id": 7,
      "title": "Corso Singolo (in convenzione)",
      "price": 50,
      "frequency": "Mensile",
      "disciplines": ["MMA o BJJ (mensile)", "Grappling", "Sambo"],
      "classesPerWeek": 4,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Grappling e Sambo sempre inclusi",
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
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo"],
      "classesPerWeek": 6,
      "benefits": ["Accesso a tutte le discipline", "Allenamenti intensivi"],
      "sumupUrl": "https://pay.sumup.com/b2c/QZLJXISP",
      "color": 0xFF1976D2,
    },
    {
      "id": 8,
      "title": "Doppio corso (in convenzione)",
      "price": 75,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo"],
      "classesPerWeek": 6,
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
      "benefits": [
        "Focus su condizionamento fisico",
        "Allenamento personalizzato",
        "Programmi specifici"
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QU0R8I0A",
      "color": 0xFF388E3C,
    },
    {
      "id": 4,
      "title": "Corso Singolo + Prep. Atletica",
      "price": 90,
      "frequency": "Mensile",
      "disciplines": [
        "MMA o BJJ (mensile)",
        "Grappling",
        "Sambo",
        "Prep. Atletica"
      ],
      "classesPerWeek": 6,
      "benefits": [
        "Scelta tra MMA o BJJ ogni mese",
        "Grappling e Sambo sempre inclusi",
        "Preparazione atletica completa"
      ],
      "sumupUrl": "https://pay.sumup.com/b2c/QQ9F1KED",
      "color": 0xFFF57F17,
    },
    {
      "id": 5,
      "title": "Doppio Corso + Prep. Atletica",
      "price": 120,
      "frequency": "Mensile",
      "disciplines": ["BJJ", "MMA", "Grappling", "Sambo", "Prep. Atletica"],
      "classesPerWeek": 8,
      "benefits": [
        "Tutte le discipline incluse",
        "Piano di allenamento completo",
        "Massima intensità"
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
      "benefits": ["Quota associativa annuale", "Accesso agli eventi del team"],
      "sumupUrl": "https://pay.sumup.com/b2c/Q0ND0EKY",
      "color": 0xFF5D4037,
    },
  ];

  // Satispay URL for all subscriptions
  final String _satispayUrl =
      "https://www.satispay.com/app/pay/shops/58875f70-d796-4596-a2f6-12fe91a8c202";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get payment method from previous screen argument
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String && _previouslySelectedPaymentMethod == null) {
      _previouslySelectedPaymentMethod = arguments;
      _selectedPaymentMethod = arguments;
    }
  }

  void _selectSubscription(int subscriptionId) {
    setState(() {
      _selectedSubscriptionId = subscriptionId;
    });

    // If payment method was already selected, proceed directly to payment
    if (_previouslySelectedPaymentMethod != null) {
      _proceedToPayment();
    }
  }

  void _selectPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
  }

  bool get _canProceedToPayment =>
      _selectedSubscriptionId != null && _selectedPaymentMethod != null;

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire il link di pagamento'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _proceedToPayment() async {
    if (!_canProceedToPayment) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedPlan = _subscriptionPlans
          .firstWhere((plan) => plan['id'] == _selectedSubscriptionId);

      String redirectUrl;

      // Determine redirect URL based on payment method
      if (_selectedPaymentMethod == 'sumup') {
        // Use specific SumUp URL for each subscription
        redirectUrl = selectedPlan['sumupUrl'] as String;
      } else if (_selectedPaymentMethod == 'satispay') {
        // Use same Satispay URL for all subscriptions
        redirectUrl = _satispayUrl;
      } else {
        throw Exception('Metodo di pagamento non supportato');
      }

      // Show loading for better UX
      await Future.delayed(const Duration(milliseconds: 800));

      // Launch the payment URL
      await _launchUrl(redirectUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reindirizzamento al pagamento per ${selectedPlan['title']}',
            ),
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Errore durante il reindirizzamento: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Selezione Abbonamento',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header with Team Logo
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                CustomImageWidget(
                  imageUrl: AppConstants.teamLogo,
                  width: 20.w,
                  height: 20.w,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Team Ragnarok',
                  style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                Text(
                  _previouslySelectedPaymentMethod != null
                      ? 'Seleziona il tuo abbonamento e procedi al pagamento'
                      : 'Scegli il tuo piano di allenamento',
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                // Show payment method indicator if already selected
                if (_previouslySelectedPaymentMethod != null) ...[
                  SizedBox(height: 1.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: AppTheme.lightTheme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: _previouslySelectedPaymentMethod == 'sumup'
                              ? 'payment'
                              : 'smartphone',
                          color: AppTheme.lightTheme.colorScheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Pagamento via ${_previouslySelectedPaymentMethod == 'sumup' ? 'SumUp' : 'Satispay'}',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Subscription Plans
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              itemCount: _subscriptionPlans.length,
              itemBuilder: (context, index) {
                final plan = _subscriptionPlans[index];
                return SubscriptionCardWidget(
                  plan: plan,
                  isSelected: _selectedSubscriptionId == plan['id'],
                  isMonthly: true,
                  onTap: () => _selectSubscription(plan['id']),
                  preselectedPaymentMethod: _previouslySelectedPaymentMethod,
                  isLoading:
                      _isLoading && _selectedSubscriptionId == plan['id'],
                );
              },
            ),
          ),

          // Payment Method Section - Only show if no payment method was pre-selected
          if (_selectedSubscriptionId != null &&
              _previouslySelectedPaymentMethod == null)
            PaymentMethodSectionWidget(
              selectedMethod: _selectedPaymentMethod,
              onMethodSelected: _selectPaymentMethod,
              isFromPreviousSelection: false,
            ),

          // Proceed to Payment Button - Only show if payment method was NOT pre-selected
          if (_previouslySelectedPaymentMethod == null)
            Container(
              padding: EdgeInsets.all(4.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceedToPayment && !_isLoading
                      ? _proceedToPayment
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 3.h,
                          width: 3.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Procedi al Pagamento',
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
