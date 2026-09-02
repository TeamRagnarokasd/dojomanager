import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';

class RevenueAnalyticsWidget extends StatefulWidget {
  const RevenueAnalyticsWidget({Key? key}) : super(key: key);

  @override
  State<RevenueAnalyticsWidget> createState() => _RevenueAnalyticsWidgetState();
}

class _RevenueAnalyticsWidgetState extends State<RevenueAnalyticsWidget> {
  int selectedPeriod = 0; // 0: Mese, 1: Trimestre, 2: Anno

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
                'Analytics Revenue',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildPeriodSelector(),
            ],
          ),
          SizedBox(height: 3.h),
          _buildRevenueStats(),
          SizedBox(height: 3.h),
          _buildChart(),
          SizedBox(height: 2.h),
          _buildClassPopularity(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(1.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('Mese', 0),
          _buildPeriodButton('3M', 1),
          _buildPeriodButton('Anno', 2),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    bool isSelected = selectedPeriod == index;
    return GestureDetector(
      onTap: () => setState(() => selectedPeriod = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withAlpha(77) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.red : Colors.grey[400],
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Guadagni Mensili',
            '€2,890',
            '+12.5%',
            Colors.green,
            Icons.trending_up,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: _buildStatCard(
            'seasonal_schedule.total_lessons'.tr(),
            '124',
            '+8 vs scorso mese',
            Colors.blue,
            Icons.school,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, String change, Color color, IconData icon) {
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
            children: [
              Icon(icon, color: color, size: 4.w),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 9.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            change,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 8.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 20.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = [
                    'Lun',
                    'Mar',
                    'Mer',
                    'Gio',
                    'Ven',
                    'Sab',
                    'Dom'
                  ];
                  if (value.toInt() < days.length) {
                    return Text(
                      days[value.toInt()],
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 8.sp,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, 3),
                FlSpot(1, 1),
                FlSpot(2, 4),
                FlSpot(3, 2),
                FlSpot(4, 5),
                FlSpot(5, 3),
                FlSpot(6, 4),
              ],
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withAlpha(51),
              ),
            ),
          ],
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 6,
        ),
      ),
    );
  }

  Widget _buildClassPopularity() {
    List<Map<String, dynamic>> popularClasses = [
      {'name': 'BJJ Principianti', 'students': 15, 'color': Colors.blue},
      {'name': 'MMA Open', 'students': 12, 'color': Colors.purple},
      {'name': 'SAMBO Avanzato', 'students': 10, 'color': Colors.orange},
      {'name': 'Grappling', 'students': 8, 'color': Colors.green},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lezioni Più Popolari',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        ...popularClasses.map((classData) => _buildPopularClassItem(classData)),
      ],
    );
  }

  Widget _buildPopularClassItem(Map<String, dynamic> classData) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 1.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: classData['color'],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              classData['name'],
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: classData['color'].withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${classData['students']} studenti',
              style: GoogleFonts.inter(
                color: classData['color'],
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
