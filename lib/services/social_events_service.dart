import 'package:supabase_flutter/supabase_flutter.dart';

import 'asd_documents_service.dart' show AsdDocument;

/// "Aggiungi spesa" payment method keys, in menu order, and their Italian
/// labels.
const List<String> kSocialEventPaymentMethodKeys = [
  'carta_asd',
  'contanti',
  'bonifico',
  'altro',
];

const Map<String, String> kSocialEventPaymentMethodLabels = {
  'carta_asd': 'Carta ASD',
  'contanti': 'Contanti',
  'bonifico': 'Bonifico',
  'altro': 'Altro',
};

String socialEventPaymentMethodLabel(String key) =>
    kSocialEventPaymentMethodLabels[key] ?? key;

/// One row of `asd_social_events`.
class SocialEvent {
  const SocialEvent({
    required this.id,
    required this.title,
    required this.eventDate,
    this.place,
    this.participants,
    this.notes,
    this.verbaleDocumentId,
    this.ratificaDocumentId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime eventDate;
  final String? place;
  final int? participants;
  final String? notes;
  final String? verbaleDocumentId;
  final String? ratificaDocumentId;
  final DateTime createdAt;

  bool get hasRatifica => ratificaDocumentId != null;
  bool get hasVerbale => verbaleDocumentId != null;

  factory SocialEvent.fromMap(Map<String, dynamic> map) => SocialEvent(
        id: map['id'] as String,
        title: map['title'] as String,
        eventDate: DateTime.parse(map['event_date'] as String),
        place: map['place'] as String?,
        participants: (map['participants'] as num?)?.toInt(),
        notes: map['notes'] as String?,
        verbaleDocumentId: map['verbale_document_id'] as String?,
        ratificaDocumentId: map['ratifica_document_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// One row of `asd_social_event_expenses`.
class SocialEventExpense {
  const SocialEventExpense({
    required this.id,
    required this.eventId,
    required this.expenseDate,
    required this.vendor,
    required this.amount,
    required this.paymentMethod,
    this.note,
    this.documentId,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final DateTime expenseDate;
  final String vendor;
  final double amount;

  /// One of [kSocialEventPaymentMethodKeys].
  final String paymentMethod;
  final String? note;
  final String? documentId;
  final DateTime createdAt;

  factory SocialEventExpense.fromMap(Map<String, dynamic> map) => SocialEventExpense(
        id: map['id'] as String,
        eventId: map['event_id'] as String,
        expenseDate: DateTime.parse(map['expense_date'] as String),
        vendor: map['vendor'] as String,
        amount: (map['amount'] as num).toDouble(),
        paymentMethod: map['payment_method'] as String,
        note: map['note'] as String?,
        documentId: map['document_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Client for the "Eventi sociali" tables (`asd_social_events`,
/// `asd_social_event_expenses`). Additive and isolated: touches only these
/// two tables — nothing here changes payments, bookings, subscriptions,
/// receipts, the Registro di Cassa, the Scadenzario, Presenze e compensi or
/// the documents archive (expense receipts and verbali are filed there via
/// AsdDocumentsService, called from the UI, not from here). RLS already
/// scopes reads to can_access_admin_section('social_events') and writes to
/// the principal admin only.
class SocialEventsService {
  SocialEventsService._();
  static final SocialEventsService instance = SocialEventsService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const String _eventsTable = 'asd_social_events';
  static const String _expensesTable = 'asd_social_event_expenses';

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Most recent first.
  Future<List<SocialEvent>> getEvents() async {
    final rows = await _client
        .from(_eventsTable)
        .select('*')
        .order('event_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => SocialEvent.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Read-only cross-reference into `asd_documents` (owned by the Archivio
  /// documenti, not touched here otherwise) so an expense receipt or a
  /// generated verbale/ratifica can be opened with the archive's own
  /// openAsdDocument, without modifying asd_documents_service.dart.
  Future<AsdDocument?> getDocumentById(String id) async {
    final row = await _client.from('asd_documents').select('*').eq('id', id).maybeSingle();
    return row == null ? null : AsdDocument.fromMap(row);
  }

  Future<SocialEvent> getEvent(String id) async {
    final row = await _client.from(_eventsTable).select('*').eq('id', id).single();
    return SocialEvent.fromMap(row);
  }

  /// event_id -> sum of its expenses' amounts, for the events list totals.
  /// One query for every event rather than one per row.
  Future<Map<String, double>> getExpenseTotalsByEvent() async {
    final rows = await _client.from(_expensesTable).select('event_id, amount');
    final totals = <String, double>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final eventId = row['event_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      totals[eventId] = (totals[eventId] ?? 0) + amount;
    }
    return totals;
  }

  /// Principal admin only (RLS).
  Future<SocialEvent> addEvent({
    required String title,
    required DateTime eventDate,
    String? place,
    int? participants,
    String? notes,
  }) async {
    final row = await _client
        .from(_eventsTable)
        .insert({
          'title': title.trim().isEmpty ? 'Cena sociale' : title.trim(),
          'event_date': _dateStr(eventDate),
          'place': (place == null || place.trim().isEmpty) ? null : place.trim(),
          'participants': participants,
          'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        })
        .select()
        .single();
    return SocialEvent.fromMap(row);
  }

  /// Principal admin only (RLS).
  Future<void> updateEvent(
    String id, {
    String? title,
    DateTime? eventDate,
    String? place,
    int? participants,
    String? notes,
  }) async {
    final values = <String, dynamic>{
      if (title != null) 'title': title.trim().isEmpty ? 'Cena sociale' : title.trim(),
      if (eventDate != null) 'event_date': _dateStr(eventDate),
      if (place != null) 'place': place.trim().isEmpty ? null : place.trim(),
      if (participants != null) 'participants': participants,
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
    if (values.isEmpty) return;
    await _client.from(_eventsTable).update(values).eq('id', id);
  }

  /// Principal admin only (RLS). Cascades to the event's expense rows; the
  /// underlying receipt/verbale files stay in the Archivio documenti.
  Future<void> deleteEvent(String id) async {
    await _client.from(_eventsTable).delete().eq('id', id);
  }

  /// Principal admin only (RLS).
  Future<void> setVerbaleDocument(String eventId, String documentId) async {
    await _client
        .from(_eventsTable)
        .update({'verbale_document_id': documentId}).eq('id', eventId);
  }

  /// Principal admin only (RLS).
  Future<void> setRatificaDocument(String eventId, String documentId) async {
    await _client
        .from(_eventsTable)
        .update({'ratifica_document_id': documentId}).eq('id', eventId);
  }

  /// Most recent first.
  Future<List<SocialEventExpense>> getExpenses(String eventId) async {
    final rows = await _client
        .from(_expensesTable)
        .select('*')
        .eq('event_id', eventId)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => SocialEventExpense.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Principal admin only (RLS).
  Future<void> addExpense({
    required String eventId,
    required DateTime expenseDate,
    required String vendor,
    required double amount,
    required String paymentMethod,
    String? note,
    String? documentId,
  }) async {
    await _client.from(_expensesTable).insert({
      'event_id': eventId,
      'expense_date': _dateStr(expenseDate),
      'vendor': vendor.trim().isEmpty ? 'Metro' : vendor.trim(),
      'amount': amount,
      'payment_method': paymentMethod,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      'document_id': documentId,
    });
  }

  /// Principal admin only (RLS).
  Future<void> deleteExpense(String id) async {
    await _client.from(_expensesTable).delete().eq('id', id);
  }
}
