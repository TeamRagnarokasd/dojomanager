import 'package:supabase_flutter/supabase_flutter.dart';

class EnhancedInstructorDashboardService {
  static final EnhancedInstructorDashboardService _instance =
      EnhancedInstructorDashboardService._internal();
  factory EnhancedInstructorDashboardService() => _instance;
  EnhancedInstructorDashboardService._internal();

  static EnhancedInstructorDashboardService get instance => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get instructor profile with user data
  Future<Map<String, dynamic>?> getInstructorProfile(String userId) async {
    try {
      final response = await _supabase
          .from('instructor_profiles')
          .select('''
            *,
            user_profiles!instructor_profiles_user_id_fkey(
              id,
              full_name,
              email,
              phone,
              profile_image_url,
              role
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (error) {
      print('Error fetching instructor profile: $error');
      return null;
    }
  }

  /// Get today's schedule instances for instructor
  Future<List<Map<String, dynamic>>> getTodaySchedule(
    String instructorId,
  ) async {
    try {
      final today = DateTime.now();
      final todayDateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabase
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
          .eq('class_date', todayDateString)
          .eq('is_cancelled', false)
          .order('start_time', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching today schedule: $error');
      return [];
    }
  }

  /// Get upcoming classes (next 7 days)
  Future<List<Map<String, dynamic>>> getUpcomingClasses(
    String instructorId,
  ) async {
    try {
      final today = DateTime.now();
      final nextWeek = today.add(const Duration(days: 7));

      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final nextWeekString =
          '${nextWeek.year}-${nextWeek.month.toString().padLeft(2, '0')}-${nextWeek.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('schedule_instances')
          .select('''
            id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            max_capacity,
            is_cancelled
          ''')
          .eq('instructor_id', instructorId)
          .gte('class_date', todayString)
          .lte('class_date', nextWeekString)
          .eq('is_cancelled', false)
          .order('class_date', ascending: true)
          .order('start_time', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching upcoming classes: $error');
      return [];
    }
  }

  /// Get recent payment confirmations for instructor's classes
  Future<List<Map<String, dynamic>>> getRecentPayments({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('payment_confirmations')
          .select('''
            id,
            amount,
            status,
            payment_method,
            confirmed_at,
            created_at,
            user_profiles!payment_confirmations_user_id_fkey(
              full_name,
              email
            ),
            subscription_plans!payment_confirmations_subscription_plan_id_fkey(
              name,
              plan_type
            )
          ''')
          .eq('status', 'confirmed')
          .order('confirmed_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching recent payments: $error');
      return [];
    }
  }

  /// Get revenue analytics for instructor
  Future<Map<String, dynamic>> getRevenueAnalytics() async {
    try {
      final today = DateTime.now();
      final firstDayOfMonth = DateTime(today.year, today.month, 1);
      final lastDayOfMonth = DateTime(today.year, today.month + 1, 0);

      final firstDayString =
          '${firstDayOfMonth.year}-${firstDayOfMonth.month.toString().padLeft(2, '0')}-${firstDayOfMonth.day.toString().padLeft(2, '0')}';
      final lastDayString =
          '${lastDayOfMonth.year}-${lastDayOfMonth.month.toString().padLeft(2, '0')}-${lastDayOfMonth.day.toString().padLeft(2, '0')}';

      // Get monthly confirmed payments
      final monthlyPayments = await _supabase
          .from('payment_confirmations')
          .select('amount')
          .eq('status', 'confirmed')
          .gte('confirmed_at', firstDayString)
          .lte('confirmed_at', lastDayString);

      // Calculate total monthly revenue
      double monthlyRevenue = 0.0;
      for (var payment in monthlyPayments) {
        monthlyRevenue += (payment['amount'] as num).toDouble();
      }

      // Get total confirmed payments count
      final totalPaymentsData = await _supabase
          .from('payment_confirmations')
          .select('id')
          .eq('status', 'confirmed')
          .count();

      return {
        'monthly_revenue': monthlyRevenue,
        'total_payments': totalPaymentsData.count ?? 0,
        'currency': '€',
      };
    } catch (error) {
      print('Error fetching revenue analytics: $error');
      return {'monthly_revenue': 0.0, 'total_payments': 0, 'currency': '€'};
    }
  }

  /// Get student progress summary
  Future<Map<String, dynamic>> getStudentProgressSummary() async {
    try {
      // Get active students count
      final activeStudentsData = await _supabase
          .from('user_profiles')
          .select('id')
          .inFilter('role', ['student', 'instructor_student'])
          .eq('is_active', true)
          .eq('status', 'approved')
          .count();

      // Get active subscriptions count
      final activeSubscriptionsData = await _supabase
          .from('user_subscriptions')
          .select('id')
          .eq('is_active', true)
          .count();

      return {
        'active_students': activeStudentsData.count ?? 0,
        'active_subscriptions': activeSubscriptionsData.count ?? 0,
      };
    } catch (error) {
      print('Error fetching student progress: $error');
      return {'active_students': 0, 'active_subscriptions': 0};
    }
  }

  /// Get instructor's class history
  Future<List<Map<String, dynamic>>> getClassHistory(
    String instructorId, {
    int limit = 10,
  }) async {
    try {
      final today = DateTime.now();
      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabase
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
          .lt('class_date', todayString)
          .order('class_date', ascending: false)
          .order('start_time', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching class history: $error');
      return [];
    }
  }

  /// Get instructor notifications/activities
  Future<List<Map<String, dynamic>>> getInstructorNotifications(
    String userId, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('admin_activity_log')
          .select('''
            id,
            action_type,
            details,
            created_at,
            user_profiles!admin_activity_log_admin_id_fkey(
              full_name
            )
          ''')
          .eq('target_user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching instructor notifications: $error');
      return [];
    }
  }

  /// Cancel a class
  Future<bool> cancelClass(String classId, String reason) async {
    try {
      await _supabase
          .from('schedule_instances')
          .update({
            'is_cancelled': true,
            'cancellation_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', classId);

      return true;
    } catch (error) {
      print('Error canceling class: $error');
      return false;
    }
  }

  /// Update instructor availability
  Future<bool> updateAvailability(
    String instructorId,
    Map<String, dynamic> availabilitySchedule,
  ) async {
    try {
      await _supabase
          .from('instructor_profiles')
          .update({
            'availability_schedule': availabilitySchedule,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', instructorId);

      return true;
    } catch (error) {
      print('Error updating availability: $error');
      return false;
    }
  }
}
