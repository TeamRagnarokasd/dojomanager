import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _shownThisLaunch = false;

/// Annuncio Black Friday all'apertura dell'app (una volta per avvio, solo
/// finché la promo esiste ed è attiva nel database e non è scaduta).
Future<void> maybeShowBlackFridayAnnouncement(BuildContext context) async {
  if (_shownThisLaunch) return;
  try {
    final rows = await Supabase.instance.client
        .from('custom_subscription_plans')
        .select('promo_ends_at')
        .not('promo_of', 'is', null)
        .eq('is_active', true)
        .limit(1);
    if ((rows as List).isEmpty) return;
    final ends = DateTime.tryParse(
        (rows.first as Map)['promo_ends_at']?.toString() ?? '');
    if (ends != null && !ends.isAfter(DateTime.now())) return;
  } catch (_) {
    return;
  }
  if (!context.mounted || _shownThisLaunch) return;
  _shownThisLaunch = true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Black Friday'),
      content: const Text(
        'Fino al 28 novembre, in Pagamenti, puoi attivare 3 mesi di abbonamento in una volta '
        'con il 20% di sconto rispetto al prezzo mensile. I 3 mesi si '
        'aggiungono al mese già in corso.',
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Ho capito'),
        ),
      ],
    ),
  );
}
