import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/child_profile_service.dart';

class PaymentService {
  static final SupabaseClient _client = SupabaseService.instance.client;

  /// Get or create receipt ID for a payment confirmation.
  /// Always resolves via batch_transaction_id → non_fiscal_receipts.id directly.
  /// Never uses ambiguous notes/plan/amount search to avoid returning the wrong receipt.
  static Future<String?> getReceiptIdForPayment(String paymentId) async {
    try {
      final paymentRow = await _client
          .from('payment_confirmations')
          .select(
            'id, batch_transaction_id, custom_plan_id, user_id, amount, payment_method, confirmed_at, custom_subscription_plans!payment_confirmations_custom_plan_id_fkey(id, name, amount, plan_type)',
          )
          .eq('id', paymentId)
          .maybeSingle();

      if (paymentRow == null) return null;

      final batchTxId = paymentRow['batch_transaction_id'] as String?;

      // PRIMARY: Always resolve via batch_transaction_id — this is the only
      // reliable 1:1 link between a payment_confirmation and its receipt.
      // Never fall back to notes/plan/amount search (causes Bug 1: wrong receipt shown).
      if (batchTxId != null && batchTxId.isNotEmpty) {
        final byBatch = await _client
            .from('non_fiscal_receipts')
            .select('id')
            .eq('batch_transaction_id', batchTxId)
            .limit(1)
            .maybeSingle();
        if (byBatch != null) return byBatch['id'] as String?;
      }

      // FALLBACK: Only if no batch_transaction_id exists (legacy/manual payments),
      // search by the exact payment confirmation ID stored in fiscal_notes.
      // This is still unambiguous because it references the specific row ID.
      final byFiscalNotes = await _client
          .from('non_fiscal_receipts')
          .select('id')
          .ilike('fiscal_notes', '%$paymentId%')
          .limit(1)
          .maybeSingle();
      if (byFiscalNotes != null) return byFiscalNotes['id'] as String?;

      // SECONDARY FALLBACK: Search by customer_name + issue_date + amount.
      // This finds admin-created receipts that were generated for this payment
      // but not linked via batch_transaction_id or fiscal_notes.
      final userId = paymentRow['user_id'] as String?;
      if (userId == null) return null;

      final userProfile = await _client
          .from('user_profiles')
          .select(
            'full_name, codice_fiscale, tax_code, address_line, city, province, cap',
          )
          .eq('id', userId)
          .single();

      final customerName = userProfile['full_name'] as String?;
      final paymentAmount = paymentRow['amount'];
      final confirmedAtStr = paymentRow['confirmed_at'] as String?;
      final issueDate = confirmedAtStr?.split('T')[0];

      if (customerName != null &&
          customerName.isNotEmpty &&
          issueDate != null) {
        // Try to find an existing admin-created receipt for this customer on this date
        final byCustomerDate = await _client
            .from('non_fiscal_receipts')
            .select('id')
            .ilike('customer_name', customerName)
            .eq('issue_date', issueDate)
            .limit(1)
            .maybeSingle();
        if (byCustomerDate != null) return byCustomerDate['id'] as String?;

        // Also try within ±1 day range in case of timezone differences
        if (confirmedAtStr != null) {
          final confirmedDate = DateTime.tryParse(confirmedAtStr);
          if (confirmedDate != null) {
            final dayBefore = confirmedDate.subtract(const Duration(days: 1));
            final dayAfter = confirmedDate.add(const Duration(days: 1));
            final byCustomerRange = await _client
                .from('non_fiscal_receipts')
                .select('id')
                .ilike('customer_name', customerName)
                .gte('issue_date', dayBefore.toIso8601String().split('T')[0])
                .lte('issue_date', dayAfter.toIso8601String().split('T')[0])
                .limit(1)
                .maybeSingle();
            if (byCustomerRange != null)
              return byCustomerRange['id'] as String?;
          }
        }
      }

      // No existing receipt found — create one only for legacy payments without batch_transaction_id
      final addressParts = <String>[];
      if (userProfile['address_line'] != null)
        addressParts.add(userProfile['address_line']);
      if (userProfile['city'] != null) addressParts.add(userProfile['city']);
      if (userProfile['province'] != null)
        addressParts.add(userProfile['province']);
      if (userProfile['cap'] != null) addressParts.add(userProfile['cap']);

      final customPlan =
          paymentRow['custom_subscription_plans'] as Map<String, dynamic>?;
      final planName = customPlan?['name'] as String? ?? 'Abbonamento';
      final taxCode =
          userProfile['tax_code'] ??
          userProfile['codice_fiscale'] ??
          'NON DISPONIBILE';

      final receiptNumber =
          await _client.rpc('generate_italian_receipt_number') as String;

      final newReceipt = await _client
          .from('non_fiscal_receipts')
          .insert({
            'customer_name': userProfile['full_name'] ?? 'Cliente',
            'customer_tax_code': taxCode,
            'customer_address': addressParts.isNotEmpty
                ? addressParts.join(', ')
                : null,
            'description': planName,
            'amount': paymentRow['amount'],
            'quantity': 1,
            'unit_price': paymentRow['amount'],
            'payment_method': paymentRow['payment_method'],
            'status': 'issued',
            'vat_rate': '0',
            'vat_amount': 0.0,
            'discount_percentage': 0.0,
            'receipt_number': receiptNumber,
            'issue_date':
                (paymentRow['confirmed_at'] as String?)?.split('T')[0] ??
                DateTime.now().toIso8601String().split('T')[0],
            'created_by': userId,
            'batch_transaction_id': batchTxId,
            'fiscal_notes': 'Payment confirmation ID: $paymentId',
          })
          .select('id')
          .single();

      return newReceipt['id'];
    } catch (e) {
      print('Error getting/creating receipt for payment: $e');
      return null;
    }
  }

