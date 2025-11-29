import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../widgets/main_navigation_wrapper.dart';
import '../../models/class_schedule_model.dart';
import '../../services/class_schedule_service.dart';
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

  // Dynamic data from Supabase
  List<ClassScheduleModel> _allClasses = [];
  List<ClassScheduleModel> _filteredClasses = [];
  final ClassScheduleService _classService = ClassScheduleService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _checkConnectivity();
    _loadClassSchedule();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkConnectivity() {
    setState(() {
      _isOffline = false; // For demo purposes, assume online
    });
  }

  Future<void> _loadClassSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final classes =
          await _classService.getClassScheduleForDate(_selectedDate);

      setState(() {
        _allClasses = classes;
        _isLoading = false;
        _isOffline = false; // Reset offline status on successful load
      });
      _filterClasses();
    } catch (error) {
      print('Error loading class schedule: $error');
      setState(() {
        _isLoading = false;
        _isOffline = true; // Set offline status on error
      });

      // Show user-friendly error message
      Fluttertoast.showToast(
        msg: "Impossibile caricare il palinsesto. Verifica la connessione.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _filterClasses() {
    setState(() {
      if (_selectedFilters.contains('all')) {
        _filteredClasses = List.from(_allClasses);
      } else {
        _filteredClasses = _allClasses.where((classItem) {
          bool matchesType = _selectedFilters.any(
            (filter) =>
                filter.toLowerCase() == classItem.discipline.toLowerCase(),
          );
          bool matchesAvailability = _selectedFilters.contains('available')
              ? classItem.hasAvailableSpots
              : true;
          bool matchesMyClasses = _selectedFilters.contains('my_classes')
              ? classItem.isBooked
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
    _loadClassSchedule();
  }

  void _showBookingModal(ClassScheduleModel classData) {
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
          classData: _convertModelToMap(classData),
          onBookingConfirmed: () {
            _onBookingConfirmed(classData.id);
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _convertModelToMap(ClassScheduleModel model) {
    return {
      'id': model.id,
      'type': model.disciplineDisplayName,
      'instructor': model.instructorName,
      'time': model.timeRange,
      'date': model.dateFormatted,
      'capacity': model.capacity,
      'enrolled': model.enrolled,
      'isBooked': model.isBooked,
      'waitlistPosition': model.waitlistPosition,
      'description': model.description,
      'instructorBio': model.instructorBio,
    };
  }

  Future<void> _onBookingConfirmed(String classId) async {
    final theme = Theme.of(context);

    try {
      final success = await _classService.bookClass(classId);

      if (success) {
        setState(() {
          final classIndex = _allClasses.indexWhere((c) => c.id == classId);
          if (classIndex != -1) {
            _allClasses[classIndex] = _allClasses[classIndex].copyWith(
              isBooked: true,
              enrolled: _allClasses[classIndex].enrolled + 1,
            );
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
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella prenotazione: ${error.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: theme.colorScheme.error,
        textColor: theme.colorScheme.onError,
      );
    }
  }

  Future<void> _onCancelBooking(String classId) async {
    final theme = Theme.of(context);

    try {
      final success = await _classService.cancelBooking(classId);

      if (success) {
        setState(() {
          final classIndex = _allClasses.indexWhere((c) => c.id == classId);
          if (classIndex != -1) {
            _allClasses[classIndex] = _allClasses[classIndex].copyWith(
              isBooked: false,
              enrolled: _allClasses[classIndex].enrolled - 1,
            );
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
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella cancellazione: ${error.toString()}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: theme.colorScheme.error,
        textColor: theme.colorScheme.onError,
      );
    }
  }

  void _showQuickBookingModal() {
    final availableClasses =
        _allClasses.where((c) => c.hasAvailableSpots && !c.isBooked).toList();

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
    await _loadClassSchedule();

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
                                classData: _convertModelToMap(classData),
                                isBooked: classData.isBooked,
                                onTap: () => _showBookingModal(classData),
                                onCancelBooking: () =>
                                    _onCancelBooking(classData.id),
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
              'Non ci sono classi disponibili per i filtri selezionati. Prova a modificare i filtri o seleziona una data diversa.',
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
                  _selectedDate = DateTime.now();
                });
                _loadClassSchedule();
              },
              child: const Text('Mostra Tutte le Classi'),
            ),
          ],
        ),
      ),
    );
  }
}
