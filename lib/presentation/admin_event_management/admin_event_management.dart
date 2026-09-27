import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../services/discipline_service.dart';
import '../../services/events_service.dart';
import './widgets/event_form_sheet.dart';
import './widgets/event_list_item.dart';
import './widgets/event_participants_sheet.dart';

/// Gestione Eventi e Seminari, collegata a `events_seminars` /
/// `event_registrations` (nessun dato finto, nessuna simulazione: ogni
/// azione qui scrive davvero sul database).
class AdminEventManagement extends StatefulWidget {
  const AdminEventManagement({super.key});

  @override
  State<AdminEventManagement> createState() => _AdminEventManagementState();
}

class _AdminEventManagementState extends State<AdminEventManagement> {
  List<Map<String, dynamic>> _events = [];
  Map<String, int> _registrationCounts = {};
  List<String> _disciplines = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDisciplines();
    _loadEvents();
  }

  Future<void> _loadDisciplines() async {
    try {
      final disciplines = await DisciplineService.instance
          .getActiveDisciplines();
      if (mounted) {
        setState(() {
          _disciplines = disciplines
              .map((d) => (d['name'] ?? d['id'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      // La lista disciplina resta vuota — il form funziona comunque.
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await EventsService.instance.getEvents();
      final counts = await EventsService.instance.getRegistrationCounts();
      if (!mounted) return;
      setState(() {
        _events = events;
        _registrationCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossibile caricare gli eventi.';
        _isLoading = false;
      });
    }
  }

  void _openCreateForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventFormSheet(
        disciplines: _disciplines,
        onSaved: _loadEvents,
      ),
    );
  }

  void _openEditForm(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventFormSheet(
        existingEvent: event,
        disciplines: _disciplines,
        onSaved: _loadEvents,
      ),
    );
  }

  void _showParticipants(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventParticipantsSheet(
        eventId: event['id'].toString(),
        eventTitle: (event['title'] ?? '').toString(),
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> event) async {
    final currentStatus = (event['status'] ?? 'pubblicato').toString();
    final newStatus = currentStatus == 'pubblicato' ? 'annullato' : 'pubblicato';
    try {
      await EventsService.instance.updateEvent(
        event['id'].toString(),
        {'status': newStatus},
      );
      _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Evento'),
        content: Text(
          'Sei sicuro di voler eliminare "${event['title']}"?\n'
          'Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await EventsService.instance.deleteEvent(event['id'].toString());
      _loadEvents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione Eventi')),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Evento'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          SizedBox(height: 20.h),
          Center(
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }
    if (_events.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 15.h),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_note,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Nessun evento creato',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 1.h),
                Text(
                  'Tocca + per creare il primo evento',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final eventId = event['id'].toString();
        return EventListItem(
          event: event,
          registeredCount: _registrationCounts[eventId] ?? 0,
          posterUrl: EventsService.instance.posterUrl(
            event['poster_path'] as String?,
          ),
          onEdit: () => _openEditForm(event),
          onDelete: () => _deleteEvent(event),
          onToggleStatus: () => _toggleStatus(event),
          onShowParticipants: () => _showParticipants(event),
        );
      },
    );
  }
}
