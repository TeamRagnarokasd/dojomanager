import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/receipt_model.dart';
import '../../../core/app_export.dart';

class ReceiptListWidget extends StatefulWidget {
  final List<ItalianReceiptModel> receipts;
  final Function(ItalianReceiptModel) onReceiptTap;
  final Function(ItalianReceiptModel) onGeneratePdf;
  final VoidCallback onRefresh;
  final Future<void> Function(List<String> receiptIds, bool deleteSubscription)?
  onDeleteReceipts;

  const ReceiptListWidget({
    Key? key,
    required this.receipts,
    required this.onReceiptTap,
    required this.onGeneratePdf,
    required this.onRefresh,
    this.onDeleteReceipts,
  }) : super(key: key);

  @override
  State<ReceiptListWidget> createState() => _ReceiptListWidgetState();
}

class _ReceiptListWidgetState extends State<ReceiptListWidget> {
  String _searchQuery = '';
  String _selectedPaymentMethod = 'all';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;

  Map<String, String> get _paymentMethodFilters => {
    'all': 'receipt.filter_all_receipts'.tr(),
    'cash': 'payment.cash'.tr(),
    'satispay': 'payment.satispay'.tr(),
    'sumup': 'payment.sumup'.tr(),
    'bank_transfer': 'payment.bank_transfer'.tr(),
    'credit_card': 'payment.credit_card'.tr(),
  };

