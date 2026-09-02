import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../services/discipline_service.dart';
import './widgets/event_calendar_widget.dart';
import './widgets/event_card_widget.dart';
import './widgets/event_creation_form_widget.dart';
import './widgets/event_management_header_widget.dart';

class AdminEventManagement extends StatefulWidget {
  const AdminEventManagement({super.key});

  @override
  State<AdminEventManagement> createState() => _AdminEventManagementState();
}

class _AdminEventManagementState extends State<AdminEventManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Event management state
  List<Map<String, dynamic>> specialEvents = [
    {
      'id': '1',
      'title': 'Seminario BJJ con Maestro Silva',
      'type': 'seminario',
      'date': DateTime(2024, 12, 15),
      'time': '14:00 - 18:00',
      'instructor': 'Marco Silva',
      'instructorId': 'silva_001',
      'venue': 'Sala BJJ secondo piano',
      'capacity': 20,
      'registered': 15,
      'price': 35.0,
      'description':
          'Seminario intensivo sulle tecniche di guardia nel Brazilian Jiu-Jitsu',
      'image':
          'https://images.unsplash.com/photo-1555597408-966dcdc2b8b0?w=400',
      'status': 'active',
      'priority': 'high',
      'category': 'BJJ',
      'requirements': 'Almeno 6 mesi di pratica',
      'equipment': 'Gi obbligatorio, protezioni facoltative',
    },
    {
      'id': '2',
      'title': 'Stage MMA Combat Conditioning',
      'type': 'stage',
      'date': DateTime(2024, 12, 22),
      'time': '10:00 - 16:00',
      'instructor': 'Dmitri Volkov',
      'instructorId': 'volkov_001',
      'venue': 'Gabbia MMA',
      'capacity': 12,
      'registered': 8,
      'price': 50.0,
      'description':
          'Intensivo di condizionamento fisico e tecniche di striking per MMA',
      'image':
          'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=400',
      'status': 'active',
      'priority': 'medium',
      'category': 'MMA',
      'requirements': 'Livello intermedio-avanzato',
      'equipment': 'Guantini, paratibie, paradenti',
    },
  ];

  // UI state
  String selectedFilter = 'all';
  DateTime selectedMonth = DateTime.now();
  bool isCreatingEvent = false;

  // Disciplines loaded from Supabase
  List<String> _dynamicDisciplines = [];

  final List<String> eventFilters = [
    'all',
    'seminari',
    'stage',
    'active',
    'upcoming',
  ];
  final List<String> availableInstructors = [
    'Marco Silva - BJJ',
    'Elena Rossi - BJJ',
    'Dmitri Volkov - MMA',
    'Ana Santos - MMA',
    'Igor Petrov - SAMBO',
    'Carlos Mendez - Grappling',
    'Sofia Andersson - Grappling',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDisciplines();
  }

  Future<void> _loadDisciplines() async {
    try {
      final disciplines = await DisciplineService.instance
          .getActiveDisciplines();
      if (mounted) {
        setState(() {
          _dynamicDisciplines = disciplines
              .map((d) => (d['name'] ?? d['id'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      // Silently fail — disciplines list will be empty, form still works
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'admin_event.title'.tr(),
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Add seasonal schedule access button
          Container(
            margin: EdgeInsets.only(right: 4.w),
            child: IconButton(
              onPressed: _navigateToSeasonalSchedule,
              icon: Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.calendar_view_month,
                  color: Color(0xFFFF0000),
                  size: 20,
                ),
              ),
              tooltip: 'Pianificazione Stagionale',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'admin_event.tab_list'.tr()),
            Tab(text: 'admin_event.tab_calendar'.tr()),
          ],
          indicatorColor: const Color(0xFFFF0000),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage(AppConstants.teamLogo),
            fit: BoxFit.contain,
            alignment: Alignment.center,
            opacity: 0.1,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [_buildEventsList(), _buildEventsCalendar()],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Seasonal Schedule Management FAB
          Container(
            margin: EdgeInsets.only(bottom: 2.h),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _navigateToSeasonalSchedule,
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              heroTag: "seasonal_schedule",
              child: const Icon(Icons.calendar_view_month),
              tooltip: 'Pianificazione Stagionale',
            ),
          ),

          // Main Create Event FAB
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _showCreateEventDialog,
              backgroundColor: const Color(0xFFFF0000),
              foregroundColor: Colors.white,
              heroTag: "create_event",
              icon: const Icon(Icons.add),
              label: Text('admin_event.new_event'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    final filteredEvents = _getFilteredEvents();

    return Column(
      children: [
        // Add Seasonal Schedule Management section
        _buildSeasonalScheduleAccessCard(),

        // Header with filters and stats
        EventManagementHeaderWidget(
          eventCount: specialEvents.length,
          selectedFilter: selectedFilter,
          filters: eventFilters,
          onFilterChanged: (filter) {
            setState(() => selectedFilter = filter);
          },
          selectedMonth: selectedMonth,
          onMonthChanged: (month) {
            setState(() => selectedMonth = month);
          },
        ),

        // Events list
        Expanded(
          child: filteredEvents.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: EdgeInsets.all(4.w),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return EventCardWidget(
                      event: event,
                      onEdit: () => _editEvent(event['id']),
                      onDuplicate: () => _duplicateEvent(event['id']),
                      onDelete: () => _deleteEvent(event['id']),
                      onViewAttendees: () => _viewAttendees(event['id']),
                      onToggleStatus: () => _toggleEventStatus(event['id']),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSeasonalScheduleAccessCard() {
    return Container(
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[600]!.withValues(alpha: 0.2),
            Colors.orange[800]!.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange[600]!.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.orange[600]!.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_view_month,
                  color: Colors.orange[400],
                  size: 24,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin_event.seasonal_planning_title'.tr(),
                      style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'admin_event.seasonal_planning_subtitle'.tr(),
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToSeasonalSchedule,
                  icon: const Icon(Icons.calendar_view_month, size: 18),
                  label: Text('admin_event.open_schedule'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange[600]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _showSeasonalScheduleInfo(),
                  icon: Icon(
                    Icons.info_outline,
                    color: Colors.orange[600],
                    size: 20,
                  ),
                  tooltip: 'admin_event.seasonal_info_tooltip'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsCalendar() {
    return EventCalendarWidget(
      events: specialEvents,
      selectedDate: selectedMonth,
      onDateSelected: (date) {
        setState(() => selectedMonth = date);
      },
      onEventTap: (eventId) => _editEvent(eventId),
      onDateTap: (date) => _quickCreateEvent(date),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 80, color: Colors.grey[600]),
          SizedBox(height: 2.h),
          Text(
            'admin_event.no_events_found'.tr(),
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'admin_event.create_first_event'.tr(),
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'admin_event.use_seasonal_schedule'.tr(),
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: Colors.orange[400],
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _navigateToSeasonalSchedule,
                icon: const Icon(Icons.calendar_view_month),
                label: Text('admin_event_ui.schedule'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 1.5.h,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              ElevatedButton.icon(
                onPressed: _showCreateEventDialog,
                icon: const Icon(Icons.add),
                label: Text('admin_event_ui.create_event'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 1.5.h,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredEvents() {
    return specialEvents.where((event) {
      // Filter by category
      if (selectedFilter == 'seminari' && event['type'] != 'seminario')
        return false;
      if (selectedFilter == 'stage' && event['type'] != 'stage') return false;
      if (selectedFilter == 'active' && event['status'] != 'active')
        return false;
      if (selectedFilter == 'upcoming' &&
          event['date'].isBefore(DateTime.now()))
        return false;

      // Filter by month
      if (event['date'].month != selectedMonth.month ||
          event['date'].year != selectedMonth.year) {
        return false;
      }

      return true;
    }).toList()..sort((a, b) => a['date'].compareTo(b['date']));
  }

  void _showCreateEventDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventCreationFormWidget(
        availableInstructors: availableInstructors,
        disciplines: _dynamicDisciplines,
        onSave: (eventData) {
          _createEvent(eventData);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _quickCreateEvent(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventCreationFormWidget(
        initialDate: date,
        availableInstructors: availableInstructors,
        disciplines: _dynamicDisciplines,
        onSave: (eventData) {
          _createEvent(eventData);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _createEvent(Map<String, dynamic> eventData) {
    final newEvent = {
      ...eventData,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'registered': 0,
      'status': 'active',
    };

    setState(() {
      specialEvents.add(newEvent);
    });

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${eventData['title']} creato con successo'),
        backgroundColor: const Color(0xFFFF0000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _editEvent(String eventId) {
    final event = specialEvents.firstWhere((e) => e['id'] == eventId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventCreationFormWidget(
        existingEvent: event,
        availableInstructors: availableInstructors,
        disciplines: _dynamicDisciplines,
        onSave: (eventData) {
          _updateEvent(eventId, eventData);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _updateEvent(String eventId, Map<String, dynamic> eventData) {
    setState(() {
      final index = specialEvents.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        specialEvents[index] = {...specialEvents[index], ...eventData};
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${eventData['title']} aggiornato'),
        backgroundColor: AppTheme.successLight,
      ),
    );
  }

  void _duplicateEvent(String eventId) {
    final event = specialEvents.firstWhere((e) => e['id'] == eventId);
    final duplicatedEvent = {
      ...Map<String, dynamic>.from(event),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': '${event['title']} (Copia)',
      'registered': 0,
      'date': DateTime.now().add(const Duration(days: 7)),
    };

    setState(() {
      specialEvents.add(duplicatedEvent);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Evento duplicato: ${duplicatedEvent['title']}'),
        backgroundColor: AppTheme.successLight,
      ),
    );
  }

  void _deleteEvent(String eventId) {
    final event = specialEvents.firstWhere((e) => e['id'] == eventId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Elimina Evento', style: TextStyle(color: Colors.white)),
        content: Text(
          'Sei sicuro di voler eliminare "${event['title']}"?\nQuesta azione non può essere annullata.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                specialEvents.removeWhere((e) => e['id'] == eventId);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${event['title']} eliminato'),
                  backgroundColor: AppTheme.errorLight,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorLight,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _toggleEventStatus(String eventId) {
    setState(() {
      final index = specialEvents.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        final currentStatus = specialEvents[index]['status'];
        specialEvents[index]['status'] = currentStatus == 'active'
            ? 'inactive'
            : 'active';
      }
    });
  }

  void _viewAttendees(String eventId) {
    final event = specialEvents.firstWhere((e) => e['id'] == eventId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 70.h,
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Partecipanti - ${event['title']}',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Iscritti: ${event['registered']}/${event['capacity']}',
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
            ),
            SizedBox(height: 2.h),
            Expanded(
              child: Center(
                child: Text(
                  'Elenco partecipanti sarà disponibile\npresto con integrazione database',
                  textAlign: TextAlign.center,
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation method for seasonal schedule
  void _navigateToSeasonalSchedule() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/seasonal-schedule-creation');
  }

  // Info method for seasonal schedule
  void _showSeasonalScheduleInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.only(bottom: 3.h),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.orange[600]!.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_view_month,
                    color: Colors.orange[400],
                    size: 28,
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Pianificazione Stagionale',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              'admin_event.features_available'.tr(),
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            _buildInfoItem(
              Icons.schedule,
              'admin_event.weekly_schema'.tr(),
              'admin_event.weekly_schema_desc'.tr(),
            ),
            _buildInfoItem(
              Icons.event_busy,
              'admin_event.holiday_management'.tr(),
              'admin_event.holiday_management_desc'.tr(),
            ),
            _buildInfoItem(
              Icons.auto_awesome,
              'admin_event.auto_generation'.tr(),
              'admin_event.auto_generation_desc'.tr(),
            ),
            _buildInfoItem(
              Icons.preview,
              'admin_event.full_preview'.tr(),
              'admin_event.full_preview_desc'.tr(),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToSeasonalSchedule();
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text('admin_event_ui.access_schedule'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.orange[600]!.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.orange[400], size: 20),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  description,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
