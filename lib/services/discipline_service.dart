import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import './supabase_service.dart';

class DisciplineService {
  static DisciplineService? _instance;
  static DisciplineService get instance => _instance ??= DisciplineService._();

  DisciplineService._();

  final SupabaseClient _client = SupabaseService.instance.client;

  /// Get all active disciplines from instructor profiles and schedule templates
  Future<List<Map<String, dynamic>>> getActiveDisciplines() async {
    try {
      // Resolve current season to scope all queries
      final String? currentSeasonId = await _getCurrentSeasonId();

      // Get disciplines from active instructor profiles
      final instructorDisciplinesResponse = await _client
          .from('instructor_profiles')
          .select(
            'disciplines, primary_discipline, user_id, is_active, user_profiles!inner(full_name)',
          )
          .eq('is_active', true);

      // Get disciplines from weekly schedule templates (active seasonal schedules)
      var scheduleQuery = _client
          .from('weekly_schedule_templates')
          .select(
            'discipline, seasonal_schedule_id, seasonal_schedules!inner(status)',
          );
      if (currentSeasonId != null) {
        scheduleQuery = scheduleQuery.eq(
          'seasonal_schedule_id',
          currentSeasonId,
        );
      } else {
        scheduleQuery = scheduleQuery.eq('seasonal_schedules.status', 'active');
      }
      final scheduleDisciplinesResponse = await scheduleQuery;

      // Process and combine disciplines
      Set<String> activeDisciplines = {};
      Map<String, List<String>> disciplineInstructors = {};
      Map<String, List<String>> disciplineLocations = {};
      Map<String, Map<String, List<Map<String, dynamic>>>> disciplineSchedules =
          {};
      Map<String, double> disciplineWeeklyHours = {};
      Map<String, int> disciplineStudentCounts = {};
      Map<String, Map<String, dynamic>?> disciplineNextClasses = {};

      // Process instructor disciplines
      for (var instructor in instructorDisciplinesResponse) {
        final disciplines = List<String>.from(instructor['disciplines'] ?? []);
        final instructorName =
            instructor['user_profiles']['full_name'] ?? 'Istruttore';

        for (String discipline in disciplines) {
          activeDisciplines.add(discipline);
          disciplineInstructors[discipline] ??= [];

          if (!disciplineInstructors[discipline]!.contains(instructorName)) {
            disciplineInstructors[discipline]!.add(instructorName);
          }
        }
      }

      // Process schedule disciplines
      for (var schedule in scheduleDisciplinesResponse) {
        final discipline = schedule['discipline'];
        if (discipline != null) {
          activeDisciplines.add(discipline);
        }
      }

      // Get detailed schedule information for active disciplines
      if (activeDisciplines.isNotEmpty) {
        var detailedQuery = _client
            .from('weekly_schedule_templates')
            .select(
              'discipline, day_of_week, start_time, end_time, location, notes, instructor_id, max_capacity, seasonal_schedules!inner(status), user_profiles!inner(full_name)',
            )
            .inFilter('discipline', activeDisciplines.toList());
        if (currentSeasonId != null) {
          detailedQuery = detailedQuery.eq(
            'seasonal_schedule_id',
            currentSeasonId,
          );
        } else {
          detailedQuery = detailedQuery.eq(
            'seasonal_schedules.status',
            'active',
          );
        }
        final detailedSchedulesResponse = await detailedQuery;

        // Process schedules by discipline and day
        for (var schedule in detailedSchedulesResponse) {
          final discipline = schedule['discipline'];
          final dayOfWeek = schedule['day_of_week'];
          final startTime = schedule['start_time'];
          final endTime = schedule['end_time'];
          final location = schedule['location'];
          final notes = schedule['notes'];
          final maxCapacity = schedule['max_capacity'] ?? 20;
          final instructorName =
              schedule['user_profiles']['full_name'] ?? 'Istruttore';

          // Calculate weekly hours per discipline
          final classDuration = _calculateClassDurationFromTimes(
            startTime,
            endTime,
          );
          disciplineWeeklyHours[discipline] =
              (disciplineWeeklyHours[discipline] ?? 0.0) + classDuration;

          // Add to estimated student count (based on capacity)
          disciplineStudentCounts[discipline] =
              (disciplineStudentCounts[discipline] ?? 0) +
              ((maxCapacity as int) * 0.7).round();

          disciplineSchedules[discipline] ??= {};
          disciplineSchedules[discipline]![_formatDayName(dayOfWeek)] ??= [];

          disciplineSchedules[discipline]![_formatDayName(dayOfWeek)]!.add({
            'time': '$startTime-$endTime',
            'instructor': instructorName,
            'location': location ?? 'Sala Principale',
            'note': notes ?? '',
          });

          // Add locations
          if (location != null) {
            disciplineLocations[discipline] ??= [];
            if (!disciplineLocations[discipline]!.contains(location)) {
              disciplineLocations[discipline]!.add(location);
            }
          }

          // Add instructors from schedule (if not already added)
          disciplineInstructors[discipline] ??= [];
          if (!disciplineInstructors[discipline]!.contains(instructorName)) {
            disciplineInstructors[discipline]!.add(instructorName);
          }
        }

        // Get next classes from schedule_instances for the same season
        for (String discipline in activeDisciplines) {
          final nextClassData = await _getNextClassForDiscipline(
            discipline,
            seasonId: currentSeasonId,
          );
          disciplineNextClasses[discipline] = nextClassData;
        }
      }

      // Convert to required format
      return activeDisciplines.map((discipline) {
        return {
          'id': discipline,
          'name': _formatDisciplineName(discipline),
          'isActive': true,
          'color': _getDisciplineColor(discipline),
          'instructors': disciplineInstructors[discipline] ?? [],
          'locations': disciplineLocations[discipline] ?? ['Sala Principale'],
          'schedule': disciplineSchedules[discipline] ?? {},
          'weeklyHours': disciplineWeeklyHours[discipline] ?? 0.0,
          'studentCount': disciplineStudentCounts[discipline] ?? 0,
          'nextClass': disciplineNextClasses[discipline],
        };
      }).toList();
    } catch (error) {
      throw Exception('Failed to fetch disciplines: $error');
    }
  }