  List<ItalianReceiptModel> get _filteredReceipts {
    return widget.receipts.where((receipt) {
      final matchesSearch =
          receipt.customerName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          receipt.receiptNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      final matchesPaymentMethod =
          _selectedPaymentMethod == 'all' ||
          receipt.paymentMethod == _selectedPaymentMethod;
      return matchesSearch && matchesPaymentMethod;
    }).toList();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredReceipts.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredReceipts.map((r) => r.id));
      }
    });
  }

  Future<void> _showDeleteConfirmation() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Elimina ${count == 1 ? 'ricevuta' : '$count ricevute'}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cosa vuoi eliminare?',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 8.sp),
            Text(
              'Eliminando anche l\'abbonamento associato, l\'utente perderà l\'accesso alle discipline acquistate.',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'receipt_only'),
            child: Text(
              'Solo ricevuta',
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, 'receipt_and_subscription'),
            child: Text(
              'Ricevuta + abbonamento',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == null) return;

    final deleteSubscription = result == 'receipt_and_subscription';
    final idsToDelete = List<String>.from(_selectedIds);

    setState(() => _isDeleting = true);
    try {
      if (widget.onDeleteReceipts != null) {
        await widget.onDeleteReceipts!(idsToDelete, deleteSubscription);
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleteSubscription
                  ? '${count == 1 ? 'Ricevuta' : '$count ricevute'} e abbonamento eliminati'
                  : '${count == 1 ? 'Ricevuta eliminata' : '$count ricevute eliminate'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'eliminazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReceipts;
    final totalAmount = filtered.fold<double>(0, (s, r) => s + r.amount);
    final totalVat = filtered.fold<double>(0, (s, r) => s + r.vatAmount);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.sp, 16.sp, 16.sp, 0),
                child: Column(
                  children: [
                    // Selection mode toolbar
                    if (_isSelectionMode) ...[
                      _buildSelectionToolbar(filtered),
                      SizedBox(height: 12.sp),
                    ],
                    // Filters
                    _buildFilters(),
                    SizedBox(height: 16.sp),
                    // Statistics Card
                    _buildStatisticsCard(filtered, totalAmount, totalVat),
                    SizedBox(height: 16.sp),
                  ],
                ),
              ),
            ),
            filtered.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState())
                : SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16.sp,
                      0,
                      16.sp,
                      MediaQuery.of(context).viewPadding.bottom + 100.sp,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildReceiptCard(filtered[index]),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
          ],
        ),
        // FAB for selection mode toggle
        Positioned(
          bottom: MediaQuery.of(context).viewPadding.bottom + 16.sp,
          right: 16.sp,
          child: _isSelectionMode
              ? FloatingActionButton.extended(
                  onPressed: _isDeleting ? null : _showDeleteConfirmation,
                  backgroundColor: _selectedIds.isEmpty
                      ? Colors.grey
                      : Colors.red,
                  icon: _isDeleting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.delete, color: Colors.white),
                  label: Text(
                    _selectedIds.isEmpty
                        ? 'Seleziona ricevute'
                        : 'Elimina (${_selectedIds.length})',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : FloatingActionButton(
                  onPressed: _toggleSelectionMode,
                  backgroundColor: Colors.blueGrey.shade700,
                  mini: true,
                  child: Icon(Icons.checklist, color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildSelectionToolbar(List<ItalianReceiptModel> filtered) {
    final allSelected =
        _selectedIds.length == filtered.length && filtered.isNotEmpty;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            tristate: _selectedIds.isNotEmpty && !allSelected,
            onChanged: (_) => _selectAll(),
            activeColor: Colors.white,
            checkColor: Colors.blueGrey.shade800,
          ),
          Expanded(
            child: Text(
              _selectedIds.isEmpty
                  ? 'Seleziona ricevute'
                  : '${_selectedIds.length} selezionat${_selectedIds.length == 1 ? 'a' : 'e'}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ),
          TextButton(
            onPressed: _toggleSelectionMode,
            child: Text('Annulla', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Cerca per cliente o numero ricevuta...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        SizedBox(height: 12.sp),
        DropdownButtonFormField<String>(
          initialValue: _selectedPaymentMethod,
          decoration: InputDecoration(
            labelText: 'Filtra per metodo di pagamento',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          items: _paymentMethodFilters.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard(
    List<ItalianReceiptModel> filtered,
    double totalAmount,
    double totalVat,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16.sp),
        child: Column(
          children: [
            Text(
              'Statistiche Ricevute',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.sp),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Totale Ricevute',
                    filtered.length.toString(),
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Importo Totale',
                    '€${totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                    Icons.euro,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'IVA Totale',
                    '€${totalVat.toStringAsFixed(2).replaceAll('.', ',')}',
                    Icons.percent,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8.sp),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: color, size: 20.sp),
        ),
        SizedBox(height: 8.sp),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.sp),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildReceiptCard(ItalianReceiptModel receipt) {
    final isSelected = _selectedIds.contains(receipt.id);
    return Card(
      margin: EdgeInsets.only(bottom: 12.sp),
      elevation: 2,
      color: isSelected ? Colors.blueGrey.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: isSelected
            ? BorderSide(color: Colors.blueGrey.shade400, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(receipt.id);
          } else {
            widget.onReceiptTap(receipt);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() => _isSelectionMode = true);
          }
          _toggleSelection(receipt.id);
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: EdgeInsets.all(16.sp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(receipt.id),
                  activeColor: Colors.blueGrey.shade700,
                ),
                SizedBox(width: 4.sp),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receipt.receiptNumber,
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.sp),
                              Text(
                                receipt.customerName,
                                style: GoogleFonts.inter(fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '€${receipt.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: GoogleFonts.inter(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                SizedBox(height: 4.sp),
                                Text(
                                  receipt.formattedIssueDate,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 12.sp),
                            InkWell(
                              onTap: () => widget.onGeneratePdf(receipt),
                              borderRadius: BorderRadius.circular(8.0),
                              child: Container(
                                padding: EdgeInsets.all(8.sp),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red.shade600,
                                  size: 24.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 12.sp),
                    Row(
                      children: [
                        _buildInfoChip(
                          receipt.paymentMethodText,
                          Icons.payment,
                          Colors.blue,
                        ),
                        SizedBox(width: 8.sp),
                        _buildInfoChip(
                          'IVA ${receipt.vatRate}%',
                          Icons.percent,
                          Colors.orange,
                        ),
                      ],
                    ),
                    if (receipt.description.isNotEmpty) ...[
                      SizedBox(height: 8.sp),
                      Container(
                        padding: EdgeInsets.all(8.sp),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description,
                              size: 14.sp,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 8.sp),
                            Expanded(
                              child: Text(
                                receipt.description,
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 4.sp),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 4.sp),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64.sp, color: Colors.grey.shade400),
          SizedBox(height: 16.sp),
          Text(
            'receipt.no_receipts_found'.tr(),
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.sp),
          Text(
            _searchQuery.isNotEmpty || _selectedPaymentMethod != 'all'
                ? 'Prova a modificare i filtri di ricerca'
                : 'Crea la tua prima ricevuta fiscale',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.sp),
          ElevatedButton(
            onPressed: widget.onRefresh,
            child: Text('italian_receipt.refresh'.tr()),
          ),
        ],
      ),
    );
  }
}
