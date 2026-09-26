import 'package:supabase_flutter/supabase_flutter.dart';

/// "Chiedi a Claude (dati app)": chat AI di sola lettura riservata ad admin
/// e admin principale. Claude legge i dati che gli servono da sé tramite
/// una connessione al database separata, aperta in sola lettura lato
/// server (edge function `admin-ask-claude`) — questo servizio si limita a
/// chiamarla e a leggere/mostrare la cronologia locale delle domande.
class AdminAskClaudeService {
  AdminAskClaudeService._();
  static final AdminAskClaudeService instance = AdminAskClaudeService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'admin_ai_queries';

  /// True se il ruolo dell'utente loggato è 'admin' o 'principal_admin'.
  /// Fallisce chiuso: qualunque errore ritorna false.
  Future<bool> canUse() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final profile = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = profile?['role'] as String?;
      return role == 'admin' || role == 'principal_admin';
    } catch (_) {
      return false;
    }
  }

  /// Chiama l'edge function con la domanda e ritorna la risposta. Lancia
  /// un'eccezione con un messaggio in italiano se qualcosa va storto.
  Future<String> ask(String question) async {
    const fallbackMessage = 'Non riesco a rispondere ora, riprova più tardi.';
    try {
      final response = await _client.functions.invoke(
        'admin-ask-claude',
        body: {'question': question},
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (data is! Map || data['answer'] is! String) {
        throw Exception(fallbackMessage);
      }
      return data['answer'] as String;
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

  /// Le proprie domande/risposte precedenti, più recenti prima.
  Future<List<Map<String, dynamic>>> getHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
