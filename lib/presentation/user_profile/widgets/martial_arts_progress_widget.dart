import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';
import '../../../services/supabase_service.dart';

class MartialArtsProgressWidget extends StatefulWidget {
  const MartialArtsProgressWidget({Key? key}) : super(key: key);

  @override
  State<MartialArtsProgressWidget> createState() =>
      _MartialArtsProgressWidgetState();
}

class _MartialArtsProgressWidgetState extends State<MartialArtsProgressWidget> {
  List<Map<String, dynamic>> _progressData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;

      if (user == null) return;

      // Load user subscription data which contains progress information
      final subscriptions = await client
          .from('user_subscriptions')
          .select(
              'subscription_plans(name, plan_type), entries_total, entries_remaining, is_active')
          .eq('user_id', user.id)
          .eq('is_active', true);

      // Load instructor profile if user is instructor
      final userProfile = await client
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      List<Map<String, dynamic>> progressList = [];

      if (userProfile['role'] == 'instructor' ||
          userProfile['role'] == 'admin' ||
          userProfile['role'] == 'principal_admin') {
        // For instructors/admins, show instructor progress
        try {
          final instructorProfile = await client
              .from('instructor_profiles')
              .select('disciplines, years_experience, achievements')
              .eq('user_id', user.id)
              .single();

          final disciplines = List<String>.from(
              instructorProfile['disciplines'] ?? ['bjj', 'mma']);
          final years = instructorProfile['years_experience'] ?? 0;
          final achievements =
              List<String>.from(instructorProfile['achievements'] ?? []);

          for (String discipline in disciplines) {
            progressList.add({
              'discipline': _formatDiscipline(discipline),
              'level': years > 10
                  ? 'Esperto'
                  : years > 5
                      ? 'Avanzato'
                      : 'Base',
              'progress': (years * 10).clamp(0, 100).toDouble(),
              'details': achievements.isNotEmpty
                  ? achievements.first
                  : 'Istruttore qualificato',
            });
          }
        } catch (e) {
          // If no instructor profile found, show basic progress
          progressList.add({
            'discipline': 'Team Ragnarok',
            'level': 'Istruttore',
            'progress': 100.0,
            'details': 'Staff qualificato',
          });
        }
      } else {
        // For students, show subscription-based progress
        if (subscriptions.isNotEmpty) {
          for (var subscription in subscriptions) {
            final planName =
                subscription['subscription_plans']['name'] ?? 'Piano Base';
            final total = subscription['entries_total'] ?? 0;
            final remaining = subscription['entries_remaining'] ?? 0;
            final used = total - remaining;

            progressList.add({
              'discipline': planName,
              'level': used > 50
                  ? 'Avanzato'
                  : used > 20
                      ? 'Intermedio'
                      : 'Novizio',
              'progress': total > 0 ? (used / total * 100).toDouble() : 0.0,
              'details': 'Utilizzati $used di $total ingressi',
            });
          }
        }
      }

      // If no specific progress, show default progress
      if (progressList.isEmpty) {
        progressList = [
          {
            'discipline': 'Brazilian Jiu-Jitsu',
            'level': 'Novizio',
            'progress': 25.0,
            'details': 'Inizio del percorso di apprendimento',
          },
        ];
      }

      setState(() {
        _progressData = progressList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading progress data: $e');
      setState(() {
        _progressData = [
          {
            'discipline': 'Brazilian Jiu-Jitsu',
            'level': 'Novizio',
            'progress': 25.0,
            'details': 'Dati non disponibili',
          },
        ];
        _isLoading = false;
      });
    }
  }

  String _formatDiscipline(String discipline) {
    switch (discipline.toLowerCase()) {
      case 'bjj':
        return 'Brazilian Jiu-Jitsu';
      case 'mma':
        return 'Mixed Martial Arts';
      case 'sambo':
        return 'SAMBO';
      case 'grappling':
        return 'Grappling';
      case 'fitness':
        return 'Prep. Atletica';
      default:
        return discipline.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(color: Colors.red.withAlpha(77)),
        ),
        child: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

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
            'Progressi Arti Marziali',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          ..._progressData.map((progress) => _buildProgressItem(progress)),
        ],
      ),
    );
  }

  Widget _buildProgressItem(Map<String, dynamic> progress) {
    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  progress['discipline'],
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: _getLevelColor(progress['level']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  progress['level'],
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          LinearProgressIndicator(
            value: progress['progress'] / 100,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            minHeight: 6,
          ),
          SizedBox(height: 0.5.h),
          Text(
            progress['details'],
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'novizio':
        return Colors.blue;
      case 'intermedio':
        return Colors.orange;
      case 'avanzato':
        return Colors.green;
      case 'esperto':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
