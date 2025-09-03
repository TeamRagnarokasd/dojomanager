import '../models/receipt_model.dart';
import '../services/supabase_service.dart';

class ItalianReceiptService {
  static final ItalianReceiptService _instance =
      ItalianReceiptService._internal();
  factory ItalianReceiptService() => _instance;
  ItalianReceiptService._internal();

  final client = SupabaseService.instance.client;

  /// Create a manual receipt using the database function
  /// This ensures chronological numbering after automatic receipts
  Future<String> createManualReceipt({
    required String createdBy,
    required String customerName,
    required String description,
    String? customerTaxCode,
    String? customerAddress,
    int quantity = 1,
    double unitPrice = 0.0,
    double discountPercentage = 0.0,
    String vatRate = '0',
    String paymentMethod = 'cash',
    DateTime? validityStartDate,
    DateTime? validityEndDate,
    String? notes,
    String? fiscalNotes,
  }) async {
    try {
      final response = await client.rpc('create_italian_receipt', params: {
        'p_created_by': createdBy,
        'p_customer_name': customerName,
        'p_description': description,
        'p_customer_tax_code': customerTaxCode,
        'p_customer_address': customerAddress,
        'p_quantity': quantity,
        'p_unit_price': unitPrice,
        'p_discount_percentage': discountPercentage,
        'p_vat_rate': vatRate,
        'p_payment_method': paymentMethod,
        'p_validity_start_date':
            validityStartDate?.toIso8601String().split('T')[0],
        'p_validity_end_date': validityEndDate?.toIso8601String().split('T')[0],
        'p_notes': notes,
        'p_fiscal_notes': fiscalNotes,
      });

      return response as String; // Returns receipt UUID
    } catch (error) {
      throw Exception('Errore nella creazione della ricevuta manuale: $error');
    }
  }

  /// Get all receipts for admin view with organization info
  Future<List<Map<String, dynamic>>> getAllReceipts() async {
    try {
      final response = await client
          .from('non_fiscal_receipts')
          .select('*, user_profiles(id, full_name, email)')
          .order('created_at', ascending: false);

      // Get organization info for each receipt
      final organizationInfo = await getOrganizationInfo();

      final receiptsWithOrgInfo = List<Map<String, dynamic>>.from(response);
      for (final receipt in receiptsWithOrgInfo) {
        receipt['organization_info'] = {
          'id': organizationInfo.id,
          'name': organizationInfo.name,
          'address': organizationInfo.address,
          'tax_code': organizationInfo.taxCode,
          'phone': organizationInfo.phone,
          'email': organizationInfo.email,
        };
      }

      return receiptsWithOrgInfo;
    } catch (error) {
      throw Exception('Errore nel caricamento delle ricevute: $error');
    }
  }

  /// Get receipts created by specific user with organization info
  Future<List<Map<String, dynamic>>> getUserCreatedReceipts(
      String userId) async {
    try {
      final response = await client
          .from('non_fiscal_receipts')
          .select('*, user_profiles(id, full_name, email)')
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      // Get organization info for each receipt
      final organizationInfo = await getOrganizationInfo();

      final receiptsWithOrgInfo = List<Map<String, dynamic>>.from(response);
      for (final receipt in receiptsWithOrgInfo) {
        receipt['organization_info'] = {
          'id': organizationInfo.id,
          'name': organizationInfo.name,
          'address': organizationInfo.address,
          'tax_code': organizationInfo.taxCode,
          'phone': organizationInfo.phone,
          'email': organizationInfo.email,
        };
      }

      return receiptsWithOrgInfo;
    } catch (error) {
      throw Exception('Errore nel caricamento delle ricevute utente: $error');
    }
  }

  /// Get receipt by ID with organization info
  Future<Map<String, dynamic>?> getReceiptById(String receiptId) async {
    try {
      final response = await client
          .from('non_fiscal_receipts')
          .select('*, user_profiles(id, full_name, email)')
          .eq('id', receiptId)
          .single();

      // Add organization info
      final organizationInfo = await getOrganizationInfo();
      response['organization_info'] = {
        'id': organizationInfo.id,
        'name': organizationInfo.name,
        'address': organizationInfo.address,
        'tax_code': organizationInfo.taxCode,
        'phone': organizationInfo.phone,
        'email': organizationInfo.email,
      };

      return response;
    } catch (error) {
      throw Exception('Errore nel caricamento della ricevuta: $error');
    }
  }

