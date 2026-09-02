import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/discipline_service.dart';
import '../../../services/subscription_service.dart';

class PaymentConfirmationDialog extends StatefulWidget {
  final String paymentMethod;
  final VoidCallback onCancel;

  const PaymentConfirmationDialog({
    Key? key,
    required this.paymentMethod,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  bool _isSubmitting = false;
  String? _selectedPlanName;
  String? _selectedDiscipline;
  String? _selectedDiscipline2; // 🆕 Second discipline for Doppio Corso
  bool _showDetails = false;
  List<String> _availableDisciplines = [];
  bool _isLoadingDisciplines = false;
  List<Map<String, dynamic>> _allPlans = [];
  bool _isLoadingPlans = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableDisciplines();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPlans = true;
    });
    try {
      final plans = await SubscriptionService.getAllPlansForSatispay();
      if (!mounted) return;
      setState(() {
        _allPlans = plans;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allPlans = [];
        _isLoadingPlans = false;
      });
    }
  }

  Future<void> _loadAvailableDisciplines() async {
    setState(() {
      _isLoadingDisciplines = true;
    });

    try {
      // Use DisciplineService to get all active disciplines (including custom ones)
      final disciplineData = await DisciplineService.instance
          .getActiveDisciplines();
      setState(() {
        // Map discipline data to display names
        _availableDisciplines = disciplineData
            .map((d) {
              final name = (d['name'] ?? d['id'] ?? '')
                  .toString()
                  .toLowerCase();
              final displayName = d['display_name']?.toString();

              // Use display_name if available, otherwise map known values
              if (displayName != null && displayName.isNotEmpty) {
                return displayName;
              }

              switch (name) {
                case 'bjj':
                  return 'BJJ';
                case 'mma':
                  return 'MMA';
                case 'sambo':
                  return 'Sambo';
                case 'grappling':
                  return 'Grappling';
                case 'fitness':
                case 'prep_atletica':
                  return 'Fitness';
                case 'k1':
                  return 'K1';
                default:
                  // Capitalize first letter for unknown disciplines
                  return name.isNotEmpty
                      ? name[0].toUpperCase() + name.substring(1)
                      : name.toUpperCase();
              }
            })
            .toSet()
            .toList(); // Use Set to remove duplicates

        // Ensure "Fitness" is always available for Preparazione Atletica plans
        if (!_availableDisciplines.any(
          (d) =>
              d.toLowerCase() == 'fitness' ||
              d.toLowerCase() == 'preparazione atletica',
        )) {
          _availableDisciplines.add('Fitness');
        }

        _availableDisciplines.sort();
        _isLoadingDisciplines = false;
      });
    } catch (e) {
      print('Error loading disciplines: $e');
      // Fallback to default disciplines including K1
      setState(() {
        _availableDisciplines = [
          'BJJ',
          'Fitness',
          'Grappling',
          'K1',
          'MMA',
          'Sambo',
        ];
        _isLoadingDisciplines = false;
      });
    }
  }

  bool _shouldShowDisciplineDropdown() {
    if (_selectedPlanName == null) return false;

    final planNameLower = _selectedPlanName!.toLowerCase();

    // 🎯 RULE 1: "Iscrizione Annuale" - NO discipline required (null discipline is acceptable)
    if (planNameLower.contains('iscrizione annuale')) {
      return false;
    }

    // 🎯 RULE 2: "Doppio Corso" plans - Require TWO disciplines (separate method handles this)
    // Note: _shouldShowTwoDisciplineDropdowns() handles Doppio Corso plans
    if (planNameLower.contains('doppio corso') ||
        planNameLower.contains('doppio')) {
      return false;
    }

    // 🎯 RULE 3: Entry-based plans (Ingresso singolo, Pacchetto 10 ingressi) - NO discipline required
    if (planNameLower.contains('ingresso singolo') ||
        planNameLower.contains('pacchetto 10 ingressi')) {
      return false;
    }

    // 🎯 RULE 4: "Preparazione Atletica" (standalone) - Show dropdown with ONLY Fitness
    if (_isPreparazioneAtleticaPlan()) {
      return true;
    }

    // 🎯 RULE 5: "Corso Singolo" variants - Discipline REQUIRED (user must select one discipline)
    return planNameLower.contains('corso singolo');
  }

  // Check if the selected plan is "Preparazione Atletica" (standalone, not as part of combo)
  bool _isPreparazioneAtleticaPlan() {
    if (_selectedPlanName == null) return false;
    final planNameLower = _selectedPlanName!.toLowerCase();

    // "Preparazione Atletica" standalone plan (not "Corso Singolo + Preparazione" or "Doppio Corso + Preparazione")
    return planNameLower == 'preparazione atletica' ||
        (planNameLower.contains('preparazione atletica') &&
            !planNameLower.contains('corso singolo') &&
            !planNameLower.contains('doppio'));
  }

  // Get filtered disciplines based on selected plan
  List<String> _getDisciplinesForSelectedPlan() {
    // For "Preparazione Atletica" plan, only show "Fitness"
    if (_isPreparazioneAtleticaPlan()) {
      return ['Fitness'];
    }

    // For all other plans, show all disciplines
    return _availableDisciplines;
  }

  // 🆕 NEW: Check if plan requires TWO discipline selections (Doppio Corso)
  bool _shouldShowTwoDisciplineDropdowns() {
    if (_selectedPlanName == null) return false;

    final planNameLower = _selectedPlanName!.toLowerCase();

    // 🎯 "Doppio Corso" plans (without Preparazione) - Require TWO different disciplines
    if (planNameLower.contains('doppio corso') &&
        !planNameLower.contains('preparazione') &&
        !planNameLower.contains('prep.')) {
      return true;
    }

    // 🎯 "Doppio Corso + Preparazione Atletica" - Require TWO disciplines + fixed fitness
    if (planNameLower.contains('doppio corso') &&
        (planNameLower.contains('preparazione') ||
            planNameLower.contains('prep.'))) {
      return true;
    }

    return false;
  }

  // 🆕 NEW: Get available disciplines for selection (exclude already selected ones)
  List<String> _getAvailableDisciplinesForSelection1() {
    final planNameLower = _selectedPlanName?.toLowerCase() ?? '';

    // For "Doppio Corso + Preparazione" plans, exclude fitness (it's automatically included)
    if (planNameLower.contains('doppio corso') &&
        (planNameLower.contains('preparazione') ||
            planNameLower.contains('prep.'))) {
      return _availableDisciplines
          .where(
            (d) =>
                d.toLowerCase() != 'preparazione atletica' &&
                d.toLowerCase() != 'prep. atletica' &&
                d.toLowerCase() != 'fitness',
          )
          .toList();
    }

    // For first selection, allow all disciplines except fitness for regular Doppio Corso
    // (Doppio Corso = BJJ, MMA, Sambo, Grappling only)
    if (planNameLower.contains('doppio corso')) {
      return _availableDisciplines
          .where(
            (d) =>
                d.toLowerCase() != 'preparazione atletica' &&
                d.toLowerCase() != 'prep. atletica' &&
                d.toLowerCase() != 'fitness',
          )
          .toList();
    }

    return _availableDisciplines;
  }

  List<String> _getAvailableDisciplinesForSelection2() {
    // For second selection, exclude the first selected discipline to ensure different selection
    if (_selectedDiscipline == null) {
      return _getAvailableDisciplinesForSelection1();
    }

    final planNameLower = _selectedPlanName?.toLowerCase() ?? '';

    // For "Doppio Corso + Preparazione" plans, exclude fitness and first selected discipline
    if (planNameLower.contains('doppio corso') &&
        (planNameLower.contains('preparazione') ||
            planNameLower.contains('prep.'))) {
      return _availableDisciplines
          .where(
            (d) =>
                d != _selectedDiscipline &&
                d.toLowerCase() != 'preparazione atletica' &&
                d.toLowerCase() != 'prep. atletica' &&
                d.toLowerCase() != 'fitness',
          )
          .toList();
    }

    // For regular Doppio Corso, exclude first selected discipline and fitness
    if (planNameLower.contains('doppio corso')) {
      return _availableDisciplines
          .where(
            (d) =>
                d != _selectedDiscipline &&
                d.toLowerCase() != 'preparazione atletica' &&
                d.toLowerCase() != 'prep. atletica' &&
                d.toLowerCase() != 'fitness',
          )
          .toList();
    }

    // For regular Doppio Corso, exclude first selected discipline
    return _availableDisciplines
        .where((d) => d != _selectedDiscipline)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: 'payment',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'payment_confirm.subscription_details'.tr(),
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showDetails) ...[
              Text(
                'payment_confirm.payment_completed_question'.tr(),
                style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              // Plan selection dropdown
              Text(
                'payment_confirm.subscription_type'.tr(),
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              DropdownButtonFormField<String>(
                initialValue: _selectedPlanName,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 1.5.h,
                  ),
                ),
                hint: Text('subscription_ui.select_plan'.tr()),
                items: _allPlans.map((plan) {
                  return DropdownMenuItem<String>(
                    value: plan['name'] as String,
                    child: Text(
                      '${plan['name']} - €${(plan['price'] as num).toDouble().toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlanName = value;
                    // Reset disciplines when plan changes
                    _selectedDiscipline = null;
                    _selectedDiscipline2 = null;
                  });
                },
              ),
              SizedBox(height: 2.h),

              // 🆕 NEW: Two discipline selectors for Doppio Corso plans
              if (_shouldShowTwoDisciplineDropdowns()) ...[
                Text(
                  'payment_confirm.select_two_disciplines'.tr(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '* ${'payment.double_course_required'.tr()}',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.red[600],
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 1.h),

                // First discipline dropdown
                Text(
                  'payment.first_discipline'.tr(),
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                _isLoadingDisciplines
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedDiscipline,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _selectedDiscipline == null
                                  ? Colors.red
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.5.h,
                          ),
                        ),
                        hint: Text('validation.select_first_discipline'.tr()),
                        items: _getAvailableDisciplinesForSelection1().map((
                          discipline,
                        ) {
                          return DropdownMenuItem<String>(
                            value: discipline,
                            child: Text(discipline),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDiscipline = value;
                            // Reset second discipline if it matches the new first selection
                            if (_selectedDiscipline2 == value) {
                              _selectedDiscipline2 = null;
                            }
                          });
                        },
                      ),
                SizedBox(height: 1.5.h),

                // Second discipline dropdown
                Text(
                  'payment.second_discipline'.tr(),
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                _isLoadingDisciplines
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedDiscipline2,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _selectedDiscipline2 == null
                                  ? Colors.red
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.5.h,
                          ),
                        ),
                        hint: Text(
                          _selectedDiscipline == null
                              ? 'payment_confirm.select_first_discipline_first'
                                    .tr()
                              : 'payment_confirm.select_second_discipline_hint'
                                    .tr(),
                        ),
                        items: _getAvailableDisciplinesForSelection2().map((
                          discipline,
                        ) {
                          return DropdownMenuItem<String>(
                            value: discipline,
                            child: Text(discipline),
                          );
                        }).toList(),
                        onChanged: _selectedDiscipline == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedDiscipline2 = value;
                                });
                              },
                      ),
                SizedBox(height: 1.h),

                // Info for Doppio Corso + Preparazione
                Builder(
                  builder: (context) {
                    final planNameForInfo =
                        _selectedPlanName?.toLowerCase() ?? '';
                    if (planNameForInfo.contains('preparazione') ||
                        planNameForInfo.contains('prep.')) {
                      return Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(2.w),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue[700],
                                ),
                                SizedBox(width: 2.w),
                                Expanded(
                                  child: Text(
                                    'receipt.preparazione_included'.tr(),
                                    style: AppTheme
                                        .lightTheme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.blue[900],
                                          fontSize: 11.sp,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 1.h),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'payment.book_both_disciplines'.tr(),
                          style: AppTheme.lightTheme.textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.blue[900],
                                fontSize: 11.sp,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
              ] else if (_shouldShowDisciplineDropdown()) ...[
                // Single discipline selector for Corso Singolo or Preparazione Atletica
                Text(
                  _isPreparazioneAtleticaPlan()
                      ? 'payment_confirm.associated_discipline'.tr()
                      : 'payment.choose_discipline'.tr(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isPreparazioneAtleticaPlan()
                        ? Colors.blue[700]
                        : Colors.red[700],
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  _isPreparazioneAtleticaPlan()
                      ? 'payment_confirm.fitness_only'.tr()
                      : '* ${'payment.required_field_note'.tr()}',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: _isPreparazioneAtleticaPlan()
                        ? Colors.blue[600]
                        : Colors.red[600],
                    fontSize: 11.sp,
                  ),
                ),
                SizedBox(height: 1.h),
                _isLoadingDisciplines
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        initialValue: _isPreparazioneAtleticaPlan()
                            ? 'Fitness' // Auto-select Fitness for Preparazione Atletica
                            : _selectedDiscipline,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color:
                                  _selectedDiscipline == null &&
                                      !_isPreparazioneAtleticaPlan()
                                  ? Colors.red
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.5.h,
                          ),
                        ),
                        hint: Text('validation.select_discipline'.tr()),
                        items: _getDisciplinesForSelectedPlan().map((
                          discipline,
                        ) {
                          return DropdownMenuItem<String>(
                            value: discipline,
                            child: Text(discipline),
                          );
                        }).toList(),
                        onChanged: _isPreparazioneAtleticaPlan()
                            ? null // Disable dropdown for Preparazione Atletica (only Fitness)
                            : (value) {
                                setState(() {
                                  _selectedDiscipline = value;
                                });
                              },
                      ),
                SizedBox(height: 1.h),
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          _isPreparazioneAtleticaPlan()
                              ? 'payment.fitness_only_note'.tr()
                              : 'payment.booking_scope_single'.tr(),
                          style: AppTheme.lightTheme.textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.blue[900],
                                fontSize: 11.sp,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
              ],

              // Info text
              if (_selectedPlanName != null) ...[
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'payment.non_fiscal_invoice_note'.tr(),
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (!_showDetails) ...[
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'common.no'.tr(),
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showDetails = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightTheme.colorScheme.primary,
              foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
            ),
            child: Text(
              'common.yes'.tr(),
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    setState(() {
                      _showDetails = false;
                      _selectedPlanName = null;
                      _selectedDiscipline = null;
                      _selectedDiscipline2 = null;
                    });
                  },
            child: Text(
              'common.back'.tr(),
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed:
                _isSubmitting ||
                    _selectedPlanName == null ||
                    (_shouldShowDisciplineDropdown() &&
                        !_isPreparazioneAtleticaPlan() &&
                        _selectedDiscipline == null) ||
                    (_shouldShowTwoDisciplineDropdowns() &&
                        (_selectedDiscipline == null ||
                            _selectedDiscipline2 == null))
                ? null
                : _handleConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightTheme.colorScheme.primary,
              foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.lightTheme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    'payment_confirm.confirm_subscription'.tr(),
                    style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleConfirmation() async {
    if (_selectedPlanName == null) return;

    final planNameLower = _selectedPlanName!.toLowerCase();

    // 🎯 RULE 1: "Iscrizione Annuale" - Accept null discipline (no discipline required)
    if (planNameLower.contains('iscrizione annuale')) {
      // Explicitly set disciplines to null for annual membership
      _selectedDiscipline = null;
      _selectedDiscipline2 = null;
    }

    // 🎯 RULE 2: Entry-based plans - Accept null discipline (any discipline allowed)
    if (planNameLower.contains('ingresso singolo') ||
        planNameLower.contains('pacchetto 10 ingressi')) {
      // Explicitly set disciplines to null for entry-based plans
      _selectedDiscipline = null;
      _selectedDiscipline2 = null;
    }

    // 🎯 RULE 3: "Preparazione Atletica" standalone - Always set discipline to "Fitness"
    if (_isPreparazioneAtleticaPlan()) {
      _selectedDiscipline = 'Fitness';
      _selectedDiscipline2 = null;
    }

    // 🆕 NEW RULE: "Doppio Corso" plans - Require TWO different disciplines
    if (_shouldShowTwoDisciplineDropdowns()) {
      if (_selectedDiscipline == null || _selectedDiscipline2 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('payment.double_course_disciplines'.tr()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Validate that two disciplines are different
      if (_selectedDiscipline == _selectedDiscipline2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('validation.disciplines_must_differ'.tr()),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      print('🔍 DEBUG: Doppio Corso - First discipline: $_selectedDiscipline');
      print(
        '🔍 DEBUG: Doppio Corso - Second discipline: $_selectedDiscipline2',
      );
    }

    // Validate discipline selection ONLY for "Corso Singolo" plans
    if (_shouldShowDisciplineDropdown() && _selectedDiscipline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('validation.select_discipline'.tr()),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Find the selected plan to get correct price
      final selectedPlan = _allPlans.firstWhere(
        (plan) => plan['name'] == _selectedPlanName,
      );

      final double correctPrice = (selectedPlan['price'] as num).toDouble();

      print(
        '🔍 DEBUG: Starting payment confirmation for plan: $_selectedPlanName',
      );
      print('🔍 DEBUG: Amount: €${correctPrice.toStringAsFixed(2)}');
      if (_selectedDiscipline != null) {
        print('🔍 DEBUG: Selected discipline: $_selectedDiscipline');
      }
      if (_selectedDiscipline2 != null) {
        print('🔍 DEBUG: Selected discipline 2: $_selectedDiscipline2');
      }

      // Build items list with discipline(s)
      final items = [
        {
          'plan_name': _selectedPlanName!,
          'price': correctPrice,
          'discipline': _selectedDiscipline,
          'discipline2':
              _selectedDiscipline2, // 🆕 Pass second discipline for Doppio Corso
        },
      ];

      print('🔍 DEBUG: Calling createBatchPaymentAndReceipts...');

      // Execute atomic batch with discipline parameter(s)
      final transactionId =
          await SubscriptionService.createBatchPaymentAndReceipts(
            items: items,
            paymentMethod: widget.paymentMethod.toLowerCase(),
            amount: correctPrice,
            description: _selectedPlanName!,
            discipline: _selectedDiscipline, // Pass first discipline to service
            discipline2:
                _selectedDiscipline2, // 🆕 Pass second discipline for Doppio Corso
          );

      if (transactionId.isEmpty) {
        throw Exception(
          'Transaction ID is empty - payment may have failed or is already processing',
        );
      }

      print('✅ DEBUG: Transaction completed: $transactionId');

      if (!mounted) return;

      // Clear pending items and navigate
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('payment.subscription_activated'.tr()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ DEBUG: Payment confirmation failed: $e');

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('receipt.create_error'.tr(namedArgs: {'detail': '$e'})),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
