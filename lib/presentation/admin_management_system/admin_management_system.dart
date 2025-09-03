import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';

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
  List<dynamic> pendingRegistrations = [];
  List<dynamic> activityLogs = [];
  List<dynamic> adminCommunications = [];
  List<dynamic> nonFiscalReceipts = [];
  String selectedTab = 'users';

  // Form controllers
  final TextEditingController _communicationTitleController =
      TextEditingController();
  final TextEditingController _communicationContentController =
      TextEditingController();
  final TextEditingController _communicationTargetController =
      TextEditingController();
  final TextEditingController _receiptDescriptionController =
      TextEditingController();
  final TextEditingController _receiptAmountController =
      TextEditingController();
  final TextEditingController _receiptNotesController = TextEditingController();
  final TextEditingController _editFullNameController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();
  final TextEditingController _editEmergencyContactController =
      TextEditingController();
  final TextEditingController _editEmergencyPhoneController =
      TextEditingController();

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
    _receiptDescriptionController.dispose();
    _receiptAmountController.dispose();
    _receiptNotesController.dispose();
    _editFullNameController.dispose();
    _editPhoneController.dispose();
    _editEmergencyContactController.dispose();
    _editEmergencyPhoneController.dispose();
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
      final profileResponse =
          await client
              .from('user_profiles')
              .select()
              .eq('id', user.id)
              .single();

      currentUser = profileResponse;

      // Check if principal admin or regular admin
      isPrincipalAdmin =
          user.email == 'lutadordeeliteravenna@gmail.com' ||
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

      // Load pending registrations with error handling
      try {
        final pendingResponse = await client
            .from('pending_registrations')
            .select()
            .eq('status', 'pending')
            .order('created_at', ascending: false);
        pendingRegistrations = pendingResponse ?? [];
      } catch (e) {
        print('Error loading pending registrations: $e');
        pendingRegistrations = [];
      }

      // Load activity logs with error handling
      try {
        final logsResponse = await client
            .from('admin_activity_log')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        activityLogs = logsResponse ?? [];
      } catch (e) {
        print('Error loading activity logs: $e');
        activityLogs = [];
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

      // Load non-fiscal receipts with error handling
      try {
        final receiptsResponse = await client
            .from('non_fiscal_receipts')
            .select()
            .order('created_at', ascending: false);
        nonFiscalReceipts = receiptsResponse ?? [];
      } catch (e) {
        print('Error loading receipts: $e');
        nonFiscalReceipts = [];
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
        'target_audience':
            _communicationTargetController.text.isEmpty
                ? 'all'
                : _communicationTargetController.text,
        'status': 'sent',
      });

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'COMMUNICATION_SENT',
        'description':
            'Comunicazione inviata: ${_communicationTitleController.text}',
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

  Future<void> _createNonFiscalReceipt() async {
    if (_receiptDescriptionController.text.isEmpty ||
        _receiptAmountController.text.isEmpty) {
      _showErrorMessage('Descrizione e importo sono obbligatori');
      return;
    }

    try {
      final client = SupabaseService.instance.client;
      final amount = double.parse(_receiptAmountController.text);

      final receiptNumber =
          'NF${DateTime.now().year}${DateTime.now().millisecondsSinceEpoch}';

      await client.from('non_fiscal_receipts').insert({
        'receipt_number': receiptNumber,
        'created_by': currentUser?['id'],
        'description': _receiptDescriptionController.text,
        'amount': amount,
        'notes': _receiptNotesController.text,
        'status': 'issued',
      });

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'RECEIPT_CREATED',
        'description': 'Ricevuta non fiscale creata: $receiptNumber',
      });

      _receiptDescriptionController.clear();
      _receiptAmountController.clear();
      _receiptNotesController.clear();

      _showSuccessMessage('Ricevuta non fiscale creata: $receiptNumber');
      await _loadSystemData();
    } catch (e) {
      print('Error creating receipt: $e');
      _showErrorMessage('Errore nella creazione ricevuta: ${e.toString()}');
    }
  }

  Future<void> _downloadReceipt(Map<String, dynamic> receipt) async {
    try {
      final content = _generateReceiptContent(receipt);
      final fileName = 'ricevuta_${receipt['receipt_number']}.txt';

      if (kIsWeb) {
        // Web download
        final bytes = utf8.encode(content);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute("download", fileName)
              ..click();
        html.Url.revokeObjectUrl(url);
        _showSuccessMessage('Ricevuta scaricata');
      } else {
        // Mobile download
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(content);
        _showSuccessMessage('Ricevuta salvata in: ${file.path}');
      }
    } catch (e) {
      print('Error downloading receipt: $e');
      _showErrorMessage('Errore nel download: ${e.toString()}');
    }
  }

  String _generateReceiptContent(Map<String, dynamic> receipt) {
    return '''
RICEVUTA NON FISCALE
====================

Numero Ricevuta: ${receipt['receipt_number']}
Data: ${DateTime.parse(receipt['created_at']).toLocal().toString().split(' ')[0]}

Descrizione: ${receipt['description']}
Importo: €${receipt['amount'].toStringAsFixed(2)}

${receipt['notes'] != null && receipt['notes'].toString().isNotEmpty ? 'Note: ${receipt['notes']}\n' : ''}

Emessa da: Team Ragnarok ASD
Data di emissione: ${DateTime.now().toLocal().toString()}

====================
Questa è una ricevuta non fiscale
    ''';
  }

  Future<void> _approvePendingRegistration(String registrationId) async {
    try {
      final client = SupabaseService.instance.client;

      await client
          .from('pending_registrations')
          .update({
            'status': 'approved',
            'reviewed_by': currentUser?['id'],
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', registrationId);

      _showSuccessMessage('Registrazione approvata');
      await _loadSystemData();
    } catch (e) {
      print('Error approving registration: $e');
      _showErrorMessage('Errore nell\'approvazione: ${e.toString()}');
    }
  }

  Future<void> _rejectPendingRegistration(String registrationId) async {
    try {
      final client = SupabaseService.instance.client;

      await client
          .from('pending_registrations')
          .update({
            'status': 'rejected',
            'reviewed_by': currentUser?['id'],
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', registrationId);

      _showSuccessMessage('Registrazione respinta');
      await _loadSystemData();
    } catch (e) {
      print('Error rejecting registration: $e');
      _showErrorMessage('Errore nel rifiuto: ${e.toString()}');
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
                                color:
                                    Theme.of(
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
                  // Tab navigation - horizontal scroll
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton('users', 'Utenti', Icons.people),
                        SizedBox(width: 8),
                        _buildTabButton(
                          'pending',
                          'Registrazioni',
                          Icons.pending_actions,
                        ),
                        SizedBox(width: 8),
                        _buildTabButton(
                          'communications',
                          'Comunicazioni',
                          Icons.campaign,
                        ),
                        SizedBox(width: 8),
                        _buildTabButton(
                          'receipts',
                          'Ricevute',
                          Icons.receipt_long,
                        ),
                        SizedBox(width: 8),
                        _buildTabButton('activity', 'Attività', Icons.history),
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
          // Navigate to dedicated screens instead of switching tabs
          if (tabId == 'users') {
            Navigator.pushNamed(context, AppRoutes.userManagementSystem);
            return;
          }
          if (tabId == 'pending') {
            Navigator.pushNamed(
              context,
              AppRoutes.registrationManagementSystem,
            );
            return;
          }

          // For other tabs, keep the existing behavior
          if (mounted) {
            setState(() => selectedTab = tabId);
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
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
                color:
                    isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.secondary,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  color:
                      isSelected
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
      case 'pending':
        return _buildPendingTab();
      case 'communications':
        return _buildCommunicationsTab();
      case 'receipts':
        return _buildReceiptsTab();
      case 'activity':
        return _buildActivityTab();
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
                        backgroundImage:
                            user['profile_image_url'] != null
                                ? NetworkImage(user['profile_image_url'])
                                : null,
                        child:
                            user['profile_image_url'] == null
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
                            user['full_name']?.toString() ??
                                'Nome non disponibile',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            user['email']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (user['phone'] != null)
                            Text(
                              'Tel: ${user['phone']}',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    Theme.of(
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

  Widget _buildPendingTab() {
    if (pendingRegistrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: AppTheme.textSecondaryLight),
            SizedBox(height: 16),
            Text(
              'Nessuna registrazione in attesa',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Registrazioni in Attesa',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 16),
        ...pendingRegistrations
            .map((registration) => _buildPendingCard(registration))
            .toList(),
      ],
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> registration) {
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
              Icon(Icons.person_add, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  registration['full_name']?.toString() ??
                      'Nome non disponibile',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Email: ${registration['email']?.toString() ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          if (registration['phone'] != null)
            Text(
              'Telefono: ${registration['phone']}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondaryLight,
              ),
            ),
          if (registration['message'] != null) ...[
            SizedBox(height: 8),
            Text(
              'Messaggio: ${registration['message']}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textPrimaryLight,
              ),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      () => _approvePendingRegistration(registration['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Approva',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      () => _rejectPendingRegistration(registration['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Rifiuta',
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildReceiptsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Gestione Ricevute Non Fiscali',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 16),

        // Receipt Form Card
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
                  Icon(
                    Icons.receipt_long,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Crea Nuova Ricevuta Non Fiscale',
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
                controller: _receiptDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Descrizione *',
                  hintText: 'Descrivi il servizio o prodotto',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _receiptAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Importo (€) *',
                  hintText: 'Es: 25.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _receiptNotesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note aggiuntive (opzionale)',
                  hintText: 'Eventuali note o specifiche...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createNonFiscalReceipt,
                  icon: Icon(Icons.add),
                  label: Text('Crea Ricevuta'),
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

        // Receipts History
        Text(
          'Ricevute Emesse',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 12),

        if (nonFiscalReceipts.isEmpty)
          Container(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: AppTheme.textSecondaryLight,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nessuna ricevuta emessa',
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
          ...nonFiscalReceipts
              .map((receipt) => _buildReceiptCard(receipt))
              .toList(),
      ],
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final amount = receipt['amount']?.toDouble() ?? 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        elevation: 2,
        child: InkWell(
          onTap: () => _downloadReceipt(receipt),
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'N° ${receipt['receipt_number']}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimaryLight,
                        ),
                      ),
                    ),
                    Text(
                      '€${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  receipt['description']?.toString() ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                if (receipt['notes'] != null &&
                    receipt['notes'].toString().isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    'Note: ${receipt['notes']}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondaryLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Data: ${DateTime.parse(receipt['created_at']).toLocal().toString().split(' ')[0]}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _downloadReceipt(receipt),
                      icon: Icon(Icons.download, size: 16),
                      label: Text('Scarica'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
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

  Widget _buildActivityTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'Log Attività Sistema',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppTheme.textPrimaryLight,
          ),
        ),
        SizedBox(height: 16),
        if (activityLogs.isEmpty)
          Center(
            child: Column(
              children: [
                SizedBox(height: 32),
                Icon(
                  Icons.history,
                  size: 48,
                  color: AppTheme.textSecondaryLight,
                ),
                SizedBox(height: 16),
                Text(
                  'Nessuna attività registrata',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          )
        else
          ...activityLogs.map((log) => _buildActivityCard(log)).toList(),
      ],
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> log) {
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
          Text(
            log['action_type']?.toString() ?? 'Azione non specificata',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          SizedBox(height: 4),
          Text(
            log['description']?.toString() ?? '',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Data: ${log['created_at']?.toString().split('T')[0] ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.textSecondaryLight,
            ),
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
    _editFullNameController.text = user['full_name']?.toString() ?? '';
    _editPhoneController.text = user['phone']?.toString() ?? '';
    _editEmergencyContactController.text =
        user['emergency_contact']?.toString() ?? '';
    _editEmergencyPhoneController.text =
        user['emergency_phone']?.toString() ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                  SizedBox(height: 12),
                  TextField(
                    controller: _editPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Telefono',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _editEmergencyContactController,
                    decoration: InputDecoration(
                      labelText: 'Contatto di Emergenza',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.contact_emergency),
                    ),
                  ),
                  SizedBox(height: 12),
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
                child: Text('Salva'),
              ),
            ],
          ),
    );
  }

  void _showPromotionDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
