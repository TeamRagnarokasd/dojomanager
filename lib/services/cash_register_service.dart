import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// One row of the Registro di Cassa ledger (`cash_register_entries`).
class CashRegisterEntry {
  const CashRegisterEntry({
    required this.id,
    required this.entryDate,
    required this.kind,
    required this.source,
    required this.description,
    required this.amount,
    this.receiptNumber,
    this.customerName,
    this.photoPath,
  });

  final String id;
  final DateTime entryDate;
  final String kind; // 'entrata' | 'uscita'
  final String source; // 'receipt' | 'manual'
  final String description;
  final double amount;
  final String? receiptNumber;
  final String? customerName;
  final String? photoPath;

  bool get isEntrata => kind == 'entrata';
  bool get isManual => source == 'manual';

  factory CashRegisterEntry.fromMap(Map<String, dynamic> map) {
    return CashRegisterEntry(
      id: map['id'] as String,
      entryDate: DateTime.parse(map['entry_date'] as String),
      kind: map['kind'] as String,
      source: map['source'] as String,
      description: map['description'] as String? ?? '',
      amount: (map['amount'] as num).toDouble(),
      receiptNumber: map['receipt_number'] as String?,
      customerName: map['customer_name'] as String?,
      photoPath: map['photo_path'] as String?,
    );
  }
}

/// Ledger rows + running totals for a single calendar month, as shown in the
/// Registro di Cassa "Prima Nota" list.
class CashRegisterMonthSummary {
  const CashRegisterMonthSummary({
    required this.month,
    required this.balanceAtMonthStart,
    required this.entries,
    required this.progressiveBalances,
    required this.totalEntrate,
    required this.totalUscite,
    required this.balanceAtMonthEnd,
  });

  /// First day of the month.
  final DateTime month;

  /// Running cash balance immediately before the first day of this month.
  final double balanceAtMonthStart;

  /// Ledger rows for this month, in chronological order.
  final List<CashRegisterEntry> entries;

  /// Running balance right after each entry in [entries] (same order/length).
  final List<double> progressiveBalances;

  final double totalEntrate;
  final double totalUscite;

  /// Running cash balance at the end of this month (can be negative if a
  /// manual entry was later back-dated into this month — see
  /// CashRegisterService docs).
  final double balanceAtMonthEnd;
}

/// Client for the Registro di Cassa (Fase 1) backend: a plain ledger table
/// (`cash_register_entries`) fed automatically from cash receipts
/// (`cash_register_sync`) and manually for outflows, plus a single settings
/// row (`cash_register_settings`) holding the opening balance/date.
///
/// All reads/writes are additive and isolated from payments, bookings,
/// receipts, subscriptions, SumUp and Satispay — this service touches only
/// the cash_register_* tables/RPCs and the private 'cash-receipts' storage
/// bucket, all already provisioned server-side (including RLS restricting
/// them to the principal admin). Every mutation goes through a
/// SECURITY DEFINER RPC (never a direct table insert/update/delete), since
/// that is the only way RLS allows these tables to be written.
class CashRegisterService {
  CashRegisterService._();
  static final CashRegisterService instance = CashRegisterService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _entriesTable = 'cash_register_entries';
  static const String _settingsTable = 'cash_register_settings';
  static const String _bucket = 'cash-receipts';

  static const String _entryColumns =
      'id, entry_date, kind, source, description, amount, receipt_number, customer_name, photo_path';

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// True if [error] is the CASH_NEGATIVE guard raised by
  /// cash_register_add_outflow / cash_register_set_opening.
  static bool isCashNegativeError(Object error) {
    final message = error is PostgrestException
        ? error.message
        : error.toString();
    return message.contains('CASH_NEGATIVE');
  }

  /// Copies any new cash receipts into the ledger. Safe to call repeatedly
  /// (idempotent server-side) — call every time the screen opens.
  Future<void> sync() async {
    await _client.rpc('cash_register_sync');
  }

  Future<Map<String, dynamic>> getSettings() async {
    return await _client
        .from(_settingsTable)
        .select('opening_balance, opening_date')
        .eq('id', 1)
        .single();
  }

  /// Sum of entrata minus uscita for entries with
  /// fromInclusive <= entry_date < toExclusive.
  Future<double> _netBetween(DateTime fromInclusive, DateTime toExclusive) async {
    final rows = await _client
        .from(_entriesTable)
        .select('kind, amount')
        .gte('entry_date', _dateStr(fromInclusive))
        .lt('entry_date', _dateStr(toExclusive));

    double total = 0.0;
    for (final row in (rows as List)) {
      final amount = (row['amount'] as num).toDouble();
      total += (row['kind'] == 'entrata') ? amount : -amount;
    }
    return total;
  }

