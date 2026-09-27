import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/child_profile_service.dart';
import '../../../services/events_service.dart';

/// "Eventi in programma" in Home: eventi pubblicati e futuri, con
/// prenotazione/disdetta reale (event_register / event_cancel_registration).
class UpcomingEventsSectionWidget extends StatefulWidget {
  const UpcomingEventsSectionWidget({super.key});

  @override
  State<UpcomingEventsSectionWidget> createState() =>
      _UpcomingEventsSectionWidgetState();
}

class _UpcomingEventsSectionWidgetState
    extends State<UpcomingEventsSectionWidget> {
  List<Map<String, dynamic>> _events = [];
  Map<String, int> _registrationCounts = {};
  Set<String> _myRegistrations = {};
  bool _isLoading = true;
  final Set<String> _pendingEventIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await EventsService.instance.getUpcomingPublishedEvents();
      final counts = await EventsService.instance.getRegistrationCounts();
      final userId = ChildProfileService.getActiveUserId();
      final myRegistrations = userId == null
          ? <String>{}
          : await EventsService.instance.getActiveRegistrationsFor(userId);
      if (!mounted) return;
      setState(() {
        _events = events;
        _registrationCounts = counts;
        _myRegistrations = myRegistrations;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register(String eventId) async {
    final userId = ChildProfileService.getActiveUserId();
    if (userId == null) return;
    setState(() => _pendingEventIds.add(eventId));
    try {
      await EventsService.instance.register(eventId: eventId, userId: userId);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _pendingEventIds.remove(eventId));
    }
  }

  Future<void> _cancel(String eventId) async {
    final userId = ChildProfileService.getActiveUserId();
    if (userId == null) return;
    setState(() => _pendingEventIds.add(eventId));
    try {
      await EventsService.instance.cancelRegistration(
        eventId: eventId,
        userId: userId,
      );
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _pendingEventIds.remove(eventId));
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_events.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Eventi in programma',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              SizedBox(width: 2.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_events.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.event_available,
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.7),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ..._events.map(_buildEventCard),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventId = event['id'].toString();
    final title = (event['title'] ?? '').toString();
    final discipline = (event['discipline'] ?? '').toString();
    final location = (event['location'] ?? '').toString();
    final room = (event['room'] ?? '').toString();
    final description = (event['description'] ?? '').toString();
    final capacity = (event['capacity'] as num?)?.toInt() ?? 0;
    final price = (event['price'] as num?)?.toDouble() ?? 0;
    final registered = _registrationCounts[eventId] ?? 0;
    final spotsLeft = (capacity - registered).clamp(0, capacity);
    final isFull = spotsLeft <= 0;
    final isRegistered = _myRegistrations.contains(eventId);
    final isPending = _pendingEventIds.contains(eventId);
    final posterUrl = EventsService.instance.posterUrl(
      event['poster_path'] as String?,
    );
    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(event['event_datetime'].toString()).toLocal();
    } catch (_) {
      dateTime = null;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            child: CustomImageWidget(
              imageUrl: posterUrl,
              width: double.infinity,
              height: 18.h,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: 0.5.h),
                if (dateTime != null)
                  Text(
                    DateFormat(
                      'EEE d MMM yyyy, HH:mm',
                      'it_IT',
                    ).format(dateTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (discipline.isNotEmpty || location.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 0.3.h),
                    child: Text(
                      [
                        if (discipline.isNotEmpty) discipline,
                        if (location.isNotEmpty)
                          room.isNotEmpty ? '$location ($room)' : location,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (description.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 1.h),
                    child: Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Text(
                      isFull
                          ? 'Al completo'
                          : '$spotsLeft/$capacity posti liberi',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isFull
                                ? Colors.red
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      price > 0 ? '€${price.toStringAsFixed(2)}' : 'Gratuito',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                SizedBox(height: 1.5.h),
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(
                    eventId: eventId,
                    isFull: isFull,
                    isRegistered: isRegistered,
                    isPending: isPending,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String eventId,
    required bool isFull,
    required bool isRegistered,
    required bool isPending,
  }) {
    if (isRegistered) {
      return OutlinedButton.icon(
        onPressed: isPending ? null : () => _cancel(eventId),
        icon: isPending
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.close, size: 18),
        label: const Text('Prenotato — Disdici'),
      );
    }
    if (isFull) {
      return ElevatedButton(
        onPressed: null,
        child: const Text('Al completo'),
      );
    }
    return ElevatedButton.icon(
      onPressed: isPending ? null : () => _register(eventId),
      icon: isPending
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.event_available, size: 18),
      label: const Text('Prenota'),
    );
  }
}
