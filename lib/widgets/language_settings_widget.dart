import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../constants/profile_typography.dart';
import '../services/locale_service.dart';

/// Profile settings tile + bottom sheet to switch app language at runtime.
class LanguageSettingsWidget extends StatelessWidget {
  const LanguageSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _showLanguageSheet(context),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.language, color: Colors.red, size: 22),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'profile.language'.tr(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: ProfileTypography.rowLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    LocaleService.languageLabel(context.locale),
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: ProfileTypography.subtitle,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              current.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: ProfileTypography.caption,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 2.w),
            Icon(Icons.chevron_right, color: Colors.grey[500], size: 22),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 12.w,
                    height: 0.5.h,
                    margin: EdgeInsets.only(bottom: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  'profile.select_language'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.sectionTitle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                ...LocaleService.supportedLocales.map((locale) {
                  final isSelected =
                      sheetContext.locale.languageCode == locale.languageCode;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? Colors.red : Colors.grey,
                    ),
                    title: Text(
                      LocaleService.languageLabel(locale),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: ProfileTypography.rowLabel,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      locale.languageCode.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: ProfileTypography.caption,
                      ),
                    ),
                    onTap: () {
                      if (isSelected) {
                        Navigator.pop(sheetContext);
                        return;
                      }
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (!context.mounted) return;
                        await context.setLocale(locale);
                        await LocaleService.saveLocale(locale);
                      });
                    },
                  );
                }),
                SizedBox(height: 1.h),
              ],
            ),
          ),
        );
      },
    );
  }
}