  /// The real cash balance right now: opening balance + all entrate - all
  /// uscite from the opening date up to today. Never negative in practice —
  /// enforced server-side by the CASH_NEGATIVE guard on every write.
  Future<double> getCurrentCashBalance() async {
    final settings = await getSettings();
    final openingBalance = (settings['opening_balance'] as num).toDouble();
    final openingDate = DateTime.parse(settings['opening_date'] as String);

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final net = await _netBetween(openingDate, tomorrow);
    return openingBalance + net;
  }

  /// Ledger rows and running totals for [month] (any date within the
  /// target month). The month selector must never go before the opening
  /// month, which keeps the running-balance math below correct.
  Future<CashRegisterMonthSummary> getMonthSummary(DateTime month) async {
    final settings = await getSettings();
    final openingBalance = (settings['opening_balance'] as num).toDouble();
    final openingDate = DateTime.parse(settings['opening_date'] as String);

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEndExclusive = DateTime(month.year, month.month + 1, 1);

    final netBeforeMonth = await _netBetween(openingDate, monthStart);
    final balanceAtMonthStart = openingBalance + netBeforeMonth;

    final rows = await _client
        .from(_entriesTable)
        .select(_entryColumns)
        .gte('entry_date', _dateStr(monthStart))
        .lt('entry_date', _dateStr(monthEndExclusive))
        .order('entry_date', ascending: true)
        .order('created_at', ascending: true);

    final entries = <CashRegisterEntry>[];
    final progressive = <double>[];
    double totalEntrate = 0.0;
    double totalUscite = 0.0;
    double running = balanceAtMonthStart;

    for (final row in (rows as List)) {
      final entry = CashRegisterEntry.fromMap(row as Map<String, dynamic>);
      entries.add(entry);
      if (entry.isEntrata) {
        running += entry.amount;
        totalEntrate += entry.amount;
      } else {
        running -= entry.amount;
        totalUscite += entry.amount;
      }
      progressive.add(running);
    }

    return CashRegisterMonthSummary(
      month: monthStart,
      balanceAtMonthStart: balanceAtMonthStart,
      entries: entries,
      progressiveBalances: progressive,
      totalEntrate: totalEntrate,
      totalUscite: totalUscite,
      balanceAtMonthEnd: running,
    );
  }

  /// Records a manual outflow. Throws a PostgrestException whose message
  /// contains CASH_NEGATIVE if it would push the current cash balance below
  /// zero (see [isCashNegativeError]) — nothing is recorded in that case.
  Future<String> addOutflow({
    required DateTime date,
    required String description,
    required double amount,
    String? photoPath,
  }) async {
    final id = await _client.rpc(
      'cash_register_add_outflow',
      params: {
        'p_date': _dateStr(date),
        'p_description': description,
        'p_amount': amount,
        'p_photo_path': photoPath,
      },
    );
    return id as String;
  }

  /// Deletes a manual outflow (receipt-sourced rows are never deletable —
  /// the RPC itself only ever deletes rows with source='manual').
  Future<void> deleteOutflow(String id) async {
    await _client.rpc('cash_register_delete_outflow', params: {'p_id': id});
  }

  /// Updates the opening balance/date. Throws a PostgrestException whose
  /// message contains CASH_NEGATIVE if it would push the current cash
  /// balance below zero (see [isCashNegativeError]).
  Future<void> setOpening({required double balance, required DateTime date}) async {
    await _client.rpc(
      'cash_register_set_opening',
      params: {'p_balance': balance, 'p_date': _dateStr(date)},
    );
  }

  /// Compresses a receipt photo and uploads it to the private 'cash-receipts'
  /// bucket under a random file name, returning the storage path to pass as
  /// photo_path to [addOutflow].
  Future<String> uploadReceiptPhoto(Uint8List bytes) async {
    final compressed = _compressReceiptPhoto(bytes);
    final fileName = '${const Uuid().v4()}.jpg';
    await _client.storage.from(_bucket).uploadBinary(fileName, compressed);
    return fileName;
  }

  /// Signed URL (1 hour) to view a receipt photo from the private bucket.
  Future<String> getReceiptPhotoUrl(String photoPath) async {
    return await _client.storage.from(_bucket).createSignedUrl(photoPath, 3600);
  }

  /// Resizes to a max width of 1600px (keeping aspect ratio, so a tall
  /// receipt stays readable) and re-encodes as JPEG, shrinking quality
  /// further if still over ~1.5MB. Mirrors UserProfileService's photo
  /// compression approach.
  Uint8List _compressReceiptPhoto(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final resized = decoded.width > 1600
          ? img.copyResize(decoded, width: 1600, interpolation: img.Interpolation.linear)
          : decoded;

      var quality = 85;
      var compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      const maxBytes = 1536 * 1024; // ~1.5MB
      while (compressed.lengthInBytes > maxBytes && quality > 40) {
        quality -= 10;
        compressed = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      }
      return compressed;
    } catch (_) {
      return bytes;
    }
  }
}
