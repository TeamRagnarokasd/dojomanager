import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_schedule_model.dart';
import '../services/supabase_service.dart';

class ClassScheduleService {
  static ClassScheduleService? _instance;
  static ClassScheduleService get instance =>
      _instance ??= ClassScheduleService._();

  ClassScheduleService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  /// List of available disciplines (without discontinued martial arts)
  static const List<String> _availableDisciplines = [
    'bjj',
    'mma',
    'sambo',
    'grappling',
    'fitness',
  ];

  /// Get class schedule for a specific date with enrollment data
  /// Enhanced to handle dates without instances by showing weekly template pattern
  Future<List<ClassScheduleModel>> getClassScheduleForDate(
    DateTime date,
  ) async {
    try {
      print(
        '📅 Fetching class schedule for: ${date.toIso8601String().split('T')[0]}',
      );

      // Use the correct existing function name
      final response = await _client.rpc(
        'get_class_schedule_with_enrollments',
        params: {'target_date': date.toIso8601String().split('T')[0]},
      );

      print(
        '📦 Response received: ${response?.toString().substring(0, response.toString().length > 200 ? 200 : response.toString().length)}...',
      );

      if (response == null || (response is List && response.isEmpty)) {
        print('⚠️ No schedule instances found, fetching weekly template...');
        // If no instances found, try to get the weekly template pattern
        return _getWeeklyTemplateForDate(date);
      }

      // Handle both List and single object responses
      List<dynamic> responseList;
      if (response is List) {
        responseList = response;
      } else {
        responseList = [response];
      }

      // Filter out any discontinued martial arts that might still exist
      final filteredResponse =
          responseList.where((item) {
            final discipline =
                item['discipline']?.toString().toLowerCase() ?? '';
            return _availableDisciplines.contains(discipline);
          }).toList();

      print('✅ Found ${filteredResponse.length} schedule instances');

      // If we got results, return them
      if (filteredResponse.isNotEmpty) {
        final classes =
            filteredResponse.map((json) {
              // Log instructor info for debugging
              final instructorName = json['instructor_name'] ?? 'Not set';
              print(
                '👤 Class: ${json['disciplineDisplayName'] ?? json['discipline']} - Instructor: $instructorName',
              );

              return ClassScheduleModel.fromJson(json as Map<String, dynamic>);
            }).toList();

        return classes;
      }

      // Otherwise, fall back to weekly template
      print('⚠️ No instances after filtering, fetching weekly template...');
      return _getWeeklyTemplateForDate(date);
    } catch (error) {
      print('❌ Error fetching class schedule: $error');

      // Try to get weekly template as fallback
      try {
        return await _getWeeklyTemplateForDate(date);
      } catch (templateError) {
        print('❌ Error fetching template: $templateError');
        return [];
      }
    }
  }

