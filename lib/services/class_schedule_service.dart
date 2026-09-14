import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_export.dart';
import '../models/class_schedule_model.dart';
import '../services/supabase_service.dart';

class ClassScheduleService {
  static ClassScheduleService? _instance;
  static ClassScheduleService get instance =>
      _instance ??= ClassScheduleService._();

  ClassScheduleService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  // Cache for discipline colors fetched from custom_disciplines table
  Map<String, String>? _disciplineColorCache;
  bool _colorCacheLoading = false;

  /// Fetch discipline colors from custom_disciplines table and cache them.
  /// Returns immediately if already cached.
  Future<void> _ensureDisciplineColorsLoaded() async {
    if (_disciplineColorCache != null) return;
    if (_colorCacheLoading) {
      // Wait briefly for the ongoing load
      await Future.delayed(const Duration(milliseconds: 200));
      if (_disciplineColorCache != null) return;
    }
    _colorCacheLoading = true;
    try {
      final response = await _client
          .from('custom_disciplines')
          .select('name, color_hex')
          .eq('is_active', true);
      final Map<String, String> colors = {};
      for (final row in response) {
        final name = (row['name'] ?? '').toString().toLowerCase().trim();
        final hex = (row['color_hex'] ?? '').toString().trim();
        if (name.isNotEmpty && hex.isNotEmpty) {
          // Store under original name (e.g. "total submission kids")
          colors[name] = hex;
          // Also store under underscore variant (e.g. "total_submission_kids")
          final underscoreKey = name.replaceAll(' ', '_');
          if (underscoreKey != name) {
            colors[underscoreKey] = hex;
          }
          // Also store under space variant in case DB uses underscores
          final spaceKey = name.replaceAll('_', ' ');
          if (spaceKey != name) {
            colors[spaceKey] = hex;
          }
        }
      }
      _disciplineColorCache = colors;
      print(
          '🎨 Loaded ${colors.length} discipline color entries from DB: $colors');
    } catch (e) {
      print('⚠️ Could not load discipline colors from DB: $e');
      _disciplineColorCache = {}; // empty cache so we fall back to defaults
    } finally {
      _colorCacheLoading = false;
    }
  }

  /// Returns the hex color for a discipline, preferring the admin-assigned color
  /// from custom_disciplines, falling back to hardcoded defaults.
  String _getDisciplineColor(String dbDiscipline) {
    final key = dbDiscipline.toLowerCase().trim();
    final cached = _disciplineColorCache;
    if (cached != null) {
      // Try exact match first
      if (cached.containsKey(key)) return cached[key]!;
      // Try replacing underscores with spaces (e.g. "total_submission_kids" → "total submission kids")
      final spaceKey = key.replaceAll('_', ' ');
      if (cached.containsKey(spaceKey)) return cached[spaceKey]!;
      // Try replacing spaces with underscores
      final underscoreKey = key.replaceAll(' ', '_');
      if (cached.containsKey(underscoreKey)) return cached[underscoreKey]!;
    }
    return _getDefaultDisciplineColor(dbDiscipline);
  }

  /// Invalidate the discipline color cache so it will be re-fetched on next use.
  void invalidateDisciplineColorCache() {
    _disciplineColorCache = null;
  }

  // No hardcoded discipline whitelist — all disciplines from Supabase are shown dynamically

