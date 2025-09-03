import 'package:intl/intl.dart';
import '../models/receipt_model.dart';
import '../services/supabase_service.dart';

class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  final client = SupabaseService.instance.client;

  /// Create receipt for SumUp payment (amount and subscription known)
  Future<ReceiptModel> createReceiptForSumUp({
    required String userId,
    required String subscriptionId,
    required double amount,
    required String subscriptionType,
  }) async {
    try {
      final response = await client.rpc('create_receipt', params: {
        'p_user_id': userId,
        'p_subscription_id': subscriptionId,
        'p_amount': amount,
        'p_payment_method': 'sumup',
        'p_subscription_type': subscriptionType,
      });

      final receiptId = response as String;
      return await getReceiptById(receiptId);
    } catch (error) {
      throw Exception('Failed to create SumUp receipt: $error');
    }
  }

  /// Create receipt for Satispay payment (manual amount entry)
  Future<ReceiptModel> createReceiptForSatispay({
    required String userId,
    required double amount,
    required String subscriptionType,
  }) async {
    try {
      // First create subscription
      final subscriptionId = await _createSubscription(
        userId: userId,
        amount: amount,
        type: subscriptionType,
      );

      final response = await client.rpc('create_receipt', params: {
        'p_user_id': userId,
        'p_subscription_id': subscriptionId,
        'p_amount': amount,
        'p_payment_method': 'satispay',
        'p_subscription_type': subscriptionType,
      });

      final receiptId = response as String;
      return await getReceiptById(receiptId);
    } catch (error) {
      throw Exception('Failed to create Satispay receipt: $error');
    }
  }

  /// Create subscription record
  Future<String> _createSubscription({
    required String userId,
    required double amount,
    required String type,
  }) async {
    try {
      // Calculate dates using business rules
      final dates = await _calculateSubscriptionDates(type);

      final response = await client
          .from('subscriptions')
          .insert({
            'user_id': userId,
            'type': type,
            'amount': amount,
            'start_date': dates['start_date'],
            'end_date': dates['end_date'],
            'is_active': true,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (error) {
      throw Exception('Failed to create subscription: $error');
    }
  }

  /// Calculate subscription dates according to Team Ragnarok rules
  Future<Map<String, String>> _calculateSubscriptionDates(String type) async {
    final now = DateTime.now();

    if (type == 'monthly') {
      // Monthly: Always from 10th of current month to 10th of next month
      final startDate = DateTime(now.year, now.month, 10);
      final endDate = DateTime(now.year, now.month + 1, 10);

      return {
        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
      };
    } else {
      // Annual: Valid until August 28th based on payment timing
      late DateTime endDate;

      if (now.month >= 8 && now.day >= 29) {
        // Paid from August 29th onwards - valid until next year's August 28th
        endDate = DateTime(now.year + 1, 8, 28);
      } else {
        // Paid before August 29th - valid until current year's August 28th
        endDate = DateTime(now.year, 8, 28);
      }

      return {
        'start_date': DateFormat('yyyy-MM-dd').format(now),
        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
      };
    }
  }

  /// Get receipt by ID with all related data
  Future<ReceiptModel> getReceiptById(String receiptId) async {
    try {
      final response = await client.from('receipts').select('''
            *,
            user_profiles(id, email, full_name, tax_code, address, phone),
            gym_info(id, name, address, tax_code, phone, email),
            subscriptions(id, type, amount, start_date, end_date, is_active)
          ''').eq('id', receiptId).single();

      return ReceiptModel.fromJson(response);
    } catch (error) {
      throw Exception('Failed to get receipt: $error');
    }
  }

  /// Get all receipts for a user
  Future<List<ReceiptModel>> getUserReceipts(String userId) async {
    try {
      final response = await client.from('receipts').select('''
            *,
            user_profiles(id, email, full_name, tax_code, address, phone),
            gym_info(id, name, address, tax_code, phone, email),
            subscriptions(id, type, amount, start_date, end_date, is_active)
          ''').eq('user_id', userId).order('issue_date', ascending: false);

      return response.map((json) => ReceiptModel.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to get user receipts: $error');
    }
  }

  /// Get all receipts for admin view
  Future<List<ReceiptModel>> getAllReceipts({String? userFilter}) async {
    try {
      var query = client.from('receipts').select('''
            *,
            user_profiles(id, email, full_name, tax_code, address, phone),
            gym_info(id, name, address, tax_code, phone, email),
            subscriptions(id, type, amount, start_date, end_date, is_active)
          ''');

      if (userFilter != null && userFilter.isNotEmpty) {
        query = query.ilike('user_profiles.full_name', '%$userFilter%');
      }

      final response = await query.order('issue_date', ascending: false);

      return response.map((json) => ReceiptModel.fromJson(json)).toList();
    } catch (error) {
      throw Exception('Failed to get all receipts: $error');
    }
  }

  /// Generate PDF content for receipt
  String generateReceiptPdf(ReceiptModel receipt) {
    final issueDate = DateFormat('dd-MM-yyyy').format(receipt.issueDate);
    final validityPeriod = receipt.validityStart != null &&
            receipt.validityEnd != null
        ? 'dal ${DateFormat('dd/MM/yyyy').format(receipt.validityStart!)} al ${DateFormat('dd/MM/yyyy').format(receipt.validityEnd!)}'
        : '';

    return '''
RICEVUTA NON FISCALE

${receipt.gym?.name ?? 'TEAM RAGNAROK ASD'}
${receipt.gym?.address ?? 'via giulio bezzi 25, 48026 Russi - RA'}
Codice Fiscale: ${receipt.gym?.taxCode ?? '92100170395'}

==========================================

Ricevuta fiscale ${receipt.receiptNumber} del $issueDate

DATI CLIENTE:
${receipt.user?.fullName ?? ''}
${receipt.user?.phone != null ? 'Tel. ${receipt.user!.phone}' : ''}
${receipt.user?.email ?? ''}

DETTAGLI PAGAMENTO:
Descrizione: ${receipt.description}
Periodo di validità: $validityPeriod
Quantità: ${receipt.quantity}
Prezzo unitario: €${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}
Importo: €${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}
IVA: ${receipt.vatRate.toStringAsFixed(2)}% (N2.2)

Metodo di pagamento: ${_getPaymentMethodText(receipt.paymentMethod)}

==========================================

${receipt.notes}

Data: $issueDate
    ''';
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'Satispay';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico Bancario';
      default:
        return method;
    }
  }

  /// Check if user needs payment reminder
  Future<bool> needsPaymentReminder(String userId) async {
    try {
      final response = await client
          .rpc('check_payment_reminder_needed', params: {'p_user_id': userId});
      return response as bool;
    } catch (error) {
      throw Exception('Failed to check payment reminder: $error');
    }
  }

  /// Create payment reminder
  Future<void> createPaymentReminder(String userId) async {
    try {
      await client.from('payment_reminders').insert({
        'user_id': userId,
        'reminder_date': DateTime.now().toIso8601String().split('T')[0],
        'message':
            'Ricorda di pagare il tuo abbonamento mensile entro il giorno 10.',
        'is_sent': false,
      });
    } catch (error) {
      throw Exception('Failed to create payment reminder: $error');
    }
  }

  /// Get pending payment reminders for user
  Future<List<Map<String, dynamic>>> getPendingReminders(String userId) async {
    try {
      final response = await client
          .from('payment_reminders')
          .select()
          .eq('user_id', userId)
          .eq('is_sent', false)
          .order('reminder_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Failed to get pending reminders: $error');
    }
  }

  /// Mark reminder as sent
  Future<void> markReminderSent(String reminderId) async {
    try {
      await client
          .from('payment_reminders')
          .update({'is_sent': true}).eq('id', reminderId);
    } catch (error) {
      throw Exception('Failed to mark reminder as sent: $error');
    }
  }
}