  /// Get weekly template pattern for a specific date
  /// This shows what classes SHOULD be scheduled based on the day of week
  Future<List<ClassScheduleModel>> _getWeeklyTemplateForDate(
    DateTime date,
  ) async {
    try {
      // Get the day of week (convert DateTime.weekday to our enum format)
      final dayOfWeek = _getDayOfWeekString(date.weekday);

      // Query weekly_schedule_templates for this day
      final response = await _client
          .from('weekly_schedule_templates')
          .select('''
            id,
            discipline,
            location,
            max_capacity,
            start_time,
            end_time,
            notes,
            instructor_id,
            seasonal_schedule_id,
            user_profiles!weekly_schedule_templates_instructor_id_fkey (
              full_name,
              email
            ),
            seasonal_schedules!weekly_schedule_templates_seasonal_schedule_id_fkey (
              id,
              status,
              start_date,
              end_date
            )
          ''')
          .eq('day_of_week', dayOfWeek)
          .inFilter('discipline', _availableDisciplines);

      if (response.isEmpty) {
        return [];
      }

      // Filter to active seasonal schedules that cover the target date
      final activeTemplates =
          response.where((template) {
            final season = template['seasonal_schedules'];
            if (season == null) return false;

            final status = season['status'];
            final startDate = DateTime.parse(season['start_date']);
            final endDate = DateTime.parse(season['end_date']);

            // FIXED: Check if the target date falls within the season range AND season is active
            return status == 'active' &&
                !date.isBefore(startDate) && // date >= startDate
                !date.isAfter(endDate); // date <= endDate
          }).toList();

      if (activeTemplates.isEmpty) {
        print('No active templates found for date: $date, day: $dayOfWeek');
        return [];
      }

      // Transform templates into ClassScheduleModel format
      return activeTemplates.map((template) {
        final transformedJson = <String, dynamic>{
          'id': template['id'], // Use template ID as temporary instance ID
          'discipline': template['discipline'],
          'disciplineDisplayName': _mapDbValueToUI(
            template['discipline'] ?? 'bjj',
          ),
          'instructor_name':
              template['user_profiles']?['full_name'] ??
              'Istruttore Disponibile',
          'instructor_email': template['user_profiles']?['email'] ?? '',
          'instructor_bio': 'Istruttore esperto con anni di esperienza',
          'time_range': '${template['start_time']} - ${template['end_time']}',
          'date_formatted': _formatDate(date.toIso8601String().split('T')[0]),
          'capacity': template['max_capacity'] ?? 20,
          'location': template['location'],
          'is_cancelled': false,
          'cancellation_reason': null,
          'is_holiday_affected': false,
          'is_modified': false,
          'updated_at': DateTime.now().toIso8601String(),
          'start_time': template['start_time'],
          'end_time': template['end_time'],
          'class_date': date.toIso8601String().split('T')[0],
          'enrolled': 0, // No enrollments for template view
          'is_booked': false,
          'waitlist_position': null,
          'description':
              template['notes'] ??
              'Allenamento di ${_mapDbValueToUI(template['discipline'] ?? 'bjj')}',
        };

        return ClassScheduleModel.fromJson(transformedJson);
      }).toList();
    } catch (error) {
      print('Error fetching weekly template: $error');
      return [];
    }
  }

