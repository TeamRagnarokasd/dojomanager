import 'package:supabase_flutter/supabase_flutter.dart';

/// Client for the admin section visibility backend: a small
/// `admin_section_visibility` table (readable by any admin) plus two RPCs —
/// `can_access_admin_section` (the actual access check: always true for the
/// principal admin; for other admins, true only if both 'administration_asd'
/// and the requested section are enabled) and `set_admin_section_visibility`
/// (principal admin only). Used to gate the "Amministrazione ASD" dashboard
/// card and its inner sections, and to power the on/off switches the
/// principal admin sees in AdministrationAsdScreen.
class AdminSectionVisibilityService {
  AdminSectionVisibilityService._();
  static final AdminSectionVisibilityService instance =
      AdminSectionVisibilityService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// True if the current user can access admin section [key] — always true
  /// for the principal admin, otherwise depends on the on/off switches.
  Future<bool> canAccess(String key) async {
    final result = await _client.rpc(
      'can_access_admin_section',
      params: {'p_key': key},
    );
    return result == true;
  }

  /// Principal admin only. Toggles whether a section is visible to
  /// non-principal admins.
  Future<void> setVisibility(String key, bool visible) async {
    await _client.rpc(
      'set_admin_section_visibility',
      params: {'p_key': key, 'p_visible': visible},
    );
  }

  /// Raw section_key -> visible_to_admins map, for rendering the toggle
  /// switches (principal admin only). Any admin can read this table (RLS),
  /// but only the principal admin can write via [setVisibility].
  Future<Map<String, bool>> getVisibilityMap() async {
    final rows = await _client
        .from('admin_section_visibility')
        .select('section_key, visible_to_admins');

    final map = <String, bool>{};
    for (final row in (rows as List)) {
      map[row['section_key'] as String] = row['visible_to_admins'] as bool? ?? false;
    }
    return map;
  }
}
