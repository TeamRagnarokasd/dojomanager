import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EventCalendarWidget extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final Function(String) onEventTap;
  final Function(DateTime) onDateTap;

  const EventCalendarWidget({
    super.key,
    required this.events,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onEventTap,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calendar header
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              bottom: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              Text(
                _getMonthYearString(selectedDate),
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _buildLegendItem('Seminario', const Color(0xFFFF0000)),
                  SizedBox(width: 3.w),
                  _buildLegendItem('Stage', AppTheme.primaryLight),
                ],
              ),
            ],
          ),
        ),

        // Calendar grid
        Expanded(
          child: Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: Column(
              children: [
                // Days of week header
                Container(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Row(
                    children: ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']
                        .map((day) => Expanded(
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: AppTheme.lightTheme.textTheme.bodyMedium
                                    ?.copyWith(
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // Calendar days
                Expanded(
                  child: _buildCalendarGrid(context),
                ),

                // Events for selected date
                if (_getEventsForDate(selectedDate).isNotEmpty)
                  Container(
                    height: 25.h,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      border: Border(
                        top: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eventi ${_formatSelectedDate(selectedDate)}',
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _getEventsForDate(selectedDate).length,
                            itemBuilder: (context, index) {
                              final event =
                                  _getEventsForDate(selectedDate)[index];
                              return _buildEventListItem(event);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.w,
          height: 3.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 1.w),
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final lastDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0);
    final startDate = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday - 1),
    );

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: 42, // 6 weeks * 7 days
      itemBuilder: (context, index) {
        final date = startDate.add(Duration(days: index));
        final isCurrentMonth = date.month == selectedDate.month;
        final isToday = _isSameDay(date, DateTime.now());
        final isSelected = _isSameDay(date, selectedDate);
        final eventsForDate = _getEventsForDate(date);

        return GestureDetector(
          onTap: () {
            onDateSelected(date);
            if (eventsForDate.isEmpty) {
              onDateTap(date);
            }
          },
          child: Container(
            margin: EdgeInsets.all(0.5.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFF0000).withValues(alpha: 0.3)
                  : isToday
                      ? Colors.grey[800]
                      : null,
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: const Color(0xFFFF0000), width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.day.toString(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: isCurrentMonth
                        ? (isSelected ? Colors.white : Colors.grey[300])
                        : Colors.grey[600],
                    fontWeight: isToday || isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (eventsForDate.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 0.5.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: eventsForDate.take(3).map((event) {
                        final color = event['type'] == 'seminario'
                            ? const Color(0xFFFF0000)
                            : AppTheme.primaryLight;
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 0.25.w),
                          width: 1.5.w,
                          height: 1.5.w,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventListItem(Map<String, dynamic> event) {
    final eventColor = event['type'] == 'seminario'
        ? const Color(0xFFFF0000)
        : AppTheme.primaryLight;

    return GestureDetector(
      onTap: () => onEventTap(event['id']),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: eventColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 1.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: eventColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['title'],
                    style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'schedule',
                        color: Colors.grey[400]!,
                        size: 14,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        event['time'],
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'person',
                        color: Colors.grey[400]!,
                        size: 14,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        event['instructor'],
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.w),
              decoration: BoxDecoration(
                color: eventColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event['type'].toUpperCase(),
                style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                  color: eventColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return events.where((event) => _isSameDay(event['date'], date)).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getMonthYearString(DateTime date) {
    final months = [
      '',
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre'
    ];
    return '${months[date.month]} ${date.year}';
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return 'Oggi';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Domani';
    } else {
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
      return '${date.day} ${months[date.month]}';
    }
  }
}
