import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';


class ReceiptFilterWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onFiltersApplied;
  final VoidCallback onClearFilters;
  final Map<String, dynamic> currentFilters;

  const ReceiptFilterWidget({
    Key? key,
    required this.onFiltersApplied,
    required this.onClearFilters,
    required this.currentFilters,
  }) : super(key: key);

  @override
  State<ReceiptFilterWidget> createState() => _ReceiptFilterWidgetState();
}

class _ReceiptFilterWidgetState extends State<ReceiptFilterWidget> {
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _paymentMethod = 'all';
  String _subscriptionType = 'all';
  double? _amountMin;
  double? _amountMax;

  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _amountMinController = TextEditingController();
  final TextEditingController _amountMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentFilters();
  }

  void _loadCurrentFilters() {
    if (widget.currentFilters.isNotEmpty) {
      setState(() {
        _dateFrom = widget.currentFilters['date_from'];
        _dateTo = widget.currentFilters['date_to'];
        _paymentMethod = widget.currentFilters['payment_method'] ?? 'all';
        _subscriptionType = widget.currentFilters['subscription_type'] ?? 'all';
        _amountMin = widget.currentFilters['amount_min'];
        _amountMax = widget.currentFilters['amount_max'];

        _clientSearchController.text =
            widget.currentFilters['client_search'] ?? '';
        _amountMinController.text = _amountMin?.toString() ?? '';
        _amountMaxController.text = _amountMax?.toString() ?? '';
      });
    }
  }

  void _applyFilters() {
    final filters = <String, dynamic>{};

    if (_dateFrom != null) filters['date_from'] = _dateFrom;
    if (_dateTo != null) filters['date_to'] = _dateTo;
    if (_paymentMethod != 'all') filters['payment_method'] = _paymentMethod;
    if (_subscriptionType != 'all')
      filters['subscription_type'] = _subscriptionType;
    if (_amountMin != null) filters['amount_min'] = _amountMin;
    if (_amountMax != null) filters['amount_max'] = _amountMax;
    if (_clientSearchController.text.isNotEmpty) {
      filters['client_search'] = _clientSearchController.text;
    }

    widget.onFiltersApplied(filters);
  }

  void _clearAllFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _paymentMethod = 'all';
      _subscriptionType = 'all';
      _amountMin = null;
      _amountMax = null;
      _clientSearchController.clear();
      _amountMinController.clear();
      _amountMaxController.clear();
    });
    widget.onClearFilters();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final initialDate = isFromDate ? _dateFrom : _dateTo;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        if (isFromDate) {
          _dateFrom = pickedDate;
        } else {
          _dateTo = pickedDate;
        }
      });
    }
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _amountMinController.dispose();
    _amountMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.filter_alt, color: Colors.blue.shade700),
                    SizedBox(width: 8.w),
                    Text(
                      'Filtri Avanzati',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Spacer(),
                    TextButton(
                      onPressed: _clearAllFilters,
                      child: Text(
                        'Cancella Tutto',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Client search
                Text(
                  'Cerca Cliente',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _clientSearchController,
                  decoration: InputDecoration(
                    hintText: 'Nome del cliente...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade500),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // Date range
                Text(
                  'Periodo',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.grey.shade600,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                _dateFrom != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(_dateFrom!)
                                    : 'Da...',
                                style: GoogleFonts.inter(
                                  color: _dateFrom != null
                                      ? Colors.black
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 14.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.grey.shade600,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                _dateTo != null
                                    ? DateFormat('dd/MM/yyyy').format(_dateTo!)
                                    : 'A...',
                                style: GoogleFonts.inter(
                                  color: _dateTo != null
                                      ? Colors.black
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // Payment method and subscription type
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metodo Pagamento',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            value: _paymentMethod,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue.shade500),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 12.h,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'all', child: Text('Tutti')),
                              DropdownMenuItem(
                                  value: 'sumup', child: Text('SumUp')),
                              DropdownMenuItem(
                                  value: 'satispay', child: Text('Satispay')),
                              DropdownMenuItem(
                                  value: 'cash', child: Text('Contanti')),
                              DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('Bonifico')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _paymentMethod = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo Abbonamento',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          DropdownButtonFormField<String>(
                            value: _subscriptionType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue.shade500),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 12.h,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'all', child: Text('Tutti')),
                              DropdownMenuItem(
                                  value: 'monthly', child: Text('Mensile')),
                              DropdownMenuItem(
                                  value: 'annual', child: Text('Annuale')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _subscriptionType = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // Amount range
                Text(
                  'Fascia Importo (€)',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountMinController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Min...',
                          prefixText: '€ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue.shade500),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 12.h,
                          ),
                        ),
                        onChanged: (value) {
                          _amountMin = double.tryParse(value);
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _amountMaxController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Max...',
                          prefixText: '€ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.blue.shade500),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 12.h,
                          ),
                        ),
                        onChanged: (value) {
                          _amountMax = double.tryParse(value);
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Applica Filtri',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
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
    );
  }
}