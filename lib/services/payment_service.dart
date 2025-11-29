import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class PaymentService {
  static final SupabaseClient _client = SupabaseService.instance.client;

  /// Get payment transactions for the current user
  static Future<List<Map<String, dynamic>>> getPaymentTransactions(
      [String? userId]) async {
    try {
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get payment confirmations with subscription plan details
      final paymentConfirmations = await _client
          .from('payment_confirmations')
          .select('''
            *,
            subscription_plans!inner(name, price, plan_type)
          ''')
          .eq('user_id', currentUserId)
          .eq('status', 'confirmed')
          .order('confirmed_at', ascending: false);

      // Get non-fiscal receipts for additional payment history
      final receipts = await _client
          .from('non_fiscal_receipts')
          .select('*')
          .eq('created_by', currentUserId)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> transactions = [];

      // Process payment confirmations
      for (final payment in paymentConfirmations) {
        final subscriptionPlan = payment['subscription_plans'];
        final confirmedAt = DateTime.parse(payment['confirmed_at']);

        transactions.add({
          'id': payment['id'],
          'description': _generatePaymentDescription(subscriptionPlan),
          'amount': '€${payment['amount'].toString().replaceAll('.', ',')}',
          'date': _formatDate(confirmedAt),
          'status': 'completato',
          'paymentMethod': _formatPaymentMethod(payment['payment_method']),
          'type': _getPaymentType(subscriptionPlan['plan_type']),
          'month': _getMonthYear(confirmedAt),
          'receiptId':
              'PAY-${payment['external_payment_id'] ?? payment['id'].substring(0, 8)}',
          'source': 'payment_confirmation',
          'originalData': payment,
        });
      }

      // Process receipts
      for (final receipt in receipts) {
        final issueDate = DateTime.parse(receipt['issue_date']);

        transactions.add({
          'id': receipt['id'],
          'description': receipt['description'],
          'amount': '€${receipt['amount'].toString().replaceAll('.', ',')}',
          'date': _formatDate(issueDate),
          'status': receipt['status'] == 'issued' ? 'completato' : 'fallito',
          'paymentMethod': _formatPaymentMethod(receipt['payment_method']),
          'type': _getReceiptType(receipt['description']),
          'month': _getMonthYear(issueDate),
          'receiptId': receipt['receipt_number'],
          'source': 'receipt',
          'originalData': receipt,
        });
      }

      // Sort by date (newest first)
      transactions.sort((a, b) {
        final dateA = _parseDate(a['date'] as String);
        final dateB = _parseDate(b['date'] as String);
        return dateB.compareTo(dateA);
      });

      return transactions;
    } catch (e) {
      throw Exception('Failed to fetch payment transactions: $e');
    }
  }

  /// Get subscription status for current user
  static Future<Map<String, dynamic>> getSubscriptionStatus(
      [String? userId]) async {
    try {
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final activeSubscriptions = await _client
          .from('user_subscriptions')
          .select('''
            *,
            subscription_plans!inner(name, price, plan_type, description)
          ''')
          .eq('user_id', currentUserId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);

      if (activeSubscriptions.isEmpty) {
        return {
          'planName': 'Nessun Abbonamento Attivo',
          'renewalDate': '',
          'autoPayment': false,
          'status': 'inactive',
          'hasActiveSubscription': false,
        };
      }

      final subscription = activeSubscriptions.first;
      final plan = subscription['subscription_plans'];
      final expiresAt = subscription['expires_at'] != null
          ? DateTime.parse(subscription['expires_at'])
          : null;

      return {
        'planName': plan['name'],
        'renewalDate': expiresAt != null ? _formatDate(expiresAt) : '',
        'autoPayment': true, // Could be made configurable
        'status': 'active',
        'hasActiveSubscription': true,
        'subscriptionData': subscription,
        'planData': plan,
      };
    } catch (e) {
      throw Exception('Failed to fetch subscription status: $e');
    }
  }

  /// Get payment statistics
  static Future<Map<String, dynamic>> getPaymentStatistics(
      [String? userId]) async {
    try {
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final transactions = await getPaymentTransactions(currentUserId);

      final completedTransactions =
          transactions.where((t) => t['status'] == 'completato').toList();

      double totalSpent = 0;
      for (final transaction in completedTransactions) {
        final amountStr = (transaction['amount'] as String)
            .replaceAll('€', '')
            .replaceAll(',', '.');
        totalSpent += double.tryParse(amountStr) ?? 0;
      }

      // Group by month for analysis
      final monthlyStats = <String, Map<String, dynamic>>{};
      for (final transaction in completedTransactions) {
        final month = transaction['month'] as String;
        if (!monthlyStats.containsKey(month)) {
          monthlyStats[month] = {
            'count': 0,
            'total': 0.0,
            'types': <String>{},
          };
        }
        monthlyStats[month]!['count'] =
            (monthlyStats[month]!['count'] as int) + 1;

        final amountStr = (transaction['amount'] as String)
            .replaceAll('€', '')
            .replaceAll(',', '.');
        final amount = double.tryParse(amountStr) ?? 0;
        monthlyStats[month]!['total'] =
            (monthlyStats[month]!['total'] as double) + amount;
        (monthlyStats[month]!['types'] as Set<String>)
            .add(transaction['type'] as String);
      }

      return {
        'totalTransactions': transactions.length,
        'completedTransactions': completedTransactions.length,
        'totalSpent': totalSpent,
        'monthlyStats': monthlyStats,
        'lastTransactionDate':
            transactions.isNotEmpty ? transactions.first['date'] : null,
      };
    } catch (e) {
      throw Exception('Failed to fetch payment statistics: $e');
    }
  }

  // Helper methods
  static String _generatePaymentDescription(Map<String, dynamic> plan) {
    switch (plan['plan_type']) {
      case 'monthly':
        return '${plan['name']} - ${_getCurrentMonthYear()}';
      case 'annual':
        return '${plan['name']} - Anno ${DateTime.now().year}';
      case 'single_entry':
        return 'Ingresso Singolo - ${plan['name']}';
      case 'multi_entry':
        return '${plan['name']} - Pacchetto Ingressi';
      default:
        return plan['name'] ?? 'Pagamento';
    }
  }

  static String _getPaymentType(String planType) {
    switch (planType) {
      case 'single_entry':
        return 'Classe Singola';
      case 'multi_entry':
        return 'Pacchetto Ingressi';
      case 'monthly':
      case 'annual':
        return 'Abbonamento';
      default:
        return 'Altro';
    }
  }

  static String _getReceiptType(String description) {
    if (description.toLowerCase().contains('abbonamento') ||
        description.toLowerCase().contains('subscription')) {
      return 'Abbonamento';
    } else if (description.toLowerCase().contains('singol') ||
        description.toLowerCase().contains('classe')) {
      return 'Classe Singola';
    }
    return 'Altro';
  }

  static String _formatPaymentMethod(String method) {
    switch (method) {
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
      'Dicembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String _getCurrentMonthYear() {
    return _getMonthYear(DateTime.now());
  }
}
