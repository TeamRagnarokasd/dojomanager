import 'package:flutter/material.dart';
import '../../../core/app_export.dart';

class FilterChipsWidget extends StatelessWidget {
  final List<String> selectedFilters;
  final Function(String) onFilterToggle;
  final List<String> availableDisciplines;

  const FilterChipsWidget({
    Key? key,
    required this.selectedFilters,
    required this.onFilterToggle,
    this.availableDisciplines = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build filter list: 'all' first, then dynamic disciplines from Supabase
    final List<String> filterKeys = ['all', ...availableDisciplines];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filterKeys.length,
        itemBuilder: (context, index) {
          final filterKey = filterKeys[index];
          final isSelected = selectedFilters.contains(filterKey);

          final label = filterKey == 'all' ? 'disciplines.all'.tr() : filterKey;

          // Use high-contrast colors for readability on both light and dark themes
          final unselectedTextColor = isDark
              ? Colors.white70
              : Colors.grey[800]!;
          final selectedTextColor = theme.primaryColor;
          final unselectedBgColor = isDark
              ? Colors.white.withAlpha(20)
              : Colors.grey.withAlpha(26);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (bool selected) {
                onFilterToggle(filterKey);
              },
              selectedColor: theme.primaryColor.withAlpha(51),
              checkmarkColor: theme.primaryColor,
              backgroundColor: unselectedBgColor,
              side: BorderSide(
                color: isSelected
                    ? theme.primaryColor
                    : (isDark ? Colors.white38 : Colors.grey.withAlpha(77)),
                width: 1.5,
              ),
              labelStyle: TextStyle(
                color: isSelected ? selectedTextColor : unselectedTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}
