import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/class_schedule_model.dart';
import '../../services/class_schedule_service.dart';
import '../../services/discipline_service.dart';
import '../../services/realtime_notification_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/booking_modal_widget.dart';
import './widgets/class_card_widget.dart';
import './widgets/filter_chips_widget.dart';
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

  // Dynamic disciplines loaded from Supabase
  List<String> _availableDisciplines = [];

  // My bookings
  List<Map<String, dynamic>> _myBookings = [];
  bool _isLoadingBookings = false;
  bool _showMyBookings = true;
  Map<String, dynamic>? _entryBasedInfo;

  // Realtime subscription for schedule changes
  StreamSubscription<RealtimeDataChangeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 1);
    _checkConnectivity();
    _loadDisciplines();
    _loadClassSchedule();
    _loadMyBookings();
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    RealtimeNotificationService.instance.subscribeToAdminDataChanges();

    _realtimeSubscription =
        RealtimeNotificationService.instance.dataChangeStream
            .where(
      (event) =>
          event.type == RealtimeDataChangeType.scheduleTemplates ||
          event.type == RealtimeDataChangeType.scheduleInstances,
    )
            .listen((_) {
      if (mounted && !_isLoading) {
        _loadClassSchedule();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _checkConnectivity() {
    setState(() {
      _isOffline = false; // For demo purposes, assume online
    });
  }

  Future<void> _loadDisciplines() async {
    try {
      final disciplines =
          await DisciplineService.instance.getActiveDisciplines();
      if (!mounted) return;
      final names = disciplines
          .map((d) => (d['name'] as String?) ?? (d['id'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _availableDisciplines = names;
      });
    } catch (e) {
      // Silently fail — filter will just show 'Tutti'
    }
  }

  Future<void> _loadClassSchedule() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final classes = await _classService.getClassScheduleForDate(
        _selectedDate,
      );

      if (!mounted) return;
      setState(() {
        _allClasses = classes;
        _isLoading = false;
        _isOffline = false;
      });
      _filterClasses();
    } catch (error) {
      print('Error loading class schedule: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });

      Fluttertoast.showToast(
        msg: 'class_schedule.load_error'.tr(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _loadMyBookings() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBookings = true;
    });
    try {
      final bookings = await _classService.getUserRegistrations(
        status: 'registered',
      );
      final entryInfo = await _classService.getEntryBasedInfo();
      if (!mounted) return;
      setState(() {
        _myBookings = bookings;
        _entryBasedInfo = entryInfo;
        _isLoadingBookings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBookings = false;
      });
    }
  }

  void _filterClasses() {
    if (!mounted) return;
    setState(() {
      if (_selectedFilters.contains('all')) {
        _filteredClasses = List.from(_allClasses);
      } else {
        _filteredClasses = _allClasses.where((classItem) {
          bool matchesType = _selectedFilters.any(
            (filter) =>
                filter.toLowerCase() == classItem.discipline.toLowerCase() ||
                filter.toLowerCase() ==
                    classItem.disciplineDisplayName.toLowerCase(),
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
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() {
      _selectedDate = date;
    });
    _loadClassSchedule();
  }

  void _showBookingModal(ClassScheduleModel classData) async {
    final theme = Theme.of(context);

    // Check booking eligibility before showing modal
    // 🔥 CRITICAL: Pass schedule instance ID instead of discipline for RPC function
    final eligibility = await _classService.checkBookingEligibility(
      classData.id, // Pass instance ID for RPC function
    );

    if (!(eligibility['allowed'] ?? false)) {
      // Show denial alert dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.block, color: theme.colorScheme.error, size: 28),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'class_schedule.access_denied_title'.tr(),
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            eligibility['reason'] ?? 'class_schedule.cannot_book_fallback'.tr(),
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Pass entry balance info to the modal
    final classMap = _convertModelToMap(classData);
    if (eligibility['booking_type'] == 'entry_based') {
      classMap['booking_type'] = 'entry_based';
      classMap['entries_remaining'] = eligibility['entries_remaining'];
    }

    // If eligible, show booking modal
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
          classData: classMap,
          onBookingConfirmed: () => _onBookingConfirmed(classData),
        ),
      ),
    );
  }

  Map<String, dynamic> _convertModelToMap(ClassScheduleModel model) {
    // Ensure discipline display name is never empty
    final rawDisplayName = model.disciplineDisplayName.trim();
    final displayName = rawDisplayName.isNotEmpty
        ? rawDisplayName
        : model.discipline.isNotEmpty
            ? model.discipline.toUpperCase()
            : 'BJJ';

    return {
      'id': model.id,
      'type': displayName,
      'discipline_color': model.disciplineColor,
      'instructor': model.instructorName,
      'time': model.timeRange,
      'date': model.dateFormatted,
      'capacity': model.capacity,
      'enrolled': model.enrolled,
      'isBooked': model.isBooked,
      'waitlistPosition': model.waitlistPosition,
      'description': model.description,
      'instructorBio': model.instructorBio,
      'location': model.location.isNotEmpty ? model.location : 'Palestra',
    };
  }

  Future<bool> _onBookingConfirmed(ClassScheduleModel classData) async {
    final theme = Theme.of(context);

    try {
      final result = await _classService.bookClass(
        classData.id,
        classModel: classData,
      );

      if (result['success'] == true) {
        await _loadClassSchedule();
        await _loadMyBookings();

        if (mounted) {
          final entryDeducted = result['entry_deducted'] as bool? ?? false;
          final entriesRemaining = result['entries_remaining'] as int?;

          String message = 'class_schedule.booking_success'.tr();
          if (entryDeducted && entriesRemaining != null) {
            message = entriesRemaining > 0
                ? 'Prenotazione confermata! Ingressi rimanenti: $entriesRemaining'
                : 'Prenotazione confermata! Ultimo ingresso utilizzato.';
          }

          Fluttertoast.showToast(
            msg: message,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: theme.colorScheme.tertiary,
            textColor: theme.colorScheme.onTertiary,
          );
        }
        return true;
      } else {
        if (mounted) {
          final error = result['error'] as String? ??
              'class_schedule.booking_failed_detail'.tr();
          Fluttertoast.showToast(
            msg: error,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: theme.colorScheme.error,
            textColor: theme.colorScheme.onError,
          );
        }
        return false;
      }
    } catch (error) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Errore nella prenotazione: ${error.toString()}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: theme.colorScheme.error,
          textColor: theme.colorScheme.onError,
        );
      }
      return false;
    }
  }

  Future<void> _onCancelBooking(String classId) async {
    final theme = Theme.of(context);

    try {
      final result = await _classService.cancelBooking(classId);

      if (result['success'] == true) {
        await _loadClassSchedule();
        await _loadMyBookings();

        if (mounted) {
          final entryRefunded = result['entry_refunded'] as bool? ?? false;
          final entriesRemaining = result['entries_remaining'] as int?;

          String message = 'class_schedule.cancellation_confirmed'.tr();
          if (entryRefunded && entriesRemaining != null) {
            message =
                'Prenotazione cancellata. Ingresso rimborsato (rimanenti: $entriesRemaining)';
          }

          Fluttertoast.showToast(
            msg: message,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
          );
        }
      } else {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'class_schedule.cancellation_failed'.tr(),
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: theme.colorScheme.error,
            textColor: theme.colorScheme.onError,
          );
        }
      }
    } catch (error) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Errore nella cancellazione: ${error.toString()}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: theme.colorScheme.error,
          textColor: theme.colorScheme.onError,
        );
      }
    }
  }

  void _showQuickBookingModal() {
    final availableClasses =
        _allClasses.where((c) => c.hasAvailableSpots && !c.isBooked).toList();

    if (availableClasses.isEmpty) {
      Fluttertoast.showToast(
        msg: 'class_schedule.no_classes_available'.tr(),
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
    await _loadMyBookings();

    Fluttertoast.showToast(
      msg: 'class_schedule.schedule_updated'.tr(),
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
            'class_schedule.title'.tr(),
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
          child: CustomScrollView(
            slivers: [
              // Calendar widget
              SliverToBoxAdapter(
                child: WeeklyCalendarWidget(
                  selectedDate: _selectedDate,
                  onDateSelected: _onDateSelected,
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 2.h)),

              // Filter chips
              SliverToBoxAdapter(
                child: FilterChipsWidget(
                  selectedFilters: _selectedFilters,
                  onFilterToggle: _onFilterToggle,
                  availableDisciplines: _availableDisciplines,
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 1.h)),

              // Classes list or loading/empty state
              if (_isLoading)
                SliverToBoxAdapter(child: _buildLoadingSkeleton())
              else if (_filteredClasses.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final classData = _filteredClasses[index];
                    return ClassCardWidget(
                      classData: _convertModelToMap(classData),
                      isBooked: classData.isBooked,
                      onTap: () => _showBookingModal(classData),
                      onCancelBooking: () => _onCancelBooking(classData.id),
                    );
                  }, childCount: _filteredClasses.length),
                ),

              SliverToBoxAdapter(child: SizedBox(height: 1.h)),

              // My Bookings section — scrolls with the page
              SliverToBoxAdapter(child: _buildMyBookingsSection(theme)),

              SliverToBoxAdapter(child: SizedBox(height: 2.h)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyBookingsSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            onTap: () {
              setState(() {
                _showMyBookings = !_showMyBookings;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'event_available',
                    color: theme.primaryColor,
                    size: 22,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Le Mie Prenotazioni',
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (_entryBasedInfo != null)
                          Text(
                            '${_entryBasedInfo!['entries_remaining']} ingressi rimasti',
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: (_entryBasedInfo!['entries_remaining']
                                          as int) ==
                                      0
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_myBookings.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.4.h,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_myBookings.length}',
                        style: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(width: 2.w),
                  CustomIconWidget(
                    iconName: _showMyBookings
                        ? 'keyboard_arrow_down'
                        : 'keyboard_arrow_up',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Bookings list (collapsible)
          if (_showMyBookings)
            _isLoadingBookings
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    child: SizedBox(
                      height: 3.h,
                      width: 3.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor,
                      ),
                    ),
                  )
                : _myBookings.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(
                          left: 4.w,
                          right: 4.w,
                          bottom: 2.h,
                        ),
                        child: Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'info_outline',
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'Nessuna prenotazione attiva',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: 4.w,
                          right: 4.w,
                          bottom: 2.h,
                        ),
                        itemCount: _myBookings.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, index) {
                          return _buildBookingItem(theme, _myBookings[index]);
                        },
                      ),
        ],
      ),
    );
  }

  Widget _buildBookingItem(ThemeData theme, Map<String, dynamic> booking) {
    final instance = booking['schedule_instances'] as Map<String, dynamic>?;
    if (instance == null) return const SizedBox.shrink();

    final discipline = instance['discipline']?.toString() ?? '';
    final displayDiscipline =
        discipline.isNotEmpty ? discipline.toUpperCase() : 'Classe';
    final startTime = instance['start_time']?.toString() ?? '';
    final endTime = instance['end_time']?.toString() ?? '';
    final timeRange = (startTime.isNotEmpty && endTime.isNotEmpty)
        ? '$startTime - $endTime'
        : startTime;
    final classDate = instance['class_date']?.toString() ?? '';
    final formattedDate = _formatBookingDate(classDate);
    final instructorName =
        (instance['user_profiles'] as Map<String, dynamic>?)?['full_name']
                ?.toString() ??
            '';

    // Schedule instance ID for cancellation
    final instanceId = instance['id']?.toString() ?? '';

    // Discipline color accent
    final Color disciplineColor = _getDisciplineColor(theme, discipline);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        children: [
          // Colored discipline indicator
          Container(
            width: 1.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: disciplineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: disciplineColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        displayDiscipline,
                        style: theme.textTheme.labelSmall!.copyWith(
                          color: disciplineColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.4.h),
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'schedule',
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 14,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      timeRange,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11.sp,
                      ),
                    ),
                    if (instructorName.isNotEmpty) ...[
                      SizedBox(width: 3.w),
                      CustomIconWidget(
                        iconName: 'person',
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 14,
                      ),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          instructorName,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          CustomIconWidget(
            iconName: 'check_circle',
            color: theme.colorScheme.tertiary,
            size: 18,
          ),
          SizedBox(width: 1.w),
          GestureDetector(
            onTap: () => _confirmCancelBooking(instanceId),
            child: Padding(
              padding: EdgeInsets.all(1.w),
              child: CustomIconWidget(
                iconName: 'delete',
                color: theme.colorScheme.error,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancelBooking(String instanceId) {
    if (instanceId.isEmpty) return;
    final theme = Theme.of(context);

    // Client-side 1-hour deadline check using booking data
    final booking = _myBookings.firstWhere((b) {
      final inst = b['schedule_instances'] as Map<String, dynamic>?;
      return inst != null && inst['id']?.toString() == instanceId;
    }, orElse: () => {});

    if (booking.isNotEmpty) {
      final instance = booking['schedule_instances'] as Map<String, dynamic>?;
      if (instance != null) {
        final classDateStr = instance['class_date']?.toString() ?? '';
        final startTimeStr = instance['start_time']?.toString() ?? '';
        if (classDateStr.isNotEmpty && startTimeStr.isNotEmpty) {
          try {
            final timeParts = startTimeStr.split(':');
            final classDate = DateTime.parse(classDateStr);
            final classDateTime = DateTime(
              classDate.year,
              classDate.month,
              classDate.day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );
            final deadline =
                classDateTime.subtract(const Duration(minutes: 30));
            if (DateTime.now().isAfter(deadline)) {
              Fluttertoast.showToast(
                msg:
                    'Non è possibile disdire la prenotazione a meno di 30 minuti dall\'inizio della classe.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: theme.colorScheme.error,
                textColor: theme.colorScheme.onError,
              );
              return;
            }
          } catch (_) {
            // If parsing fails, let the server-side check handle it
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancella prenotazione',
          style: theme.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Sei sicuro di voler cancellare questa prenotazione?',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Annulla',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _onCancelBooking(instanceId);
            },
            child: Text(
              'Conferma',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBookingDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
      const months = [
        'Gen',
        'Feb',
        'Mar',
        'Apr',
        'Mag',
        'Giu',
        'Lug',
        'Ago',
        'Set',
        'Ott',
        'Nov',
        'Dic',
      ];
      final weekday = weekdays[date.weekday - 1];
      final month = months[date.month - 1];
      return '$weekday ${date.day} $month';
    } catch (_) {
      return dateStr;
    }
  }

  Color _getDisciplineColor(ThemeData theme, String discipline) {
    switch (discipline.toLowerCase()) {
      case 'bjj':
        return const Color(0xFF1565C0);
      case 'mma':
        return const Color(0xFFB71C1C);
      case 'sambo':
        return const Color(0xFF2E7D32);
      case 'grappling':
        return const Color(0xFF6A1B9A);
      case 'fitness':
        return const Color(0xFFE65100);
      default:
        return theme.primaryColor;
    }
  }

  Widget _buildLoadingSkeleton() {
    final theme = Theme.of(context);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
              'class_schedule.empty_title'.tr(),
              style: theme.textTheme.headlineSmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            Text(
              'class_schedule.empty_subtitle'.tr(),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            ElevatedButton(
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _selectedFilters = ['all'];
                  _selectedDate = DateTime.now();
                });
                _loadClassSchedule();
              },
              child: Text('class_schedule.show_all_classes'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
