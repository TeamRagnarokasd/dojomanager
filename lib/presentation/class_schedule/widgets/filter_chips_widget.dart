import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class FilterChipsWidget extends StatelessWidget {
  final List<String> selectedFilters;
  final Function(String) onFilterToggle;

  const FilterChipsWidget({
    Key? key,
    required this.selectedFilters,
    required this.onFilterToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Map<String, dynamic>> filterOptions = [
      {'label': 'Tutti', 'value': 'all', 'icon': 'filter_list'},
      {'label': 'Karate', 'value': 'karate', 'icon': 'sports_kabaddi'},
      {'label': 'Judo', 'value': 'judo', 'icon': 'sports_martial_arts'},
      {'label': 'Taekwondo', 'value': 'taekwondo', 'icon': 'sports_mma'},
      {'label': 'Disponibili', 'value': 'available', 'icon': 'check_circle'},
      {'label': 'I Miei Corsi', 'value': 'my_classes', 'icon': 'bookmark'},
    ];

    return Container(
      height: 6.h,
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        itemCount: filterOptions.length,
        separatorBuilder: (context, index) => SizedBox(width: 2.w),
        itemBuilder: (context, index) {
          final filter = filterOptions[index];
          final isSelected = selectedFilters.contains(filter['value']);

          return FilterChip(
            selected: isSelected,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIconWidget(
                  iconName: filter['icon'],
                  color:
                      isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                  size: 16,
                ),
                SizedBox(width: 1.w),
                Text(
                  filter['label'],
                  style: theme.textTheme.labelMedium!.copyWith(
                    color:
                        isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            onSelected: (selected) => onFilterToggle(filter['value']),
            backgroundColor: theme.colorScheme.surface,
            selectedColor: theme.primaryColor,
            checkmarkColor: theme.colorScheme.onPrimary,
            side: BorderSide(
              color:
                  isSelected ? theme.primaryColor : theme.colorScheme.outline,
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
