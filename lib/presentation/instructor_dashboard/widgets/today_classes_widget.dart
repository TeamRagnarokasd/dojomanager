import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class TodayClassesWidget extends StatefulWidget {
  const TodayClassesWidget({Key? key}) : super(key: key);

  @override
  State<TodayClassesWidget> createState() => _TodayClassesWidgetState();
}

class _TodayClassesWidgetState extends State<TodayClassesWidget> {
  List<Map<String, dynamic>> todayClasses = [
    {
      'time': '09:00',
      'discipline': 'BJJ',
      'level': 'Principianti',
      'students': 12,
      'maxStudents': 15,
      'status': 'confirmed',
      'color': Colors.blue,
    },
    {
      'time': '11:00',
      'discipline': 'SAMBO',
      'level': 'Intermedio',
      'students': 8,
      'maxStudents': 12,
      'status': 'confirmed',
      'color': Colors.orange,
    },
    {
      'time': '16:30',
      'discipline': 'MMA',
      'level': 'Avanzato',
      'students': 6,
      'maxStudents': 10,
      'status': 'upcoming',
      'color': Colors.purple,
    },
    {
      'time': '18:00',
      'discipline': 'GRAPPLING',
      'level': 'Open Mat',
      'students': 15,
      'maxStudents': 20,
      'status': 'upcoming',
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lezioni di Oggi',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(128)),
                ),
                child: Text(
                  '${todayClasses.length} lezioni',
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          ...todayClasses
              .map((classData) => _buildClassCard(classData))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    bool isPast = classData['status'] == 'confirmed';
    bool isUpcoming = classData['status'] == 'upcoming';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      child: Slidable(
        key: ValueKey(classData['time']),
        endActionPane: ActionPane(
          motion: ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _viewStudentList(classData),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.people,
              label: 'Lista',
              borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
            ),
            SlidableAction(
              onPressed: (_) => _sendMessage(classData),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.message,
              label: 'Messaggio',
            ),
            SlidableAction(
              onPressed: (_) => _editClass(classData),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Modifica',
              borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
            ),
          ],
        ),
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPast
                  ? Colors.green.withAlpha(77)
                  : isUpcoming
                      ? Colors.orange.withAlpha(77)
                      : Colors.grey.withAlpha(77),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: classData['color'],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${classData['time']} - ${classData['discipline']}',
                          style: GoogleFonts.inter(
                            color: classData['color'],
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _buildStatusBadge(classData['status']),
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      classData['level'],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.grey[400], size: 4.w),
                        SizedBox(width: 2.w),
                        Text(
                          '${classData['students']}/${classData['maxStudents']} studenti',
                          style: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 10.sp,
                          ),
                        ),
                        Spacer(),
                        if (isPast)
                          GestureDetector(
                            onTap: () => _markAttendance(classData),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 2.w, vertical: 0.5.h),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(51),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.green.withAlpha(128)),
                              ),
                              child: Text(
                                'Presenza',
                                style: GoogleFonts.inter(
                                  color: Colors.green,
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = 'COMPLETATA';
        break;
      case 'upcoming':
        color = Colors.orange;
        text = 'PROSSIMA';
        break;
      default:
        color = Colors.grey;
        text = 'PROGRAMMATA';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 7.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _viewStudentList(Map<String, dynamic> classData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lista Studenti - ${classData['discipline']} ${classData['time']}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            // Mock student list
            ...List.generate(classData['students'], (index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.withAlpha(51),
                  child: Text(
                    'S${index + 1}',
                    style:
                        GoogleFonts.inter(color: Colors.red, fontSize: 10.sp),
                  ),
                ),
                title: Text(
                  'Studente ${index + 1}',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                trailing: Icon(Icons.check_circle, color: Colors.green),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _sendMessage(Map<String, dynamic> classData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Invio messaggio per ${classData['discipline']} delle ${classData['time']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _editClass(Map<String, dynamic> classData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Modifica lezione ${classData['discipline']} delle ${classData['time']}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _markAttendance(Map<String, dynamic> classData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Segna presenze per ${classData['discipline']} delle ${classData['time']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}