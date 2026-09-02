import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../services/sponsor_service.dart';

class TeamCertificationsWidget extends StatefulWidget {
  const TeamCertificationsWidget({super.key});

  @override
  State<TeamCertificationsWidget> createState() =>
      _TeamCertificationsWidgetState();
}

class _TeamCertificationsWidgetState extends State<TeamCertificationsWidget> {
  List<Map<String, dynamic>> _affiliazioni = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAffiliazioni();
  }

  Future<void> _loadAffiliazioni() async {
    try {
      final data = await SponsorService.getActiveAffiliazioni();
      if (mounted) {
        setState(() {
          _affiliazioni = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading affiliazioni: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      HapticFeedback.lightImpact();
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  // Determine border color based on index for visual variety
  Color _getBorderColor(int index) {
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.blue,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  Color _getSubtitleColor(int index) {
    final colors = [
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.blue,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: const Color(0xFFFF0000).withAlpha(77),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: const Color(0xFFFF0000), size: 20.sp),
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

          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: const Color(0xFFFF0000)),
            )
          else if (_affiliazioni.isEmpty)
            Center(
              child: Text(
                'Nessuna affiliazione disponibile',
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 12.sp,
                ),
              ),
            )
          else
            ...List.generate(_affiliazioni.length, (index) {
              final item = _affiliazioni[index];
              final borderColor = _getBorderColor(index);
              final subtitleColor = _getSubtitleColor(index);
              final hasUrl =
                  item['external_url'] != null &&
                  (item['external_url'] as String).isNotEmpty;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < _affiliazioni.length - 1 ? 2.h : 0,
                ),
                child: GestureDetector(
                  onTap: hasUrl ? () => _launchUrl(item['external_url']) : null,
                  child: Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor.withAlpha(77),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Logo
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child:
                                    item['image_url'] != null &&
                                        (item['image_url'] as String).isNotEmpty
                                    ? Image.network(
                                        item['image_url'],
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.verified,
                                          color: borderColor,
                                          size: 30,
                                        ),
                                      )
                                    : Icon(
                                        Icons.verified,
                                        color: borderColor,
                                        size: 30,
                                      ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 0.5.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 2.w,
                                      vertical: 0.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: subtitleColor.withAlpha(51),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Team Affiliato',
                                      style: GoogleFonts.inter(
                                        color: subtitleColor,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasUrl)
                              Icon(
                                Icons.open_in_new,
                                color: Colors.grey[500],
                                size: 16,
                              ),
                          ],
                        ),
                        if (item['description'] != null &&
                            (item['description'] as String).isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            item['description'],
                            style: GoogleFonts.inter(
                              color: Colors.grey[300],
                              fontSize: 11.sp,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),

          SizedBox(height: 2.h),

          // Quality Assurance Banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF0000).withAlpha(26),
                  const Color(0xFFFF0000).withAlpha(51),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF0000).withAlpha(77),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.stars, color: const Color(0xFFFF0000), size: 18.sp),
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
}
