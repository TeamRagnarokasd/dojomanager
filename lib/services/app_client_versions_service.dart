import 'package:supabase_flutter/supabase_flutter.dart';

/// Client for the admin "Versioni app" RPC: `admin_outdated_clients_list`,
/// already joined with user_profiles and ordered oldest-last-access-first.
/// Each row is {user_id, name, email, platform, version_name, build_number,
/// last_seen_at, outdated}.
class AppClientVersionsService {
  AppClientVersionsService._();
  static final AppClientVersionsService instance =
      AppClientVersionsService._();

  static final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> adminOutdatedClientsList() async {
    final result = await _client.rpc('admin_outdated_clients_list');
    final list = (result as List?) ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
