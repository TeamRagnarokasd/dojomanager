import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/receipt_model.dart';

class ReceiptListWidget extends StatefulWidget {
  final List<ItalianReceiptModel> receipts;
  final Function(ItalianReceiptModel) onReceiptTap;
  final Function(ItalianReceiptModel) onGeneratePdf;
  final VoidCallback onRefresh;

  const ReceiptListWidget({
    Key? key,
    required this.receipts,
    required this.onReceiptTap,
    required this.onGeneratePdf,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<ReceiptListWidget> createState() => _ReceiptListWidgetState();
}

class _ReceiptListWidgetState extends State<ReceiptListWidget> {
  String _searchQuery = '';
  String _selectedPaymentMethod = 'all';

  final Map<String, String> _paymentMethodFilters = {
    'all': 'Tutti i metodi',
    'cash': 'Contanti',
    'satispay': 'Satispay',
    'sumup': 'SumUp',
    'bank_transfer': 'Bonifico Bancario',
    'credit_card': 'Carta di Credito',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      child: Column(
        children: [
          // Filters
          _buildFilters(),
          SizedBox(height: 16.sp),

          // Statistics Card
          _buildStatisticsCard(),
          SizedBox(height: 16.sp),

          // Receipts List
          Expanded(
            child:
                _filteredReceipts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: () async => widget.onRefresh(),
                      child: ListView.builder(
                        itemCount: _filteredReceipts.length,
                        itemBuilder: (context, index) {
                          final receipt = _filteredReceipts[index];
                          return _buildReceiptCard(receipt);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        // Search bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Cerca per cliente o numero ricevuta...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.sp),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.sp),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.sp),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        SizedBox(height: 12.sp),

        // Payment method filter
        DropdownButtonFormField<String>(
          value: _selectedPaymentMethod,
          decoration: InputDecoration(
            labelText: 'Filtra per metodo di pagamento',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.sp),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.sp),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.sp),
              borderSide: BorderSide(color: Theme.of(context).primaryColor),
            ),
          ),
          items:
              _paymentMethodFilters.entries
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

  Widget _buildStatisticsCard() {
    final totalAmount = _filteredReceipts.fold<double>(
      0,
      (sum, receipt) => sum + receipt.amount,
    );

    final totalVat = _filteredReceipts.fold<double>(
      0,
      (sum, receipt) => sum + receipt.vatAmount,
    );

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
                    _filteredReceipts.length.toString(),
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
            borderRadius: BorderRadius.circular(8.sp),
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
    return Card(
      margin: EdgeInsets.only(bottom: 12.sp),
      elevation: 2,
      child: InkWell(
        onTap: () => widget.onReceiptTap(receipt),
        borderRadius: BorderRadius.circular(8.sp),
        child: Padding(
          padding: EdgeInsets.all(16.sp),
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
                  const Spacer(),

                  // PDF Button
                  IconButton(
                    onPressed: () => widget.onGeneratePdf(receipt),
                    icon: const Icon(Icons.picture_as_pdf),
                    color: Colors.red.shade600,
                    tooltip: 'Genera PDF',
                  ),
                ],
              ),

              if (receipt.description.isNotEmpty) ...[
                SizedBox(height: 8.sp),
                Container(
                  padding: EdgeInsets.all(8.sp),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6.sp),
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
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 4.sp),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12.sp),
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
            'Nessuna ricevuta trovata',
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
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );
  }
}
