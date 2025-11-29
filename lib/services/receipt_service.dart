import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt_model.dart';

class ReceiptService {
  final _client = Supabase.instance.client;

  // Get all receipts for a user (production-ready)
  Future<List<ReceiptModel>> getUserReceipts(String userId) async {
    try {
      final response = await _client
          .from('non_fiscal_receipts')
          .select()
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((receipt) => ReceiptModel.fromJson(receipt))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero delle ricevute: $e');
    }
  }

  // Create a new receipt (production-ready)
  Future<ReceiptModel> createReceipt({
    required String description,
    required double amount,
    required String createdBy,
    String? customerName,
    String? customerTaxCode,
    String? customerAddress,
    String? notes,
    String paymentMethod = 'cash',
  }) async {
    try {
      // Validate required production data
      if (description.trim().isEmpty) {
        throw Exception('La descrizione è obbligatoria');
      }
      if (amount <= 0) {
        throw Exception('L\'importo deve essere maggiore di zero');
      }
      if (createdBy.trim().isEmpty) {
        throw Exception('Creatore ricevuta non specificato');
      }

      final response = await _client
          .from('non_fiscal_receipts')
          .insert({
            'description': description.trim(),
            'amount': amount,
            'created_by': createdBy,
            'customer_name': customerName?.trim(),
            'customer_tax_code': customerTaxCode?.trim(),
            'customer_address': customerAddress?.trim(),
            'notes': notes?.trim(),
            'payment_method': paymentMethod,
            'status': 'issued', // Always issued for production
          })
          .select()
          .single();

      return ReceiptModel.fromJson(response);
    } catch (e) {
      throw Exception('Errore nella creazione della ricevuta: $e');
    }
  }

  // Get receipts by date range (production-ready)
  Future<List<ReceiptModel>> getReceiptsByDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    try {
      // Validate date range
      if (startDate.isAfter(endDate)) {
        throw Exception(
            'La data di inizio deve essere precedente alla data di fine');
      }

      final response = await _client
          .from('non_fiscal_receipts')
          .select()
          .eq('created_by', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((receipt) => ReceiptModel.fromJson(receipt))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero delle ricevute per data: $e');
    }
  }

  // Delete a receipt (production-ready with validation)
  Future<void> deleteReceipt(String receiptId, String userId) async {
    try {
      if (receiptId.trim().isEmpty) {
        throw Exception('ID ricevuta non valido');
      }

      // Verify ownership before deletion (production security)
      final existing = await _client
          .from('non_fiscal_receipts')
          .select('created_by')
          .eq('id', receiptId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Ricevuta non trovata');
      }

      if (existing['created_by'] != userId) {
        throw Exception('Non autorizzato a cancellare questa ricevuta');
      }

      await _client.from('non_fiscal_receipts').delete().eq('id', receiptId);
    } catch (e) {
      throw Exception('Errore nella cancellazione della ricevuta: $e');
    }
  }

  // Get receipt statistics for a user (production-ready)
  Future<Map<String, dynamic>> getReceiptStatistics(String userId) async {
    try {
      final response = await _client
          .from('non_fiscal_receipts')
          .select('amount, created_at')
          .eq('created_by', userId);

      if (response.isEmpty) {
        return {
          'totalAmount': 0.0,
          'receiptCount': 0,
          'averageAmount': 0.0,
          'monthlyTotal': 0.0,
          'yearlyTotal': 0.0,
        };
      }

      double totalAmount = 0.0;
      int receiptCount = response.length;
      double monthlyTotal = 0.0;
      double yearlyTotal = 0.0;

      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      for (var receipt in response) {
        final amount = (receipt['amount'] as num).toDouble();
        totalAmount += amount;

        final createdAt = DateTime.parse(receipt['created_at']);

        // Monthly total
        if (createdAt.month == currentMonth && createdAt.year == currentYear) {
          monthlyTotal += amount;
        }

        // Yearly total
        if (createdAt.year == currentYear) {
          yearlyTotal += amount;
        }
      }

      return {
        'totalAmount': totalAmount,
        'receiptCount': receiptCount,
        'averageAmount': receiptCount > 0 ? totalAmount / receiptCount : 0.0,
        'monthlyTotal': monthlyTotal,
        'yearlyTotal': yearlyTotal,
      };
    } catch (e) {
      throw Exception('Errore nel recupero delle statistiche: $e');
    }
  }

  // Get all receipts for admin (production-ready)
  Future<List<ReceiptModel>> getAllReceipts({String? searchFilter}) async {
    try {
      var query = _client.from('non_fiscal_receipts').select();

      // Add search filter if provided
      if (searchFilter != null && searchFilter.trim().isNotEmpty) {
        final filter = '%${searchFilter.trim()}%';
        query = query.or('customer_name.ilike.$filter,'
            'description.ilike.$filter,'
            'receipt_number.ilike.$filter');
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((receipt) => ReceiptModel.fromJson(receipt))
          .toList();
    } catch (e) {
      throw Exception('Errore nel recupero di tutte le ricevute: $e');
    }
  }

  // Check if a payment reminder is needed for the given user (uses Supabase RPC)
  Future<bool> needsPaymentReminder(String userId) async {
    try {
      final result =
          await _client.rpc('check_payment_reminder_needed', params: {
        'p_user_id': userId,
      });

      if (result is bool) {
        return result;
      }

      // Some Supabase versions return a map with a single key or a list
      if (result is Map && result.values.isNotEmpty) {
        final value = result.values.first;
        if (value is bool) return value;
      }
      if (result is List && result.isNotEmpty) {
        final value = result.first;
        if (value is bool) return value;
        if (value is Map &&
            value.values.isNotEmpty &&
            value.values.first is bool) {
          return value.values.first as bool;
        }
      }

      throw Exception('Formato di risposta RPC non valido: $result');
    } catch (e) {
      throw Exception('Errore nella verifica del promemoria pagamento: $e');
    }
  }

  // Create a payment reminder record for the user
  Future<void> createPaymentReminder(
    String userId, {
    DateTime? reminderDate,
    String? message,
  }) async {
    try {
      final DateTime date = reminderDate ?? DateTime.now();
      final String reminderMessage = message ??
          'Ricorda di pagare il tuo abbonamento mensile entro il giorno 10.';

      await _client.from('payment_reminders').insert({
        'user_id': userId,
        'reminder_date': date.toIso8601String(),
        'message': reminderMessage,
        'is_sent': true,
      });
    } catch (e) {
      throw Exception('Errore nella creazione del promemoria pagamento: $e');
    }
  }
}
