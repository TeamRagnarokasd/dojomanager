import 'dart:io' as io if (dart.library.html) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/app_export.dart';
import '../../services/child_profile_service.dart';
import '../../services/italian_receipt_service.dart';
import '../../services/payment_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/empty_payment_state.dart';
import './widgets/monthly_group_header.dart';
import './widgets/payment_confirmation_dialog.dart';
import './widgets/payment_filter_chips.dart';
import './widgets/payment_search_bar.dart';
import './widgets/payment_transaction_card.dart';
import './widgets/subscription_plans_widget.dart';
import './widgets/subscription_status_card.dart';
import './widgets/sumup_payment_options_widget.dart';

class PaymentHistory extends StatefulWidget {
  const PaymentHistory({Key? key}) : super(key: key);

  @override
  State<PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<PaymentHistory>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = false;
  bool _isOfflineMode = false;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final Map<String, bool> _expandedMonths = {};
  Map<String, dynamic>? _selectedPlan;

  // Replace mock data with real data from Supabase
  Map<String, dynamic> _subscriptionData = {};
  List<Map<String, dynamic>> _paymentTransactions = [];

  static const List<String> _filterKeys = [
    'all',
    'Abbonamento',
    'Classe Singola',
  ];

  List<String> get _filterOptions =>
      _filterKeys.map((key) => _paymentFilterLabel(key)).toList();

  String _paymentFilterLabel(String key) {
    switch (key) {
      case 'all':
        return 'disciplines.all'.tr();
      case 'Abbonamento':
        return 'payment.filter_subscription'.tr();
      case 'Classe Singola':
        return 'payment.filter_single_class'.tr();
      default:
        return key;
    }
  }

  String _filterKeyFromLabel(String label) {
    for (final key in _filterKeys) {
      if (_paymentFilterLabel(key) == label) return key;
    }
    return label;
  }

