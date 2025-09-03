import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../services/italian_receipt_service.dart';
import '../../../services/supabase_service.dart';

class ManualReceiptCreationDialog extends StatefulWidget {
  final VoidCallback onReceiptCreated;

  const ManualReceiptCreationDialog({
    Key? key,
    required this.onReceiptCreated,
  }) : super(key: key);

  @override
  State<ManualReceiptCreationDialog> createState() =>
      _ManualReceiptCreationDialogState();
}

class _ManualReceiptCreationDialogState
    extends State<ManualReceiptCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final ItalianReceiptService _italianReceiptService = ItalianReceiptService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  bool _isLoading = false;

  // Form controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerTaxCodeController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  String _selectedPaymentMethod = 'cash';
  String _selectedVatRate = '0';
  DateTime? _validityStartDate;
  DateTime? _validityEndDate;

  final List<Map<String, String>> _paymentMethods = [
    {'value': 'cash', 'label': 'Contanti'},
    {'value': 'satispay', 'label': 'Satispay'},
    {'value': 'sumup', 'label': 'SumUp'},
    {'value': 'bank_transfer', 'label': 'Bonifico Bancario'},
    {'value': 'credit_card', 'label': 'Carta di Credito'},
  ];

  final List<Map<String, String>> _vatRates = [
    {'value': '0', 'label': '0% (Esente)'},
    {'value': '4', 'label': '4% (Ridotta)'},
    {'value': '5', 'label': '5% (Ridotta)'},
    {'value': '10', 'label': '10% (Ridotta)'},
    {'value': '22', 'label': '22% (Ordinaria)'},
  ];

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerTaxCodeController.dispose();
    _customerAddressController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 90.w,
        constraints: BoxConstraints(maxHeight: 85.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long,
                      color: Colors.green.shade700, size: 24.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Crea Ricevuta Manuale',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Information Section
                      Text(
                        'Informazioni Cliente',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Customer Name
                      TextFormField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: 'Nome Cliente',
                          hintText: 'Inserisci il nome del cliente',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Il nome del cliente è obbligatorio';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Customer Tax Code
                      TextFormField(
                        controller: _customerTaxCodeController,
                        decoration: InputDecoration(
                          labelText: 'Codice Fiscale (Opzionale)',
                          hintText: 'Es. RSSMRA80A01H501X',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Customer Address
                      TextFormField(
                        controller: _customerAddressController,
                        decoration: InputDecoration(
                          labelText: 'Indirizzo (Opzionale)',
                          hintText: 'Via, Città, CAP',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 24.h),

                      // Receipt Details Section
                      Text(
                        'Dettagli Ricevuta',
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Descrizione Servizio/Prodotto',
                          hintText: 'Es. Lezione privata di arti marziali',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'La descrizione è obbligatoria';
                          }
                          return null;
                        },
                        maxLines: 2,
                      ),
                      SizedBox(height: 16.h),

                      // Quantity and Unit Price
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantità',
                                prefixIcon: Icon(Icons.format_list_numbered),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isEmpty == true)
                                  return 'Obbligatorio';
                                if (int.tryParse(value!) == null ||
                                    int.parse(value) <= 0) {
                                  return 'Deve essere > 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _unitPriceController,
                              decoration: InputDecoration(
                                labelText: 'Prezzo Unitario (€)',
                                prefixIcon: Icon(Icons.euro),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                if (value?.isEmpty == true)
                                  return 'Obbligatorio';
                                if (double.tryParse(value!) == null ||
                                    double.parse(value) < 0) {
                                  return 'Deve essere ≥ 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Discount and VAT
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _discountController,
                              decoration: InputDecoration(
                                labelText: 'Sconto (%)',
                                prefixIcon: Icon(Icons.percent),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                if (value?.isNotEmpty == true) {
                                  final discount = double.tryParse(value!);
                                  if (discount == null ||
                                      discount < 0 ||
                                      discount > 100) {
                                    return 'Tra 0 e 100';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedVatRate,
                              decoration: InputDecoration(
                                labelText: 'Aliquota IVA',
                                prefixIcon: Icon(Icons.account_balance),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _vatRates
                                  .map((vat) => DropdownMenuItem(
                                        value: vat['value'],
                                        child: Text(vat['label']!),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedVatRate = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Payment Method
                      DropdownButtonFormField<String>(
                        value: _selectedPaymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Metodo di Pagamento',
                          prefixIcon: Icon(Icons.payment),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _paymentMethods
                            .map((method) => DropdownMenuItem(
                                  value: method['value'],
                                  child: Text(method['label']!),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value!;
                          });
                        },
                      ),
                      SizedBox(height: 16.h),

                      // Validity Period
                      Text(
                        'Periodo di Validità (Opzionale)',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectValidityStartDate,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 16.h, horizontal: 12.w),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 20.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      _validityStartDate != null
                                          ? '${_validityStartDate!.day}/${_validityStartDate!.month}/${_validityStartDate!.year}'
                                          : 'Data Inizio',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        color: _validityStartDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: InkWell(
                              onTap: _selectValidityEndDate,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    vertical: 16.h, horizontal: 12.w),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 20.sp),
                                    SizedBox(width: 8.w),
                                    Text(
                                      _validityEndDate != null
                                          ? '${_validityEndDate!.day}/${_validityEndDate!.month}/${_validityEndDate!.year}'
                                          : 'Data Fine',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        color: _validityEndDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: 'Note Aggiuntive (Opzionale)',
                          hintText:
                              'Es. Lezione individuale di 1 ora - settore combattimento',
                          prefixIcon: Icon(Icons.note_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: Text(
                        'Annulla',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createManualReceipt,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20.sp,
                              height: 20.sp,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Crea Ricevuta',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectValidityStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _validityStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _validityStartDate = date;
      });
    }
  }

  Future<void> _selectValidityEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _validityEndDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: _validityStartDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _validityEndDate = date;
      });
    }
  }

  Future<void> _createManualReceipt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _supabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Utente non autenticato');
      }

      // Create manual receipt using Italian Receipt Service
      await _italianReceiptService.createManualReceipt(
        createdBy: currentUser.id,
        customerName: _customerNameController.text.trim(),
        description: _descriptionController.text.trim(),
        customerTaxCode: _customerTaxCodeController.text.trim().isNotEmpty
            ? _customerTaxCodeController.text.trim()
            : null,
        customerAddress: _customerAddressController.text.trim().isNotEmpty
            ? _customerAddressController.text.trim()
            : null,
        quantity: int.parse(_quantityController.text),
        unitPrice: double.parse(_unitPriceController.text),
        discountPercentage: double.tryParse(_discountController.text) ?? 0.0,
        vatRate: _selectedVatRate,
        paymentMethod: _selectedPaymentMethod,
        validityStartDate: _validityStartDate,
        validityEndDate: _validityEndDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      Fluttertoast.showToast(
        msg: "Ricevuta manuale creata con successo!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      Navigator.pop(context);
      widget.onReceiptCreated();
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella creazione della ricevuta: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
