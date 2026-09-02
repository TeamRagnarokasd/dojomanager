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
      final disciplinesList = activeDisciplines.map((discipline) {
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
          'totalClasses':
              disciplineSchedules[discipline]?.values.fold<int>(
                0,
                (sum, daySchedules) => sum + daySchedules.length,
              ) ??
              0,
        };
      }).toList();

      // Also fetch custom disciplines from the custom_disciplines table
      try {
        final customDisciplinesResponse = await _client
            .from('custom_disciplines')
            .select('*')
            .eq('is_active', true);

        for (var customDiscipline in customDisciplinesResponse) {
          final disciplineId = customDiscipline['name'];

          // Check if this custom discipline is already in the list (from schedules/instructors)
          final existingIndex = disciplinesList.indexWhere(
            (d) => d['id'] == disciplineId,
          );

          if (existingIndex == -1) {
            // Add custom discipline that's not yet in use
            disciplinesList.add({
              'id': disciplineId,
              'name': customDiscipline['display_name'] ?? disciplineId,
              'isActive': true,
              'color': _parseColor(customDiscipline['color_hex'] ?? '#757575'),
              'instructors': <String>[],
              'locations': <String>['Sala Principale'],
              'schedule': <String, dynamic>{},
              'weeklyHours': 0.0,
              'studentCount': 0,
              'nextClass': null,
              'totalClasses': 0,
              'isCustom': true,
            });
          } else {
            // Update existing discipline with custom info
            disciplinesList[existingIndex]['isCustom'] = true;
            disciplinesList[existingIndex]['name'] =
                customDiscipline['display_name'] ??
                disciplinesList[existingIndex]['name'];
            disciplinesList[existingIndex]['color'] = _parseColor(
              customDiscipline['color_hex'] ?? '#757575',
            );
          }
        }
      } catch (error) {
        print('Error fetching custom disciplines: $error');
        // Continue without custom disciplines if there's an error
      }

      return disciplinesList;
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
      final instructorResponse = await _client
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
  /// - All discipline-subscription plan associations
  Future<bool> deleteDiscipline(String disciplineId) async {
    try {
      // Check if this is a custom discipline (stored in custom_disciplines table)
      final isCustom = await _isCustomDiscipline(disciplineId);

      if (isCustom) {
        return await _deleteCustomDiscipline(disciplineId);
      }

      // For ENUM-based disciplines, use the safe database function
      try {
        final response = await _client.rpc(
          'safe_delete_discipline',
          params: {'discipline_to_delete': disciplineId},
        );

        if (response != null && response['success'] == true) {
          print('Successfully deleted discipline: $disciplineId');
          return true;
        } else {
          final errorMsg = response?['error'] ?? 'Unknown error';
          print('safe_delete_discipline returned error: $errorMsg');
          // Fall through to manual deletion
        }
      } catch (rpcError) {
        print(
          'RPC safe_delete_discipline failed: $rpcError — trying manual deletion',
        );
      }

      // Fallback: manual deletion for ENUM disciplines
      return await _manualDeleteEnumDiscipline(disciplineId);
    } catch (error) {
      print('Error deleting discipline $disciplineId: $error');

      if (error.toString().contains('Unauthorized')) {
        throw Exception('Non hai i permessi per eliminare discipline');
      } else {
        throw Exception('Errore durante l\'eliminazione della disciplina');
      }
    }
  }

  /// Manual deletion fallback for ENUM-based disciplines
  Future<bool> _manualDeleteEnumDiscipline(String disciplineId) async {
    try {
      // 1. Delete from discipline_subscription_plans (ENUM-based)
      try {
        await _client
            .from('discipline_subscription_plans')
            .delete()
            .eq('discipline', disciplineId);
      } catch (e) {
        print('Note: could not delete from discipline_subscription_plans: $e');
      }

      // 2. Delete from discipline_subscription_plans_custom (text-based, by name)
      try {
        await _client
            .from('discipline_subscription_plans_custom')
            .delete()
            .eq('discipline_name', disciplineId);
      } catch (e) {
        print(
          'Note: could not delete from discipline_subscription_plans_custom: $e',
        );
      }

      // 3. Delete schedule instances
      try {
        await _client
            .from('schedule_instances')
            .delete()
            .eq('discipline', disciplineId);
      } catch (e) {
        print('Note: could not delete schedule_instances: $e');
      }

      // 4. Delete weekly schedule templates
      try {
        await _client
            .from('weekly_schedule_templates')
            .delete()
            .eq('discipline', disciplineId);
      } catch (e) {
        print('Note: could not delete weekly_schedule_templates: $e');
      }

      // 5. Delete instructor specializations
      try {
        await _client
            .from('instructor_specializations')
            .delete()
            .eq('specialization', disciplineId);
      } catch (e) {
        print('Note: could not delete instructor_specializations: $e');
      }

      // 6. Remove from instructor_profiles disciplines array
      try {
        final instructors = await _client
            .from('instructor_profiles')
            .select('id, disciplines, primary_discipline')
            .filter('disciplines', 'cs', '{"$disciplineId"}');

        for (final instructor in instructors) {
          final currentDisciplines = List<String>.from(
            instructor['disciplines'] ?? [],
          );
          currentDisciplines.remove(disciplineId);

          String? newPrimary = instructor['primary_discipline'];
          if (newPrimary == disciplineId) {
            newPrimary = currentDisciplines.isNotEmpty
                ? currentDisciplines.first
                : 'mma';
          }

          await _client
              .from('instructor_profiles')
              .update({
                'disciplines': currentDisciplines,
                'primary_discipline': newPrimary,
              })
              .eq('id', instructor['id']);
        }
      } catch (e) {
        print('Note: could not update instructor_profiles: $e');
      }

      // 7. If it's also in custom_disciplines (e.g. added as custom), delete it
      try {
        await _client
            .from('custom_disciplines')
            .delete()
            .or(
              'name.eq.$disciplineId,name.ilike.%${disciplineId.replaceAll('_', ' ')}%',
            );
      } catch (e) {
        print('Note: could not delete from custom_disciplines: $e');
      }

      print('Manual deletion completed for discipline: $disciplineId');
      return true;
    } catch (error) {
      print('Manual deletion failed for $disciplineId: $error');
      throw Exception('Errore durante l\'eliminazione della disciplina');
    }
  }

  /// Check if a discipline is a custom one (stored in custom_disciplines table)
  Future<bool> _isCustomDiscipline(String disciplineId) async {
    try {
      final response = await _client
          .from('custom_disciplines')
          .select('id')
          .or(
            'name.eq.$disciplineId,name.ilike.%${disciplineId.replaceAll('_', ' ')}%',
          )
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Delete a custom discipline using the safe RPC function (with fallback)
  Future<bool> _deleteCustomDiscipline(String disciplineId) async {
    try {
      // Try the safe RPC function first
      try {
        final response = await _client.rpc(
          'safe_delete_custom_discipline',
          params: {'discipline_name_to_delete': disciplineId},
        );
        if (response != null && response['success'] == true) {
          print(
            'Successfully deleted custom discipline via RPC: $disciplineId',
          );
          return true;
        }
      } catch (rpcError) {
        print(
          'RPC safe_delete_custom_discipline failed: $rpcError — using direct delete',
        );
      }

      // Fallback: direct delete from custom_disciplines
      // Also clean up subscription plan associations
      try {
        await _client
            .from('discipline_subscription_plans_custom')
            .delete()
            .eq('discipline_name', disciplineId);
      } catch (e) {
        print(
          'Note: could not delete from discipline_subscription_plans_custom: $e',
        );
      }

      await _client
          .from('custom_disciplines')
          .delete()
          .or(
            'name.eq.$disciplineId,name.ilike.%${disciplineId.replaceAll('_', ' ')}%',
          );

      print('Successfully deleted custom discipline: $disciplineId');
      return true;
    } catch (error) {
      print('Error deleting custom discipline $disciplineId: $error');
      throw Exception(
        'Errore durante l\'eliminazione della disciplina personalizzata',
      );
    }
  }

  /// Create new discipline directly
  /// This method adds a new discipline to the custom_disciplines table
  Future<bool> createNewDiscipline(
    String disciplineName, {
    String colorHex = '#FF5722',
  }) async {
    try {
      // Validate discipline name
      if (disciplineName.trim().isEmpty) {
        throw Exception('Il nome della disciplina non può essere vuoto');
      }

      // Check if discipline already exists (in ENUM or custom table)
      final existingDisciplines = await getActiveDisciplines();
      final normalizedName = disciplineName.trim().toLowerCase();

      for (var discipline in existingDisciplines) {
        if (discipline['name'].toString().toLowerCase() == normalizedName ||
            discipline['id'].toString().toLowerCase() == normalizedName) {
          throw Exception('Una disciplina con questo nome esiste già');
        }
      }

      // Create the custom discipline
      final response = await _client.from('custom_disciplines').insert({
        'name': disciplineName.trim().toLowerCase().replaceAll(' ', '_'),
        'display_name': disciplineName.trim(),
        'description': 'Disciplina personalizzata',
        'color_hex': colorHex,
        'is_active': true,
        'created_by': _client.auth.currentUser?.id,
      }).select();

      if (response.isEmpty) {
        throw Exception('Errore durante la creazione della disciplina');
      }

      return true;
    } catch (error) {
      print('Error creating new discipline: $error');
      rethrow;
    }
  }

  /// Get available discipline types from enum
  List<String> getAvailableDisciplineTypes() {
    return ['bjj', 'mma', 'sambo', 'grappling', 'fitness'];
  }

  /// List of valid discipline_type ENUM values
  static const List<String> _enumDisciplines = [
    'bjj',
    'mma',
    'sambo',
    'grappling',
    'fitness',
    'doppio',
    'Preparazione Atletica',
    'prep_atletica',
  ];

  /// Check if a discipline name is a custom discipline (not in ENUM)
  bool _isCustomDisciplineName(String discipline) {
    return !_enumDisciplines.contains(discipline);
  }

  /// Get subscription plans associated with a discipline
  Future<List<Map<String, dynamic>>> getSubscriptionPlansForDiscipline(
    String discipline,
  ) async {
    try {
      // Use the new correct junction table that references custom_subscription_plans
      final response = await _client
          .from('discipline_custom_plan_associations')
          .select('custom_plan_id, custom_subscription_plans!inner(*)')
          .eq('discipline_name', discipline);

      return response.map<Map<String, dynamic>>((row) {
        final plan = row['custom_subscription_plans'] as Map<String, dynamic>;
        return {
          'subscription_plan_id': row['custom_plan_id'],
          'id': plan['id'],
          'name': plan['name'],
          'plan_type': 'custom',
          'price': plan['amount'],
          'description': null,
        };
      }).toList();
    } catch (error) {
      print('Error fetching subscription plans for discipline: $error');
      return [];
    }
  }

  /// Get disciplines associated with a subscription plan
  /// Returns a list of discipline names/IDs linked to the given plan
  Future<List<String>> getDisciplinesForPlan(String subscriptionPlanId) async {
    try {
      final List<String> disciplines = [];

      // Query ENUM-based associations
      try {
        final enumResponse = await _client
            .from('discipline_subscription_plans')
            .select('discipline')
            .eq('subscription_plan_id', subscriptionPlanId);

        for (final row in enumResponse) {
          final discipline = row['discipline'] as String?;
          if (discipline != null && discipline.isNotEmpty) {
            disciplines.add(discipline);
          }
        }
      } catch (e) {
        print('Note: Could not query discipline_subscription_plans: $e');
      }

      // Query custom discipline associations
      try {
        final customResponse = await _client
            .from('discipline_subscription_plans_custom')
            .select('discipline_name')
            .eq('subscription_plan_id', subscriptionPlanId);

        for (final row in customResponse) {
          final disciplineName = row['discipline_name'] as String?;
          if (disciplineName != null && disciplineName.isNotEmpty) {
            disciplines.add(disciplineName);
          }
        }
      } catch (e) {
        print('Note: Could not query discipline_subscription_plans_custom: $e');
      }

      return disciplines;
    } catch (error) {
      print('Error fetching disciplines for plan: $error');
      return [];
    }
  }

  /// Get disciplines for a plan by plan name (looks up plan ID first)
  /// Useful when you only have the plan name from the UI
  Future<List<String>> getDisciplinesForPlanByName(String planName) async {
    try {
      // First, find the subscription plan by name
      final planResponse = await _client
          .from('subscription_plans')
          .select('id')
          .eq('name', planName)
          .limit(1);

      if (planResponse.isEmpty) {
        print('No subscription plan found with name: $planName');
        return [];
      }

      final planId = planResponse[0]['id'] as String;
      return getDisciplinesForPlan(planId);
    } catch (error) {
      print('Error fetching disciplines for plan by name: $error');
      return [];
    }
  }

  /// Associate a subscription plan to a discipline
  Future<bool> associateSubscriptionPlanToDiscipline({
    required String discipline,
    required String subscriptionPlanId,
  }) async {
    try {
      // Use the new correct junction table that references custom_subscription_plans
      await _client.from('discipline_custom_plan_associations').insert({
        'discipline_name': discipline,
        'custom_plan_id': subscriptionPlanId,
      });
      return true;
    } catch (error) {
      print('Error associating subscription plan to discipline: $error');
      if (error.toString().contains('duplicate') ||
          error.toString().contains('unique')) {
        throw Exception('Questo piano è già associato a questa disciplina');
      }
      throw Exception('Errore nell\'associazione del piano alla disciplina');
    }
  }

  /// Remove association between a subscription plan and a discipline
  Future<bool> removeSubscriptionPlanFromDiscipline({
    required String discipline,
    required String subscriptionPlanId,
  }) async {
    try {
      // Use the new correct junction table
      await _client
          .from('discipline_custom_plan_associations')
          .delete()
          .eq('discipline_name', discipline)
          .eq('custom_plan_id', subscriptionPlanId);
      return true;
    } catch (error) {
      print('Error removing subscription plan from discipline: $error');
      throw Exception('Errore nella rimozione dell\'associazione');
    }
  }

  /// Get all available subscription plans (for selection in UI)
  Future<List<Map<String, dynamic>>> getAllSubscriptionPlans() async {
    try {
      final response = await _client
          .from('custom_subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('name');

      return List<Map<String, dynamic>>.from(response).map((plan) {
        // Normalize: custom_subscription_plans uses 'amount', UI expects 'price'
        final mapped = Map<String, dynamic>.from(plan);
        if (!mapped.containsKey('price') && mapped.containsKey('amount')) {
          mapped['price'] = mapped['amount'];
        }
        // Ensure plan_type exists for _formatPlanType
        if (!mapped.containsKey('plan_type') || mapped['plan_type'] == null) {
          mapped['plan_type'] = 'custom';
        }
        return mapped;
      }).toList();
    } catch (error) {
      print('Error fetching all subscription plans: $error');
      return [];
    }
  }

  /// Get instructors qualified for a specific discipline
  Future<List<Map<String, dynamic>>> getInstructorsForDiscipline(
    String discipline,
  ) async {
    try {
      final response = await _client
          .from('instructor_profiles')
          .select(
            'id, user_id, disciplines, primary_discipline, bio, years_experience, profile_image_url, is_active, user_profiles!inner(id, full_name, profile_image_url)',
          )
          .eq('is_active', true)
          .contains('disciplines', [discipline]);

      return response.map<Map<String, dynamic>>((instructor) {
        final userProfile = instructor['user_profiles'];
        final userId = userProfile['id'];
        final fullName = userProfile['full_name'] ?? 'Nome non disponibile';
        final userProfileImageUrl = userProfile['profile_image_url'];
        final instructorProfileImageUrl = instructor['profile_image_url'];

        return {
          'instructor_profile_id': instructor['id'],
          'user_id': userId,
          'name': fullName,
          'profile_image_url': instructorProfileImageUrl ?? userProfileImageUrl,
          'disciplines': List<String>.from(instructor['disciplines'] ?? []),
          'primary_discipline': instructor['primary_discipline'],
          'bio': instructor['bio'],
          'years_experience': instructor['years_experience'],
          'is_active': instructor['is_active'],
        };
      }).toList();
    } catch (error) {
      throw Exception('Failed to fetch instructors for discipline: $error');
    }
  }

  /// Update instructor for schedule instances of a specific discipline
  Future<bool> updateDisciplineInstructor({
    required String discipline,
    required String newInstructorUserId,
    String? seasonId,
  }) async {
    try {
      // Build query to update schedule instances
      var updateQuery = _client
          .from('schedule_instances')
          .update({
            'instructor_id': newInstructorUserId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('discipline', discipline)
          .eq('is_cancelled', false);

      // Filter by season if provided
      if (seasonId != null) {
        updateQuery = updateQuery.eq('seasonal_schedule_id', seasonId);
      }

      // Also update future instances only (today and beyond)
      final today = DateTime.now().toIso8601String().split('T')[0];
      updateQuery = updateQuery.gte('class_date', today);

      await updateQuery;

      // Also update weekly templates for this discipline
      var templateUpdateQuery = _client
          .from('weekly_schedule_templates')
          .update({'instructor_id': newInstructorUserId})
          .eq('discipline', discipline);

      if (seasonId != null) {
        templateUpdateQuery = templateUpdateQuery.eq(
          'seasonal_schedule_id',
          seasonId,
        );
      }

      await templateUpdateQuery;

      print(
        'Successfully updated instructor for discipline $discipline to user $newInstructorUserId',
      );
      return true;
    } catch (error) {
      print('Error updating instructor for discipline $discipline: $error');
      return false;
    }
  }

  /// Get current season ID for instructor assignment context
  Future<String?> getCurrentSeasonIdForInstructorAssignment() async {
    return await _getCurrentSeasonId();
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

  /// Parse color hex string to Color object
  Color _parseColor(String colorHex) {
    try {
      final hexCode = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      return const Color(0xFF757575); // Default gray color
    }
  }
}
