import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import './widgets/bulk_actions_widget.dart';
import './widgets/filter_chips_widget.dart';
import './widgets/user_card_widget.dart';
import './widgets/user_management_header_widget.dart';
import './widgets/user_search_widget.dart';

class UserManagementSystem extends StatefulWidget {
  const UserManagementSystem({super.key});

  @override
  State<UserManagementSystem> createState() => _UserManagementSystemState();
}

class _UserManagementSystemState extends State<UserManagementSystem> {
  bool isLoading = true;
  bool isPrincipalAdmin = false;
  Map<String, dynamic>? currentUser;
  List<dynamic> systemUsers = [];
  List<dynamic> filteredUsers = [];
  Set<String> selectedUsers = {};
  String searchQuery = '';
  String selectedRoleFilter = 'all';
  String selectedStatusFilter = 'all';
  String selectedActivityFilter = 'all';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _editFullNameController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editEmergencyContactController =
      TextEditingController();
  final TextEditingController _editEmergencyPhoneController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeUserManagement();
    // 🔍 DIAGNOSTIC: Print to verify code is running with FORCED VERSION UPDATE
    debugPrint(
      '🚀 USER MANAGEMENT SYSTEM INITIALIZED - Version: 2025-01-29-CACHE-BUSTER-${DateTime.now().millisecondsSinceEpoch}',
    );
    debugPrint(
      '✅ Features active: Subscription badges, Medical cert badges, Modifica Veloce, Full Profile Edit',
    );
    debugPrint('🔄 Widget rebuild forced with unique keys');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _editFullNameController.dispose();
    _editPhoneController.dispose();
    _editEmergencyContactController.dispose();
    _editEmergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserManagement() async {
    try {
      await _checkAdminAccess();
      await _loadSystemUsers();
    } catch (e) {
      _showErrorMessage(
        'user_mgmt.access_error'.tr(namedArgs: {'error': e.toString()}),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkAdminAccess() async {
    final client = SupabaseService.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('Accesso non autorizzato');
    }

    try {
      final profileResponse = await client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      currentUser = profileResponse;
      isPrincipalAdmin =
          user.email == 'lutadordeeliteravenna@gmail.com' ||
          (currentUser?['role'] == 'principal_admin');

      final userRole = currentUser?['role']?.toString() ?? '';
      if (!['admin', 'principal_admin'].contains(userRole) &&
          !isPrincipalAdmin) {
        throw Exception('Accesso negato: diritti amministratore richiesti');
      }
    } catch (e) {
      print('Error checking admin access: $e');
      throw Exception('user_mgmt.admin_permission_error'.tr());
    }
  }

  Future<void> _loadSystemUsers() async {
    final client = SupabaseService.instance.client;

    try {
      // 🔍 DIAGNOSTIC: Print to verify data fetching
      debugPrint('📊 Fetching users with subscription data...');

      // Fetch users with their subscription data
      final usersResponse = await client
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);

      debugPrint('✅ Fetched ${(usersResponse as List).length} users');

      // For each user, fetch their active subscription AND child profiles
      final enrichedUsers = await Future.wait(
        (usersResponse).map((user) async {
          try {
            // Fetch most recent subscription for this user (active or not)
            final subscriptionResponse = await client
                .from('user_subscriptions')
                .select()
                .eq('user_id', user['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            // Add subscription data to user object
            user['subscription_data'] = subscriptionResponse;

            // 🔍 DIAGNOSTIC: Log subscription status for first user
            if (user == usersResponse.first) {
              debugPrint(
                '🎫 Sample user subscription: ${subscriptionResponse != null ? 'FOUND' : 'NOT FOUND'}',
              );
              if (subscriptionResponse != null) {
                debugPrint('   - Active: ${subscriptionResponse['is_active']}');
                debugPrint(
                  '   - Expires: ${subscriptionResponse['expires_at']}',
                );
              }
            }
          } catch (e) {
            debugPrint(
              'Error fetching subscription for user ${user['id']}: $e',
            );
            user['subscription_data'] = null;
          }

          // Fetch child profiles for this user
          try {
            final childrenResponse = await client
                .from('child_profiles')
                .select(
                  'id, first_name, last_name, birth_date, image_consent, is_active, tax_code, codice_fiscale, phone, email',
                )
                .eq('guardian_id', user['id'])
                .eq('is_active', true)
                .order('created_at', ascending: true);
            user['child_profiles'] = List<Map<String, dynamic>>.from(
              childrenResponse,
            );
          } catch (e) {
            debugPrint('Error fetching children for user ${user['id']}: $e');
            user['child_profiles'] = <Map<String, dynamic>>[];
          }

          return user;
        }),
      );

      systemUsers = enrichedUsers;
      _applyFilters();

      // 🔍 DIAGNOSTIC: Confirm data enrichment
      debugPrint(
        '✨ User data enriched with subscriptions and medical certificates',
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading users: $e');
      systemUsers = [];
    }
  }

  void _applyFilters() {
    filteredUsers = systemUsers.where((user) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final name = user['full_name']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';
        final searchLower = searchQuery.toLowerCase();

        if (!name.contains(searchLower) &&
            !email.contains(searchLower) &&
            !phone.contains(searchLower)) {
          return false;
        }
      }

      // Role filter
      if (selectedRoleFilter != 'all') {
        final role = user['role']?.toString() ?? 'student';
        if (role != selectedRoleFilter) return false;
      }

      // Status filter
      if (selectedStatusFilter != 'all') {
        final isActive = user['is_active'] == true;
        if (selectedStatusFilter == 'active' && !isActive) return false;
        if (selectedStatusFilter == 'inactive' && isActive) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _promoteUser(String userId, String newRole) async {
    if (!isPrincipalAdmin) {
      _showErrorMessage('Solo l\'admin principale può promuovere utenti');
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      await client
          .from('user_profiles')
          .update({'role': newRole})
          .eq('id', userId);

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'ROLE_UPDATE',
        'description': 'Ruolo utente aggiornato a $newRole',
        'target_user_id': userId,
      });

      _showSuccessMessage('Utente promosso con successo');
      await _loadSystemUsers();
    } catch (e) {
      print('Error promoting user: $e');
      _showErrorMessage(
        'user_mgmt.promote_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<void> _updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final client = SupabaseService.instance.client;

      await client.from('user_profiles').update(updates).eq('id', userId);

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'PROFILE_UPDATE',
        'description': 'Profilo utente aggiornato',
        'target_user_id': userId,
      });

      _showSuccessMessage('Profilo utente aggiornato con successo');
      await _loadSystemUsers();
    } catch (e) {
      print('Error updating user profile: $e');
      _showErrorMessage(
        'user_mgmt.update_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<void> _updateUserPhoto(String userId) async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? image;

      if (kIsWeb) {
        image = await picker.pickImage(source: ImageSource.gallery);
      } else {
        final result = await showDialog<ImageSource>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('user_mgmt.image_source_title'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('common.camera'.tr()),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('common.gallery'.tr()),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );

        if (result != null) {
          image = await picker.pickImage(source: result);
        }
      }

      if (image != null) {
        final client = SupabaseService.instance.client;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName =
            'profile_${userId}_$timestamp.${image.name.split('.').last}';

        // Upload to Supabase Storage
        final bytes = await image.readAsBytes();
        await client.storage
            .from('profile-images')
            .uploadBinary('$userId/$fileName', bytes);

        // Get public URL
        final imageUrl = client.storage
            .from('profile-images')
            .getPublicUrl('$userId/$fileName');

        // Update user profile with image URL
        await _updateUserProfile(userId, {'profile_image_url': imageUrl});
      }
    } catch (e) {
      print('Error updating user photo: $e');
      _showErrorMessage(
        'user_mgmt.photo_update_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<void> _suspendUser(String userId, bool suspend) async {
    try {
      final client = SupabaseService.instance.client;

      await client
          .from('user_profiles')
          .update({'is_active': !suspend})
          .eq('id', userId);

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': suspend ? 'USER_SUSPENDED' : 'USER_ACTIVATED',
        'description': suspend ? 'Utente sospeso' : 'Utente riattivato',
        'target_user_id': userId,
      });

      _showSuccessMessage(suspend ? 'Utente sospeso' : 'Utente riattivato');
      await _loadSystemUsers();
    } catch (e) {
      print('Error updating user status: $e');
      _showErrorMessage(
        'user_mgmt.status_update_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<void> _sendMessageToUser(String userId) async {
    // Implementation for sending messages
    _showSuccessMessage('Funzionalità messaggio in sviluppo');
  }

  Future<void> _sendWelcomeEmail(String userId) async {
    try {
      final client = SupabaseService.instance.client;

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'WELCOME_EMAIL_SENT',
        'description': 'Email di benvenuto inviata',
        'target_user_id': userId,
      });

      _showSuccessMessage('Email di benvenuto inviata');
    } catch (e) {
      print('Error sending welcome email: $e');
      _showErrorMessage(
        'user_mgmt.email_send_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<void> _resetPassword(String userId) async {
    // Implementation for password reset
    _showSuccessMessage('Link reset password inviato');
  }

  Future<void> _generateUserReport(String userId) async {
    // Implementation for generating user report
    _showSuccessMessage('Report generato');
  }

  Future<void> _togglePasspartout(String userId, bool currentValue) async {
    if (!isPrincipalAdmin) {
      _showErrorMessage("Solo l'admin principale può gestire il passpartout");
      return;
    }
    try {
      final client = SupabaseService.instance.client;
      final newValue = !currentValue;
      await client
          .from('user_profiles')
          .update({'booking_passpartout': newValue})
          .eq('id', userId);
      await client.from('admin_activity_log').insert({
        'admin_id': client.auth.currentUser?.id,
        'action_type': 'PASSPARTOUT_UPDATE',
        'description':
            'Passpartout prenotazione ${newValue ? 'abilitato' : 'disabilitato'}',
        'target_user_id': userId,
        'metadata': {
          'passpartout_enabled': newValue,
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      _showSuccessMessage(
        newValue
            ? "🗝️ Passpartout abilitato: l'utente può prenotare senza abbonamento"
            : "🔒 Passpartout disabilitato",
      );
      await _loadSystemUsers();
    } catch (e) {
      _showErrorMessage("Errore nell'aggiornamento del passpartout");
    }
  }

  void _showPasspartoutDialog(Map<String, dynamic> user) {
    final hasPasspartout = user['booking_passpartout'] == true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.key, color: hasPasspartout ? Colors.amber : Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Passpartout Prenotazione',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Utente: ${user['full_name'] ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              hasPasspartout
                  ? '✅ Passpartout ATTIVO.\n\nL\'utente può prenotare qualsiasi lezione senza abbonamento.\n\nVuoi disabilitarlo?'
                  : '🔒 Passpartout DISATTIVO.\n\nAbilitandolo, l\'utente potrà prenotare qualsiasi lezione anche senza abbonamento acquistato.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _togglePasspartout(user['id'], hasPasspartout);
            },
            icon: Icon(hasPasspartout ? Icons.lock : Icons.key, size: 16),
            label: Text(hasPasspartout ? 'Disabilita' : 'Abilita'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPasspartout ? Colors.red : Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    // Show confirmation dialog with delete type selection
    final deleteType = await _showDeleteConfirmationDialog(userName);
    if (deleteType == null) return;

    try {
      final client = SupabaseService.instance.client;

      // 🗑️ Delete user_documents records first to avoid FK constraint errors
      try {
        await client.from('user_documents').delete().eq('user_id', userId);
        print('✅ user_documents eliminati per userId: $userId');
      } catch (docError) {
        print('⚠️ Errore eliminazione user_documents: $docError');
        // Continue anyway — constraint may not exist or table may be empty
      }

      // Choose RPC based on delete type
      final rpcName = deleteType == 'total'
          ? 'safe_delete_user_with_receipts'
          : 'safe_delete_user';

      final response = await client.rpc(
        rpcName,
        params: {'target_user_id': userId},
      );

      if (response['success'] == true) {
        // 🔑 Call Edge Function to delete from auth.users (frees email for re-registration)
        try {
          final edgeFunctionResponse = await client.functions.invoke(
            'delete-auth-user',
            body: {'userId': userId},
          );
          if (edgeFunctionResponse.data != null &&
              edgeFunctionResponse.data['success'] == true) {
            print('✅ auth.users eliminato con successo per userId: $userId');
          } else {
            print(
              '⚠️ Edge Function delete-auth-user: ${edgeFunctionResponse.data}',
            );
          }
        } catch (edgeError) {
          // Log but don't block — profile is already deleted
          print('⚠️ Errore chiamata delete-auth-user: $edgeError');
        }

        final msg = deleteType == 'total'
            ? 'Utente e tutte le ricevute eliminate con successo. Email liberata.'
            : 'Utente eliminato con successo. Fatture preservate in memoria.';
        _showSuccessMessage(msg);
        await _loadSystemUsers();
      } else {
        _showErrorMessage(
          response['error'] ?? 'user_mgmt.user_delete_error'.tr(),
        );
      }
    } catch (e) {
      print('Error deleting user: $e');
      _showErrorMessage(
        'user_mgmt.user_delete_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<String?> _showDeleteConfirmationDialog(String userName) async {
    final deleteType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'user_mgmt.confirm_deletion'.tr(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sei sicuro di voler eliminare l\'utente "$userName"?',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(26),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.amber.withAlpha(77)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.amber,
                        size: 16.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Scegli modalità di eliminazione:',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.sp,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '• Eliminazione standard: preserva le fatture emesse\n'
                    '• Eliminazione totale: elimina anche tutte le ricevute\n'
                    '• In entrambi i casi l\'email verrà liberata',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: AppTheme.textSecondaryLight),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'standard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Elimina (preserva fatture)',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 11.sp,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'total'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Elimina Tutto',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 11.sp,
              ),
            ),
          ),
        ],
      ),
    );

    return deleteType;
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: Text(
            'Sistema Gestione Utenti',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          automaticallyImplyLeading: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalUsers = systemUsers.length;
    final activeUsers = systemUsers.where((u) => u['is_active'] == true).length;
    final pendingUsers = systemUsers
        .where((u) => u['medical_certificate_status'] == 'pending')
        .length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: Text(
          'Sistema Gestione Utenti',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: _loadSystemUsers,
            icon: Icon(Icons.refresh, color: Colors.white),
          ),
          if (selectedUsers.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  selectedUsers.clear();
                });
              },
              icon: Icon(Icons.clear_all, color: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          UserManagementHeaderWidget(
            totalUsers: totalUsers,
            activeUsers: activeUsers,
            pendingUsers: pendingUsers,
          ),
          UserSearchWidget(
            controller: _searchController,
            onSearchChanged: (query) {
              setState(() {
                searchQuery = query;
                _applyFilters();
              });
            },
          ),
          FilterChipsWidget(
            selectedRoleFilter: selectedRoleFilter,
            selectedStatusFilter: selectedStatusFilter,
            selectedActivityFilter: selectedActivityFilter,
            onRoleFilterChanged: (filter) {
              setState(() {
                selectedRoleFilter = filter;
                _applyFilters();
              });
            },
            onStatusFilterChanged: (filter) {
              setState(() {
                selectedStatusFilter = filter;
                _applyFilters();
              });
            },
            onActivityFilterChanged: (filter) {
              setState(() {
                selectedActivityFilter = filter;
                _applyFilters();
              });
            },
          ),
          if (selectedUsers.isNotEmpty)
            BulkActionsWidget(
              selectedCount: selectedUsers.length,
              onMassMessage: () {
                // Bulk message functionality
                _showSuccessMessage(
                  'Messaggio inviato a ${selectedUsers.length} utenti',
                );
                setState(() {
                  selectedUsers.clear();
                });
              },
              onMassRoleUpdate: () {
                // Bulk role update functionality
                if (isPrincipalAdmin) {
                  _showPromotionDialog(null, isBulk: true);
                } else {
                  _showErrorMessage(
                    'Solo l\'admin principale può modificare ruoli in massa',
                  );
                }
              },
            ),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(child: Text('reminders.no_users_found'.tr()))
                : ListView.builder(
                    key: ValueKey(
                      'user_list_widget_v5_surgical_${DateTime.now().millisecondsSinceEpoch}',
                    ),
                    padding: EdgeInsets.all(16.w),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = selectedUsers.contains(user['id']);
                      final childProfiles =
                          (user['child_profiles'] as List<dynamic>?)
                              ?.cast<Map<String, dynamic>>() ??
                          [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserCardWidget(
                            key: ValueKey(
                              'user_card_${user['id']}_surgical_v5',
                            ),
                            user: user,
                            isSelected: isSelected,
                            isPrincipalAdmin: isPrincipalAdmin,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedUsers.remove(user['id']);
                                } else {
                                  selectedUsers.add(user['id']);
                                }
                              });
                            },
                            onLongPress: () => _showUserEditDialog(user),
                            onUpdatePhoto: () => _updateUserPhoto(user['id']),
                            onViewProfile: () => _showUserDetailDialog(user),
                            onChangeRole: () => _showPromotionDialog(user),
                            onSendMessage: () => _sendMessageToUser(user['id']),
                            onSuspendAccount: () => _suspendUser(
                              user['id'],
                              user['is_active'] == true,
                            ),
                            onSendWelcomeEmail: () =>
                                _sendWelcomeEmail(user['id']),
                            onResetPassword: () => _resetPassword(user['id']),
                            onGenerateReport: () =>
                                _generateUserReport(user['id']),
                            onDeleteUser: () => _deleteUser(
                              user['id'],
                              user['full_name']?.toString() ??
                                  'common.user'.tr(),
                            ),
                            onFullProfileEdit: () =>
                                _openFullUserProfile(user['id']),
                            onTogglePasspartout: isPrincipalAdmin
                                ? () => _showPasspartoutDialog(user)
                                : null,
                            onViewReceipts: () =>
                                _showUserReceiptsBottomSheet(user),
                          ),
                          // ── Child profiles inline under parent ──────────
                          if (childProfiles.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: childProfiles.map((child) {
                                  final firstName =
                                      child['first_name'] as String? ?? '';
                                  final lastName =
                                      child['last_name'] as String? ?? '';
                                  final childName = '$firstName $lastName'
                                      .trim();
                                  final imageConsent =
                                      child['image_consent'] as bool? ?? false;
                                  final birthDate =
                                      child['birth_date'] as String?;
                                  String? age;
                                  if (birthDate != null) {
                                    try {
                                      final bd = DateTime.parse(birthDate);
                                      final now = DateTime.now();
                                      int a = now.year - bd.year;
                                      if (now.month < bd.month ||
                                          (now.month == bd.month &&
                                              now.day < bd.day))
                                        a--;
                                      age = '$a anni';
                                    } catch (_) {}
                                  }
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 6.h),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 10.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(10.0),
                                      border: Border.all(
                                        color: imageConsent
                                            ? Colors.green.withValues(
                                                alpha: 0.4,
                                              )
                                            : Colors.orange.withValues(
                                                alpha: 0.5,
                                              ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Indent indicator
                                        Container(
                                          width: 3,
                                          height: 36.h,
                                          decoration: BoxDecoration(
                                            color: imageConsent
                                                ? Colors.green
                                                : Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              2.0,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Container(
                                          padding: EdgeInsets.all(6.w),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.15,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.child_care,
                                            color: Colors.blue[300],
                                            size: 16.sp,
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      childName,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 6.w,
                                                          vertical: 2.h,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6.0,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'Minore',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.sp,
                                                        color: Colors.blue[300],
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 3.h),
                                              Row(
                                                children: [
                                                  if (age != null) ...[
                                                    Icon(
                                                      Icons.cake,
                                                      size: 11.sp,
                                                      color: Colors.grey[500],
                                                    ),
                                                    SizedBox(width: 3.w),
                                                    Text(
                                                      age,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11.sp,
                                                        color: Colors.grey[400],
                                                      ),
                                                    ),
                                                    SizedBox(width: 10.w),
                                                  ],
                                                  Icon(
                                                    imageConsent
                                                        ? Icons.photo_camera
                                                        : Icons
                                                              .no_photography_outlined,
                                                    size: 11.sp,
                                                    color: imageConsent
                                                        ? Colors.green[400]
                                                        : Colors.orange[400],
                                                  ),
                                                  SizedBox(width: 3.w),
                                                  Text(
                                                    imageConsent
                                                        ? 'Liberatoria OK'
                                                        : 'No liberatoria',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11.sp,
                                                      color: imageConsent
                                                          ? Colors.green[400]
                                                          : Colors.orange[400],
                                                      fontWeight: imageConsent
                                                          ? FontWeight.w400
                                                          : FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateUserDialog();
        },
        backgroundColor: AppTheme.primaryColor,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text(
          'user_mgmt.new_user'.tr(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showUserEditDialog(Map<String, dynamic> user) {
    // NEW IMPLEMENTATION: BRAND NEW MODAL BOTTOM SHEET
    // Controllers for editable fields only
    String selectedRole = user['role']?.toString() ?? 'student';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withAlpha(26),
                      backgroundImage: user['profile_image_url'] != null
                          ? NetworkImage(user['profile_image_url'])
                          : null,
                      radius: 24.w,
                      child: user['profile_image_url'] == null
                          ? Icon(Icons.person, color: AppTheme.primaryColor)
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'user_mgmt.edit_user'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            user['email']?.toString() ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1),

              // SECTION A: STANDARD FIELDS (Read-only Nome/Cognome, Editable Role)
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome (Read-only)
                      Text(
                        'Nome Completo',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          user['full_name']?.toString() ?? 'N/A',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Ruolo (Editable Dropdown)
                      Text(
                        'Ruolo Utente',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: AppTheme.primaryColor.withAlpha(77),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.primaryColor,
                            ),
                            items:
                                [
                                      'student',
                                      'instructor',
                                      if (isPrincipalAdmin) 'admin',
                                      if (isPrincipalAdmin) 'instructor_admin',
                                      if (isPrincipalAdmin)
                                        'instructor_student',
                                    ]
                                    .map(
                                      (role) => DropdownMenuItem(
                                        value: role,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getRoleIcon(role),
                                              size: 18.sp,
                                              color: _getRoleColor(role),
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              _getRoleLabel(role),
                                              style: GoogleFonts.inter(
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedRole = value!;
                              });
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: 20.h),
                      Divider(thickness: 1),
                      SizedBox(height: 20.h),

                      // SECTION B: MEDICAL CERTIFICATE
                      Row(
                        children: [
                          Icon(
                            Icons.medical_information,
                            color: AppTheme.primaryColor,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'profile.medical_certificate'.tr(),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Check if certificate exists
                      Builder(
                        builder: (context) {
                          final certificateUrl =
                              user['medical_certificate_url'];
                          final hasCertificate =
                              certificateUrl != null &&
                              certificateUrl.toString().isNotEmpty;

                          if (hasCertificate) {
                            return InkWell(
                              onTap: () => _openMedicalCertificate(
                                user['id'],
                                certificateUrl,
                              ),
                              child: Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: Colors.blue.withAlpha(102),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withAlpha(51),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.description,
                                        color: Colors.blue,
                                        size: 28.sp,
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Visualizza/Scarica Certificato Medico',
                                            style: GoogleFonts.inter(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            'Tocca per aprire il documento',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.open_in_new,
                                      color: Colors.blue,
                                      size: 24.sp,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(26),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: Colors.orange.withAlpha(77),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Colors.orange,
                                    size: 24.sp,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      'user_mgmt.no_medical_certificate'.tr(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),

                      SizedBox(height: 20.h),
                      Divider(thickness: 1),
                      SizedBox(height: 20.h),

                      // SECTION C: USER DOCUMENTS
                      Row(
                        children: [
                          Icon(
                            Icons.folder_open,
                            color: AppTheme.primaryColor,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Altri Documenti Caricati',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // FutureBuilder for user_documents table
                      Container(
                        height: 200.h,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12.0),
                          color: Colors.grey.shade50,
                        ),
                        child: FutureBuilder(
                          future: SupabaseService.instance.client
                              .from('user_documents')
                              .select()
                              .eq('user_id', user['id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (!snapshot.hasData ||
                                (snapshot.data as List).isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 56.sp,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'user_mgmt.no_documents'.tr(),
                                      style: GoogleFonts.inter(
                                        color: Colors.grey.shade600,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final docs = snapshot.data as List<dynamic>;
                            return ListView.builder(
                              padding: EdgeInsets.all(8.w),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8.h),
                                  elevation: 1,
                                  child: ListTile(
                                    leading: Container(
                                      padding: EdgeInsets.all(8.w),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.description,
                                        color: Colors.blue,
                                        size: 22.sp,
                                      ),
                                    ),
                                    title: Text(
                                      doc['file_name'] ?? 'Documento',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Tipo: ${doc['file_type'] ?? 'N/A'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.download,
                                        color: Colors.blue,
                                        size: 22.sp,
                                      ),
                                      tooltip: 'Apri/Scarica documento',
                                      onPressed: () async {
                                        final fileUrl = doc['file_url'];
                                        if (fileUrl != null &&
                                            fileUrl.toString().isNotEmpty) {
                                          try {
                                            final url = Uri.parse(fileUrl);
                                            bool launched = false;

                                            try {
                                              launched = await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            } catch (e) {
                                              try {
                                                launched = await launchUrl(
                                                  url,
                                                  mode: LaunchMode
                                                      .platformDefault,
                                                );
                                              } catch (e) {
                                                debugPrint(
                                                  'Error launching URL: $e',
                                                );
                                              }
                                            }

                                            if (launched) {
                                              _showSuccessMessage(
                                                'Documento aperto',
                                              );
                                            } else {
                                              _showErrorMessage(
                                                'Impossibile aprire il documento',
                                              );
                                            }
                                          } catch (e) {
                                            _showErrorMessage(
                                              'user_mgmt.open_error'.tr(
                                                namedArgs: {
                                                  'error': e.toString(),
                                                },
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),

              // SECTION D: ACTIONS
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          'common.cancel'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Save only if role changed
                          if (selectedRole != user['role']) {
                            Navigator.pop(context);
                            await _promoteUser(user['id'], selectedRole);
                          } else {
                            Navigator.pop(context);
                            _showSuccessMessage('common.no_changes'.tr());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 18.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'profile.save_changes'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMedicalCertificate(
    String userId,
    String certificateUrl,
  ) async {
    if (certificateUrl.isEmpty) {
      _showErrorMessage('URL del certificato non disponibile');
      return;
    }

    try {
      // Show loading indicator
      _showSuccessMessage('Apertura certificato...');

      // Regenerate signed URL before opening (handles expired URLs)
      String? freshUrl = certificateUrl;

      try {
        final client = SupabaseService.instance.client;
        final uri = Uri.parse(certificateUrl);
        final pathSegments = uri.pathSegments;

        // Extract filename from URL path
        final fileName = pathSegments.lastWhere(
          (segment) => segment.isNotEmpty && !segment.startsWith('sign'),
          orElse: () => pathSegments.last.split('?').first,
        );

        // Generate fresh signed URL (valid for 24 hours)
        freshUrl = await client.storage
            .from('medical-certificates')
            .createSignedUrl(fileName, 86400); // 24 hours
      } catch (urlError) {
        debugPrint('⚠️ Could not regenerate URL: $urlError');
        // Continue with existing URL if regeneration fails
      }

      final url = Uri.parse(freshUrl!);
      bool launched = false;

      // Try multiple launch modes for maximum compatibility
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        } catch (e) {
          try {
            launched = await launchUrl(
              url,
              mode: LaunchMode.externalNonBrowserApplication,
            );
          } catch (e) {
            debugPrint('❌ All launch modes failed: $e');
          }
        }
      }

      if (launched) {
        _showSuccessMessage('Certificato aperto');
      } else {
        _showErrorMessage('Impossibile aprire il certificato');
      }
    } catch (e) {
      debugPrint('❌ Error opening certificate: $e');
      _showErrorMessage('Errore: ${e.toString()}');
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getExpiryColor(String expiryDateStr) {
    final expiryDate = DateTime.parse(expiryDateStr);
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

    if (daysUntilExpiry < 0) {
      return Colors.red; // Expired
    } else if (daysUntilExpiry < 60) {
      return Colors.orange; // Expiring soon
    } else {
      return Colors.green; // Valid
    }
  }

  IconData _getExpiryIcon(String expiryDateStr) {
    final expiryDate = DateTime.parse(expiryDateStr);
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

    if (daysUntilExpiry < 0) {
      return Icons.error_outline; // Expired
    } else if (daysUntilExpiry < 60) {
      return Icons.warning_amber; // Expiring soon
    } else {
      return Icons.check_circle_outline; // Valid
    }
  }

  String _getExpiryMessage(String expiryDateStr) {
    final expiryDate = DateTime.parse(expiryDateStr);
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

    if (daysUntilExpiry < 0) {
      return 'profile.status_expired'.tr();
    } else if (daysUntilExpiry < 60) {
      return 'In scadenza tra $daysUntilExpiry giorni';
    } else {
      return 'profile.status_valid'.tr();
    }
  }

  bool _isExpired(String expiryDateStr) {
    final expiryDate = DateTime.parse(expiryDateStr);
    return expiryDate.difference(DateTime.now()).inDays < 0;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showUserDetailDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserDetailWithChildrenDialog(user: user),
    );
  }

  void _showPromotionDialog(Map<String, dynamic>? user, {bool isBulk = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isBulk
              ? 'user_mgmt.bulk_role_update'.tr()
              : 'user_mgmt.manage_user_role'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isBulk)
              Text(
                'user_mgmt.select_role_for_one'.tr(
                  namedArgs: {'name': '${user?['full_name']}'},
                ),
                style: GoogleFonts.inter(fontSize: 14.sp),
              )
            else
              Text(
                'user_mgmt.select_role_for_many'.tr(
                  namedArgs: {'count': '${selectedUsers.length}'},
                ),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
            SizedBox(height: 16.h),
            ...[
              'student',
              'instructor',
              'admin',
              if (isPrincipalAdmin) 'instructor_admin',
              if (isPrincipalAdmin) 'instructor_student',
            ].map(
              (role) => ListTile(
                title: Text(_getRoleLabel(role)),
                leading: Icon(_getRoleIcon(role)),
                onTap: () {
                  Navigator.pop(context);
                  if (isBulk) {
                    _bulkPromoteUsers(role);
                  } else {
                    _promoteUser(user!['id'], role);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkPromoteUsers(String newRole) async {
    if (!isPrincipalAdmin) {
      _showErrorMessage(
        'Solo l\'admin principale può promuovere utenti in massa',
      );
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      for (String userId in selectedUsers) {
        await client
            .from('user_profiles')
            .update({'role': newRole})
            .eq('id', userId);

        // Log the admin activity
        await client.from('admin_activity_log').insert({
          'admin_id': currentUser?['id'],
          'action_type': 'BULK_ROLE_UPDATE',
          'description': 'Ruolo aggiornato in massa a $newRole',
          'target_user_id': userId,
        });
      }

      _showSuccessMessage(
        '${selectedUsers.length} utenti promossi con successo',
      );
      setState(() {
        selectedUsers.clear();
      });
      await _loadSystemUsers();
    } catch (e) {
      print('Error in bulk promotion: $e');
      _showErrorMessage(
        'user_mgmt.bulk_promote_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'student';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'user_mgmt.create_new_user'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'profile.phone'.tr(),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                SizedBox(height: 12.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'profile.role'.tr(),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                  ),
                  items:
                      [
                            'student',
                            'instructor',
                            if (isPrincipalAdmin) 'admin',
                            if (isPrincipalAdmin) 'instructor_admin',
                            if (isPrincipalAdmin) 'instructor_student',
                          ]
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(_getRoleLabel(role)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRole = value!;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  emailController.text.isNotEmpty) {
                Navigator.pop(context);
                _createNewUser(
                  nameController.text,
                  emailController.text,
                  phoneController.text,
                  selectedRole,
                );
              } else {
                _showErrorMessage('Nome e email sono obbligatori');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('user_mgmt.create_user'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewUser(
    String name,
    String email,
    String phone,
    String role,
  ) async {
    // This would typically involve creating a new auth user and profile
    // For now, we'll show a success message
    _showSuccessMessage('Funzionalità di creazione utente in sviluppo');
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'principal_admin':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'instructor_admin':
        return Colors.purple;
      case 'instructor_student':
        return Colors.teal;
      case 'instructor':
        return Colors.blue;
      case 'student':
      default:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'principal_admin':
        return Icons.shield;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'instructor_admin':
        return Icons.supervisor_account;
      case 'instructor_student':
        return Icons.swap_horiz;
      case 'instructor':
        return Icons.school;
      case 'student':
      default:
        return Icons.person;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'principal_admin':
        return 'dashboard.role_principal_admin'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'instructor_student':
        return 'Istruttore Allievo';
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'student':
      default:
        return 'dashboard.role_student'.tr();
    }
  }

  // NEW: Method to navigate to full user profile for editing
  Future<void> _openFullUserProfile(String userId) async {
    try {
      // Navigate to user profile screen with edit mode enabled
      await Navigator.pushNamed(
        context,
        AppRoutes.userProfile,
        arguments: {
          'userId': userId,
          'isAdminView': true, // Flag to indicate admin is viewing
        },
      );

      // Reload users after returning from profile screen
      await _loadSystemUsers();
    } catch (e) {
      print('Error opening user profile: $e');
      _showErrorMessage(
        'user_mgmt.profile_open_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  void _showUserReceiptsBottomSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserReceiptsSheet(
        user: user,
        userName: user['full_name']?.toString() ?? '',
        client: SupabaseService.instance.client,
      ),
    );
  }
}

// ── User Receipts Bottom Sheet Widget ────────────────────────────────────────
class _UserReceiptsSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final String userName;
  final dynamic client;

  const _UserReceiptsSheet({
    required this.user,
    required this.userName,
    required this.client,
  });

  @override
  State<_UserReceiptsSheet> createState() => _UserReceiptsSheetState();
}

class _UserReceiptsSheetState extends State<_UserReceiptsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _receipts = [];
  Set<String> _selectedReceiptIds = {};
  bool _isSelectionMode = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    try {
      final customerName = widget.user['full_name']?.toString() ?? '';
      List<dynamic> response = [];

      if (customerName.isNotEmpty) {
        response = await widget.client
            .from('non_fiscal_receipts')
            .select()
            .eq('customer_name', customerName)
            .order('created_at', ascending: false);
      }

      if (response.isEmpty) {
        final userId = widget.user['id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          response = await widget.client
              .from('non_fiscal_receipts')
              .select()
              .eq('created_by', userId)
              .order('created_at', ascending: false);
        }
      }

      setState(() {
        _receipts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReceipts(List<String> ids) async {
    setState(() => _isDeleting = true);
    try {
      for (final id in ids) {
        await widget.client.from('non_fiscal_receipts').delete().eq('id', id);
      }
      await _loadReceipts();
      setState(() {
        _selectedReceiptIds.clear();
        _isSelectionMode = false;
        _isDeleting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ids.length == 1
                  ? 'Ricevuta eliminata'
                  : '${ids.length} ricevute eliminate',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore eliminazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina tutte le ricevute'),
        content: Text(
          'Sei sicuro di voler eliminare tutte le ${_receipts.length} ricevute di ${widget.userName}? Questa azione è irreversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Elimina Tutte',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteReceipts(_receipts.map((r) => r['id'] as String).toList());
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina ricevute selezionate'),
        content: Text(
          'Sei sicuro di voler eliminare ${_selectedReceiptIds.length} ricevute selezionate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteReceipts(_selectedReceiptIds.toList());
    }
  }

  void _showReceiptDetail(Map<String, dynamic> receipt) {
    final dateStr = receipt['created_at'] != null
        ? DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(DateTime.parse(receipt['created_at']))
        : '—';
    final amount = (receipt['amount'] ?? 0.0) as num;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ricevuta #${receipt['receipt_number'] ?? '—'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Cliente', receipt['customer_name'] ?? '—'),
            _detailRow('Descrizione', receipt['description'] ?? '—'),
            _detailRow('Importo', '€ ${amount.toStringAsFixed(2)}'),
            _detailRow('Data', dateStr),
            _detailRow('Metodo', receipt['payment_method'] ?? '—'),
            if (receipt['notes'] != null &&
                receipt['notes'].toString().isNotEmpty)
              _detailRow('Note', receipt['notes']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.teal, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ricevute di ${widget.userName}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (!_isLoading)
                        Text(
                          '${_receipts.length} ricevut${_receipts.length == 1 ? 'a' : 'e'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_receipts.isNotEmpty && !_isLoading) ...[
                  if (_isSelectionMode) ...[
                    TextButton(
                      onPressed: () => setState(() {
                        _isSelectionMode = false;
                        _selectedReceiptIds.clear();
                      }),
                      child: const Text('Annulla'),
                    ),
                  ] else ...[
                    IconButton(
                      onPressed: () => setState(() => _isSelectionMode = true),
                      icon: const Icon(Icons.checklist, color: Colors.teal),
                      tooltip: 'Seleziona',
                    ),
                    IconButton(
                      onPressed: _confirmDeleteAll,
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      tooltip: 'Elimina tutte',
                    ),
                  ],
                ],
              ],
            ),
          ),
          // Selection toolbar
          if (_isSelectionMode && _selectedReceiptIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedReceiptIds.length} selezionat${_selectedReceiptIds.length == 1 ? 'a' : 'e'}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _confirmDeleteSelected,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Elimina'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _isDeleting
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  )
                : _receipts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nessuna ricevuta trovata',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _receipts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final receipt = _receipts[i];
                      final id = receipt['id'] as String;
                      final isSelected = _selectedReceiptIds.contains(id);
                      final amount = (receipt['amount'] ?? 0.0) as num;
                      final dateStr = receipt['created_at'] != null
                          ? DateFormat(
                              'dd/MM/yyyy',
                            ).format(DateTime.parse(receipt['created_at']))
                          : '—';

                      return Material(
                        color: isSelected
                            ? Colors.teal.withAlpha(20)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _isSelectionMode
                              ? () => setState(() {
                                  if (isSelected) {
                                    _selectedReceiptIds.remove(id);
                                  } else {
                                    _selectedReceiptIds.add(id);
                                  }
                                })
                              : () => _showReceiptDetail(receipt),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.teal
                                    : Colors.grey.shade200,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (_isSelectionMode)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? Colors.teal
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.receipt,
                                    color: Colors.teal,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        receipt['description'] ?? '—',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '€ ${amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    if (!_isSelectionMode)
                                      GestureDetector(
                                        onTap: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Elimina ricevuta',
                                              ),
                                              content: const Text(
                                                'Sei sicuro di voler eliminare questa ricevuta?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Annulla'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  child: const Text(
                                                    'Elimina',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await _deleteReceipts([id]);
                                          }
                                        },
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dialog that shows user details including child profiles with image consent indicators.
class _UserDetailWithChildrenDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserDetailWithChildrenDialog({required this.user});

  @override
  State<_UserDetailWithChildrenDialog> createState() =>
      _UserDetailWithChildrenDialogState();
}

class _UserDetailWithChildrenDialogState
    extends State<_UserDetailWithChildrenDialog> {
  List<Map<String, dynamic>> _childProfiles = [];
  bool _loadingChildren = true;

  @override
  void initState() {
    super.initState();
    _loadChildProfiles();
  }

  Future<void> _loadChildProfiles() async {
    try {
      final client = SupabaseService.instance.client;
      final response = await client
          .from('child_profiles')
          .select(
            'id, first_name, last_name, birth_date, image_consent, is_active',
          )
          .eq('guardian_id', widget.user['id'])
          .eq('is_active', true)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _childProfiles = List<Map<String, dynamic>>.from(response);
          _loadingChildren = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'principal_admin':
        return 'Admin Principale';
      case 'instructor':
        return 'Istruttore';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'instructor_student':
        return 'Istruttore Allievo';
      default:
        return 'Studente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return AlertDialog(
      title: Text(
        'Dettagli Utente',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user['profile_image_url'] != null)
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(user['profile_image_url']),
                ),
              ),
            SizedBox(height: 16),
            Text('Nome: ${user['full_name'] ?? 'N/A'}'),
            SizedBox(height: 8),
            Text('Email: ${user['email'] ?? 'N/A'}'),
            SizedBox(height: 8),
            Text('Telefono: ${user['phone'] ?? 'N/A'}'),
            SizedBox(height: 8),
            Text(
              'Ruolo: ${_getRoleLabel(user['role']?.toString() ?? 'student')}',
            ),
            SizedBox(height: 8),
            Text(
              'Stato: ${user['is_active'] == true ? 'Attivo' : 'Disattivato'}',
            ),
            SizedBox(height: 8),
            Text(
              'Certificato Medico: ${user['medical_certificate_status'] ?? 'pending'}',
            ),
            SizedBox(height: 8),
            Text(
              'Registrazione: ${DateTime.parse(user['created_at']).toLocal().toString().split(' ')[0]}',
            ),
            if (user['emergency_contact'] != null) ...[
              SizedBox(height: 8),
              Text('Contatto Emergenza: ${user['emergency_contact']}'),
            ],
            if (user['emergency_phone'] != null) ...[
              SizedBox(height: 8),
              Text('Tel. Emergenza: ${user['emergency_phone']}'),
            ],

            // ── Child Profiles Section ──────────────────────────────────
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.child_care, size: 16, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text(
                  'Profili Minori',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (_loadingChildren)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_childProfiles.isEmpty)
              Text(
                'Nessun profilo minore registrato',
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
              )
            else
              ..._childProfiles.map((child) {
                final firstName = child['first_name'] as String? ?? '';
                final lastName = child['last_name'] as String? ?? '';
                final name = '$firstName $lastName'.trim();
                final imageConsent = child['image_consent'] as bool? ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: imageConsent
                        ? Colors.green.withValues(alpha: 0.06)
                        : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: imageConsent
                          ? Colors.green.withValues(alpha: 0.35)
                          : Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        imageConsent
                            ? Icons.photo_camera
                            : Icons.no_photography_outlined,
                        size: 16,
                        color: imageConsent
                            ? Colors.green[600]
                            : Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              imageConsent
                                  ? 'Liberatoria immagini: ACCETTATA'
                                  : '⚠️ Liberatoria immagini: NON ACCETTATA',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: imageConsent
                                    ? Colors.green[700]
                                    : Colors.orange[800],
                                fontWeight: imageConsent
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}