  /// Get class schedule for a specific date with enrollment data
  /// Enhanced to handle dates without instances by showing weekly template pattern
  Future<List<ClassScheduleModel>> getClassScheduleForDate(
    DateTime date,
  ) async {
    // Ensure discipline colors are loaded from DB before building any class data
    await _ensureDisciplineColorsLoaded();
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
        print('⚠️ No schedule instances found via RPC, trying regeneration...');

        try {
          await _client.rpc('ensure_schedule_instances_exist');
          final retryResponse = await _client.rpc(
            'get_class_schedule_with_enrollments',
            params: {'target_date': date.toIso8601String().split('T')[0]},
          );
          if (retryResponse is List && retryResponse.isNotEmpty) {
            print(
              '✅ Found ${retryResponse.length} schedule instances after regeneration',
            );
            return retryResponse.map((json) {
              final jsonMap =
                  Map<String, dynamic>.from(json as Map<String, dynamic>);
              final disc = jsonMap['discipline']?.toString() ?? 'bjj';
              // Always override with admin-assigned color from cache
              jsonMap['discipline_color'] = _getDisciplineColor(disc);
              return ClassScheduleModel.fromJson(jsonMap);
            }).toList();
          }
        } catch (_) {
          // Best-effort regeneration only; continue with fallback chain.
        }

        print('⚠️ Falling back to direct/table/template schedule retrieval');
        // If RPC returns empty, try direct schedule_instances query first.
        // This avoids non-bookable template IDs when instances actually exist.
        final directInstances = await _getDirectScheduleInstancesForDate(date);
        if (directInstances.isNotEmpty) {
          print(
            '✅ Found ${directInstances.length} schedule instances via direct query fallback',
          );
          return directInstances;
        }

        // If no real instances exist, show weekly template pattern
        return _getWeeklyTemplateForDate(date);
      }

      // Handle both List and single object responses
      List<dynamic> responseList;
      if (response is List) {
        responseList = response;
      } else {
        responseList = [response];
      }

      // All disciplines from Supabase are shown — no hardcoded whitelist filtering
      final filteredResponse = responseList;

      print('✅ Found ${filteredResponse.length} schedule instances');

