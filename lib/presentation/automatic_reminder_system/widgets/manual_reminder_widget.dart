import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:sizer/sizer.dart';
import '../../../services/supabase_service.dart';

class ManualReminderWidget extends StatefulWidget {
  final VoidCallback onReminderSent;

  const ManualReminderWidget({
    super.key,
    required this.onReminderSent,
  });

  @override
  State<ManualReminderWidget> createState() => _ManualReminderWidgetState();
}

class _ManualReminderWidgetState extends State<ManualReminderWidget> {
  final SupabaseService _supabaseService = SupabaseService.instance;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Set<String> _selectedUsers = {};

  String _searchQuery = '';
  String _filterType = 'all'; // all, monthly, annual, expired
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);

      final users =
          await _supabaseService.client.from('user_profiles').select('''
            id,
            full_name,
            email,
            subscriptions!inner(
              id,
              type,
              end_date,
              is_active
            )
          ''').eq('role', 'member').order('full_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(users);
        _filteredUsers = _users;
      });

      _applyFilters();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'reminders.load_users_error'.tr(namedArgs: {'error': '$error'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _users;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = user['full_name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    // Apply type filter
    switch (_filterType) {
      case 'monthly':
        filtered = filtered.where((user) {
          final subscriptions = user['subscriptions'] as List?;
          return subscriptions?.any((sub) =>
                  sub['type'] == 'monthly' && sub['is_active'] == true) ??
              false;
        }).toList();
        break;
      case 'annual':
        filtered = filtered.where((user) {
          final subscriptions = user['subscriptions'] as List?;
          return subscriptions?.any((sub) =>
                  sub['type'] == 'annual' && sub['is_active'] == true) ??
              false;
        }).toList();
        break;
      case 'expired':
        filtered = filtered.where((user) {
          final subscriptions = user['subscriptions'] as List?;
          if (subscriptions == null || subscriptions.isEmpty) return false;

          final now = DateTime.now();
          return subscriptions.any((sub) {
            final endDate = DateTime.parse(sub['end_date']);
            return endDate.isBefore(now);
          });
        }).toList();
        break;
    }

    setState(() => _filteredUsers = filtered);
  }

  Future<void> _sendManualReminders() async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reminders.select_one_user'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final reminderDate = DateTime.now().add(const Duration(days: 1));

      for (final userId in _selectedUsers) {
        await _supabaseService.client.from('payment_reminders').insert({
          'user_id': userId,
          'reminder_date': reminderDate.toIso8601String().split('T')[0],
          'message': 'reminders.manual_payment_message'.tr(),
          'is_sent': false,
        });
      }

      setState(() => _selectedUsers.clear());
      widget.onReminderSent();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('reminders.send_error'.tr(namedArgs: {'error': '$error'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
        Expanded(child: _buildUsersList()),
        if (_selectedUsers.isNotEmpty) _buildSendButton(),
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
            'Invio Manuale Promemoria',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'reminders.manual_send_hint'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          if (_selectedUsers.isNotEmpty) ...[
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedUsers.length} utenti selezionati',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
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
          TextField(
            decoration: InputDecoration(
              hintText: 'reminders.search_name_email'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _applyFilters();
            },
          ),
          SizedBox(height: 2.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('disciplines.all'.tr(), 'all'),
                _buildFilterChip('reminders.filter_monthly'.tr(), 'monthly'),
                _buildFilterChip('reminders.filter_annual'.tr(), 'annual'),
                _buildFilterChip('reminders.filter_expired'.tr(), 'expired'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;

    return Padding(
      padding: EdgeInsets.only(right: 2.w),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Theme.of(context).colorScheme.primary.withAlpha(51),
        checkmarkColor: Theme.of(context).colorScheme.primary,
        onSelected: (selected) {
          setState(() => _filterType = value);
          _applyFilters();
        },
      ),
    );
  }

  Widget _buildUsersList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 15.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 2.h),
            Text(
              'reminders.no_users_found'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'];
    final isSelected = _selectedUsers.contains(userId);
    final subscriptions = user['subscriptions'] as List? ?? [];

    String subscriptionStatus = 'reminders.no_subscription'.tr();
    Color statusColor = Colors.grey;

    if (subscriptions.isNotEmpty) {
      final activeSubscription = subscriptions.firstWhere(
        (sub) => sub['is_active'] == true,
        orElse: () => subscriptions.first,
      );

      final endDate = DateTime.parse(activeSubscription['end_date']);
      final now = DateTime.now();

      if (endDate.isBefore(now)) {
        subscriptionStatus = 'profile.status_expired'.tr();
        statusColor = Colors.red;
      } else {
        subscriptionStatus =
            '${activeSubscription['type']} - Scade: ${endDate.day}/${endDate.month}/${endDate.year}';
        statusColor = activeSubscription['type'] == 'monthly'
            ? Colors.blue
            : Colors.green;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedUsers.add(userId);
            } else {
              _selectedUsers.remove(userId);
            }
          });
        },
        activeColor: Theme.of(context).colorScheme.primary,
        contentPadding: EdgeInsets.all(4.w),
        secondary: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(26),
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          user['full_name'] ?? 'Nome non disponibile',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 0.5.h),
            Text(
              user['email'] ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                subscriptionStatus,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      padding: EdgeInsets.all(4.w),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 5.w,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'I promemoria verranno programmati per domani',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[700],
                        ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendManualReminders,
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _isSending
                    ? 'Programmazione in corso...'
                    : 'Programma Promemoria (${_selectedUsers.length})',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
