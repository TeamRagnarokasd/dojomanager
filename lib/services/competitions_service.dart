import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Gare" (MMA / BJJ-Grappling / Sambo): calendario gare (`competitions`),
/// leggibile da tutti gli autenticati. L'allievo (o un suo figlio, tramite
/// ChildProfileService) segna interesse ("voglio farla") e iscrizione
/// ("mi sono iscritto") in `competition_interest`, tramite le RPC
/// `competition_set_interest` / `competition_set_self_registered`.
/// L'admin carica la foto di un calendario, la fa leggere a Claude
/// dall'edge function `competition-calendar-read` e pubblica le righe
/// confermate con un insert vero.
class CompetitionsService {
  CompetitionsService._();
  static final CompetitionsService instance = CompetitionsService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _sourcesBucket = 'competition-sources';

  static const List<String> categories = [
    'mma',
    'bjj_grappling',
    'sambo',
    'k1',
  ];

  static String categoryLabel(String category) {
    switch (category) {
      case 'mma':
        return 'MMA';
      case 'bjj_grappling':
        return 'BJJ/Grappling';
      case 'sambo':
        return 'Sambo';
      case 'k1':
        return 'K1';
      default:
        return category;
    }
  }

  /// True se il ruolo dell'utente loggato è 'admin', 'principal_admin' o
  /// 'instructor_admin' — stessa platea che può scrivere su `competitions`
  /// per la RLS (public.is_admin_from_auth()). Fallisce chiuso: qualunque
  /// errore ritorna false.
  Future<bool> isAdmin() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final profile = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = profile?['role'] as String?;
      return role == 'admin' ||
          role == 'principal_admin' ||
          role == 'instructor_admin';
    } catch (_) {
      return false;
    }
  }

  // ─── Lettura ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCompetitions({
    String? category,
  }) async {
    final rows = category == null
        ? await _client
              .from('competitions')
              .select()
              .order('event_date_start', ascending: true)
        : await _client
              .from('competitions')
              .select()
              .eq('category', category)
              .order('event_date_start', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// True se esiste almeno una gara che inizia entro 30 giorni da oggi —
  /// per il badge sulla voce "Gare". Fallisce chiuso: qualunque errore
  /// spegne il badge invece di far crashare la Home.
  Future<bool> hasUpcomingWithin30Days() async {
    try {
      final today = DateTime.now();
      final in30Days = today.add(const Duration(days: 30));
      final rows = await _client
          .from('competitions')
          .select('id')
          .gte('event_date_start', _dateOnly(today))
          .lte('event_date_start', _dateOnly(in30Days))
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T')[0];

  /// Le righe di interesse/iscrizione di [userId] (adulto o figlio), come
  /// mappa competition_id -> riga.
  Future<Map<String, Map<String, dynamic>>> getInterestFor(
    String userId,
  ) async {
    try {
      final rows = await _client
          .from('competition_interest')
          .select()
          .eq('user_id', userId);
      final map = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        map[row['competition_id'].toString()] = Map<String, dynamic>.from(
          row as Map,
        );
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ─── Interesse/iscrizione (allievo) ──────────────────────────────────────

  Future<void> setInterest({
    required String competitionId,
    required String userId,
    required bool interested,
  }) async {
    try {
      await _client.rpc(
        'competition_set_interest',
        params: {
          'p_competition_id': competitionId,
          'p_user_id': userId,
          'p_interested': interested,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> setSelfRegistered({
    required String competitionId,
    required String userId,
    required bool registered,
  }) async {
    try {
      await _client.rpc(
        'competition_set_self_registered',
        params: {
          'p_competition_id': competitionId,
          'p_user_id': userId,
          'p_registered': registered,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ─── Amministrazione (admin) ─────────────────────────────────────────────

  /// Chi ha segnato interesse o iscrizione per la gara [competitionId], con
  /// nome e se sono un figlio. Riservato agli admin lato database (RPC
  /// SECURITY DEFINER).
  Future<List<Map<String, dynamic>>> getParticipants(
    String competitionId,
  ) async {
    try {
      final rows = await _client.rpc(
        'admin_competition_participants',
        params: {'p_competition_id': competitionId},
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Apre la galleria, carica la foto del calendario in
  /// `competition-sources/` e ritorna il percorso salvato. Ritorna null se
  /// l'utente annulla la selezione o se qualcosa va storto.
  Future<String?> pickAndUploadSourceImage() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
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
      final storagePath = 'calendar_$timestamp.$extension';

      await _client.storage
          .from(_sourcesBucket)
          .uploadBinary(storagePath, bytes);
      return storagePath;
    } catch (_) {
      return null;
    }
  }

  /// Chiama l'edge function che legge la foto del calendario e ritorna
  /// l'elenco letto (non salva nulla nel database). Lancia un'eccezione con
  /// un messaggio in italiano se qualcosa va storto.
  Future<List<Map<String, dynamic>>> readCalendar(String imagePath) async {
    const fallbackMessage =
        'Lettura del calendario non disponibile, riprova più tardi.';
    try {
      final response = await _client.functions.invoke(
        'competition-calendar-read',
        body: {'image_path': imagePath},
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (data is! Map || data['competitions'] is! List) {
        throw Exception(fallbackMessage);
      }
      return (data['competitions'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (e) {
      String? extractedMessage;
      try {
        final details = (e as dynamic).details;
        if (details is Map && details['error'] is String) {
          extractedMessage = details['error'] as String;
        }
      } catch (_) {
        // e has no .details in this shape — ignore.
      }
      if (extractedMessage != null) throw Exception(extractedMessage);
      if (e is Exception) rethrow;
      throw Exception(fallbackMessage);
    }
  }

  /// Insert vero delle righe confermate dall'admin.
  Future<void> publishCompetitions(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('competitions').insert(rows);
  }
}
