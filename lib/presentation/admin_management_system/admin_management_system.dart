import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/italian_receipt_service.dart';
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
  String _selectedRoleTitle = 'profile.default_student_role'
      .tr(); // NEW: Role title state

  Map<String, dynamic>? selectedUserForEdit;

  // Team data controllers
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _teamAddressController = TextEditingController();
  final TextEditingController _teamTaxCodeController = TextEditingController();
  final TextEditingController _teamPhoneController = TextEditingController();
  final TextEditingController _teamEmailController = TextEditingController();
  final TextEditingController _teamPecController = TextEditingController();
  bool _isLoadingTeamData = false;
  bool _isSavingTeamData = false;
  Map<String, dynamic>? _teamOrgInfo;

  // --- Search & filter state for "Gestione Utenti Sistema" ---
  final TextEditingController _userSearchController = TextEditingController();
  String _userSearchText = '';
  final Set<String> _activeFilterChips = {};

  static const String _chipUnder14 = 'under14';
  static const String _chip1417 = '14_17';
  static const String _chipNoCert = 'no_cert';
  static const String _chipPending = 'pending';
  static const String _chipNoSub = 'no_sub';

  Set<String> _subscribedTaxCodes = {};

  // Compute age in years from a birth_date string (ISO-8601 or similar)
  int? _ageFromBirthDate(dynamic birthDate) {
    if (birthDate == null) return null;
    try {
      final dob = DateTime.parse(birthDate.toString());
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month ||
          (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  bool _userMatchesChips(Map<String, dynamic> user) {
    if (_activeFilterChips.isEmpty) return true;

    final children =
        (user['child_profiles'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    for (final chip in _activeFilterChips) {
      bool chipMatch = false;

      if (chip == _chipUnder14) {
        final userAge = _ageFromBirthDate(user['birth_date']);
        if (userAge != null && userAge < 14) {
          chipMatch = true;
        } else {
          chipMatch = children.any((c) {
            final a = _ageFromBirthDate(c['birth_date']);
            return a != null && a < 14;
          });
        }
      } else if (chip == _chip1417) {
        final userAge = _ageFromBirthDate(user['birth_date']);
        if (userAge != null && userAge >= 14 && userAge <= 17) {
          chipMatch = true;
        } else {
          chipMatch = children.any((c) {
            final a = _ageFromBirthDate(c['birth_date']);
            return a != null && a >= 14 && a <= 17;
          });
        }
      } else if (chip == _chipNoCert) {
        final certUrl = user['medical_certificate_url']?.toString() ?? '';
        final expiryStr = user['medical_certificate_expiry']?.toString() ?? '';
        bool certMissing = certUrl.isEmpty;
        bool certExpired = false;
        if (!certMissing && expiryStr.isNotEmpty) {
          try {
            final expiry = DateTime.parse(expiryStr);
            certExpired = expiry.isBefore(DateTime.now());
          } catch (_) {}
        }
        chipMatch = certMissing || certExpired;
      } else if (chip == _chipPending) {
        chipMatch = (user['status']?.toString() ?? '') == 'pending';
      } else if (chip == _chipNoSub) {
        final taxCode =
            (user['codice_fiscale']?.toString() ??
                    user['tax_code']?.toString() ??
                    '')
                .trim()
                .toUpperCase();
        chipMatch = taxCode.isEmpty || !_subscribedTaxCodes.contains(taxCode);
      }

      if (!chipMatch) return false; // AND logic
    }
    return true;
  }

  bool _userMatchesSearch(Map<String, dynamic> user) {
    if (_userSearchText.isEmpty) return true;
    final q = _userSearchText.toLowerCase();
    final name = (user['full_name']?.toString() ?? '').toLowerCase();
    final email = (user['email']?.toString() ?? '').toLowerCase();
    final phone = (user['phone']?.toString() ?? '').toLowerCase();
    return name.contains(q) || email.contains(q) || phone.contains(q);
  }

  List<dynamic> get _filteredUsers {
    return systemUsers.where((u) {
      final user = u as Map<String, dynamic>;
      return _userMatchesSearch(user) && _userMatchesChips(user);
    }).toList();
  }
  // --- end search & filter state ---

  @override
  void initState() {
    super.initState();
    _initializeAdminSystem();
    _userSearchController.addListener(() {
      setState(() => _userSearchText = _userSearchController.text);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['initialTab'] != null) {
      final tab = args['initialTab'] as String;
      if (selectedTab != tab) {
        setState(() => selectedTab = tab);
      }
    }
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

    _teamNameController.dispose();
    _teamAddressController.dispose();
    _teamTaxCodeController.dispose();
    _teamPhoneController.dispose();
    _teamEmailController.dispose();
    _teamPecController.dispose();

    _userSearchController.dispose();

    super.dispose();
  }

  Future<void> _initializeAdminSystem() async {
    try {
      await _checkAdminAccess();
      await _loadSystemData();
    } catch (e) {
      _showErrorMessage(
        'admin_management.access_error'.tr(namedArgs: {'error': e.toString()}),
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
      throw Exception('admin_management.admin_permission_error'.tr());
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

        final rawUsers = List<Map<String, dynamic>>.from(usersResponse ?? []);

        // Fetch child profiles for each user
        final enrichedUsers = await Future.wait(
          rawUsers.map((user) async {
            try {
              final childrenResponse = await client
                  .from('child_profiles')
                  .select(
                    'id, first_name, last_name, birth_date, image_consent, is_active, tax_code, codice_fiscale, profile_photo_url, medical_certificate_url, medical_certificate_pending, medical_certificate_uploaded_at',
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
      } catch (e) {
        print('Error loading users: $e');
        systemUsers = [];
      }

      // Load subscribed tax codes (non-annual active subscriptions)
      try {
        final now = DateTime.now();
        DateTime mostRecentAug28;
        if (now.month > 8 || (now.month == 8 && now.day >= 28)) {
          mostRecentAug28 = DateTime(now.year, 8, 28);
        } else {
          mostRecentAug28 = DateTime(now.year - 1, 8, 28);
        }
        final aug28Str =
            '${mostRecentAug28.year}-${mostRecentAug28.month.toString().padLeft(2, '0')}-28';

        final receiptsResponse = await client
            .from('non_fiscal_receipts')
            .select('customer_tax_code')
            .not('description', 'ilike', '%Iscrizione Annuale%')
            .eq('deleted_by_user', false)
            .gte('issue_date', aug28Str);

        final codes = <String>{};
        for (final row in (receiptsResponse as List)) {
          final code = (row['customer_tax_code']?.toString() ?? '')
              .trim()
              .toUpperCase();
          if (code.isNotEmpty) codes.add(code);
        }
        _subscribedTaxCodes = codes;
      } catch (e) {
        print('Error loading subscribed tax codes: $e');
        _subscribedTaxCodes = {};
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
      _showErrorMessage(
        'admin_management.promote_error'.tr(namedArgs: {'error': e.toString()}),
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
      await _loadSystemData();
    } catch (e) {
      print('Error updating user profile: $e');
      _showErrorMessage(
        'admin_management.update_error'.tr(namedArgs: {'error': e.toString()}),
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
            title: Text('admin_management.image_source_title'.tr()),
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
        'admin_management.photo_update_error'.tr(
          namedArgs: {'error': e.toString()},
        ),
      );
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
      _showErrorMessage(
        'admin_management.send_error'.tr(namedArgs: {'error': e.toString()}),
      );
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

    // Show confirmation dialog with receipt choice
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'admin_management.confirm_deletion'.tr(),
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
            Text('Email: $userEmail', style: GoogleFonts.inter(fontSize: 14)),
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
                    '⚠️ Cosa vuoi fare con le ricevute associate?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Scegli se conservare o eliminare le ricevute collegate a questo utente.',
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
            onPressed: () => Navigator.pop(context, null),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep_receipts'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
            ),
            child: Text(
              'Elimina utente\n(conserva ricevute)',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'delete_receipts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Elimina tutto\n(utente + ricevute)',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      final client = SupabaseService.instance.client;

      if (choice == 'delete_receipts') {
        // Call function that also deletes receipts
        final rawResult = await client.rpc(
          'safe_delete_user_with_receipts',
          params: {'target_user_id': userId},
        );
        // RPC may return a Map or a List wrapping a Map
        final result = rawResult is List ? rawResult.first : rawResult;
        if (result is Map && result['success'] == true) {
          final int receiptsCount =
              (result['receipts_count'] as num?)?.toInt() ?? 0;
          final String msg = receiptsCount == 0
              ? 'Utente eliminato con successo. Nessuna ricevuta associata trovata.'
              : 'Utente e $receiptsCount ricevuta/e associate eliminati con successo.';
          _showSuccessMessage(msg);
          await _loadSystemData();
        } else {
          _showErrorMessage(
            (result is Map ? result['error']?.toString() : null) ??
                'admin_management.delete_error'.tr(namedArgs: {'error': ''}),
          );
        }
      } else {
        // Call the safe_delete_user function (preserves receipts)
        final result = await client.rpc(
          'safe_delete_user',
          params: {'target_user_id': userId},
        );
        if (result['success'] == true) {
          _showSuccessMessage(
            'Utente eliminato con successo (ricevute preservate)',
          );
          await _loadSystemData();
        } else {
          _showErrorMessage(
            result['error']?.toString() ??
                'admin_management.delete_error'.tr(namedArgs: {'error': ''}),
          );
        }
      }
    } catch (e) {
      print('Error deleting user: $e');
      _showErrorMessage(
        'admin_management.delete_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  Future<void> _acceptUser(String userId, String userName) async {
    try {
      final client = SupabaseService.instance.client;

      // CRITICAL FIX: Direct update with 'approved' status (ENUM compliant)
      await client
          .from('user_profiles')
          .update({'status': 'approved'}) // CRITICAL: Must use 'approved'
          .eq('id', userId);

      // Force UI refresh
      if (mounted) {
        setState(() {});
      }

      _showSuccessMessage('Utente $userName approvato con successo!');
      await _loadSystemData(); // Refresh the user list
    } catch (e) {
      print('Error approving user: $e');
      _showErrorMessage('Errore: ${e.toString()}');
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
            'admin_management.title'.tr(),
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
              'admin_management.title'.tr(),
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
                              'admin_management.title'.tr(),
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
    final filtered = _filteredUsers;
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'admin_management.user_management_title'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _loadSystemData,
              icon: Icon(Icons.refresh, size: 18),
              label: Text('admin_management.add_short'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        // Search field
        TextField(
          controller: _userSearchController,
          decoration: InputDecoration(
            hintText: 'Cerca per nome, email o telefono…',
            prefixIcon: Icon(Icons.search, size: 20),
            suffixIcon: _userSearchText.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _userSearchController.clear();
                    },
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          style: TextStyle(fontSize: 14),
        ),
        SizedBox(height: 10),
        // Filter chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildFilterChip('Under 14', _chipUnder14),
            _buildFilterChip('14-17 anni', _chip1417),
            _buildFilterChip('Senza certificato medico', _chipNoCert),
            _buildFilterChip('In attesa di approvazione', _chipPending),
            _buildFilterChip('Senza abbonamento', _chipNoSub),
          ],
        ),
        SizedBox(height: 10),
        // Results counter
        if (_userSearchText.isNotEmpty || _activeFilterChips.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '${filtered.length} risultat${filtered.length == 1 ? 'o' : 'i'}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
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
                  'reminders.no_users_found'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Nessun utente corrisponde ai criteri di ricerca.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...filtered.map((user) => _buildUserCard(user)).toList(),
      ],
    );
  }

  Widget _buildFilterChip(String label, String chipKey) {
    final isSelected = _activeFilterChips.contains(chipKey);
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          if (isSelected) {
            _activeFilterChips.remove(chipKey);
          } else {
            _activeFilterChips.add(chipKey);
          }
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withAlpha(64),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        width: isSelected ? 1.5 : 1.0,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'student';
    final isActive = user['is_active'] == true;
    final userStatus = user['status']?.toString() ?? 'pending';
    final userEmail = user['email']?.toString() ?? '';
    final userName = user['full_name']?.toString() ?? 'Nome non disponibile';
    final userId = user['id']?.toString() ?? '';
    final roleTitle =
        user['role_title']?.toString() ?? 'profile.default_student_role'.tr();

    final needsAcceptance = userStatus != 'approved';

    final childProfiles =
        (user['child_profiles'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: childProfiles.isEmpty ? 12 : 4),
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12.0),
            elevation: 2,
            shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.1),
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
                            Row(
                              children: [
                                Icon(
                                  Icons.badge,
                                  size: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Ruolo: $roleTitle',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                  // Action row — use Wrap to avoid overflow
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            color: isActive ? Colors.green : Colors.red,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isActive
                                ? 'admin_management.active_status'.tr()
                                : 'admin_management.deactivated_status'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.userProfile,
                            arguments: user,
                          );
                        },
                        icon: Icon(Icons.person, size: 16),
                        label: Text('admin_management.personal_card'.tr()),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (needsAcceptance)
                        IconButton(
                          onPressed: () => _acceptUser(userId, userName),
                          icon: Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'admin_management.accept_user_tooltip'.tr(),
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      if (isPrincipalAdmin || currentUser?['role'] == 'admin')
                        IconButton(
                          onPressed: () => _showRoleModificationDialog(user),
                          icon: Icon(Icons.edit, color: Colors.blue),
                          tooltip: 'admin_management.edit_role_tooltip'.tr(),
                          iconSize: 20,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      if (isPrincipalAdmin &&
                          userEmail != 'lutadordeeliteravenna@gmail.com')
                        TextButton.icon(
                          onPressed: () =>
                              _deleteUser(userId, userName, userEmail),
                          icon: Icon(Icons.delete, size: 16),
                          label: Text('common.delete'.tr()),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: Size.zero,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (isPrincipalAdmin && role != 'principal_admin')
                        TextButton.icon(
                          onPressed: () => _showPromotionDialog(user),
                          icon: Icon(Icons.admin_panel_settings, size: 16),
                          label: Text('profile.role'.tr()),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                            minimumSize: Size.zero,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Child profiles inline under parent ──────────────────────
        if (childProfiles.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 16, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: childProfiles.map((child) {
                final firstName = child['first_name'] as String? ?? '';
                final lastName = child['last_name'] as String? ?? '';
                final childName = '$firstName $lastName'.trim();
                final imageConsent = child['image_consent'] as bool? ?? false;
                final birthDate = child['birth_date'] as String?;
                String? age;
                if (birthDate != null) {
                  try {
                    final bd = DateTime.parse(birthDate);
                    final now = DateTime.now();
                    int a = now.year - bd.year;
                    if (now.month < bd.month ||
                        (now.month == bd.month && now.day < bd.day))
                      a--;
                    age = '$a anni';
                  } catch (_) {}
                }
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.adminChildProfile,
                      arguments: {'child': child, 'parent': user},
                    ).then((_) => _loadSystemData()),
                    borderRadius: BorderRadius.circular(10.0),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: imageConsent
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.orange.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left accent bar
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: imageConsent
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                          ),
                          SizedBox(width: 10),
                          _ChildPhotoAvatar(
                            storagePath: child['profile_photo_url'] as String?,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        childName.isEmpty
                                            ? 'Minore'
                                            : childName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          6.0,
                                        ),
                                      ),
                                      child: Text(
                                        'Minore',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: Colors.blue[300],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (age != null) ...[
                                      Icon(
                                        Icons.cake,
                                        size: 11,
                                        color: Colors.grey[500],
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        age,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                    ],
                                    Icon(
                                      imageConsent
                                          ? Icons.photo_camera
                                          : Icons.no_photography_outlined,
                                      size: 11,
                                      color: imageConsent
                                          ? Colors.green[400]
                                          : Colors.orange[400],
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      imageConsent
                                          ? 'Liberatoria OK'
                                          : 'No liberatoria',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
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
                          // Delete button (same logic as adults)
                          if (isPrincipalAdmin)
                            GestureDetector(
                              onTap: () => _deleteChildProfile(child, user),
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red[400],
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // 🎯 Show edit dialog for a child/minor profile
  void _showEditChildDialog(
    Map<String, dynamic> child,
    Map<String, dynamic> parentUser,
  ) {
    final childId = child['id']?.toString() ?? '';
    final firstNameCtrl = TextEditingController(
      text: child['first_name']?.toString() ?? '',
    );
    final lastNameCtrl = TextEditingController(
      text: child['last_name']?.toString() ?? '',
    );
    final taxCodeCtrl = TextEditingController(
      text: (child['tax_code'] ?? child['codice_fiscale'])?.toString() ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: child['phone']?.toString() ?? '',
    );
    final cityCtrl = TextEditingController(
      text: child['city']?.toString() ?? '',
    );
    final emergencyNameCtrl = TextEditingController(
      text: child['emergency_contact_name']?.toString() ?? '',
    );
    final emergencyPhoneCtrl = TextEditingController(
      text: child['emergency_contact_phone']?.toString() ?? '',
    );
    final medicalNotesCtrl = TextEditingController(
      text: child['medical_notes']?.toString() ?? '',
    );
    bool imageConsent = child['image_consent'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.child_care, color: Colors.blue[300]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modifica Profilo Minore',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genitore: ${parentUser['full_name'] ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cognome',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: taxCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Codice Fiscale',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefono',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: cityCtrl,
                  decoration: InputDecoration(
                    labelText: 'Città',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emergencyNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Contatto emergenza (nome)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.emergency),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emergencyPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Contatto emergenza (tel)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.phone_in_talk),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: medicalNotesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Note mediche',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.medical_services),
                  ),
                ),
                SizedBox(height: 12),
                // Image consent toggle
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: imageConsent
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: imageConsent
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        imageConsent
                            ? Icons.photo_camera
                            : Icons.no_photography_outlined,
                        color: imageConsent ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Liberatoria immagini',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: imageConsent,
                        activeThumbColor: Colors.green,
                        onChanged: (val) =>
                            dialogSetState(() => imageConsent = val),
                      ),
                    ],
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
              onPressed: () async {
                Navigator.pop(context);
                await _saveChildProfileChanges(
                  childId: childId,
                  firstName: firstNameCtrl.text,
                  lastName: lastNameCtrl.text,
                  taxCode: taxCodeCtrl.text,
                  phone: phoneCtrl.text,
                  city: cityCtrl.text,
                  emergencyContactName: emergencyNameCtrl.text,
                  emergencyContactPhone: emergencyPhoneCtrl.text,
                  medicalNotes: medicalNotesCtrl.text,
                  imageConsent: imageConsent,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChildProfileChanges({
    required String childId,
    required String firstName,
    required String lastName,
    required String taxCode,
    required String phone,
    required String city,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String medicalNotes,
    required bool imageConsent,
  }) async {
    try {
      final client = SupabaseService.instance.client;
      final data = <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'image_consent': imageConsent,
      };
      if (taxCode.trim().isNotEmpty) {
        data['tax_code'] = taxCode.trim().toUpperCase();
        data['codice_fiscale'] = taxCode.trim().toUpperCase();
      }
      if (phone.trim().isNotEmpty) data['phone'] = phone.trim();
      if (city.trim().isNotEmpty) data['city'] = city.trim();
      if (emergencyContactName.trim().isNotEmpty)
        data['emergency_contact_name'] = emergencyContactName.trim();
      if (emergencyContactPhone.trim().isNotEmpty)
        data['emergency_contact_phone'] = emergencyContactPhone.trim();
      if (medicalNotes.trim().isNotEmpty)
        data['medical_notes'] = medicalNotes.trim();

      await client.from('child_profiles').update(data).eq('id', childId);
      _showSuccessMessage('Profilo minore aggiornato con successo');
      await _loadSystemData();
    } catch (e) {
      _showErrorMessage('Errore aggiornamento profilo minore: $e');
    }
  }

  // 🎯 Delete a child/minor profile with confirmation dialog
  Future<void> _deleteChildProfile(
    Map<String, dynamic> child,
    Map<String, dynamic> parentUser,
  ) async {
    final childId = child['id']?.toString() ?? '';
    final firstName = child['first_name']?.toString() ?? '';
    final lastName = child['last_name']?.toString() ?? '';
    final childName = '$firstName $lastName'.trim();
    final displayName = childName.isEmpty ? 'Minore' : childName;
    final parentName = parentUser['full_name']?.toString() ?? 'Genitore';

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Elimina Profilo Minore',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sei sicuro di voler eliminare questo profilo minore?',
              style: GoogleFonts.inter(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Minore: $displayName',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Genitore/Tutore: $parentName',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'ℹ️ Le ricevute non verranno eliminate: sono intestate al genitore, non al minore.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Elimina Profilo',
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = SupabaseService.instance.client;
      // Delete only the child profile record — receipts belong to the parent
      await client.from('child_profiles').delete().eq('id', childId);
      _showSuccessMessage('Profilo minore eliminato con successo.');
      await _loadSystemData();
    } catch (e) {
      debugPrint('Error deleting child profile: $e');
      _showErrorMessage('Errore eliminazione profilo minore: ${e.toString()}');
    }
  }

  // 🎯 NEW: Show role modification dialog with dropdown
  void _showRoleModificationDialog(Map<String, dynamic> user) {
    final currentRoleTitle =
        user['role_title']?.toString() ?? 'profile.default_student_role'.tr();
    String selectedRoleTitle = currentRoleTitle;
    String selectedSystemRole = user['role']?.toString() ?? 'student';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.badge, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin_management.edit_user_role_title'.tr(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'admin_management.edit_role_for'.tr(
                    namedArgs: {'name': '${user['full_name']}'},
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ℹ️ Stato attuale:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Titolo: $currentRoleTitle',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ruolo sistema: ${_getRoleLabel(user['role']?.toString() ?? 'student')}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // ── SEZIONE 1: Ruolo di sistema ──
                Text(
                  'Ruolo di sistema (badge a destra)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedSystemRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.admin_panel_settings),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(value: 'student', child: Text('Studente')),
                    DropdownMenuItem(
                      value: 'instructor',
                      child: Text('Istruttore'),
                    ),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(
                      value: 'instructor_admin',
                      child: Text('Istruttore Admin'),
                    ),
                    DropdownMenuItem(
                      value: 'instructor_student',
                      child: Text('Istruttore Allievo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      dialogSetState(() {
                        selectedSystemRole = value;
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                // ── SEZIONE 2: Titolo visibile ──
                Text(
                  'admin_management.select_new_role_label'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRoleTitle,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.badge),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  items:
                      [
                        'profile.default_student_role'.tr(),
                        'Pro',
                        'Istruttore Fitness',
                        'Coach',
                        'Staff',
                        'Headcoach',
                        'Presidente',
                      ].map((roleOption) {
                        return DropdownMenuItem<String>(
                          value: roleOption,
                          child: Text(
                            roleOption,
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      dialogSetState(() {
                        selectedRoleTitle = value;
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '⚠️ Questa modifica aggiornerà sia il ruolo di sistema che il titolo visibile nel profilo utente.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUserRoleTitle(
                  user['id'],
                  selectedRoleTitle,
                  user['full_name'],
                  systemRole: selectedSystemRole,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 NEW: Update user role_title in database
  Future<void> _updateUserRoleTitle(
    String userId,
    String newRoleTitle,
    String userName, {
    String? systemRole,
  }) async {
    // Security check: only admins can modify roles
    if (!isPrincipalAdmin && currentUser?['role'] != 'admin') {
      _showErrorMessage('Solo gli amministratori possono modificare i ruoli');
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      // Build update map
      final Map<String, dynamic> updates = {'role_title': newRoleTitle};
      if (systemRole != null) {
        updates['role'] = systemRole;
      }

      // Update role_title (and optionally role) in user_profiles
      await client.from('user_profiles').update(updates).eq('id', userId);

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'ROLE_TITLE_UPDATE',
        'description': systemRole != null
            ? 'Ruolo sistema aggiornato a: $systemRole — Titolo: $newRoleTitle'
            : 'Ruolo utente aggiornato a: $newRoleTitle',
        'target_user_id': userId,
      });

      _showSuccessMessage('Ruolo di $userName aggiornato con successo');
      await _loadSystemData(); // Refresh the user list
    } catch (e) {
      print('Error updating user role_title: $e');
      _showErrorMessage(
        'admin_management.role_update_error'.tr(
          namedArgs: {'error': e.toString()},
        ),
      );
    }
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
                  labelText: 'admin_management.comm_title_label'.tr(),
                  hintText: 'admin_management.comm_title_hint'.tr(),
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
                  labelText: 'admin_management.comm_content_label'.tr(),
                  hintText: 'admin_management.comm_content_hint'.tr(),
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
                  label: Text('admin_management.send_communication'.tr()),
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
                    'common.no_communications'.tr(),
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
                'Destinatari: ${communication['target_audience'] ?? 'disciplines.all'.tr()}',
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

        // ── TEAM DATA CARD ──────────────────────────────────────────────
        _buildTeamDataCard(),
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

  Widget _buildTeamDataCard() {
    return Container(
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
              Icon(Icons.business, color: Colors.red.shade700, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dati Team / ASD',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
              ),
              if (_teamOrgInfo == null && !_isLoadingTeamData)
                TextButton.icon(
                  onPressed: _loadTeamData,
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Modifica'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Modifica i dati del team che appaiono nelle ricevute non fiscali.',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
          ),
          SizedBox(height: 12),
          if (_isLoadingTeamData)
            Center(child: CircularProgressIndicator())
          else if (_teamOrgInfo == null)
            OutlinedButton.icon(
              onPressed: _loadTeamData,
              icon: Icon(Icons.edit_note),
              label: Text('Carica e modifica dati team'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
            )
          else
            _buildTeamDataForm(),
        ],
      ),
    );
  }

  Widget _buildTeamDataForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _teamNameController,
          label: 'Nome ASD / Team',
          icon: Icons.business,
        ),
        SizedBox(height: 12),
        _buildTextField(
          controller: _teamAddressController,
          label: 'Indirizzo sede (via, città, CAP)',
          icon: Icons.location_on,
          maxLines: 2,
        ),
        SizedBox(height: 12),
        _buildTextField(
          controller: _teamTaxCodeController,
          label: 'Codice Fiscale',
          icon: Icons.credit_card,
        ),
        SizedBox(height: 12),
        _buildTextField(
          controller: _teamPhoneController,
          label: 'Telefono (opzionale)',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: 12),
        _buildTextField(
          controller: _teamEmailController,
          label: 'Email (opzionale)',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 12),
        _buildTextField(
          controller: _teamPecController,
          label: 'PEC (opzionale)',
          icon: Icons.mark_email_read,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Le modifiche saranno applicate a tutte le ricevute successive.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _teamOrgInfo = null);
                },
                child: Text('Annulla'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSavingTeamData ? null : _saveTeamData,
                icon: _isSavingTeamData
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.save),
                label: Text(_isSavingTeamData ? 'Salvataggio...' : 'Salva'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadTeamData() async {
    setState(() => _isLoadingTeamData = true);
    try {
      final italianReceiptService = ItalianReceiptService();
      final orgInfo = await italianReceiptService.getOrganizationInfo();
      _teamNameController.text = orgInfo.name;
      _teamAddressController.text = orgInfo.address;
      _teamTaxCodeController.text = orgInfo.taxCode;
      _teamPhoneController.text = orgInfo.phone ?? '';
      _teamEmailController.text = orgInfo.email ?? '';
      _teamPecController.text = orgInfo.pec ?? '';
      setState(() {
        _teamOrgInfo = {
          'id': orgInfo.id,
          'name': orgInfo.name,
          'address': orgInfo.address,
          'tax_code': orgInfo.taxCode,
          'phone': orgInfo.phone,
          'email': orgInfo.email,
          'pec': orgInfo.pec,
        };
        _isLoadingTeamData = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeamData = false);
      _showErrorMessage('Errore nel caricamento dei dati team: $e');
    }
  }

  Future<void> _saveTeamData() async {
    if (_teamNameController.text.trim().isEmpty ||
        _teamAddressController.text.trim().isEmpty ||
        _teamTaxCodeController.text.trim().isEmpty) {
      _showErrorMessage('Nome, indirizzo e codice fiscale sono obbligatori');
      return;
    }
    setState(() => _isSavingTeamData = true);
    try {
      final italianReceiptService = ItalianReceiptService();
      await italianReceiptService.updateOrganizationInfo(
        name: _teamNameController.text.trim(),
        address: _teamAddressController.text.trim(),
        taxCode: _teamTaxCodeController.text.trim(),
        phone: _teamPhoneController.text.trim().isEmpty
            ? null
            : _teamPhoneController.text.trim(),
        email: _teamEmailController.text.trim().isEmpty
            ? null
            : _teamEmailController.text.trim(),
        pec: _teamPecController.text.trim().isEmpty
            ? null
            : _teamPecController.text.trim(),
      );
      setState(() {
        _isSavingTeamData = false;
        _teamOrgInfo = null;
      });
      _showSuccessMessage('Dati team aggiornati con successo!');
    } catch (e) {
      setState(() => _isSavingTeamData = false);
      _showErrorMessage('Errore nel salvataggio: $e');
    }
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
                          'admin_management.edit_full_profile'.tr(),
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
                          'profile.personal_info'.tr(),
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
                              label: 'profile.phone'.tr(),
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editCodiceFiscaleController,
                              label: 'profile.tax_code'.tr(),
                              icon: Icons.credit_card,
                            ),
                            SizedBox(height: 16),
                            // Birth Date Picker
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _selectedBirthDate ??
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
                                  borderRadius: BorderRadius.circular(8),
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
                                          : 'profile.birth_date'.tr(),
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
                          'profile.address'.tr(),
                          Icons.location_on,
                          [
                            _buildTextField(
                              controller: _editAddressLineController,
                              label: 'profile.address'.tr(),
                              icon: Icons.home,
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _editCityController,
                                    label: 'profile.city'.tr(),
                                    icon: Icons.location_city,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _editProvinceController,
                                    label: 'profile.province'.tr(),
                                    icon: Icons.map,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _editCapController,
                              label: 'profile.zip_code'.tr(),
                              icon: Icons.local_post_office,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Emergency Contact Section
                        _buildFormSection(
                          'profile.emergency_contact'.tr(),
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
                              label: 'profile.emergency_phone'.tr(),
                              icon: Icons.phone_in_talk,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Parent/Guardian Section (if minor)
                        _buildFormSection(
                          'profile.parent_guardian_info'.tr(),
                          Icons.family_restroom,
                          [
                            CheckboxListTile(
                              title: Text('admin_management.minor_user'.tr()),
                              value: _isMinor,
                              onChanged: (value) {
                                dialogSetState(() => _isMinor = value ?? false);
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
                                      label: 'profile.parent_guardian_name'
                                          .tr(),
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
                                label: 'profile.parent_guardian_email'.tr(),
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              SizedBox(height: 16),
                              _buildTextField(
                                controller: _editParentGuardianPhoneController,
                                label: 'profile.parent_guardian_phone'.tr(),
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                              SizedBox(height: 16),
                              _buildTextField(
                                controller:
                                    _editParentGuardianCodiceFiscaleController,
                                label: 'profile.parent_guardian_tax_code'.tr(),
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
                                  initialValue: _selectedRole,
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
                                      child: Text('roles.student'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'instructor',
                                      child: Text(
                                        'class_schedule.instructor'.tr(),
                                      ),
                                    ),
                                    if (isPrincipalAdmin) ...[
                                      DropdownMenuItem(
                                        value: 'admin',
                                        child: Text('roles.admin'.tr()),
                                      ),
                                      DropdownMenuItem(
                                        value: 'instructor_admin',
                                        child: Text(
                                          'dashboard.role_instructor_admin'
                                              .tr(),
                                        ),
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
                                  initialValue: _selectedStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Stato Account',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(Icons.check_circle),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('common.pending'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('common.approved'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text('common.rejected'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'suspended',
                                      child: Text(
                                        'admin_management.suspended'.tr(),
                                      ),
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
                                  initialValue:
                                      _selectedMedicalCertificateStatus,
                                  decoration: InputDecoration(
                                    labelText: 'Stato Certificato Medico',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(Icons.medical_services),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('common.pending'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'approved',
                                      child: Text('common.approved'.tr()),
                                    ),
                                    DropdownMenuItem(
                                      value: 'expired',
                                      child: Text(
                                        'profile.status_expired'.tr(),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'rejected',
                                      child: Text('common.rejected'.tr()),
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
                                  title: Text(
                                    'admin_management.active_account'.tr(),
                                  ),
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
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveCompleteUserProfile(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text('profile.save_changes'.tr()),
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
          updates['birth_date'] = _selectedBirthDate!.toIso8601String().split(
            'T',
          )[0];
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
        _showSuccessMessage('common.no_changes'.tr());
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      print('Error saving complete user profile: $e');
      _showErrorMessage(
        'admin_management.save_error'.tr(namedArgs: {'error': e.toString()}),
      );
    }
  }

  void _showPromotionDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'admin_management.manage_user_role'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'admin_management.select_role_for'.tr(
                namedArgs: {'name': '${user['full_name']}'},
              ),
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
            child: Text('common.cancel'.tr()),
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
        return 'dashboard.role_principal_admin'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'student':
      default:
        return 'dashboard.role_student'.tr();
    }
  }
}

/// Small circular avatar for a child profile in the admin list.
/// Loads the signed URL from Supabase storage and shows the photo if available,
/// otherwise falls back to the child_care icon.
class _ChildPhotoAvatar extends StatefulWidget {
  final String? storagePath;
  const _ChildPhotoAvatar({this.storagePath});

  @override
  State<_ChildPhotoAvatar> createState() => _ChildPhotoAvatarState();
}

class _ChildPhotoAvatarState extends State<_ChildPhotoAvatar> {
  String? _signedUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void didUpdateWidget(_ChildPhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _loadUrl();
    }
  }

  Future<void> _loadUrl() async {
    if (widget.storagePath == null || widget.storagePath!.isEmpty) {
      setState(() => _signedUrl = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await Supabase.instance.client.storage
          .from('user_docs')
          .createSignedUrl(widget.storagePath!, 3600);
      if (mounted)
        setState(() {
          _signedUrl = url;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _signedUrl = null;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0x26448AFF),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue,
            ),
          ),
        ),
      );
    }
    if (_signedUrl != null) {
      return ClipOval(
        child: Image.network(
          _signedUrl!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.child_care, color: Colors.blue[300], size: 16),
    );
  }
}
