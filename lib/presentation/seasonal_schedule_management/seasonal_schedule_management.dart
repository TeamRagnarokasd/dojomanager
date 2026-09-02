import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_notification_service.dart';
import './widgets/bulk_operations_widget.dart';
import './widgets/holiday_management_widget.dart';
import './widgets/season_configuration_widget.dart';

class SeasonalScheduleManagement extends StatefulWidget {
  const SeasonalScheduleManagement({Key? key}) : super(key: key);

  @override
  State<SeasonalScheduleManagement> createState() =>
      _SeasonalScheduleManagementState();
}

class _SeasonalScheduleManagementState extends State<SeasonalScheduleManagement>
    with SingleTickerProviderStateMixin {
  String? _userRole;
  bool _isLoading = true;
  late TabController _tabController;

  // Current seasonal schedule state
  Map<String, dynamic>? _currentSeason;
  List<Map<String, dynamic>> _weeklyTemplates = [];
  List<Map<String, dynamic>> _holidays = [];
  List<Map<String, dynamic>> _scheduleInstances = [];
  List<Map<String, dynamic>> _instructors = [];

  final SupabaseClient _supabase = Supabase.instance.client;

  // Realtime subscription for admin schedule changes
  StreamSubscription<RealtimeDataChangeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    RealtimeNotificationService.instance.subscribeToAdminDataChanges();

    _realtimeSubscription = RealtimeNotificationService
        .instance.dataChangeStream
        .where((event) =>
            event.type == RealtimeDataChangeType.scheduleTemplates ||
            event.type == RealtimeDataChangeType.scheduleInstances)
        .listen((_) {
      if (mounted && !_isLoading) {
        _loadWeeklyTemplates();
        _loadScheduleInstances();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    if (!AuthService.instance.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login-screen');
      return;
    }

    try {
      final role = await AuthService.instance.getUserRole();

      // Verify admin privileges
      if (!['admin', 'principal_admin', 'instructor_admin'].contains(role)) {
        Navigator.pushReplacementNamed(context, '/dashboard-home');
        return;
      }

      setState(() {
        _userRole = role;
      });

      await _loadInitialData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('seasonal_management.auth_error'.tr()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        Navigator.pushReplacementNamed(context, '/dashboard-home');
      }
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_loadCurrentSeason(), _loadInstructors()]);

      if (_currentSeason != null) {
        await Future.wait([
          _loadWeeklyTemplates(),
          _loadHolidays(),
          _loadScheduleInstances(),
        ]);
      }

      // Force UI refresh
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('seasonal_schedule.load_data_error'.tr());
      }
    }
  }

  Future<void> _loadCurrentSeason() async {
    // Load the most recent schedule (prioritize draft, then active, then others)
    final draftResponse = await _supabase
        .from('seasonal_schedules')
        .select('*')
        .eq('status', 'draft')
        .order('created_at', ascending: false)
        .limit(1);

    if (draftResponse.isNotEmpty) {
      setState(() {
        _currentSeason = draftResponse.first;
      });
      return;
    }

    // If no draft, load the most recent active schedule
    final activeResponse = await _supabase
        .from('seasonal_schedules')
        .select('*')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1);

    if (activeResponse.isNotEmpty) {
      setState(() {
        _currentSeason = activeResponse.first;
      });
      return;
    }

    // If no active, load the most recent schedule of any status
    final anyResponse = await _supabase
        .from('seasonal_schedules')
        .select('*')
        .order('created_at', ascending: false)
        .limit(1);

    if (anyResponse.isNotEmpty) {
      setState(() {
        _currentSeason = anyResponse.first;
      });
    } else {
      setState(() {
        _currentSeason = null;
      });
    }
  }

  Future<void> _loadWeeklyTemplates() async {
    if (_currentSeason == null) return;

    final response = await _supabase
        .from('weekly_schedule_templates')
        .select('''
          *,
          instructor:instructor_id(id, full_name)
        ''')
        .eq('seasonal_schedule_id', _currentSeason!['id'])
        .order('day_of_week, start_time');

    setState(() {
      _weeklyTemplates = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _loadHolidays() async {
    if (_currentSeason == null) return;

    final response = await _supabase
        .from('seasonal_holidays')
        .select('*')
        .eq('seasonal_schedule_id', _currentSeason!['id'])
        .order('holiday_date');

    setState(() {
      _holidays = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _loadScheduleInstances() async {
    if (_currentSeason == null) return;

    final response = await _supabase
        .from('schedule_instances')
        .select('''
          *,
          instructor:instructor_id(id, full_name)
        ''')
        .eq('seasonal_schedule_id', _currentSeason!['id'])
        .order('class_date, start_time')
        .limit(100);

    setState(() {
      _scheduleInstances = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _loadInstructors() async {
    final response = await _supabase
        .from('user_profiles')
        .select('id, full_name')
        .eq('role', 'instructor')
        .eq('is_active', true)
        .order('full_name');

    setState(() {
      _instructors = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _createNewSeason(Map<String, dynamic> seasonData) async {
    try {
      final response = await _supabase
          .from('seasonal_schedules')
          .insert({
            ...seasonData,
            'created_by': AuthService.instance.currentUser!.id,
          })
          .select()
          .single();

      setState(() {
        _currentSeason = response;
        _weeklyTemplates.clear();
        _holidays.clear();
        _scheduleInstances.clear();
      });

      // Force reload all data to ensure consistency
      await _loadInitialData();

      _showSuccessSnackBar('Nuova stagione creata con successo');
    } catch (error) {
      _showErrorSnackBar('seasonal_schedule.create_season_error'.tr());
    }
  }

  Future<void> _generateScheduleInstances() async {
    if (_currentSeason == null) return;

    try {
      HapticFeedback.mediumImpact();

      final response = await _supabase.rpc(
        'generate_seasonal_schedule_instances',
        params: {'schedule_id': _currentSeason!['id']},
      );

      await _loadScheduleInstances();
      _showSuccessSnackBar('bulk_schedule.lessons_generated'
          .tr(namedArgs: {'count': '$response'}));
    } catch (error) {
      _showErrorSnackBar('bulk_schedule.generate_error'.tr());
    }
  }

  Future<void> _activateSeason() async {
    if (_currentSeason == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('bulk_schedule.activate_title'.tr()),
        content: Text(
          'Sei sicuro di voler attivare questo palinsesto? Una volta attivato, sarà visibile a tutti gli utenti e diventerà il palinsesto ufficiale.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: Text('seasonal_management.activate'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // First deactivate any existing active schedules
      await _supabase
          .from('seasonal_schedules')
          .update({'status': 'completed'}).eq('status', 'active');

      // Then activate the current schedule
      await _supabase
          .from('seasonal_schedules')
          .update({'status': 'active'}).eq('id', _currentSeason!['id']);

      setState(() {
        _currentSeason!['status'] = 'active';
      });

      _showSuccessSnackBar('Palinsesto attivato con successo!');

      // Show success dialog with option to go home
      _showActivationSuccessDialog();
    } catch (error) {
      _showErrorSnackBar('bulk_schedule.activate_error'.tr());
    }
  }

  void _showActivationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 2.w),
            Text('seasonal_management.activated'.tr()),
          ],
        ),
        content: Text(
          'Il palinsesto è stato attivato con successo e ora è visibile a tutti gli utenti dell\'applicazione.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('bulk_schedule.continue_here'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/dashboard-home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: Text('seasonal_management.back_home'.tr()),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    Navigator.pushReplacementNamed(context, '/dashboard-home');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getSeasonStatusText() {
    if (_currentSeason == null) return 'seasonal_schedule.no_season'.tr();

    switch (_currentSeason!['status']) {
      case 'draft':
        return 'Bozza';
      case 'active':
        return 'Applicato';
      case 'completed':
        return 'Completata';
      case 'cancelled':
        return 'class_schedule.status_cancelled'.tr();
      default:
        return 'Sconosciuto';
    }
  }

  Color _getSeasonStatusColor() {
    if (_currentSeason == null) return Colors.grey;

    switch (_currentSeason!['status']) {
      case 'draft':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('seasonal_management.title'.tr()),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          leading: IconButton(
            icon: Icon(Icons.home),
            onPressed: _goHome,
            tooltip: 'Torna alla Home',
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
              ),
              SizedBox(height: 2.h),
              Text(
                'seasonal_schedule.loading_system'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('screens.seasonal_schedule'.tr()),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        leading: IconButton(
          icon: Icon(Icons.home),
          onPressed: _goHome,
          tooltip: 'Torna alla Home Admin',
        ),
        actions: [
          if (_currentSeason != null && _currentSeason!['status'] == 'draft')
            Container(
              margin: EdgeInsets.only(right: 2.w),
              child: ElevatedButton.icon(
                onPressed: _activateSeason,
                icon: Icon(Icons.publish, size: 18),
                label: Text('bulk_schedule.activate_button'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          // Show current status for active schedules
          if (_currentSeason != null && _currentSeason!['status'] == 'active')
            Container(
              margin: EdgeInsets.only(right: 2.w),
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 1.w),
                  Text(
                    'Applicato al Sistema',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: () => _showQuickActionsMenu(),
            icon: Icon(Icons.more_vert),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(12.h),
          child: Column(
            children: [
              // Season Status Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getSeasonStatusColor().withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getSeasonStatusColor(),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getSeasonStatusColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                _getSeasonStatusText(),
                                style: TextStyle(
                                  color: _getSeasonStatusColor(),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Spacer(),
                        if (_currentSeason != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            '${DateFormat('dd/MM').format(DateTime.parse(_currentSeason!['start_date']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(_currentSeason!['end_date']))}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_currentSeason != null) ...[
                      SizedBox(height: 1.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _currentSeason!['title'] ?? 'Stagione senza titolo',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.secondary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.secondary,
                tabs: [
                  Tab(text: 'Schema Orari'),
                  Tab(text: 'class_schedule.status_holiday'.tr()),
                  Tab(text: 'Operazioni'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Season Configuration Tab (Schema Orari)
          SeasonConfigurationWidget(
            currentSeason: _currentSeason,
            onSeasonCreated: _createNewSeason,
            onSeasonUpdated: () async {
              await _loadCurrentSeason();
              await _loadWeeklyTemplates();
            },
          ),

          // Holiday Management Tab
          HolidayManagementWidget(
            currentSeason: _currentSeason,
            holidays: _holidays,
            onHolidaysUpdated: _loadHolidays,
          ),

          // Bulk Operations Tab
          BulkOperationsWidget(
            currentSeason: _currentSeason,
            weeklyTemplates: _weeklyTemplates,
            instructors: _instructors,
            onOperationCompleted: () => _loadInitialData(),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Azioni Rapide Palinsesto',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 3.h),
            _buildQuickActionTile(
              'Crea Nuovo Palinsesto',
              Icons.add_circle_outline,
              () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  AppRoutes.seasonalScheduleCreation,
                );
              },
            ),
            _buildQuickActionTile(
              'Genera Automatico',
              Icons.auto_awesome,
              _currentSeason != null && _weeklyTemplates.isNotEmpty
                  ? () {
                      Navigator.pop(context);
                      _generateScheduleInstances();
                    }
                  : null,
            ),
            _buildQuickActionTile(
              'bulk_schedule.activate_button'.tr(),
              Icons.publish,
              _currentSeason != null && _currentSeason!['status'] == 'draft'
                  ? () {
                      Navigator.pop(context);
                      _activateSeason();
                    }
                  : null,
            ),
            _buildQuickActionTile('Torna alla Home', Icons.home, () {
              Navigator.pop(context);
              _goHome();
            }),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    String title,
    IconData icon,
    VoidCallback? onTap,
  ) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(4.w),
          margin: EdgeInsets.only(bottom: 1.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEnabled
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 24,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isEnabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: isEnabled
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
