import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification types pushed via real-time
enum RealtimeNotificationType {
  classChange,
  paymentConfirmation,
  adminMessage,
  certificateExpiration,
  adminAlert,
}

/// Tables that can emit data-change events
enum RealtimeDataChangeType {
  subscriptionPlans,
  customSubscriptionPlans,
  disciplines,
  scheduleTemplates,
  scheduleInstances,
}

/// Fired when admin changes data that other screens should reload
class RealtimeDataChangeEvent {
  final RealtimeDataChangeType type;
  final String? recordId;
  final Map<String, dynamic>? newRecord;
  final Map<String, dynamic>? oldRecord;

  RealtimeDataChangeEvent({
    required this.type,
    this.recordId,
    this.newRecord,
    this.oldRecord,
  });
}

/// A single real-time notification payload
class RealtimeNotification {
  final String id;
  final RealtimeNotificationType type;
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final DateTime receivedAt;

  RealtimeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

class RealtimeNotificationService {
  static RealtimeNotificationService? _instance;
  static RealtimeNotificationService get instance =>
      _instance ??= RealtimeNotificationService._();

  RealtimeNotificationService._();

  final SupabaseClient _client = Supabase.instance.client;

  final StreamController<RealtimeNotification> _notificationController =
      StreamController<RealtimeNotification>.broadcast();

  /// Stream for data-change events (subscription plans, disciplines, schedule)
  final StreamController<RealtimeDataChangeEvent> _dataChangeController =
      StreamController<RealtimeDataChangeEvent>.broadcast();

  Stream<RealtimeNotification> get notificationStream =>
      _notificationController.stream;

  /// Subscribe to this stream to react to admin data changes in real time
  Stream<RealtimeDataChangeEvent> get dataChangeStream =>
      _dataChangeController.stream;

  final List<RealtimeChannel> _channels = [];
  bool _isSubscribed = false;
  bool _isAdminDataSubscribed = false;

  /// Start all real-time subscriptions for the current user
  void subscribe(String userId) {
    if (_isSubscribed) return;
    _isSubscribed = true;

    _subscribeToClassChanges();
    _subscribeToPaymentConfirmations(userId);
    _subscribeToAdminCommunications();
    _subscribeToCertificateAndAccountChanges(userId);
  }

  /// Subscribe to admin-managed data tables so all connected clients
  /// receive instant updates when the admin modifies plans, disciplines or schedule.
  /// Safe to call multiple times — only subscribes once.
  void subscribeToAdminDataChanges() {
    if (_isAdminDataSubscribed) return;
    _isAdminDataSubscribed = true;

    _subscribeToSubscriptionPlans();
    _subscribeToCustomSubscriptionPlans();
    _subscribeToDisciplineChanges();
    _subscribeToScheduleTemplateChanges();
  }

  /// Unsubscribe all channels (call on logout or dispose)
  Future<void> unsubscribe() async {
    for (final channel in _channels) {
      await channel.unsubscribe();
    }
    _channels.clear();
    _isSubscribed = false;
    _isAdminDataSubscribed = false;
  }

  // ─── 1. Class schedule changes ────────────────────────────────────────────

  void _subscribeToClassChanges() {
    final channel = _client
        .channel('realtime:schedule_instances')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'schedule_instances',
          callback: (payload) {
            final record = payload.newRecord;
            final isCancelled = record['is_cancelled'] == true;
            final discipline = record['discipline'] ?? 'Classe';
            final classDate = record['class_date'] ?? '';

            if (isCancelled) {
              _emit(
                RealtimeNotification(
                  id: 'class_cancel_${record['id']}',
                  type: RealtimeNotificationType.classChange,
                  title: 'Classe Annullata',
                  message:
                      'La classe di $discipline del $classDate è stata annullata.',
                  color: const Color(0xFFE53935),
                  icon: Icons.event_busy,
                ),
              );
            } else {
              _emit(
                RealtimeNotification(
                  id: 'class_update_${record['id']}',
                  type: RealtimeNotificationType.classChange,
                  title: 'Orario Aggiornato',
                  message:
                      'La classe di $discipline del $classDate è stata modificata.',
                  color: const Color(0xFFFB8C00),
                  icon: Icons.schedule,
                ),
              );
            }
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  // ─── 2. Payment confirmations ─────────────────────────────────────────────

  void _subscribeToPaymentConfirmations(String userId) {
    final updateChannel = _client
        .channel('realtime:payment_confirmations_update:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payment_confirmations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final status = record['status'] ?? '';
            final amount = record['amount']?.toString() ?? '0';

            if (status == 'confirmed') {
              _emit(
                RealtimeNotification(
                  id: 'payment_confirmed_${record['id']}',
                  type: RealtimeNotificationType.paymentConfirmation,
                  title: 'Pagamento Confermato ✓',
                  message:
                      'Il tuo pagamento di €$amount è stato confermato con successo.',
                  color: const Color(0xFF43A047),
                  icon: Icons.check_circle,
                ),
              );
            } else if (status == 'rejected') {
              _emit(
                RealtimeNotification(
                  id: 'payment_rejected_${record['id']}',
                  type: RealtimeNotificationType.paymentConfirmation,
                  title: 'Pagamento Rifiutato',
                  message:
                      'Il pagamento di €$amount non è stato approvato. Contatta l\'amministratore.',
                  color: const Color(0xFFE53935),
                  icon: Icons.cancel,
                ),
              );
            }
          },
        )
        .subscribe();

    final insertChannel = _client
        .channel('realtime:payment_confirmations_insert:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'payment_confirmations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final amount = record['amount']?.toString() ?? '0';
            _emit(
              RealtimeNotification(
                id: 'payment_new_${record['id']}',
                type: RealtimeNotificationType.paymentConfirmation,
                title: 'Nuova Richiesta Pagamento',
                message:
                    'È stata creata una richiesta di pagamento di €$amount in attesa di conferma.',
                color: const Color(0xFF1E88E5),
                icon: Icons.payment,
              ),
            );
          },
        )
        .subscribe();

    _channels.add(updateChannel);
    _channels.add(insertChannel);
  }

