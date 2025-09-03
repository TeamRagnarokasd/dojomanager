import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class ReceiptFormWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;

  const ReceiptFormWidget({
    Key? key,
    required this.onSubmit,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ReceiptFormWidget> createState() => _ReceiptFormWidgetState();
}

class _ReceiptFormWidgetState extends State<ReceiptFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _customerNameController = TextEditingController();
  final _customerTaxCodeController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _fiscalNotesController = TextEditingController();

  String _selectedVatRate = '0';
  String _selectedPaymentMethod = 'cash';
  DateTime? _validityStartDate;
  DateTime? _validityEndDate;

  final List<String> _vatRates = ['0', '4', '5', '10', '22'];
  final Map<String, String> _paymentMethods = {
    'cash': 'Contanti',
    'satispay': 'Satispay',
    'sumup': 'SumUp',
    'bank_transfer': 'Bonifico Bancario',
    'credit_card': 'Carta di Credito',
  };

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
    _fiscalNotesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final formData = {
        'customerName': _customerNameController.text,
        'customerTaxCode':
            _customerTaxCodeController.text.isNotEmpty
                ? _customerTaxCodeController.text
                : null,
        'customerAddress':
            _customerAddressController.text.isNotEmpty
                ? _customerAddressController.text
                : null,
        'description': _descriptionController.text,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'unitPrice': double.tryParse(_unitPriceController.text) ?? 0.0,
        'discountPercentage': double.tryParse(_discountController.text) ?? 0.0,
        'vatRate': _selectedVatRate,
        'paymentMethod': _selectedPaymentMethod,
        'validityStartDate': _validityStartDate,
        'validityEndDate': _validityEndDate,
        'notes':
            _notesController.text.isNotEmpty ? _notesController.text : null,
        'fiscalNotes':
            _fiscalNotesController.text.isNotEmpty
                ? _fiscalNotesController.text
                : null,
      };

      widget.onSubmit(formData);
    }
  }

  void _clearForm() {
    _customerNameController.clear();
    _customerTaxCodeController.clear();
    _customerAddressController.clear();
    _descriptionController.clear();
    _quantityController.text = '1';
    _unitPriceController.clear();
    _discountController.text = '0';
    _notesController.clear();
    _fiscalNotesController.clear();

    setState(() {
      _selectedVatRate = '0';
      _selectedPaymentMethod = 'cash';
      _validityStartDate = null;
      _validityEndDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      child: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Dati Cliente'),
                SizedBox(height: 12.sp),

                // Customer Information
                _buildTextFormField(
                  controller: _customerNameController,
                  label: 'Nome Cliente*',
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Il nome del cliente è obbligatorio';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.sp),

                _buildTextFormField(
                  controller: _customerTaxCodeController,
                  label: 'Codice Fiscale',
                  textCapitalization: TextCapitalization.characters,
                ),
                SizedBox(height: 12.sp),

                _buildTextFormField(
                  controller: _customerAddressController,
                  label: 'Indirizzo',
                  maxLines: 2,
                ),
                SizedBox(height: 20.sp),

                _buildSectionTitle('Dettagli Ricevuta'),
                SizedBox(height: 12.sp),

                // Receipt Details
                _buildTextFormField(
                  controller: _descriptionController,
                  label: 'Descrizione*',
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'La descrizione è obbligatoria';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12.sp),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextFormField(
                        controller: _quantityController,
                        label: 'Quantità*',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Richiesta';
                          }
                          if (int.tryParse(value!) == null ||
                              int.parse(value) <= 0) {
                            return 'Deve essere > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 12.sp),
                    Expanded(
                      flex: 2,
                      child: _buildTextFormField(
                        controller: _unitPriceController,
                        label: 'Prezzo Unitario (€)*',
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Richiesto';
                          }
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
                SizedBox(height: 12.sp),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextFormField(
                        controller: _discountController,
                        label: 'Sconto (%)',
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value?.isNotEmpty == true) {
                            final discount = double.tryParse(value!);
                            if (discount == null ||
                                discount < 0 ||
                                discount > 100) {
                              return 'Deve essere tra 0 e 100';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: 12.sp),
                    Expanded(
                      child: _buildDropdownField<String>(
                        value: _selectedVatRate,
                        label: 'Aliquota IVA (%)',
                        items:
                            _vatRates
                                .map(
                                  (rate) => DropdownMenuItem(
                                    value: rate,
                                    child: Text('$rate%'),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) =>
                                setState(() => _selectedVatRate = value!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.sp),

                _buildDropdownField<String>(
                  value: _selectedPaymentMethod,
                  label: 'Metodo di Pagamento',
                  items:
                      _paymentMethods.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) =>
                          setState(() => _selectedPaymentMethod = value!),
                ),
                SizedBox(height: 20.sp),

                _buildSectionTitle('Periodo di Validità (opzionale)'),
                SizedBox(height: 12.sp),

                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'Data Inizio',
                        selectedDate: _validityStartDate,
                        onDateSelected:
                            (date) => setState(() => _validityStartDate = date),
                      ),
                    ),
                    SizedBox(width: 12.sp),
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'Data Fine',
                        selectedDate: _validityEndDate,
                        onDateSelected:
                            (date) => setState(() => _validityEndDate = date),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.sp),

                _buildSectionTitle('Note'),
                SizedBox(height: 12.sp),

                _buildTextFormField(
                  controller: _notesController,
                  label: 'Note Generali',
                  maxLines: 3,
                ),
                SizedBox(height: 12.sp),

                _buildTextFormField(
                  controller: _fiscalNotesController,
                  label: 'Note Fiscali',
                  maxLines: 2,
                  hintText: 'Es: Operazione esente IVA - N2.2',
                ),
                SizedBox(height: 24.sp),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.isLoading ? null : _clearForm,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.sp),
                        ),
                        child: Text('Cancella'),
                      ),
                    ),
                    SizedBox(width: 12.sp),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: widget.isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.sp),
                        ),
                        child:
                            widget.isLoading
                                ? SizedBox(
                                  height: 20.sp,
                                  width: 20.sp,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Crea Ricevuta'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.sp)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.sp),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.sp),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: textCapitalization,
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.sp)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.sp),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.sp),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required void Function(DateTime?) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        onDateSelected(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.sp)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.sp),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
              : 'Seleziona data',
          style: TextStyle(
            color: selectedDate != null ? null : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
