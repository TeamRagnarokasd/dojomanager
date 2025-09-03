import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class MartialArtsProgressWidget extends StatelessWidget {
  const MartialArtsProgressWidget({Key? key}) : super(key: key);

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
          Text(
            'Progresso Arti Marziali',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _buildDisciplineCard(
              'BJJ', 'Cintura Blu', '156 ore', 0.6, Colors.blue),
          SizedBox(height: 2.h),
          _buildDisciplineCard(
              'SAMBO', 'Livello Intermedio', '89 ore', 0.4, Colors.orange),
          SizedBox(height: 2.h),
          _buildDisciplineCard(
              'MMA', 'Principiante Avanzato', '67 ore', 0.3, Colors.purple),
          SizedBox(height: 2.h),
          _buildDisciplineCard(
              'GRAPPLING', 'Intermedio', '123 ore', 0.5, Colors.green),
          SizedBox(height: 3.h),
          _buildAchievementsBadges(),
        ],
      ),
    );
  }

  Widget _buildDisciplineCard(String discipline, String rank, String hours,
      double progress, Color color) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                discipline,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                hours,
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            rank,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riconoscimenti',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.5.h),
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: [
            _buildBadge('🥉', 'Primo Torneo', Colors.amber),
            _buildBadge('🔥', '100 Lezioni', Colors.red),
            _buildBadge('💪', 'Atleta del Mese', Colors.blue),
            _buildBadge('🏆', 'Campionato Regionale', Colors.yellow),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String emoji, String title, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 12.sp)),
          SizedBox(width: 1.w),
          Text(
            title,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}