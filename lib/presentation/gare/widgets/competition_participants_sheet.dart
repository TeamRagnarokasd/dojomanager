import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/competitions_service.dart';

/// Foglio admin: chi ha segnato "Voglio farla" e chi "Mi sono iscritto" per
/// una gara, con nome e "(figlio)" se è un child_profile — letto tramite la
/// RPC admin_competition_participants (riservata agli admin). Un
/// partecipante può comparire in entrambi i gruppi.
class CompetitionParticipantsSheet extends StatefulWidget {
  final String competitionId;
  final String competitionName;

  const CompetitionParticipantsSheet({
    super.key,
    required this.competitionId,
    required this.competitionName,
  });

  @override
  State<CompetitionParticipantsSheet> createState() =>
      _CompetitionParticipantsSheetState();
}

class _CompetitionParticipantsSheetState
    extends State<CompetitionParticipantsSheet> {
  List<Map<String, dynamic>>? _participants;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final participants = await CompetitionsService.instance.getParticipants(
        widget.competitionId,
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
                'Partecipanti — ${widget.competitionName}',
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

    final interested = participants
        .where((p) => p['interested'] as bool? ?? false)
        .toList();
    final selfRegistered = participants
        .where((p) => p['self_registered'] as bool? ?? false)
        .toList();

    if (interested.isEmpty && selfRegistered.isEmpty) {
      return Center(
        child: Text(
          'Nessun interesse o iscrizione per questa gara.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      children: [
        _buildGroupHeader('Vogliono farla (${interested.length})'),
        if (interested.isEmpty)
          _buildEmptyGroupLabel()
        else
          ...interested.map(_buildParticipantTile),
        SizedBox(height: 1.h),
        _buildGroupHeader('Già iscritti (${selfRegistered.length})'),
        if (selfRegistered.isEmpty)
          _buildEmptyGroupLabel()
        else
          ...selfRegistered.map(_buildParticipantTile),
      ],
    );
  }

  Widget _buildGroupHeader(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0.5.h),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildEmptyGroupLabel() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        'Nessuno',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final name = (participant['full_name'] ?? 'Utente').toString();
    final isChild = participant['is_child'] as bool? ?? false;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.person_outline),
      title: Text(isChild ? '$name (figlio)' : name),
    );
  }
}
