import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/receipt_model.dart';

class ReceiptCardWidget extends StatelessWidget {
  final ReceiptModel receipt;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const ReceiptCardWidget({
    Key? key,
    required this.receipt,
    required this.onTap,
    required this.onDownload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 1.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomIconWidget(
                      iconName: 'receipt_long',
                      color: _getStatusColor(),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ricevuta #${receipt.receiptNumber}',
                              style: AppTheme.lightTheme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: _getPaymentMethodColor()
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _getPaymentMethodColor()
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _getPaymentMethodText(),
                                style: AppTheme.lightTheme.textTheme.labelSmall
                                    ?.copyWith(
                                  color: _getPaymentMethodColor(),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          DateFormat('dd/MM/yyyy').format(receipt.issueDate),
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme
                                .lightTheme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                receipt.description,
                style: AppTheme.lightTheme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 1.h),
              if (receipt.validityStart != null && receipt.validityEnd != null)
                Text(
                  'Validità: ${DateFormat('dd/MM/yyyy').format(receipt.validityStart!)} - ${DateFormat('dd/MM/yyyy').format(receipt.validityEnd!)}',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Text(
                    '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.lightTheme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDownload,
                    icon: CustomIconWidget(
                      iconName: 'download',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 16,
                    ),
                    label: Text(
                      'Scarica',
                      style:
                          AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                      backgroundColor:
                          AppTheme.lightTheme.colorScheme.primaryContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (receipt.status) {
      case 'issued':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentMethodColor() {
    switch (receipt.paymentMethod.toLowerCase()) {
      case 'sumup':
        return const Color(0xFF2196F3);
      case 'satispay':
        return const Color(0xFFFF5722);
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'bank_transfer':
        return const Color(0xFF9C27B0);
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodText() {
    switch (receipt.paymentMethod.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'Satispay';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico';
      default:
        return receipt.paymentMethod.toUpperCase();
    }
  }
}