      // If we got results, return them
      if (filteredResponse.isNotEmpty) {
        final classes = filteredResponse.map((json) {
          // Log instructor info for debugging
          final instructorName = json['instructor_name'] ?? 'Not set';
          print(
            '👤 Class: ${json['disciplineDisplayName'] ?? json['discipline']} - Instructor: $instructorName',
          );

          // Inject the admin-assigned discipline color from cache
          final jsonWithColor =
              Map<String, dynamic>.from(json as Map<String, dynamic>);
          final disc = jsonWithColor['discipline']?.toString() ?? 'bjj';
          // Always override with the admin-assigned color from cache;
          // the RPC may return a stale/default color that doesn't match
          // the admin's current assignment in custom_disciplines.
          jsonWithColor['discipline_color'] = _getDisciplineColor(disc);

          return ClassScheduleModel.fromJson(jsonWithColor);
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
    await _ensureDisciplineColorsLoaded();
    try {
      // Get the day of week (convert DateTime.weekday to our enum format)
      final dayOfWeek = _getDayOfWeekString(date.weekday);

      // Query weekly_schedule_templates for this day
      final response =
          await _client.from('weekly_schedule_templates').select('''
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
          ''').eq('day_of_week', dayOfWeek);

      if (response.isEmpty) {
        return [];
      }

      // Filter to active seasonal schedules that cover the target date
      final activeTemplates = response.where((template) {
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
        final disc = template['discipline'] ?? 'bjj';
        final transformedJson = <String, dynamic>{
          'id': template['id'], // Use template ID as temporary instance ID
          'discipline': disc,
          'disciplineDisplayName': _mapDbValueToUI(disc),
          'discipline_color': _getDisciplineColor(disc),
          'instructor_name': template['user_profiles']?['full_name'] ??
              'common.default_instructor'.tr(),
          'instructor_email': template['user_profiles']?['email'] ?? '',
          'instructor_bio': 'class_schedule.instructor_bio_default'.tr(),
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
          'enrolled': 0,
          'is_booked': false,
          'waitlist_position': null,
          'description': template['notes'] ??
              'class_schedule.training_description'.tr(
                namedArgs: {'discipline': _mapDbValueToUI(disc)},
              ),
          'is_from_template': true,
          'template_id': template['id'],
        };

        return ClassScheduleModel.fromJson(transformedJson);
      }).toList();
    } catch (error) {
      print('Error fetching weekly template: $error');
      return [];
    }
  }

  Future<List<ClassScheduleModel>> _getDirectScheduleInstancesForDate(
    DateTime date,
  ) async {
    await _ensureDisciplineColorsLoaded();
    try {
      final targetDate = date.toIso8601String().split('T')[0];
      final userId = _client.auth.currentUser?.id;

      final response = await _client
          .from('schedule_instances')
          .select('''
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
          ''')
          .eq('class_date', targetDate)
          .eq('is_cancelled', false)
          .order('start_time')
          .order('discipline');

      if (response.isEmpty) {
        return [];
      }

      final instanceIds =
          response.map((item) => item['id'] as String).toList(growable: false);

      final registrations = await _client
          .from('class_registrations')
          .select('schedule_instance_id, user_id, registration_status')
          .inFilter('schedule_instance_id', instanceIds)
          .eq('registration_status', 'registered');

      final enrolledByInstance = <String, int>{};
      final bookedByUser = <String, bool>{};
      for (final reg in registrations) {
        final instanceId = reg['schedule_instance_id'] as String?;
        if (instanceId == null) continue;
        enrolledByInstance[instanceId] =
            (enrolledByInstance[instanceId] ?? 0) + 1;

        if (userId != null && reg['user_id'] == userId) {
          bookedByUser[instanceId] = true;
        }
      }

      return response.map((json) {
        final classId = json['id'] as String;
        final createdAt = DateTime.tryParse(
          json['created_at']?.toString() ?? '',
        );
        final updatedAt = DateTime.tryParse(
          json['updated_at']?.toString() ?? '',
        );
        final isModified = createdAt != null &&
            updatedAt != null &&
            updatedAt.difference(createdAt).inMinutes > 1;

        final transformedJson = <String, dynamic>{
          'id': classId,
          'discipline': json['discipline'],
          'disciplineDisplayName': _mapDbValueToUI(json['discipline'] ?? 'bjj'),
          'discipline_color': _getDisciplineColor(
            json['discipline'] ?? 'bjj',
          ),
          'instructor_name': json['user_profiles']?['full_name'] ??
              'common.default_instructor'.tr(),
          'instructor_email': json['user_profiles']?['email'] ?? '',
          'instructor_bio': 'class_schedule.instructor_bio_default'.tr(),
          'time_range': '${json['start_time']} - ${json['end_time']}',
          'date_formatted': _formatDate(json['class_date']),
          'capacity': json['max_capacity'] ?? 20,
          'enrolled': enrolledByInstance[classId] ?? 0,
          'is_booked': bookedByUser[classId] ?? false,
          'waitlist_position': null,
          'description': 'class_schedule.training_description'.tr(
            namedArgs: {
              'discipline': _mapDbValueToUI(json['discipline'] ?? 'bjj'),
            },
          ),
          'location': json['location'] ?? 'common.gym'.tr(),
          'is_cancelled': json['is_cancelled'] ?? false,
          'cancellation_reason': json['cancellation_reason'],
          'is_holiday_affected': json['is_holiday_affected'] ?? false,
          'is_modified': isModified,
          'updated_at': json['updated_at']?.toString(),
          'start_time': json['start_time']?.toString() ?? '',
          'end_time': json['end_time']?.toString() ?? '',
          'class_date': json['class_date']?.toString() ?? targetDate,
        };

        return ClassScheduleModel.fromJson(transformedJson);
      }).toList();
    } catch (error) {
      print('Error fetching direct schedule instances: $error');
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

      var query = _client.from('class_registrations').select('''
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
      ''').eq('user_id', userId);

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

  /// Returns the total entries remaining across all active entry-based
  /// subscription plans for the current user.
  /// Returns null if the user has no entry-based plans.
  Future<Map<String, dynamic>?> getEntryBasedInfo() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final subs = await _client
          .from('user_subscriptions')
          .select(
            'id, entries_remaining, entries_total, is_active, subscription_plan_id, subscription_plans(id, plan_type, name, entry_count)',
          )
          .eq('user_id', userId);

      if (subs.isEmpty) return null;

      int totalRemaining = 0;
      int totalEntries = 0;
      String? planName;
      bool hasEntryPlan = false;

      for (final sub in subs) {
        final plan = sub['subscription_plans'] as Map<String, dynamic>?;
        if (plan == null) continue;
        final planType = plan['plan_type'] as String? ?? '';
        if (planType != 'single_entry' && planType != 'multi_entry') continue;

        hasEntryPlan = true;
        final entryCount = (sub['entries_total'] as int?) ??
            (plan['entry_count'] as int?) ??
            (planType == 'single_entry' ? 1 : 0);
        final remaining = (sub['entries_remaining'] as int?) ?? 0;
        totalRemaining += remaining;
        totalEntries += entryCount;
        planName ??= plan['name'] as String?;
      }

      if (!hasEntryPlan) return null;

      // Cross-check with confirmed bookings count (same logic as checkBookingEligibility)
      try {
        final confirmedCount = await _client
            .from('class_registrations')
            .select('id')
            .eq('user_id', userId)
            .eq('registration_status', 'registered');
        final usedByBookings = confirmedCount.length;
        final computedRemaining = totalEntries - usedByBookings;
        return {
          'entries_remaining': computedRemaining < 0 ? 0 : computedRemaining,
          'entries_total': totalEntries,
          'plan_name': planName,
        };
      } catch (_) {
        return {
          'entries_remaining': totalRemaining < 0 ? 0 : totalRemaining,
          'entries_total': totalEntries,
          'plan_name': planName,
        };
      }
    } catch (e) {
      print('⚠️ [getEntryBasedInfo] failed: $e');
      return null;
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

  /// Check if user can book a specific class.
  ///
  /// Fully Flutter-side: queries payment_confirmations (custom_plan_id) and
  /// discipline_custom_plan_associations to verify the user has a confirmed
  /// payment whose plan is associated with the class discipline.
  /// No SQL function (check_class_booking_eligibility) is called.
  Future<Map<String, dynamic>> checkBookingEligibility(
    String scheduleInstanceId,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'allowed': false,
          'reason': 'class_schedule.login_required'.tr(),
        };
      }

      print('🔍 [eligibility] userId=$userId, instanceId=$scheduleInstanceId');

      // ── Step 0: Check booking passpartout ─────────────────────────────
      try {
        final profileRows = await _client
            .from('user_profiles')
            .select('booking_passpartout')
            .eq('id', userId)
            .limit(1);
        if (profileRows.isNotEmpty &&
            profileRows[0]['booking_passpartout'] == true) {
          print('🗝️ [eligibility] Passpartout active — booking allowed');
          return {'allowed': true, 'booking_type': 'passpartout'};
        }
      } catch (e) {
        print('⚠️ [eligibility] Could not check passpartout: $e');
      }

      // ── Step 1: Resolve discipline of the requested class ──────────────
      String? classDiscipline;
      try {
        final rows = await _client
            .from('schedule_instances')
            .select('discipline')
            .eq('id', scheduleInstanceId)
            .limit(1);
        if (rows.isNotEmpty) {
          classDiscipline =
              (rows[0]['discipline'] as String?)?.toLowerCase().trim();
        }
      } catch (e) {
        print('⚠️ [eligibility] Could not resolve discipline: $e');
      }

      print('📍 [eligibility] classDiscipline=$classDiscipline');

      // ── Step 2: Fetch all confirmed payment_confirmations with custom_plan_id ──
      List<dynamic> confirmations = [];
      try {
        confirmations = await _client
            .from('payment_confirmations')
            .select(
                'id, custom_plan_id, status, custom_subscription_plans(id, name, is_unlimited, entry_count, duration_months)')
            .eq('user_id', userId)
            .eq('status', 'confirmed')
            .not('custom_plan_id', 'is', null);
        print(
            '🧾 [eligibility] Found ${confirmations.length} confirmed payment(s) with custom_plan_id');
      } catch (e) {
        print('⚠️ [eligibility] Could not fetch payment_confirmations: $e');
        return {
          'allowed': false,
          'reason': 'errors.subscription_check_failed'.tr(),
        };
      }

      if (confirmations.isEmpty) {
        print(
            '❌ [eligibility] No confirmed payments with custom_plan_id found');
        return {
          'allowed': false,
          'reason': 'class_schedule.no_valid_subscription'.tr(),
        };
      }

      // ── Step 3: For each confirmed payment, check discipline association ──
      for (final payment in confirmations) {
        final customPlanId = payment['custom_plan_id'] as String?;
        if (customPlanId == null) continue;

        final planData =
            payment['custom_subscription_plans'] as Map<String, dynamic>?;
        final planName = (planData?['name'] as String? ?? '').toLowerCase();

        print(
            '🔎 [eligibility] Checking plan "$planName" (id=$customPlanId) against discipline=$classDiscipline');

        // Fetch discipline associations for this plan
        List<dynamic> associations = [];
        try {
          associations = await _client
              .from('discipline_custom_plan_associations')
              .select('discipline_name')
              .eq('custom_plan_id', customPlanId);
        } catch (e) {
          print(
              '⚠️ [eligibility] Could not fetch associations for plan $customPlanId: $e');
          continue;
        }

        print(
            '📋 [eligibility] Plan "$planName" has ${associations.length} discipline association(s): ${associations.map((a) => a['discipline_name']).toList()}');

        if (associations.isEmpty) {
          // No associations configured — skip this plan
          continue;
        }

        // Check if any association matches the class discipline
        bool disciplineMatches = false;

        if (classDiscipline == null) {
          // Unknown discipline — allow if plan has any association
          disciplineMatches = associations.isNotEmpty;
        } else {
          for (final assoc in associations) {
            final assocDiscipline = (assoc['discipline_name'] as String? ?? '')
                .toLowerCase()
                .trim();
            if (assocDiscipline == classDiscipline) {
              disciplineMatches = true;
              break;
            }
            // Also handle partial match for display names vs db values
            // e.g. "bjj" matches "BJJ", "Brazilian Jiu-Jitsu" etc.
            if (assocDiscipline.contains(classDiscipline) ||
                classDiscipline.contains(assocDiscipline)) {
              disciplineMatches = true;
              break;
            }
          }
        }

        if (!disciplineMatches) {
          print(
              '⏭️ [eligibility] Plan "$planName" does not cover discipline=$classDiscipline — skipping');
          continue;
        }

        // ── Step 4: Check entry count for entry-based plans ───────────────
        final isUnlimited = planData?['is_unlimited'] as bool? ?? false;
        final entryCount = planData?['entry_count'] as int?;

        if (isUnlimited || entryCount == null) {
          // Unlimited plan or monthly-style — allow immediately
          print(
              '✅ [eligibility] Plan "$planName" is unlimited/monthly — booking allowed');
          return {
            'allowed': true,
            'booking_type': 'subscription',
          };
        }

        // Entry-based: count confirmed bookings and compare
        int confirmedBookings = 0;
        try {
          final registrations = await _client
              .from('class_registrations')
              .select('id')
              .eq('user_id', userId)
              .eq('registration_status', 'registered');
          confirmedBookings = registrations.length;
        } catch (e) {
          print('⚠️ [eligibility] Could not count registrations: $e');
          return {
            'allowed': false,
            'reason': 'errors.subscription_check_failed'.tr(),
          };
        }

        print(
            '🎫 [eligibility] Entry plan "$planName": confirmedBookings=$confirmedBookings, entryCount=$entryCount');

        if (confirmedBookings >= entryCount) {
          print(
              '🚫 [eligibility] Entry limit reached ($confirmedBookings/$entryCount)');
          return {
            'allowed': false,
            'reason': 'class_schedule.no_valid_subscription'.tr(),
          };
        }

        print(
            '✅ [eligibility] Entry plan allows booking ($confirmedBookings/$entryCount used)');
        return {
          'allowed': true,
          'booking_type': 'entry_based',
          'entries_remaining': entryCount - confirmedBookings,
        };
      }

      print('❌ [eligibility] No plan covers discipline=$classDiscipline');
      return {
        'allowed': false,
        'reason': 'class_schedule.no_valid_subscription'.tr(),
      };
    } catch (error) {
      print('❌ [eligibility] Unexpected error: $error');
      return {
        'allowed': false,
        'reason': 'errors.subscription_check_failed'.tr(),
      };
    }
  }

  /// Returns an eligibility map for an entry-based plan referenced by a
  /// confirmed payment. Only used for self-healing when no user_subscriptions
  /// row exists at all (first booking). Returns null if entries are exhausted.
  Future<Map<String, dynamic>?> _ensureEntrySubscription({
    required String userId,
    required Map<String, dynamic> plan,
  }) async {
    final planId = plan['id'] as String?;
    if (planId == null) return null;

    try {
      final planType = plan['plan_type'] as String? ?? '';
      final planEntryCount =
          (plan['entry_count'] as int?) ?? (planType == 'single_entry' ? 1 : 0);
      if (planEntryCount <= 0) return null;

      // Count confirmed bookings for this user
      int confirmedBookings = 0;
      try {
        final registrations = await _client
            .from('class_registrations')
            .select('id')
            .eq('user_id', userId)
            .eq('registration_status', 'registered');
        confirmedBookings = registrations.length;
      } catch (e) {
        print('⚠️ [_ensureEntry] Failed to count registrations: $e');
        return null;
      }

      if (confirmedBookings >= planEntryCount) {
        print(
          '🚫 [_ensureEntry] Booking limit reached '
          '($confirmedBookings/$planEntryCount) — blocking',
        );
        return null;
      }

      // Check for existing active row
      final existing = await _client
          .from('user_subscriptions')
          .select('id, entries_remaining, entries_total')
          .eq('user_id', userId)
          .eq('subscription_plan_id', planId)
          .eq('is_active', true)
          .gt('entries_remaining', 0)
          .limit(1);

      if (existing.isNotEmpty) {
        return {
          'allowed': true,
          'booking_type': 'entry_based',
          'subscription_id': existing[0]['id'] as String,
          'entries_remaining': planEntryCount - confirmedBookings,
        };
      }

      // No row exists — self-heal only if no bookings yet
      if (confirmedBookings > 0) {
        print(
          '⚠️ [_ensureEntry] User has $confirmedBookings booking(s) but no '
          'subscription row — blocking to prevent over-booking',
        );
        return null;
      }

      print(
        '🩺 [_ensureEntry] No subscription row for plan $planId — '
        'self-healing with $planEntryCount entries',
      );

      final inserted = await _client
          .from('user_subscriptions')
          .insert({
            'user_id': userId,
            'subscription_plan_id': planId,
            'entries_remaining': planEntryCount,
            'entries_total': planEntryCount,
            'is_active': true,
          })
          .select('id, entries_remaining')
          .single();

      return {
        'allowed': true,
        'booking_type': 'entry_based',
        'subscription_id': inserted['id'] as String,
        'entries_remaining': inserted['entries_remaining'] as int,
      };
    } catch (e) {
      print('⚠️ [_ensureEntry] failed: $e');
      return null;
    }
  }

  /// Look up a subscription_plans row by price as a last resort when the
  /// payment_confirmations row has no subscription_plan_id (older data).
  /// Returns null if no unambiguous match is found. €30 maps to two plans
  /// ('Iscrizione Annuale' and 'Preparazione Atletica'); for safety we
  /// prefer the non-annual monthly plan to avoid wrongly granting
  /// booking from the annual registration fee.
  Future<Map<String, dynamic>?> _lookupPlanByAmount(double amount) async {
    try {
      final plans = await _client
          .from('subscription_plans')
          .select('id, plan_type, name, entry_count, price')
          .eq('price', amount)
          .eq('is_active', true);
      if (plans.isEmpty) return null;
      if (plans.length == 1) return Map<String, dynamic>.from(plans[0]);

      // Ambiguous amount: prefer entry-based first, then annual (safer
      // — the eligibility loop will skip it rather than granting access),
      // then monthly as a last resort. At €30 both Iscrizione Annuale and
      // Preparazione Atletica exist; without further evidence we default
      // to annual so an annual-only user can't accidentally book via the
      // monthly branch.
      Map<String, dynamic>? entry;
      Map<String, dynamic>? annual;
      Map<String, dynamic>? monthly;
      for (final p in plans) {
        final t = (p['plan_type'] as String?) ?? '';
        if (t == 'multi_entry' || t == 'single_entry') {
          entry = Map<String, dynamic>.from(p);
        } else if (t == 'annual' && annual == null) {
          annual = Map<String, dynamic>.from(p);
        } else if (t == 'monthly' && monthly == null) {
          monthly = Map<String, dynamic>.from(p);
        }
      }
      return entry ?? annual ?? monthly;
    } catch (_) {
      return null;
    }
  }

  bool _isSubscriptionStillValid(String? expiresAtRaw, DateTime now) {
    if (expiresAtRaw == null || expiresAtRaw.isEmpty) {
      return true;
    }

    try {
      final parsed = DateTime.parse(expiresAtRaw);
      final isDateOnly = expiresAtRaw.length <= 10;
      final effectiveExpiry = isDateOnly
          ? DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59, 999)
          : parsed;
      return !effectiveExpiry.isBefore(now);
    } catch (_) {
      // Fail-open here to avoid false negatives from malformed legacy values.
      return true;
    }
  }

