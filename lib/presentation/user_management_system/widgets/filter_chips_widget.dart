import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_theme.dart';

class FilterChipsWidget extends StatelessWidget {
  final String selectedRoleFilter;
  final String selectedStatusFilter;
  final String selectedActivityFilter;
  final Function(String) onRoleFilterChanged;
  final Function(String) onStatusFilterChanged;
  final Function(String) onActivityFilterChanged;

  const FilterChipsWidget({
    super.key,
    required this.selectedRoleFilter,
    required this.selectedStatusFilter,
    required this.selectedActivityFilter,
    required this.onRoleFilterChanged,
    required this.onStatusFilterChanged,
    required this.onActivityFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtri Avanzati',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          SizedBox(height: 8.h),

          // Role filters
          Text(
            'Ruolo:',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 11.sp,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 6.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Tutti',
                  'all',
                  selectedRoleFilter,
                  Colors.grey,
                  onRoleFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Studenti',
                  'student',
                  selectedRoleFilter,
                  Colors.green,
                  onRoleFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Istruttori',
                  'instructor',
                  selectedRoleFilter,
                  Colors.blue,
                  onRoleFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Amministratori',
                  'admin',
                  selectedRoleFilter,
                  Colors.orange,
                  onRoleFilterChanged,
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Status filters
          Text(
            'Stato Abbonamento:',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 11.sp,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 6.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Tutti',
                  'all',
                  selectedStatusFilter,
                  Colors.grey,
                  onStatusFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Attivi',
                  'active',
                  selectedStatusFilter,
                  Colors.green,
                  onStatusFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Inattivi',
                  'inactive',
                  selectedStatusFilter,
                  Colors.red,
                  onStatusFilterChanged,
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Activity level filters
          Text(
            'Livello Attività:',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 11.sp,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 6.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Tutti',
                  'all',
                  selectedActivityFilter,
                  Colors.grey,
                  onActivityFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Molto Attivi',
                  'high',
                  selectedActivityFilter,
                  Colors.green,
                  onActivityFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Moderati',
                  'medium',
                  selectedActivityFilter,
                  Colors.orange,
                  onActivityFilterChanged,
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  'Poco Attivi',
                  'low',
                  selectedActivityFilter,
                  Colors.red,
                  onActivityFilterChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Color color,
    Function(String) onChanged,
  ) {
    final isSelected = selectedValue == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(26) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isSelected
                  ? color
                  : AppTheme.textSecondaryLight.withAlpha(77),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 14.sp,
                ),
                SizedBox(width: 4.w),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? color : AppTheme.textSecondaryLight,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