  /// Get payment transactions for the current user.
  /// Uses the get_receipts_for_user SECURITY DEFINER function which fetches
  /// non_fiscal_receipts by customer_name match — same data admin sees in archive.
  static Future<List<Map<String, dynamic>>> getPaymentTransactions([
    String? userId,
  ]) async {
    try {
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Use SECURITY DEFINER function that fetches receipts by customer_name
      // This is the same data the admin sees in the receipt archive
      List<Map<String, dynamic>> receipts = [];
      try {
        final rpcResult = await _client.rpc(
          'get_receipts_for_user',
          params: {'user_uuid': currentUserId},
        );
        receipts = List<Map<String, dynamic>>.from(rpcResult as List);
        print(
          'DEBUG getPaymentTransactions: found ${receipts.length} receipts via get_receipts_for_user',
        );
      } catch (rpcError) {
        print('RPC get_receipts_for_user failed: $rpcError');
        // Fallback: try direct query (may be limited by RLS)
        try {
          final fallback = await _client
              .from('non_fiscal_receipts')
              .select('*')
              .or('created_by.eq.$currentUserId')
              .order('issue_date', ascending: false);
          receipts = List<Map<String, dynamic>>.from(fallback as List);
          print(
            'DEBUG getPaymentTransactions: found ${receipts.length} receipts via fallback',
          );
        } catch (fallbackError) {
          print('Fallback also failed: $fallbackError');
        }
      }

      final transactions = <Map<String, dynamic>>[];

      for (final receipt in receipts) {
        final issueDateStr = receipt['issue_date'];
        final createdAtStr = receipt['created_at'];
        DateTime issueDate;
        try {
          issueDate = issueDateStr != null
              ? DateTime.parse(issueDateStr.toString())
              : (createdAtStr != null
                    ? DateTime.parse(createdAtStr.toString())
                    : DateTime.now());
        } catch (_) {
          issueDate = DateTime.now();
        }

        final receiptId = receipt['id'] as String;
        final description = receipt['description'] as String? ?? 'Pagamento';
        final amount = receipt['amount'];
        final paymentMethod = receipt['payment_method'] as String? ?? 'cash';
        final status = receipt['status'] as String? ?? 'issued';

        transactions.add({
          'id': receiptId,
          'description': description,
          'amount': '€${_formatAmount(amount)}',
          'date': _formatDate(issueDate),
          'status': status == 'issued' ? 'completato' : 'fallito',
          'paymentMethod': _formatPaymentMethod(paymentMethod),
          'type': _getReceiptType(description),
          'month': _getMonthYear(issueDate),
          'receiptId': receiptId,
          'source': 'receipt',
          'originalData': receipt,
          'hasReceiptInDatabase': true,
        });
      }

      transactions.sort((a, b) {
        final dateA = _parseDate(a['date'] as String);
        final dateB = _parseDate(b['date'] as String);
        return dateB.compareTo(dateA);
      });

      print(
        'DEBUG getPaymentTransactions: returning ${transactions.length} total transactions',
      );
      return transactions;
    } catch (e) {
      print('ERROR getPaymentTransactions: $e');
      throw Exception('Failed to fetch payment transactions: $e');
    }
  }

