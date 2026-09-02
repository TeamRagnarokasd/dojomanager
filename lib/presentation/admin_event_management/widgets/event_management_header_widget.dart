import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EventManagementHeaderWidget extends StatelessWidget {
  final int eventCount;
  final String selectedFilter;
  final List<String> filters;
  final Function(String) onFilterChanged;
  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  const EventManagementHeaderWidget({
    super.key,
    required this.eventCount,
    required this.selectedFilter,
    required this.filters,
    required this.onFilterChanged,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation and stats
          Row(
            children: [
              // Month navigation
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => onMonthChanged(DateTime(
                        selectedMonth.year,
                        selectedMonth.month - 1,
                      )),
                      child: CustomIconWidget(
                        iconName: 'chevron_left',
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      _getMonthYearString(selectedMonth),
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    GestureDetector(
                      onTap: () => onMonthChanged(DateTime(
                        selectedMonth.year,
                        selectedMonth.month + 1,
                      )),
                      child: CustomIconWidget(
                        iconName: 'chevron_right',
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Event count indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: 'event_note',
                      color: const Color(0xFFFF0000),
                      size: 16,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      '$eventCount eventi',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFFF0000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = selectedFilter == filter;
                return Container(
                  margin: EdgeInsets.only(right: 2.w),
                  child: GestureDetector(
                    onTap: () => onFilterChanged(filter),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 4.w, vertical: 1.5.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF0000)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(25),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            CustomIconWidget(
                              iconName: 'check',
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 1.w),
                          ],
                          Text(
                            _getFilterLabel(filter),
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color:
                                  isSelected ? Colors.white : Colors.grey[300],
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthYearString(DateTime date) {
    final months = [
      '',
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic'
    ];
    return '${months[date.month]} ${date.year}';
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'disciplines.all'.tr();
      case 'seminari':
        return 'Seminari';
      case 'stage':
        return 'Stage';
      case 'active':
        return 'Attivi';
      case 'upcoming':
        return 'Prossimi';
      default:
        return filter.toUpperCase();
    }
  }
}
