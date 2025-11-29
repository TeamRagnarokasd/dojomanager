
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class AdminManagementSystem extends StatefulWidget {
  const AdminManagementSystem({super.key});

  @override
  State<AdminManagementSystem> createState() => _AdminManagementSystemState();
}

class _AdminManagementSystemState extends State<AdminManagementSystem> {
  bool isLoading = true;
  bool isPrincipalAdmin = false;
  Map<String, dynamic>? currentUser;
  List<dynamic> systemUsers = [];
  List<dynamic> adminCommunications = [];
  String selectedTab = 'users';

  // Form controllers
  final TextEditingController _communicationTitleController =
      TextEditingController();
  final TextEditingController _communicationContentController =
      TextEditingController();
  final TextEditingController _communicationTargetController =
      TextEditingController();
  final TextEditingController _editFullNameController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editEmergencyContactController =
      TextEditingController();
  final TextEditingController _editEmergencyPhoneController =
      TextEditingController();

  // Additional form controllers for expanded user profile editing
  final TextEditingController _editEmailController = TextEditingController();
  final TextEditingController _editAddressLineController =
      TextEditingController();
  final TextEditingController _editCityController = TextEditingController();
  final TextEditingController _editProvinceController = TextEditingController();
  final TextEditingController _editCapController = TextEditingController();
  final TextEditingController _editCodiceFiscaleController =
      TextEditingController();
  final TextEditingController _editParentGuardianNameController =
      TextEditingController();
  final TextEditingController _editParentGuardianSurnameController =
      TextEditingController();
  final TextEditingController _editParentGuardianEmailController =
      TextEditingController();
  final TextEditingController _editParentGuardianPhoneController =
      TextEditingController();
  final TextEditingController _editParentGuardianCodiceFiscaleController =
      TextEditingController();
  final TextEditingController _editParentGuardianRelationController =
      TextEditingController();

  DateTime? _selectedBirthDate;
  bool _isMinor = false;
  bool _isActive = true;
  String _selectedStatus = 'approved';
  String _selectedRole = 'student';
  String _selectedMedicalCertificateStatus = 'pending';

  Map<String, dynamic>? selectedUserForEdit;

  @override
  void initState() {
    super.initState();
    _initializeAdminSystem();
  }

  @override
  void dispose() {
    _communicationTitleController.dispose();
    _communicationContentController.dispose();
    _communicationTargetController.dispose();
    _editFullNameController.dispose();
    _editPhoneController.dispose();
    _editEmergencyContactController.dispose();
    _editEmergencyPhoneController.dispose();

    // Dispose additional controllers
    _editEmailController.dispose();
    _editAddressLineController.dispose();
    _editCityController.dispose();
    _editProvinceController.dispose();
    _editCapController.dispose();
    _editCodiceFiscaleController.dispose();
    _editParentGuardianNameController.dispose();
    _editParentGuardianSurnameController.dispose();
    _editParentGuardianEmailController.dispose();
    _editParentGuardianPhoneController.dispose();
    _editParentGuardianCodiceFiscaleController.dispose();
    _editParentGuardianRelationController.dispose();

    super.dispose();
  }

