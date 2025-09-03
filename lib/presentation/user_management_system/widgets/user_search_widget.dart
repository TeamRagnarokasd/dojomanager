import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_theme.dart';

class UserSearchWidget extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearchChanged;

  const UserSearchWidget({
    super.key,
    required this.controller,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: AppTheme.textSecondaryLight.withAlpha(51),
              ),
            ),
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cerca utenti per nome, email o telefono...',
                hintStyle: GoogleFonts.inter(
                  color: AppTheme.textSecondaryLight,
                  fontSize: 14.sp,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppTheme.textSecondaryLight,
                  size: 20.sp,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.textSecondaryLight,
                          size: 18.sp,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: AppTheme.textPrimaryLight,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.textSecondaryLight,
                size: 14.sp,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Supporta ricerca in tempo reale con suggerimenti di completamento automatico',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
