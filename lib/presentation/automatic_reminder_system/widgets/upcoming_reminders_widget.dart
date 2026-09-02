import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class UpcomingRemindersWidget extends StatelessWidget {
  final List<Map<String, dynamic>> upcomingReminders;
  final VoidCallback onReminderUpdated;

  const UpcomingRemindersWidget({
    super.key,
    required this.upcomingReminders,
    required this.onReminderUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reminders.scheduled_reminders'.tr(),
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryLight,
            ),
          ),
          SizedBox(height: 3.h),
          _buildSummaryCard(),
          SizedBox(height: 3.h),
          _buildRemindersList(context),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final todayReminders = upcomingReminders.where((reminder) {
      final reminderDate = DateTime.parse(reminder['reminder_date']);
      final today = DateTime.now();
      return reminderDate.year == today.year &&
          reminderDate.month == today.month &&
          reminderDate.day == today.day;
    }).length;

    final weekReminders = upcomingReminders.length;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              title: 'registration_card.today'.tr(),
              count: todayReminders,
              icon: Icons.today,
              color: Colors.red,
            ),
          ),
          Container(
            height: 6.h,
            width: 1,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildSummaryItem(
              title: 'reminders.next_7_days'.tr(),
              count: weekReminders,
              icon: Icons.schedule,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 6.w),
        ),
        SizedBox(height: 1.h),
        Text(
          count.toString(),
          style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          title,
          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRemindersList(BuildContext context) {
    if (upcomingReminders.isEmpty) {
      return Container(
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(26),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.notification_add,
              size: 15.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 2.h),
            Text(
              'reminders.no_scheduled'.tr(),
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'reminders.auto_create_on_7th'.tr(),
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group reminders by date
    final groupedReminders = <String, List<Map<String, dynamic>>>{};
    for (final reminder in upcomingReminders) {
      final dateKey = reminder['reminder_date'];
      if (!groupedReminders.containsKey(dateKey)) {
        groupedReminders[dateKey] = [];
      }
      groupedReminders[dateKey]!.add(reminder);
    }

    return Column(
      children: groupedReminders.entries.map((entry) {
        final date = DateTime.parse(entry.key);
        final reminders = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateHeader(date, reminders.length),
            SizedBox(height: 1.h),
            ...reminders
                .map((reminder) => _buildReminderCard(context, reminder)),
            SizedBox(height: 2.h),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDateHeader(DateTime date, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(date.year, date.month, date.day);

    String dateLabel;
    Color labelColor = Colors.grey[700]!;

    if (reminderDate == today) {
      dateLabel = 'Oggi';
      labelColor = Colors.red;
    } else if (reminderDate == today.add(const Duration(days: 1))) {
      dateLabel = 'reminders.tomorrow'.tr();
      labelColor = Colors.orange;
    } else {
      dateLabel = DateFormat('EEEE, d MMMM', 'it_IT').format(date);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: labelColor.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: labelColor,
            size: 4.w,
          ),
          SizedBox(width: 2.w),
          Text(
            dateLabel,
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
      BuildContext context, Map<String, dynamic> reminder) {
    final userProfile = reminder['user_profiles'];
    final userName = userProfile?['full_name'] ?? 'reminders.unknown_user'.tr();
    final userEmail = userProfile?['email'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(4.w),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryLight.withAlpha(26),
          child: Icon(
            Icons.person,
            color: AppTheme.primaryLight,
          ),
        ),
        title: Text(
          userName,
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 0.5.h),
            Text(
              userEmail,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'reminders.monthly_reminder_message'.tr(),
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              _handleReminderAction(context, reminder, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'send_now',
              child: Row(
                children: [
                  Icon(Icons.send, color: Colors.green),
                  SizedBox(width: 8),
                  Text('reminders.send_now'.tr()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('profile.modify'.tr()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('common.delete'.tr()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReminderAction(
    BuildContext context,
    Map<String, dynamic> reminder,
    String action,
  ) async {
    final supabaseService = SupabaseService.instance;

    switch (action) {
      case 'send_now':
        try {
          // Mark reminder as sent
          await supabaseService.client
              .from('payment_reminders')
              .update({'is_sent': true}).eq('id', reminder['id']);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('reminders.send_success'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          onReminderUpdated();
        } catch (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'reminders.send_error'.tr(namedArgs: {'error': '$error'})),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('reminders.delete_confirm_title'.tr()),
            content: Text('reminders.delete_confirm_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('common.delete'.tr()),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await supabaseService.client
                .from('payment_reminders')
                .delete()
                .eq('id', reminder['id']);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('reminders.deleted_success'.tr()),
                backgroundColor: Colors.orange,
              ),
            );
            onReminderUpdated();
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('reminders.delete_error'
                    .tr(namedArgs: {'error': '$error'})),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
    }
  }
}