  /// Generate receipt PDF content (simplified version)
  String generateReceiptText(Map<String, dynamic> receipt) {
    final issueDate =
        receipt['issue_date'] ?? DateTime.now().toIso8601String().split('T')[0];
    final receiptNumber = receipt['receipt_number'] ?? '';
    final customerName = receipt['customer_name'] ?? '';
    final description = receipt['description'] ?? '';
    final quantity = receipt['quantity'] ?? 1;
    final unitPrice = receipt['unit_price'] ?? 0.0;
    final amount = receipt['amount'] ?? 0.0;
    final paymentMethod =
        _getPaymentMethodText(receipt['payment_method'] ?? 'cash');
    final notes = receipt['notes'] ?? '';

    return '''
RICEVUTA NON FISCALE

TEAM RAGNAROK ASD
Via Giulio Bezzi 25, 48026 Russi-RA
Codice Fiscale: 92100170395

==========================================

Ricevuta ${receiptNumber} del ${issueDate}

DATI CLIENTE:
${customerName}
${receipt['customer_tax_code'] != null ? 'CF: ${receipt['customer_tax_code']}' : ''}
${receipt['customer_address'] ?? ''}

DETTAGLI:
Descrizione: ${description}
Quantità: ${quantity}
Prezzo unitario: €${unitPrice.toStringAsFixed(2).replaceAll('.', ',')}
Importo totale: €${amount.toStringAsFixed(2).replaceAll('.', ',')}

Metodo di pagamento: ${paymentMethod}

${notes.isNotEmpty ? 'Note: ${notes}' : ''}

==========================================

Data: ${issueDate}
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
      case 'credit_card':
        return 'Carta di Credito';
      default:
        return method;
    }
  }

  /// Get organization information
  Future<OrganizationInfo> getOrganizationInfo() async {
    try {
      final response = await client.from('organization_info').select().single();
      return OrganizationInfo.fromJson(response);
    } catch (error) {
      // If no organization info exists, create default
      try {
        await client.from('organization_info').insert({
          'name': 'Team Ragnarok ASD',
          'address': 'via giulio bezzi 25, 48026 Russi - RA',
          'tax_code': '92100170395',
        });

        final response =
            await client.from('organization_info').select().single();
        return OrganizationInfo.fromJson(response);
      } catch (createError) {
        throw Exception('Failed to get organization info: $createError');
      }
    }
  }

  /// Update organization information (admin only)
  Future<void> updateOrganizationInfo({
    required String name,
    required String address,
    required String taxCode,
    String? phone,
    String? email,
  }) async {
    try {
      final orgInfo = await getOrganizationInfo();
      await client.from('organization_info').update({
        'name': name,
        'address': address,
        'tax_code': taxCode,
        'phone': phone,
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orgInfo.id);
    } catch (error) {
      throw Exception('Failed to update organization info: $error');
    }
  }

  /// Delete receipt (admin only)
  Future<void> deleteReceipt(String receiptId) async {
    try {
      await client.from('non_fiscal_receipts').delete().eq('id', receiptId);
    } catch (error) {
      throw Exception('Failed to delete receipt: $error');
    }
  }

  /// Get monthly receipt statistics
  Future<Map<String, dynamic>> getMonthlyStatistics({
    required int year,
    required int month,
  }) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);

      final response = await client
          .from('non_fiscal_receipts')
          .select('*')
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      final receiptsData = List<Map<String, dynamic>>.from(response);

      double totalRevenue = 0;
      double totalVat = 0;
      Map<String, int> paymentMethods = {};
      Map<String, double> vatByRate = {};

      for (final receiptData in receiptsData) {
        final amount = receiptData['amount'] ?? 0.0;
        final vatAmount = receiptData['vat_amount'] ?? 0.0;
        final paymentMethod = receiptData['payment_method'] ?? 'cash';
        final vatRate = receiptData['vat_rate'] ?? '0';

        totalRevenue += amount;
        totalVat += vatAmount;

        // Count payment methods
        paymentMethods[paymentMethod] =
            (paymentMethods[paymentMethod] ?? 0) + 1;

        // Sum VAT by rate
        vatByRate[vatRate] = (vatByRate[vatRate] ?? 0) + vatAmount;
      }

      return {
        'total_receipts': receiptsData.length,
        'total_revenue': totalRevenue,
        'total_vat': totalVat,
        'payment_methods': paymentMethods,
        'vat_by_rate': vatByRate,
        'receipts': receiptsData,
      };
    } catch (error) {
      throw Exception('Failed to get monthly statistics: $error');
    }
  }
}