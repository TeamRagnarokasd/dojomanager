import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EventListItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final int registeredCount;
  final String? posterUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const EventListItem({
    super.key,
    required this.event,
    required this.registeredCount,
    required this.posterUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final title = (event['title'] ?? '').toString();
    final discipline = (event['discipline'] ?? '').toString();
    final location = (event['location'] ?? '').toString();
    final room = (event['room'] ?? '').toString();
    final capacity = (event['capacity'] as num?)?.toInt() ?? 0;
    final price = (event['price'] as num?)?.toDouble() ?? 0;
    final status = (event['status'] ?? 'pubblicato').toString();
    final isCancelled = status == 'annullato';
    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(event['event_datetime'].toString()).toLocal();
    } catch (_) {
      dateTime = null;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEdit,
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomImageWidget(
                    imageUrl: posterUrl,
                    width: 18.w,
                    height: 18.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCancelled)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.3.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Annullato',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 0.5.h),
                      if (dateTime != null)
                        Text(
                          DateFormat('EEE d MMM yyyy, HH:mm', 'it_IT')
                              .format(dateTime),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      if (discipline.isNotEmpty || location.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 0.3.h),
                          child: Text(
                            [
                              if (discipline.isNotEmpty) discipline,
                              if (location.isNotEmpty)
                                room.isNotEmpty ? '$location ($room)' : location,
                            ].join(' • '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      SizedBox(height: 0.5.h),
                      Row(
                        children: [
                          Text(
                            '$registeredCount/$capacity posti',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            price > 0
                                ? '€${price.toStringAsFixed(2)}'
                                : 'Gratuito',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: onToggleStatus,
                      icon: Icon(
                        isCancelled
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 20,
                        color: isCancelled ? Colors.green : Colors.orange,
                      ),
                      tooltip: isCancelled ? 'Ripubblica' : 'Annulla evento',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    SizedBox(height: 1.h),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red,
                      ),
                      tooltip: 'Elimina',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
