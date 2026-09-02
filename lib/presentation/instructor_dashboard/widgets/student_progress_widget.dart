import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class StudentProgressWidget extends StatelessWidget {
  const StudentProgressWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 5.w),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Progressi Recenti',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildProgressItem(
            'Marco R.',
            'BJJ Cintura Blu',
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=50&h=50&fit=crop&crop=face',
            Colors.blue,
          ),
          SizedBox(height: 1.h),
          _buildProgressItem(
            'Sofia T.',
            'MMA Livello 2',
            'https://images.unsplash.com/photo-1494790108755-2616b612ad91?w=50&h=50&fit=crop&crop=face',
            Colors.purple,
          ),
          SizedBox(height: 1.h),
          _buildProgressItem(
            'Luca M.',
            'SAMBO Intermedio',
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=50&h=50&fit=crop&crop=face',
            Colors.orange,
          ),
          SizedBox(height: 2.h),
          _buildAddProgressButton(),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
      String name, String achievement, String avatarUrl, Color color) {
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: color, width: 1),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  achievement,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(1.w),
            decoration: BoxDecoration(
              color: color.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: color,
              size: 3.w,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProgressButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Handle add progress
        },
        icon: Icon(Icons.add, size: 4.w),
        label: Text(
          'Aggiungi Progresso',
          style: GoogleFonts.inter(fontSize: 10.sp),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withAlpha(51),
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.withAlpha(128)),
          padding: EdgeInsets.symmetric(vertical: 1.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