  /// Convert DateTime.weekday to our day_of_week enum format
  String _getDayOfWeekString(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  /// Get user's class registrations
  Future<List<Map<String, dynamic>>> getUserRegistrations({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      var query = _client
          .from('class_registrations')
          .select('''
        id,
        registration_status,
        registered_at,
        cancelled_at,
        cancellation_reason,
        schedule_instances!inner (
          id,
          discipline,
          location,
          start_time,
          end_time,
          class_date,
          max_capacity,
          user_profiles!schedule_instances_instructor_id_fkey (
            full_name
          )
        )
      ''')
          .eq('user_id', userId);

      if (startDate != null) {
        query = query.gte(
          'schedule_instances.class_date',
          startDate.toIso8601String().split('T')[0],
        );
      }

      if (endDate != null) {
        query = query.lte(
          'schedule_instances.class_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('registration_status', status);
      }

      final response = await query.order('registered_at', ascending: false);

      return response.cast<Map<String, dynamic>>();
    } catch (error) {
      print('Error fetching user registrations: $error');
      return [];
    }
  }

  /// Check if user can register for a class
  Future<bool> canRegisterForClass(String classId) async {
    try {
      final response = await _client.rpc(
        'can_register_for_class',
        params: {
          'instance_id': classId,
          'requesting_user_id': _client.auth.currentUser?.id,
        },
      );

      return response == true;
    } catch (error) {
      print('Error checking registration eligibility: $error');
      return false;
    }
  }

  /// Get enrollment count for a specific class
  Future<int> getEnrollmentCount(String classId) async {
    try {
      final response = await _client.rpc(
        'get_current_enrollment_count',
        params: {'instance_id': classId},
      );

      return response ?? 0;
    } catch (error) {
      print('Error getting enrollment count: $error');
      return 0;
    }
  }

  /// Get all schedule instances with filters
  Future<List<ClassScheduleModel>> getScheduleInstances({
    DateTime? startDate,
    DateTime? endDate,
    String? discipline,
    String? instructorId,
    bool includeCancel = false,
  }) async {
    try {
      var query = _client.from('schedule_instances').select('''
            id,
            discipline,
            location,
            max_capacity,
            is_cancelled,
            cancellation_reason,
            is_holiday_affected,
            start_time,
            end_time,
            class_date,
            created_at,
            updated_at,
            user_profiles!schedule_instances_instructor_id_fkey (
              full_name,
              email
            )
          ''');

      // Apply filters
      if (startDate != null) {
        query = query.gte(
          'class_date',
          startDate.toIso8601String().split('T')[0],
        );
      }

      if (endDate != null) {
        query = query.lte(
          'class_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      if (discipline != null && discipline.isNotEmpty && discipline != 'all') {
        if (_availableDisciplines.contains(discipline.toLowerCase())) {
          query = query.eq('discipline', discipline);
        } else {
          return [];
        }
      }

      if (instructorId != null && instructorId.isNotEmpty) {
        query = query.eq('instructor_id', instructorId);
      }

      if (!includeCancel) {
        query = query.eq('is_cancelled', false);
      }

      query = query.inFilter('discipline', _availableDisciplines);

      final response = await query.order('class_date').order('start_time');

      return response.map((json) {
        // Calculate if modified (updated_at > created_at + 1 minute)
        final createdAt = DateTime.parse(json['created_at']);
        final updatedAt = DateTime.parse(json['updated_at']);
        final isModified = updatedAt.difference(createdAt).inMinutes > 1;

        final transformedJson = <String, dynamic>{
          'id': json['id'],
          'discipline': json['discipline'],
          'disciplineDisplayName': _mapDbValueToUI(json['discipline'] ?? 'bjj'),
          'instructor_name':
              json['user_profiles']?['full_name'] ?? 'Istruttore Disponibile',
          'instructor_email': json['user_profiles']?['email'] ?? '',
          'instructor_bio': 'Istruttore esperto con anni di esperienza',
          'time_range': '${json['start_time']} - ${json['end_time']}',
          'date_formatted': _formatDate(json['class_date']),
          'capacity': json['max_capacity'],
          'location': json['location'],
          'is_cancelled': json['is_cancelled'],
          'cancellation_reason': json['cancellation_reason'],
          'is_holiday_affected': json['is_holiday_affected'],
          'is_modified': isModified,
          'updated_at': json['updated_at'],
          'start_time': json['start_time'],
          'end_time': json['end_time'],
          'class_date': json['class_date'],
          'enrolled': _generateRandomEnrolled(json['max_capacity']),
          'is_booked': false,
          'waitlist_position': null,
          'description':
              'Allenamento di ${_mapDbValueToUI(json['discipline'] ?? 'bjj')}',
        };

        return ClassScheduleModel.fromJson(transformedJson);
      }).toList();
    } catch (error) {
      print('Error fetching schedule instances: $error');
      return [];
    }
  }

  /// Get weekly schedule for a specific week
  Future<List<ClassScheduleModel>> getWeeklySchedule(DateTime weekStart) async {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return getScheduleInstances(
      startDate: weekStart,
      endDate: weekEnd,
      includeCancel: false,
    );
  }

  /// Book a class (real implementation with Supabase)
  Future<bool> bookClass(String classId) async {
    try {
      final response = await _client.rpc(
        'register_for_class',
        params: {
          'instance_id': classId,
          'subscription_id':
              null, // Could be enhanced to pass active subscription
        },
      );

      if (response != null && response['success'] == true) {
        return true;
      } else {
        print('Booking failed: ${response?['error'] ?? 'Unknown error'}');
        return false;
      }
    } catch (error) {
      print('Error booking class: $error');
      return false;
    }
  }

  /// Cancel a class booking (real implementation with Supabase)
  Future<bool> cancelBooking(String classId) async {
    try {
      final response = await _client.rpc(
        'cancel_class_registration',
        params: {
          'instance_id': classId,
          'cancellation_reason': 'Cancellato dall\'utente',
        },
      );

      if (response != null && response['success'] == true) {
        return true;
      } else {
        print('Cancellation failed: ${response?['error'] ?? 'Unknown error'}');
        return false;
      }
    } catch (error) {
      print('Error canceling booking: $error');
      return false;
    }
  }

  /// Get available disciplines for filtering (only current disciplines)
  Future<List<String>> getAvailableDisciplines() async {
    try {
      final response = await _client
          .from('schedule_instances')
          .select('discipline')
          .eq('is_cancelled', false)
          .inFilter('discipline', _availableDisciplines);

      final disciplines =
          response.map((item) => item['discipline'] as String).toSet().toList();

      disciplines.sort();
      return disciplines;
    } catch (error) {
      print('Error fetching disciplines: $error');
      return _availableDisciplines; // Return default list
    }
  }

  /// Get available instructors
  Future<List<Map<String, dynamic>>> getAvailableInstructors() async {
    try {
      final response = await _client
          .from('schedule_instances')
          .select('''
            instructor_id,
            user_profiles!schedule_instances_instructor_id_fkey (
              id,
              full_name,
              email
            )
          ''')
          .eq('is_cancelled', false)
          .inFilter('discipline', _availableDisciplines);

      final instructorsMap = <String, Map<String, dynamic>>{};

      for (final item in response) {
        final profile = item['user_profiles'];
        if (profile != null) {
          final id = profile['id'] as String;
          if (!instructorsMap.containsKey(id)) {
            instructorsMap[id] = {
              'id': id,
              'full_name': profile['full_name'],
              'email': profile['email'],
            };
          }
        }
      }

      return instructorsMap.values.toList();
    } catch (error) {
      print('Error fetching instructors: $error');
      return [];
    }
  }

  /// Subscribe to real-time schedule updates
  RealtimeChannel subscribeToScheduleUpdates(
    Function(List<ClassScheduleModel>) onUpdate,
  ) {
    return _client
        .channel('schedule_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'schedule_instances',
          callback: (payload) async {
            // Refresh the schedule when changes occur
            final today = DateTime.now();
            final updatedSchedule = await getClassScheduleForDate(today);
            onUpdate(updatedSchedule);
          },
        )
        .subscribe();
  }

  /// Helper method to format date
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  /// Helper method to generate random enrollment for demo purposes
  int _generateRandomEnrolled(int capacity) {
    // Generate realistic enrollment numbers
    if (capacity <= 0) return 0;

    // Random enrollment between 0 and capacity, with tendency to be fuller for popular classes
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    if (random < 20) {
      // 20% chance of being nearly full
      return (capacity * 0.8).round() +
          (random % (capacity - (capacity * 0.8).round()));
    } else if (random < 60) {
      // 40% chance of being moderately filled
      return (capacity * 0.4).round() +
          (random % (capacity - (capacity * 0.4).round()));
    } else {
      // 40% chance of having few enrollments
      return random % (capacity * 0.3).round();
    }
  }

  static String _mapDisciplineToDbValue(String uiDiscipline) {
    // Map UI display values to database enum values
    // Updated to only include valid discipline_type enum values
    switch (uiDiscipline.toLowerCase()) {
      case 'bjj':
        return 'bjj';
      case 'mma':
        return 'mma';
      case 'sambo':
        return 'sambo';
      case 'grappling':
        return 'grappling';
      case 'fitness':
      case 'prep. atletica':
        return 'fitness';
      default:
        return 'bjj'; // Default fallback to a valid enum value
    }
  }

  static String _mapDbValueToUI(String dbDiscipline) {
    // Map database enum values to UI display values
    switch (dbDiscipline.toLowerCase()) {
      case 'bjj':
        return 'BJJ';
      case 'mma':
        return 'MMA';
      case 'sambo':
        return 'Sambo';
      case 'grappling':
        return 'Grappling';
      case 'fitness':
        return 'Prep. Atletica';
      default:
        return 'BJJ'; // Default fallback
    }
  }

  // Updated method to fetch schedule with valid discipline filtering
  static Future<List<Map<String, dynamic>>> fetchScheduleByDiscipline(
    String discipline,
  ) async {
    try {
      var query = SupabaseService.instance.client
          .from('schedule_instances')
          .select('''
            *,
            instructor:user_profiles!schedule_instances_instructor_id_fkey(
              id,
              full_name,
              profile_image_url
            )
          ''')
          .eq('is_cancelled', false)
          .gte('class_date', DateTime.now().toIso8601String().split('T')[0]);

      // Apply discipline filter only for valid disciplines
      if (discipline != 'Tutti' && discipline.isNotEmpty) {
        final dbDiscipline = _mapDisciplineToDbValue(discipline);
        // Only apply filter if it's a valid enum value
        if ([
          'bjj',
          'mma',
          'sambo',
          'grappling',
          'fitness',
        ].contains(dbDiscipline)) {
          query = query.eq('discipline', dbDiscipline);
        }
      }

      final response = await query.order('class_date').order('start_time');

      // Map database values to UI-friendly values
      return response.map<Map<String, dynamic>>((item) {
        return {
          ...item,
          'discipline': _mapDbValueToUI(item['discipline'] ?? 'bjj'),
        };
      }).toList();
    } catch (e) {
      print('Error fetching schedule by discipline: $e');
      return [];
    }
  }
}
