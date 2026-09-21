import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/discipline_service.dart';
import '../../../services/italian_receipt_service.dart';

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
  final _receiptService = ItalianReceiptService();

  // Form controllers for non-dropdown fields
  final _notesController = TextEditingController();
  final _fiscalNotesController = TextEditingController();

  // Dropdown state
  String? _selectedUserId;
  String? _selectedSubscriptionPlanId;
  String _selectedPaymentMethod = 'cash';
  String? _selectedDiscipline;
  String? _selectedDiscipline2;
  DateTime? _validityStartDate;
  DateTime? _validityEndDate;

  // Auto-populated fields from selected user
  String _customerName = '';
  String _customerTaxCode = '';
  String _customerAddress = '';
  String _customerEmail = '';

  // Auto-populated fields from selected subscription
  String _description = '';
  double _unitPrice = 0.0;
  bool _requiresDiscipline = false;
  bool _requiresTwoDisciplines = false;
  bool _includesPreparazione = false;

  // Fixed values for automated receipt
  final int _quantity = 1;
  final double _discountPercentage = 0.0;
  final String _vatRate = '0';

  // Data lists
  List<Map<String, dynamic>> _registeredUsers = [];
  List<Map<String, dynamic>> _subscriptionPlans = [];
  bool _isLoadingData = false;

  // Disciplines loaded dynamically from the database (key = id, value = display name)
  Map<String, String> _disciplineOptions = {};

  Map<String, String> get _paymentMethods => {
    'cash': 'payment.cash'.tr(),
    'sumup': 'payment.sumup'.tr(),
    'satispay': 'payment.satispay'.tr(),
    'bank_transfer': 'payment.bank_transfer'.tr(),
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _fiscalNotesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      final users = await _receiptService.getAllRegisteredUsers();
      final plans = await _receiptService.getActiveSubscriptionPlans();
      final disciplineData = await DisciplineService.instance
          .getActiveDisciplines();

      // Build discipline map: id -> display name
      final Map<String, String> disciplineMap = {};
      for (final d in disciplineData) {
        final id = (d['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final rawName = (d['name'] ?? d['id'] ?? '').toString().toLowerCase();
        String displayName;
        switch (rawName) {
          case 'bjj':
            displayName = 'BJJ (Brazilian Jiu-Jitsu)';
            break;
          case 'mma':
            displayName = 'MMA';
            break;
          case 'sambo':
            displayName = 'Sambo';
            break;
          case 'grappling':
            displayName = 'Grappling';
            break;
          case 'fitness':
          case 'prep_atletica':
            displayName = 'Fitness';
            break;
          default:
            // Use display_name from DB if available, otherwise capitalise id
            displayName = (d['display_name']?.toString().isNotEmpty == true)
                ? d['display_name'].toString()
                : id[0].toUpperCase() + id.substring(1);
        }
        disciplineMap[id] = displayName;
      }

      // Guarantee Fitness is always present (needed for Preparazione Atletica)
      if (!disciplineMap.containsKey('fitness') &&
          !disciplineMap.values.any((v) => v == 'Fitness')) {
        disciplineMap['fitness'] = 'Fitness';
      }

      setState(() {
        _registeredUsers = users;
        _subscriptionPlans = plans;
        _disciplineOptions = disciplineMap;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'errors.load_data_error'.tr(namedArgs: {'detail': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onUserSelected(String? userId) {
    if (userId == null) return;

    final selectedUser = _registeredUsers.firstWhere(
      (user) => user['id'] == userId,
      orElse: () => {},
    );

    if (selectedUser.isNotEmpty) {
      setState(() {
        _selectedUserId = userId;
        _customerName = selectedUser['full_name'] ?? '';
        _customerTaxCode =
            selectedUser['codice_fiscale'] ?? selectedUser['tax_code'] ?? '';
        _customerEmail = selectedUser['email'] ?? '';

        // Build address from components
        final addressLine = selectedUser['address_line'] ?? '';
        final cap = selectedUser['cap'] ?? '';
        final city = selectedUser['city'] ?? '';
        final province = selectedUser['province'] ?? '';

        _customerAddress = [
          if (addressLine.isNotEmpty) addressLine,
          if (cap.isNotEmpty || city.isNotEmpty || province.isNotEmpty)
            '${cap.isNotEmpty ? '$cap ' : ''}${city.isNotEmpty ? '$city ' : ''}${province.isNotEmpty ? '($province)' : ''}'
                .trim(),
        ].where((s) => s.isNotEmpty).join(', ');
      });
    }
  }

  void _onSubscriptionSelected(String? planId) {
    if (planId == null) return;

    final selectedPlan = _subscriptionPlans.firstWhere(
      (plan) => plan['id'] == planId,
      orElse: () => {},
    );

    if (selectedPlan.isNotEmpty) {
      final planName = selectedPlan['name'] ?? '';

      const requiresDiscipline = false;
      const requiresTwo = false;

      setState(() {
        _selectedSubscriptionPlanId = planId;
        _description = planName;
        _unitPrice = (selectedPlan['price'] ?? 0.0) is int
            ? (selectedPlan['price'] as int).toDouble()
            : (selectedPlan['price'] ?? 0.0) as double;
        _requiresDiscipline = requiresDiscipline;
        _requiresTwoDisciplines = requiresTwo;
        _includesPreparazione = false;
        _selectedDiscipline = null;
        _selectedDiscipline2 = null;
      });
    }
  }

  Map<String, String> _getFilteredDisciplineOptions({String? excludeKey}) {
    final filtered = Map<String, String>.from(_disciplineOptions);

    if (_includesPreparazione) {
      // Preparazione Atletica is a bundled bonus and must not constrain
      // the primary technical discipline selection.
      filtered.removeWhere(
        (key, value) =>
            key == 'fitness' ||
            key == 'prep_atletica' ||
            value.toLowerCase() == 'fitness',
      );
    }

    if (excludeKey != null) {
      filtered.remove(excludeKey);
    }

    return filtered;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('validation.select_user'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedSubscriptionPlanId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('validation.select_plan'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_requiresDiscipline && _selectedDiscipline == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _requiresTwoDisciplines
                  ? 'validation.select_first_discipline'.tr()
                  : 'validation.select_discipline'.tr(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_requiresTwoDisciplines && _selectedDiscipline2 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('validation.select_second_discipline'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String fullDescription;
      if (_requiresTwoDisciplines && _selectedDiscipline2 != null) {
        fullDescription =
            '$_description - ${_disciplineOptions[_selectedDiscipline]} + ${_disciplineOptions[_selectedDiscipline2]}';
      } else if (_selectedDiscipline != null) {
        fullDescription =
            '$_description - ${_disciplineOptions[_selectedDiscipline]}';
      } else {
        fullDescription = _description;
      }

      final formData = {
        'userId': _selectedUserId,
        'subscriptionPlanId': _selectedSubscriptionPlanId,
        'isCustomPlan':
            _subscriptionPlans.firstWhere(
              (p) => p['id'] == _selectedSubscriptionPlanId,
              orElse: () => {},
            )['is_custom'] ==
            true,
        'customerName': _customerName,
        'customerTaxCode': _customerTaxCode.isNotEmpty
            ? _customerTaxCode
            : null,
        'customerAddress': _customerAddress.isNotEmpty
            ? _customerAddress
            : null,
        'description': fullDescription,
        'quantity': _quantity,
        'unitPrice': _unitPrice,
        'discountPercentage': _discountPercentage,
        'vatRate': _vatRate,
        'paymentMethod': _selectedPaymentMethod,
        'targetDiscipline': _selectedDiscipline,
        'targetDiscipline2': _requiresTwoDisciplines
            ? _selectedDiscipline2
            : null,
        'includesPreparazione': _includesPreparazione,
        'validityStartDate': _validityStartDate,
        'validityEndDate': _validityEndDate,
        'notes': _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        'fiscalNotes': _fiscalNotesController.text.isNotEmpty
            ? _fiscalNotesController.text
            : null,
      };

      widget.onSubmit(formData);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedUserId = null;
      _selectedSubscriptionPlanId = null;
      _selectedPaymentMethod = 'cash';
      _selectedDiscipline = null;
      _selectedDiscipline2 = null;
      _requiresDiscipline = false;
      _requiresTwoDisciplines = false;
      _includesPreparazione = false;
      _validityStartDate = null;
      _validityEndDate = null;
      _customerName = '';
      _customerTaxCode = '';
      _customerAddress = '';
      _customerEmail = '';
      _description = '';
      _unitPrice = 0.0;
    });
    _notesController.clear();
    _fiscalNotesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.sp,
        16.sp,
        16.sp,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('receipt.customer_section'.tr()),
                SizedBox(height: 12.sp),

                // User Selection Dropdown
                _buildDropdownField<String>(
                  value: _selectedUserId,
                  label: 'receipt.select_user_label'.tr(),
                  hint: 'receipt.select_user_hint'.tr(),
                  items: _registeredUsers
                      .map(
                        (user) => DropdownMenuItem(
                          value: user['id'] as String,
                          child: Text(
                            user['full_name'] ??
                                'receipt.name_unavailable'.tr(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onUserSelected,
                ),
                SizedBox(height: 12.sp),

                // Display auto-populated customer info
                if (_selectedUserId != null) ...[
                  _buildInfoCard('receipt.auto_filled_data'.tr(), [
                    if (_customerTaxCode.isNotEmpty)
                      'receipt.tax_code'.tr(
                        namedArgs: {'value': _customerTaxCode},
                      ),
                    if (_customerAddress.isNotEmpty)
                      'receipt.address'.tr(
                        namedArgs: {'value': _customerAddress},
                      ),
                    if (_customerEmail.isNotEmpty)
                      'receipt.email_label'.tr(
                        namedArgs: {'value': _customerEmail},
                      ),
                  ]),
                  SizedBox(height: 20.sp),
                ],

                _buildSectionTitle('receipt.subscription_section'.tr()),
                SizedBox(height: 12.sp),

                // Subscription Plan Selection
                _buildDropdownField<String>(
                  value: _selectedSubscriptionPlanId,
                  label: 'receipt.select_plan_label'.tr(),
                  hint: 'receipt.select_plan_hint_form'.tr(),
                  items: _subscriptionPlans
                      .map(
                        (plan) => DropdownMenuItem(
                          value: plan['id'] as String,
                          child: Text(
                            '${plan['name']} - €${(plan['price'] ?? 0.0).toString().replaceAll('.', ',')}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onSubscriptionSelected,
                ),
                SizedBox(height: 12.sp),

                if (_requiresDiscipline) ...[
                  _buildDropdownField<String>(
                    value: _selectedDiscipline,
                    label: _requiresTwoDisciplines
                        ? 'receipt.first_discipline'.tr()
                        : 'receipt.discipline'.tr(),
                    hint: _requiresTwoDisciplines
                        ? 'receipt.select_first_discipline'.tr()
                        : 'receipt.select_discipline'.tr(),
                    items: _getFilteredDisciplineOptions().entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedDiscipline = value;
                      if (_selectedDiscipline2 == value) {
                        _selectedDiscipline2 = null;
                      }
                    }),
                  ),
                  SizedBox(height: 8.sp),
                  if (_requiresTwoDisciplines) ...[
                    _buildDropdownField<String>(
                      value: _selectedDiscipline2,
                      label: 'receipt.second_discipline'.tr(),
                      hint: 'receipt.select_second_discipline'.tr(),
                      items:
                          _getFilteredDisciplineOptions(
                                excludeKey: _selectedDiscipline,
                              ).entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedDiscipline2 = value),
                    ),
                    SizedBox(height: 8.sp),
                  ],
                  if (_includesPreparazione)
                    Container(
                      padding: EdgeInsets.all(10.sp),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8.sp),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16.sp,
                            color: Colors.green.shade800,
                          ),
                          SizedBox(width: 8.sp),
                          Expanded(
                            child: Text(
                              'Preparazione Atletica è inclusa automaticamente nel piano selezionato',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_includesPreparazione)
                    Container(
                      padding: EdgeInsets.all(10.sp),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8.sp),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16.sp,
                            color: Colors.amber.shade800,
                          ),
                          SizedBox(width: 8.sp),
                          Expanded(
                            child: Text(
                              'receipt.discipline_booking_hint'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 12.sp),
                ],

                // Display auto-populated subscription info
                if (_selectedSubscriptionPlanId != null) ...[
                  _buildInfoCard('profile.subscription_details'.tr(), [
                    'receipt.description_line'.tr(
                      namedArgs: {'value': _description},
                    ),
                    if (_selectedDiscipline != null)
                      'receipt.discipline_1_line'.tr(
                        namedArgs: {
                          'value':
                              _disciplineOptions[_selectedDiscipline] ?? '',
                        },
                      ),
                    if (_selectedDiscipline2 != null)
                      'receipt.discipline_2_line'.tr(
                        namedArgs: {
                          'value':
                              _disciplineOptions[_selectedDiscipline2] ?? '',
                        },
                      ),
                    if (_includesPreparazione) 'receipt.prep_included'.tr(),
                    'receipt.price_line'.tr(
                      namedArgs: {
                        'value': _unitPrice
                            .toStringAsFixed(2)
                            .replaceAll('.', ','),
                      },
                    ),
                    'receipt.quantity_line'.tr(
                      namedArgs: {'value': '$_quantity'},
                    ),
                    'receipt.vat_line'.tr(namedArgs: {'value': '$_vatRate'}),
                  ]),
                  SizedBox(height: 20.sp),
                ],

                _buildSectionTitle('payment.payment_method'.tr()),
                SizedBox(height: 12.sp),

                _buildDropdownField<String>(
                  value: _selectedPaymentMethod,
                  label: 'receipt.payment_method_required'.tr(),
                  items: _paymentMethods.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedPaymentMethod = value!),
                ),
                SizedBox(height: 20.sp),

                _buildSectionTitle('receipt.validity_period_optional'.tr()),
                SizedBox(height: 12.sp),

                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'seasonal_schedule.start_date'.tr(),
                        selectedDate: _validityStartDate,
                        onDateSelected: (date) =>
                            setState(() => _validityStartDate = date),
                      ),
                    ),
                    SizedBox(width: 12.sp),
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'seasonal_schedule.end_date'.tr(),
                        selectedDate: _validityEndDate,
                        onDateSelected: (date) =>
                            setState(() => _validityEndDate = date),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.sp),

                _buildSectionTitle('receipt.notes_optional'.tr()),
                SizedBox(height: 12.sp),

                _buildTextFormField(
                  controller: _notesController,
                  label: 'receipt.general_notes'.tr(),
                  maxLines: 3,
                ),
                SizedBox(height: 12.sp),

                _buildTextFormField(
                  controller: _fiscalNotesController,
                  label: 'receipt.fiscal_notes'.tr(),
                  maxLines: 2,
                  hintText: 'italian_receipt.vat_exempt_hint'.tr(),
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
                        child: Text('common.cancel'.tr()),
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
                        child: widget.isLoading
                            ? SizedBox(
                                height: 20.sp,
                                width: 20.sp,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('receipt.create_receipt'.tr()),
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

  Widget _buildInfoCard(String title, List<String> items) {
    return Container(
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.sp),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 8.sp),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 4.sp),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16.sp,
                    color: Colors.blue.shade600,
                  ),
                  SizedBox(width: 8.sp),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
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
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    String? hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
      isExpanded: true,
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
              : 'common.select_date'.tr(),
          style: TextStyle(
            color: selectedDate != null ? null : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