  /// Get subscription status for current user
  static Future<Map<String, dynamic>> getSubscriptionStatus([
    String? userId,
  ]) async {
    try {
      // 🔥 ACTIVE PROFILE FIX: use active profile ID (child or adult)
      final currentUserId =
          userId ??
          ChildProfileService.getActiveUserId() ??
          _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final dashboardData = await getSubscriptionDashboardData(currentUserId);

      return {
        'planName':
            dashboardData['currentPlanName'] ?? 'Nessun Abbonamento Attivo',
        'renewalDate': dashboardData['renewalDate'] ?? '',
        'autoPayment': false,
        'status': dashboardData['status'] ?? 'inactive',
        'hasActiveSubscription':
            dashboardData['hasActiveSubscription'] ?? false,
      };
    } catch (e) {
      return {
        'planName': 'Nessun Abbonamento Attivo',
        'renewalDate': '',
        'autoPayment': false,
        'status': 'inactive',
        'hasActiveSubscription': false,
      };
    }
  }

  /// Dedicated enrollment gate check.
  /// Uses a SECURITY DEFINER RPC function that runs server-side and bypasses
  /// all RLS complexity. Falls back to a direct query if the RPC fails.
  /// Returns true ONLY if the ACTIVE PROFILE (child or adult) has a confirmed
  /// annual registration where they are the beneficiary.
  static Future<bool> checkHasAnnualRegistration([String? userId]) async {
    try {
      // 🔥 ACTIVE PROFILE FIX: use active profile ID (child or adult)
      final currentUserId =
          userId ??
          ChildProfileService.getActiveUserId() ??
          _client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // PRIMARY: Use SECURITY DEFINER RPC function — bypasses all RLS issues
      try {
        final result = await _client.rpc(
          'check_user_has_annual_registration',
          params: {'p_user_id': currentUserId},
        );
        print('DEBUG checkHasAnnualRegistration RPC result: $result');
        if (result is bool) return result;
        if (result != null) return result as bool;
      } catch (rpcError) {
        print('DEBUG checkHasAnnualRegistration RPC failed: $rpcError');
        // Fall through to direct query
      }

      // FALLBACK: Direct query on payment_confirmations filtered by beneficiary_profile_id.
      // STRICT: only rows where this profile is the explicit beneficiary,
      // OR legacy rows where beneficiary_profile_id IS NULL and user_id matches.
      final rows = await _client
          .from('payment_confirmations')
          .select(
            'id, status, custom_plan_id, custom_subscription_plans!payment_confirmations_custom_plan_id_fkey(name)',
          )
          .or(
            'beneficiary_profile_id.eq.$currentUserId,and(beneficiary_profile_id.is.null,user_id.eq.$currentUserId)',
          )
          .eq('status', 'confirmed')
          .not('custom_plan_id', 'is', null);

      print(
        'DEBUG checkHasAnnualRegistration fallback: found ${(rows as List).length} confirmed rows',
      );

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final plan = row['custom_subscription_plans'] as Map<String, dynamic>?;
        if (plan == null) continue;
        final name = (plan['name'] as String? ?? '').toLowerCase();
        print('DEBUG checkHasAnnualRegistration plan name: $name');
        if (name.contains('iscrizione annuale') ||
            (name.contains('iscrizione') && name.contains('annuale'))) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('ERROR checkHasAnnualRegistration: $e');
      // On any error, deny access — safer to block than to allow
      return false;
    }
  }

