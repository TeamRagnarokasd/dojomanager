import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  static final _supabase = Supabase.instance.client;

  // Get all subscription plans
  static Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    try {
      final response = await _supabase
          .from('subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('plan_type')
          .order('price');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch subscription plans: $e');
    }
  }

  // Get user's active subscriptions
  static Future<List<Map<String, dynamic>>> getUserActiveSubscriptions(
      [String? userId]) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final response = await _supabase.rpc('get_user_active_subscriptions',
          params: {'user_uuid': currentUserId});

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch user subscriptions: $e');
    }
  }

  // Create a new subscription
  static Future<Map<String, dynamic>> createSubscription({
    required String subscriptionPlanId,
    String? userId,
  }) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get plan details first
      final planResponse = await _supabase
          .from('subscription_plans')
          .select('*')
          .eq('id', subscriptionPlanId)
          .single();

      final plan = Map<String, dynamic>.from(planResponse);

      // Calculate entries and expiration based on plan type
      int entriesRemaining = 0;
      int entriesTotal = 0;
      DateTime? expiresAt;

      switch (plan['plan_type']) {
        case 'single_entry':
          entriesRemaining = 1;
          entriesTotal = 1;
          break;
        case 'multi_entry':
          entriesRemaining = plan['entry_count'] ?? 0;
          entriesTotal = plan['entry_count'] ?? 0;
          break;
        case 'monthly':
          // Monthly plans expire after 30 days
          expiresAt = DateTime.now().add(const Duration(days: 30));
          break;
        case 'annual':
          // Annual plans expire after 365 days
          expiresAt = DateTime.now().add(const Duration(days: 365));
          break;
      }

      final response = await _supabase
          .from('user_subscriptions')
          .insert({
            'user_id': currentUserId,
            'subscription_plan_id': subscriptionPlanId,
            'entries_remaining': entriesRemaining,
            'entries_total': entriesTotal,
            'is_active': true,
            'expires_at': expiresAt?.toIso8601String(),
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  // Use a subscription entry
  static Future<bool> useSubscriptionEntry({
    required String userSubscriptionId,
    String? classType,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc('use_subscription_entry', params: {
        'user_subscription_uuid': userSubscriptionId,
        'class_type_param': classType,
        'notes_param': notes,
      });

      return response == true;
    } catch (e) {
      throw Exception('Failed to use subscription entry: $e');
    }
  }

  // Get user's subscription usage history
  static Future<List<Map<String, dynamic>>> getUserSubscriptionUsage(
      [String? userId]) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final response =
          await _supabase.from('subscription_entry_usage').select('''
            *,
            user_subscriptions!inner(
              subscription_plans!inner(name, plan_type)
            )
          ''').eq('user_id', currentUserId).order('used_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch subscription usage: $e');
    }
  }

  // Get subscription statistics for user
  static Future<Map<String, dynamic>> getUserSubscriptionStats(
      [String? userId]) async {
    try {
      final currentUserId = userId ?? _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final activeSubscriptions =
          await getUserActiveSubscriptions(currentUserId);
      final usageHistory = await getUserSubscriptionUsage(currentUserId);

      int totalEntriesRemaining = 0;
      int totalEntriesUsed = usageHistory.length;

      for (final sub in activeSubscriptions) {
        totalEntriesRemaining += (sub['entries_remaining'] ?? 0) as int;
      }

      return {
        'active_subscriptions_count': activeSubscriptions.length,
        'total_entries_remaining': totalEntriesRemaining,
        'total_entries_used': totalEntriesUsed,
        'active_subscriptions': activeSubscriptions,
      };
    } catch (e) {
      throw Exception('Failed to fetch subscription stats: $e');
    }
  }

  // Admin functions - Get all subscriptions
  static Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final response = await _supabase.from('user_subscriptions').select('''
            *,
            user_profiles!inner(full_name, email),
            subscription_plans!inner(name, price, plan_type)
          ''').order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch all subscriptions: $e');
    }
  }

  // Admin functions - Get subscription usage analytics
  static Future<Map<String, dynamic>> getSubscriptionAnalytics() async {
    try {
      final allSubs = await getAllSubscriptions();
      final usageResponse = await _supabase
          .from('subscription_entry_usage')
          .select('*')
          .order('used_at', ascending: false);

      final usage = List<Map<String, dynamic>>.from(usageResponse);

      // Calculate analytics
      final totalSubscriptions = allSubs.length;
      final activeSubscriptions =
          allSubs.where((s) => s['is_active'] == true).length;
      final totalEntriesUsed = usage.length;

      // Group by plan type
      final planTypeStats = <String, Map<String, dynamic>>{};
      for (final sub in allSubs) {
        final planType = sub['subscription_plans']['plan_type'];
        if (!planTypeStats.containsKey(planType)) {
          planTypeStats[planType] = {
            'count': 0,
            'total_revenue': 0.0,
          };
        }
        planTypeStats[planType]!['count'] =
            (planTypeStats[planType]!['count'] as int) + 1;
        planTypeStats[planType]!['total_revenue'] =
            (planTypeStats[planType]!['total_revenue'] as double) +
                (sub['subscription_plans']['price'] ?? 0.0);
      }

      return {
        'total_subscriptions': totalSubscriptions,
        'active_subscriptions': activeSubscriptions,
        'total_entries_used': totalEntriesUsed,
        'plan_type_stats': planTypeStats,
        'recent_subscriptions': allSubs.take(10).toList(),
        'recent_usage': usage.take(10).toList(),
      };
    } catch (e) {
      throw Exception('Failed to fetch subscription analytics: $e');
    }
  }
}
