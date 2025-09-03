import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BulkOperationsToolbarWidget extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onBulkEdit;
  final VoidCallback onBulkDelete;
  final VoidCallback onBulkScheduleUpdate;

  const BulkOperationsToolbarWidget({
    super.key,
    required this.selectedCount,
    required this.onBulkEdit,
    required this.onBulkDelete,
    required this.onBulkScheduleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: selectedCount > 0 ? 60 : 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            // Selection count
            Text(
              '$selectedCount selezionate',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),

            const Spacer(),

            // Bulk operations buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  context,
                  Icons.edit,
                  'Modifica',
                  onBulkEdit,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  context,
                  Icons.schedule,
                  'Orari',
                  onBulkScheduleUpdate,
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  context,
                  Icons.delete,
                  'Elimina',
                  onBulkDelete,
                  isDestructive: true,
                ),
              ],
            ),

            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red.withAlpha(26)
                  : theme.colorScheme.surface.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? Colors.red
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
