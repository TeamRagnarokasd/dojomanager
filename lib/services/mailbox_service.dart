import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// "Email Palestra": riepilogo della casella email condivisa (sincronizzata
/// da una edge function via IMAP) e delle fatture lette automaticamente dai
/// PDF allegati. Riservato a admin/principal_admin (non instructor_admin,
/// a differenza della maggior parte delle altre sezioni amministrative).
class MailboxService {
  MailboxService._();
  static final MailboxService instance = MailboxService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _attachmentsBucket = 'mailbox-attachments';

  /// True solo per 'admin' o 'principal_admin' — non instructor_admin.
  /// Fallisce chiuso: qualunque errore ritorna false.
  Future<bool> isVisibleForCurrentUser() async {
    try {
      final role = await AuthService.instance.getUserRole();
      return role == 'admin' || role == 'principal_admin';
    } catch (_) {
      return false;
    }
  }

  /// Numero di email non ancora lette dall'admin corrente, per il badge
  /// sulla card della dashboard. Fallisce chiuso a 0.
  Future<int> getUnreadCount() async {
    try {
      final result = await _client.rpc('mailbox_unread_count');
      return (result as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Le email più recenti prima.
  Future<List<Map<String, dynamic>>> getMessages() async {
    final rows = await _client
        .from('mailbox_messages')
        .select()
        .order('received_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Gli id dei messaggi già letti dall'admin corrente (per mostrare lo
  /// stato "letta/non letta" nell'elenco).
  Future<Set<String>> getReadMessageIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final rows = await _client
          .from('mailbox_message_reads')
          .select('message_id')
          .eq('user_id', userId);
      return (rows as List).map((row) => row['message_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> markRead(String messageId) async {
    try {
      await _client.rpc('mailbox_mark_read', params: {'p_message_id': messageId});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Le fatture non ancora pagate (da confermare o già confermate, in
  /// attesa della prova di bonifico), più recenti prima.
  Future<List<Map<String, dynamic>>> getInvoicesToPay() async {
    final rows = await _client
        .from('mailbox_invoices')
        .select()
        .inFilter('status', ['da_confermare', 'confermata'])
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> confirmInvoice({
    required String invoiceId,
    required double amount,
    required DateTime dueDate,
    required String description,
  }) async {
    try {
      await _client.rpc('mailbox_confirm_invoice', params: {
        'p_invoice_id': invoiceId,
        'p_amount': amount,
        'p_due_date': _dateOnly(dueDate),
        'p_description': description,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Ignora una fattura 'da_confermare' (es. letta per errore da un
  /// allegato che non era davvero una fattura): sparisce dalla lista.
  Future<void> ignoreInvoice(String invoiceId) async {
    try {
      await _client.rpc('mailbox_ignore_invoice', params: {'p_invoice_id': invoiceId});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> markInvoicePaid({
    required String invoiceId,
    required String attachmentPath,
  }) async {
    try {
      await _client.rpc('mailbox_mark_invoice_paid', params: {
        'p_invoice_id': invoiceId,
        'p_attachment_path': attachmentPath,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Apre il selettore file (galleria o PDF) e carica la prova di bonifico
  /// in `mailbox-attachments/proofs/<invoiceId>/...`, l'unico percorso del
  /// bucket scrivibile direttamente dall'admin (il resto è popolato solo
  /// dalla edge function). Ritorna il percorso salvato, o null se l'utente
  /// annulla la selezione o qualcosa va storto.
  Future<String?> pickAndUploadPaymentProof(String invoiceId) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
        withData: true,
      );
    } catch (_) {
      return null;
    }
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;

    try {
      final sanitizedName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'proofs/$invoiceId/${timestamp}_$sanitizedName';
      await _client.storage
          .from(_attachmentsBucket)
          .uploadBinary(storagePath, bytes);
      return storagePath;
    } catch (_) {
      return null;
    }
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T')[0];
}