  /// Get comprehensive subscription dashboard data including annual registration.
  /// When called without userId, uses the ACTIVE PROFILE (child or adult).
  static Future<Map<String, dynamic>> getSubscriptionDashboardData([
    String? userId,
  ]) async {
    try {
      // 🔥 ACTIVE PROFILE FIX: use active profile ID (child or adult)
      final currentUserId =
          userId ??
          ChildProfileService.getActiveUserId() ??
          _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Try SECURITY DEFINER RPC first
      try {
        final rpcResult = await _client.rpc(
          'get_user_subscription_dashboard',
          params: {'user_uuid': currentUserId},
        );
        final rows = List<Map<String, dynamic>>.from(rpcResult as List);
        print(
          'DEBUG getSubscriptionDashboardData: RPC returned ${rows.length} rows',
        );

        if (rows.isNotEmpty) {
          final row = rows.first;
          final hasAnnual = row['has_annual_registration'] as bool? ?? false;
          final hasActiveSub = row['has_active_subscription'] as bool? ?? false;
          final currentPlanName =
              row['current_plan_name'] as String? ??
              'Nessun abbonamento attivo';
          final annualExpiryDate = row['annual_expiry_date'];
          final confirmedAt = row['current_plan_confirmed_at'];
          final durationMonths =
              (row['current_plan_duration_months'] as num?)?.toInt() ?? 1;

          String renewalDate = '';
          if (hasActiveSub && confirmedAt != null) {
            final purchaseDate = DateTime.parse(confirmedAt.toString());
            final expiryDate = purchaseDate.add(
              Duration(days: 30 * durationMonths),
            );
            renewalDate = _formatDate(expiryDate);
          }

          String annualExpiryStr = '';
          if (hasAnnual && annualExpiryDate != null) {
            final expiry = DateTime.parse(annualExpiryDate.toString());
            annualExpiryStr =
                'scad. ${expiry.day.toString().padLeft(2, '0')}/'
                '${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
          }

          return {
            'currentPlanName': currentPlanName,
            'renewalDate': renewalDate,
            'annualRegistrationStatus': hasAnnual
                ? 'Effettuata'
                : 'Da acquistare',
            'annualRegistrationExpiry': annualExpiryStr,
            'hasAnnualRegistration': hasAnnual,
            'hasActiveSubscription': hasActiveSub,
            'autoPayment': true,
            'status': (hasActiveSub || hasAnnual) ? 'active' : 'inactive',
          };
        }
      } catch (rpcError) {
        print(
          'RPC get_user_subscription_dashboard failed, using fallback: $rpcError',
        );
      }

      // Fallback: direct query on payment_confirmations filtered by beneficiary_profile_id.
      // This ensures the dashboard shows only subscriptions FOR this specific profile
      // (adult or child), not all subscriptions paid by the adult payer.
      final paymentConfirmations = await _client
          .from('payment_confirmations')
          .select('''
            id,
            amount,
            confirmed_at,
            batch_transaction_id,
            custom_plan_id,
            custom_subscription_plans!payment_confirmations_custom_plan_id_fkey(
              id, name, amount, duration_months
            )
          ''')
          .or(
            'beneficiary_profile_id.eq.$currentUserId,and(beneficiary_profile_id.is.null,user_id.eq.$currentUserId)',
          )
          .eq('status', 'confirmed')
          .not('custom_plan_id', 'is', null)
          .order('confirmed_at', ascending: false);

      final confirmations = List<Map<String, dynamic>>.from(
        paymentConfirmations as List,
      );

      print(
        'DEBUG getSubscriptionDashboardData fallback: found ${confirmations.length} confirmations',
      );

      bool hasAnnualRegistration = false;
      DateTime? annualRegistrationExpiry;
      List<Map<String, dynamic>> otherPlans = [];
      final Set<String> seenPlanIds = {};

      for (final payment in confirmations) {
        final customPlan =
            payment['custom_subscription_plans'] as Map<String, dynamic>?;
        if (customPlan == null) continue;

        final customPlanId = payment['custom_plan_id'] as String? ?? '';
        final customPlanName = customPlan['name'] as String? ?? '';
        final lower = customPlanName.toLowerCase();

        final isAnnual =
            lower.contains('iscrizione') || lower.contains('annuale');

        if (isAnnual) {
          hasAnnualRegistration = true;
          if (annualRegistrationExpiry == null) {
            final now = DateTime.now();
            final august28ThisYear = DateTime(now.year, 8, 28);
            final expiryYear =
                now.isBefore(august28ThisYear) ||
                    now.isAtSameMomentAs(august28ThisYear)
                ? now.year
                : now.year + 1;
            annualRegistrationExpiry = DateTime(expiryYear, 8, 28);
          }
        } else {
          if (!seenPlanIds.contains(customPlanId)) {
            seenPlanIds.add(customPlanId);
            otherPlans.add({
              'name': customPlanName,
              'created_at': payment['confirmed_at'] as String,
              'amount': payment['amount'],
              'duration_months':
                  (customPlan['duration_months'] as num?)?.toInt() ?? 1,
            });
          }
        }
      }

      // Also check receipts for subscription info (admin-created receipts)
      if (!hasAnnualRegistration || otherPlans.isEmpty) {
        try {
          final receiptsResult = await _client.rpc(
            'get_receipts_for_user',
            params: {'user_uuid': currentUserId},
          );
          final userReceipts = List<Map<String, dynamic>>.from(
            receiptsResult as List,
          );

          for (final receipt in userReceipts) {
            final desc = (receipt['description'] as String? ?? '')
                .toLowerCase();
            final issueDateStr = receipt['issue_date'];
            if (issueDateStr == null) continue;

            final isAnnual =
                desc.contains('iscrizione') || desc.contains('annuale');

            if (isAnnual && !hasAnnualRegistration) {
              hasAnnualRegistration = true;
              final now = DateTime.now();
              final august28ThisYear = DateTime(now.year, 8, 28);
              final expiryYear =
                  now.isBefore(august28ThisYear) ||
                      now.isAtSameMomentAs(august28ThisYear)
                  ? now.year
                  : now.year + 1;
              annualRegistrationExpiry = DateTime(expiryYear, 8, 28);
            } else if (!isAnnual && otherPlans.isEmpty) {
              // Use receipt description as plan name
              final planName =
                  receipt['description'] as String? ?? 'Abbonamento';
              otherPlans.add({
                'name': planName,
                'created_at':
                    receipt['created_at'] as String? ??
                    DateTime.now().toIso8601String(),
                'amount': receipt['amount'],
                'duration_months': 1,
              });
            }
          }
        } catch (e) {
          print('DEBUG: Could not fetch receipts for dashboard: $e');
        }
      }

      String currentPlanName = 'Nessun abbonamento attivo';
      DateTime? currentPlanExpiry;

      if (otherPlans.isNotEmpty) {
        otherPlans.sort((a, b) {
          final dateA = DateTime.parse(a['created_at'] as String);
          final dateB = DateTime.parse(b['created_at'] as String);
          return dateB.compareTo(dateA);
        });

        final mostRecentPlan = otherPlans.first;
        currentPlanName = mostRecentPlan['name'] as String;
        final durationMonths =
            (mostRecentPlan['duration_months'] as num?)?.toInt() ?? 1;
        final createdAt = DateTime.parse(
          mostRecentPlan['created_at'] as String,
        );
        currentPlanExpiry = createdAt.add(Duration(days: 30 * durationMonths));
      }

      final annualRegistrationStatus = hasAnnualRegistration
          ? 'Effettuata'
          : 'Da acquistare';

      String annualRegistrationExpiryStr = '';
      if (hasAnnualRegistration && annualRegistrationExpiry != null) {
        annualRegistrationExpiryStr =
            'scad. ${annualRegistrationExpiry.day.toString().padLeft(2, '0')}/'
            '${annualRegistrationExpiry.month.toString().padLeft(2, '0')}/'
            '${annualRegistrationExpiry.year}';
      }

      final renewalDate = currentPlanExpiry != null
          ? _formatDate(currentPlanExpiry)
          : '';

      return {
        'currentPlanName': currentPlanName,
        'renewalDate': renewalDate,
        'annualRegistrationStatus': annualRegistrationStatus,
        'annualRegistrationExpiry': annualRegistrationExpiryStr,
        'hasAnnualRegistration': hasAnnualRegistration,
        'hasActiveSubscription': otherPlans.isNotEmpty,
        'autoPayment': true,
        'status': otherPlans.isNotEmpty || hasAnnualRegistration
            ? 'active'
            : 'inactive',
      };
    } catch (e) {
      print('ERROR getSubscriptionDashboardData: $e');
      throw Exception('Failed to fetch subscription dashboard data: $e');
    }
  }

