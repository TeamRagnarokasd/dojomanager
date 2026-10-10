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

  /// Like [isEnabled], but for a gate where a transient read failure must
  /// never be silently treated the same as a genuine "off" — e.g. the
  /// SumUp/Satispay payment kill-switch, where there is no manual fallback
  /// left to offer if this comes back wrong. Bypasses the cache and retries
  /// the read once before giving up; only a confirmed `enabled = false` row,
  /// or two failed reads in a row, return false.
  Future<bool> isEnabledReliable(String key) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final row = await _client
            .from(_table)
            .select('enabled')
            .eq('key', key)
            .maybeSingle();
        final value = row?['enabled'] as bool? ?? false;
        _cache[key] =
            _CachedFlag(value: value, expiresAt: DateTime.now().add(_cacheTtl));
        return value;
      } catch (_) {
        if (attempt == 1) return false;
      }
    }
    return false;
  }
}

class _CachedFlag {
  const _CachedFlag({required this.value, required this.expiresAt});

  final bool value;
  final DateTime expiresAt;
}
