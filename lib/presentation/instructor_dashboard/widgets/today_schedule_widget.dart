import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';

class TodayScheduleWidget extends StatelessWidget {
  const TodayScheduleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> todayClasses = [
      {
        'martial_art': 'BJJ',
        'time': '09:00 - 10:30',
        'students': 12,
        'max_capacity': 15,
        'level': 'Principianti',
        'icon': Icons.sports_mma,
        'color': const Color(0xFFFF0000),
      },
      {
        'martial_art': 'SAMBO',
        'time': '11:00 - 12:30',
        'students': 8,
        'max_capacity': 10,
        'level': 'Intermedio',
        'icon': Icons.sports_kabaddi,
        'color': const Color(0xFFFF8800),
      },
      {
        'martial_art': 'MMA',
        'time': '18:00 - 19:30',
        'students': 15,
        'max_capacity': 20,
        'level': 'Avanzato',
        'icon': Icons.sports_martial_arts,
        'color': const Color(0xFF8800FF),
      },
      {
        'martial_art': 'GRAPPLING',
        'time': '20:00 - 21:30',
        'students': 10,
        'max_capacity': 12,
        'level': 'Misto',
        'icon': Icons.accessibility_new,
        'color': const Color(0xFF0088FF),
      },
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Programma di Oggi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${todayClasses.length} Lezioni',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFF0000),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...List.generate(todayClasses.length, (index) {
              final classData = todayClasses[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: _buildClassCard(context, classData),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, Map<String, dynamic> classData) {
    final double fillPercentage =
        classData['students'] / classData['max_capacity'];
    final bool isNearCapacity = fillPercentage >= 0.8;
    final bool isFull = classData['students'] >= classData['max_capacity'];

    return Slidable(
      key: ValueKey(classData['martial_art']),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _viewStudentList(context, classData),
            backgroundColor: const Color(0xFF0099FF),
            foregroundColor: Colors.white,
            icon: Icons.list_alt,
            label: 'Lista',
            borderRadius: BorderRadius.circular(8),
          ),
          SlidableAction(
            onPressed: (context) => _sendMessage(context, classData),
            backgroundColor: const Color(0xFF00CC66),
            foregroundColor: Colors.white,
            icon: Icons.message,
            label: 'communication.message_label'.tr(),
            borderRadius: BorderRadius.circular(8),
          ),
          SlidableAction(
            onPressed: (context) => _editClass(context, classData),
            backgroundColor: const Color(0xFFFF0000),
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'profile.modify'.tr(),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: classData['color'].withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: classData['color'].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    classData['icon'],
                    color: classData['color'],
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            classData['martial_art'],
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            classData['time'],
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFFF0000),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            classData['level'],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: 14.sp,
                                color: isNearCapacity
                                    ? isFull
                                        ? Colors.red
                                        : Colors.orange
                                    : Colors.green,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${classData['students']}/${classData['max_capacity']}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                      color: isNearCapacity
                                          ? isFull
                                              ? Colors.red
                                              : Colors.orange
                                          : Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: fillPercentage,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isNearCapacity
                          ? isFull
                              ? Colors.red
                              : Colors.orange
                          : Colors.green,
                    ),
                    minHeight: 4,
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    onTap: () => _markAttendance(context, classData),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16.sp,
                          color: const Color(0xFFFF0000),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Presenze',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFFF0000),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewStudentList(BuildContext context, Map<String, dynamic> classData) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lista Studenti - ${classData['martial_art']}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 16.h),
            // Mock student list
            ...List.generate(classData['students'], (index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=50&h=50&fit=crop&crop=face',
                  ),
                  radius: 20.sp,
                ),
                title: Text('instructor_dashboard_ui.student_n'
                    .tr(namedArgs: {'n': '${index + 1}'})),
                subtitle: Text('Livello: ${classData['level']}'),
                trailing: Icon(Icons.check_circle, color: Colors.green),
              );
            }),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _sendMessage(BuildContext context, Map<String, dynamic> classData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('instructor_dashboard_ui.send_message'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'instructor_dashboard_ui.send_message_prompt'
                  .tr(namedArgs: {'discipline': '${classData['martial_art']}'}),
            ),
            SizedBox(height: 16.h),
            TextField(
              decoration: InputDecoration(
                labelText: 'communication.message_label'.tr(),
                hintText: 'communication.message_hint'.tr(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Messaggio inviato a ${classData['students']} studenti',
                  ),
                  backgroundColor: const Color(0xFFFF0000),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
            ),
            child:
                Text('common.send'.tr(), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editClass(BuildContext context, Map<String, dynamic> classData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('instructor_dashboard_ui.edit_lesson'
            .tr(namedArgs: {'discipline': '${classData['martial_art']}'})),
        backgroundColor: const Color(0xFFFF0000),
      ),
    );
  }

  void _markAttendance(BuildContext context, Map<String, dynamic> classData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Presenze per ${classData['martial_art']} registrate'),
        backgroundColor: const Color(0xFFFF0000),
      ),
    );
  }
}
