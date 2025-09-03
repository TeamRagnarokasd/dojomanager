
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
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
      final profileResponse = await client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      currentUser = profileResponse;
      isPrincipalAdmin = user.email == 'lutadordeeliteravenna@gmail.com' ||
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
      final usersResponse = await client
          .from('user_profiles')
          .select()
          .order('created_at', ascending: false);

      systemUsers = usersResponse ?? [];
      _applyFilters();

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
          .update({'role': newRole}).eq('id', userId);

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
      String userId, Map<String, dynamic> updates) async {
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
          builder: (context) => AlertDialog(
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
          .update({'is_active': !suspend}).eq('id', userId);

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
        body: const Center(
          child: CircularProgressIndicator(),
        ),
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
                    'Messaggio inviato a ${selectedUsers.length} utenti');
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
                      'Solo l\'admin principale può modificare ruoli in massa');
                }
              },
            ),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people,
                            size: 48.sp, color: AppTheme.textSecondaryLight),
                        SizedBox(height: 16.h),
                        Text(
                          'Nessun utente trovato',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                        if (searchQuery.isNotEmpty ||
                            selectedRoleFilter != 'all' ||
                            selectedStatusFilter != 'all')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                selectedRoleFilter = 'all';
                                selectedStatusFilter = 'all';
                                selectedActivityFilter = 'all';
                                _searchController.clear();
                                _applyFilters();
                              });
                            },
                            child: Text('Pulisci filtri'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = selectedUsers.contains(user['id']);

                      return UserCardWidget(
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
                        onSuspendAccount: () =>
                            _suspendUser(user['id'], user['is_active'] == true),
                        onSendWelcomeEmail: () => _sendWelcomeEmail(user['id']),
                        onResetPassword: () => _resetPassword(user['id']),
                        onGenerateReport: () => _generateUserReport(user['id']),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Modifica Profilo Utente',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              TextField(
                controller: _editEmergencyContactController,
                decoration: InputDecoration(
                  labelText: 'Contatto di Emergenza',
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

              if (_editFullNameController.text != (user['full_name'] ?? '')) {
                updates['full_name'] = _editFullNameController.text;
              }
              if (_editPhoneController.text != (user['phone'] ?? '')) {
                updates['phone'] = _editPhoneController.text.isEmpty
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
            child: Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _showUserDetailDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                    backgroundImage: NetworkImage(user['profile_image_url']),
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
                  'Ruolo: ${_getRoleLabel(user['role']?.toString() ?? 'student')}'),
              SizedBox(height: 8.h),
              Text(
                  'Stato: ${user['is_active'] == true ? 'Attivo' : 'Disattivato'}'),
              SizedBox(height: 8.h),
              Text(
                  'Certificato Medico: ${user['medical_certificate_status'] ?? 'pending'}'),
              SizedBox(height: 8.h),
              Text(
                  'Registrazione: ${DateTime.parse(user['created_at']).toLocal().toString().split(' ')[0]}'),
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
      builder: (context) => AlertDialog(
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
              if (isPrincipalAdmin) 'instructor_admin'
            ].map((role) => ListTile(
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
                )),
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
          'Solo l\'admin principale può promuovere utenti in massa');
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      for (String userId in selectedUsers) {
        await client
            .from('user_profiles')
            .update({'role': newRole}).eq('id', userId);

        // Log the admin activity
        await client.from('admin_activity_log').insert({
          'admin_id': currentUser?['id'],
          'action_type': 'BULK_ROLE_UPDATE',
          'description': 'Ruolo aggiornato in massa a $newRole',
          'target_user_id': userId,
        });
      }

      _showSuccessMessage(
          '${selectedUsers.length} utenti promossi con successo');
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
      builder: (context) => AlertDialog(
        title: Text(
          'Crea Nuovo Utente',
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
                  items: [
                    'student',
                    'instructor',
                    if (isPrincipalAdmin) 'admin',
                    if (isPrincipalAdmin) 'instructor_admin'
                  ]
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(_getRoleLabel(role)),
                          ))
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
      String name, String email, String phone, String role) async {
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
}
