import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../services/sponsor_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/sponsor_card_widget.dart';
import './widgets/sponsor_form_dialog_widget.dart';
import './widgets/sponsor_stats_widget.dart';

class AdminSponsorManagement extends StatefulWidget {
  const AdminSponsorManagement({Key? key}) : super(key: key);

  @override
  State<AdminSponsorManagement> createState() => _AdminSponsorManagementState();
}

class _AdminSponsorManagementState extends State<AdminSponsorManagement> {
  List<Map<String, dynamic>> _sponsors = [];
  Map<String, int> _stats = {'total': 0, 'active': 0, 'inactive': 0};
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    _loadSponsors();
    _loadStats();
  }

  Future<void> _loadSponsors() async {
    try {
      setState(() => _isLoading = true);
      final sponsors = await SponsorService.getAllSponsors();
      if (mounted) {
        setState(() {
          _sponsors = sponsors;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading sponsors: $error');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorMessage('Errore nel caricamento degli sponsor');
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await SponsorService.getSponsorStats();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (error) {
      print('Error loading sponsor stats: $error');
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadSponsors(),
      _loadStats(),
    ]);
  }

  List<Map<String, dynamic>> get _filteredSponsors {
    return _sponsors.where((sponsor) {
      final matchesSearch = _searchQuery.isEmpty ||
          sponsor['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sponsor['description']
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);

      final matchesStatus =
          _statusFilter == 'all' || sponsor['status'] == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _showCreateSponsorDialog() {
    showDialog(
      context: context,
      builder: (context) => SponsorFormDialogWidget(
        onSponsorCreated: () {
          Navigator.pop(context);
          _refreshData();
          _showSuccessMessage('Sponsor creato con successo');
        },
      ),
    );
  }

  void _showEditSponsorDialog(Map<String, dynamic> sponsor) {
    showDialog(
      context: context,
      builder: (context) => SponsorFormDialogWidget(
        sponsor: sponsor,
        onSponsorUpdated: () {
          Navigator.pop(context);
          _refreshData();
          _showSuccessMessage('Sponsor aggiornato con successo');
        },
      ),
    );
  }

  Future<void> _deleteSponsor(String sponsorId, String sponsorName) async {
    final confirmed = await _showDeleteConfirmationDialog(sponsorName);
    if (!confirmed) return;

    try {
      final success = await SponsorService.deleteSponsor(sponsorId);
      if (success) {
        _refreshData();
        _showSuccessMessage('Sponsor eliminato con successo');
      } else {
        _showErrorMessage('Errore nell\'eliminazione dello sponsor');
      }
    } catch (error) {
      print('Error deleting sponsor: $error');
      _showErrorMessage('Errore nell\'eliminazione dello sponsor');
    }
  }

  Future<void> _toggleSponsorStatus(
      String sponsorId, String currentStatus) async {
    try {
      final success =
          await SponsorService.toggleSponsorStatus(sponsorId, currentStatus);
      if (success) {
        _refreshData();
        final newStatus =
            currentStatus == 'active' ? 'disattivato' : 'attivato';
        _showSuccessMessage('Sponsor $newStatus con successo');
      } else {
        _showErrorMessage('Errore nel cambio di stato dello sponsor');
      }
    } catch (error) {
      print('Error toggling sponsor status: $error');
      _showErrorMessage('Errore nel cambio di stato dello sponsor');
    }
  }

  Future<bool> _showDeleteConfirmationDialog(String sponsorName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Conferma eliminazione'),
            content: Text(
                'Sei sicuro di voler eliminare lo sponsor "$sponsorName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Gestione Sponsor'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Aggiorna',
            ),
            IconButton(
              onPressed: _showCreateSponsorDialog,
              icon: const Icon(Icons.add),
              tooltip: 'Aggiungi Sponsor',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          child: Column(
            children: [
              // Stats Section
              SponsorStatsWidget(stats: _stats),

              // Search and Filter
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Cerca sponsor...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Status Filter
                    Row(
                      children: [
                        Text(
                          'Stato: ',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Wrap(
                            spacing: 2.w,
                            children: [
                              _buildFilterChip('Tutti', 'all'),
                              _buildFilterChip('Attivi', 'active'),
                              _buildFilterChip('Inattivi', 'inactive'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sponsors List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _buildSponsorsList(),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateSponsorDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _statusFilter = value);
        }
      },
      selectedColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSponsorsList() {
    final filteredSponsors = _filteredSponsors;

    if (filteredSponsors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            SizedBox(height: 2.h),
            Text(
              _searchQuery.isEmpty && _statusFilter == 'all'
                  ? 'Nessuno sponsor presente'
                  : 'Nessun risultato trovato',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: 1.h),
            Text(
              _searchQuery.isEmpty && _statusFilter == 'all'
                  ? 'Aggiungi il primo sponsor cliccando il pulsante +'
                  : 'Prova con criteri di ricerca diversi',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      itemCount: filteredSponsors.length,
      itemBuilder: (context, index) {
        final sponsor = filteredSponsors[index];
        return SponsorCardWidget(
          sponsor: sponsor,
          onEdit: () => _showEditSponsorDialog(sponsor),
          onDelete: () => _deleteSponsor(sponsor['id'], sponsor['name']),
          onToggleStatus: () => _toggleSponsorStatus(
            sponsor['id'],
            sponsor['status'],
          ),
        );
      },
    );
  }
}