  // 🎨 FIX 2: Replace ugly text PDF with beautiful graphic PDF
  Map<String, bool> _isLoadingPDF = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _loadPaymentData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // 🔥 CRITICAL FIX: Force complete data refresh when app resumes
      _checkPaymentConfirmation();
      // 🔥 CRITICAL FIX 2: Also reload payment data to sync with database
      _loadPaymentData();
    }
  }

  Future<void> _checkPaymentConfirmation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPaymentPending = prefs.getBool('isPaymentPending') ?? false;

      if (isPaymentPending) {
        // Clear flag to prevent duplicate dialogs
        await prefs.setBool('isPaymentPending', false);

        // Get pending payment data
        final planId = prefs.getString('pendingPlanId');
        final planTitle = prefs.getString('pendingPlanTitle');
        final planAmount = prefs.getDouble('pendingPlanAmount');
        final paymentMethod =
            prefs.getString('pendingPaymentMethod') ?? 'sumup';

        // 🎯 FIX: Show dialog for both SumUp (with planId) and Satispay (without planId)
        if (mounted) {
          // Show confirmation dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => PaymentConfirmationDialog(
              planData: {
                'plan_id': planId,
                'plan_title': planTitle,
                'amount': planAmount,
                'payment_method': paymentMethod,
              },
              onConfirmed: () {
                // 🔥 TRIGGER AGGIORNAMENTO: Refresh payment data immediately after confirmation
                _loadPaymentData();
              },
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail - don't disrupt user experience
      print('ERROR checking payment confirmation: $e');
    }
  }

  void _initializeExpandedMonths() {
    final months = _getUniqueMonths();
    for (String month in months) {
      _expandedMonths[month] = true;
    }
  }

  List<String> _getUniqueMonths() {
    final months = <String>{};
    for (var transaction in _getFilteredTransactions()) {
      months.add(transaction['month'] as String);
    }
    return months.toList()..sort((a, b) => _compareMonths(b, a));
  }

  int _compareMonths(String a, String b) {
    final monthsMap = {
      'Gennaio': 1,
      'Febbraio': 2,
      'Marzo': 3,
      'Aprile': 4,
      'Maggio': 5,
      'Giugno': 6,
      'Luglio': 7,
      'Agosto': 8,
      'Settembre': 9,
      'Ottobre': 10,
      'Novembre': 11,
      'Dicembre': 12,
    };

    final aParts = a.split(' ');
    final bParts = b.split(' ');

    final aYear = int.parse(aParts[1]);
    final bYear = int.parse(bParts[1]);

    if (aYear != bYear) return aYear.compareTo(bYear);

    final aMonth = monthsMap[aParts[0]] ?? 0;
    final bMonth = monthsMap[bParts[0]] ?? 0;

    return aMonth.compareTo(bMonth);
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    var filtered = _paymentTransactions.where((transaction) {
      final matchesFilter =
          _selectedFilter == 'all' ||
          (transaction['type'] as String) == _selectedFilter;

      final matchesSearch =
          _searchQuery.isEmpty ||
          (transaction['description'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (transaction['amount'] as String).toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _parseDate(a['date'] as String);
      final bDate = _parseDate(b['date'] as String);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  List<Map<String, dynamic>> _getTransactionsForMonth(String month) {
    return _getFilteredTransactions()
        .where((transaction) => (transaction['month'] as String) == month)
        .toList();
  }

  String _calculateMonthTotal(String month) {
    final transactions = _getTransactionsForMonth(month);
    double total = 0;

    for (var transaction in transactions) {
      if ((transaction['status'] as String) == 'completato') {
        final amountStr = (transaction['amount'] as String)
            .replaceAll('€', '')
            .replaceAll(',', '.');
        total += double.tryParse(amountStr) ?? 0;
      }
    }

    return '€${total.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _loadPaymentData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // 🔥 ACTIVE PROFILE FIX: pass the active profile ID so the dashboard
      // data reflects the currently active profile (child or adult), not
      // always the adult payer.
      final activeProfileId = ChildProfileService.getActiveUserId();
      final dashboardData = await PaymentService.getSubscriptionDashboardData(
        activeProfileId,
      );
      final transactions = await PaymentService.getPaymentTransactions();

      if (!mounted) return;
      setState(() {
        _subscriptionData = dashboardData;
        _paymentTransactions = transactions;
        _isLoading = false;
        _isOfflineMode = false;
      });

      _initializeExpandedMonths();

      print('DEBUG: Dashboard data refreshed from database');
      print(
        'DEBUG: Annual Registration Status: ${dashboardData['annualRegistrationStatus']}',
      );
      print('DEBUG: Current Plan: ${dashboardData['currentPlanName']}');
      print(
        'DEBUG: Has Annual Registration: ${dashboardData['hasAnnualRegistration']}',
      );
      print(
        'DEBUG: Active Subscription: ${dashboardData['hasActiveSubscription']}',
      );
    } catch (e) {
      print('ERROR loading payment data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOfflineMode = true;
        _subscriptionData = {
          "currentPlanName": "Nessun abbonamento attivo",
          "planName": "",
          "renewalDate": "",
          "autoPayment": false,
          "status": "inactive",
          "annualRegistrationStatus": "Da acquistare",
          "annualRegistrationExpiry": "",
          "hasAnnualRegistration": false,
          "hasActiveSubscription": false,
        };
        _paymentTransactions = [];
      });
    }
  }

  Future<void> _refreshPaymentData() async {
    HapticFeedback.lightImpact();

    // 🔥 TRIGGER AGGIORNAMENTO: Force data reload from database
    await _loadPaymentData();

    Fluttertoast.showToast(
      msg: 'payment.refreshed'.tr(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _onFilterChanged(String filterLabel) {
    setState(() {
      _selectedFilter = _filterKeyFromLabel(filterLabel);
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onSearchClear() {
    setState(() {
      _searchQuery = '';
    });
  }

  void _toggleMonthExpansion(String month) {
    setState(() {
      _expandedMonths[month] = !(_expandedMonths[month] ?? false);
    });
  }

  void _onTransactionTap(Map<String, dynamic> transaction) {
    _showTransactionDetails(transaction);
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTransactionDetailsSheet(transaction),
    );
  }

  Widget _buildTransactionDetailsSheet(Map<String, dynamic> transaction) {
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 12.w,
            height: 0.5.h,
            margin: EdgeInsets.symmetric(vertical: 2.h),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.all(6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'payment.transaction_details'.tr(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadReceipt(transaction),
                      icon: CustomIconWidget(
                        iconName: 'download',
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                      label: Text(
                        'payment.download_receipt_pdf'.tr(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  _buildDetailRow(
                    'common.description'.tr(),
                    transaction['description'] as String,
                  ),
                  _buildDetailRow(
                    'payment.amount'.tr(),
                    transaction['amount'] as String,
                  ),
                  _buildDetailRow(
                    'class_schedule.date'.tr(),
                    transaction['date'] as String,
                  ),
                  _buildDetailRow(
                    'payment.status'.tr(),
                    transaction['status'] as String,
                  ),
                  _buildDetailRow(
                    'payment.payment_method'.tr(),
                    transaction['paymentMethod'] as String,
                  ),
                  _buildDetailRow(
                    'payment.receipt_id'.tr(),
                    transaction['receiptId'] as String,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent background
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 35.w,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 FIX 3: Transform payment_confirmation data into receipt format
  Future<Map<String, dynamic>> _transformPaymentToReceipt(
    Map<String, dynamic> payment,
  ) async {
    // Get current user profile for customer info
    final userId = payment['user_id'];
    final userProfile = await SupabaseService.instance.client
        .from('user_profiles')
        .select('full_name, codice_fiscale, address_line, city, province, cap')
        .eq('id', userId)
        .single();

    // Build customer address
    final addressParts = <String>[];
    if (userProfile['address_line'] != null) {
      addressParts.add(userProfile['address_line']);
    }
    if (userProfile['city'] != null) {
      addressParts.add(userProfile['city']);
    }
    if (userProfile['province'] != null) {
      addressParts.add(userProfile['province']);
    }
    if (userProfile['cap'] != null) {
      addressParts.add(userProfile['cap']);
    }

    return {
      'id': payment['id'],
      'receipt_number':
          payment['external_payment_id'] ??
          'PAY-${payment['id'].substring(0, 8)}',
      'issue_date':
          payment['created_at']?.split('T')[0] ??
          DateTime.now().toIso8601String().split('T')[0],
      'customer_name': userProfile['full_name'] ?? 'payment.customer'.tr(),
      'customer_tax_code': userProfile['codice_fiscale'],
      'customer_address': addressParts.isNotEmpty
          ? addressParts.join(', ')
          : null,
      'description': 'payment.subscription_payment_desc'.tr(
        namedArgs: {'method': _getPaymentMethodText(payment['payment_method'])},
      ),
      'amount': payment['amount'],
      'quantity': 1,
      'unit_price': payment['amount'],
      'payment_method': payment['payment_method'],
      'status': 'issued',
      'vat_rate': '0',
      'vat_amount': 0.0,
      'discount_percentage': 0.0,
      'created_at': payment['created_at'],
      'created_by': userId,
    };
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'sumup':
        return 'payment.sumup'.tr();
      case 'satispay':
        return 'payment.satispay'.tr();
      case 'cash':
        return 'payment.cash'.tr();
      case 'bank_transfer':
        return 'payment.bank_transfer_full'.tr();
      case 'credit_card':
        return 'payment.credit_card'.tr();
      default:
        return method;
    }
  }

  Future<void> _downloadReceipt(Map<String, dynamic> transaction) async {
    // 🎯 FIX: Use EXACT SAME PDF generator as Admin Panel
    String? receiptIdKey = transaction['receiptId']?.toString();

    try {
      setState(() {
        _isLoadingPDF[receiptIdKey ?? transaction['id']] = true;
      });

      // 🔥 STEP 1: Get the receipt ID - if from payment_confirmation, create receipt first
      String? receiptId = transaction['receiptId'] as String?;

      // Handle case where receiptId might be a placeholder (e.g., "PAY-xxxxx")
      if (receiptId == null ||
          receiptId.isEmpty ||
          receiptId.startsWith('PAY-')) {
        // If this is from payment_confirmation source, try to create/get receipt
        if (transaction['source'] == 'payment_confirmation') {
          try {
            final paymentId = transaction['id'] as String?;
            if (paymentId == null || paymentId.isEmpty) {
              throw Exception('payment.invalid_transaction_id'.tr());
            }

            receiptId = await PaymentService.getReceiptIdForPayment(paymentId);

            if (receiptId == null || receiptId.isEmpty) {
              throw Exception('payment.receipt_create_failed'.tr());
            }
          } catch (e) {
            throw Exception(
              'payment.receipt_create_error'.tr(
                namedArgs: {'detail': e.toString()},
              ),
            );
          }
        } else {
          throw Exception('payment.receipt_id_not_found'.tr());
        }
      }

      // If receiptId was a placeholder, we should have created one by now
      if (receiptId.isEmpty) {
        throw Exception('payment.invalid_receipt_id'.tr());
      }

      // 🔥 STEP 2: Get receipt with organization info from ItalianReceiptService
      Map<String, dynamic>? receiptData;
      try {
        receiptData = await ItalianReceiptService().getReceiptById(receiptId);
      } catch (e) {
        throw Exception(
          'payment.receipt_fetch_error'.tr(namedArgs: {'detail': e.toString()}),
        );
      }

      if (receiptData == null) {
        throw Exception('payment.receipt_not_found_db'.tr());
      }

      // 🔥 STEP 3: Generate BEAUTIFUL PDF using ItalianReceiptService
      pw.Document pdfDocument;
      try {
        pdfDocument = await ItalianReceiptService().generateBeautifulReceiptPDF(
          receiptData,
        );
      } catch (e) {
        throw Exception(
          'payment.pdf_generate_error'.tr(namedArgs: {'detail': e.toString()}),
        );
      }

      // 🔥 STEP 4: Save/Download the PDF
      Uint8List pdfBytes;
      try {
        pdfBytes = await pdfDocument.save();
      } catch (e) {
        throw Exception(
          'payment.pdf_save_error'.tr(namedArgs: {'detail': e.toString()}),
        );
      }

      final receiptNumber =
          (receiptData['receipt_number']?.toString() ??
              receiptData['id']?.toString().substring(0, 8) ??
              'ricevuta')
          .replaceAll('/', '_')
          .replaceAll('\\', '_');
      final filename = 'ricevuta_$receiptNumber.pdf';

      try {
        if (kIsWeb) {
          // Web: Enhanced download trigger with better browser support
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = filename;

          html.document.body?.append(anchor);
          anchor.click();
          anchor.remove();

          Future.delayed(const Duration(milliseconds: 100), () {
            html.Url.revokeObjectUrl(url);
          });

          // Safely close bottom sheet for web
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } else {
          // Mobile: Close bottom sheet FIRST so the share intent doesn't get killed
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          // Use path_provider and share_plus for reliable native sharing
          final tempDir = await getTemporaryDirectory();
          final file = io.File('${tempDir.path}/$filename');
          await file.writeAsBytes(pdfBytes);

          await Share.shareXFiles([XFile(file.path)], subject: filename);
        }

        Fluttertoast.showToast(
          msg: 'payment.pdf_downloaded'.tr(),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } catch (e) {
        throw Exception(
          'payment.download_file_error'.tr(namedArgs: {'detail': e.toString()}),
        );
      }
    } catch (e) {
      // Provide user-friendly error messages
      String errorMessage = 'payment.download_error'.tr();

      if (e.toString().contains('non trovato') ||
          e.toString().contains('not found')) {
        errorMessage = 'payment.receipt_not_found_support'.tr();
      } else if (e.toString().contains('creare') ||
          e.toString().contains('create')) {
        errorMessage = 'payment.receipt_create_failed'.tr();
      } else if (e.toString().contains('generazione') ||
          e.toString().contains('generat')) {
        errorMessage = 'payment.pdf_generate_error'.tr(
          namedArgs: {'detail': ''},
        );
      } else {
        errorMessage = '$errorMessage: ${e.toString()}';
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoadingPDF.remove(receiptIdKey);
        _isLoadingPDF.remove(transaction['id']);
      });
    }
  }

  Future<void> _shareReceipt(Map<String, dynamic> transaction) async {
    try {
      // Remove this line - _generateReceiptContent method doesn't exist
      // Instead, just copy the receipt ID or basic transaction info
      final receiptInfo = 'payment.receipt_clipboard'.tr(
        namedArgs: {
          'id': '${transaction['receiptId']}',
          'description': '${transaction['description']}',
          'amount': '${transaction['amount']}',
          'date': '${transaction['date']}',
          'status': '${transaction['status']}',
        },
      );

      await Clipboard.setData(ClipboardData(text: receiptInfo));
      Fluttertoast.showToast(
        msg: 'payment.copied_to_clipboard'.tr(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'payment.share_error'.tr(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _contactSupport(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'payment.contact_support'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'payment.contact_support_confirm'.tr(
            namedArgs: {'id': '${transaction['receiptId']}'},
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: 'payment.support_request_sent'.tr(),
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
              );
            },
            child: Text(
              'payment.contact'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAutoPaymentToggle(bool enabled) {
    setState(() {
      _subscriptionData['autoPayment'] = enabled;
    });

    Fluttertoast.showToast(
      msg: enabled ? 'payment.auto_pay_on'.tr() : 'payment.auto_pay_off'.tr(),
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _showManualPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'payment.manual_payment'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'payment.manual_payment_confirm'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/dashboard-home');
            },
            child: Text(
              'payment.proceed'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPlanSelected(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlan = plan;
    });
  }

  void _onTabChanged(int tabIndex) {
    setState(() {
      _tabController.animateTo(tabIndex);
    });
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Card(
        elevation: 2,
        color: Theme.of(context).cardColor, // Use theme card color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          color: Theme.of(
            context,
          ).cardColor, // Ensure card has consistent theme color
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 2.h,
                          width: 60.w,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Container(
                          height: 1.5.h,
                          width: 30.w,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 3.h,
                    width: 20.w,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Container(
                height: 1.5.h,
                width: 40.w,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTab() {
    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent dark background
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Show selected plan information if available
                  if (_selectedPlan != null) ...[
                    Container(
                      margin: EdgeInsets.all(4.w),
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Color(
                          _selectedPlan!['color'] as int,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(
                            _selectedPlan!['color'] as int,
                          ).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'check_circle',
                                color: Color(_selectedPlan!['color'] as int),
                                size: 24,
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Text(
                                  'payment.selected_plan'.tr(),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Color(
                                          _selectedPlan!['color'] as int,
                                        ),
                                      ),
                                ),
                              ),
                              Text(
                                '€${_selectedPlan!['price']}/${_selectedPlan!['frequency']}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Color(
                                        _selectedPlan!['color'] as int,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            _selectedPlan!['title'] as String,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SumUpPaymentOptionsWidget(),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryTab() {
    final filteredTransactions = _getFilteredTransactions();

    if (_isLoading) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SubscriptionStatusCard(
                    subscriptionData: _subscriptionData,
                    onAutoPaymentToggle: _onAutoPaymentToggle,
                  ),
                  PaymentFilterChips(
                    filterOptions: _filterOptions,
                    selectedFilter: _paymentFilterLabel(_selectedFilter),
                    onFilterChanged: _onFilterChanged,
                  ),
                  PaymentSearchBar(
                    onSearchChanged: _onSearchChanged,
                    onClear: _onSearchClear,
                  ),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSkeletonCard(),
                childCount: 6,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 10.h)),
          ],
        ),
      );
    }

    if (filteredTransactions.isEmpty) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SubscriptionStatusCard(
                    subscriptionData: _subscriptionData,
                    onAutoPaymentToggle: _onAutoPaymentToggle,
                  ),
                  PaymentFilterChips(
                    filterOptions: _filterOptions,
                    selectedFilter: _paymentFilterLabel(_selectedFilter),
                    onFilterChanged: _onFilterChanged,
                  ),
                  PaymentSearchBar(
                    onSearchChanged: _onSearchChanged,
                    onClear: _onSearchClear,
                  ),
                ],
              ),
            ),
            SliverFillRemaining(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: EmptyPaymentState(
                  onButtonPressed: () =>
                      Navigator.pushNamed(context, '/class-schedule'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final months = _getUniqueMonths();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshPaymentData,
        color: Theme.of(context).colorScheme.secondary,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    SubscriptionStatusCard(
                      subscriptionData: _subscriptionData,
                      onAutoPaymentToggle: _onAutoPaymentToggle,
                    ),
                    PaymentFilterChips(
                      filterOptions: _filterOptions,
                      selectedFilter: _paymentFilterLabel(_selectedFilter),
                      onFilterChanged: _onFilterChanged,
                    ),
                    PaymentSearchBar(
                      onSearchChanged: _onSearchChanged,
                      onClear: _onSearchClear,
                    ),
                    if (_isOfflineMode)
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.h,
                        ),
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF39C12).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFF39C12,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'wifi_off',
                              color: const Color(0xFFF39C12),
                              size: 20,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'payment.offline_mode'.tr(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: const Color(0xFFF39C12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final month = months[index];
                final monthTransactions = _getTransactionsForMonth(month);
                final isExpanded = _expandedMonths[month] ?? false;

                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      MonthlyGroupHeader(
                        monthYear: month,
                        totalAmount: _calculateMonthTotal(month),
                        transactionCount: monthTransactions.length,
                        isExpanded: isExpanded,
                        onToggle: () => _toggleMonthExpansion(month),
                      ),
                      if (isExpanded)
                        ...monthTransactions.map(
                          (transaction) => PaymentTransactionCard(
                            transaction: transaction,
                            onTap: () => _onTransactionTap(transaction),
                            onDownloadReceipt: () =>
                                _downloadReceipt(transaction),
                            onShare: () => _shareReceipt(transaction),
                            onContactSupport: () =>
                                _contactSupport(transaction),
                          ),
                        ),
                    ],
                  ),
                );
              }, childCount: months.length),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                height: 10.h,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlansTab() {
    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent dark background
      child: SubscriptionPlansWidget(
        onTabChanged: _onTabChanged,
        onPlanSelected: _onPlanSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            _tabController.index == 1
                ? 'payment.title_history'.tr()
                : 'nav.payments'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () => _refreshPaymentData(),
              icon: CustomIconWidget(
                iconName: 'refresh',
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            tabs: [
              Tab(text: 'receipt.pay_tab'.tr()),
              Tab(text: 'payment.title_history'.tr()),
              Tab(text: 'receipt.subscriptions_tab'.tr()),
            ],
          ),
        ),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaymentTab(),
              _buildPaymentHistoryTab(),
              _buildSubscriptionPlansTab(),
            ],
          ),
        ),
      ),
    );
  }
}