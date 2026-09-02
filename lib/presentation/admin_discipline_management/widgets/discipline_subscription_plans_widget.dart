import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import '../../../services/discipline_service.dart';

class DisciplineSubscriptionPlansWidget extends StatefulWidget {
  final String disciplineId;
  final String disciplineName;

  const DisciplineSubscriptionPlansWidget({
    Key? key,
    required this.disciplineId,
    required this.disciplineName,
  }) : super(key: key);

  @override
  State<DisciplineSubscriptionPlansWidget> createState() =>
      _DisciplineSubscriptionPlansWidgetState();
}

class _DisciplineSubscriptionPlansWidgetState
    extends State<DisciplineSubscriptionPlansWidget> {
  final DisciplineService _disciplineService = DisciplineService.instance;
  List<Map<String, dynamic>> _allPlans = [];
  Set<String> _selectedPlanIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _disciplineService.getAllSubscriptionPlans(),
        _disciplineService.getSubscriptionPlansForDiscipline(
          widget.disciplineId,
        ),
      ]);

      final allPlans = results[0];
      final associatedPlans = results[1];

      // Filter out "iscrizione annuale" by name (case-insensitive)
      final filtered = allPlans.where((plan) {
        final planName = (plan['name'] as String? ?? '').toLowerCase().trim();
        if (planName.contains('iscrizione annuale')) return false;
        return true;
      }).toList();

      // Build selected IDs from associated plans
      final selectedIds = <String>{};
      for (final plan in associatedPlans) {
        final id =
            plan['subscription_plan_id'] as String? ?? plan['id'] as String?;
        if (id != null) selectedIds.add(id);
      }

      setState(() {
        _allPlans = filtered;
        _selectedPlanIds = selectedIds;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento dei piani: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlanAssociation(String planId) async {
    if (_isSaving) return;

    final isCurrentlySelected = _selectedPlanIds.contains(planId);

    // Optimistic UI update immediately
    setState(() {
      if (isCurrentlySelected) {
        _selectedPlanIds.remove(planId);
      } else {
        _selectedPlanIds.add(planId);
      }
      _isSaving = true;
    });

    try {
      if (isCurrentlySelected) {
        await _disciplineService.removeSubscriptionPlanFromDiscipline(
          discipline: widget.disciplineId,
          subscriptionPlanId: planId,
        );
      } else {
        await _disciplineService.associateSubscriptionPlanToDiscipline(
          discipline: widget.disciplineId,
          subscriptionPlanId: planId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlySelected
                  ? 'Piano rimosso dalla disciplina'
                  : 'Piano associato alla disciplina',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      // Revert optimistic update on error
      setState(() {
        if (isCurrentlySelected) {
          _selectedPlanIds.add(planId);
        } else {
          _selectedPlanIds.remove(planId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore: ${error.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatPlanType(String? planType) {
    switch (planType) {
      case 'monthly':
        return 'payment.monthly_plan'.tr();
      case 'single_entry':
        return 'admin_discipline.single_entry'.tr();
      case 'multi_entry':
        return 'admin_discipline.entry_package'.tr();
      case 'annual':
        return 'payment.annual_plan'.tr();
      default:
        return planType ?? 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'discipline_plans.subscription_plans_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadData,
                    tooltip: 'discipline_plans.reload_tooltip'.tr(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'admin_discipline.select_plans_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_allPlans.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'common.no_plans'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allPlans.length,
                  itemBuilder: (context, index) {
                    final plan = _allPlans[index];
                    final planId = plan['id'] as String;
                    final planName =
                        plan['name'] as String? ??
                        'discipline_plans.unknown_plan'.tr();
                    final planType = plan['plan_type'] as String?;
                    final price = plan['price'] as num?;
                    final isSelected = _selectedPlanIds.contains(planId);

                    return InkWell(
                      onTap: _isSaving
                          ? null
                          : () => _togglePlanAssociation(planId),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: _isSaving
                                  ? null
                                  : (_) => _togglePlanAssociation(planId),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    planName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatPlanType(planType),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (price != null)
                                    Text(
                                      '€${price.toStringAsFixed(2)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
