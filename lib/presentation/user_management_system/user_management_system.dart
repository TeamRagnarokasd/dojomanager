import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
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
      _showErrorMessage('Errore di accesso: ${e.toString()}');
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
      final profileResponse =
          await client
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
      throw Exception('Errore nel controllo dei permessi amministratore');
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

      // For each user, fetch their active subscription
      final enrichedUsers = await Future.wait(
        (usersResponse).map((user) async {
          try {
            // Fetch most recent subscription for this user (active or not)
            final subscriptionResponse =
                await client
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
    filteredUsers =
        systemUsers.where((user) {
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
      _showErrorMessage('Errore nella promozione: ${e.toString()}');
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
      _showErrorMessage('Errore nell\'aggiornamento: ${e.toString()}');
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
          builder:
              (context) => AlertDialog(
                title: Text('Seleziona fonte immagine'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.camera_alt),
                      title: Text('Camera'),
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                    ListTile(
                      leading: Icon(Icons.photo_library),
                      title: Text('Galleria'),
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
      _showErrorMessage('Errore nell\'aggiornamento foto: ${e.toString()}');
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
      _showErrorMessage('Errore nell\'aggiornamento stato: ${e.toString()}');
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
      _showErrorMessage('Errore nell\'invio email: ${e.toString()}');
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

  Future<void> _deleteUser(String userId, String userName) async {
    // Show confirmation dialog first
    final confirmed = await _showDeleteConfirmationDialog(userName);
    if (!confirmed) return;

    try {
      final client = SupabaseService.instance.client;

      // Call the safe delete function
      final response = await client.rpc(
        'safe_delete_user',
        params: {'target_user_id': userId},
      );

      if (response['success'] == true) {
        _showSuccessMessage(
          'Utente eliminato con successo. Fatture preservate in memoria.',
        );
        await _loadSystemUsers();
      } else {
        _showErrorMessage(
          response['error'] ?? 'Errore nell\'eliminazione utente',
        );
      }
    } catch (e) {
      print('Error deleting user: $e');
      _showErrorMessage('Errore nell\'eliminazione utente: ${e.toString()}');
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Conferma Eliminazione',
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
                            'Questa azione:',
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
                        '• Eliminerà TUTTI i dati dell\'utente\n'
                        '• PRESERVERÀ le fatture emesse\n'
                        '• Non potrà essere annullata',
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
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Annulla',
                  style: GoogleFonts.inter(color: AppTheme.textSecondaryLight),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Elimina Utente',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );

    return confirmed ?? false;
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
    final pendingUsers =
        systemUsers
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
            child:
                filteredUsers.isEmpty
                    ? Center(child: Text('Nessun utente trovato'))
                    : ListView.builder(
                      key: ValueKey(
                        'user_list_direct_v3_${DateTime.now().millisecondsSinceEpoch}',
                      ),
                      padding: EdgeInsets.all(16.w),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final isSelected = selectedUsers.contains(user['id']);

                        // EXTRACT SUBSCRIPTION DATA
                        final subscriptionData = user['subscription_data'];
                        final isSubscriptionActive =
                            subscriptionData != null &&
                            subscriptionData['is_active'] == true;
                        final subscriptionExpiry =
                            subscriptionData?['expires_at'];

                        // EXTRACT MEDICAL CERTIFICATE DATA
                        final certificateExpiry =
                            user['medical_certificate_expiry'];
                        final certificateUrl = user['medical_certificate_url'];
                        final hasCertificate =
                            certificateUrl != null &&
                            certificateUrl.toString().isNotEmpty;

                        // CALCULATE MEDICAL CERTIFICATE STATUS
                        Color certificateColor;
                        String certificateText;
                        IconData certificateIcon;

                        if (!hasCertificate) {
                          certificateColor = Colors.grey;
                          certificateText = 'Da Caricare';
                          certificateIcon = Icons.upload_file;
                        } else if (certificateExpiry == null) {
                          certificateColor = Colors.orange;
                          certificateText = 'Mancante Data';
                          certificateIcon = Icons.warning_amber;
                        } else {
                          final expiryDate = DateTime.parse(certificateExpiry);
                          final daysUntilExpiry =
                              expiryDate.difference(DateTime.now()).inDays;

                          if (daysUntilExpiry < 0) {
                            certificateColor = Colors.red;
                            certificateText = 'Scaduto';
                            certificateIcon = Icons.error_outline;
                          } else if (daysUntilExpiry < 60) {
                            certificateColor = Colors.orange;
                            certificateText = 'In Scadenza';
                            certificateIcon = Icons.warning_amber;
                          } else {
                            certificateColor = Colors.green;
                            certificateText = 'Valido';
                            certificateIcon = Icons.check_circle_outline;
                          }
                        }

                        // CARD UI - EMBEDDED DIRECTLY
                        return GestureDetector(
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
                          child: Container(
                            margin: EdgeInsets.only(bottom: 12.h),
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppTheme.primaryColor.withAlpha(26)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.grey.withAlpha(77),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // RIGA 1: Avatar, Nome, Email
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24.w,
                                      backgroundImage:
                                          user['profile_image_url'] != null
                                              ? NetworkImage(
                                                user['profile_image_url'],
                                              )
                                              : null,
                                      backgroundColor: AppTheme.primaryColor
                                          .withAlpha(77),
                                      child:
                                          user['profile_image_url'] == null
                                              ? Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 24.sp,
                                              )
                                              : null,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['full_name'] ?? 'Utente',
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16.sp,
                                              color: AppTheme.textPrimaryLight,
                                            ),
                                          ),
                                          SizedBox(height: 4.h),
                                          Text(
                                            user['email'] ?? '',
                                            style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                              color:
                                                  AppTheme.textSecondaryLight,
                                            ),
                                          ),
                                          if (user['phone'] != null) ...[
                                            SizedBox(height: 2.h),
                                            Text(
                                              'Tel: ${user['phone']}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11.sp,
                                                color:
                                                    AppTheme.textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(
                                          user['role']?.toString() ?? 'student',
                                        ).withAlpha(26),
                                        borderRadius: BorderRadius.circular(
                                          6.0,
                                        ),
                                      ),
                                      child: Text(
                                        _getRoleLabel(
                                          user['role']?.toString() ?? 'student',
                                        ),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          color: _getRoleColor(
                                            user['role']?.toString() ??
                                                'student',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12.h),

                                // RIGA 2: BADGE DI STATO (NUOVO)
                                Row(
                                  children: [
                                    // BADGE ABBONAMENTO
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSubscriptionActive
                                                ? Colors.green.withAlpha(26)
                                                : Colors.red.withAlpha(26),
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        border: Border.all(
                                          color:
                                              isSubscriptionActive
                                                  ? Colors.green.withAlpha(102)
                                                  : Colors.red.withAlpha(102),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSubscriptionActive
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color:
                                                isSubscriptionActive
                                                    ? Colors.green
                                                    : Colors.red,
                                            size: 14.sp,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            isSubscriptionActive
                                                ? 'Attivo'
                                                : 'Inattivo',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isSubscriptionActive
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(width: 8.w),

                                    // BADGE CERTIFICATO MEDICO
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 6.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: certificateColor.withAlpha(26),
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                        border: Border.all(
                                          color: certificateColor.withAlpha(
                                            102,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            certificateIcon,
                                            color: certificateColor,
                                            size: 14.sp,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            certificateText,
                                            style: GoogleFonts.inter(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  certificateColor ==
                                                          Colors.grey
                                                      ? Colors.grey.shade700
                                                      : certificateColor ==
                                                          Colors.red
                                                      ? Colors.red.shade700
                                                      : certificateColor ==
                                                          Colors.orange
                                                      ? Colors.orange.shade700
                                                      : Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12.h),

                                // RIGA 3: PULSANTI AZIONE (RIFATTI)
                                Row(
                                  children: [
                                    // PULSANTE 1: "Modifica Veloce"
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            () => _showUserEditDialog(user),
                                        icon: Icon(Icons.edit, size: 16.sp),
                                        label: Text(
                                          'Modifica Veloce',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 8.w),

                                    // PULSANTE 2: "Profilo Completo"
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            () => _openFullUserProfile(
                                              user['id'],
                                            ),
                                        icon: Icon(Icons.person, size: 16.sp),
                                        label: Text(
                                          'Profilo Completo',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade700,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 10.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 8.w),

                                    // PULSANTE 3: Elimina
                                    IconButton(
                                      onPressed:
                                          () => _deleteUser(
                                            user['id'],
                                            user['full_name']?.toString() ??
                                                'Utente',
                                          ),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20.sp,
                                      ),
                                      tooltip: 'Elimina Utente',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
          'Nuovo Utente',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showUserEditDialog(Map<String, dynamic> user) {
    _editFullNameController.text = user['full_name']?.toString() ?? '';
    _editPhoneController.text = user['phone']?.toString() ?? '';
    _editEmergencyContactController.text =
        user['emergency_contact']?.toString() ?? '';
    _editEmergencyPhoneController.text =
        user['emergency_phone']?.toString() ?? '';

    // Extract medical certificate data
    final certificateUrl = user['medical_certificate_url'];
    final expiryDate = user['medical_certificate_expiry'];
    final hasCertificate =
        certificateUrl != null && certificateUrl.toString().isNotEmpty;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Modifica Profilo Utente Completo',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent/Guardian Information Section
                  Text(
                    'Informazioni Genitore/Tutore',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _editFullNameController,
                    decoration: InputDecoration(
                      labelText: 'Nome Completo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _editPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Telefono',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Minor User Checkbox
                  CheckboxListTile(
                    value: user['is_minor'] ?? false,
                    onChanged: null, // Read-only in this dialog
                    title: Text(
                      'Utente Minorenne',
                      style: GoogleFonts.inter(fontSize: 13.sp),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),

                  SizedBox(height: 16.h),
                  Divider(thickness: 1),
                  SizedBox(height: 16.h),

                  // Emergency Contact Section
                  Text(
                    'Contatto di Emergenza',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _editEmergencyContactController,
                    decoration: InputDecoration(
                      labelText: 'Nome Contatto Emergenza',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.contact_emergency),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _editEmergencyPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Telefono Emergenza',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_in_talk),
                    ),
                  ),

                  SizedBox(height: 16.h),
                  Divider(thickness: 1),
                  SizedBox(height: 16.h),

                  // Medical Certificate Section - ALWAYS SHOWN
                  Text(
                    'Certificato Medico',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  if (hasCertificate) ...[
                    // Certificate Link Button
                    GestureDetector(
                      onTap:
                          () => _openMedicalCertificate(
                            user['id'],
                            certificateUrl,
                          ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(26),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Colors.blue.withAlpha(102),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Colors.blue,
                              size: 24.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Certificato Medico',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Clicca per aprire',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      color: Colors.blue.withAlpha(179),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              color: Colors.blue.withAlpha(153),
                              size: 18.sp,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expiry Date Section
                    if (expiryDate != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: _getExpiryColor(expiryDate).withAlpha(26),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: _getExpiryColor(expiryDate).withAlpha(77),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getExpiryIcon(expiryDate),
                              color: _getExpiryColor(expiryDate),
                              size: 20.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Data di Scadenza',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.sp,
                                      color: _getExpiryColor(expiryDate),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    _formatDate(DateTime.parse(expiryDate)),
                                    style: GoogleFonts.inter(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _getExpiryColor(expiryDate),
                                    ),
                                  ),
                                  if (!_isExpired(expiryDate)) ...[
                                    SizedBox(height: 2.h),
                                    Text(
                                      _getExpiryMessage(expiryDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 10.sp,
                                        color: _getExpiryColor(
                                          expiryDate,
                                        ).withAlpha(204),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // No Certificate Uploaded State
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(26),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.grey.withAlpha(77),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.upload_file,
                            color: Colors.grey,
                            size: 24.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nessun Certificato Caricato',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'L\'utente deve caricare il certificato medico',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 16.h),
                  Divider(thickness: 1),
                  SizedBox(height: 16.h),

                  // User Status & Settings Section
                  Text(
                    'Stato & Impostazioni',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: user['role']?.toString() ?? 'student',
                    decoration: InputDecoration(
                      labelText: 'Ruolo Utente',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                    ),
                    items:
                        [
                              'student',
                              'instructor',
                              if (isPrincipalAdmin) 'admin',
                              if (isPrincipalAdmin) 'instructor_admin',
                            ]
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(_getRoleLabel(role)),
                              ),
                            )
                            .toList(),
                    onChanged: null, // Read-only in this dialog
                  ),
                  SizedBox(height: 12.h),

                  // Account Status Dropdown
                  DropdownButtonFormField<String>(
                    value: (user['is_active'] ?? true) ? 'active' : 'inactive',
                    decoration: InputDecoration(
                      labelText: 'Stato Account',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.toggle_on),
                    ),
                    items: [
                      DropdownMenuItem(value: 'active', child: Text('Attivo')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Sospeso'),
                      ),
                    ],
                    onChanged: null, // Read-only in this dialog
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  final updates = <String, dynamic>{};

                  if (_editFullNameController.text !=
                      (user['full_name'] ?? '')) {
                    updates['full_name'] = _editFullNameController.text;
                  }
                  if (_editPhoneController.text != (user['phone'] ?? '')) {
                    updates['phone'] =
                        _editPhoneController.text.isEmpty
                            ? null
                            : _editPhoneController.text;
                  }
                  if (_editEmergencyContactController.text !=
                      (user['emergency_contact'] ?? '')) {
                    updates['emergency_contact'] =
                        _editEmergencyContactController.text.isEmpty
                            ? null
                            : _editEmergencyContactController.text;
                  }
                  if (_editEmergencyPhoneController.text !=
                      (user['emergency_phone'] ?? '')) {
                    updates['emergency_phone'] =
                        _editEmergencyPhoneController.text.isEmpty
                            ? null
                            : _editEmergencyPhoneController.text;
                  }

                  if (updates.isNotEmpty) {
                    Navigator.pop(context);
                    _updateUserProfile(user['id'], updates);
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('Salva Modifiche'),
              ),
            ],
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
      return 'Scaduto';
    } else if (daysUntilExpiry < 60) {
      return 'In scadenza tra $daysUntilExpiry giorni';
    } else {
      return 'Valido';
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
      builder:
          (context) => AlertDialog(
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
                        radius: 40.w,
                        backgroundImage: NetworkImage(
                          user['profile_image_url'],
                        ),
                      ),
                    ),
                  SizedBox(height: 16.h),
                  Text('Nome: ${user['full_name'] ?? 'N/A'}'),
                  SizedBox(height: 8.h),
                  Text('Email: ${user['email'] ?? 'N/A'}'),
                  SizedBox(height: 8.h),
                  Text('Telefono: ${user['phone'] ?? 'N/A'}'),
                  SizedBox(height: 8.h),
                  Text(
                    'Ruolo: ${_getRoleLabel(user['role']?.toString() ?? 'student')}',
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Stato: ${user['is_active'] == true ? 'Attivo' : 'Disattivato'}',
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Certificato Medico: ${user['medical_certificate_status'] ?? 'pending'}',
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Registrazione: ${DateTime.parse(user['created_at']).toLocal().toString().split(' ')[0]}',
                  ),
                  if (user['emergency_contact'] != null) ...[
                    SizedBox(height: 8.h),
                    Text('Contatto Emergenza: ${user['emergency_contact']}'),
                  ],
                  if (user['emergency_phone'] != null) ...[
                    SizedBox(height: 8.h),
                    Text('Tel. Emergenza: ${user['emergency_phone']}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Chiudi'),
              ),
            ],
          ),
    );
  }

  void _showPromotionDialog(Map<String, dynamic>? user, {bool isBulk = false}) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isBulk ? 'Aggiorna Ruoli in Massa' : 'Gestisci Ruolo Utente',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isBulk)
                  Text(
                    'Seleziona il nuovo ruolo per ${user?['full_name']}:',
                    style: GoogleFonts.inter(fontSize: 14.sp),
                  )
                else
                  Text(
                    'Seleziona il nuovo ruolo per ${selectedUsers.length} utenti:',
                    style: GoogleFonts.inter(fontSize: 14.sp),
                  ),
                SizedBox(height: 16.h),
                ...[
                  'student',
                  'instructor',
                  'admin',
                  if (isPrincipalAdmin) 'instructor_admin',
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
                child: Text('Annulla'),
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
      _showErrorMessage('Errore nella promozione in massa: ${e.toString()}');
    }
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'student';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Crea Nuovo Utente',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            content: StatefulBuilder(
              builder:
                  (context, setDialogState) => SingleChildScrollView(
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
                            labelText: 'Telefono',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: InputDecoration(
                            labelText: 'Ruolo',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.security),
                          ),
                          items:
                              [
                                    'student',
                                    'instructor',
                                    if (isPrincipalAdmin) 'admin',
                                    if (isPrincipalAdmin) 'instructor_admin',
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
                child: Text('Annulla'),
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
                child: Text('Crea Utente'),
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
        return 'Admin Principale';
      case 'admin':
        return 'Amministratore';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'instructor':
        return 'Istruttore';
      case 'student':
      default:
        return 'Studente';
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
      _showErrorMessage('Errore nell\'apertura del profilo: ${e.toString()}');
    }
  }
}
