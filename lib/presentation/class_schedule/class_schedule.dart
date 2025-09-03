import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/booking_modal_widget.dart';
import './widgets/class_card_widget.dart';
import './widgets/filter_chips_widget.dart';
import './widgets/quick_booking_fab_widget.dart';
import './widgets/weekly_calendar_widget.dart';

class ClassSchedule extends StatefulWidget {
  const ClassSchedule({Key? key}) : super(key: key);

  @override
  State<ClassSchedule> createState() => _ClassScheduleState();
}

class _ClassScheduleState extends State<ClassSchedule>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedFilters = ['all'];
  bool _isLoading = false;
  bool _isOffline = false;

  // Mock data for classes
  final List<Map<String, dynamic>> _allClasses = [
    {
      "id": 1,
      "type": "Karate",
      "instructor": "Marco Rossi",
      "time": "09:00 - 10:30",
      "date": "29/08/2025",
      "capacity": 20,
      "enrolled": 15,
      "isBooked": false,
      "description":
          "Corso di Karate tradizionale per principianti e intermedi. Focus su tecniche di base, kata e kumite.",
      "instructorBio":
          "Marco Rossi è un maestro di Karate con 15 anni di esperienza. Cintura nera 4° dan, ha partecipato a numerose competizioni nazionali.",
    },
    {
      "id": 2,
      "type": "Judo",
      "instructor": "Anna Bianchi",
      "time": "11:00 - 12:30",
      "date": "29/08/2025",
      "capacity": 16,
      "enrolled": 16,
      "isBooked": false,
      "waitlistPosition": 3,
      "description":
          "Allenamento di Judo con focus su tecniche di proiezione e controllo a terra.",
      "instructorBio":
          "Anna Bianchi, cintura nera 3° dan, specializzata in tecniche di Ne-waza e preparazione atletica.",
    },
    {
      "id": 3,
      "type": "Taekwondo",
      "instructor": "Giuseppe Verdi",
      "time": "15:00 - 16:30",
      "date": "29/08/2025",
      "capacity": 18,
      "enrolled": 12,
      "isBooked": true,
      "description":
          "Corso di Taekwondo con enfasi su tecniche di calcio e forme (poomsae).",
      "instructorBio":
          "Giuseppe Verdi, maestro di Taekwondo WTF, ha allenato diversi atleti a livello nazionale e internazionale.",
    },
    {
      "id": 4,
      "type": "Karate",
      "instructor": "Lucia Ferrari",
      "time": "17:30 - 19:00",
      "date": "29/08/2025",
      "capacity": 22,
      "enrolled": 8,
      "isBooked": false,
      "description":
          "Karate avanzato con focus su applicazioni pratiche e autodifesa.",
      "instructorBio":
          "Lucia Ferrari, cintura nera 5° dan, specializzata in Karate applicato e difesa personale femminile.",
    },
    {
      "id": 5,
      "type": "Judo",
      "instructor": "Roberto Conti",
      "time": "19:30 - 21:00",
      "date": "29/08/2025",
      "capacity": 20,
      "enrolled": 18,
      "isBooked": false,
      "description":
          "Judo competitivo per atleti esperti. Preparazione per gare regionali.",
      "instructorBio":
          "Roberto Conti, ex atleta nazionale di Judo, ora dedito all'insegnamento e alla preparazione di giovani talenti.",
    },
  ];

  List<Map<String, dynamic>> _filteredClasses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _filteredClasses = List.from(_allClasses);
    _checkConnectivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkConnectivity() {
    // Simulate connectivity check
    setState(() {
      _isOffline = false; // For demo purposes, assume online
    });
  }

  void _filterClasses() {
    setState(() {
      if (_selectedFilters.contains('all')) {
        _filteredClasses = List.from(_allClasses);
      } else {
        _filteredClasses = _allClasses.where((classItem) {
          bool matchesType = _selectedFilters.any(
            (filter) =>
                filter.toLowerCase() ==
                (classItem['type'] as String).toLowerCase(),
          );
          bool matchesAvailability = _selectedFilters.contains('available')
              ? (classItem['enrolled'] as int) < (classItem['capacity'] as int)
              : true;
          bool matchesMyClasses = _selectedFilters.contains('my_classes')
              ? classItem['isBooked'] as bool
              : true;

          return (matchesType ||
                  _selectedFilters.contains('available') ||
                  _selectedFilters.contains('my_classes')) &&
              matchesAvailability &&
              matchesMyClasses;
        }).toList();
      }
    });
  }

  void _onFilterToggle(String filter) {
    setState(() {
      if (filter == 'all') {
        _selectedFilters = ['all'];
      } else {
        _selectedFilters.remove('all');
        if (_selectedFilters.contains(filter)) {
          _selectedFilters.remove(filter);
        } else {
          _selectedFilters.add(filter);
        }
        if (_selectedFilters.isEmpty) {
          _selectedFilters = ['all'];
        }
      }
    });
    _filterClasses();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    // In a real app, you would fetch classes for the selected date
  }

  void _showBookingModal(Map<String, dynamic> classData) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => BookingModalWidget(
          classData: classData,
          onBookingConfirmed: () {
            _onBookingConfirmed(classData['id'] as int);
          },
        ),
      ),
    );
  }

  void _onBookingConfirmed(int classId) {
    final theme = Theme.of(context);

    setState(() {
      final classIndex = _allClasses.indexWhere((c) => c['id'] == classId);
      if (classIndex != -1) {
        _allClasses[classIndex]['isBooked'] = true;
        _allClasses[classIndex]['enrolled'] =
            (_allClasses[classIndex]['enrolled'] as int) + 1;
      }
    });
    _filterClasses();

    Fluttertoast.showToast(
      msg: "Prenotazione confermata!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: theme.colorScheme.tertiary,
      textColor: theme.colorScheme.onTertiary,
    );
  }

  void _onCancelBooking(int classId) {
    final theme = Theme.of(context);

    setState(() {
      final classIndex = _allClasses.indexWhere((c) => c['id'] == classId);
      if (classIndex != -1) {
        _allClasses[classIndex]['isBooked'] = false;
        _allClasses[classIndex]['enrolled'] =
            (_allClasses[classIndex]['enrolled'] as int) - 1;
      }
    });
    _filterClasses();

    Fluttertoast.showToast(
      msg: "Prenotazione cancellata",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: theme.colorScheme.error,
      textColor: theme.colorScheme.onError,
    );
  }

  void _showQuickBookingModal() {
    final availableClasses = _allClasses
        .where(
          (c) =>
              (c['enrolled'] as int) < (c['capacity'] as int) &&
              !(c['isBooked'] as bool),
        )
        .toList();

    if (availableClasses.isEmpty) {
      Fluttertoast.showToast(
        msg: "Nessuna classe disponibile al momento",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    final nextClass = availableClasses.first;
    _showBookingModal(nextClass);
  }

  Future<void> _refreshSchedule() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    Fluttertoast.showToast(
      msg: "Orario aggiornato",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MainNavigationWrapper(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Orario Classi',
            style: theme.textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            if (_isOffline)
              Padding(
                padding: EdgeInsets.only(right: 2.w),
                child: CustomIconWidget(
                  iconName: 'cloud_off',
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              ),
            IconButton(
              onPressed: _refreshSchedule,
              icon: CustomIconWidget(
                iconName: 'refresh',
                color: theme.primaryColor,
                size: 24,
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshSchedule,
          color: theme.primaryColor,
          child: Column(
            children: [
              // Calendar widget
              WeeklyCalendarWidget(
                selectedDate: _selectedDate,
                onDateSelected: _onDateSelected,
              ),

              SizedBox(height: 2.h),

              // Filter chips
              FilterChipsWidget(
                selectedFilters: _selectedFilters,
                onFilterToggle: _onFilterToggle,
              ),

              SizedBox(height: 1.h),

              // Classes list
              Expanded(
                child: _isLoading
                    ? _buildLoadingSkeleton()
                    : _filteredClasses.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: 10.h),
                            itemCount: _filteredClasses.length,
                            itemBuilder: (context, index) {
                              final classData = _filteredClasses[index];
                              return ClassCardWidget(
                                classData: classData,
                                isBooked: classData['isBooked'] as bool,
                                onTap: () => _showBookingModal(classData),
                                onCancelBooking: () =>
                                    _onCancelBooking(classData['id'] as int),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        floatingActionButton: QuickBookingFabWidget(
          onPressed: _showQuickBookingModal,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.symmetric(vertical: 1.h),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              SizedBox(height: 2.h),
              Container(
                width: 40.w,
                height: 2.h,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 1.h),
              Container(
                width: 60.w,
                height: 2.h,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'event_busy',
              color: theme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            SizedBox(height: 3.h),
            Text(
              'Nessuna Classe Programmata',
              style: theme.textTheme.headlineSmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            Text(
              'Non ci sono classi disponibili per i filtri selezionati. Prova a modificare i filtri o contatta l\'amministrazione.',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedFilters = ['all'];
                });
                _filterClasses();
              },
              child: Text('Mostra Tutte le Classi'),
            ),
          ],
        ),
      ),
    );
  }
}
