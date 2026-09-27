import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Eventi e Seminari": eventi organizzati dal team (`events_seminars`), con
/// prenotazione posti (`event_registrations`). L'admin crea/modifica gli
/// eventi; l'allievo (o un suo figlio, tramite ChildProfileService) si
/// prenota e può disdire tramite le RPC `event_register` /
/// `event_cancel_registration`, che verificano capienza e appartenenza lato
/// database.
class EventsService {
  EventsService._();
  static final EventsService instance = EventsService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _postersBucket = 'event-posters';

  // ─── Lettura ─────────────────────────────────────────────────────────────

  /// Tutti gli eventi (anche annullati), più vicini per primi — per la
  /// schermata admin.
  Future<List<Map<String, dynamic>>> getEvents() async {
    final rows = await _client
        .from('events_seminars')
        .select()
        .order('event_datetime', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Solo gli eventi pubblicati e futuri — per la sezione "Eventi in
  /// programma" in Home.
  Future<List<Map<String, dynamic>>> getUpcomingPublishedEvents() async {
    final rows = await _client
        .from('events_seminars')
        .select()
        .eq('status', 'pubblicato')
        .gte('event_datetime', DateTime.now().toIso8601String())
        .order('event_datetime', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Numero di posti 'prenotato' per ogni evento (chiave: event_id). Fallisce
  /// chiuso: qualunque errore ritorna una mappa vuota (nessun conteggio
  /// mostrato, mai un numero sbagliato).
  Future<Map<String, int>> getRegistrationCounts() async {
    try {
      final rows = await _client.rpc('get_events_registration_counts');
      final counts = <String, int>{};
      for (final row in (rows as List)) {
        final eventId = row['event_id']?.toString();
        if (eventId == null) continue;
        counts[eventId] = (row['registered_count'] as num?)?.toInt() ?? 0;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Gli event_id per cui [userId] (adulto o figlio) ha una prenotazione
  /// attiva ('prenotato').
  Future<Set<String>> getActiveRegistrationsFor(String userId) async {
    try {
      final rows = await _client
          .from('event_registrations')
          .select('event_id')
          .eq('user_id', userId)
          .eq('status', 'prenotato');
      return (rows as List).map((row) => row['event_id'].toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  /// URL pubblico della locandina, o null se non caricata.
  String? posterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return null;
    return _client.storage.from(_postersBucket).getPublicUrl(posterPath);
  }

  // ─── Prenotazione (allievo) ──────────────────────────────────────────────

  /// Prenota [userId] (adulto o figlio) all'evento [eventId]. Lancia
  /// un'eccezione con il messaggio del database (es. "Evento al completo")
  /// se non è possibile.
  Future<void> register({
    required String eventId,
    required String userId,
  }) async {
    try {
      await _client.rpc(
        'event_register',
        params: {'p_event_id': eventId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Annulla la prenotazione di [userId] all'evento [eventId].
  Future<void> cancelRegistration({
    required String eventId,
    required String userId,
  }) async {
    try {
      await _client.rpc(
        'event_cancel_registration',
        params: {'p_event_id': eventId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ─── Amministrazione (admin) ─────────────────────────────────────────────

  /// I prenotati ('prenotato') all'evento [eventId], con nome e se sono un
  /// figlio. Riservato agli admin lato database (RPC SECURITY DEFINER).
  Future<List<Map<String, dynamic>>> getParticipants(String eventId) async {
    try {
      final rows = await _client.rpc(
        'admin_event_participants',
        params: {'p_event_id': eventId},
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> createEvent(Map<String, dynamic> data) async {
    await _client.from('events_seminars').insert(data);
  }

  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await _client.from('events_seminars').update(data).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('events_seminars').delete().eq('id', id);
  }

  /// Apre la galleria, carica la locandina scelta in `event-posters/` e
  /// ritorna il percorso salvato. Ritorna null se l'utente annulla la
  /// selezione o se qualcosa va storto.
  Future<String?> pickAndUploadPoster() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
    } catch (_) {
      return null;
    }
    if (picked == null) return null;

    try {
      final Uint8List bytes = kIsWeb
          ? await picked.readAsBytes()
          : await File(picked.path).readAsBytes();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      final storagePath = 'poster_$timestamp.$extension';

      await _client.storage
          .from(_postersBucket)
          .uploadBinary(storagePath, bytes);
      return storagePath;
    } catch (_) {
      return null;
    }
  }
}
