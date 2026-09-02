import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class ReminderHistoryWidget extends StatefulWidget {
  final VoidCallback onHistoryRefresh;

  const ReminderHistoryWidget({
    super.key,
    required this.onHistoryRefresh,
  });

  @override
  State<ReminderHistoryWidget> createState() => _ReminderHistoryWidgetState();
}

class _ReminderHistoryWidgetState extends State<ReminderHistoryWidget> {
  final SupabaseService _supabaseService = SupabaseService.instance;

  List<Map<String, dynamic>> _reminderHistory = [];
  bool _isLoading = true;
  String _filterPeriod = 'month'; // week, month, quarter, year
  String _filterStatus = 'all'; // all, sent, pending

  @override
  void initState() {
    super.initState();
    _loadReminderHistory();
  }

  Future<void> _loadReminderHistory() async {
    try {
      setState(() => _isLoading = true);

      DateTime startDate;
      final now = DateTime.now();

      switch (_filterPeriod) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'quarter':
          startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          startDate = DateTime(now.year, now.month - 1, now.day);
      }

      var query = _supabaseService.client.from('payment_reminders').select('''
            id,
            reminder_date,
            message,
            is_sent,
            created_at,
            user_profiles!inner(
              id,
              full_name,
              email
            )
          ''').gte('created_at', startDate.toIso8601String());

      if (_filterStatus != 'all') {
        final isSent = _filterStatus == 'sent';
        query = query.eq('is_sent', isSent);
      }

      final reminders = await query.order('created_at', ascending: false);

      setState(() {
        _reminderHistory = List<Map<String, dynamic>>.from(reminders);
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reminders.history_load_error'
              .tr(namedArgs: {'error': '$error'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
        Expanded(child: _buildHistoryList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(4.w),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reminders.history_title'.tr(),
            style: AppTheme.lightTheme.textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryLight,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.grey[600],
                size: 4.w,
              ),
              SizedBox(width: 2.w),
              Text(
                'common.last_n_items'.tr(namedArgs: {
                  'count': '${_reminderHistory.length}',
                }),
                style: AppTheme.lightTheme.textTheme.bodyMedium!.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _loadReminderHistory();
                  widget.onHistoryRefresh();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(4.w),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'reminders.period_label'.tr(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterPeriod,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'week', child: Text('reminders.last_week'.tr())),
                    DropdownMenuItem(
                        value: 'month',
                        child: Text('reminders.last_month'.tr())),
                    DropdownMenuItem(
                        value: 'quarter',
                        child: Text('reminders.last_3_months'.tr())),
                    DropdownMenuItem(
                        value: 'year', child: Text('reminders.last_year'.tr())),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _filterPeriod = value);
                      _loadReminderHistory();
                    }
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'reminders.status_filter_label'.tr(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _filterStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'all', child: Text('disciplines.all'.tr())),
                    DropdownMenuItem(
                        value: 'sent',
                        child: Text('reminders.status_sent'.tr())),
                    DropdownMenuItem(
                        value: 'pending', child: Text('common.pending'.tr())),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _filterStatus = value);
                      _loadReminderHistory();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryLight,
        ),
      );
    }

    if (_reminderHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 15.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 2.h),
            Text(
              'common.no_history'.tr(),
              style: AppTheme.lightTheme.textTheme.titleMedium!.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'reminders.history_empty_subtitle'.tr(),
              style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final groupedHistory = <String, List<Map<String, dynamic>>>{};
    for (final reminder in _reminderHistory) {
      final date = DateTime.parse(reminder['created_at']);
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(reminder);
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      itemCount: groupedHistory.entries.length,
      itemBuilder: (context, index) {
        final entry = groupedHistory.entries.elementAt(index);
        final date = DateTime.parse(entry.key);
        final reminders = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, reminders.length),
            SizedBox(height: 1.h),
            ...reminders.map((reminder) => _buildReminderItem(reminder)),
            SizedBox(height: 2.h),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(date.year, date.month, date.day);

    String dateLabel;
    if (reminderDate == today) {
      dateLabel = 'Oggi';
    } else if (reminderDate == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Ieri';
    } else {
      dateLabel = DateFormat('EEEE, d MMMM yyyy', 'it_IT').format(date);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: AppTheme.primaryLight,
            size: 4.w,
          ),
          SizedBox(width: 2.w),
          Text(
            dateLabel,
            style: AppTheme.lightTheme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryLight,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> reminder) {
    final userProfile = reminder['user_profiles'];
    final userName = userProfile?['full_name'] ?? 'reminders.unknown_user'.tr();
    final userEmail = userProfile?['email'] ?? '';
    final isSent = reminder['is_sent'] ?? false;
    final createdAt = DateTime.parse(reminder['created_at']);

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSent ? Colors.green.withAlpha(77) : Colors.orange.withAlpha(77),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(13),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 5.w,
                backgroundColor:
                    (isSent ? Colors.green : Colors.orange).withAlpha(26),
                child: Icon(
                  isSent ? Icons.check_circle : Icons.schedule,
                  color: isSent ? Colors.green : Colors.orange,
                  size: 5.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: AppTheme.lightTheme.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      userEmail,
                      style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color:
                          (isSent ? Colors.green : Colors.orange).withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSent
                          ? 'reminders.status_sent_single'.tr()
                          : 'reminders.status_pending'.tr(),
                      style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                        color: isSent ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    DateFormat('HH:mm').format(createdAt),
                    style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (reminder['message'] != null) ...[
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                reminder['message'],
                style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
