import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Sponsor e Shop": l'allievo carica lo screenshot del carrello fatto sul
/// sito di uno sponsor convenzionato, un'edge function lo legge e calcola il
/// prezzo scontato, l'allievo conferma (da solo o unendosi a un gruppo per
/// dividere la spedizione) e paga. Tutto dietro `shop_enabled_for_me()`, così
/// una tabella mancante o un errore di rete lasciano semplicemente la
/// funzione nascosta invece di far crashare l'app.
class ShopService {
  ShopService._();
  static final ShopService instance = ShopService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _screenshotsBucket = 'shop-carts';

  /// True se il flag globale `shop_sponsor_enabled` è acceso oppure
  /// l'utente corrente è in `shop_testers`. Fallisce chiuso: qualunque
  /// errore (tabella mancante, rete) ritorna false.
  Future<bool> isEnabledForMe() async {
    try {
      final result = await _client.rpc('shop_enabled_for_me');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Gli sponsor, tra [sponsorIds], che hanno una riga in
  /// `shop_sponsor_settings` (cioè hanno lo shop configurato).
  Future<Set<String>> getSponsorIdsWithShop(List<String> sponsorIds) async {
    if (sponsorIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('shop_sponsor_settings')
          .select('sponsor_id')
          .inFilter('sponsor_id', sponsorIds);
      return (rows as List)
          .map((row) => row['sponsor_id'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> getShopSettings(String sponsorId) async {
    try {
      final row = await _client
          .from('shop_sponsor_settings')
          .select('discount_pct, shipping_total, cash_surcharge, satispay_tag, window_days, close_hour')
          .eq('sponsor_id', sponsorId)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  String _shopTipPrefKey(String userId, String sponsorId) =>
      'shop_tip_dismissed_${userId}_$sponsorId';

  /// Se l'utente ha già scelto "Non mostrare più" per il messaggio informativo
  /// del banner di questo sponsor.
  Future<bool> isShopTipDismissed(String sponsorId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_shopTipPrefKey(userId, sponsorId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismissShopTip(String sponsorId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_shopTipPrefKey(userId, sponsorId), true);
    } catch (_) {
      // Non critico: il messaggio ricomparirà la prossima volta.
    }
  }

  /// Apre la galleria, carica l'immagine scelta in `shop-carts/<user_id>/...`
  /// e ritorna il percorso salvato. Ritorna null se l'utente annulla la
  /// selezione o se qualcosa va storto.
  Future<String?> pickAndUploadCartScreenshot() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      return null;
    }
    if (picked == null) return null;

    try {
      final Uint8List bytes;
      if (kIsWeb) {
        bytes = await picked.readAsBytes();
      } else {
        bytes = await File(picked.path).readAsBytes();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      final storagePath = '$userId/cart_$timestamp.$extension';

      await _client.storage
          .from(_screenshotsBucket)
          .uploadBinary(storagePath, bytes);

      return storagePath;
    } catch (_) {
      return null;
    }
  }

  /// Chiama l'edge function che legge lo screenshot e crea l'ordine
  /// ('da_confermare'). Lancia un'eccezione con un messaggio in italiano se
  /// qualcosa va storto.
  Future<Map<String, dynamic>> readCart({
    required String sponsorId,
    required String screenshotPath,
  }) async {
    const fallbackMessage = 'Lettura del carrello non disponibile, riprova più tardi.';
    try {
      final response = await _client.functions.invoke(
        'shop-cart-read',
        body: {'sponsor_id': sponsorId, 'screenshot_path': screenshotPath},
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (data is! Map || data['order'] is! Map) {
        throw Exception(fallbackMessage);
      }
      return (data['order'] as Map).cast<String, dynamic>();
    } catch (e) {
      // A non-2xx edge function response surfaces here as a thrown
      // exception (not as `response.data`) — try to pull its Italian
      // message out of the error body, falling back to the generic one.
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

  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await _client
          .from('shop_orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> confirmOrder({
    required String orderId,
    required bool shared,
  }) async {
    await _client.rpc('shop_confirm_order', params: {
      'p_order_id': orderId,
      'p_shared': shared,
    });
  }

  Future<void> declarePayment({
    required String orderId,
    required String method,
  }) async {
    await _client.rpc('shop_declare_payment', params: {
      'p_order_id': orderId,
      'p_method': method,
    });
  }

  /// closes_at, other_participants e shipping_share attuale per un ordine.
  /// Non espone mai i dati degli altri partecipanti, solo il loro numero.
  Future<Map<String, dynamic>?> getWindowInfo(String orderId) async {
    try {
      final result = await _client.rpc('shop_window_info', params: {
        'p_order_id': orderId,
      });
      final rows = result as List;
      if (rows.isEmpty) return null;
      return (rows.first as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOpenWindows() async {
    final rows = await _client
        .from('shop_group_windows')
        .select()
        .eq('status', 'aperta')
        .order('opened_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getClosedWindows({int limit = 20}) async {
    final rows = await _client
        .from('shop_group_windows')
        .select()
        .eq('status', 'chiusa')
        .order('opened_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> closeWindowNow(String windowId) async {
    await _client.rpc('shop_close_window', params: {'p_window_id': windowId});
  }

  Future<List<Map<String, dynamic>>> getOrdersForWindow(String windowId) async {
    final rows = await _client
        .from('shop_orders')
        .select()
        .eq('group_window_id', windowId)
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Ordini non condivisi (nessuna finestra di gruppo).
  Future<List<Map<String, dynamic>>> getOrdersWithoutWindow() async {
    final rows = await _client
        .from('shop_orders')
        .select()
        .eq('shared', false)
        .neq('status', 'da_confermare')
        .order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, Map<String, dynamic>>> getCostsForOrders(
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return {};
    final rows = await _client
        .from('shop_order_costs')
        .select()
        .inFilter('order_id', orderIds);
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['order_id'] as String: row,
    };
  }

  Future<Map<String, String>> getSponsorNames(List<String> sponsorIds) async {
    if (sponsorIds.isEmpty) return {};
    final rows = await _client
        .from('sponsors')
        .select('id, name')
        .inFilter('id', sponsorIds);
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['id'] as String: (row['name'] ?? '').toString(),
    };
  }

  Future<Map<String, String>> getFullNamesForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('user_profiles')
        .select('id, full_name')
        .inFilter('id', userIds);
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['id'] as String: (row['full_name'] ?? '').toString(),
    };
  }

  Future<void> markPaid(String orderId) async {
    await _client.rpc('shop_mark_paid', params: {'p_order_id': orderId});
  }

  Future<void> markOrdered(String orderId) async {
    await _client.rpc('shop_mark_ordered', params: {'p_order_id': orderId});
  }

  Future<String?> getScreenshotSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      return await _client.storage
          .from(_screenshotsBucket)
          .createSignedUrl(storagePath, expiresInSeconds);
    } catch (_) {
      return null;
    }
  }
}
