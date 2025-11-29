import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class BookingModalWidget extends StatefulWidget {
  final Map<String, dynamic> classData;
  final VoidCallback onBookingConfirmed;

  const BookingModalWidget({
    Key? key,
    required this.classData,
    required this.onBookingConfirmed,
  }) : super(key: key);

  @override
  State<BookingModalWidget> createState() => _BookingModalWidgetState();
}

class _BookingModalWidgetState extends State<BookingModalWidget> {
  bool _isBooking = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBooked = widget.classData['isBooked'] ?? false;
    final capacity = widget.classData['capacity'] ?? 20;
    final enrolled = widget.classData['enrolled'] ?? 0;
    final availableSpots = capacity - enrolled;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 1.h, bottom: 2.h),
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class type and status
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getTypeColor(widget.classData['type'] ?? 'BJJ'),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.classData['type'] ?? 'BJJ',
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      if (isBooked)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomIconWidget(
                                iconName: 'check_circle',
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                'Prenotato',
                                style: theme.textTheme.labelSmall!.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 3.h),

                  // Class details
                  _buildDetailRow(
                    context,
                    'Istruttore',
                    widget.classData['instructor'] ?? 'Da definire',
                    'person',
                  ),
                  _buildDetailRow(
                    context,
                    'Orario',
                    widget.classData['time'] ?? '',
                    'schedule',
                  ),
                  _buildDetailRow(
                    context,
                    'Data',
                    widget.classData['date'] ?? '',
                    'calendar_today',
                  ),
                  _buildDetailRow(
                    context,
                    'Posti disponibili',
                    '$availableSpots/$capacity',
                    'people',
                    valueColor: availableSpots > 0 ? Colors.green : Colors.red,
                  ),

                  SizedBox(height: 3.h),

                  // Capacity indicator
                  _buildCapacityIndicator(context, enrolled, capacity),

                  SizedBox(height: 3.h),

                  // Description
                  if (widget.classData['description'] != null &&
                      widget.classData['description'].isNotEmpty) ...[
                    Text(
                      'Descrizione',
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      widget.classData['description'],
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 3.h),
                  ],

                  // Instructor bio
                  if (widget.classData['instructorBio'] != null &&
                      widget.classData['instructorBio'].isNotEmpty) ...[
                    Text(
                      'Istruttore',
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      widget.classData['instructorBio'],
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 3.h),
                  ],

                  // Important note
                  if (!isBooked) ...[
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'info',
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Text(
                              'La prenotazione può essere cancellata fino al giorno precedente la lezione.',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: theme.primaryColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 3.h),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        side: BorderSide(
                          color: theme.colorScheme.outline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Chiudi',
                        style: theme.textTheme.titleSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isBooking || availableSpots <= 0
                          ? null
                          : () => _handleBooking(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBooked
                            ? Colors.red
                            : availableSpots > 0
                                ? theme.primaryColor
                                : theme.colorScheme.onSurfaceVariant,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isBooking
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              isBooked
                                  ? 'Cancella Prenotazione'
                                  : availableSpots > 0
                                      ? 'Prenota Classe'
                                      : 'Classe Piena',
                              style: theme.textTheme.titleSmall!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    String iconName, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: iconName,
              color: theme.primaryColor,
              size: 18,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityIndicator(
    BuildContext context,
    int enrolled,
    int capacity,
  ) {
    final theme = Theme.of(context);
    final percentage = capacity > 0 ? enrolled / capacity : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Partecipanti',
              style: theme.textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$enrolled/$capacity',
              style: theme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: percentage > 0.8 ? Colors.red : theme.primaryColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Container(
          height: 1.h,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: percentage,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: percentage > 0.8
                    ? Colors.red
                    : percentage > 0.6
                        ? Colors.orange
                        : theme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleBooking(BuildContext context) async {
    if (_isBooking) return;

    setState(() {
      _isBooking = true;
    });

    try {
      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      widget.onBookingConfirmed();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'bjj':
      case 'brazilian jiu-jitsu':
        return const Color(0xFF2196F3); // Blue
      case 'mma':
        return const Color(0xFFFF5722); // Deep Orange
      case 'sambo':
        return const Color(0xFF795548); // Brown
      case 'grappling':
        return const Color(0xFF9C27B0); // Purple
      case 'prep. atletica':
      case 'fitness':
        return const Color(0xFF4CAF50); // Green
      default:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }
}
