import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/supabase_service.dart';
import './widgets/bulk_approval_widget.dart';
import './widgets/document_verification_widget.dart';
import './widgets/registration_card_widget.dart';

class RegistrationManagementSystem extends StatefulWidget {
  const RegistrationManagementSystem({super.key});

  @override
  State<RegistrationManagementSystem> createState() =>
      _RegistrationManagementSystemState();
}

class _RegistrationManagementSystemState
    extends State<RegistrationManagementSystem> {
  bool isLoading = true;
  bool isPrincipalAdmin = false;
  Map<String, dynamic>? currentUser;
  List<dynamic> pendingRegistrations = [];
  List<dynamic> filteredRegistrations = [];
  Set<String> selectedRegistrations = {};
  String selectedTypeFilter = 'all';
  String selectedUrgencyFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initializeRegistrationManagement();
  }

  Future<void> _initializeRegistrationManagement() async {
    try {
      await _checkAdminAccess();
      await _loadPendingRegistrations();
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

  Future<void> _loadPendingRegistrations() async {
    final client = SupabaseService.instance.client;

    try {
      final pendingResponse = await client
          .from('pending_registrations')
          .select()
          .order('created_at', ascending: false);

      pendingRegistrations = pendingResponse ?? [];
      _applyFilters();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading pending registrations: $e');
      pendingRegistrations = [];
    }
  }

  void _applyFilters() {
    filteredRegistrations =
        pendingRegistrations.where((registration) {
          // Type filter
          if (selectedTypeFilter != 'all') {
            final role =
                registration['requested_role']?.toString() ?? 'instructor';
            final isAdminRequest = ['admin', 'instructor_admin'].contains(role);

            if (selectedTypeFilter == 'standard' && isAdminRequest)
              return false;
            if (selectedTypeFilter == 'admin' && !isAdminRequest) return false;
          }

          // Urgency filter based on submission date
          if (selectedUrgencyFilter != 'all') {
            final createdAt = DateTime.parse(registration['created_at']);
            final daysSinceSubmission =
                DateTime.now().difference(createdAt).inDays;

            if (selectedUrgencyFilter == 'urgent' && daysSinceSubmission < 7)
              return false;
            if (selectedUrgencyFilter == 'normal' && daysSinceSubmission >= 7)
              return false;
          }

          return true;
        }).toList();
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

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'REGISTRATION_APPROVED',
        'description': 'Registrazione approvata',
        'target_user_id': registrationId,
      });

      _showSuccessMessage('Registrazione approvata con successo');
      await _loadPendingRegistrations();
    } catch (e) {
      print('Error approving registration: $e');
      _showErrorMessage('Errore nell\'approvazione: ${e.toString()}');
    }
  }

  Future<void> _rejectPendingRegistration(
    String registrationId,
    String reason,
  ) async {
    try {
      final client = SupabaseService.instance.client;

      await client
          .from('pending_registrations')
          .update({
            'status': 'rejected',
            'reviewed_by': currentUser?['id'],
            'reviewed_at': DateTime.now().toIso8601String(),
            'rejection_reason': reason,
          })
          .eq('id', registrationId);

      // Log the admin activity
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'REGISTRATION_REJECTED',
        'description': 'Registrazione respinta: $reason',
        'target_user_id': registrationId,
      });

      _showSuccessMessage('Registrazione respinta');
      await _loadPendingRegistrations();
    } catch (e) {
      print('Error rejecting registration: $e');
      _showErrorMessage('Errore nel rifiuto: ${e.toString()}');
    }
  }

  Future<void> _requestAdditionalDocuments(
    String registrationId,
    List<String> documents,
  ) async {
    try {
      final client = SupabaseService.instance.client;

      // In a real implementation, this would send an email or notification
      // For now, we'll just log it
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'DOCUMENTS_REQUESTED',
        'description':
            'Richiesti documenti aggiuntivi: ${documents.join(', ')}',
        'target_user_id': registrationId,
      });

      _showSuccessMessage('Richiesta documenti inviata automaticamente');
    } catch (e) {
      print('Error requesting documents: $e');
      _showErrorMessage('Errore nella richiesta documenti: ${e.toString()}');
    }
  }

  Future<void> _contactApplicant(
    String registrationId,
    String contactMethod,
  ) async {
    try {
      final client = SupabaseService.instance.client;

      // Log the contact attempt
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'APPLICANT_CONTACTED',
        'description': 'Contattato richiedente via $contactMethod',
        'target_user_id': registrationId,
      });

      _showSuccessMessage('Contatto registrato nel sistema');
    } catch (e) {
      print('Error logging contact: $e');
      _showErrorMessage('Errore nel logging contatto: ${e.toString()}');
    }
  }

  Future<void> _scheduleInterview(
    String registrationId,
    DateTime dateTime,
  ) async {
    try {
      final client = SupabaseService.instance.client;

      // Log the interview scheduling
      await client.from('admin_activity_log').insert({
        'admin_id': currentUser?['id'],
        'action_type': 'INTERVIEW_SCHEDULED',
        'description': 'Colloquio programmato per ${dateTime.toString()}',
        'target_user_id': registrationId,
      });

      _showSuccessMessage('Colloquio programmato con notifica automatica');
    } catch (e) {
      print('Error scheduling interview: $e');
      _showErrorMessage(
        'Errore nella programmazione colloquio: ${e.toString()}',
      );
    }
  }

  Future<void> _archiveApplication(String registrationId) async {
    try {
      final client = SupabaseService.instance.client;

      await client
          .from('pending_registrations')
          .update({
            'status': 'archived',
            'reviewed_by': currentUser?['id'],
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', registrationId);

      _showSuccessMessage('Domanda archiviata');
      await _loadPendingRegistrations();
    } catch (e) {
      print('Error archiving application: $e');
      _showErrorMessage('Errore nell\'archiviazione: ${e.toString()}');
    }
  }

  Future<void> _bulkApproveRegistrations() async {
    if (selectedRegistrations.isEmpty) return;

    try {
      final client = SupabaseService.instance.client;

      for (String registrationId in selectedRegistrations) {
        await client
            .from('pending_registrations')
            .update({
              'status': 'approved',
              'reviewed_by': currentUser?['id'],
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', registrationId);

        // Log each approval
        await client.from('admin_activity_log').insert({
          'admin_id': currentUser?['id'],
          'action_type': 'BULK_REGISTRATION_APPROVED',
          'description': 'Registrazione approvata in massa',
          'target_user_id': registrationId,
        });
      }

      _showSuccessMessage(
        '${selectedRegistrations.length} registrazioni approvate con email di benvenuto automatiche',
      );
      setState(() {
        selectedRegistrations.clear();
      });
      await _loadPendingRegistrations();
    } catch (e) {
      print('Error in bulk approval: $e');
      _showErrorMessage('Errore nell\'approvazione in massa: ${e.toString()}');
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sistema Gestione Registrazioni',
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
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final totalPending =
        pendingRegistrations.where((r) => r['status'] == 'pending').length;
    final approvalStatistics = _calculateApprovalStatistics();
    final priorityCount = _getPriorityRegistrationsCount();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sistema Gestione Registrazioni',
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
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadPendingRegistrations,
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (selectedRegistrations.isNotEmpty)
            IconButton(
              onPressed: () {
                setState(() {
                  selectedRegistrations.clear();
                });
              },
              icon: Icon(
                Icons.clear_all,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section - Consistent with app design
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
                          Icons.pending_actions,
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
                              'Gestione Registrazioni',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Approva, gestisci e monitora registrazioni',
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
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              totalPending > 0
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                totalPending > 0 ? Colors.orange : Colors.green,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$totalPending in attesa',
                          style: TextStyle(
                            color:
                                totalPending > 0 ? Colors.orange : Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (totalPending > 0 || priorityCount > 0) ...[
                    SizedBox(height: 12),
                    Row(
                      children: [
                        if (priorityCount > 0) ...[
                          Icon(
                            Icons.priority_high,
                            color: Colors.red,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$priorityCount prioritarie',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 16),
                        ],
                        Text(
                          '${approvalStatistics['approved']} approvate • ${approvalStatistics['rejected']} respinte',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Filter section
            Container(
              width: double.infinity,
              color: Theme.of(context).cardColor,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtri Registrazioni',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'Tutte',
                          'all',
                          selectedTypeFilter,
                          Colors.grey,
                          (value) => setState(() {
                            selectedTypeFilter = value;
                            _applyFilters();
                          }),
                        ),
                        SizedBox(width: 8),
                        _buildFilterChip(
                          'Standard',
                          'standard',
                          selectedTypeFilter,
                          Colors.blue,
                          (value) => setState(() {
                            selectedTypeFilter = value;
                            _applyFilters();
                          }),
                        ),
                        SizedBox(width: 8),
                        _buildFilterChip(
                          'Admin',
                          'admin',
                          selectedTypeFilter,
                          Colors.orange,
                          (value) => setState(() {
                            selectedTypeFilter = value;
                            _applyFilters();
                          }),
                        ),
                        SizedBox(width: 16),
                        _buildFilterChip(
                          'Urgenti',
                          'urgent',
                          selectedUrgencyFilter,
                          Colors.red,
                          (value) => setState(() {
                            selectedUrgencyFilter = value;
                            _applyFilters();
                          }),
                        ),
                        SizedBox(width: 8),
                        _buildFilterChip(
                          'Normali',
                          'normal',
                          selectedUrgencyFilter,
                          Colors.green,
                          (value) => setState(() {
                            selectedUrgencyFilter = value;
                            _applyFilters();
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (selectedRegistrations.isNotEmpty)
              BulkApprovalWidget(
                selectedCount: selectedRegistrations.length,
                onBulkApprove: _bulkApproveRegistrations,
                onClearSelection: () {
                  setState(() {
                    selectedRegistrations.clear();
                  });
                },
              ),

            Expanded(
              child:
                  filteredRegistrations.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 48,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nessuna registrazione in attesa',
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (selectedTypeFilter != 'all' ||
                                selectedUrgencyFilter != 'all') ...[
                              SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedTypeFilter = 'all';
                                    selectedUrgencyFilter = 'all';
                                    _applyFilters();
                                  });
                                },
                                child: Text('Pulisci filtri'),
                              ),
                            ],
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: filteredRegistrations.length,
                        itemBuilder: (context, index) {
                          final registration = filteredRegistrations[index];
                          final isSelected = selectedRegistrations.contains(
                            registration['id'],
                          );

                          return RegistrationCardWidget(
                            registration: registration,
                            isSelected: isSelected,
                            isPrincipalAdmin: isPrincipalAdmin,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedRegistrations.remove(
                                    registration['id'],
                                  );
                                } else {
                                  selectedRegistrations.add(registration['id']);
                                }
                              });
                            },
                            onApprove:
                                () => _approvePendingRegistration(
                                  registration['id'],
                                ),
                            onReject:
                                (reason) => _rejectPendingRegistration(
                                  registration['id'],
                                  reason,
                                ),
                            onRequestDocuments:
                                (documents) => _requestAdditionalDocuments(
                                  registration['id'],
                                  documents,
                                ),
                            onContactApplicant:
                                (method) => _contactApplicant(
                                  registration['id'],
                                  method,
                                ),
                            onScheduleInterview:
                                (dateTime) => _scheduleInterview(
                                  registration['id'],
                                  dateTime,
                                ),
                            onArchive:
                                () => _archiveApplication(registration['id']),
                            onViewDocuments:
                                () => _showDocumentVerificationDialog(
                                  registration,
                                ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show real-time notifications panel
          _showNotificationsPanel();
        },
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Colors.white,
        icon: Stack(
          children: [
            Icon(Icons.notifications, color: Colors.white),
            if (priorityCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  constraints: BoxConstraints(minWidth: 12, minHeight: 12),
                  child: Text(
                    priorityCount.toString(),
                    style: TextStyle(color: Colors.white, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: Text(
          'Notifiche',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Color color,
    Function(String) onChanged,
  ) {
    final isSelected = selectedValue == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color:
                  isSelected
                      ? color
                      : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  isSelected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateApprovalStatistics() {
    final total = pendingRegistrations.length;
    final approved =
        pendingRegistrations.where((r) => r['status'] == 'approved').length;
    final rejected =
        pendingRegistrations.where((r) => r['status'] == 'rejected').length;
    final pending =
        pendingRegistrations.where((r) => r['status'] == 'pending').length;

    return {
      'total': total,
      'approved': approved,
      'rejected': rejected,
      'pending': pending,
    };
  }

  int _getPriorityRegistrationsCount() {
    return pendingRegistrations.where((registration) {
      final createdAt = DateTime.parse(registration['created_at']);
      final daysSinceSubmission = DateTime.now().difference(createdAt).inDays;
      final role = registration['requested_role']?.toString() ?? 'instructor';
      final isAdminRequest = ['admin', 'instructor_admin'].contains(role);

      return daysSinceSubmission >= 7 || isAdminRequest;
    }).length;
  }

  void _showDocumentVerificationDialog(Map<String, dynamic> registration) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: DocumentVerificationWidget(
              registration: registration,
              onDocumentApprove: (docType) {
                _showSuccessMessage('Documento $docType approvato');
              },
              onDocumentReject: (docType, reason) {
                _showErrorMessage('Documento $docType respinto: $reason');
              },
            ),
          ),
    );
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifiche Tempo Reale',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Registrazioni che richiedono attenzione immediata',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      if (_getPriorityRegistrationsCount() > 0)
                        ListTile(
                          leading: Icon(Icons.priority_high, color: Colors.red),
                          title: Text('Registrazioni urgenti'),
                          subtitle: Text(
                            '${_getPriorityRegistrationsCount()} registrazioni richiedono attenzione',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              selectedUrgencyFilter = 'urgent';
                              _applyFilters();
                            });
                          },
                        ),
                      ListTile(
                        leading: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.orange,
                        ),
                        title: Text('Richieste Admin'),
                        subtitle: Text(
                          'Richieste amministratore necessitano approvazione principale',
                        ),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            selectedTypeFilter = 'admin';
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
