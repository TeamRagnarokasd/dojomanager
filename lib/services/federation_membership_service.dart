import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Federation keys tracked in `user_federation_memberships` and
/// `asd_deadlines.federation`, with their display labels.
const Map<String, String> kFederationFullLabels = {
  'federkombat': 'Federkombat',
  'fijlkam': 'FIJLKAM',
  'asc_bjj_italia': 'ASC-BJJ Italia',
};

/// Short badge label for a membership row (e.g. "FK #123").
const Map<String, String> kFederationShortLabels = {
  'federkombat': 'FK',
  'fijlkam': 'FIJLKAM',
  'asc_bjj_italia': 'ASC/BJJ Italia',
};

String federationFullLabel(String key) => kFederationFullLabels[key] ?? key;

String federationShortLabel(String key) => kFederationShortLabels[key] ?? key;

/// The two document labels a federation-affiliation deadline requires.
const String kFederationCertificateLabel = 'Certificato di affiliazione';
const String kFederationRosterLabel = 'Elenco tesserati (Excel)';

/// One row of `user_federation_memberships`.
class FederationMembership {
  const FederationMembership({
    required this.userId,
    required this.federation,
    this.cardNumber,
    required this.updatedAt,
    required this.source,
    this.importedFromDocumentId,
  });

  final String userId;
  final String federation;
  final String? cardNumber;
  final DateTime updatedAt;
  final String source;
  final String? importedFromDocumentId;

  factory FederationMembership.fromMap(Map<String, dynamic> map) =>
      FederationMembership(
        userId: map['user_id'] as String,
        federation: map['federation'] as String,
        cardNumber: map['card_number'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
        source: map['source'] as String? ?? '',
        importedFromDocumentId: map['imported_from_document_id'] as String?,
      );
}

/// Result of `admin_sync_federation_roster`.
class FederationRosterSyncResult {
  const FederationRosterSyncResult({required this.matched, required this.notFound});

  final int matched;
  final List<String> notFound;

