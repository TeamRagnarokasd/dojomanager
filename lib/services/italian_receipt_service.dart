import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../models/receipt_model.dart';
import '../services/supabase_service.dart';

class ItalianReceiptService {
  static final ItalianReceiptService _instance =
      ItalianReceiptService._internal();
  factory ItalianReceiptService() => _instance;
  ItalianReceiptService._internal();

  final client = SupabaseService.instance.client;

  /// 🔥 FIXED: Create manual receipt using direct insert (no phantom function)
  /// This method now mirrors the payment confirmation flow logic
  /// Steps: 1) Generate receipt number, 2) Direct insert, 3) Return receipt ID
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
    // The student the receipt is FOR (may differ from the admin who creates it)
    String? studentUserId,
    // 'adult' for regular profiles, 'child' for minor profiles
    String beneficiaryType = 'adult',
  }) async {
    try {
      // 🎯 STEP 1: Generate receipt number using existing function
      final receiptNumber =
          await client.rpc('generate_italian_receipt_number') as String;

      print('✅ Generated receipt number: $receiptNumber');

      // 🎯 STEP 2: Calculate total amount
      final subtotal = quantity * unitPrice;
      final discount = subtotal * (discountPercentage / 100);
      final subtotalAfterDiscount = subtotal - discount;

      // Parse VAT rate and calculate VAT amount
      final vatRateDouble = double.tryParse(vatRate) ?? 0.0;
      final vatAmount = subtotalAfterDiscount * (vatRateDouble / 100);
      final totalAmount = subtotalAfterDiscount + vatAmount;

      // Use the student's user id as created_by so RLS allows the student to
      // read their own receipt. Fall back to the caller's id when no student
      // id is supplied (e.g. receipts not linked to a specific user account).
      final effectiveCreatedBy = studentUserId ?? createdBy;

      // Generate the batch_transaction_id upfront so it can be shared between
      // the non_fiscal_receipts row and the payment_confirmations row.
      // We use a UUID-like value derived from a temporary placeholder; the
      // actual receipt UUID is not yet known, so we generate a random suffix.
      final batchTransactionId =
          'MANUAL_RECEIPT_${DateTime.now().millisecondsSinceEpoch}_${createdBy.substring(0, 8)}';

      // 🎯 STEP 3: Direct insert into non_fiscal_receipts table
      final response = await client
          .from('non_fiscal_receipts')
          .insert({
            'created_by': effectiveCreatedBy,
            'customer_name': customerName,
            'customer_tax_code': customerTaxCode,
            'customer_address': customerAddress,
            'description': description,
            'quantity': quantity,
            'unit_price': unitPrice,
            'discount_percentage': discountPercentage,
            'amount': totalAmount,
            'vat_rate': vatRate,
            'vat_amount': vatAmount,
            'payment_method': paymentMethod,
            'receipt_number': receiptNumber,
            'issue_date': DateTime.now().toIso8601String().split('T')[0],
            'validity_start_date': validityStartDate?.toIso8601String().split(
              'T',
            )[0],
            'validity_end_date': validityEndDate?.toIso8601String().split(
              'T',
            )[0],
            'notes': notes,
            'fiscal_notes': fiscalNotes,
            'status': 'issued',
            'batch_transaction_id': batchTransactionId,
          })
          .select('id')
          .single();

      final receiptId = response['id'] as String;
      print('✅ Receipt created successfully with ID: $receiptId');

      // 🎯 STEP 4: If this receipt is for a specific student, create a
      // payment_confirmation row so the annual-registration check and the
      // student's payment history both work correctly.
      if (studentUserId != null) {
        try {
          await client.from('payment_confirmations').insert({
            'user_id': studentUserId,
            'amount': totalAmount,
            'payment_method': paymentMethod,
            'status': 'confirmed',
            'confirmed_at': DateTime.now().toIso8601String(),
            'batch_transaction_id': batchTransactionId,
            'beneficiary_profile_id': studentUserId,
            'beneficiary_type': beneficiaryType,
          });
          print(
            '✅ payment_confirmation created for student $studentUserId '
            '(beneficiary_type=$beneficiaryType, batch=$batchTransactionId)',
          );
        } catch (pcError) {
          // Non-fatal: log but do not fail the whole receipt creation
          print('⚠️ Could not create payment_confirmation: $pcError');
        }
      }

      return receiptId;
    } catch (error) {
      print('❌ Error creating manual receipt: $error');
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
    String userId,
  ) async {
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

  /// 🎨 BEAUTIFUL PDF GENERATOR (Red Header Version) - FIXED VERSION
  /// This is the "PDF Bello" that both Admin and Users should use
  Future<pw.Document> generateBeautifulReceiptPDF(
    Map<String, dynamic> receipt,
  ) async {
    final pdf = pw.Document();

    // Get organization info
    final orgInfo = await getOrganizationInfo();

    // 🔧 FIX 1: Load Team Ragnarok logo from uploaded assets (JPG format)
    final logoBytes = await rootBundle.load(
      'assets/images/146804-1764638363594.jpg',
    );
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final issueDate =
        receipt['issue_date'] ?? DateTime.now().toIso8601String().split('T')[0];
    final receiptNumber = receipt['receipt_number'] ?? '';
    final customerName = receipt['customer_name'] ?? '';
    final description = receipt['description'] ?? '';
    final amount = (receipt['amount'] ?? 0.0) as double;
    final paymentMethod = _getPaymentMethodText(
      receipt['payment_method'] ?? 'cash',
    );

    final customerTaxCode = receipt['customer_tax_code'] ?? 'NON DISPONIBILE';
    final receiptNotes = receipt['notes'] as String?;
    final isKidsPurchase = receiptNotes != null && receiptNotes.isNotEmpty;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🔴 RED HEADER - TEAM RAGNAROK WITH LOGO
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // 🔧 FIX 1: Real Team Ragnarok logo from uploaded asset
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logoImage),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            orgInfo.name,
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            orgInfo.address,
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'c.f. ${orgInfo.taxCode}',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                          if (orgInfo.pec != null && orgInfo.pec!.isNotEmpty)
                            pw.Text(
                              'PEC: ${orgInfo.pec}',
                              style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.white,
                              ),
                            ),
                          if (orgInfo.phone != null)
                            pw.Text(
                              'Tel: ${orgInfo.phone}',
                              style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.white,
                              ),
                            ),
                          if (orgInfo.email != null)
                            pw.Text(
                              'Email: ${orgInfo.email}',
                              style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // RECEIPT TITLE
              pw.Center(
                child: pw.Text(
                  'RICEVUTA NON FISCALE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // RECEIPT INFO BOX
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Ricevuta N°: $receiptNumber',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Data: $issueDate',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // CUSTOMER DETAILS
              pw.Text(
                'DATI CLIENTE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      customerName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'CF: $customerTaxCode',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    if (receipt['customer_address'] != null)
                      pw.Text(
                        receipt['customer_address'],
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    // 🔥 KIDS/MINOR NOTE: Show minor beneficiary info if present
                    if (isKidsPurchase) ...[
                      pw.SizedBox(height: 6),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.orange50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.orange300),
                        ),
                        child: pw.Text(
                          receiptNotes,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // PAYMENT DETAILS TABLE
              pw.Text(
                'DETTAGLI PAGAMENTO',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Descrizione',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Importo',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Data
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(description),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '€ ${amount.toStringAsFixed(2).replaceAll('.', ',')}',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // PAYMENT METHOD
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Metodo di pagamento:',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      paymentMethod,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // 🎯 FIXED: Removed yellow VAT box, replaced with subtle gray legal text
              // This matches payment-history style without the yellow highlighting
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Operazione esclusa da IVA ai sensi dell\'articolo 4, quarto comma, del DPR 26 ottobre 1972, n. 633 e successive modificazioni, in conformità all\'art. 90 della Legge 289/2002',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.justify,
                ),
              ),

              pw.Spacer(),

              // FOOTER
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Grazie per aver scelto Team Ragnarok ASD',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
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
    final paymentMethod = _getPaymentMethodText(
      receipt['payment_method'] ?? 'cash',
    );
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
      // 🎯 FIX: Use the new secure function instead of direct table query
      // This allows students to access organization info for receipt generation
      final response = await client
          .rpc('get_organization_info_for_receipts')
          .single();
      return OrganizationInfo.fromJson(response);
    } catch (error) {
      // If no organization info exists, create default (admin only operation)
      try {
        await client.from('organization_info').insert({
          'name': 'Team Ragnarok ASD',
          'address': 'via giulio bezzi 25, 48026 Russi - RA',
          'tax_code': '92100170395',
        });

        final response = await client
            .rpc('get_organization_info_for_receipts')
            .single();
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
    String? pec,
  }) async {
    try {
      final orgInfo = await getOrganizationInfo();
      await client
          .from('organization_info')
          .update({
            'name': name,
            'address': address,
            'tax_code': taxCode,
            'phone': phone,
            'email': email,
            'pec': pec,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orgInfo.id);
    } catch (error) {
      throw Exception('Failed to update organization info: $error');
    }
  }

  /// Delete receipt (admin only). Always removes associated payment_confirmations
  /// so the receipt disappears from the user's payment history too.
  Future<void> deleteReceipt(
    String receiptId, {
    bool deleteSubscription = false,
  }) async {
    try {
      // Fetch the receipt — NOTE: non_fiscal_receipts has NO user_id column.
      // We get user_id later via payment_confirmations.
      final receiptData = await client
          .from('non_fiscal_receipts')
          .select('id, batch_transaction_id, description')
          .eq('id', receiptId)
          .maybeSingle();

      final batchTxId = receiptData?['batch_transaction_id'] as String?;
      final receiptDescription =
          ((receiptData?['description'] as String?) ?? '').toLowerCase();

      // Determine if this receipt is for an annual registration
      final bool isAnnualRegistration =
          receiptDescription.contains('iscrizione annuale') ||
          receiptDescription.contains('iscrizione  annuale');

      // ─── Resolve user_id via payment_confirmations ───────────────────────
      // Try to find the associated user_id from payment_confirmations using
      // batch_transaction_id or the MANUAL_RECEIPT_<id> patterns.
      String? receiptUserId;
      try {
        Map<String, dynamic>? pcRow;

        if (batchTxId != null && batchTxId.isNotEmpty) {
          final rows = await client
              .from('payment_confirmations')
              .select('user_id')
              .eq('batch_transaction_id', batchTxId)
              .limit(1);
          if (rows.isNotEmpty) {
            pcRow = rows.first;
          }
        }

        // Fallback: try MANUAL_RECEIPT patterns
        if (pcRow == null) {
          final rows = await client
              .from('payment_confirmations')
              .select('user_id')
              .or(
                'batch_transaction_id.eq.MANUAL_RECEIPT_$receiptId,'
                'batch_transaction_id.eq.MANUAL_RECEIPT_${receiptId}_D2,'
                'batch_transaction_id.eq.MANUAL_RECEIPT_${receiptId}_PREP',
              )
              .limit(1);
          if (rows.isNotEmpty) {
            pcRow = rows.first;
          }
        }

        receiptUserId = pcRow?['user_id'] as String?;
      } catch (_) {
        // Non-fatal: proceed without user_id
      }
      // ─────────────────────────────────────────────────────────────────────

      // Always delete associated payment_confirmations so the receipt
      // disappears from the user's payment history as well
      if (batchTxId != null && batchTxId.isNotEmpty) {
        await client
            .from('payment_confirmations')
            .delete()
            .eq('batch_transaction_id', batchTxId);
      }

      // Also delete by MANUAL_RECEIPT patterns
      try {
        await client
            .from('payment_confirmations')
            .delete()
            .or(
              'batch_transaction_id.eq.MANUAL_RECEIPT_$receiptId,'
              'batch_transaction_id.eq.MANUAL_RECEIPT_${receiptId}_D2,'
              'batch_transaction_id.eq.MANUAL_RECEIPT_${receiptId}_PREP',
            );
      } catch (_) {
        // Ignore if no matching records
      }

      // ─── ANNUAL REGISTRATION RESET ───────────────────────────────────────
      // If the receipt is for an annual registration, we must also delete ALL
      // payment_confirmations for this user that are linked to annual plans.
      // This ensures check_user_has_annual_registration() returns false and
      // the user is correctly asked to pay the annual fee again.
      if (isAnnualRegistration && receiptUserId != null) {
        try {
          // Fetch all custom_plan_ids whose name contains 'iscrizione annuale'
          final annualPlans = await client
              .from('custom_subscription_plans')
              .select('id')
              .or(
                'name.ilike.%iscrizione annuale%,'
                'name.ilike.%iscrizione  annuale%',
              );

          if (annualPlans.isNotEmpty) {
            final annualPlanIds = (annualPlans as List)
                .map((p) => p['id'] as String)
                .toList();

            // Delete all payment_confirmations for this user linked to annual plans
            for (final planId in annualPlanIds) {
              try {
                await client
                    .from('payment_confirmations')
                    .delete()
                    .eq('user_id', receiptUserId)
                    .eq('custom_plan_id', planId);
              } catch (_) {
                // Continue even if one deletion fails
              }
            }
          }
        } catch (_) {
          // Non-fatal: continue with receipt deletion
        }

        // Also delete user_subscriptions of type 'annual' for this user
        try {
          await client
              .from('user_subscriptions')
              .delete()
              .eq('user_id', receiptUserId)
              .eq('type', 'annual');
        } catch (_) {
          // Column/table may differ, ignore
        }
      }
      // ─────────────────────────────────────────────────────────────────────

      if (deleteSubscription) {
        // Also try to delete by matching receipt_id directly if column exists
        try {
          await client
              .from('user_subscriptions')
              .delete()
              .eq('receipt_id', receiptId);
        } catch (_) {
          // Column may not exist, ignore
        }
      }

      // Hard delete the receipt from the database
      await client.from('non_fiscal_receipts').delete().eq('id', receiptId);
    } catch (error) {
      throw Exception('Failed to delete receipt: $error');
    }
  }

  /// Soft-delete a receipt for the user (hides it from user view, admin can still see it).
  /// Sets deleted_by_user = true on the receipt row.
  Future<void> softDeleteReceiptForUser(String receiptId) async {
    try {
      await client
          .from('non_fiscal_receipts')
          .update({
            'deleted_by_user': true,
            'deleted_by_user_at': DateTime.now().toIso8601String(),
          })
          .eq('id', receiptId);
    } catch (error) {
      throw Exception('Failed to soft-delete receipt: $error');
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

  /// Get all registered users for receipt generation dropdown
  Future<List<Map<String, dynamic>>> getAllRegisteredUsers() async {
    try {
      final response = await client
          .from('user_profiles')
          .select(
            'id, full_name, first_name, last_name, email, codice_fiscale, tax_code, address_line, city, cap, province',
          )
          .eq('status', 'approved')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      throw Exception('Errore nel caricamento degli utenti registrati: $error');
    }
  }

  /// Get all active subscription plans for receipt generation
  /// Loads from BOTH subscription_plans and custom_subscription_plans
  Future<List<Map<String, dynamic>>> getActiveSubscriptionPlans() async {
    try {
      // Load standard plans
      final standardPlans = await client
          .from('subscription_plans')
          .select('id, name, description, price, plan_type, entry_count')
          .eq('is_active', true)
          .order('price', ascending: true);

      // Load custom plans (these are the ones actually used by the admin)
      final customPlans = await client
          .from('custom_subscription_plans')
          .select(
            'id, name, amount, is_active, duration_months, is_unlimited, entry_count',
          )
          .eq('is_active', true)
          .order('amount', ascending: true);

      // Normalize custom plans to match the standard plan shape
      final normalizedCustom = (customPlans as List).map((plan) {
        final isUnlimited = plan['is_unlimited'] == true;
        final entryCount = plan['entry_count'] as int?;
        String planType;
        if (isUnlimited) {
          planType = 'monthly';
        } else if (entryCount != null && entryCount == 1) {
          planType = 'single_entry';
        } else if (entryCount != null && entryCount > 1) {
          planType = 'multi_entry';
        } else {
          planType = 'monthly';
        }
        return {
          'id': plan['id'],
          'name': plan['name'],
          'description': null,
          'price': plan['amount'],
          'plan_type': planType,
          'entry_count': entryCount,
          'is_custom': true, // flag to distinguish in activateSubscription
        };
      }).toList();

      // Combine: custom plans first (they are the real ones), then standard
      final combined = [
        ...normalizedCustom,
        ...List<Map<String, dynamic>>.from(standardPlans),
      ];
      return combined;
    } catch (error) {
      throw Exception('Errore nel caricamento dei piani abbonamento: $error');
    }
  }

  String? _mapDisciplineToDb(String? discipline) {
    if (discipline == null) return null;
    switch (discipline.toUpperCase()) {
      case 'BJJ':
        return 'bjj';
      case 'MMA':
        return 'mma';
      case 'SAMBO':
        return 'sambo';
      case 'GRAPPLING':
        return 'grappling';
      case 'PREP. ATLETICA':
      case 'FITNESS':
        return 'fitness';
      default:
        return null;
    }
  }

  Future<void> activateSubscriptionForUser({
    required String userId,
    required String subscriptionPlanId,
    required double amount,
    required String paymentMethod,
    String? targetDiscipline,
    String? targetDiscipline2,
    bool includesPreparazione = false,
    required String receiptId,
    bool isCustomPlan = false,
  }) async {
    try {
      final dbDiscipline = _mapDisciplineToDb(targetDiscipline);
      final dbDiscipline2 = _mapDisciplineToDb(targetDiscipline2);
      final now = DateTime.now().toIso8601String();

      // Resolve plan metadata from the correct table
      String planType = 'monthly';
      int planEntryCount = 0;
      try {
        if (isCustomPlan) {
          final planRow = await client
              .from('custom_subscription_plans')
              .select('is_unlimited, entry_count, duration_months')
              .eq('id', subscriptionPlanId)
              .maybeSingle();
          if (planRow != null) {
            final isUnlimited = planRow['is_unlimited'] == true;
            final entryCount = planRow['entry_count'] as int?;
            if (isUnlimited) {
              planType = 'monthly';
            } else if (entryCount != null && entryCount == 1) {
              planType = 'single_entry';
              planEntryCount = 1;
            } else if (entryCount != null && entryCount > 1) {
              planType = 'multi_entry';
              planEntryCount = entryCount;
            } else {
              planType = 'monthly';
            }
          }
        } else {
          final planRow = await client
              .from('subscription_plans')
              .select('plan_type, entry_count')
              .eq('id', subscriptionPlanId)
              .maybeSingle();
          if (planRow != null) {
            planType = (planRow['plan_type'] as String?) ?? 'monthly';
            planEntryCount = (planRow['entry_count'] as int?) ?? 0;
          }
        }
      } catch (e) {
        print('⚠️ activateSubscriptionForUser: plan lookup failed: $e');
      }

      int entriesRemaining = 0;
      int entriesTotal = 0;
      DateTime? subscriptionExpiry;
      switch (planType) {
        case 'single_entry':
          entriesRemaining = 1;
          entriesTotal = 1;
          subscriptionExpiry = null;
          break;
        case 'multi_entry':
          entriesRemaining = planEntryCount;
          entriesTotal = planEntryCount;
          subscriptionExpiry = null;
          break;
        case 'monthly':
          subscriptionExpiry = DateTime.now().add(const Duration(days: 30));
          break;
        case 'annual':
          subscriptionExpiry = DateTime.now().add(const Duration(days: 365));
          break;
        default:
          subscriptionExpiry = DateTime.now().add(const Duration(days: 30));
      }

      final paymentExpiresAt = DateTime.now()
          .add(const Duration(days: 365))
          .toIso8601String();

      // Build payment confirmation data — use correct FK column based on plan type
      final Map<String, dynamic> confirmationData = {
        'user_id': userId,
        'amount': amount,
        'payment_method': paymentMethod,
        'status': 'confirmed',
        'confirmed_at': now,
        'expires_at': paymentExpiresAt,
        'batch_transaction_id': 'MANUAL_RECEIPT_$receiptId',
      };
      if (isCustomPlan) {
        confirmationData['custom_plan_id'] = subscriptionPlanId;
      } else {
        confirmationData['subscription_plan_id'] = subscriptionPlanId;
      }
      if (dbDiscipline != null) {
        confirmationData['target_discipline'] = dbDiscipline;
      }

      await client.from('payment_confirmations').insert(confirmationData);

      // For doppio corso: create a second payment confirmation for the second discipline
      if (dbDiscipline2 != null) {
        final Map<String, dynamic> conf2 = {
          'user_id': userId,
          'amount': amount,
          'payment_method': paymentMethod,
          'status': 'confirmed',
          'confirmed_at': now,
          'expires_at': paymentExpiresAt,
          'batch_transaction_id': 'MANUAL_RECEIPT_${receiptId}_D2',
          'target_discipline': dbDiscipline2,
        };
        if (isCustomPlan) {
          conf2['custom_plan_id'] = subscriptionPlanId;
        } else {
          conf2['subscription_plan_id'] = subscriptionPlanId;
        }
        await client.from('payment_confirmations').insert(conf2);
      }

      // Auto-include fitness/preparazione atletica when the plan includes it
      if (includesPreparazione &&
          dbDiscipline != 'fitness' &&
          dbDiscipline2 != 'fitness') {
        final Map<String, dynamic> confPrep = {
          'user_id': userId,
          'amount': amount,
          'payment_method': paymentMethod,
          'status': 'confirmed',
          'confirmed_at': now,
          'expires_at': paymentExpiresAt,
          'batch_transaction_id': 'MANUAL_RECEIPT_${receiptId}_PREP',
          'target_discipline': 'fitness',
        };
        if (isCustomPlan) {
          confPrep['custom_plan_id'] = subscriptionPlanId;
        } else {
          confPrep['subscription_plan_id'] = subscriptionPlanId;
        }
        await client.from('payment_confirmations').insert(confPrep);
      }

      // Create user subscription entry
      final Map<String, dynamic> subscriptionData = {
        'user_id': userId,
        'is_active': true,
        'purchased_at': now,
        'entries_remaining': entriesRemaining,
        'entries_total': entriesTotal,
        'expires_at': subscriptionExpiry?.toIso8601String(),
      };
      if (isCustomPlan) {
        subscriptionData['custom_plan_id'] = subscriptionPlanId;
      } else {
        subscriptionData['subscription_plan_id'] = subscriptionPlanId;
      }

      await client.from('user_subscriptions').insert(subscriptionData);

      print(
        '✅ activateSubscriptionForUser: planType=$planType, isCustom=$isCustomPlan, '
        'entries_remaining=$entriesRemaining, expires_at=$subscriptionExpiry',
      );
    } catch (error) {
      throw Exception('Errore nell\'attivazione dell\'abbonamento: $error');
    }
  }
}