  // ─── 3. Admin / instructor messages ──────────────────────────────────────

  void _subscribeToAdminCommunications() {
    final channel = _client
        .channel('realtime:admin_communications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'admin_communications',
          callback: (payload) {
            final record = payload.newRecord;
            final title = record['title'] ?? 'Messaggio';
            final content = record['content'] ?? '';
            final priority = record['priority'] ?? 'normal';

            _emit(
              RealtimeNotification(
                id: 'admin_msg_${record['id']}',
                type: RealtimeNotificationType.adminMessage,
                title: title,
                message: content.length > 100
                    ? '${content.substring(0, 100)}…'
                    : content,
                color: priority == 'high'
                    ? const Color(0xFFE53935)
                    : const Color(0xFF5E35B1),
                icon: Icons.announcement,
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  // ─── 4. Certificate expirations & account status (admin alerts) ───────────

  void _subscribeToCertificateAndAccountChanges(String userId) {
    final channel = _client
        .channel('realtime:user_profiles_cert:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;

            final newExpiry = newRecord['medical_certificate_expiry'];
            final oldExpiry = oldRecord['medical_certificate_expiry'];

            if (newExpiry != null && newExpiry != oldExpiry) {
              final expiryDate = DateTime.tryParse(newExpiry.toString());
              if (expiryDate != null) {
                final daysLeft = expiryDate.difference(DateTime.now()).inDays;
                if (daysLeft <= 30) {
                  _emit(
                    RealtimeNotification(
                      id: 'cert_expiry_$userId',
                      type: RealtimeNotificationType.certificateExpiration,
                      title: 'Certificato Medico in Scadenza',
                      message: daysLeft <= 0
                          ? 'Il tuo certificato medico è scaduto. Rinnovalo al più presto.'
                          : 'Il tuo certificato medico scade tra $daysLeft giorni.',
                      color: daysLeft <= 7
                          ? const Color(0xFFE53935)
                          : const Color(0xFFFB8C00),
                      icon: Icons.medical_services,
                    ),
                  );
                }
              }
            }

            final newCertStatus = newRecord['medical_certificate_status'];
            final oldCertStatus = oldRecord['medical_certificate_status'];
            if (newCertStatus != null && newCertStatus != oldCertStatus) {
              if (newCertStatus == 'expired') {
                _emit(
                  RealtimeNotification(
                    id: 'cert_status_expired_$userId',
                    type: RealtimeNotificationType.certificateExpiration,
                    title: 'Certificato Medico Scaduto',
                    message:
                        'Il tuo certificato medico è scaduto. Carica il rinnovo per continuare ad allenarti.',
                    color: const Color(0xFFE53935),
                    icon: Icons.medical_services,
                  ),
                );
              } else if (newCertStatus == 'approved') {
                _emit(
                  RealtimeNotification(
                    id: 'cert_approved_$userId',
                    type: RealtimeNotificationType.certificateExpiration,
                    title: 'Certificato Approvato',
                    message: 'Il tuo certificato medico è stato approvato.',
                    color: const Color(0xFF43A047),
                    icon: Icons.verified,
                  ),
                );
              }
            }

            final newAccountStatus = newRecord['status'];
            final oldAccountStatus = oldRecord['status'];
            if (newAccountStatus != null &&
                newAccountStatus != oldAccountStatus) {
              if (newAccountStatus == 'approved') {
                _emit(
                  RealtimeNotification(
                    id: 'account_approved_$userId',
                    type: RealtimeNotificationType.adminAlert,
                    title: 'Account Approvato',
                    message:
                        'Il tuo account è stato approvato dall\'amministratore.',
                    color: const Color(0xFF43A047),
                    icon: Icons.how_to_reg,
                  ),
                );
              } else if (newAccountStatus == 'suspended') {
                _emit(
                  RealtimeNotification(
                    id: 'account_suspended_$userId',
                    type: RealtimeNotificationType.adminAlert,
                    title: 'Account Sospeso',
                    message:
                        'Il tuo account è stato sospeso. Contatta l\'amministratore.',
                    color: const Color(0xFFE53935),
                    icon: Icons.block,
                  ),
                );
              }
            }
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  // ─── 5. Subscription plans (admin changes) ───────────────────────────────

  void _subscribeToSubscriptionPlans() {
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      final eventName = event.name;
      final channel = _client
          .channel('realtime:subscription_plans_$eventName')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'subscription_plans',
            callback: (payload) {
              _emitDataChange(RealtimeDataChangeEvent(
                type: RealtimeDataChangeType.subscriptionPlans,
                recordId: (payload.newRecord['id'] ?? payload.oldRecord['id'])
                    ?.toString(),
                newRecord:
                    payload.newRecord.isNotEmpty ? payload.newRecord : null,
                oldRecord:
                    payload.oldRecord.isNotEmpty ? payload.oldRecord : null,
              ));
            },
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  // ─── 6. Custom subscription plans (admin changes) ────────────────────────

  void _subscribeToCustomSubscriptionPlans() {
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      final eventName = event.name;
      final channel = _client
          .channel('realtime:custom_subscription_plans_$eventName')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'custom_subscription_plans',
            callback: (payload) {
              _emitDataChange(RealtimeDataChangeEvent(
                type: RealtimeDataChangeType.customSubscriptionPlans,
                recordId: (payload.newRecord['id'] ?? payload.oldRecord['id'])
                    ?.toString(),
                newRecord:
                    payload.newRecord.isNotEmpty ? payload.newRecord : null,
                oldRecord:
                    payload.oldRecord.isNotEmpty ? payload.oldRecord : null,
              ));
            },
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  // ─── 7. Discipline changes (instructor_profiles) ─────────────────────────

  void _subscribeToDisciplineChanges() {
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      final eventName = event.name;
      final channel = _client
          .channel('realtime:instructor_profiles_disciplines_$eventName')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'instructor_profiles',
            callback: (payload) {
              _emitDataChange(RealtimeDataChangeEvent(
                type: RealtimeDataChangeType.disciplines,
                recordId: (payload.newRecord['id'] ?? payload.oldRecord['id'])
                    ?.toString(),
                newRecord:
                    payload.newRecord.isNotEmpty ? payload.newRecord : null,
                oldRecord:
                    payload.oldRecord.isNotEmpty ? payload.oldRecord : null,
              ));
            },
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  // ─── 8. Schedule template changes ────────────────────────────────────────

  void _subscribeToScheduleTemplateChanges() {
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
      PostgresChangeEvent.delete,
    ]) {
      final eventName = event.name;
      final templateChannel = _client
          .channel('realtime:weekly_schedule_templates_$eventName')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'weekly_schedule_templates',
            callback: (payload) {
              _emitDataChange(RealtimeDataChangeEvent(
                type: RealtimeDataChangeType.scheduleTemplates,
                recordId: (payload.newRecord['id'] ?? payload.oldRecord['id'])
                    ?.toString(),
                newRecord:
                    payload.newRecord.isNotEmpty ? payload.newRecord : null,
                oldRecord:
                    payload.oldRecord.isNotEmpty ? payload.oldRecord : null,
              ));
            },
          )
          .subscribe();

      final instanceChannel = _client
          .channel('realtime:schedule_instances_admin_$eventName')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: 'schedule_instances',
            callback: (payload) {
              _emitDataChange(RealtimeDataChangeEvent(
                type: RealtimeDataChangeType.scheduleInstances,
                recordId: (payload.newRecord['id'] ?? payload.oldRecord['id'])
                    ?.toString(),
                newRecord:
                    payload.newRecord.isNotEmpty ? payload.newRecord : null,
                oldRecord:
                    payload.oldRecord.isNotEmpty ? payload.oldRecord : null,
              ));
            },
          )
          .subscribe();

      _channels.add(templateChannel);
      _channels.add(instanceChannel);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _emit(RealtimeNotification notification) {
    if (!_notificationController.isClosed) {
      _notificationController.add(notification);
    }
  }

  void _emitDataChange(RealtimeDataChangeEvent event) {
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(event);
    }
  }

  void dispose() {
    unsubscribe();
    _notificationController.close();
    _dataChangeController.close();
  }
}
