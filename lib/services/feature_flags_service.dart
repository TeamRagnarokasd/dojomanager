import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `app_feature_flags` (key -> enabled), for gating new behavior from
/// the server without an app release. A missing row or any read error both
/// mean "off" — never fail open. Each key is cached for 60s so a feature
/// check on the hot path doesn't hit the table every time.
class FeatureFlagsService {
  FeatureFlagsService._();
  static final FeatureFlagsService instance = FeatureFlagsService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'app_feature_flags';
  static const Duration _cacheTtl = Duration(seconds: 60);

  final Map<String, _CachedFlag> _cache = {};

  Future<bool> isEnabled(String key) async {
    final cached = _cache[key];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.value;
    }

    var value = false;
    try {
      final row = await _client
          .from(_table)
          .select('enabled')
          .eq('key', key)
          .maybeSingle();
      value = row?['enabled'] as bool? ?? false;
    } catch (_) {
      value = false;
    }

    _cache[key] = _CachedFlag(value: value, expiresAt: DateTime.now().add(_cacheTtl));
    return value;
  }
}

class _CachedFlag {
  const _CachedFlag({required this.value, required this.expiresAt});

  final bool value;
  final DateTime expiresAt;
}