  String? _normalizeDiscipline(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty) return null;

    switch (value) {
      case 'preparazione atletica':
      case 'preparazione_atletica':
      case 'prep_atletica':
      case 'prep. atletica':
        return 'fitness';
      default:
        return value;
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
    await _ensureDisciplineColorsLoaded();
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
        query = query.eq('discipline', discipline);
      }

      if (instructorId != null && instructorId.isNotEmpty) {
        query = query.eq('instructor_id', instructorId);
      }

      if (!includeCancel) {
        query = query.eq('is_cancelled', false);
      }

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
          'discipline_color': _getDisciplineColor(
            json['discipline'] ?? 'bjj',
          ),
          'instructor_name': json['user_profiles']?['full_name'] ??
              'common.default_instructor'.tr(),
          'instructor_email': json['user_profiles']?['email'] ?? '',
          'instructor_bio': 'class_schedule.instructor_bio_default'.tr(),
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
          'description': 'class_schedule.training_description'.tr(
            namedArgs: {
              'discipline': _mapDbValueToUI(json['discipline'] ?? 'bjj'),
            },
          ),
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

  /// Resolve a template ID to a real schedule_instance ID by ensuring
  /// instances exist for the target date and matching by discipline + time.
  Future<String?> _resolveTemplateToInstanceId(
    String templateId,
    String classDate,
    String discipline,
    String startTime,
  ) async {
    try {
      // Ensure schedule instances are generated for the target date
      await _client.rpc('ensure_schedule_instances_exist');

      // Find the real instance that matches this template's class
      final instances = await _client
          .from('schedule_instances')
          .select('id')
          .eq('class_date', classDate)
          .eq('discipline', discipline)
          .eq('start_time', startTime)
          .eq('is_cancelled', false)
          .limit(1);

      if (instances.isNotEmpty) {
        final resolvedId = instances[0]['id'] as String;
        print('✅ Resolved template $templateId → instance $resolvedId');
        return resolvedId;
      }

      print('❌ Could not find a schedule instance for template $templateId');
      return null;
    } catch (error) {
      print('❌ Error resolving template to instance: $error');
      return null;
    }
  }

