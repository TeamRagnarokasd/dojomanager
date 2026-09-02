import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CustomerFilterWidget extends StatefulWidget {
  final String customerFilter;
  final String selectedPeriodKey;
  final List<String> periodKeys;
  final Function(String) onCustomerFilterChanged;
  final Function(String) onPeriodChanged;

  const CustomerFilterWidget({
    Key? key,
    required this.customerFilter,
    required this.selectedPeriodKey,
    required this.periodKeys,
    required this.onCustomerFilterChanged,
    required this.onPeriodChanged,
  }) : super(key: key);

  @override
  State<CustomerFilterWidget> createState() => _CustomerFilterWidgetState();
}

class _CustomerFilterWidgetState extends State<CustomerFilterWidget> {
  final TextEditingController _customerController = TextEditingController();

  String _periodLabel(String key) {
    switch (key) {
      case 'this_month':
        return 'receipt.period_this_month'.tr();
      case 'last_3_months':
        return 'receipt.period_last_3_months'.tr();
      case 'last_6_months':
        return 'receipt.period_last_6_months'.tr();
      case 'this_year':
        return 'receipt.period_this_year'.tr();
      case 'all':
        return 'receipt.period_all'.tr();
      default:
        return key;
    }
  }

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
          Text(
            'receipt.filter_by_customer'.tr(),
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
                hintText: 'receipt_mgmt.search_customer'.tr(),
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
          Text(
            'receipt.period_label'.tr(),
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
                value: widget.selectedPeriodKey,
                isExpanded: true,
                icon: CustomIconWidget(
                  iconName: 'arrow_drop_down',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                style: AppTheme.lightTheme.textTheme.bodyMedium,
                items: widget.periodKeys.map((periodKey) {
                  return DropdownMenuItem<String>(
                    value: periodKey,
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: _getPeriodIcon(periodKey),
                          color: periodKey == widget.selectedPeriodKey
                              ? AppTheme.lightTheme.colorScheme.primary
                              : AppTheme
                                  .lightTheme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          _periodLabel(periodKey),
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: periodKey == widget.selectedPeriodKey
                                ? AppTheme.lightTheme.colorScheme.primary
                                : AppTheme.lightTheme.colorScheme.onSurface,
                            fontWeight: periodKey == widget.selectedPeriodKey
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
          SizedBox(height: 2.h),
          SizedBox(
            height: 4.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.periodKeys.length,
              itemBuilder: (context, index) {
                final periodKey = widget.periodKeys[index];
                final isSelected = periodKey == widget.selectedPeriodKey;

                return Container(
                  margin: EdgeInsets.only(right: 2.w),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(
                      _periodLabel(periodKey),
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
                        widget.onPeriodChanged(periodKey);
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

  String _getPeriodIcon(String periodKey) {
    switch (periodKey) {
      case 'this_month':
        return 'calendar_month';
      case 'last_3_months':
        return 'date_range';
      case 'last_6_months':
        return 'calendar_view_month';
      case 'this_year':
        return 'calendar_view_year';
      case 'all':
        return 'all_inclusive';
      default:
        return 'date_range';
    }
  }
}
