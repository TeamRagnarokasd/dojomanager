import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class PaymentFilterChips extends StatefulWidget {
  final List<String> filterOptions;
  final String selectedFilter;
  final Function(String)? onFilterChanged;

  const PaymentFilterChips({
    Key? key,
    required this.filterOptions,
    required this.selectedFilter,
    this.onFilterChanged,
  }) : super(key: key);

  @override
  State<PaymentFilterChips> createState() => _PaymentFilterChipsState();
}

class _PaymentFilterChipsState extends State<PaymentFilterChips> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: widget.filterOptions.map((option) {
            final isSelected = widget.selectedFilter == option;
            return Container(
              margin: EdgeInsets.only(right: 2.w),
              child: FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => widget.onFilterChanged?.call(option),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                checkmarkColor: Theme.of(context).colorScheme.primary,
                labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.5)
                      : Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
