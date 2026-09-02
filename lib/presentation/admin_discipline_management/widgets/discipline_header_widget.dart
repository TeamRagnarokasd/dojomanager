import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/subscription_service.dart';

class DisciplineHeaderWidget extends StatelessWidget {
  final List<Map<String, dynamic>> disciplines;
  final String searchQuery;
  final List<String> activeFilters;
  final Function(String) onSearchChanged;
  final Function(List<String>) onFilterChanged;
  final Function(String) onDisciplineToggle;

  // 🆕 NEW: Static storage for discipline-subscription associations (session-based)
  static final Map<String, Set<String>> _disciplineSubscriptionMap = {};

  const DisciplineHeaderWidget({
    super.key,
    required this.disciplines,
    required this.searchQuery,
    required this.activeFilters,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onDisciplineToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'admin_discipline.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => onSearchChanged(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),

          // Active disciplines chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discipline Attive',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: disciplines.map((discipline) {
                    return _buildDisciplineChip(context, discipline);
                  }).toList(),
                ),
              ],
            ),
          ),

          // Filter chips
          if (activeFilters.isNotEmpty || _hasAvailableFilters())
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtri',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _buildFilterChips(context),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDisciplineChip(
    BuildContext context,
    Map<String, dynamic> discipline,
  ) {
    final theme = Theme.of(context);
    final isActive = discipline['isActive'] ?? true;

    return GestureDetector(
      onTap: () => _showSubscriptionPlansDropdown(context, discipline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (discipline['color'] as Color?) ?? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (discipline['color'] as Color?) ?? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: ((discipline['color'] as Color?) ??
                            theme.colorScheme.primary)
                        .withAlpha(77),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                    width: 1,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              discipline['name'],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: isActive
                  ? Colors.white.withAlpha(204)
                  : theme.colorScheme.onSurface.withAlpha(153),
            ),
          ],
        ),
      ),
    );
  }

  // 🔄 UPDATED METHOD: Pass saved subscription IDs when opening modal
  void _showSubscriptionPlansDropdown(
    BuildContext context,
    Map<String, dynamic> discipline,
  ) async {
    final theme = Theme.of(context);

    // Show loading indicator while fetching plans
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch subscription plans from Supabase
      final subscriptionPlans =
          await SubscriptionService.getSubscriptionPlans();

      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      // 🆕 NEW: Get previously saved subscription IDs for this discipline
      final disciplineId = discipline['id'] as String;
      final savedSubscriptionIds =
          _disciplineSubscriptionMap[disciplineId] ?? {};

      // Show multi-select bottom sheet with saved selections
      if (context.mounted) {
        final updatedSelections = await showModalBottomSheet<Set<String>>(
          context: context,
          isScrollControlled: true,
          isDismissible: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _MultiSelectSubscriptionSheet(
            discipline: discipline,
            subscriptionPlans: subscriptionPlans,
            theme: theme,
            initialSelectedPlanIds: savedSubscriptionIds, // 🆕 Pass saved IDs
            onConfirm: (selectedIds) {
              // 🆕 NEW: Save selections when confirmed
              _disciplineSubscriptionMap[disciplineId] = selectedIds;
              return selectedIds;
            },
          ),
        );

        // Update stored selections if user confirmed
        if (updatedSelections != null) {
          _disciplineSubscriptionMap[disciplineId] = updatedSelections;
        }
      }
    } catch (error) {
      // Close loading indicator if still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'admin_discipline.subscriptions_load_error_detail'
                  .tr(namedArgs: {'error': error.toString()}),
            ),
            backgroundColor: theme.colorScheme.error,
            action: SnackBarAction(
              label: 'common.ok'.tr(),
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // 🆕 NEW METHOD: Build subscription plan tile
  Widget _buildSubscriptionPlanTile(
    BuildContext context,
    Map<String, dynamic> plan,
    Map<String, dynamic> discipline,
  ) {
    final theme = Theme.of(context);

    // Format plan type for display
    String planTypeLabel;
    IconData planIcon;
    Color planColor;

    switch (plan['plan_type']) {
      case 'single_entry':
        planTypeLabel = 'Ingresso Singolo';
        planIcon = Icons.person;
        planColor = Colors.blue;
        break;
      case 'multi_entry':
        planTypeLabel = '${plan['entry_count']} Ingressi';
        planIcon = Icons.people;
        planColor = Colors.purple;
        break;
      case 'monthly':
        planTypeLabel = 'payment.monthly_plan'.tr();
        planIcon = Icons.calendar_month;
        planColor = Colors.green;
        break;
      case 'annual':
        planTypeLabel = 'payment.annual_plan'.tr();
        planIcon = Icons.calendar_today;
        planColor = Colors.orange;
        break;
      default:
        planTypeLabel = 'Piano';
        planIcon = Icons.card_membership;
        planColor = theme.colorScheme.primary;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: planColor.withAlpha(51),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(planIcon, color: planColor, size: 24),
      ),
      title: Text(
        plan['name'],
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            planTypeLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          if (plan['description'] != null) ...[
            const SizedBox(height: 2),
            Text(
              plan['description'],
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withAlpha(128),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '€${(plan['price'] as num).toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      onTap: () => _handleSubscriptionPlanSelection(context, plan, discipline),
    );
  }

  // 🆕 NEW METHOD: Handle subscription plan selection
  void _handleSubscriptionPlanSelection(
    BuildContext context,
    Map<String, dynamic> plan,
    Map<String, dynamic> discipline,
  ) {
    Navigator.pop(context); // Close the bottom sheet

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('admin_discipline.subscription_selected'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hai selezionato:',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.card_membership,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.sports_martial_arts,
                  size: 20,
                  color: (discipline['color'] as Color?) ??
                      Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'per ${discipline['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Gli studenti con questo abbonamento potranno ora prenotare le classi di ${discipline['name']}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'user_mgmt.plan_enabled_snackbar'.tr(namedArgs: {
            'plan': plan['name'],
            'discipline': discipline['name'],
          }),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(
          label: 'common.ok'.tr(),
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  bool _hasAvailableFilters() {
    return disciplines.any((d) => d['isActive'] == true) &&
        disciplines.any((d) => d['isActive'] == false);
  }

  List<Widget> _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    // Active/Inactive filters
    if (_hasAvailableFilters()) {
      chips.add(
        _buildFilterChip(
          context,
          'seasonal_schedule.active_lessons'.tr(),
          'active',
          activeFilters.contains('active'),
          Icons.check_circle,
          theme.colorScheme.primary,
        ),
      );

      chips.add(
        _buildFilterChip(
          context,
          'Disattivate',
          'inactive',
          activeFilters.contains('inactive'),
          Icons.cancel,
          Colors.grey[600]!,
        ),
      );
    }

    // Instructor filter
    final allInstructors = disciplines
        .expand((d) => d['instructors'] as List<String>)
        .toSet()
        .toList();

    if (allInstructors.length > 1) {
      chips.add(_buildInstructorFilterChip(context, allInstructors));
    }

    return chips;
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String filterId,
    bool isSelected,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        final newFilters = List<String>.from(activeFilters);
        if (selected) {
          newFilters.add(filterId);
        } else {
          newFilters.remove(filterId);
        }
        onFilterChanged(newFilters);
      },
      backgroundColor: theme.colorScheme.surface,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildInstructorFilterChip(
    BuildContext context,
    List<String> instructors,
  ) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      child: Chip(
        avatar: Icon(
          Icons.person,
          size: 16,
          color: theme.colorScheme.onSurface,
        ),
        label: Text(
          'class_schedule.instructor'.tr(),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      itemBuilder: (context) => instructors.map((instructor) {
        return PopupMenuItem<String>(
          value: instructor,
          child: Text(instructor),
        );
      }).toList(),
      onSelected: (instructor) {
        // Filter by instructor
        onSearchChanged(instructor);
      },
    );
  }
}

// 🔄 UPDATED STATEFUL WIDGET: Accept and use initial selected IDs
class _MultiSelectSubscriptionSheet extends StatefulWidget {
  final Map<String, dynamic> discipline;
  final List<Map<String, dynamic>> subscriptionPlans;
  final ThemeData theme;
  final Set<String> initialSelectedPlanIds; // 🆕 NEW: Accept initial selections
  final Set<String> Function(Set<String>)
      onConfirm; // 🆕 NEW: Callback for confirmation

  const _MultiSelectSubscriptionSheet({
    required this.discipline,
    required this.subscriptionPlans,
    required this.theme,
    required this.initialSelectedPlanIds,
    required this.onConfirm,
  });

  @override
  State<_MultiSelectSubscriptionSheet> createState() =>
      _MultiSelectSubscriptionSheetState();
}

class _MultiSelectSubscriptionSheetState
    extends State<_MultiSelectSubscriptionSheet> {
  // Track selected subscription plan IDs
  late final Set<String> _selectedPlanIds;

  @override
  void initState() {
    super.initState();
    // 🆕 CRITICAL FIX: Initialize with previously saved selections
    _selectedPlanIds = Set<String>.from(widget.initialSelectedPlanIds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (widget.discipline['color'] as Color?) ??
                      widget.theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Abbonamenti per ${widget.discipline['name']}',
                  style: widget.theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Instruction text
          Text(
            'admin_discipline.select_subscription_plans'.tr(),
            style: widget.theme.textTheme.bodyMedium?.copyWith(
              color: widget.theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 16),

          // Selected count indicator
          if (_selectedPlanIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: widget.theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedPlanIds.length} abbonamento/i selezionato/i',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Subscription plans list with checkboxes
          Flexible(
            child: widget.subscriptionPlans.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.subscriptionPlans.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final plan = widget.subscriptionPlans[index];
                      final planId = plan['id'] as String;
                      final isSelected = _selectedPlanIds.contains(planId);

                      return _buildSubscriptionPlanTile(
                        plan,
                        isSelected,
                        () => _togglePlanSelection(planId),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Clear all button
              if (_selectedPlanIds.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedPlanIds.clear());
                    },
                    icon: const Icon(Icons.clear_all),
                    label: Text('admin_discipline.clear_all'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              if (_selectedPlanIds.isNotEmpty) const SizedBox(width: 12),

              // Confirm button
              Expanded(
                flex: _selectedPlanIds.isEmpty ? 1 : 2,
                child: ElevatedButton.icon(
                  onPressed: _selectedPlanIds.isEmpty
                      ? null
                      : () => _confirmSelection(context),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _selectedPlanIds.isEmpty
                        ? 'admin_discipline.select_subscriptions'.tr()
                        : 'admin_discipline.confirm_selection'.tr(),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: widget.theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Toggle plan selection
  void _togglePlanSelection(String planId) {
    setState(() {
      if (_selectedPlanIds.contains(planId)) {
        _selectedPlanIds.remove(planId);
      } else {
        _selectedPlanIds.add(planId);
      }
    });
  }

  // Build individual subscription plan tile with checkbox
  Widget _buildSubscriptionPlanTile(
    Map<String, dynamic> plan,
    bool isSelected,
    VoidCallback onToggle,
  ) {
    // Format plan type for display
    String planTypeLabel;
    IconData planIcon;
    Color planColor;

    switch (plan['plan_type']) {
      case 'single_entry':
        planTypeLabel = 'Ingresso Singolo';
        planIcon = Icons.person;
        planColor = Colors.blue;
        break;
      case 'multi_entry':
        planTypeLabel = '${plan['entry_count']} Ingressi';
        planIcon = Icons.people;
        planColor = Colors.purple;
        break;
      case 'monthly':
        planTypeLabel = 'payment.monthly_plan'.tr();
        planIcon = Icons.calendar_month;
        planColor = Colors.green;
        break;
      case 'annual':
        planTypeLabel = 'payment.annual_plan'.tr();
        planIcon = Icons.calendar_today;
        planColor = Colors.orange;
        break;
      default:
        planTypeLabel = 'Piano';
        planIcon = Icons.card_membership;
        planColor = widget.theme.colorScheme.primary;
    }

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? widget.theme.colorScheme.primaryContainer.withAlpha(128)
            : Colors.transparent,
        border: isSelected
            ? Border.all(color: widget.theme.colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onToggle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

        // Checkbox indicator
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              activeColor: widget.theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: planColor.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(planIcon, color: planColor, size: 24),
            ),
          ],
        ),

        // Plan details
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan['name'],
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  decoration: isSelected
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: widget.theme.colorScheme.primary,
                  decorationThickness: 2,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: widget.theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              planTypeLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: widget.theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            if (plan['description'] != null) ...[
              const SizedBox(height: 2),
              Text(
                plan['description'],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: widget.theme.colorScheme.onSurface.withAlpha(128),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),

        trailing: Text(
          '€${(plan['price'] as num).toStringAsFixed(2)}',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? widget.theme.colorScheme.primary
                : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: widget.theme.colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'admin_discipline.no_plans_available'.tr(),
            style: widget.theme.textTheme.titleMedium?.copyWith(
              color: widget.theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'admin_discipline.create_plans_hint'.tr(),
            style: widget.theme.textTheme.bodyMedium?.copyWith(
              color: widget.theme.colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🔄 UPDATED: Return selections when confirming
  void _confirmSelection(BuildContext context) {
    if (_selectedPlanIds.isEmpty) return;

    // Call the onConfirm callback to save selections
    final confirmedSelections = widget.onConfirm(_selectedPlanIds);

    Navigator.pop(context, confirmedSelections); // 🆕 Return selections

    // Get selected plan names for display
    final selectedPlans = widget.subscriptionPlans
        .where((plan) => _selectedPlanIds.contains(plan['id'] as String))
        .map((plan) => plan['name'] as String)
        .toList();

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: widget.theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text('admin_discipline.subscriptions_confirmed'
                    .tr())), // 🔄 Changed text
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hai confermato ${_selectedPlanIds.length} abbonamento/i per ${widget.discipline['name']}:', // 🔄 Changed text
              style: widget.theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...selectedPlans.map(
              (planName) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: widget.theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        planName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Le selezioni verranno mantenute. Riclicca sulla disciplina per vederle evidenziate.', // 🆕 NEW hint
              style: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.theme.colorScheme.onSurface.withAlpha(153),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedPlanIds.length} abbonamento/i confermato/i per ${widget.discipline['name']}', // 🔄 Changed text
        ),
        backgroundColor: widget.theme.colorScheme.primary,
        action: SnackBarAction(
          label: 'common.ok'.tr(),
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
