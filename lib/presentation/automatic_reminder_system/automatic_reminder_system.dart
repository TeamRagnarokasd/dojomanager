import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_error_widget.dart';
import './widgets/delivery_status_dashboard_widget.dart';
import './widgets/manual_reminder_widget.dart';
import './widgets/notification_settings_widget.dart';
import './widgets/notification_template_editor_widget.dart';
import './widgets/reminder_configuration_widget.dart';
import './widgets/reminder_history_widget.dart';
import './widgets/reminder_statistics_widget.dart';
import './widgets/upcoming_reminders_widget.dart';

class AutomaticReminderSystem extends StatefulWidget {
  const AutomaticReminderSystem({super.key});

  @override
  State<AutomaticReminderSystem> createState() =>
      _AutomaticReminderSystemState();
}

class _AutomaticReminderSystemState extends State<AutomaticReminderSystem>
    with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService.instance;
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _reminderStats = {};
  List<Map<String, dynamic>> _upcomingReminders = [];
  Map<String, dynamic> _deliveryStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadReminderData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReminderData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load reminder statistics
      await _loadReminderStatistics();

      // Load upcoming reminders
      await _loadUpcomingReminders();

      // Load delivery statistics
      await _loadDeliveryStatistics();
    } catch (error) {
      setState(() {
        _errorMessage = 'Errore nel caricamento dei dati: $error';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReminderStatistics() async {
    try {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);

      // Count active reminders
      final activeReminders = await _supabaseService.client
          .from('payment_reminders')
          .select('id')
          .eq('is_sent', false)
          .gte('reminder_date', thisMonth.toIso8601String())
          .count();

      // Count sent reminders this month
      final sentReminders = await _supabaseService.client
          .from('payment_reminders')
          .select('id')
          .eq('is_sent', true)
          .gte('reminder_date', thisMonth.toIso8601String())
          .count();

      // Count users who paid after reminder
      final successfulReminders = await _supabaseService.client
          .from('receipts')
          .select('id')
          .gte('issue_date', thisMonth.toIso8601String())
          .count();

      setState(() {
        _reminderStats = {
          'activeReminders': activeReminders.count ?? 0,
          'sentReminders': sentReminders.count ?? 0,
          'successfulPayments': successfulReminders.count ?? 0,
          'successRate': sentReminders.count > 0
              ? (successfulReminders.count ?? 0) / sentReminders.count * 100
              : 0.0,
        };
      });
    } catch (error) {
      print('Error loading reminder statistics: $error');
    }
  }

  Future<void> _loadUpcomingReminders() async {
    try {
      final today = DateTime.now();
      final nextWeek = today.add(const Duration(days: 7));

      final reminders = await _supabaseService.client
          .from('payment_reminders')
          .select('''
            id,
            reminder_date,
            message,
            is_sent,
            user_profiles!inner(
              id,
              full_name,
              email
            )
          ''')
          .eq('is_sent', false)
          .gte('reminder_date', today.toIso8601String().split('T')[0])
          .lte('reminder_date', nextWeek.toIso8601String().split('T')[0])
          .order('reminder_date', ascending: true);

      setState(() {
        _upcomingReminders = List<Map<String, dynamic>>.from(reminders);
      });
    } catch (error) {
      print('Error loading upcoming reminders: $error');
    }
  }

  Future<void> _loadDeliveryStatistics() async {
    try {
      final today = DateTime.now();
      final thisMonth = DateTime(today.year, today.month, 1);

      final totalSent = await _supabaseService.client
          .from('payment_reminders')
          .select('id')
          .eq('is_sent', true)
          .gte('reminder_date', thisMonth.toIso8601String())
          .count();

      final successfulDeliveries = totalSent.count ?? 0;
      final failedDeliveries =
          0; // In real implementation, track delivery failures

      setState(() {
        _deliveryStats = {
          'totalSent': successfulDeliveries,
          'successful': successfulDeliveries,
          'failed': failedDeliveries,
          'deliveryRate': successfulDeliveries > 0 ? 100.0 : 0.0,
        };
      });
    } catch (error) {
      print('Error loading delivery statistics: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryLight,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: _buildAppBar(),
        body: CustomErrorWidget(
          errorMessage: _errorMessage!,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatisticsTab(),
                _buildConfigurationTab(),
                _buildTemplateEditorTab(),
                _buildUpcomingRemindersTab(),
                _buildManualReminderTab(),
                _buildDeliveryStatusTab(),
                _buildHistoryTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryLight,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Sistema Promemoria Automatici',
        style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadReminderData,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.primaryLight,
        labelColor: AppTheme.primaryLight,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Statistiche'),
          Tab(text: 'Configurazione'),
          Tab(text: 'Template'),
          Tab(text: 'Promemoria'),
          Tab(text: 'Invio Manuale'),
          Tab(text: 'Status Invio'),
          Tab(text: 'Cronologia'),
          Tab(text: 'Impostazioni'),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return ReminderStatisticsWidget(
      statistics: _reminderStats,
      onRefresh: _loadReminderStatistics,
    );
  }

  Widget _buildConfigurationTab() {
    return ReminderConfigurationWidget(
      onConfigurationChanged: () => _loadReminderData(),
    );
  }

  Widget _buildTemplateEditorTab() {
    return NotificationTemplateEditorWidget(
      onTemplateUpdated: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template aggiornato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  Widget _buildUpcomingRemindersTab() {
    return UpcomingRemindersWidget(
      upcomingReminders: _upcomingReminders,
      onReminderUpdated: _loadUpcomingReminders,
    );
  }

  Widget _buildManualReminderTab() {
    return ManualReminderWidget(
      onReminderSent: () {
        _loadReminderData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promemoria inviato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  Widget _buildDeliveryStatusTab() {
    return DeliveryStatusDashboardWidget(
      deliveryStats: _deliveryStats,
      onRefresh: _loadDeliveryStatistics,
    );
  }

  Widget _buildHistoryTab() {
    return ReminderHistoryWidget(
      onHistoryRefresh: () => _loadReminderData(),
    );
  }

  Widget _buildSettingsTab() {
    return NotificationSettingsWidget(
      onSettingsChanged: () => _loadReminderData(),
    );
  }
}