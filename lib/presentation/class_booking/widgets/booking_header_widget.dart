import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class BookingHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> classData;

  const BookingHeaderWidget({Key? key, required this.classData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(classData['instructor']['photo']),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData['discipline'],
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'con ${classData['instructor']['name']}',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.red, size: 20),
              SizedBox(width: 8.w),
              Text(
                classData['date'],
                style: GoogleFonts.inter(fontSize: 16.sp, color: Colors.white),
              ),
              SizedBox(width: 24.w),
              Icon(Icons.access_time, color: Colors.red, size: 20),
              SizedBox(width: 8.w),
              Text(
                classData['time'],
                style: GoogleFonts.inter(fontSize: 16.sp, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
