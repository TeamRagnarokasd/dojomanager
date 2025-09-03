import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class QuickBookingFabWidget extends StatelessWidget {
  final VoidCallback onPressed;

  const QuickBookingFabWidget({Key? key, required this.onPressed})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: theme.colorScheme.secondary,
      foregroundColor: theme.colorScheme.onSecondary,
      elevation: 4.0,
      icon: CustomIconWidget(
        iconName: 'add',
        color: theme.colorScheme.onSecondary,
        size: 24,
      ),
      label: Text(
        'Prenotazione Rapida',
        style: theme.textTheme.labelLarge!.copyWith(
          color: theme.colorScheme.onSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
