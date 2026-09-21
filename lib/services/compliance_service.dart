import 'package:supabase_flutter/supabase_flutter.dart';

/// Client for the "documenti obbligatori" compliance RPCs, all already
/// implemented server-side (my_compliance / admin_compliance_list /
/// admin_set_booking_block / admin_extend_compliance). This service only
/// wraps them — no schema or SQL changes involved.
class ComplianceService {
  ComplianceService._();
  static final ComplianceService instance = ComplianceService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Current user's own compliance status:
  /// {applies, blocked, minor_docs:{needed, ok, uploads, due, days_left},
  /// medical_cert:{needed, ok, due, days_left}}.
  Future<Map<String, dynamic>> myCompliance() async {
    final result = await _client.rpc('my_compliance');
    return (result as Map?)?.cast<String, dynamic>() ?? const {};
  }

  /// Students with something missing, already ordered from most urgent:
  /// each row is {user_id, name, email, registered_at, blocked, minor_docs,
  /// medical_cert, worst_days_left}.
  Future<List<Map<String, dynamic>>> adminComplianceList() async {
    final result = await _client.rpc('admin_compliance_list');
    final list = (result as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> setBookingBlock({
    required String userId,
    required bool active,
    String? note,
  }) async {
    await _client.rpc('admin_set_booking_block', params: {
      'p_user': userId,
      'p_active': active,
      'p_note': note,
    });
  }

  /// [kind] is 'minor_docs' or 'medical_cert'.
  Future<void> extendCompliance({
    required String userId,
    required String kind,
    required int days,
    String? note,
  }) async {
    await _client.rpc('admin_extend_compliance', params: {
      'p_user': userId,
      'p_kind': kind,
      'p_days': days,
      'p_note': note,
    });
  }
}
