import 'package:supabase_flutter/supabase_flutter.dart';

/// Una sede salvata per la "Carta intestata" (vedi
/// lib/presentation/letterhead/letterhead_screen.dart) — un'alternativa
/// all'indirizzo della sede legale usata nell'intestazione, nel piè di
/// pagina e nella frase del legale rappresentante. Codice fiscale,
/// telefono ed email dell'ASD restano sempre quelli reali.
class AsdLetterheadAddress {
  const AsdLetterheadAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String address;
  final int sortOrder;

  factory AsdLetterheadAddress.fromMap(Map<String, dynamic> map) =>
      AsdLetterheadAddress(
        id: map['id'] as String,
        label: map['label'] as String? ?? '',
        address: map['address'] as String? ?? '',
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}

class AsdLetterheadService {
  AsdLetterheadService._();
  static final AsdLetterheadService instance = AsdLetterheadService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'asd_letterhead_addresses';

  Future<List<AsdLetterheadAddress>> getAddresses() async {
    final rows = await _client
        .from(_table)
        .select('id, label, address, sort_order')
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((row) => AsdLetterheadAddress.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Inserisce una nuova sede. [sortOrder] di default la mette in coda
  /// rispetto alle sedi già salvate (il chiamante passa il valore
  /// successivo al massimo già visto, così non compare prima di "Russi
  /// (RA)" che oggi ha sort_order 1).
  Future<AsdLetterheadAddress> addAddress({
    required String label,
    required String address,
    int sortOrder = 1,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'label': label,
          'address': address,
          'sort_order': sortOrder,
        })
        .select('id, label, address, sort_order')
        .single();
    return AsdLetterheadAddress.fromMap(row);
  }

  Future<void> deleteAddress(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
