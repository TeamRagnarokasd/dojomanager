import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';

class CommunicationCenter extends StatefulWidget {
  const CommunicationCenter({super.key});

  @override
  State<CommunicationCenter> createState() => _CommunicationCenterState();
}

class _CommunicationCenterState extends State<CommunicationCenter>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedRecipientGroup = 'all';
  String _messageTemplate = 'custom';
  bool _isLoading = true;
  bool _isSending = false;

  // Recurrence settings
  bool _isRecurring = false;
  String _recurrenceType = 'none'; // 'none', 'weekly', 'monthly'
  Set<String> _selectedWeekdays = {};
  int _selectedDayOfMonth = 1;

  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _templates = [];
  final List<Map<String, dynamic>> _scheduledMessages = [];

  // Weekday options for Italian
  Map<String, String> get _weekdayOptions => {
        'monday': 'seasonal_schedule.monday'.tr(),
        'tuesday': 'seasonal_schedule.tuesday'.tr(),
        'wednesday': 'seasonal_schedule.wednesday'.tr(),
        'thursday': 'seasonal_schedule.thursday'.tr(),
        'friday': 'seasonal_schedule.friday'.tr(),
        'saturday': 'seasonal_schedule.saturday'.tr(),
        'sunday': 'seasonal_schedule.sunday'.tr(),
      };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCommunicationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunicationData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService.instance.client;

      // Load existing communications
      final response = await supabase
          .from('admin_communications')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _messages.clear();
        for (var item in response) {
          _messages.add({
            'id': item['id'],
            'subject': item['title'],
            'preview': item['content'].toString().length > 100
                ? '${item['content'].toString().substring(0, 100)}...'
                : item['content'].toString(),
            'status': item['status'],
            'recipients': _getRecipientCount(item['target_audience']),
            'sent_at': DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.parse(item['created_at'])),
            'target_audience': item['target_audience'],
            'is_recurring': item['is_recurring'] ?? false,
            'recurrence_type': item['recurrence_type'] ?? 'none',
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading communication data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getRecipientCount(String audience) {
    switch (audience) {
      case 'students':
        return 120;
      case 'instructors':
        return 15;
      case 'admins':
        return 5;
      case 'active_subscriptions':
        return 95;
      case 'expired_subscriptions':
        return 25;
      default:
        return 140;
    }
  }

  Future<void> _sendMessage() async {
    if (_subjectController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('communication.enter_subject_message'.tr())),
      );
      return;
    }

    // Validate recurrence settings
    if (_isRecurring) {
      if (_recurrenceType == 'weekly' && _selectedWeekdays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('communication.select_weekday'.tr())),
        );
        return;
      }
    }

    setState(() => _isSending = true);

    try {
      final supabase = SupabaseService.instance.client;

      // Prepare recurrence data
      final Map<String, dynamic> messageData = {
        'title': _subjectController.text.trim(),
        'content': _contentController.text.trim(),
        'target_audience': _selectedRecipientGroup,
        'sender_id': supabase.auth.currentUser?.id,
        'status': _isRecurring ? 'scheduled' : 'sent',
        'is_recurring': _isRecurring,
        'recurrence_type': _isRecurring ? _recurrenceType : 'none',
      };

      // Add recurrence-specific fields
      if (_isRecurring) {
        if (_recurrenceType == 'weekly') {
          messageData['recurrence_days'] = _selectedWeekdays.toList();
        } else if (_recurrenceType == 'monthly') {
          messageData['recurrence_day_of_month'] = _selectedDayOfMonth;
        }

        // Calculate next scheduled date
        DateTime nextScheduled;
        if (_recurrenceType == 'weekly') {
          nextScheduled = _calculateNextWeeklyDate();
        } else {
          nextScheduled = _calculateNextMonthlyDate();
        }
        messageData['next_scheduled_date'] = nextScheduled.toIso8601String();
      }

      await supabase.from('admin_communications').insert(messageData);

      _subjectController.clear();
      _contentController.clear();
      setState(() {
        _selectedRecipientGroup = 'all';
        _isRecurring = false;
        _recurrenceType = 'none';
        _selectedWeekdays.clear();
        _selectedDayOfMonth = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isRecurring
              ? 'communication.recurring_scheduled'.tr()
              : 'communication.sent_success'.tr()),
        ),
      );

      await _loadCommunicationData();
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'communication.send_error'.tr(namedArgs: {'error': '$e'}))),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  DateTime _calculateNextWeeklyDate() {
    final now = DateTime.now();
    final weekdayMap = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    // Find next occurrence
    for (int i = 1; i <= 7; i++) {
      final testDate = now.add(Duration(days: i));
      final weekdayName = _weekdayOptions.entries
          .firstWhere((e) => weekdayMap[e.key] == testDate.weekday)
          .key;

      if (_selectedWeekdays.contains(weekdayName)) {
        return testDate;
      }
    }

    return now.add(Duration(days: 7)); // Fallback
  }

  DateTime _calculateNextMonthlyDate() {
    final now = DateTime.now();
    DateTime nextDate = DateTime(now.year, now.month + 1, _selectedDayOfMonth);

    // Handle invalid dates (e.g., Feb 30)
    while (nextDate.month != ((now.month + 1) % 12)) {
      nextDate = nextDate.subtract(Duration(days: 1));
    }

    return nextDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.secondaryLight))
          : Column(
              children: [
                _buildStatisticsHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMessagesTab(),
                      _buildComposeTab(),
                      _buildTemplatesTab(),
                      _buildScheduledTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildQuickComposeFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'communication.title'.tr(),
        style: GoogleFonts.inter(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_active_outlined,
            color: Colors.white,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildStatisticsHeader() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          Row(
            children: [
              _buildStatCard('communication.messages_sent'.tr(),
                  '${_messages.length}', Icons.send),
              SizedBox(width: 12.w),
              _buildStatCard('communication.open_rate'.tr(), '89.2%',
                  Icons.mark_email_read),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildStatCard('communication.scheduled'.tr(),
                  '${_scheduledMessages.length}', Icons.schedule),
              SizedBox(width: 12.w),
              _buildStatCard(
                  'Template', '${_templates.length}', Icons.text_snippet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.sp),
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(12.sp),
          border: Border.all(color: AppTheme.secondaryLight.withAlpha(77)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.sp),
              decoration: BoxDecoration(
                color: AppTheme.secondaryLight.withAlpha(51),
                borderRadius: BorderRadius.circular(8.sp),
              ),
              child: Icon(
                icon,
                color: AppTheme.secondaryLight,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.primaryColor,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.secondaryLight,
        labelColor: AppTheme.secondaryLight,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(text: 'communication.tab_messages'.tr()),
          Tab(text: 'communication.tab_compose'.tr()),
          Tab(text: 'communication.tab_templates'.tr()),
          Tab(text: 'communication.scheduled'.tr()),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Container(
      color: AppTheme.backgroundDark,
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState('communication.no_messages'.tr())
                : RefreshIndicator(
                    onRefresh: _loadCommunicationData,
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.sp),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageCard(message);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeTab() {
    return Container(
      color: AppTheme.backgroundDark,
      padding: EdgeInsets.all(16.sp),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecipientSelection(),
            SizedBox(height: 16.h),
            _buildTemplateSelection(),
            SizedBox(height: 16.h),
            _buildMessageEditor(),
            SizedBox(height: 16.h),
            _buildRecurrenceSection(), // NEW: Recurrence options
            SizedBox(height: 24.h),
            _buildSendActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(
          color: _isRecurring ? AppTheme.secondaryLight : Colors.white30,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'communication.message_recurrence'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Switch(
                value: _isRecurring,
                onChanged: (value) {
                  setState(() {
                    _isRecurring = value;
                    if (!value) {
                      _recurrenceType = 'none';
                      _selectedWeekdays.clear();
                    }
                  });
                },
                activeThumbColor: AppTheme.secondaryLight,
              ),
            ],
          ),
          if (_isRecurring) ...[
            SizedBox(height: 16.h),

            // Recurrence type selection
            Text(
              'communication.recurrence_type'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 8.h),

            Row(
              children: [
                Expanded(
                  child: _buildRecurrenceTypeChip(
                      'communication.weekly'.tr(), 'weekly'),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildRecurrenceTypeChip(
                      'communication.monthly'.tr(), 'monthly'),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // Weekly options
            if (_recurrenceType == 'weekly') ...[
              Text(
                'communication.select_days'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _weekdayOptions.entries.map((entry) {
                  final isSelected = _selectedWeekdays.contains(entry.key);
                  return FilterChip(
                    label: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected ? AppTheme.primaryColor : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedWeekdays.add(entry.key);
                        } else {
                          _selectedWeekdays.remove(entry.key);
                        }
                      });
                    },
                    backgroundColor: AppTheme.backgroundDark,
                    selectedColor: AppTheme.secondaryLight,
                    side: BorderSide(
                      color:
                          isSelected ? AppTheme.secondaryLight : Colors.white30,
                    ),
                  );
                }).toList(),
              ),
            ],

            // Monthly options
            if (_recurrenceType == 'monthly') ...[
              Text(
                'communication.day_of_month'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 8.h),
              DropdownButtonFormField<int>(
                initialValue: _selectedDayOfMonth,
                style: GoogleFonts.inter(color: Colors.white),
                dropdownColor: AppTheme.backgroundDark,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.sp),
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
                items: List.generate(31, (index) {
                  final day = index + 1;
                  return DropdownMenuItem(
                    value: day,
                    child: Text(
                        'communication.day_n'.tr(namedArgs: {'day': '$day'})),
                  );
                }),
                onChanged: (value) {
                  setState(() => _selectedDayOfMonth = value!);
                },
              ),
            ],

            SizedBox(height: 12.h),

            // Preview of next scheduled date
            Container(
              padding: EdgeInsets.all(12.sp),
              decoration: BoxDecoration(
                color: AppTheme.secondaryLight.withAlpha(26),
                borderRadius: BorderRadius.circular(8.sp),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.secondaryLight,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _getRecurrencePreview(),
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurrenceTypeChip(String label, String type) {
    final isSelected = _recurrenceType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _recurrenceType = type;
          _selectedWeekdays.clear();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryLight : AppTheme.backgroundDark,
          borderRadius: BorderRadius.circular(8.sp),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryLight : Colors.white30,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  String _getRecurrencePreview() {
    if (_recurrenceType == 'weekly' && _selectedWeekdays.isNotEmpty) {
      final dayNames =
          _selectedWeekdays.map((key) => _weekdayOptions[key]).join(', ');
      return 'Il messaggio sarà inviato ogni: $dayNames';
    } else if (_recurrenceType == 'monthly') {
      return 'Il messaggio sarà inviato il giorno $_selectedDayOfMonth di ogni mese';
    }
    return 'communication.select_recurrence_options'.tr();
  }

  Widget _buildTemplatesTab() {
    return Container(
      color: AppTheme.backgroundDark,
      child: _templates.isEmpty
          ? _buildEmptyState('communication.no_templates'.tr())
          : ListView.builder(
              padding: EdgeInsets.all(16.sp),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return _buildTemplateCard(template);
              },
            ),
    );
  }

  Widget _buildScheduledTab() {
    return Container(
      color: AppTheme.backgroundDark,
      child: _scheduledMessages.isEmpty
          ? _buildEmptyState('communication.no_scheduled'.tr())
          : ListView.builder(
              padding: EdgeInsets.all(16.sp),
              itemCount: _scheduledMessages.length,
              itemBuilder: (context, index) {
                final message = _scheduledMessages[index];
                return _buildScheduledMessageCard(message);
              },
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      color: AppTheme.backgroundDark,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'communication.search_hint'.tr(),
          hintStyle: GoogleFonts.inter(color: Colors.white60),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.white60,
          ),
          filled: true,
          fillColor: AppTheme.primaryColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.sp),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          // TODO: Implement search functionality
        },
      ),
    );
  }

  Widget _buildRecipientSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'communication.recipients'.tr(),
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _buildRecipientChip('disciplines.all'.tr(), 'all'),
            _buildRecipientChip('communication.students'.tr(), 'students'),
            _buildRecipientChip(
                'communication.instructors'.tr(), 'instructors'),
            _buildRecipientChip('communication.administrators'.tr(), 'admins'),
            _buildRecipientChip('communication.active_subscriptions'.tr(),
                'active_subscriptions'),
            _buildRecipientChip('communication.expired_subscriptions'.tr(),
                'expired_subscriptions'),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipientChip(String label, String value) {
    final isSelected = _selectedRecipientGroup == value;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : Colors.white70,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedRecipientGroup = value);
      },
      backgroundColor: AppTheme.primaryColor,
      selectedColor: AppTheme.secondaryLight,
      side: BorderSide(
        color: isSelected ? AppTheme.secondaryLight : Colors.white30,
        width: 1.sp,
      ),
    );
  }

  Widget _buildTemplateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'communication.message_template'.tr(),
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          initialValue: _messageTemplate,
          style: GoogleFonts.inter(color: Colors.white),
          dropdownColor: AppTheme.primaryColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.primaryColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.sp),
              borderSide: BorderSide(color: Colors.white30),
            ),
          ),
          items: [
            DropdownMenuItem(
                value: 'custom',
                child: Text('communication.custom_message'.tr())),
            DropdownMenuItem(
                value: 'class_cancelled',
                child: Text('communication.class_cancelled'.tr())),
            DropdownMenuItem(
                value: 'payment_reminder',
                child: Text('communication.payment_reminder'.tr())),
            DropdownMenuItem(
                value: 'event_announcement',
                child: Text('communication.event_announcement'.tr())),
            DropdownMenuItem(
                value: 'welcome',
                child: Text('communication.welcome_message'.tr())),
          ],
          onChanged: (value) {
            setState(() => _messageTemplate = value!);
            _applyTemplate(value!);
          },
        ),
      ],
    );
  }

  void _applyTemplate(String template) {
    switch (template) {
      case 'class_cancelled':
        _subjectController.text = 'communication.subject_class_cancelled'.tr();
        _contentController.text = 'communication.body_class_cancelled'.tr();
        break;
      case 'payment_reminder':
        _subjectController.text = 'communication.subject_payment_reminder'.tr();
        _contentController.text = 'communication.body_payment_reminder'.tr();
        break;
      case 'event_announcement':
        _subjectController.text = 'communication.subject_event'.tr();
        _contentController.text = 'communication.body_event'.tr();
        break;
      case 'welcome':
        _subjectController.text = 'communication.subject_welcome'.tr();
        _contentController.text = 'communication.body_welcome'.tr();
        break;
    }
  }

  Widget _buildMessageEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'communication.subject_label'.tr(),
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _subjectController,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'communication.subject_hint'.tr(),
            hintStyle: GoogleFonts.inter(color: Colors.white60),
            filled: true,
            fillColor: AppTheme.primaryColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.sp),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'communication.message_label'.tr(),
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 200.h,
          child: TextField(
            controller: _contentController,
            maxLines: null,
            expands: true,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'communication.message_hint'.tr(),
              hintStyle: GoogleFonts.inter(color: Colors.white60),
              filled: true,
              fillColor: AppTheme.primaryColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.sp),
                borderSide: BorderSide.none,
              ),
              alignLabelWithHint: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSending
                ? null
                : () {
                    // TODO: Implement schedule message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('communication.schedule_coming_soon'.tr())),
                    );
                  },
            icon: const Icon(
              Icons.schedule,
              color: Colors.white,
            ),
            label: Text(
              'communication.schedule_button'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.sp),
                side: BorderSide(color: AppTheme.secondaryLight),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Icon(
                    Icons.send,
                    color: AppTheme.primaryColor,
                  ),
            label: Text(
              _isSending
                  ? 'communication.sending'.tr()
                  : 'communication.send_now'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryLight,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.sp),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message['subject'] ?? 'communication.no_subject'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryLight.withAlpha(51),
                  borderRadius: BorderRadius.circular(8.sp),
                ),
                child: Text(
                  message['status'] ?? 'communication.sent_status'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.secondaryLight,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            message['preview'] ?? 'communication.message_preview'.tr(),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.group,
                size: 14.sp,
                color: Colors.white60,
              ),
              SizedBox(width: 4.w),
              Text(
                '${message['recipients'] ?? 0} destinatari',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
              const Spacer(),
              Text(
                message['sent_at'] ??
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template['name'] ?? 'communication.template_no_name'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  // TODO: Use template in compose tab
                  _tabController.animateTo(1);
                },
                icon: Icon(
                  Icons.edit,
                  color: AppTheme.secondaryLight,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            template['description'] ??
                'communication.template_description'.tr(),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledMessageCard(Map<String, dynamic> message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: AppTheme.secondaryLight.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message['subject'] ?? 'communication.no_subject'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              PopupMenuButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white60,
                ),
                color: AppTheme.primaryColor,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Text('profile.modify'.tr(),
                        style: GoogleFonts.inter(color: Colors.white)),
                    value: 'edit',
                  ),
                  PopupMenuItem(
                    child: Text('common.delete'.tr(),
                        style:
                            GoogleFonts.inter(color: AppTheme.secondaryLight)),
                    value: 'delete',
                  ),
                ],
                onSelected: (value) {
                  // TODO: Handle scheduled message actions
                },
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            message['preview'] ?? 'communication.message_preview'.tr(),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryLight.withAlpha(51),
                  borderRadius: BorderRadius.circular(8.sp),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12.sp,
                      color: AppTheme.secondaryLight,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      message['scheduled_at'] ??
                          DateFormat('dd/MM HH:mm').format(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${message['recipients'] ?? 0} destinatari',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 48.sp,
            color: Colors.white30,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickComposeFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        _tabController.animateTo(1);
      },
      backgroundColor: AppTheme.secondaryLight,
      icon: Icon(
        Icons.edit,
        color: AppTheme.primaryColor,
      ),
      label: Text(
        'Componi',
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