  Future<void> _initializeAdminSystem() async {
    try {
      await _checkAdminAccess();
      await _loadSystemData();
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

      // Check if principal admin or regular admin
      isPrincipalAdmin = user.email == 'lutadordeeliteravenna@gmail.com' ||
          (currentUser?['role'] == 'principal_admin');

      // Allow access for admin or principal_admin roles
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

  Future<void> _loadSystemData() async {
    final client = SupabaseService.instance.client;

    try {
      // Load system users with proper error handling
      try {
        final usersResponse = await client
            .from('user_profiles')
            .select()
            .order('created_at', ascending: false);
        systemUsers = usersResponse ?? [];
      } catch (e) {
        print('Error loading users: $e');
        systemUsers = [];
      }

      // Load admin communications with error handling
      try {
        final communicationsResponse = await client
            .from('admin_communications')
            .select()
            .order('created_at', ascending: false);
        adminCommunications = communicationsResponse ?? [];
      } catch (e) {
        print('Error loading communications: $e');
        adminCommunications = [];
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading system data: $e');
    }
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
      await _loadSystemData();
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
      await _loadSystemData();
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

  Future<void> _sendCommunication() async {
    if (_communicationTitleController.text.isEmpty ||
        _communicationContentController.text.isEmpty) {
      _showErrorMessage('Titolo e contenuto sono obbligatori');
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      await client.from('admin_communications').insert({
        'sender_id': currentUser?['id'],
        'title': _communicationTitleController.text,
        'content': _communicationContentController.text,
        'target_audience': _communicationTargetController.text.isEmpty
            ? 'all'
            : _communicationTargetController.text,
        'status': 'sent',
      });

      _communicationTitleController.clear();
      _communicationContentController.clear();
      _communicationTargetController.clear();

      _showSuccessMessage('Comunicazione inviata con successo');
      await _loadSystemData();
    } catch (e) {
      print('Error sending communication: $e');
      _showErrorMessage('Errore nell\'invio: ${e.toString()}');
    }
  }

  Future<void> _deleteUser(
    String userId,
    String userName,
    String userEmail,
  ) async {
    // Prevent deletion of principal admin
    if (userEmail == 'lutadordeeliteravenna@gmail.com') {
      _showErrorMessage('Impossibile eliminare l\'amministratore principale');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Conferma Eliminazione',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sei sicuro di voler eliminare l\'utente?',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Utente: $userName',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Email: $userEmail',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Attenzione:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• L\'utente verrà eliminato permanentemente\n• Le ricevute associate verranno preservate\n• Questa azione non può essere annullata',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.orange.shade800,
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
            child: Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = SupabaseService.instance.client;

      // Call the safe_delete_user function
      final result = await client.rpc(
        'safe_delete_user',
        params: {'target_user_id': userId},
      );

      if (result['success'] == true) {
        _showSuccessMessage(
          'Utente eliminato con successo (ricevute preservate)',
        );
        await _loadSystemData(); // Refresh the user list
      } else {
        _showErrorMessage(result['error'] ?? 'Errore durante l\'eliminazione');
      }
    } catch (e) {
      print('Error deleting user: $e');
      _showErrorMessage('Errore durante l\'eliminazione: ${e.toString()}');
    }
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          title: Text(
            'Gestione Sistema',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevation: 0,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          automaticallyImplyLeading: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gestione Sistema',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Team Ragnarok',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        automaticallyImplyLeading: true,
        actions: [
          // Admin role badge
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Navigation Section - Consistent with app design
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?['full_name'] ?? 'Admin Principale',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Gestione Sistema',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Tab navigation - horizontal scroll (removed Registrazioni, Ricevute, Attività)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton('users', 'Utenti', Icons.people),
                        SizedBox(width: 8),
                        _buildTabButton(
                          'communications',
                          'Comunicazioni',
                          Icons.campaign,
                        ),
                        SizedBox(width: 8),
                        if (isPrincipalAdmin)
                          _buildTabButton(
                            'settings',
                            'Impostazioni',
                            Icons.settings,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label, IconData icon) {
    final isSelected = selectedTab == tabId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (mounted) {
            setState(() => selectedTab = tabId);
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.secondary,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 'users':
        return _buildUsersTab();
      case 'communications':
        return _buildCommunicationsTab();
      case 'settings':
        return _buildSettingsTab();
      default:
        return _buildUsersTab();
    }
  }

  Widget _buildUsersTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Gestione Utenti Sistema',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            ElevatedButton.icon(
              onPressed: _loadSystemData,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Aggiorna'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        if (systemUsers.isEmpty)
          Center(
            child: Column(
              children: [
                SizedBox(height: 32),
                Icon(
                  Icons.people,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: 16),
                Text(
                  'Nessun utente trovato',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ...systemUsers.map((user) => _buildUserCard(user)).toList(),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'student';
    final isActive = user['is_active'] == true;
    final userEmail = user['email']?.toString() ?? '';
    final userName = user['full_name']?.toString() ?? 'Nome non disponibile';
    final userId = user['id']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.0),
        elevation: 2,
        shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.1),
        child: InkWell(
          onTap: () => _showUserEditDialog(user),
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _updateUserPhoto(user['id']),
                      child: CircleAvatar(
                        backgroundColor: _getRoleColor(
                          role,
                        ).withValues(alpha: 0.1),
                        backgroundImage: user['profile_image_url'] != null
                            ? NetworkImage(user['profile_image_url'])
                            : null,
                        child: user['profile_image_url'] == null
                            ? Icon(
                                _getRoleIcon(role),
                                color: _getRoleColor(role),
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (user['phone'] != null)
                            Text(
                              'Tel: ${user['phone']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        _getRoleLabel(role),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getRoleColor(role),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      isActive ? 'Attivo' : 'Disattivato',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showUserEditDialog(user),
                      icon: Icon(Icons.edit, size: 16),
                      label: Text('Modifica'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    // Add delete button right next to edit button for admin-level users
                    if (isPrincipalAdmin &&
                        userEmail != 'lutadordeeliteravenna@gmail.com')
                      TextButton.icon(
                        onPressed: () =>
                            _deleteUser(userId, userName, userEmail),
                        icon: Icon(Icons.delete, size: 16),
                        label: Text('Elimina'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    if (isPrincipalAdmin && role != 'principal_admin')
                      TextButton.icon(
                        onPressed: () => _showPromotionDialog(user),
                        icon: Icon(Icons.admin_panel_settings, size: 16),
                        label: Text('Ruolo'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunicationsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Comunicazioni Amministrative',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 16),

        // Communication Form Card
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Nuova Comunicazione Importante',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: _communicationTitleController,
                decoration: InputDecoration(
                  labelText: 'Titolo *',
                  hintText: 'Inserisci il titolo della comunicazione',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _communicationContentController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Contenuto *',
                  hintText:
                      'Scrivi il messaggio importante per tutti gli utenti...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: Icon(Icons.message),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _communicationTargetController,
                decoration: InputDecoration(
                  labelText: 'Destinatari (opzionale)',
                  hintText:
                      'Lascia vuoto per inviare a tutti, o specifica ruolo (es: instructor)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: Icon(Icons.people),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendCommunication,
                  icon: Icon(Icons.send),
                  label: Text('Invia Comunicazione'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24),

        // Communication History
        Text(
          'Storico Comunicazioni',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 12),

        if (adminCommunications.isEmpty)
          Container(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.campaign,
                    size: 48,
                    color: AppTheme.textSecondaryLight,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nessuna comunicazione inviata',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...adminCommunications
              .map((comm) => _buildCommunicationCard(comm))
              .toList(),
      ],
    );
  }

  Widget _buildCommunicationCard(Map<String, dynamic> communication) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  communication['title']?.toString() ?? 'Comunicazione',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  'Inviata',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            communication['content']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Destinatari: ${communication['target_audience'] ?? 'Tutti'}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
              const Spacer(),
              Text(
                'Data: ${DateTime.parse(communication['created_at']).toLocal().toString().split(' ')[0]}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Impostazioni Sistema',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 16),
        // Principal Admin Credentials Card
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Credenziali Admin Principale',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Email: lutadordeeliteravenna@gmail.com',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Password: Magnus833cc',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  '⚠️ Credenziali di sistema - Non condividere',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUserEditDialog(Map<String, dynamic> user) {
    selectedUserForEdit = user;

    // Populate all form fields with existing user data
    _editFullNameController.text = user['full_name']?.toString() ?? '';
    _editPhoneController.text = user['phone']?.toString() ?? '';
    _editEmergencyContactController.text =
        user['emergency_contact']?.toString() ?? '';
    _editEmergencyPhoneController.text =
        user['emergency_phone']?.toString() ?? '';
    _editEmailController.text = user['email']?.toString() ?? '';
    _editAddressLineController.text = user['address_line']?.toString() ?? '';
    _editCityController.text = user['city']?.toString() ?? '';
    _editProvinceController.text = user['province']?.toString() ?? '';
    _editCapController.text = user['cap']?.toString() ?? '';
    _editCodiceFiscaleController.text =
        user['codice_fiscale']?.toString() ?? '';
    _editParentGuardianNameController.text =
        user['parent_guardian_name']?.toString() ?? '';
    _editParentGuardianSurnameController.text =
        user['parent_guardian_surname']?.toString() ?? '';
    _editParentGuardianEmailController.text =
        user['parent_guardian_email']?.toString() ?? '';
    _editParentGuardianPhoneController.text =
        user['parent_guardian_phone']?.toString() ?? '';
    _editParentGuardianCodiceFiscaleController.text =
        user['parent_guardian_codice_fiscale']?.toString() ?? '';
    _editParentGuardianRelationController.text =
        user['parent_guardian_relation']?.toString() ?? '';

    // Set boolean and dropdown values with proper state management
    _isMinor = user['is_minor'] ?? false;
    _isActive = user['is_active'] ?? true;
    _selectedStatus = user['status']?.toString() ?? 'approved';
    _selectedRole = user['role']?.toString() ?? 'student';
    _selectedMedicalCertificateStatus =
        user['medical_certificate_status']?.toString() ?? 'pending';

    // Parse birth date
    _selectedBirthDate = user['birth_date'] != null
        ? DateTime.tryParse(user['birth_date'])
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Modifica Profilo Utente Completo',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Scrollable Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Info Section
                        _buildFormSection(
                          'Informazioni Personali',
                          Icons.person,
                          [
                            _buildTextField(
                              controller: _editFullNameController,
                              label: 'Nome Completo *',
                              icon: Icons.person,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editEmailController,
                              label: 'Email *',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editPhoneController,
                              label: 'Telefono',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editCodiceFiscaleController,
                              label: 'Codice Fiscale',
                              icon: Icons.credit_card,
                            ),
                            SizedBox(height: 16),
                            // Birth Date Picker
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedBirthDate ??
                                      DateTime.now().subtract(
                                        Duration(days: 365 * 20),
                                      ),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  dialogSetState(
                                    () => _selectedBirthDate = date,
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.grey.shade600,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      _selectedBirthDate != null
                                          ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
                                          : 'Data di Nascita',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _selectedBirthDate != null
                                            ? Colors.black87
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Address Section
                        _buildFormSection(
                          'Indirizzo',
                          Icons.location_on,
                          [
                            _buildTextField(
                              controller: _editAddressLineController,
                              label: 'Indirizzo',
                              icon: Icons.home,
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _editCityController,
                                    label: 'Città',
                                    icon: Icons.location_city,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _editProvinceController,
                                    label: 'Provincia',
                                    icon: Icons.map,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editCapController,
                              label: 'CAP',
                              icon: Icons.local_post_office,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Emergency Contact Section
                        _buildFormSection(
                          'Contatto di Emergenza',
                          Icons.emergency,
                          [
                            _buildTextField(
                              controller: _editEmergencyContactController,
                              label: 'Nome Contatto di Emergenza',
                              icon: Icons.contact_emergency,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editEmergencyPhoneController,
                              label: 'Telefono Emergenza',
                              icon: Icons.phone_in_talk,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Parent/Guardian Section (if minor)
                        _buildFormSection(
                          'Informazioni Genitore/Tutore',
                          Icons.family_restroom,
                          [
                            CheckboxListTile(
                              title: Text('Utente Minorenne'),
                              value: _isMinor,
                              onChanged: (value) {
                                dialogSetState(
                                  () => _isMinor = value ?? false,
                                );
                              },
                            ),
                            if (_isMinor) ...[
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller:
                                          _editParentGuardianNameController,
                                      label: 'Nome Genitore/Tutore',
                                      icon: Icons.person,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      controller:
                                          _editParentGuardianSurnameController,
                                      label: 'Cognome Genitore/Tutore',
                                      icon: Icons.person,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              _buildTextField(
                                controller: _editParentGuardianEmailController,
                                label: 'Email Genitore/Tutore',
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              SizedBox(height: 16),
                              _buildTextField(
                                controller: _editParentGuardianPhoneController,
                                label: 'Telefono Genitore/Tutore',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                              SizedBox(height: 16),
                              _buildTextField(
                                controller:
                                    _editParentGuardianCodiceFiscaleController,
                                label: 'Codice Fiscale Genitore/Tutore',
                                icon: Icons.credit_card,
                              ),
                              SizedBox(height: 16),
                              _buildTextField(
                                controller:
                                    _editParentGuardianRelationController,
                                label: 'Relazione (es. Padre, Madre, Tutore)',
                                icon: Icons.family_restroom,
                              ),
                            ],
                          ],
                        ),

                        SizedBox(height: 24),

                        // Status & Settings Section
                        _buildFormSection(
                          'Stato & Impostazioni',
                          Icons.settings,
                          [
                            Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  decoration: InputDecoration(
                                    labelText: 'Ruolo Utente',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.admin_panel_settings,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'student',
                                      child: Text('Studente'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'instructor',
                                      child: Text('Istruttore'),
                                    ),
                                    if (isPrincipalAdmin) ...[
                                      DropdownMenuItem(
                                        value: 'admin',
                                        child: Text('Amministratore'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'instructor_admin',
                                        child: Text('Istruttore Admin'),
                                      ),
                                    ],
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      dialogSetState(
                                        () => _selectedRole = value,
                                      );
                                    }
                                  },
                                ),
                                SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Stato Account',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.check_circle,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('In Attesa'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('Approvato'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text('Rifiutato'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'suspended',
                                      child: Text('Sospeso'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      dialogSetState(
                                        () => _selectedStatus = value,
                                      );
                                    }
                                  },
                                ),
                                SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedMedicalCertificateStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Stato Certificato Medico',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.medical_services,
                                    ),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('In Attesa'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('Approvato'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'expired',
                                      child: Text('Scaduto'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text('Rifiutato'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      dialogSetState(
                                        () =>
                                            _selectedMedicalCertificateStatus =
                                                value,
                                      );
                                    }
                                  },
                                ),
                                SizedBox(height: 16),
                                CheckboxListTile(
                                  title: Text('Account Attivo'),
                                  subtitle: Text(
                                    'L\'utente può accedere al sistema',
                                  ),
                                  value: _isActive,
                                  onChanged: (value) {
                                    dialogSetState(
                                      () => _isActive = value ?? true,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('Annulla'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveCompleteUserProfile(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('Salva Modifiche'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(icon),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }

  Future<void> _saveCompleteUserProfile(Map<String, dynamic> user) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final updates = <String, dynamic>{};

      // Basic Info Updates
      if (_editFullNameController.text != (user['full_name'] ?? '')) {
        updates['full_name'] = _editFullNameController.text.trim();
      }
      if (_editEmailController.text != (user['email'] ?? '')) {
        updates['email'] = _editEmailController.text.trim();
      }
      if (_editPhoneController.text != (user['phone'] ?? '')) {
        updates['phone'] = _editPhoneController.text.trim().isEmpty
            ? null
            : _editPhoneController.text.trim();
      }
      if (_editCodiceFiscaleController.text != (user['codice_fiscale'] ?? '')) {
        updates['codice_fiscale'] =
            _editCodiceFiscaleController.text.trim().isEmpty
                ? null
                : _editCodiceFiscaleController.text.trim();
      }

      // Birth Date
      if (_selectedBirthDate != null) {
        final currentBirthDate = user['birth_date'] != null
            ? DateTime.tryParse(user['birth_date'])
            : null;
        if (currentBirthDate == null ||
            !_selectedBirthDate!.isAtSameMomentAs(currentBirthDate)) {
          updates['birth_date'] =
              _selectedBirthDate!.toIso8601String().split('T')[0];
        }
      }

      // Address Updates
      if (_editAddressLineController.text != (user['address_line'] ?? '')) {
        updates['address_line'] = _editAddressLineController.text.trim().isEmpty
            ? null
            : _editAddressLineController.text.trim();
      }
      if (_editCityController.text != (user['city'] ?? '')) {
        updates['city'] = _editCityController.text.trim().isEmpty
            ? null
            : _editCityController.text.trim();
      }
      if (_editProvinceController.text != (user['province'] ?? '')) {
        updates['province'] = _editProvinceController.text.trim().isEmpty
            ? null
            : _editProvinceController.text.trim();
      }
      if (_editCapController.text != (user['cap'] ?? '')) {
        updates['cap'] = _editCapController.text.trim().isEmpty
            ? null
            : _editCapController.text.trim();
      }

      // Emergency Contact Updates
      if (_editEmergencyContactController.text !=
          (user['emergency_contact'] ?? '')) {
        updates['emergency_contact'] =
            _editEmergencyContactController.text.trim().isEmpty
                ? null
                : _editEmergencyContactController.text.trim();
      }
      if (_editEmergencyPhoneController.text !=
          (user['emergency_phone'] ?? '')) {
        updates['emergency_phone'] =
            _editEmergencyPhoneController.text.trim().isEmpty
                ? null
                : _editEmergencyPhoneController.text.trim();
      }

      // Minor status and Parent/Guardian Info
      if (_isMinor != (user['is_minor'] ?? false)) {
        updates['is_minor'] = _isMinor;
      }

      if (_isMinor) {
        if (_editParentGuardianNameController.text !=
            (user['parent_guardian_name'] ?? '')) {
          updates['parent_guardian_name'] =
              _editParentGuardianNameController.text.trim().isEmpty
                  ? null
                  : _editParentGuardianNameController.text.trim();
        }
        if (_editParentGuardianSurnameController.text !=
            (user['parent_guardian_surname'] ?? '')) {
          updates['parent_guardian_surname'] =
              _editParentGuardianSurnameController.text.trim().isEmpty
                  ? null
                  : _editParentGuardianSurnameController.text.trim();
        }
        if (_editParentGuardianEmailController.text !=
            (user['parent_guardian_email'] ?? '')) {
          updates['parent_guardian_email'] =
              _editParentGuardianEmailController.text.trim().isEmpty
                  ? null
                  : _editParentGuardianEmailController.text.trim();
        }
        if (_editParentGuardianPhoneController.text !=
            (user['parent_guardian_phone'] ?? '')) {
          updates['parent_guardian_phone'] =
              _editParentGuardianPhoneController.text.trim().isEmpty
                  ? null
                  : _editParentGuardianPhoneController.text.trim();
        }
        if (_editParentGuardianCodiceFiscaleController.text !=
            (user['parent_guardian_codice_fiscale'] ?? '')) {
          updates['parent_guardian_codice_fiscale'] =
              _editParentGuardianCodiceFiscaleController.text.trim().isEmpty
                  ? null
                  : _editParentGuardianCodiceFiscaleController.text.trim();
        }
        if (_editParentGuardianRelationController.text !=
            (user['parent_guardian_relation'] ?? '')) {
          updates['parent_guardian_relation'] =
              _editParentGuardianRelationController.text.trim().isEmpty
                  ? null
                  : _editParentGuardianRelationController.text.trim();
        }
      } else {
        // Clear parent/guardian fields if not minor
        updates['parent_guardian_name'] = null;
        updates['parent_guardian_surname'] = null;
        updates['parent_guardian_email'] = null;
        updates['parent_guardian_phone'] = null;
        updates['parent_guardian_codice_fiscale'] = null;
        updates['parent_guardian_relation'] = null;
      }

      // Status & Settings Updates
      if (_selectedRole != (user['role'] ?? 'student')) {
        updates['role'] = _selectedRole;
      }
      if (_selectedStatus != (user['status'] ?? 'approved')) {
        updates['status'] = _selectedStatus;
      }
      if (_selectedMedicalCertificateStatus !=
          (user['medical_certificate_status'] ?? 'pending')) {
        updates['medical_certificate_status'] =
            _selectedMedicalCertificateStatus;
      }
      if (_isActive != (user['is_active'] ?? true)) {
        updates['is_active'] = _isActive;
      }

      // Close loading dialog
      Navigator.pop(context);

      if (updates.isNotEmpty) {
        // Close edit dialog
        Navigator.pop(context);

        // Apply updates
        await _updateUserProfile(user['id'], updates);
      } else {
        // No changes made
        Navigator.pop(context);
        _showSuccessMessage('Nessuna modifica da salvare');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('Error saving complete user profile: $e');
      _showErrorMessage('Errore nel salvataggio: ${e.toString()}');
    }
  }

  void _showPromotionDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Gestisci Ruolo Utente',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Seleziona il nuovo ruolo per ${user['full_name']}:',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            SizedBox(height: 16),
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
                  _promoteUser(user['id'], role);
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