  /// Get payment statistics
  static Future<Map<String, dynamic>> getPaymentStatistics([
    String? userId,
  ]) async {
    try {
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final transactions = await getPaymentTransactions(currentUserId);

      final completedTransactions = transactions
          .where((t) => t['status'] == 'completato')
          .toList();

      double totalSpent = 0;
      for (final transaction in completedTransactions) {
        final amountStr = (transaction['amount'] as String)
            .replaceAll('€', '')
            .replaceAll(',', '.');
        totalSpent += double.tryParse(amountStr) ?? 0;
      }

      final monthlyStats = <String, Map<String, dynamic>>{};
      for (final transaction in completedTransactions) {
        final month = transaction['month'] as String;
        if (!monthlyStats.containsKey(month)) {
          monthlyStats[month] = {'count': 0, 'total': 0.0, 'types': <String>{}};
        }
        monthlyStats[month]!['count'] =
            (monthlyStats[month]!['count'] as int) + 1;

        final amountStr = (transaction['amount'] as String)
            .replaceAll('€', '')
            .replaceAll(',', '.');
        final amount = double.tryParse(amountStr) ?? 0;
        monthlyStats[month]!['total'] =
            (monthlyStats[month]!['total'] as double) + amount;
        (monthlyStats[month]!['types'] as Set<String>).add(
          transaction['type'] as String,
        );
      }

      return {
        'totalTransactions': transactions.length,
        'completedTransactions': completedTransactions.length,
        'totalSpent': totalSpent,
        'monthlyStats': monthlyStats,
        'lastTransactionDate': transactions.isNotEmpty
            ? transactions.first['date']
            : null,
      };
    } catch (e) {
      throw Exception('Failed to fetch payment statistics: $e');
    }
  }

