import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';

class DashboardHeaderWidget extends StatelessWidget {
  const DashboardHeaderWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withAlpha(77), Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 15.w,
                height: 15.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                  image: DecorationImage(
                    image: NetworkImage(
                        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buongiorno, Marco!',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Istruttore Senior • Team Ragnarok',
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        Image.asset(
                          AppConstants.teamLogo,
                          width: 5.w,
                          height: 2.5.h,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'profile.disciplines_tagline'.tr(),
                          style: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 9.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Lezioni Oggi', '6', Icons.schedule, Colors.blue),
        _buildStatItem('Studenti Attivi', '24', Icons.people, Colors.green),
        _buildStatItem('Questo Mese', '€2,890', Icons.euro, Colors.orange),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color.withAlpha(51),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(128)),
          ),
          child: Icon(icon, color: color, size: 5.w),
        ),
        SizedBox(height: 1.h),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 9.sp,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
