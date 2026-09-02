import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ReminderConfigurationWidget extends StatefulWidget {
  final VoidCallback onConfigurationChanged;

  const ReminderConfigurationWidget({
    super.key,
    required this.onConfigurationChanged,
  });

  @override
  State<ReminderConfigurationWidget> createState() =>
      _ReminderConfigurationWidgetState();
}

class _ReminderConfigurationWidgetState
    extends State<ReminderConfigurationWidget> {
  bool _monthlyRemindersEnabled = true;
  int _reminderDayOfMonth = 7;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _smsNotificationsEnabled = false;

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    // In real implementation, load from settings table
    setState(() {
      _monthlyRemindersEnabled = true;
      _reminderDayOfMonth = 7;
      _pushNotificationsEnabled = true;
      _emailNotificationsEnabled = true;
      _smsNotificationsEnabled = false;
    });
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isLoading = true);

    try {
      // In real implementation, save to settings table
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      setState(() => _hasChanges = false);
      widget.onConfigurationChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reminders.config_saved'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'reminders.config_save_error'.tr(namedArgs: {'error': '$error'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reminders.config_title'.tr(),
            style: AppTheme.lightTheme.textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryLight,
            ),
          ),
          SizedBox(height: 3.h),
          _buildReminderScheduleSection(),
          SizedBox(height: 3.h),
          _buildNotificationMethodsSection(),
          SizedBox(height: 3.h),
          _buildAdvancedSettingsSection(),
          SizedBox(height: 4.h),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildReminderScheduleSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reminders.scheduling_title'.tr(),
            style: AppTheme.lightTheme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          SwitchListTile(
            title: Text('reminders.monthly_auto_title'.tr()),
            subtitle: Text('reminders.monthly_auto_subtitle'.tr()),
            value: _monthlyRemindersEnabled,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _monthlyRemindersEnabled = value);
              _markAsChanged();
            },
          ),
          if (_monthlyRemindersEnabled) ...[
            Divider(height: 3.h),
            Text(
              'Giorno del mese per l\'invio',
              style: AppTheme.lightTheme.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Slider(
              value: _reminderDayOfMonth.toDouble(),
              min: 1,
              max: 28,
              divisions: 27,
              activeColor: AppTheme.primaryLight,
              label: _reminderDayOfMonth.toString(),
              onChanged: (value) {
                setState(() => _reminderDayOfMonth = value.toInt());
                _markAsChanged();
              },
            ),
            Center(
              child: Text(
                'I promemoria verranno inviati il ${_reminderDayOfMonth}° giorno di ogni mese',
                style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationMethodsSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metodi di Notifica',
            style: AppTheme.lightTheme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          SwitchListTile(
            title: Text('reminders.push_notifications'.tr()),
            subtitle: Text('reminders.push_subtitle'.tr()),
            value: _pushNotificationsEnabled,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _pushNotificationsEnabled = value);
              _markAsChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('reminders.email_notifications'.tr()),
            subtitle: Text('reminders.email_subtitle'.tr()),
            value: _emailNotificationsEnabled,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _emailNotificationsEnabled = value);
              _markAsChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('reminders.sms'.tr()),
            subtitle: Text('reminders.sms_subtitle'.tr()),
            value: _smsNotificationsEnabled,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _smsNotificationsEnabled = value);
              _markAsChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsSection() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reminders.advanced_settings'.tr(),
            style: AppTheme.lightTheme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Card(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 5.w,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Regole di Scadenza Team Ragnarok',
                          style: AppTheme.lightTheme.textTheme.titleSmall!
                              .copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '• Abbonamenti mensili: dal 10 al 10 del mese successivo\n'
                    '• Iscrizioni annuali: fino al 28 agosto dell\'anno successivo\n'
                    '• I promemoria vengono inviati automaticamente il 7 di ogni mese',
                    style: AppTheme.lightTheme.textTheme.bodySmall!.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _hasChanges && !_isLoading ? _saveConfiguration : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryLight,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'reminders.config_saved'.tr(),
                style: AppTheme.lightTheme.textTheme.titleMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