  /// Book a class (real implementation with Supabase).
  /// Returns a result map with 'success' (bool) and optionally
  /// 'entries_remaining' (int?) and 'booking_type' (String?) for
  /// entry-based subscriptions.
  Future<Map<String, dynamic>> bookClass(
    String classId, {
    ClassScheduleModel? classModel,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('❌ Booking failed: User not authenticated');
        return {'success': false, 'error': 'User not authenticated'};
      }

      String resolvedClassId = classId;

      if (classModel != null && classModel.isFromTemplate) {
        print('📋 Class is from template – resolving to real instance…');
        final instanceId = await _resolveTemplateToInstanceId(
          classModel.templateId ?? classId,
          classModel.classDate,
          classModel.discipline,
          classModel.startTime,
        );
        if (instanceId == null) {
          print('❌ Booking failed: Could not resolve template to instance');
          return {'success': false, 'error': 'Could not resolve template'};
        }
        resolvedClassId = instanceId;
      }

      final eligibility = await checkBookingEligibility(resolvedClassId);
      if (!(eligibility['allowed'] ?? false)) {
        print('❌ Booking failed: Not eligible - ${eligibility['reason']}');
        return {
          'success': false,
          'error': eligibility['reason'] ?? 'Not eligible',
        };
      }

      String? subscriptionIdToUse = eligibility['subscription_id'] as String?;
      final bookingType = eligibility['booking_type'] as String?;
      final entriesBefore = eligibility['entries_remaining'] as int?;

      if (subscriptionIdToUse != null) {
        print(
          '✅ Using subscription for credit deduction: $subscriptionIdToUse '
          '(entries before: $entriesBefore)',
        );
      }

      final response = await _client.rpc(
        'register_for_class',
        params: {
          'instance_id': resolvedClassId,
          'subscription_id': subscriptionIdToUse,
        },
      );

      if (response != null && response['success'] == true) {
        final entriesAfter = response['entries_remaining'] as int?;
        final entryDeducted = response['entry_deducted'] as bool? ?? false;

        print(
          '✅ Booking successful'
          '${entryDeducted ? " (entry deducted, remaining: $entriesAfter)" : ""}',
        );

        return {
          'success': true,
          'booking_type': bookingType,
          'entry_deducted': entryDeducted,
          'entries_remaining': entriesAfter,
        };
      } else {
        print('❌ Booking failed: ${response?['error'] ?? 'Unknown error'}');
        return {
          'success': false,
          'error': response?['error'] ?? 'Unknown error',
        };
      }
    } catch (error) {
      print('❌ Error booking class: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Cancel a class booking (real implementation with Supabase).
  /// Returns a result map with 'success', 'entry_refunded', and
  /// 'entries_remaining' for entry-based subscriptions.
  Future<Map<String, dynamic>> cancelBooking(String classId) async {
    try {
      final response = await _client.rpc(
        'cancel_class_registration',
        params: {
          'instance_id': classId,
          'cancellation_reason': 'class_schedule.cancelled_by_user'.tr(),
        },
      );

      if (response != null && response['success'] == true) {
        final entryRefunded = response['entry_refunded'] as bool? ?? false;
        final entriesRemaining = response['entries_remaining'] as int?;
        if (entryRefunded) {
          print(
            '✅ Cancellation successful, entry refunded (remaining: $entriesRemaining)',
          );
        }
        return {
          'success': true,
          'entry_refunded': entryRefunded,
          'entries_remaining': entriesRemaining,
        };
      } else {
        print('Cancellation failed: ${response?['error'] ?? 'Unknown error'}');
        return {
          'success': false,
          'error': response?['error'] ?? 'Unknown error',
        };
      }
    } catch (error) {
      print('Error canceling booking: $error');
      return {'success': false, 'error': error.toString()};
    }
  }

  /// Get available disciplines for filtering (only current disciplines)
  Future<List<String>> getAvailableDisciplines() async {
    try {
      final response = await _client
          .from('schedule_instances')
          .select('discipline')
          .eq('is_cancelled', false);

      final disciplines =
          response.map((item) => item['discipline'] as String).toSet().toList();

      disciplines.sort();
      return disciplines;
    } catch (error) {
      print('Error fetching disciplines: $error');
      return []; // Return empty list so dynamic loading handles it
    }
  }

  /// Get available instructors
  Future<List<Map<String, dynamic>>> getAvailableInstructors() async {
    try {
      final response = await _client.from('schedule_instances').select('''
            instructor_id,
            user_profiles!schedule_instances_instructor_id_fkey (
              id,
              full_name,
              email
            )
          ''').eq('is_cancelled', false);

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

  String _mapDisciplineToDbValue(String uiDiscipline) {
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
      case 'preparazione atletica':
      case 'preparazione_atletica':
      case 'prep_atletica':
      case 'prep. atletica':
        return 'fitness';
      default:
        return 'bjj';
    }
  }

  String _mapDbValueToUI(String dbDiscipline) {
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
      case 'prep_atletica':
      case 'preparazione_atletica':
        return 'Preparazione Atletica';
      default:
        return dbDiscipline;
    }
  }

  String _getDefaultDisciplineColor(String dbDiscipline) {
    switch (dbDiscipline.toLowerCase()) {
      case 'bjj':
        return '#1565C0';
      case 'mma':
        return '#D32F2F';
      case 'sambo':
        return '#1976D2';
      case 'grappling':
        return '#7B1FA2';
      case 'fitness':
      case 'prep_atletica':
      case 'preparazione_atletica':
        return '#E65100';
      default:
        return '#757575';
    }
  }

  // Updated method to fetch schedule with valid discipline filtering
  Future<List<Map<String, dynamic>>> fetchScheduleByDiscipline(
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

      // Apply discipline filter for all disciplines (no whitelist restriction)
      if (discipline != 'disciplines.all'.tr() && discipline.isNotEmpty) {
        final dbDiscipline = _mapDisciplineToDbValue(discipline);
        query = query.eq('discipline', dbDiscipline);
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
