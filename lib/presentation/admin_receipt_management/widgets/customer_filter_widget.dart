import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CustomerFilterWidget extends StatefulWidget {
  final String customerFilter;
  final String selectedPeriod;
  final List<String> periodOptions;
  final Function(String) onCustomerFilterChanged;
  final Function(String) onPeriodChanged;

  const CustomerFilterWidget({
    Key? key,
    required this.customerFilter,
    required this.selectedPeriod,
    required this.periodOptions,
    required this.onCustomerFilterChanged,
    required this.onPeriodChanged,
  }) : super(key: key);

  @override
  State<CustomerFilterWidget> createState() => _CustomerFilterWidgetState();
}

class _CustomerFilterWidgetState extends State<CustomerFilterWidget> {
  final TextEditingController _customerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customerController.text = widget.customerFilter;
  }

  @override
  void dispose() {
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      color: AppTheme.lightTheme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer search
          Text(
            'Filtra per Cliente',
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _customerController,
              onChanged: widget.onCustomerFilterChanged,
              decoration: InputDecoration(
                hintText: 'Cerca per nome cliente...',
                hintStyle: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
                prefixIcon: CustomIconWidget(
                  iconName: 'person_search',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                suffixIcon: widget.customerFilter.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _customerController.clear();
                          widget.onCustomerFilterChanged('');
                        },
                        icon: CustomIconWidget(
                          iconName: 'clear',
                          color:
                              AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 2.h,
                ),
              ),
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
          ),

          SizedBox(height: 3.h),

          // Period selection
          Text(
            'Periodo',
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),

          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline
                    .withValues(alpha: 0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.selectedPeriod,
                isExpanded: true,
                icon: CustomIconWidget(
                  iconName: 'arrow_drop_down',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                style: AppTheme.lightTheme.textTheme.bodyMedium,
                items: widget.periodOptions.map((period) {
                  return DropdownMenuItem<String>(
                    value: period,
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: _getPeriodIcon(period),
                          color: period == widget.selectedPeriod
                              ? AppTheme.lightTheme.colorScheme.primary
                              : AppTheme
                                  .lightTheme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          period,
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: period == widget.selectedPeriod
                                ? AppTheme.lightTheme.colorScheme.primary
                                : AppTheme.lightTheme.colorScheme.onSurface,
                            fontWeight: period == widget.selectedPeriod
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    widget.onPeriodChanged(value);
                  }
                },
              ),
            ),
          ),

          // Period chips for quick access
          SizedBox(height: 2.h),
          SizedBox(
            height: 4.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.periodOptions.length,
              itemBuilder: (context, index) {
                final period = widget.periodOptions[index];
                final isSelected = period == widget.selectedPeriod;

                return Container(
                  margin: EdgeInsets.only(right: 2.w),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      period,
                      style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? AppTheme.lightTheme.colorScheme.onPrimary
                            : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        widget.onPeriodChanged(period);
                      }
                    },
                    backgroundColor: AppTheme.lightTheme.colorScheme.surface,
                    selectedColor: AppTheme.lightTheme.colorScheme.primary,
                    checkmarkColor: AppTheme.lightTheme.colorScheme.onPrimary,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.lightTheme.colorScheme.primary
                          : AppTheme.lightTheme.colorScheme.outline
                              .withValues(alpha: 0.3),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodIcon(String period) {
    switch (period) {
      case 'Questo Mese':
        return 'calendar_month';
      case 'Ultimi 3 Mesi':
        return 'date_range';
      case 'Ultimi 6 Mesi':
        return 'calendar_view_month';
      case 'Quest\'Anno':
        return 'calendar_view_year';
      case 'Tutto':
        return 'all_inclusive';
      default:
        return 'date_range';
    }
  }
}
