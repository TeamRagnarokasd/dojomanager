import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InstructorDashboardService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Get current user ID from Supabase auth
  static String? get currentUserId => _client.auth.currentUser?.id;

  /// Get today's classes for the instructor
  static Future<List<Map<String, dynamic>>> getTodayClasses(
      String instructorId) async {
    try {
      final today = DateTime.now();
      final todayString = DateFormat('yyyy-MM-dd').format(today);

      final response = await _client
          .from('schedule_instances')
          .select('''
            id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            cancellation_reason
          ''')
          .eq('instructor_id', instructorId)
          .eq('class_date', todayString)
          .eq('is_cancelled', false)
          .order('start_time');

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching today classes: $error');
      throw Exception('Errore nel caricamento delle lezioni di oggi: $error');
    }
  }

  /// Get instructor's week schedule
  static Future<List<Map<String, dynamic>>> getWeeklySchedule(
      String instructorId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final response = await _client
          .from('schedule_instances')
          .select('''
            id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            template:weekly_schedule_templates!template_id (
              notes,
              day_of_week
            )
          ''')
          .eq('instructor_id', instructorId)
          .gte('class_date', DateFormat('yyyy-MM-dd').format(startOfWeek))
          .lte('class_date', DateFormat('yyyy-MM-dd').format(endOfWeek))
          .order('class_date')
          .order('start_time');

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching weekly schedule: $error');
      throw Exception(
          'Errore nel caricamento del programma settimanale: $error');
    }
  }

  /// Get instructor analytics data
  static Future<Map<String, dynamic>> getInstructorAnalytics(
      String instructorId) async {
    try {
      // Get total classes this month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      final monthlyClassesResponse = await _client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .gte('class_date', DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
          .lte('class_date', DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
          .eq('is_cancelled', false);

      // Get classes today
      final todayString = DateFormat('yyyy-MM-dd').format(now);
      final todayClassesResponse = await _client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .eq('class_date', todayString)
          .eq('is_cancelled', false);

      // Get cancelled classes this month
      final cancelledClassesResponse = await _client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .gte('class_date', DateFormat('yyyy-MM-dd').format(firstDayOfMonth))
          .lte('class_date', DateFormat('yyyy-MM-dd').format(lastDayOfMonth))
          .eq('is_cancelled', true);

      return {
        'total_classes_month': monthlyClassesResponse.length,
        'classes_today': todayClassesResponse.length,
        'cancelled_classes': cancelledClassesResponse.length,
        'completion_rate': monthlyClassesResponse.length > 0
            ? ((monthlyClassesResponse.length -
                        cancelledClassesResponse.length) /
                    monthlyClassesResponse.length *
                    100)
                .round()
            : 100,
      };
    } catch (error) {
      print('Error fetching instructor analytics: $error');
      return {
        'total_classes_month': 0,
        'classes_today': 0,
        'cancelled_classes': 0,
        'completion_rate': 0,
      };
    }
  }

  /// Get recent activity for the instructor
  static Future<List<Map<String, dynamic>>> getRecentActivity(
      String instructorId,
      {int limit = 10}) async {
    try {
      final response = await _client
          .from('schedule_instances')
          .select('''
            id,
            class_date,
            start_time,
            discipline,
            location,
            is_cancelled,
            created_at,
            updated_at
          ''')
          .eq('instructor_id', instructorId)
          .order('updated_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching recent activity: $error');
      throw Exception('Errore nel caricamento dell\'attività recente: $error');
    }
  }

  /// Get student progress data (mock implementation)
  static Future<List<Map<String, dynamic>>> getStudentProgress(
      String instructorId) async {
    try {
      // This would typically join with a student_progress or attendance table
      // For now, return mock data based on class capacity and disciplines
      final classes = await _client
          .from('schedule_instances')
          .select('''
            discipline,
            max_capacity,
            class_date
          ''')
          .eq('instructor_id', instructorId)
          .gte(
              'class_date',
              DateFormat('yyyy-MM-dd')
                  .format(DateTime.now().subtract(const Duration(days: 30))))
          .eq('is_cancelled', false);

      // Group by discipline and calculate mock attendance
      Map<String, Map<String, dynamic>> disciplineStats = {};

      for (var classData in classes) {
        final discipline = classData['discipline'] as String;
        final capacity = classData['max_capacity'] as int;

        if (!disciplineStats.containsKey(discipline)) {
          disciplineStats[discipline] = {
            'discipline': discipline,
            'total_classes': 0,
            'total_capacity': 0,
            'estimated_attendance': 0,
          };
        }

        disciplineStats[discipline]!['total_classes']++;
        disciplineStats[discipline]!['total_capacity'] += capacity;
        // Mock 75-85% attendance rate
        disciplineStats[discipline]!['estimated_attendance'] +=
            (capacity * 0.8).round();
      }

      return disciplineStats.values.toList();
    } catch (error) {
      print('Error fetching student progress: $error');
      return [];
    }
  }

  /// Cancel a class
  static Future<bool> cancelClass(String classId, String reason) async {
    try {
      await _client.from('schedule_instances').update({
        'is_cancelled': true,
        'cancellation_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', classId);

      return true;
    } catch (error) {
      print('Error cancelling class: $error');
      return false;
    }
  }

  /// Create new class instance
  static Future<Map<String, dynamic>?> createClass({
    required String instructorId,
    required DateTime classDate,
    required String startTime,
    required String endTime,
    required String discipline,
    required String location,
    int maxCapacity = 20,
  }) async {
    try {
      final response = await _client
          .from('schedule_instances')
          .insert({
            'instructor_id': instructorId,
            'class_date': DateFormat('yyyy-MM-dd').format(classDate),
            'start_time': startTime,
            'end_time': endTime,
            'discipline': discipline,
            'location': location,
            'max_capacity': maxCapacity,
            'is_cancelled': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (error) {
      print('Error creating class: $error');
      throw Exception('Errore nella creazione della lezione: $error');
    }
  }

  /// Get instructor profile information
  static Future<Map<String, dynamic>?> getInstructorProfile(
      String instructorId) async {
    try {
      final response = await _client.from('user_profiles').select('''
            id,
            full_name,
            email,
            phone,
            profile_image_url,
            role,
            created_at
          ''').eq('id', instructorId).single();

      return response;
    } catch (error) {
      print('Error fetching instructor profile: $error');
      return null;
    }
  }

  /// Get class history for instructor
  static Future<List<Map<String, dynamic>>> getClassHistory(String instructorId,
      {int limit = 20}) async {
    try {
      final response = await _client
          .from('schedule_instances')
          .select('''
            id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            cancellation_reason
          ''')
          .eq('instructor_id', instructorId)
          .lt('class_date', DateFormat('yyyy-MM-dd').format(DateTime.now()))
          .order('class_date', ascending: false)
          .order('start_time', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching class history: $error');
      throw Exception('Errore nel caricamento dello storico lezioni: $error');
    }
  }
}
