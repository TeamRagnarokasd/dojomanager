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
  bool _isLoading = false;

  Color _getClassTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'karate':
        return const Color(0xFF2196F3);
      case 'judo':
        return const Color(0xFF4CAF50);
      case 'taekwondo':
        return const Color(0xFFF44336);
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Future<void> _confirmBooking() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate booking process
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    widget.onBookingConfirmed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classType = widget.classData['type'] as String? ?? '';
    final instructor = widget.classData['instructor'] as String? ?? '';
    final time = widget.classData['time'] as String? ?? '';
    final date = widget.classData['date'] as String? ?? '';
    final capacity = widget.classData['capacity'] as int? ?? 0;
    final enrolled = widget.classData['enrolled'] as int? ?? 0;
    final description = widget.classData['description'] as String? ?? '';
    final instructorBio = widget.classData['instructorBio'] as String? ?? '';
    final isAvailable = enrolled < capacity;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 2.h),
            width: 12.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: _getClassTypeColor(classType),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          classType.toUpperCase(),
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 3.h),

                  // Class details
                  _buildDetailRow('access_time', 'Orario', '$time - $date'),
                  SizedBox(height: 2.h),
                  _buildDetailRow('person', 'Istruttore', instructor),
                  SizedBox(height: 2.h),
                  _buildDetailRow(
                    'group',
                    'Posti disponibili',
                    '${capacity - enrolled}/$capacity',
                  ),

                  if (description.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Text(
                      'Descrizione del corso',
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],

                  if (instructorBio.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Text(
                      'Informazioni sull\'istruttore',
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      instructorBio,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],

                  SizedBox(height: 4.h),

                  // Booking button
                  SizedBox(
                    width: double.infinity,
                    height: 6.h,
                    child: ElevatedButton(
                      onPressed:
                          isAvailable && !_isLoading ? _confirmBooking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isAvailable
                                ? theme.primaryColor
                                : theme.colorScheme.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? SizedBox(
                                width: 5.w,
                                height: 5.w,
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                isAvailable
                                    ? 'Prenota Posto'
                                    : 'Classe Completa',
                                style: theme.textTheme.titleMedium!.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),

                  if (!isAvailable) ...[
                    SizedBox(height: 2.h),
                    SizedBox(
                      width: double.infinity,
                      height: 6.h,
                      child: OutlinedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () {
                                  // Add to waitlist functionality
                                  Navigator.pop(context);
                                },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Aggiungi alla Lista d\'Attesa',
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String iconName, String label, String value) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomIconWidget(
          iconName: iconName,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                value,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
