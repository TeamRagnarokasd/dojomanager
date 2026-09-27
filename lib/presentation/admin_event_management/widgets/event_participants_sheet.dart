import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../services/events_service.dart';

/// Foglio admin: elenco dei prenotati ('prenotato') a un evento, con nome,
/// "(figlio)" se è un child_profile, e data di prenotazione — letto tramite
/// la RPC admin_event_participants (riservata agli admin).
class EventParticipantsSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventParticipantsSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventParticipantsSheet> createState() =>
      _EventParticipantsSheetState();
}

class _EventParticipantsSheetState extends State<EventParticipantsSheet> {
  List<Map<String, dynamic>>? _participants;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final participants = await EventsService.instance.getParticipants(
        widget.eventId,
      );
      if (mounted) setState(() => _participants = participants);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(
                'Partecipanti — ${widget.eventTitle}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final participants = _participants;
    if (participants == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (participants.isEmpty) {
      return Center(
        child: Text(
          'Nessun prenotato per questo evento.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final name = (participant['full_name'] ?? 'Utente').toString();
        final isChild = participant['is_child'] as bool? ?? false;
        DateTime? registeredAt;
        try {
          registeredAt = DateTime.parse(
            participant['registered_at'].toString(),
          ).toLocal();
        } catch (_) {}

        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(isChild ? '$name (figlio)' : name),
          subtitle: registeredAt == null
              ? null
              : Text(
                  'Prenotato il ${DateFormat('d MMM yyyy, HH:mm', 'it_IT').format(registeredAt)}',
                ),
        );
      },
    );
  }
}