  factory FederationRosterSyncResult.fromMap(Map<String, dynamic> map) =>
      FederationRosterSyncResult(
        matched: (map['matched'] as num?)?.toInt() ?? 0,
        notFound: ((map['not_found'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Thrown by [parseFederationRosterExcel] when the expected columns (Codice
/// Fiscale / numero tessera) can't be found in the sheet.
class FederationRosterColumnsNotFoundException implements Exception {
  const FederationRosterColumnsNotFoundException();
}

/// Client for `user_federation_memberships` and the
/// `admin_sync_federation_roster` RPC. Additive and isolated: touches only
/// this table and RPC — nothing here changes payments, bookings,
/// subscriptions, receipts or the Registro di Cassa. RLS already scopes
/// reads/writes (admin: all rows; student: only their own).
class FederationMembershipService {
  FederationMembershipService._();
  static final FederationMembershipService instance = FederationMembershipService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'user_federation_memberships';
  static const List<String> _selectColumns = [
    'user_id',
    'federation',
    'card_number',
    'updated_at',
    'source',
    'imported_from_document_id',
  ];

  /// Every membership row for [userIds], in one query (admin-only via RLS).
  Future<List<FederationMembership>> getMembershipsForUsers(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const [];
    final rows = await _client
        .from(_table)
        .select(_selectColumns.join(', '))
        .inFilter('user_id', userIds);
    return (rows as List)
        .map((row) => FederationMembership.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// The current user's own memberships — RLS already limits this to their
  /// own rows.
  Future<List<FederationMembership>> getMyMemberships() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from(_table)
        .select(_selectColumns.join(', '))
        .eq('user_id', userId);
    return (rows as List)
        .map((row) => FederationMembership.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Upserts [rows] (one per person: {"codice_fiscale": ..., "numero_tessera":
  /// ...}) for [federation], tagging the sync with [documentId].
  Future<FederationRosterSyncResult> syncRoster({
    required String federation,
    required List<Map<String, String>> rows,
    required String documentId,
  }) async {
    final result = await _client.rpc('admin_sync_federation_roster', params: {
      'p_federation': federation,
      'p_rows': rows,
      'p_document_id': documentId,
    });
    return FederationRosterSyncResult.fromMap((result as Map).cast<String, dynamic>());
  }
}

String _reduceHeader(String raw) =>
    raw.replaceAll(RegExp(r'[\s.]'), '').toLowerCase();

/// A cell's plain text, however Excel stored it. TextCellValue wraps a
/// TextSpan whose own toString() isn't the raw text (it's a diagnostics
/// dump), so it needs its `.text` pulled out directly; every other
/// CellValue variant already has a clean toString().
String? _cellText(xlsx.CellValue? value) {
  if (value == null) return null;
  if (value is xlsx.TextCellValue) return value.value.text;
  return value.toString();
}

/// Parses a Federkombat-style roster export (also used, same logic, for
/// FIJLKAM and ASC/BJJ Italia): many columns, one row per discipline per
/// person, only "Codice Fiscale" and the card-number column matter. The
/// real header row isn't always the first one — some exports put a title
/// (e.g. "Estrazione tesserati") on row 1 and the actual column headers on
/// row 2 — so the first 5 rows are scanned for the one that has a "Codice
/// Fiscale" cell. Groups by codice fiscale and returns one row per person
/// (first card number found for that person). Throws
/// [FederationRosterColumnsNotFoundException] if no header row with the
/// expected columns can be located, or the file has no readable sheet.
List<Map<String, String>> parseFederationRosterExcel(Uint8List bytes) {
  final workbook = xlsx.Excel.decodeBytes(bytes);
  if (workbook.tables.isEmpty) {
    throw const FederationRosterColumnsNotFoundException();
  }
  final sheet = workbook.tables[workbook.tables.keys.first]!;
  final rows = sheet.rows;
  if (rows.isEmpty) {
    throw const FederationRosterColumnsNotFoundException();
  }

  int? headerRowIndex;
  final rowsToScan = rows.length < 5 ? rows.length : 5;
  for (var r = 0; r < rowsToScan; r++) {
    final hasCodiceFiscale = rows[r].any((cell) {
      return _reduceHeader(_cellText(cell?.value) ?? '') == 'codicefiscale';
    });
    if (hasCodiceFiscale) {
      headerRowIndex = r;
      break;
    }
  }
  if (headerRowIndex == null) {
    throw const FederationRosterColumnsNotFoundException();
  }

  final headerRow = rows[headerRowIndex];
  int? cfColumnIndex;
  int? tesseraColumnIndex;

  for (var i = 0; i < headerRow.length; i++) {
    final raw = _cellText(headerRow[i]?.value) ?? '';
    final reduced = _reduceHeader(raw);
    if (reduced.isEmpty) continue;

    if (cfColumnIndex == null && reduced.contains('codicefiscale')) {
      cfColumnIndex = i;
    }

    if (reduced.contains('tessera') &&
        !reduced.contains('sostituita') &&
        reduced != 'tipotessera') {
      if (reduced == 'codtessera' || tesseraColumnIndex == null) {
        tesseraColumnIndex = i;
      }
    }
  }

  if (cfColumnIndex == null || tesseraColumnIndex == null) {
    throw const FederationRosterColumnsNotFoundException();
  }
  final cfIndex = cfColumnIndex;
  final tesseraIndex = tesseraColumnIndex;

  final orderedKeys = <String>[];
  final codiceFiscaleByKey = <String, String>{};
  final tesseraByKey = <String, String>{};

  for (var r = headerRowIndex + 1; r < rows.length; r++) {
    final row = rows[r];
    if (cfIndex >= row.length) continue;
    final codiceFiscale = (_cellText(row[cfIndex]?.value) ?? '').trim();
    if (codiceFiscale.isEmpty) continue;
    final numeroTessera =
        tesseraIndex < row.length ? (_cellText(row[tesseraIndex]?.value) ?? '').trim() : '';

    final key = codiceFiscale.toUpperCase();
    if (!codiceFiscaleByKey.containsKey(key)) {
      codiceFiscaleByKey[key] = codiceFiscale;
      tesseraByKey[key] = numeroTessera;
      orderedKeys.add(key);
    }
  }

  return orderedKeys
      .map((key) => {
            'codice_fiscale': codiceFiscaleByKey[key]!,
            'numero_tessera': tesseraByKey[key] ?? '',
          })
      .toList();
}
