import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import '../../services/student_registration_service.dart';
import './widgets/bulk_approval_widget.dart';
import './widgets/document_verification_widget.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPendingRegistrations();
    // Set up periodic refresh to check for new registrations
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadPendingRegistrations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingRegistrations() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final registrations =
          await StudentRegistrationService.getPendingRegistrations();

      if (mounted) {
        setState(() {
          pendingRegistrations = registrations;
          filteredRegistrations = registrations;
          isLoading = false;
        });

        // Show notification badge if there are new registrations
        if (registrations.isNotEmpty) {
          print('Found ${registrations.length} pending registrations');
        }
      }
    } catch (e) {
      print('Error loading registrations: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      filteredRegistrations = pendingRegistrations.where((registration) {
        bool matchesType = true;
        bool matchesUrgency = true;

        if (selectedTypeFilter != 'all') {
          final role = registration['requested_role']?.toString() ?? 'instructor';
          if (selectedTypeFilter == 'admin') {
            matchesType = ['admin', 'instructor_admin'].contains(role);
          } else if (selectedTypeFilter == 'standard') {
            matchesType = role == 'instructor';
          }
        }

        if (selectedUrgencyFilter != 'all') {
          final createdAt = DateTime.parse(registration['created_at']);
          final daysSinceSubmission = DateTime.now().difference(createdAt).inDays;
          final isUrgent = daysSinceSubmission >= 7;
          
          if (selectedUrgencyFilter == 'urgent') {
            matchesUrgency = isUrgent;
          } else if (selectedUrgencyFilter == 'normal') {
            matchesUrgency = !isUrgent;
          }
        }

        return matchesType && matchesUrgency;
      }).toList();
    });
  }

  Future<void> _bulkApproveRegistrations() async {
    if (selectedRegistrations.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Approvazione Multipla'),
        content: Text(
          'Sei sicuro di voler approvare ${selectedRegistrations.length} registrazioni?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approva Tutto'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      for (final registrationId in selectedRegistrations) {
        final registration = pendingRegistrations.firstWhere(
          (r) => r['id'] == registrationId,
        );
        await StudentRegistrationService.approveUserRegistration(
          registration['email'],
          'Approvazione multipla da amministratore',
        );
      }

      _showMessage('${selectedRegistrations.length} registrazioni approvate');
      selectedRegistrations.clear();
      await _loadPendingRegistrations();
    } catch (e) {
      _showMessage('Errore durante l\'approvazione multipla: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _approveRegistration(Map<String, dynamic> registration) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conferma Approvazione'),
          content: Text(
            'Sei sicuro di voler approvare la registrazione di ${registration['full_name']}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approva'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => isLoading = true);

      final success = await StudentRegistrationService.approveUserRegistration(
        registration['email'],
        'Registrazione approvata dall\'amministratore',
      );

      if (success) {
        _showMessage('Registrazione approvata con successo');
        await _loadPendingRegistrations(); // Refresh the list
      } else {
        _showMessage('Errore durante l\'approvazione', isError: true);
      }
    } catch (e) {
      print('Error approving registration: $e');
      _showMessage('Errore durante l\'approvazione: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> registration) async {
    try {
      // Show rejection dialog with reason input
      String? rejectionReason;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final reasonController = TextEditingController();
          return AlertDialog(
            title: const Text('Rifiuta Registrazione'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sei sicuro di voler rifiutare la registrazione di ${registration['full_name']}?',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del rifiuto (opzionale)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () {
                  rejectionReason = reasonController.text.trim();
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'Rifiuta',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      setState(() => isLoading = true);

      final success = await StudentRegistrationService.rejectUserRegistration(
        registration['email'],
        rejectionReason?.isNotEmpty == true ? rejectionReason : null,
      );

      if (success) {
        _showMessage('Registrazione rifiutata');
        await _loadPendingRegistrations(); // Refresh the list
      } else {
        _showMessage('Errore durante il rifiuto', isError: true);
      }
    } catch (e) {
      print('Error rejecting registration: $e');
      _showMessage('Errore durante il rifiuto: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    _showMessage(message, isError: false);
  }

  void _showErrorMessage(String message) {
    _showMessage(message, isError: true);
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
                                color: Theme.of(
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
                          color: totalPending > 0
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
              child: filteredRegistrations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Nessuna registrazione in attesa',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(
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

                        return _buildRegistrationCard(registration);
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

  Widget _buildRegistrationCard(Map<String, dynamic> registration) {
    final isMinor = registration['is_minor'] == true;
    final medicalStatus = registration['medical_cert_status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and email
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registration['full_name'] ?? 'Nome non disponibile',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        registration['email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMinor)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'MINORENNE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Registration details
            if (registration['phone'] != null)
              _buildDetailRow('Telefono', registration['phone']),

            _buildDetailRow(
              'Data richiesta',
              _formatDate(registration['created_at']),
            ),

            _buildDetailRow(
              'Certificato medico',
              medicalStatus == 'uploaded' ? 'Caricato' : 'Da caricare',
            ),

            // Message from registration
            if (registration['message'] != null &&
                registration['message'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dettagli registrazione:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        registration['message'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => _approveRegistration(registration),
                    icon: const Icon(Icons.check),
                    label: const Text('Approva'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => _rejectRegistration(registration),
                    icon: const Icon(Icons.close),
                    label: const Text('Rifiuta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'Non disponibile';

    try {
      DateTime date;
      if (dateTime is String) {
        date = DateTime.parse(dateTime);
      } else {
        date = dateTime as DateTime;
      }
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Non disponibile';
    }
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
              color: isSelected
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
              color: isSelected
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
      builder: (context) => Dialog(
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
      builder: (context) => Container(
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