import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/registration_data_manager.dart';
import '../services/child_profile_service.dart';

class SubscriptionService {
  static final _supabase = Supabase.instance.client;

  // 🔒 CRITICAL FIX: Guard variable to prevent concurrent batch operations
  static bool _isProcessing = false;

  /// Computes the annual subscription expiry date: always 28/08 of the current
  /// season. If today is on or before 28/08 of the current year, expiry is
  /// 28/08 of the current year; otherwise it is 28/08 of the next year.
  static DateTime _computeAnnualExpiry() {
    final now = DateTime.now();
    final august28ThisYear = DateTime(now.year, 8, 28);
    if (!now.isAfter(august28ThisYear)) {
      return august28ThisYear;
    }
    return DateTime(now.year + 1, 8, 28);
  }

  // 🔥 NEW METHOD: Release processing lock (called after cart clear)
  /// Releases the processing lock to allow new payment operations
  /// **CRITICAL:** Must be called AFTER CartManager.clearPendingItems() completes
  static void releaseProcessingLock() {
    _isProcessing = false;
    print('✅ DEBUG: Processing lock released');
  }

  /// Fetches ALL active subscription plans from `custom_subscription_plans`
  /// and returns them as a unified list suitable for the Satispay confirmation dropdown.
  /// Each item has keys: 'name' (String), 'price' (double), plus 'id',
  /// 'is_unlimited', 'entry_count', 'duration_months' for callers (e.g. the
  /// Satispay plan-selection screen) that need more than name/price.
  /// Existing callers that only read 'name'/'price' are unaffected.
  static Future<List<Map<String, dynamic>>> getAllPlansForSatispay() async {
    try {
      final customResponse = await _supabase
          .from('custom_subscription_plans')
          .select('id, name, amount, is_unlimited, entry_count, duration_months')
          .eq('is_active', true)
          .order('amount');

      final List<Map<String, dynamic>> result = [];
      for (final row in customResponse) {
        result.add({
          'id': row['id'] as String,
          'name': row['name'] as String,
          'price': (row['amount'] as num).toDouble(),
          'is_unlimited': row['is_unlimited'] as bool? ?? false,
          'entry_count': (row['entry_count'] as num?)?.toInt(),
          'duration_months': (row['duration_months'] as num?)?.toInt() ?? 1,
        });
      }

      result.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      return result;
    } catch (e) {
      return [];
    }
  }

