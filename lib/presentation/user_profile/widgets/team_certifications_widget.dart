import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../constants/app_constants.dart';

class TeamCertificationsWidget extends StatelessWidget {
  const TeamCertificationsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Color(0xFFFF0000).withAlpha(77), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Color(0xFFFF0000), size: 20.sp),
              SizedBox(width: 2.w),
              Text(
                'Certificazioni e Affiliazioni',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Federkombat Affiliation Section
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withAlpha(77), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Federkombat Logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.all(2),
                      child: Image.asset(
                        'assets/images/149037-1756509894793.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FEDERKOMBAT',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Federazione Nazionale Sportiva',
                            style: GoogleFonts.inter(
                              color: Colors.green,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Team Affiliato',
                              style: GoogleFonts.inter(
                                color: Colors.green,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Il Team Ragnarok è ufficialmente affiliato alla Federazione Italiana Savate Kickboxing • Muay Thai Shoot Boxe • Sambo • MMA • Grappling',
                  style: GoogleFonts.inter(
                    color: Colors.grey[300],
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // UIJJ Affiliation Section
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withAlpha(77), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // UIJJ Logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black,
                      ),
                      padding: EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/162741-1758188985237.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UIJJ',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Unione Italiana Jiu-Jitsu',
                            style: GoogleFonts.inter(
                              color: Colors.orange,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Team Affiliato',
                              style: GoogleFonts.inter(
                                color: Colors.orange,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Il Team Ragnarok è affiliato all\'Unione Italiana Jiu-Jitsu, riconoscimento che attesta la qualità dell\'insegnamento e la competenza tecnica nella disciplina del Brazilian Jiu-Jitsu.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[300],
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Rolling JJ Academy Affiliation Section
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withAlpha(77), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Rolling JJ Academy Logo - using provided asset
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/149046-1756510853047.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROLLING JJ ACADEMY',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Brazilian Jiu-Jitsu & Grappling',
                            style: GoogleFonts.inter(
                              color: Colors.purple,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Team Affiliato',
                              style: GoogleFonts.inter(
                                color: Colors.purple,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Il Team Ragnarok è affiliato alla Rolling JJ Academy per l\'insegnamento del Brazilian Jiu-Jitsu e del Grappling con metodologie e curriculum di altissimo livello.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[300],
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Network Aurora Affiliation Section
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withAlpha(77), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Network Aurora Logo
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black,
                      ),
                      padding: EdgeInsets.all(2),
                      child: Image.asset(
                        'assets/images/146802-1756510514652.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NETWORK AURORA',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Mixed Martial Arts',
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Network Partner',
                              style: GoogleFonts.inter(
                                color: Colors.red,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Il Team Ragnarok fa parte del Network Aurora, il più importante network in Italia per le MMA, garantendo standard di eccellenza nella formazione degli atleti.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[300],
                    fontSize: 11.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Instructors Qualifications Section
          Text(
            'Istruttori Qualificati',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),

          // Qualifications List
          Column(
            children: [
              _buildQualificationItem(
                'FK',
                'Federkombat',
                'Istruttori certificati Federkombat',
                Colors.green,
              ),
              SizedBox(height: 1.h),
              _buildQualificationItem(
                'FIJLKAM',
                'Federazione Italiana Judo Lotta Karate Arti Marziali',
                'Qualifica nazionale FIJLKAM',
                Colors.blue,
              ),
              SizedBox(height: 1.h),
              _buildQualificationItem(
                'BJJ',
                'BJJ Italia',
                'Certificazione Brazilian Jiu-Jitsu Italia',
                Colors.purple,
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // Quality Assurance Banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF0000).withAlpha(26),
                  Color(0xFFFF0000).withAlpha(51),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Color(0xFFFF0000).withAlpha(77),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.stars, color: Color(0xFFFF0000), size: 18.sp),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Garanzia di qualità e professionalità nell\'insegnamento delle arti marziali',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationItem(
    String acronym,
    String fullName,
    String description,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                acronym,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified, color: color, size: 16.sp),
        ],
      ),
    );
  }
}