  /// Get the next scheduled class for a specific discipline
  Future<Map<String, dynamic>?> _getNextClassForDiscipline(
    String discipline, {
    String? seasonId,
  }) async {
    try {
      final now = DateTime.now();
      final currentDate = now.toIso8601String().split('T')[0];
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

      // Get upcoming schedule instances for this discipline
      var instanceQuery = _client
          .from('schedule_instances')
          .select(
            'class_date, start_time, end_time, location, instructor_id, is_cancelled, seasonal_schedule_id, user_profiles!inner(full_name)',
          )
          .eq('discipline', discipline)
          .eq('is_cancelled', false);
      if (seasonId != null) {
        instanceQuery = instanceQuery.eq('seasonal_schedule_id', seasonId);
      }
      final upcomingClasses = await instanceQuery
          .or(
            'class_date.gt.$currentDate,and(class_date.eq.$currentDate,start_time.gt.$currentTime)',
          )
          .order('class_date', ascending: true)
          .order('start_time', ascending: true)
          .limit(1);

      if (upcomingClasses.isEmpty) {
        return null;
      }

      final nextClass = upcomingClasses.first;
      final classDate = DateTime.parse(nextClass['class_date']);
      final dayName = _formatDayName(_getDayOfWeekString(classDate.weekday));
      final instructorName =
          nextClass['user_profiles']['full_name'] ?? 'Istruttore';

      return {
        'day': dayName,
        'time': '${nextClass['start_time']}-${nextClass['end_time']}',
        'date': nextClass['class_date'],
        'instructor': instructorName,
        'location': nextClass['location'] ?? 'Sala Principale',
        'note': '',
      };
    } catch (error) {
      print('Error getting next class for discipline $discipline: $error');
      return null;
    }
  }

