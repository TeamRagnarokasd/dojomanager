import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _eur(double v) => '€${v.toStringAsFixed(2).replaceAll('.', ',')}';

/// Black Friday: se per il piano mensile scelto esiste la versione
/// "3 mesi pagati in una volta con -20%" ancora valida, chiede all'utente
/// quale vuole. `cancelled` = ha chiuso la finestra (nessun acquisto);
/// `promo` = riga del piano 3 mesi (null = prosegue col mensile).
/// Se la promo non esiste, non è attiva o è scaduta non mostra nulla.
/// Il piano 3 mesi è una riga normale di custom_subscription_plans: prezzo,
/// durata, ricevuta e cumulo col mese in corso seguono la logica esistente.
Future<({bool cancelled, Map<String, dynamic>? promo})> offerBlackFriday(
  BuildContext context, {
  required String? planId,
  required String planName,
  required double monthlyPrice,
}) async {
  if (planId == null || planId.isEmpty) return (cancelled: false, promo: null);
  Map<String, dynamic>? row;
  try {
    row = await Supabase.instance.client
        .from('custom_subscription_plans')
        .select('id, name, amount, duration_months, promo_ends_at')
        .eq('promo_of', planId)
        .eq('is_active', true)
        .maybeSingle();
  } catch (_) {
    return (cancelled: false, promo: null);
  }
  if (row == null) return (cancelled: false, promo: null);
  final ends = DateTime.tryParse(row['promo_ends_at']?.toString() ?? '');
  if (ends != null && !ends.isAfter(DateTime.now())) {
    return (cancelled: false, promo: null);
  }
  if (!context.mounted) return (cancelled: true, promo: null);

  final promoPrice = (row['amount'] as num).toDouble();
  final fullPrice = monthlyPrice * 3;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Black Friday'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(planName, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('3 mesi pagati in una volta: ${_eur(promoPrice)} '
              'invece di ${_eur(fullPrice)} (-20%).'),
          const SizedBox(height: 8),
          const Text(
              'I 3 mesi si aggiungono al mese già in corso e durano dalla data di acquisto.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'monthly'),
          child: Text('Solo 1 mese (${_eur(monthlyPrice)})'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, 'promo'),
          child: Text('3 mesi (${_eur(promoPrice)})'),
        ),
      ],
    ),
  );
  if (choice == null) return (cancelled: true, promo: null);
  return (cancelled: false, promo: choice == 'promo' ? row : null);
}