  // Helper methods
  static String _getReceiptType(String description) {
    final d = description.toLowerCase();
    if (d.contains('iscrizione annuale') ||
        d.contains('abbonamento') ||
        d.contains('subscription') ||
        d.contains('mensile') ||
        d.contains('bjj') ||
        d.contains('mma') ||
        d.contains('grappling') ||
        d.contains('sambo') ||
        d.contains('corso')) {
      return 'Abbonamento';
    }
    if (d.contains('singol') || d.contains('classe')) {
      return 'Classe Singola';
    }
    if (d.contains('pacchetto') || d.contains('ingressi')) {
      return 'Pacchetto Ingressi';
    }
    return 'Abbonamento';
  }

  static String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card':
        return 'Carta di Credito';
      case 'satispay':
        return 'Satispay';
      case 'sumup':
        return 'SumUp';
      case 'bank_transfer':
        return 'Bonifico';
      case 'cash':
        return 'Contanti';
      default:
        return method.replaceAll('_', ' ').toUpperCase();
    }
  }

  static String _formatAmount(dynamic amount) {
    if (amount == null) return '0,00';
    final d = (amount as num).toDouble();
    return d.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  static String _getMonthYear(DateTime date) {
    const months = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _getCurrentMonthYear() {
    return _getMonthYear(DateTime.now());
  }
}
