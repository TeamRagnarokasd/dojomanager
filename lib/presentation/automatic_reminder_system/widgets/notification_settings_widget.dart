import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class NotificationSettingsWidget extends StatefulWidget {
  final VoidCallback onSettingsChanged;

  const NotificationSettingsWidget({
    super.key,
    required this.onSettingsChanged,
  });

  @override
  State<NotificationSettingsWidget> createState() =>
      _NotificationSettingsWidgetState();
}

class _NotificationSettingsWidgetState
    extends State<NotificationSettingsWidget> {
  // Global settings
  bool _enableAutomaticReminders = true;
  bool _enableMemberOptOut = true;
  bool _enableNotificationTracking = true;

  // Notification frequency
  int _reminderFrequencyDays = 7;
  int _maxRetriesPerUser = 3;

  // Advanced settings
  bool _enableEmailNotifications = true;
  bool _enablePushNotifications = true;
  bool _enableSMSNotifications = false;

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // In real implementation, load from settings table
    setState(() {
      _enableAutomaticReminders = true;
      _enableMemberOptOut = true;
      _enableNotificationTracking = true;
      _reminderFrequencyDays = 7;
      _maxRetriesPerUser = 3;
      _enableEmailNotifications = true;
      _enablePushNotifications = true;
      _enableSMSNotifications = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      // In real implementation, save to settings table
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      setState(() => _hasChanges = false);
      widget.onSettingsChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reminders.settings_saved'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reminders.settings_save_error'
              .tr(namedArgs: {'error': '$error'})),
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
            'Impostazioni Notifiche',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
          ),
          SizedBox(height: 3.h),
          _buildGeneralSettings(),
          SizedBox(height: 3.h),
          _buildFrequencySettings(),
          SizedBox(height: 3.h),
          _buildDeliverySettings(),
          SizedBox(height: 3.h),
          _buildPrivacySettings(),
          SizedBox(height: 3.h),
          _buildTeamRagnarokInfo(),
          SizedBox(height: 4.h),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
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
            'Impostazioni Generali',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 2.h),
          SwitchListTile(
            title: Text('reminders.auto_reminders'.tr()),
            subtitle: const Text(
                'Abilita l\'invio automatico di promemoria ogni mese'),
            value: _enableAutomaticReminders,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _enableAutomaticReminders = value);
              _markAsChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('reminders.delivery_tracking'.tr()),
            subtitle: Text('reminders.delivery_tracking_subtitle'.tr()),
            value: _enableNotificationTracking,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _enableNotificationTracking = value);
              _markAsChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySettings() {
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
            'Frequenza Promemoria',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Giorno del mese per l\'invio automatico',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 1.h),
          Slider(
            value: _reminderFrequencyDays.toDouble(),
            min: 1,
            max: 28,
            divisions: 27,
            activeColor: AppTheme.primaryLight,
            label: _reminderFrequencyDays.toString(),
            onChanged: (value) {
              setState(() => _reminderFrequencyDays = value.toInt());
              _markAsChanged();
            },
          ),
          Center(
            child: Text(
              'reminders.reminder_day_of_month'
                  .tr(namedArgs: {'day': '$_reminderFrequencyDays'}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Numero massimo di tentativi per utente',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 1.h),
          Slider(
            value: _maxRetriesPerUser.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: AppTheme.primaryLight,
            label: _maxRetriesPerUser.toString(),
            onChanged: (value) {
              setState(() => _maxRetriesPerUser = value.toInt());
              _markAsChanged();
            },
          ),
          Center(
            child: Text(
              'Massimo $_maxRetriesPerUser tentativi per notifica fallita',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySettings() {
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
            'Metodi di Consegna',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 2.h),
          SwitchListTile(
            title: Text('reminders.push_notifications'.tr()),
            subtitle: Text('reminders.push_subtitle'.tr()),
            value: _enablePushNotifications,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _enablePushNotifications = value);
              _markAsChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('common.email'.tr()),
            subtitle: Text('reminders.email_subtitle'.tr()),
            value: _enableEmailNotifications,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _enableEmailNotifications = value);
              _markAsChanged();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text('reminders.sms'.tr()),
            subtitle: Text('reminders.sms_subtitle'.tr()),
            value: _enableSMSNotifications,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _enableSMSNotifications = value);
              _markAsChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings() {
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
            'Privacy e Consenso',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 2.h),
          SwitchListTile(
            title: Text('reminders.opt_out_title'.tr()),
            subtitle: Text('reminders.opt_out_subtitle'.tr()),
            value: _enableMemberOptOut,
            activeThumbColor: AppTheme.primaryLight,
            onChanged: (value) {
              setState(() => _enableMemberOptOut = value);
              _markAsChanged();
            },
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withAlpha(77)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.blue[700],
                      size: 5.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'reminders.privacy_management'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  'I membri possono disattivare i promemoria dalle impostazioni del loro profilo. '
                  'I dati di contatto sono utilizzati solo per comunicazioni relative agli abbonamenti.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[800],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRagnarokInfo() {
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryLight,
                  size: 6.w,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Regole Team Ragnarok ASD',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLight,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withAlpha(13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema di Promemoria Automatico',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryLight,
                      ),
                ),
                SizedBox(height: 1.h),
                Text(
                  '• I promemoria vengono inviati automaticamente ogni 7 del mese\n'
                  '• Notificano i membri con abbonamenti in scadenza\n'
                  '• Rispettano le regole di scadenza Team Ragnarok:\n'
                  '  - Mensili: dal 10 al 10 del mese successivo\n'
                  '  - Annuali: fino al 28 agosto dell\'anno successivo\n'
                  '• I membri possono disattivare le notifiche dalle impostazioni profilo\n'
                  '• Tracciamento automatico del tasso di successo dei pagamenti',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _hasChanges && !_isLoading ? _saveSettings : null,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text('reminders.save_settings'.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryLight,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