  // Get all subscription plans
  static Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    try {
      final response = await _supabase
          .from('custom_subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('amount');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch subscription plans: $e');
    }
  }

  // Get user's active subscriptions
  static Future<List<Map<String, dynamic>>> getUserActiveSubscriptions([
    String? userId,
  ]) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc(
        'get_user_active_subscriptions',
        params: {'user_uuid': currentUserId},
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch user subscriptions: $e');
    }
  }

  // Create a new subscription
  static Future<Map<String, dynamic>> createSubscription({
    required String subscriptionPlanId,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get plan details from custom_subscription_plans
      final planResponse = await _supabase
          .from('custom_subscription_plans')
          .select('*')
          .eq('id', subscriptionPlanId)
          .single();

      final plan = Map<String, dynamic>.from(planResponse);

      // Calculate entries and expiration based on plan type
      int entriesRemaining = 0;
      int entriesTotal = 0;
      DateTime? expiresAt;

      final planType = plan['plan_type'] as String? ?? 'monthly';
      switch (planType) {
        case 'single_entry':
          entriesRemaining = 1;
          entriesTotal = 1;
          break;
        case 'multi_entry':
          entriesRemaining = plan['entry_count'] ?? 0;
          entriesTotal = plan['entry_count'] ?? 0;
          break;
        case 'monthly':
          final durationMonths =
              (plan['duration_months'] as num?)?.toInt() ?? 1;
          // 🔥 STACKING LOGIC: if user already has an active subscription for
          // the same plan, the new expiry starts from the existing expiry date.
          final baseDate = await _getStackingBaseDate(
            userId: currentUserId,
            subscriptionPlanId: subscriptionPlanId,
          );
          expiresAt = baseDate.add(Duration(days: 30 * durationMonths));
          break;
        case 'annual':
          expiresAt = _computeAnnualExpiry();
          break;
      }

      final response = await _supabase
          .from('user_subscriptions')
          .insert({
            'user_id': currentUserId,
            'subscription_plan_id': subscriptionPlanId,
            'entries_remaining': entriesRemaining,
            'entries_total': entriesTotal,
            'is_active': true,
            'expires_at': expiresAt?.toIso8601String(),
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Returns the base date for computing a new monthly subscription expiry.
  /// If the user already has an active (non-expired) subscription for the
  /// **same plan**, returns that subscription's expiry date (stacking).
  /// Otherwise returns [DateTime.now()] (normal behaviour).
  static Future<DateTime> _getStackingBaseDate({
    required String userId,
    required String subscriptionPlanId,
  }) async {
    try {
      final now = DateTime.now();
      final existing = await _supabase
          .from('user_subscriptions')
          .select('expires_at')
          .eq('user_id', userId)
          .eq('subscription_plan_id', subscriptionPlanId)
          .eq('is_active', true)
          .gt('expires_at', now.toIso8601String())
          .order('expires_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existing != null && existing['expires_at'] != null) {
        final existingExpiry = DateTime.parse(existing['expires_at'] as String);
        print(
          '🔄 STACKING: Same plan repurchased. New expiry starts from: $existingExpiry',
        );
        return existingExpiry;
      }
    } catch (e) {
      print('⚠️ STACKING: Could not check existing subscription: $e');
    }
    return DateTime.now();
  }

  // Use a subscription entry
  static Future<bool> useSubscriptionEntry({
    required String userSubscriptionId,
    String? classType,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'use_subscription_entry',
        params: {
          'p_subscription_id': userSubscriptionId,
          'class_type_param': classType,
          'notes_param': notes,
        },
      );

      return response == true;
    } catch (e) {
      throw Exception('Failed to use subscription entry: $e');
    }
  }

  // Get user's subscription usage history
  static Future<List<Map<String, dynamic>>> getUserSubscriptionUsage([
    String? userId,
  ]) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('subscription_entry_usage')
          .select('*')
          .eq('user_id', currentUserId)
          .order('used_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch subscription usage: $e');
    }
  }

  // Get subscription statistics for user
  static Future<Map<String, dynamic>> getUserSubscriptionStats([
    String? userId,
  ]) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final activeSubscriptions = await getUserActiveSubscriptions(
        currentUserId,
      );
      final usageHistory = await getUserSubscriptionUsage(currentUserId);

      int totalEntriesRemaining = 0;
      int totalEntriesUsed = usageHistory.length;

      for (final sub in activeSubscriptions) {
        totalEntriesRemaining += (sub['entries_remaining'] ?? 0) as int;
      }

      return {
        'active_subscriptions_count': activeSubscriptions.length,
        'total_entries_remaining': totalEntriesRemaining,
        'total_entries_used': totalEntriesUsed,
        'active_subscriptions': activeSubscriptions,
      };
    } catch (e) {
      throw Exception('Failed to fetch subscription stats: $e');
    }
  }

  // Admin functions - Get all subscriptions
  static Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final response = await _supabase
          .from('user_subscriptions')
          .select('''
            *,
            user_profiles!inner(full_name, email)
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch all subscriptions: $e');
    }
  }

  // Admin functions - Get subscription usage analytics
  static Future<Map<String, dynamic>> getSubscriptionAnalytics() async {
    try {
      final allSubs = await getAllSubscriptions();
      final usageResponse = await _supabase
          .from('subscription_entry_usage')
          .select('*')
          .order('used_at', ascending: false);

      final usage = List<Map<String, dynamic>>.from(usageResponse);

      // Calculate analytics
      final totalSubscriptions = allSubs.length;
      final activeSubscriptions = allSubs
          .where((s) => s['is_active'] == true)
          .length;
      final totalEntriesUsed = usage.length;

      return {
        'total_subscriptions': totalSubscriptions,
        'active_subscriptions': activeSubscriptions,
        'total_entries_used': totalEntriesUsed,
        'plan_type_stats': <String, dynamic>{},
        'recent_subscriptions': allSubs.take(10).toList(),
        'recent_usage': usage.take(10).toList(),
      };
    } catch (e) {
      throw Exception('Failed to fetch subscription analytics: $e');
    }
  }

  // Create payment confirmation record
  static Future<String?> createPaymentConfirmation({
    required String subscriptionPlanId,
    required String paymentMethod,
    required double amount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_payment_confirmation',
        params: {
          'p_subscription_plan_id': subscriptionPlanId,
          'p_payment_method': paymentMethod,
          'p_amount': amount,
        },
      );

      return response as String?;
    } catch (e) {
      throw Exception('Failed to create payment confirmation: $e');
    }
  }

  // Confirm payment and activate subscription
  static Future<bool> confirmPayment({
    required String confirmationId,
    String? externalPaymentId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'confirm_payment',
        params: {
          'p_confirmation_id': confirmationId,
          'p_external_payment_id': externalPaymentId,
        },
      );

      return response == true;
    } catch (e) {
      throw Exception('Failed to confirm payment: $e');
    }
  }

  // Check if payment confirmation should be shown
  static Future<bool> shouldShowPaymentConfirmation() async {
    try {
      final response = await _supabase.rpc('should_show_payment_confirmation');
      return response == true;
    } catch (e) {
      return false;
    }
  }

  // Get pending payment confirmations
  static Future<List<Map<String, dynamic>>>
  getPendingPaymentConfirmations() async {
    try {
      final response = await _supabase.rpc('get_pending_payment_confirmations');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch pending confirmations: $e');
    }
  }

  // 🚨 NEW METHOD: Force refresh user data from database
  /// Fetches user profile data from database and populates RegistrationDataManager
  /// **CRITICAL:** Must be called BEFORE creating payment batches to ensure tax code is available
  static Future<void> refreshUserDataFromDatabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('⚠️ DEBUG: No authenticated user found');
        return;
      }

      print('🔍 DEBUG: Fetching user profile data for user: $userId');

      // 🔥 CRITICAL FIX: Fetch complete user profile from database with explicit column selection
      final userProfile = await _supabase
          .from('user_profiles')
          .select(
            'first_name, last_name, email, phone, tax_code, codice_fiscale, address_line, city, province, cap, birth_place, birth_date',
          )
          .eq('id', userId)
          .single();

      print('✅ DEBUG: User profile fetched successfully');
      print('🔍 DEBUG: tax_code from DB: ${userProfile['tax_code']}');
      print(
        '🔍 DEBUG: codice_fiscale from DB: ${userProfile['codice_fiscale']}',
      );

      // Populate RegistrationDataManager with database values
      RegistrationDataManager.nome = userProfile['first_name'];
      RegistrationDataManager.cognome = userProfile['last_name'];
      RegistrationDataManager.email = userProfile['email'];
      RegistrationDataManager.telefono = userProfile['phone'];

      // 🔥 CRITICAL: Tax Code mapping with PRIORITY LOGIC
      // 1. First priority: tax_code field (new standardized field)
      // 2. Second priority: codice_fiscale field (legacy field)
      // 3. Fallback: 'NON DISPONIBILE' (should never reach this if DB has data)
      final taxCodeFromDb = userProfile['tax_code'];
      final codiceFiscaleFromDb = userProfile['codice_fiscale'];

      print(
        '🔍 DEBUG: Raw values - tax_code: $taxCodeFromDb, codice_fiscale: $codiceFiscaleFromDb',
      );

      // Set BOTH fields for backward compatibility
      RegistrationDataManager.taxCode = taxCodeFromDb ?? codiceFiscaleFromDb;
      RegistrationDataManager.codiceFiscale =
          codiceFiscaleFromDb ?? taxCodeFromDb;

      print(
        '✅ DEBUG: RegistrationDataManager.taxCode set to: ${RegistrationDataManager.taxCode}',
      );
      print(
        '✅ DEBUG: RegistrationDataManager.codiceFiscale set to: ${RegistrationDataManager.codiceFiscale}',
      );

      RegistrationDataManager.indirizzoResidenza = userProfile['address_line'];
      RegistrationDataManager.citta = userProfile['city'];
      RegistrationDataManager.provincia = userProfile['province'];
      RegistrationDataManager.cap = userProfile['cap'];
      RegistrationDataManager.luogoNascita = userProfile['birth_place'];

      if (userProfile['birth_date'] != null) {
        RegistrationDataManager.dataNascita = DateTime.parse(
          userProfile['birth_date'],
        );
      }

      print(
        '✅ DEBUG: RegistrationDataManager fully populated. Final tax_code: ${RegistrationDataManager.taxCode}',
      );
    } catch (e) {
      print('❌ DEBUG: Error refreshing user data: $e');
      // Don't throw - log error and continue with existing data
      // This prevents payment flow from breaking if profile fetch fails
    }
  }

  // 🚨 CRITICAL FIX: Remove 'transaction_id' and use simple insert with UI guard
  /// Creates payment confirmations and receipts in a single atomic batch operation
  /// **ENHANCED:** Supports child profile purchases — receipts addressed to adult guardian
  static Future<String> createBatchPaymentAndReceipts({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required double amount,
    required String description,
    String? discipline,
    String? discipline2,
    // 🆕 OPTIONAL — both default to null, which preserves today's behaviour
    // exactly (active-profile beneficiary, confirmed_at = now). Used by
    // PaidIntentsService to activate a subscription on behalf of a payment
    // that may have been confirmed hours ago and/or for a profile that is
    // no longer the "active" one in this session.
    String? beneficiaryProfileIdOverride,
    DateTime? paidAt,
  }) async {
    if (_isProcessing) {
      print('⚠️ DEBUG: Payment already processing, skipping...');
      return '';
    }
    _isProcessing = true;

    try {
      // The authenticated adult is always the payer
      final adultUserId = _supabase.auth.currentUser?.id;
      if (adultUserId == null) throw Exception('User not authenticated');

      // 🔥 CHILD PROFILE CONTEXT: Determine the actual beneficiary user ID.
      // When beneficiaryProfileIdOverride is provided, it fully determines
      // the beneficiary (adult if it matches the authenticated user, child
      // otherwise) instead of the in-memory "active profile".
      final bool isChildActive;
      final String? childProfileId;
      if (beneficiaryProfileIdOverride != null) {
        final overrideIsChild = beneficiaryProfileIdOverride != adultUserId;
        isChildActive = overrideIsChild;
        childProfileId = overrideIsChild ? beneficiaryProfileIdOverride : null;
      } else {
        isChildActive = ChildProfileService.isChildProfileActive;
        childProfileId = ChildProfileService.activeChildProfileId;
      }

      // The beneficiary is either the child or the adult
      final beneficiaryUserId = beneficiaryProfileIdOverride ??
          (isChildActive && childProfileId != null
              ? childProfileId
              : adultUserId);

      print(
        '🔍 DEBUG: isChildActive=$isChildActive, beneficiary=$beneficiaryUserId',
      );

      // 🔥 STEP 2: FORCE DATA REFRESH - Fetch adult (payer) data from database
      print('🔍 DEBUG: Refreshing user data from database...');
      await refreshUserDataFromDatabase();

      // 🎯 STEP 3: Generate UNIQUE batch ID (timestamp-based)
      final uniqueTxId =
          'TXN_${DateTime.now().millisecondsSinceEpoch}_$adultUserId';
      print('🔍 DEBUG: Generated transaction ID: $uniqueTxId');

      // 🎯 STEP 4: CRITICAL TAX CODE VALIDATION — always from adult (payer)
      String? taxCode = RegistrationDataManager.taxCode;
      if (taxCode == null || taxCode.trim().isEmpty) {
        taxCode = RegistrationDataManager.codiceFiscale;
      }
      if (taxCode == null || taxCode.trim().isEmpty) {
        try {
          final directProfile = await _supabase
              .from('user_profiles')
              .select('tax_code, codice_fiscale')
              .eq('id', adultUserId)
              .single();
          taxCode =
              directProfile['tax_code'] ?? directProfile['codice_fiscale'];
        } catch (e) {
          print('❌ DEBUG: Direct DB fetch failed: $e');
        }
      }
      final finalTaxCode = taxCode ?? 'NON DISPONIBILE';

      // Build complete address safely (adult address)
      String? fullAddress;
      if (RegistrationDataManager.indirizzoResidenza != null) {
        final parts = <String>[];
        if (RegistrationDataManager.indirizzoResidenza != null)
          parts.add(RegistrationDataManager.indirizzoResidenza!);
        if (RegistrationDataManager.citta != null)
          parts.add(RegistrationDataManager.citta!);
        if (RegistrationDataManager.provincia != null)
          parts.add(RegistrationDataManager.provincia!);
        if (RegistrationDataManager.cap != null)
          parts.add(RegistrationDataManager.cap!);
        fullAddress = parts.isEmpty ? null : parts.join(', ');
      }

      // Adult name (payer — always on receipt)
      final adultName =
          '${RegistrationDataManager.nome ?? ""} ${RegistrationDataManager.cognome ?? ""}'
              .trim();
      final customerName = adultName.isEmpty ? 'Cliente' : adultName;

      // 🔥 TEEN MINOR CHECK (14-17): if the purchasing user is 14-17 years old,
      // the receipt must be addressed to the parent/guardian, not to the user.
      // This mirrors the existing child-profile behaviour for under-14 purchases.
      String effectiveCustomerName = customerName;
      String effectiveTaxCode = finalTaxCode;
      String? teenMinorNote;

      if (!isChildActive) {
        // Only applies when the adult user themselves is the purchaser (not a child profile purchase)
        try {
          final adultProfile = await _supabase
              .from('user_profiles')
              .select(
                'birth_date, first_name, last_name, codice_fiscale, tax_code, '
                'parent_guardian_name, parent_guardian_surname, parent_guardian_codice_fiscale',
              )
              .eq('id', adultUserId)
              .maybeSingle();

          if (adultProfile != null) {
            final birthDateStr = adultProfile['birth_date'] as String?;
            if (birthDateStr != null && _isMinorAge14to17(birthDateStr)) {
              final guardianName =
                  adultProfile['parent_guardian_name'] as String?;
              final guardianSurname =
                  adultProfile['parent_guardian_surname'] as String?;
              final guardianCF =
                  adultProfile['parent_guardian_codice_fiscale'] as String?;

              final guardianFullName =
                  '${guardianName ?? ''} ${guardianSurname ?? ''}'.trim();

              // Only override if guardian fields are non-empty (fallback to current behaviour otherwise)
              if (guardianFullName.isNotEmpty &&
                  guardianCF != null &&
                  guardianCF.isNotEmpty) {
                effectiveCustomerName = guardianFullName;
                effectiveTaxCode = guardianCF;

                // Build minor note
                final minorFirstName =
                    adultProfile['first_name'] as String? ?? '';
                final minorLastName =
                    adultProfile['last_name'] as String? ?? '';
                final minorFullName = '$minorFirstName $minorLastName'.trim();
                final minorCF =
                    (adultProfile['tax_code'] as String? ??
                    adultProfile['codice_fiscale'] as String? ??
                    '');
                final noteParts = <String>[
                  'Quota relativa al minore: $minorFullName',
                ];
                if (minorCF.isNotEmpty) {
                  noteParts.add('Codice Fiscale: $minorCF');
                }
                noteParts.add('Data di nascita: $birthDateStr');
                teenMinorNote = noteParts.join(' | ');

                print(
                  '🔍 DEBUG: Teen minor (14-17) detected. Receipt addressed to guardian: $effectiveCustomerName',
                );
              }
            }
          }
        } catch (e) {
          print('⚠️ DEBUG: Teen minor check failed, using default: $e');
        }
      }

      // 🔥 CHILD RECEIPT NOTE: If purchasing for a child, add minor note to receipt
      String? minorNote;
      if (isChildActive && childProfileId != null) {
        try {
          final childProfile = beneficiaryProfileIdOverride != null
              // Override path: fetch the specific child profile by id rather
              // than relying on the in-memory "active profile" (which may not
              // match when this runs from a background reconciliation pass).
              ? await _supabase
                  .from('child_profiles')
                  .select('*')
                  .eq('id', childProfileId)
                  .maybeSingle()
              : await ChildProfileService.getActiveChildProfile();
          if (childProfile != null) {
            minorNote = ChildProfileService.buildMinorNote(
              Map<String, dynamic>.from(childProfile),
            );
            print('🔍 DEBUG: Minor note for receipt: $minorNote');
          }
        } catch (e) {
          print('⚠️ DEBUG: Could not fetch child profile for receipt: $e');
        }
      }

      // 🎯 STEP 5: Map discipline display values to database enum values
      String? dbDiscipline;
      if (discipline != null) {
        switch (discipline.toUpperCase()) {
          case 'BJJ':
            dbDiscipline = 'bjj';
            break;
          case 'MMA':
            dbDiscipline = 'mma';
            break;
          case 'SAMBO':
            dbDiscipline = 'sambo';
            break;
          case 'GRAPPLING':
            dbDiscipline = 'grappling';
            break;
          case 'PREP. ATLETICA':
          case 'FITNESS':
            dbDiscipline = 'fitness';
            break;
          default:
            dbDiscipline = null;
        }
      }

      String? dbDiscipline2;
      if (discipline2 != null) {
        switch (discipline2.toUpperCase()) {
          case 'BJJ':
            dbDiscipline2 = 'bjj';
            break;
          case 'MMA':
            dbDiscipline2 = 'mma';
            break;
          case 'SAMBO':
            dbDiscipline2 = 'sambo';
            break;
          case 'GRAPPLING':
            dbDiscipline2 = 'grappling';
            break;
          case 'PREP. ATLETICA':
          case 'FITNESS':
            dbDiscipline2 = 'fitness';
            break;
          default:
            dbDiscipline2 = null;
        }
      }

      // 🎯 STEP 6: Prepare atomic batch data
      final List<Map<String, dynamic>> confirmationsBatch = [];
      final List<Map<String, dynamic>> receiptsBatch = [];

      String finalDescription = description;
      if (discipline != null && discipline2 != null) {
        finalDescription = '$description - $discipline + $discipline2';
      } else if (discipline != null) {
        finalDescription = '$description - $discipline';
      }
      final methodText = _getPaymentMethodText(paymentMethod);
      finalDescription = '$finalDescription (via $methodText)';

      // Pre-fetch plan IDs
      final Map<String, String?> planIdCache = {};
      for (final item in items) {
        final itemName = item['name'] as String? ?? description;
        final itemPrice = (item['price'] as num?)?.toDouble() ?? amount;
        if (!planIdCache.containsKey(itemName)) {
          try {
            final planByName = await _supabase
                .from('custom_subscription_plans')
                .select('id')
                .eq('name', itemName)
                .eq('is_active', true)
                .maybeSingle();
            if (planByName != null) {
              planIdCache[itemName] = planByName['id'] as String?;
            } else {
              final planByPrice = await _supabase
                  .from('custom_subscription_plans')
                  .select('id')
                  .eq('amount', itemPrice)
                  .eq('is_active', true)
                  .limit(1)
                  .maybeSingle();
              planIdCache[itemName] = planByPrice?['id'] as String?;
            }
          } catch (_) {
            planIdCache[itemName] = null;
          }
        }
      }

      for (final item in items) {
        String? itemDiscipline = item['discipline'] as String?;
        String? itemDiscipline2 = item['discipline2'] as String?;
        String? itemDbDiscipline;
        String? itemDbDiscipline2;

        if (itemDiscipline != null) {
          switch (itemDiscipline.toUpperCase()) {
            case 'BJJ':
              itemDbDiscipline = 'bjj';
              break;
            case 'MMA':
              itemDbDiscipline = 'mma';
              break;
            case 'SAMBO':
              itemDbDiscipline = 'sambo';
              break;
            case 'GRAPPLING':
              itemDbDiscipline = 'grappling';
              break;
            case 'PREP. ATLETICA':
            case 'FITNESS':
              itemDbDiscipline = 'fitness';
              break;
            default:
              itemDbDiscipline = null;
          }
        }
        if (itemDiscipline2 != null) {
          switch (itemDiscipline2.toUpperCase()) {
            case 'BJJ':
              itemDbDiscipline2 = 'bjj';
              break;
            case 'MMA':
              itemDbDiscipline2 = 'mma';
              break;
            case 'SAMBO':
              itemDbDiscipline2 = 'sambo';
              break;
            case 'GRAPPLING':
              itemDbDiscipline2 = 'grappling';
              break;
            case 'PREP. ATLETICA':
            case 'FITNESS':
              itemDbDiscipline2 = 'fitness';
              break;
            default:
              itemDbDiscipline2 = null;
          }
        }

        final finalDbDiscipline = itemDbDiscipline ?? dbDiscipline;
        final finalDbDiscipline2 = itemDbDiscipline2 ?? dbDiscipline2;

        // payment_confirmations: user_id is the ADULT PAYER (always a valid user_profiles FK).
        // For child purchases, the child context is stored in the receipt notes field.
        final confirmationData = <String, dynamic>{
          'user_id': adultUserId,
          'amount': amount,
          'payment_method': paymentMethod,
          'status': 'confirmed',
          'confirmed_at': (paidAt ?? DateTime.now()).toIso8601String(),
          'batch_transaction_id': uniqueTxId,
        };

        final itemName = item['name'] as String? ?? description;
        final planId = planIdCache[itemName];
        if (planId != null) {
          // custom_plan_id: correct FK to custom_subscription_plans
          confirmationData['custom_plan_id'] = planId;
          // subscription_plan_id: kept for backward compatibility (no FK constraint now)
          confirmationData['subscription_plan_id'] = planId;
        }
        if (finalDbDiscipline != null)
          confirmationData['target_discipline'] = finalDbDiscipline;
        if (finalDbDiscipline2 != null)
          confirmationData['target_discipline_2'] = finalDbDiscipline2;

        confirmationsBatch.add(confirmationData);

        // non_fiscal_receipts: always addressed to ADULT (payer), with minor note if child purchase
        final receiptNotes = minorNote ?? teenMinorNote;

        // Generate receipt number for each receipt
        final receiptNumber =
            await _supabase.rpc('generate_italian_receipt_number') as String;

        receiptsBatch.add({
          'created_by': adultUserId,
          'customer_name': effectiveCustomerName,
          'customer_tax_code': effectiveTaxCode,
          'customer_address': fullAddress,
          'description': finalDescription,
          'amount': amount,
          'unit_price': amount,
          'quantity': 1,
          'payment_method': paymentMethod,
          'status': 'issued',
          'vat_rate': '0',
          'vat_amount': 0.0,
          'discount_percentage': 0.0,
          'batch_transaction_id': uniqueTxId,
          'receipt_number': receiptNumber,
          'issue_date': DateTime.now().toIso8601String().split('T')[0],
          if (receiptNotes != null) 'notes': receiptNotes,
        });
      }

      // 🔥 STEP 7: ATOMIC BATCH INSERT
      if (confirmationsBatch.isNotEmpty) {
        // Use SECURITY DEFINER RPC to bypass RLS on payment_confirmations
        for (final confirmation in confirmationsBatch) {
          try {
            // Determine beneficiary fields:
            // - For child purchases: beneficiary_profile_id = child_profiles.id, type = 'child'
            // - For adult purchases: beneficiary_profile_id = adult user_id, type = 'adult'
            final String? beneficiaryProfileId =
                isChildActive && childProfileId != null
                ? childProfileId
                : adultUserId;
            final String beneficiaryType =
                isChildActive && childProfileId != null ? 'child' : 'adult';

            await _supabase.rpc(
              'create_payment_confirmation',
              params: {
                'p_user_id': confirmation['user_id'],
                'p_amount': confirmation['amount'],
                'p_payment_method': confirmation['payment_method'],
                'p_status': confirmation['status'],
                'p_confirmed_at': confirmation['confirmed_at'],
                'p_batch_transaction_id': confirmation['batch_transaction_id'],
                'p_custom_plan_id': confirmation['custom_plan_id'],
                'p_subscription_plan_id': confirmation['subscription_plan_id'],
                'p_target_discipline': confirmation['target_discipline'],
                'p_target_discipline_2': confirmation['target_discipline_2'],
                // Pass adult payer ID so the RPC stores a valid user_profiles FK
                // even when the purchase is for a child profile
                'p_payer_id': adultUserId,
                // NEW: structured beneficiary reference — fixes Bug 2
                'p_beneficiary_profile_id': beneficiaryProfileId,
                'p_beneficiary_type': beneficiaryType,
              },
            );
          } catch (rpcError) {
            print(
              '⚠️ RPC create_payment_confirmation failed, falling back to direct insert: $rpcError',
            );
            // Fallback: ensure user_id is always the adult (valid user_profiles FK)
            final fallbackData = Map<String, dynamic>.from(confirmation);
            fallbackData['user_id'] = adultUserId;
            // Also store beneficiary fields in the fallback direct insert
            fallbackData['beneficiary_profile_id'] =
                isChildActive && childProfileId != null
                ? childProfileId
                : adultUserId;
            fallbackData['beneficiary_type'] =
                isChildActive && childProfileId != null ? 'child' : 'adult';
            await _supabase.from('payment_confirmations').insert(fallbackData);
          }
        }
      }
      if (receiptsBatch.isNotEmpty) {
        await _supabase.from('non_fiscal_receipts').insert(receiptsBatch);
      }

      // ✅ STEP 8b: Insert into user_subscriptions for the BENEFICIARY
      try {
        for (final item in items) {
          final itemName = item['name'] as String? ?? description;

          // ── Direct lookup by the custom_plan_id already resolved in planIdCache ──
          final resolvedPlanId = planIdCache[itemName];
          if (resolvedPlanId == null) {
            print(
              '⚠️ STEP 8b: No custom_plan_id in planIdCache for item "$itemName" — skipping user_subscriptions insert',
            );
            continue;
          }

          Map<String, dynamic>? plan;
          try {
            final planResponse = await _supabase
                .from('custom_subscription_plans')
                .select('id, entry_count, is_unlimited, duration_months, name')
                .eq('id', resolvedPlanId)
                .maybeSingle();
            if (planResponse != null) {
              plan = Map<String, dynamic>.from(planResponse);
            }
          } catch (e) {
            print(
              '❌ STEP 8b: Failed to fetch custom plan id=$resolvedPlanId: $e',
            );
          }

          if (plan != null) {
            final isUnlimited = plan['is_unlimited'] as bool? ?? false;
            final planEntryCount = (plan['entry_count'] as num?)?.toInt();
            int entriesRemaining = 0;
            int entriesTotal = 0;
            DateTime? expiresAt;

            // Determine branch: entry pack vs time-based
            if (isUnlimited && planEntryCount != null && planEntryCount > 0) {
              // Entry pack: is_unlimited=true means no time expiry, expires when entries run out
              entriesRemaining = planEntryCount;
              entriesTotal = planEntryCount;
              // expiresAt stays null
            } else {
              // Time-based plan
              final planName = (plan['name'] as String? ?? '').toLowerCase();
              final isAnnual =
                  planName.contains('iscrizione') ||
                  planName.contains('annuale');
              if (isAnnual) {
                expiresAt = _computeAnnualExpiry();
              } else {
                final durationMonths =
                    (plan['duration_months'] as num?)?.toInt() ?? 1;
                final baseDate = await _getStackingBaseDate(
                  userId: beneficiaryUserId,
                  subscriptionPlanId: plan['id'] as String,
                );
                expiresAt = baseDate.add(Duration(days: 30 * durationMonths));
              }
            }

            // 🔥 FIX: Use custom_plan_id (NOT subscription_plan_id which points to old table)
            // user_subscriptions.subscription_plan_id FK → subscription_plans (old table)
            // We store the custom plan reference in custom_plan_id column instead
            await _supabase.from('user_subscriptions').insert({
              'user_id': beneficiaryUserId,
              'custom_plan_id': plan['id'],
              // subscription_plan_id is left NULL — it references old subscription_plans table
              // which does not contain custom plans. Setting it would cause FK violation.
              'entries_remaining': entriesRemaining,
              'entries_total': entriesTotal,
              'is_active': true,
              'expires_at': expiresAt?.toIso8601String(),
            });
            print(
              '✅ DEBUG: user_subscriptions entry created for beneficiary: $beneficiaryUserId, plan: ${plan['name']}, custom_plan_id: ${plan['id']}',
            );
          } else {
            print(
              '⚠️ DEBUG: Could not find custom plan id=$resolvedPlanId for item: $itemName — skipping user_subscriptions insert',
            );
          }
        }
      } catch (e) {
        print('❌ STEP 8b: user_subscriptions insert failed: $e');
      }

      print('✅ DEBUG: Batch operation completed successfully');
      _isProcessing = false;
      return uniqueTxId;
    } catch (e) {
      print('❌ DEBUG: Batch operation failed: $e');
      _isProcessing = false;
      rethrow;
    }
  }

  // Helper method to format payment method text
  static String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'satispay':
        return 'Satispay';
      case 'sumup':
        return 'SumUp';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico Bancario';
      case 'credit_card':
        return 'Carta di Credito';
      default:
        return method.toUpperCase();
    }
  }

  // Create receipt for subscription payment
  static Future<String> createReceipt({
    required double amount,
    required String description,
    String? discipline,
    String? paymentMethod,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get user profile with tax_code
      final userProfile = await _supabase
          .from('user_profiles')
          .select(
            'full_name, tax_code, codice_fiscale, address_line, city, cap, province, '
            'birth_date, first_name, last_name, '
            'parent_guardian_name, parent_guardian_surname, parent_guardian_codice_fiscale',
          )
          .eq('id', userId)
          .single();

      // Use tax_code for linking
      String taxCode =
          userProfile['tax_code'] ??
          userProfile['codice_fiscale'] ??
          'NON DISPONIBILE';
      String customerName = userProfile['full_name'] ?? 'Cliente';
      String? receiptNotes;

      // 🔥 TEEN MINOR CHECK (14-17): receipt addressed to parent/guardian
      final birthDateStr = userProfile['birth_date'] as String?;
      if (birthDateStr != null && _isMinorAge14to17(birthDateStr)) {
        final guardianName = userProfile['parent_guardian_name'] as String?;
        final guardianSurname =
            userProfile['parent_guardian_surname'] as String?;
        final guardianCF =
            userProfile['parent_guardian_codice_fiscale'] as String?;
        final guardianFullName =
            '${guardianName ?? ''} ${guardianSurname ?? ''}'.trim();

        if (guardianFullName.isNotEmpty &&
            guardianCF != null &&
            guardianCF.isNotEmpty) {
          customerName = guardianFullName;
          taxCode = guardianCF;

          final minorFirstName = userProfile['first_name'] as String? ?? '';
          final minorLastName = userProfile['last_name'] as String? ?? '';
          final minorFullName = '$minorFirstName $minorLastName'.trim();
          final minorCF =
              (userProfile['tax_code'] as String? ??
              userProfile['codice_fiscale'] as String? ??
              '');
          final noteParts = <String>[
            'Quota relativa al minore: $minorFullName',
          ];
          if (minorCF.isNotEmpty) noteParts.add('Codice Fiscale: $minorCF');
          noteParts.add('Data di nascita: $birthDateStr');
          receiptNotes = noteParts.join(' | ');
        }
      }

      // Build complete address safely
      String? fullAddress;
      if (userProfile['address_line'] != null) {
        final parts = <String>[];
        if (userProfile['address_line'] != null)
          parts.add(userProfile['address_line']);
        if (userProfile['city'] != null) parts.add(userProfile['city']);
        if (userProfile['province'] != null) parts.add(userProfile['province']);
        if (userProfile['cap'] != null) parts.add(userProfile['cap']);
        fullAddress = parts.isEmpty ? null : parts.join(', ');
      }

      // Build description with discipline and payment method
      String finalDescription = description;
      if (discipline != null) {
        finalDescription = '$description - $discipline';
      }

      // Add payment method to description if provided
      if (paymentMethod != null) {
        final methodText = _getPaymentMethodText(paymentMethod);
        finalDescription = '$finalDescription (via $methodText)';
      }

      // Insert receipt into non_fiscal_receipts table
      final response = await _supabase
          .from('non_fiscal_receipts')
          .insert({
            'created_by': userId,
            'customer_name': customerName,
            'customer_tax_code': taxCode,
            'customer_address': fullAddress,
            'description': finalDescription,
            'amount': amount,
            'unit_price': amount,
            'quantity': 1,
            'payment_method': paymentMethod ?? 'sumup',
            'status': 'issued',
            'vat_rate': '0',
            'vat_amount': 0.0,
            'discount_percentage': 0.0,
            'notes': receiptNotes ?? 'Subscription payment',
          })
          .select('id, receipt_number')
          .single();

      return response['id'] as String;
    } catch (e) {
      print('⚠️ Receipt creation failed: $e');
      throw Exception('Failed to create receipt: $e');
    }
  }

  /// Returns true if [birthDateStr] (yyyy-MM-dd) corresponds to an age of 14–17 today (inclusive).
  static bool _isMinorAge14to17(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age >= 14 && age <= 17;
    } catch (_) {
      return false;
    }
  }
}