  /// Resolve the current seasonal_schedule id
  /// Strategy: pick the most recently updated (or created) season so that
  /// discipline cards reflect the latest configured schedule, even if it's
  /// still in draft. This avoids showing stale data from an older active
  /// season when a new draft has just been edited and saved.
  Future<String?> _getCurrentSeasonId() async {
    try {
      // Most recently updated season wins (regardless of status)
      // We sort by updated_at first (desc), then created_at (desc) as a tie breaker
      final latest = await _client
          .from('seasonal_schedules')
          .select('id')
          .order('updated_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .limit(1);
      if (latest.isNotEmpty) {
        return latest.first['id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Calculate class duration from start and end times
  double _calculateClassDurationFromTimes(String startTime, String endTime) {
    try {
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      return (endMinutes - startMinutes) / 60.0;
    } catch (e) {
      return 1.5; // Default duration
    }
  }

  /// Convert weekday number to string
  String _getDayOfWeekString(int weekday) {
    switch (weekday) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  /// Get instructor profiles with their disciplines
  Future<List<Map<String, dynamic>>> getInstructorProfiles() async {
    try {
      final response = await _client
          .from('instructor_profiles')
          .select(
            'id, disciplines, primary_discipline, user_id, is_active, bio, years_experience, certifications, specializations, user_profiles!inner(full_name)',
          )
          .eq('is_active', true);

      return response.map<Map<String, dynamic>>((instructor) {
        final userProfile = instructor['user_profiles'];
        final fullName = userProfile['full_name'] ?? 'Nome non disponibile';

        return {
          'id': instructor['id'],
          'name': fullName,
          'disciplines': List<String>.from(instructor['disciplines'] ?? []),
          'primary_discipline': instructor['primary_discipline'],
          'bio': instructor['bio'],
          'years_experience': instructor['years_experience'],
          'certifications': List<String>.from(
            instructor['certifications'] ?? [],
          ),
          'specializations': List<String>.from(
            instructor['specializations'] ?? [],
          ),
          'is_active': instructor['is_active'],
        };
      }).toList();
    } catch (error) {
      throw Exception('Failed to fetch instructor profiles: $error');
    }
  }

  /// Create new discipline by creating instructor specialization
  Future<bool> addDisciplineToInstructor(
    String instructorId,
    String discipline,
  ) async {
    try {
      await _client.from('instructor_specializations').insert({
        'instructor_id': instructorId,
        'specialization': discipline,
        'proficiency_level': 'intermediate',
      });

      // Update instructor disciplines array
      final instructorResponse =
          await _client
              .from('instructor_profiles')
              .select('disciplines')
              .eq('id', instructorId)
              .single();

      final currentDisciplines = List<String>.from(
        instructorResponse['disciplines'] ?? [],
      );
      if (!currentDisciplines.contains(discipline)) {
        currentDisciplines.add(discipline);

        await _client
            .from('instructor_profiles')
            .update({'disciplines': currentDisciplines})
            .eq('id', instructorId);
      }

      return true;
    } catch (error) {
      throw Exception('Failed to add discipline: $error');
    }
  }

  /// Delete discipline (Principal Admin only)
  /// This method removes a discipline from:
  /// - All instructor profiles
  /// - All instructor specializations
  /// - All weekly schedule templates
  /// - All seasonal schedules that become empty
  Future<bool> deleteDiscipline(String disciplineId) async {
    try {
      // Start a transaction-like operation
      // Note: Supabase doesn't support explicit transactions in the client,
      // but we can use RLS policies to ensure data integrity

      // 1. Remove from instructor profiles disciplines arrays
      final instructorsWithDiscipline = await _client
          .from('instructor_profiles')
          .select('id, disciplines')
          .contains('disciplines', [disciplineId]);

      for (var instructor in instructorsWithDiscipline) {
        final currentDisciplines = List<String>.from(
          instructor['disciplines'] ?? [],
        );
        currentDisciplines.remove(disciplineId);

        await _client
            .from('instructor_profiles')
            .update({'disciplines': currentDisciplines})
            .eq('id', instructor['id']);

        // If this was the primary discipline, update to first remaining or null
        final instructorDetails =
            await _client
                .from('instructor_profiles')
                .select('primary_discipline')
                .eq('id', instructor['id'])
                .single();

        if (instructorDetails['primary_discipline'] == disciplineId) {
          final newPrimaryDiscipline =
              currentDisciplines.isNotEmpty ? currentDisciplines.first : null;
          await _client
              .from('instructor_profiles')
              .update({'primary_discipline': newPrimaryDiscipline})
              .eq('id', instructor['id']);
        }
      }

      // 2. Remove instructor specializations for this discipline
      await _client
          .from('instructor_specializations')
          .delete()
          .eq('specialization', disciplineId);

      // 3. Remove weekly schedule templates for this discipline
      await _client
          .from('weekly_schedule_templates')
          .delete()
          .eq('discipline', disciplineId);

      // 4. Check if any seasonal schedules are now empty and mark them as cancelled
      final allSchedules = await _client
          .from('seasonal_schedules')
          .select('id, status')
          .eq('status', 'active');

      for (var schedule in allSchedules) {
        final remainingTemplates = await _client
            .from('weekly_schedule_templates')
            .select('id')
            .eq('seasonal_schedule_id', schedule['id']);

        if (remainingTemplates.isEmpty) {
          await _client
              .from('seasonal_schedules')
              .update({
                'status': 'cancelled',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', schedule['id']);
        }
      }

      // 5. Clean up any schedule instances for this discipline
      await _client.rpc(
        'cleanup_schedule_instances_by_discipline',
        params: {'discipline_to_remove': disciplineId},
      );

      print('Successfully deleted discipline: $disciplineId');
      return true;
    } catch (error) {
      print('Error deleting discipline $disciplineId: $error');

      // For enum-based disciplines, they can't be "deleted" from the enum,
      // but we can remove all references to them
      if (error.toString().contains('violates foreign key constraint') ||
          error.toString().contains('invalid input value')) {
        print(
          'Note: Discipline $disciplineId is part of enum and cannot be removed from type definition',
        );
        // The cleanup above should still work to remove all references
        return true;
      }

      return false;
    }
  }

  /// Get available discipline types from enum
  List<String> getAvailableDisciplineTypes() {
    return ['bjj', 'mma', 'sambo', 'grappling', 'fitness'];
  }

  String _formatDisciplineName(String discipline) {
    switch (discipline.toLowerCase()) {
      case 'bjj':
        return 'BJJ';
      case 'mma':
        return 'MMA';
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

  Color _getDisciplineColor(String discipline) {
    switch (discipline.toLowerCase()) {
      case 'bjj':
        return const Color(0xFF2196F3);
      case 'mma':
        return const Color(0xFFFF5722);
      case 'sambo':
        return const Color(0xFF4CAF50);
      case 'grappling':
        return const Color(0xFF9C27B0);
      case 'fitness':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF757575);
    }
  }

  String _formatDayName(String dayOfWeek) {
    switch (dayOfWeek.toLowerCase()) {
      case 'monday':
        return 'Lunedì';
      case 'tuesday':
        return 'Martedì';
      case 'wednesday':
        return 'Mercoledì';
      case 'thursday':
        return 'Giovedì';
      case 'friday':
        return 'Venerdì';
      case 'saturday':
        return 'Sabato';
      case 'sunday':
        return 'Domenica';
      default:
        return dayOfWeek;
    }
  }
}
